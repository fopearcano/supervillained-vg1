// M1 migration spike host tool (Node 22+: global fetch and WebSocket).
//   node m1_spike_tool.mjs cdp <port> <script.js> <out.json>
//       Runs <script.js> in the old Capacitor app's page (the https://localhost target) through the
//       WebView DevTools protocol (adb-forwarded port) and writes the returned value as JSON.
//   node m1_spike_tool.mjs parse-log <logcat-raw.txt> <out.json>
//       Reassembles the harness's M1_SPIKE_CHUNK lines into the plugin's raw JSON per attempt and
//       collects the M1_SPIKE_SUMMARY / KEY / IDEMPOTENT / DONE lines and the longest M1_SPIKE
//       line (Godot's Android logger truncates a print at 1023 characters).
//   node m1_spike_tool.mjs expected <old-read.json> <out.json>
//       Expected raw values and SHA-256 (UTF-8) of the five keys from a read of the old app.
//   node m1_spike_tool.mjs compare <expected.json> <parsed.json> <expect-status> <out.json>
//       Checks every attempt of a spike run: status, origin, and (for success) every key's raw
//       value equals the expected one. Exit 1 on any mismatch.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const KEYS = ['settings', 'records', 'coins', 'story', 'story-v1-backup'];
const ORIGIN = 'https://localhost';
const sha256 = (s) => createHash('sha256').update(s, 'utf8').digest('hex');
const write = (p, v) => writeFileSync(p, JSON.stringify(v, null, 2) + '\n');
const [cmd, ...args] = process.argv.slice(2);

async function cdp(port, scriptPath, outPath) {
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const page = targets.find((t) => t.type === 'page' && String(t.url).startsWith(ORIGIN + '/'));
  if (!page) throw new Error('no https://localhost page target: ' + JSON.stringify(targets.map((t) => t.url)));
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  const reply = await new Promise((res, rej) => {
    ws.onmessage = (m) => { const d = JSON.parse(m.data); if (d.id === 1) res(d); };
    ws.onerror = rej;
    ws.send(JSON.stringify({ id: 1, method: 'Runtime.evaluate', params: { expression: readFileSync(scriptPath, 'utf8'), returnByValue: true, awaitPromise: true } }));
  });
  ws.close();
  if (reply.error || reply.result.exceptionDetails) throw new Error('evaluate failed: ' + JSON.stringify(reply.error || reply.result.exceptionDetails));
  const value = reply.result.result.value;
  write(outPath, { target_url: page.url, value });
  console.log(JSON.stringify({ target_url: page.url, value }).slice(0, 400));
}

function parseLog(logPath, outPath) {
  const lines = readFileSync(logPath, 'utf8').split(/\r?\n/);
  const chunks = {};
  const out = { attempts: {}, summaries: {}, idempotent: null, done: null, start: null, max_line_length: 0 };
  for (const line of lines) {
    if (line.includes('M1_SPIKE_')) out.max_line_length = Math.max(out.max_line_length, line.length);
    let m = line.match(/M1_SPIKE_CHUNK (\d+) (\d+)\/(\d+) (\S+)/);
    if (m) { (chunks[m[1]] ??= { count: +m[3], parts: {} }).parts[+m[2]] = m[4]; continue; }
    m = line.match(/M1_SPIKE_SUMMARY (\d+) (\{.*\})\s*$/);
    if (m) { out.summaries[m[1]] = { keys: {}, ...(out.summaries[m[1]] ?? {}), ...JSON.parse(m[2]) }; continue; }
    m = line.match(/M1_SPIKE_KEY (\d+) (\S+) (\{.*\})\s*$/);
    if (m) { ((out.summaries[m[1]] ??= { keys: {} }).keys ??= {})[m[2]] = JSON.parse(m[3]); continue; }
    m = line.match(/M1_SPIKE_(IDEMPOTENT|DONE|START) (\{.*\})\s*$/);
    if (m) out[m[1].toLowerCase()] = JSON.parse(m[2]);
  }
  for (const [a, c] of Object.entries(chunks)) {
    const parts = [];
    for (let i = 1; i <= c.count; i++) {
      if (c.parts[i] === undefined) throw new Error(`attempt ${a}: chunk ${i}/${c.count} missing`);
      parts.push(c.parts[i]);
    }
    out.attempts[a] = JSON.parse(Buffer.from(parts.join(''), 'base64').toString('utf8'));
  }
  write(outPath, out);
  console.log(JSON.stringify({ attempts: Object.keys(out.attempts), done: out.done, idempotent: out.idempotent }));
}

