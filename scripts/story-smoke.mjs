/**
 * Story smoke test: plays every sub-level script from start to finish, skipping each step after a
 * few frames (`StoryScene.debugSkip`), and fails on any page error (missing marker, unknown actor,
 * bad sprite key...).
 *
 *   npm run smoke                 all sub-levels
 *   npm run smoke -- 7.3 8.1      selected sub-levels
 *   SMOKE_SHOTS=dir npm run smoke one screenshot per sub-level (first walk / mini-game / choice)
 */
import { spawn } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { chromium } from 'playwright';

const PORT = 5198;
const SHOTS = process.env.SMOKE_SHOTS ?? '';
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function startServer() {
  const proc = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--port', String(PORT), '--strictPort', '--host', '127.0.0.1'], {
    stdio: ['ignore', 'pipe', 'pipe'],
    detached: true,
  });
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('vite did not start')), 30000);
    proc.stdout.on('data', (d) => {
      if (String(d).includes('Local')) {
        clearTimeout(timer);
        resolve();
      }
    });
    proc.on('exit', (code) => reject(new Error(`vite exited ${code}`)));
  });
  return proc;
}

const INTERESTING = new Set(['WalkStep', 'MiniGameStep', 'AskStep']);

const server = await startServer();
const browser = await chromium.launch();
let failures = 0;
try {
  const page = await browser.newPage({ viewport: { width: 400, height: 860 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => {
    const text = m.text();
    if (m.type() === 'error' || /missing texture|GL_INVALID/.test(text)) errors.push(text);
  });
  await page.goto(`http://127.0.0.1:${PORT}/?story=1.1`);
  await page.waitForFunction(() => window.__sv && window.__sv.top(), null, { timeout: 30000 });
  await page.evaluate(() => localStorage.clear());
  const all = await page.evaluate(() => window.__sv.storyIds());
  const ids = process.argv.slice(2).length ? process.argv.slice(2) : all;
  if (SHOTS) mkdirSync(SHOTS, { recursive: true });
  for (const id of ids) {
    errors.length = 0;
    await page.evaluate((s) => window.__sv.flow.story.debugPlay(s), id);
    await wait(250);
    let steps = 0;
    let shot = false;
    const seen = [];
    for (let guard = 0; guard < 400; guard++) {
      const st = await page.evaluate(
        (s) => {
          const top = window.__sv.top();
          if (!top.debugSkip) return null;
          const d = top.debugState();
          return d.sub === s ? d : null;
        },
        id,
      );
      if (!st) break;
      if (st.step) seen.push(st.step);
      if (SHOTS && !shot && INTERESTING.has(st.step)) {
        await wait(st.step === 'WalkStep' ? 900 : 500);
        await page.screenshot({ path: `${SHOTS}/${id}.png` });
        shot = true;
      }
      await wait(90);
      await page.evaluate((s) => {
        const top = window.__sv.top();
        if (top.debugSkip && top.debugState().sub === s) top.debugSkip();
      }, id);
      steps++;
      if (errors.length) break;
    }
    if (SHOTS && !shot) await page.screenshot({ path: `${SHOTS}/${id}.png` });
    const kinds = [...new Set(seen)].join(',');
    if (errors.length) {
      failures++;
      console.log(`FAIL ${id} after ${steps} steps: ${errors.join(' | ')}`);
    } else console.log(`ok   ${id}  ${steps} steps  [${kinds}]`);
  }
  await page.close();
} catch (err) {
  console.error(err);
  failures++;
} finally {
  await browser.close();
  try {
    process.kill(-server.pid, 'SIGTERM');
  } catch {
    server.kill();
  }
}
console.log(failures ? `${failures} sub-level(s) failed` : 'all sub-levels ok');
process.exit(failures ? 1 : 0);
