/**
 * Verification screenshots with Playwright.
 *
 *   npm run screens -- <scenario...>        (default: all scenarios)
 *
 * Starts a Vite dev server, opens the game in a phone-sized viewport, drives it through the
 * debug hook `window.__sv`, and writes PNGs to docs/screens/.
 */
import { spawn } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { chromium } from 'playwright';

const PORT = 5199;
const OUT = 'docs/screens';
const VIEWPORT = { width: 400, height: 860 };

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

async function openGame(browser, query = '') {
  const page = await browser.newPage({ viewport: VIEWPORT, deviceScaleFactor: 2, hasTouch: true, isMobile: true });
  page.on('console', (m) => {
    if (m.type() === 'error' || m.type() === 'warning') console.log(`[page ${m.type()}] ${m.text()}`);
  });
  page.on('pageerror', (e) => console.log(`[page error] ${e.message}`));
  await page.goto(`http://127.0.0.1:${PORT}/${query}`);
  await page.waitForFunction(() => window.__sv && window.__sv.scene(), null, { timeout: 30000 });
  await wait(300);
  return page;
}

async function holdKeys(page, keys, ms) {
  for (const k of keys) await page.keyboard.down(k);
  await wait(ms);
  for (const k of keys) await page.keyboard.up(k);
}

const SCENARIOS = {
  /** Sprite sheets of every character (debug viewer). */
  async sprites(browser) {
    for (const c of ['zampano', 'bagnaskiz', 'cat']) {
      const page = await openGame(browser, `?debug=sprites&char=${c}`);
      await page.screenshot({ path: `${OUT}/sprites-${c}.png` });
      await page.close();
    }
  },
  /** M1: walking up the path, then standing behind a tree (occlusion fade). */
  async m1(browser) {
    const page = await openGame(browser, '?skip=game');
    await holdKeys(page, ['KeyW'], 1500);
    await holdKeys(page, ['KeyD'], 400);
    await wait(400);
    await page.screenshot({ path: `${OUT}/m1-walk.png` });
    // Behind a tree near the start.
    await page.evaluate(() => {
      const s = window.__sv.scene();
      const p = s.player;
      const tree = s.map.props
        .filter((t) => t.kind === 'tree')
        .sort((a, b) => Math.hypot(a.x - p.gx, a.y - p.gy) - Math.hypot(b.x - p.gx, b.y - p.gy))[0];
      s.teleport(tree.x - 0.62, tree.y - 0.62);
      s.player.face('NW');
    });
    await wait(700);
    await page.screenshot({ path: `${OUT}/m1-behind-tree.png` });
    console.log(JSON.stringify(await page.evaluate(() => window.__sv.scene().debugState())));
    await page.close();
  },

  /** M2: HUD, treats, digestion warning, poop on the path, pee cleaning. */
  async m2(browser) {
    const page = await openGame(browser, '?skip=game');
    await holdKeys(page, ['KeyW'], 900);
    await wait(300);
    await page.screenshot({ path: `${OUT}/m2-hud.png` });
    // Eat the four nearest treats.
    for (let k = 0; k < 4; k++) {
      await page.evaluate(() => {
        const s = window.__sv.scene();
        const p = s.player;
        const t = [...s.rules.treats].sort((a, b) => Math.hypot(a.gx - p.gx, a.gy - p.gy) - Math.hypot(b.gx - p.gx, b.gy - p.gy))[0];
        s.teleport(t.gx + 0.05, t.gy + 0.05);
      });
      await wait(450);
    }
    // Stand on the path while the warning runs out → heavy poop.
    await page.evaluate(() => {
      const s = window.__sv.scene();
      const m = s.map;
      const p = s.player;
      let best = null;
      for (let j = 0; j < m.height; j++)
        for (let i = 0; i < m.width; i++)
          if (m.groundAt(i, j) === 2) {
            const d = Math.hypot(i + 0.5 - p.gx, j + 0.5 - p.gy);
            if (!best || d < best.d) best = { i, j, d };
          }
      s.teleport(best.i + 0.5, best.j + 0.5);
    });
    await wait(1200);
    await page.screenshot({ path: `${OUT}/m2-warning.png` });
    await wait(2300);
    await page.screenshot({ path: `${OUT}/m2-poop.png` });
    console.log('after poop', JSON.stringify(await page.evaluate(() => window.__sv.scene().debugState())));
    await wait(1200);
    await page.keyboard.press('Space');
    await wait(450);
    await page.screenshot({ path: `${OUT}/m2-pee.png` });
    await wait(900);
    console.log('after pee', JSON.stringify(await page.evaluate(() => window.__sv.scene().debugState())));
    await page.close();
  },

  /** M1: the floating touch joystick (mouse-driven pointer events). */
  async joystick(browser) {
    const page = await openGame(browser, '?skip=game');
    const before = await page.evaluate(() => window.__sv.scene().debugState());
    await page.mouse.move(110, 640);
    await page.mouse.down();
    await page.mouse.move(150, 590, { steps: 5 });
    await wait(1200);
    await page.screenshot({ path: `${OUT}/m1-joystick.png` });
    await page.mouse.up();
    const after = await page.evaluate(() => window.__sv.scene().debugState());
    console.log('joystick moved from', JSON.stringify(before.player), 'to', JSON.stringify(after.player));
    await page.close();
  },
};

const wanted = process.argv.slice(2);
const names = wanted.length ? wanted : Object.keys(SCENARIOS);
mkdirSync(OUT, { recursive: true });
const server = await startServer();
const browser = await chromium.launch();
try {
  for (const n of names) {
    if (!SCENARIOS[n]) throw new Error(`unknown scenario ${n}`);
    console.log(`scenario ${n}`);
    await SCENARIOS[n](browser);
  }
} catch (err) {
  console.error(err);
  process.exitCode = 1;
} finally {
  await browser.close();
  try {
    process.kill(-server.pid, 'SIGTERM');
  } catch {
    server.kill();
  }
}
process.exit();