function expected(oldReadPath, outPath) {
  const v = JSON.parse(readFileSync(oldReadPath, 'utf8')).value;
  if (v.origin !== ORIGIN) throw new Error('old read origin ' + v.origin);
  const keys = {};
  for (const k of KEYS) {
    const raw = v.keys[k];
    keys[k] = { storage_key: 'supervillained:' + k, present: raw !== null, length: raw === null ? null : raw.length, sha256: raw === null ? null : sha256(raw), raw };
  }
  write(outPath, { origin: v.origin, prefixed_keys_in_store: v.prefixed_keys, keys });
  console.log(JSON.stringify(Object.fromEntries(KEYS.map((k) => [k, keys[k].sha256]))));
}

function compare(expectedPath, parsedPath, expectStatus, outPath) {
  const exp = JSON.parse(readFileSync(expectedPath, 'utf8'));
  const run = JSON.parse(readFileSync(parsedPath, 'utf8'));
  const checks = [];
  const check = (name, ok, detail) => checks.push({ name, ok: !!ok, ...(detail === undefined ? {} : { detail }) });
  const attempts = Object.keys(run.attempts);
  check('two attempts reassembled', attempts.length === 2, attempts);
  for (const a of attempts) {
    const r = run.attempts[a];
    check(`attempt ${a}: status ${expectStatus}`, r.status === expectStatus, { status: r.status, error: r.error ?? null });
    check(`attempt ${a}: verified origin ${ORIGIN}`, r.verified_origin === ORIGIN, r.verified_origin);
    if (expectStatus === 'success') {
      for (const k of KEYS) {
        const got = r.keys?.[k];
        const e = exp.keys[k];
        check(`attempt ${a}: ${k} present`, got?.present === true && e.present === true);
        check(`attempt ${a}: ${k} raw value identical`, got?.raw === e.raw, { expected_sha256: e.sha256, got_sha256: typeof got?.raw === 'string' ? sha256(got.raw) : null });
        check(`attempt ${a}: ${k} no error`, got?.error === null);
      }
    } else if (expectStatus === 'not_found') {
      for (const k of KEYS) check(`attempt ${a}: ${k} absent`, r.keys?.[k]?.present === false && r.keys?.[k]?.raw === null);
    }
    const s = run.summaries[a];
    if (expectStatus === 'success') for (const k of KEYS) check(`attempt ${a}: ${k} harness sha256`, s?.keys?.[k]?.sha256 === exp.keys[k].sha256);
  }
  if (attempts.length === 2) {
    const strip = (r) => JSON.stringify(KEYS.map((k) => r.keys?.[k] ?? null));
    check('in-process repeated read identical', strip(run.attempts['1']) === strip(run.attempts['2']));
  }
  check('no harness log line truncated (all under 1023 characters)', run.max_line_length > 0 && run.max_line_length < 1023, run.max_line_length);
  check('harness idempotence line', run.idempotent?.identical === true);
  check('harness done status', run.done?.status === expectStatus, run.done);
  const ok = checks.every((c) => c.ok);
  write(outPath, { expect_status: expectStatus, ok, checks });
  console.log(`${ok ? 'PASS' : 'FAIL'}: ${checks.filter((c) => c.ok).length}/${checks.length} checks`);
  for (const c of checks) if (!c.ok) console.log('  failed: ' + c.name + ' ' + JSON.stringify(c.detail ?? ''));
  if (!ok) process.exitCode = 1;
}

try {
  if (cmd === 'cdp') await cdp(args[0], args[1], args[2]);
  else if (cmd === 'parse-log') parseLog(args[0], args[1]);
  else if (cmd === 'expected') expected(args[0], args[1]);
  else if (cmd === 'compare') compare(args[0], args[1], args[2], args[3]);
  else throw new Error('usage: cdp | parse-log | expected | compare');
} catch (e) {
  console.error(String(e?.stack || e));
  process.exitCode = 2;
}
