import { Application, TextureSource } from 'pixi.js';
import { buildGlobalTextures } from './assets/build';
import { Game } from './core/game';
import { levelByNumber } from './levels';
import { GameScene } from './scenes/gameScene';
import { SpriteViewerScene } from './scenes/spriteViewerScene';
import type { CharacterKey } from './assets/manifest';
import { loadPixelFont } from './ui/pixelFont';

async function boot(): Promise<void> {
  // Pixel-perfect: every texture is sampled with nearest-neighbor.
  TextureSource.defaultOptions.scaleMode = 'nearest';
  const canvas = document.getElementById('game') as HTMLCanvasElement;
  const app = new Application();
  await app.init({
    canvas,
    width: 216,
    height: 400,
    preference: 'webgl',
    antialias: false,
    resolution: 1,
    autoDensity: false,
    background: 0x0c3a10,
    autoStart: false,
    sharedTicker: false,
    roundPixels: true,
    powerPreference: 'high-performance',
    eventFeatures: { move: false, globalMove: false, click: false, wheel: false },
  });
  app.ticker?.stop();
  await loadPixelFont();
  await buildGlobalTextures();
  const game = new Game(app, canvas);
  document.getElementById('boot')?.remove();

  const params = new URLSearchParams(location.search);
  const level = levelByNumber(Number(params.get('level') ?? 1)) ?? levelByNumber(1)!;
  if (params.get('debug') === 'sprites') {
    game.start(new SpriteViewerScene(game, (params.get('char') ?? 'zampano') as CharacterKey));
  } else {
    game.start(new GameScene(game, level));
  }

  // Debug/automation hook (used by the Playwright screenshot script).
  (window as unknown as { __sv: unknown }).__sv = {
    game,
    scene: () => game.scenes.top,
    step: (n: number) => game.loop.stepNow(n),
  };
}

boot().catch((err) => {
  console.error(err);
  const el = document.getElementById('boot');
  if (el) el.textContent = `ERROR: ${err instanceof Error ? err.message : String(err)}`;
});
