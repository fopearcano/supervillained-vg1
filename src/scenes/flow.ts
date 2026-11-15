import { BlurFilter } from 'pixi.js';
import type { Game } from '../core/game';
import { addCoins, saveRecord, saveSettings } from '../core/settings';
import { LEVELS, levelByNumber } from '../levels';
import { finalHealth, starBonus, starsFromHealth, timeBonus } from '../systems/scoring';
import type { LevelDef } from '../world/level';
import { bindGameAudio } from '../fx/gameAudio';
import { GameScene } from './gameScene';
import { BriefingScene, GameOverScene, LevelEndScene, PauseScene, TitleScene, type LevelResult } from './overlays';

/**
 * Scene flow: Title → Briefing → Game ⇄ Pause → Level End / Game Over → …
 * The game scene stays at the bottom of the stack; the others are overlays on top of it.
 */
export class Flow {
  private gameScene: GameScene | null = null;
  private level: LevelDef = LEVELS[0]!;
  private readonly blur = new BlurFilter({ strength: 3, quality: 2, resolution: 1 });

  constructor(private readonly game: Game) {
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) this.autoPause();
    });
    window.addEventListener('blur', () => this.autoPause());
  }

  get current(): GameScene | null {
    return this.gameScene;
  }

  /** Title card over the (blurred, frozen) level. */
  toTitle(levelNumber = this.level.number): void {
    this.level = levelByNumber(levelNumber) ?? LEVELS[0]!;
    const scene = this.newGameScene();
    scene.active = false;
    scene.worldRoot.filters = [this.blur];
    scene.hud.root.visible = false;
    this.game.scenes.replaceAll(scene);
    scene.setControlsEnabled(false);
    scene.controls.root.visible = false;
    this.game.scenes.push(new TitleScene(this.game, this.level, () => this.toBriefing()));
    this.glitch(null, 0.7, 1);
  }

  toBriefing(): void {
    const scene = this.gameScene;
    if (!scene) return;
    this.game.audio.startMusic();
    this.glitch(() => {
      this.popOverlays();
      scene.worldRoot.filters = [];
      scene.hud.root.visible = true;
      this.game.scenes.push(new BriefingScene(this.game, () => this.startPlaying()));
    });
  }

  startPlaying(): void {
    const scene = this.gameScene;
    if (!scene) return;
    this.popOverlays();
    scene.active = true;
    scene.controls.root.visible = true;
    scene.setControlsEnabled(true);
    this.game.audio.setDuck(1);
    this.game.audio.startMusic();
  }

  /** Glitch transition with its sound. */
  private glitch(mid: (() => void) | null, duration?: number, flash?: number): void {
    this.game.audio.play('glitch');
    this.game.transition.play(mid, duration, flash);
  }

  /** Straight into gameplay (Retry / Restart / ?skip=game). */
  play(levelNumber = this.level.number): void {
    this.level = levelByNumber(levelNumber) ?? LEVELS[0]!;
    const scene = this.newGameScene();
    this.game.scenes.replaceAll(scene);
    this.startPlaying();
  }

  restart(): void {
    this.game.audio.play('click');
    this.glitch(() => this.play(this.level.number));
  }

  quitToTitle(): void {
    this.game.audio.play('click');
    this.glitch(() => this.toTitle(this.level.number));
  }

  pause(): void {
    const scene = this.gameScene;
    if (!scene || this.game.scenes.top !== scene || !scene.active || scene.rules.state !== 'playing') return;
    scene.setControlsEnabled(false);
    this.game.input.joystick.active = false;
    this.game.audio.play('click');
    this.game.audio.setDuck(0.4);
    this.game.scenes.push(
      new PauseScene(this.game, {
        resume: () => this.resume(),
        restart: () => this.restart(),
        quit: () => this.quitToTitle(),
        toggleSound: () => {
          this.game.settings.muted = !this.game.settings.muted;
          saveSettings(this.game.settings);
          this.game.onSettingsChanged();
        },
        muted: () => this.game.settings.muted,
        volume: () => this.game.settings.volume,
        cycleVolume: () => {
          const steps = [0.25, 0.5, 0.7, 1];
          const i = steps.findIndex((v) => v >= this.game.settings.volume - 0.01);
          this.game.settings.volume = steps[(i + 1) % steps.length]!;
          saveSettings(this.game.settings);
          this.game.onSettingsChanged();
          this.game.audio.play('click');
        },
      }),
    );
  }

  resume(): void {
    const scene = this.gameScene;
    if (!scene) return;
    this.popOverlays();
    scene.setControlsEnabled(true);
    this.game.audio.play('click');
    this.game.audio.setDuck(scene.threats.director.state === 'attack' ? 0.45 : 1);
  }

  /** Called when the app goes to the background. */
  autoPause(): void {
    this.pause();
  }

  private levelComplete(scene: GameScene): void {
    const st = scene.rules.stats;
    const health = finalHealth(scene.map.health(), st.pees, st.poops);
    const stars = starsFromHealth(health);
    const tb = timeBonus(st.time, this.level.parTime);
    const sb = starBonus(stars);
    const total = st.score + tb + sb;
    const newBest = saveRecord(this.level.id, { score: total, stars, time: st.time });
    const coinsTotal = addCoins(st.coins);
    const idx = LEVELS.indexOf(this.level);
    const result: LevelResult = {
      stats: st,
      health,
      stars,
      timeBonus: tb,
      starBonus: sb,
      total,
      newBest,
      coinsTotal,
      hasNext: idx >= 0 && idx < LEVELS.length - 1,
    };
    scene.setControlsEnabled(false);
    const end = new LevelEndScene(this.game, this.level, result, {
      next: () => this.glitch(() => this.toTitle(LEVELS[idx + 1]!.number)),
      retry: () => this.restart(),
      quit: () => this.quitToTitle(),
    });
    end.onStar = (k) => this.game.audio.play('star', { rate: 1 + k * 0.12 });
    this.game.scenes.push(end);
  }

  private gameOver(scene: GameScene): void {
    scene.setControlsEnabled(false);
    addCoins(scene.rules.stats.coins);
    this.game.scenes.push(
      new GameOverScene(this.game, scene.rules.stats, {
        retry: () => this.restart(),
        quit: () => this.quitToTitle(),
      }),
    );
  }

  private newGameScene(): GameScene {
    const scene = new GameScene(this.game, this.level);
    bindGameAudio(scene.events, this.game.audio);
    scene.hooks = {
      onMenu: () => this.pause(),
      onComplete: (s) => this.levelComplete(s),
      onGameOver: (s) => this.gameOver(s),
    };
    this.gameScene = scene;
    return scene;
  }

  private popOverlays(): void {
    while (this.game.scenes.top && this.game.scenes.top !== this.gameScene) this.game.scenes.pop();
  }
}
