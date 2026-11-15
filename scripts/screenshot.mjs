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

  /** M3: title → briefing → game → pause → level end; then game over. */
  async m3(browser) {
    const page = await openGame(browser, '');
    await wait(1200);
    await page.screenshot({ path: `${OUT}/m3-title.png` });
    await page.mouse.click(200, 500);
    await wait(150);
    await page.screenshot({ path: `${OUT}/m3-glitch-transition.png` });
    await wait(1250);
    await page.screenshot({ path: `${OUT}/m3-briefing.png` });
    await page.mouse.click(200, 500);
    await wait(500);
    await holdKeys(page, ['KeyW'], 500);
    await page.keyboard.press('Escape');
    await wait(400);
    await page.screenshot({ path: `${OUT}/m3-pause.png` });
    await page.keyboard.press('Escape');
    await wait(300);
    // Jump to the exit.
    await page.evaluate(() => {
      const s = window.__sv.scene();
      s.rules.stats.coins = 10;
      s.teleport(s.map.exit.x + 1.2, s.map.exit.y + 1.2);
    });
    await holdKeys(page, ['KeyW'], 700);
    await wait(5200);
    await page.screenshot({ path: `${OUT}/m3-level-end.png` });
    console.log('top after exit:', await page.evaluate(() => window.__sv.top().constructor.name));
    // Retry, then starve twice → game over.
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowUp');
    await page.evaluate(() => window.__sv.flow.restart());
    await wait(900);
    for (let k = 0; k < 2; k++) {
      await page.evaluate(() => {
        const s = window.__sv.scene();
        s.player.invulnerable = 0;
        s.rules.hunger.value = 0.01;
      });
      await wait(900);
    }
    await wait(1800);
    await page.screenshot({ path: `${OUT}/m3-game-over.png` });
    console.log('top after starving:', await page.evaluate(() => window.__sv.top().constructor.name));
    console.log('records:', await page.evaluate(() => localStorage.getItem('supervillained:records')), 'coins:', await page.evaluate(() => localStorage.getItem('supervillained:coins')));
    await page.close();
  },

  /** M4: scripted "under attack" with Bagnaskiz, barking him away, a cat and a magnet ball. */
  async m4(browser) {
    const page = await openGame(browser, '?skip=game');
    // Jump past 55% of the walk → scripted attack.
    await page.evaluate(() => {
      const s = window.__sv.scene();
      const m = s.map;
      const d0 = m.exitDistance[m.index(m.startTile.i, m.startTile.j)];
      let best = null;
      for (let j = 0; j < m.height; j++)
        for (let i = 0; i < m.width; i++) {
          if (m.groundAt(i, j) !== 2) continue;
          const d = m.exitDistance[m.index(i, j)];
          const err = Math.abs(d - d0 * 0.42);
          if (!best || err < best.err) best = { i, j, err };
        }
      s.teleport(best.i + 0.5, best.j + 0.5);
    });
    await wait(900);
    await page.screenshot({ path: `${OUT}/m4-attack-title.png` });
    await wait(3500);
    await page.screenshot({ path: `${OUT}/m4-attack.png` });
    console.log('attack', JSON.stringify(await page.evaluate(() => window.__sv.scene().debugState())));
    // Bark three times at Bagnaskiz from close range.
    for (let k = 0; k < 3; k++) {
      await page.evaluate(() => {
        const s = window.__sv.scene();
        const pug = s.threats.pug;
        if (!pug) return;
        const m = s.map;
        for (const [dx, dy] of [[1.4, 0], [-1.4, 0], [0, 1.4], [0, -1.4], [1, 1], [-1, -1]]) {
          if (m.isWalkable(Math.floor(pug.gx + dx), Math.floor(pug.gy + dy))) {
            s.teleport(pug.gx + dx, pug.gy + dy);
            break;
          }
        }
        window.__sv.faceToward(pug.gx, pug.gy);
      });
      await page.keyboard.press('KeyJ');
      await wait(k === 2 ? 120 : 700);
      if (k === 2) await page.screenshot({ path: `${OUT}/m4-bark.png` });
    }
    await wait(800);
    console.log('after barks', JSON.stringify(await page.evaluate(() => window.__sv.scene().debugState().pug)));
    // Heal the zone so the attack can end, then a cat and a ball.
    await page.evaluate(() => {
      const s = window.__sv.scene();
      for (let k = 0; k < s.map.dirt.length; k++) if (s.map.dirt[k] > 0) s.map.clean((k % s.map.width) + 0.5, Math.floor(k / s.map.width) + 0.5, 0.1);
    });
    await wait(2500);
    console.log('healed', JSON.stringify(await page.evaluate(() => window.__sv.scene().debugState().attack)));
    await page.evaluate(() => {
      const s = window.__sv.scene();
      s.threats.catTimer = 0;
      s.threats.ballTimer = 0;
    });
    await wait(1200);
    await page.screenshot({ path: `${OUT}/m4-cat-ball.png` });
    console.log('spawned', JSON.stringify(await page.evaluate(() => { const d = window.__sv.scene().debugState(); return { cats: d.cats, balls: d.balls }; })));
    // Walk into the ball's magnet.
    await page.evaluate(() => {
      const s = window.__sv.scene();
      const b = s.threats.balls[0];
      if (b) s.teleport(b.gx + 2.2, b.gy + 0.2);
    });
    await wait(1500);
    console.log('ball', JSON.stringify(await page.evaluate(() => { const d = window.__sv.scene().debugState(); return { state: d.player.state, time: d.stats.time, balls: d.balls }; })));
    await page.screenshot({ path: `${OUT}/m4-fetch.png` });
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
