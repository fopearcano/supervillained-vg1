import { CHAPTERS } from '../campaign/chapters';
import { shardName } from '../campaign/titles';
import { ending, isComplete, loadCampaign, markComplete, resetCampaign, saveCampaign, type CampaignState } from '../campaign/state';
import type { ChapterDef, SubLevelDef } from '../campaign/types';
import type { Game } from '../core/game';
import { saveSettings } from '../core/settings';
import { C } from '../ui/retro';
import { BookScene, StoryCardScene, StoryMenuScene, StoryPauseScene } from './screens';
import { StoryScene } from './storyScene';

/**
 * Story flow: menu → level card → sub-level card → sub-level → … → the Professor's aside →
 * next level → … → the ending. Progress is saved after every sub-level.
 */
export class StoryFlow {
  state: CampaignState = loadCampaign();

  constructor(
    private readonly game: Game,
    private readonly backToTitle: () => void,
  ) {}

  get active(): StoryScene | null {
    const top = this.game.scenes.top;
    return top instanceof StoryScene ? top : null;
  }

  private glitch(mid: () => void): void {
    this.game.audio.play('glitch');
    this.game.transition.play(mid, 0.5, 0.6);
  }

  openMenu(): void {
    this.state = loadCampaign();
    this.game.audio.setTrack('medieval');
    this.game.audio.startMusic();
    this.game.scenes.replaceAll(
      new StoryMenuScene(this.game, this.state, CHAPTERS, {
        play: (ch) => this.glitch(() => this.playChapter(ch)),
        cont: () => this.glitch(() => this.continueStory()),
        book: () => this.openBook(),
        reset: () => {
          this.state = resetCampaign();
          this.openMenu();
        },
        back: () => this.backToTitle(),
        unlocked: (ch) => this.unlocked(ch),
      }),
    );
  }

  /**
   * Level 1 is always open. A later level opens when the previous one is complete, or when its
   * memory shard was picked up in the Professor's study (1.2: "each one unlocks a later sub-level").
   */
  unlocked(ch: ChapterDef): boolean {
    if (ch.number === 1) return true;
    const prev = CHAPTERS.find((c) => c.number === ch.number - 1);
    if (prev && prev.subLevels.every((s) => isComplete(this.state, s.id))) return true;
    return this.state.book.shards.includes(shardName(ch.number)) && isComplete(this.state, '1.2');
  }

  private continueStory(): void {
    for (const ch of CHAPTERS) {
      for (const sub of ch.subLevels) {
        if (!isComplete(this.state, sub.id)) return this.showSub(ch, sub, ch.subLevels[0] === sub);
      }
    }
    this.showEnding();
  }

  private playChapter(ch: ChapterDef): void {
    const sub = ch.subLevels.find((s) => !isComplete(this.state, s.id)) ?? ch.subLevels[0]!;
    this.showSub(ch, sub, true);
  }

  private showSub(ch: ChapterDef, sub: SubLevelDef, withChapterCard: boolean): void {
    this.game.audio.setTrack(ch.music);
    this.game.audio.startMusic();
    const subCard = () =>
      this.game.scenes.replaceAll(
        new StoryCardScene(
          this.game,
          sub.blackHole ? 0x12062a : 0x0a0a14,
          [
            { text: sub.blackHole ? 'BLACK HOLE' : `LEVEL ${ch.number}`, color: sub.blackHole ? '#b070ff' : '#9aa4c0' },
            { text: `${sub.id} ${sub.title.toUpperCase()}`, color: C.yellow, scale: 1, gap: 14 },
            { text: sub.happens, color: C.white, gap: 14 },
            { text: `SOURCE: ${sub.source}`, color: '#7a84a0' },
          ],
          () => this.glitch(() => this.startSub(ch, sub)),
        ),
      );
    if (!withChapterCard) return subCard();
    this.game.scenes.replaceAll(
      new StoryCardScene(
        this.game,
        0x140a24,
        [
          { text: `LEVEL ${ch.number}`, color: C.hotPink, scale: 3, gap: 6 },
          { text: ch.title, color: C.green, scale: 2, gap: 16 },
          { text: ch.intro, color: C.white, gap: 12 },
          { text: `CAST: ${ch.cast}`, color: C.cyan },
        ],
        () => this.glitch(subCard),
      ),
    );
  }

  private startSub(ch: ChapterDef, sub: SubLevelDef): void {
    const scene = new StoryScene(this.game, this.state, ch, sub, {
      onFinished: () => this.finishSub(ch, sub),
      onMenu: () => this.pause(ch, sub),
    });
    this.game.scenes.replaceAll(scene);
  }

  private finishSub(ch: ChapterDef, sub: SubLevelDef): void {
    markComplete(this.state, sub.id);
    saveCampaign(this.state);
    const idx = ch.subLevels.indexOf(sub);
    const nextSub = ch.subLevels[idx + 1];
    if (nextSub) return this.glitch(() => this.showSub(ch, nextSub, false));
    // End of the level: the Professor's aside.
    this.glitch(() =>
      this.game.scenes.replaceAll(
        new StoryCardScene(
          this.game,
          0x1a1206,
          [
            { text: '', portrait: true, gap: 10 },
            { text: ch.professor.after ? `THE PROFESSOR (AFTER ${ch.professor.after})` : 'THE PROFESSOR', color: '#f0d8a0', gap: 12 },
            { text: ch.professor.text, color: C.white, align: 'justify' },
          ],
          () => {
            const nextCh = CHAPTERS.find((c) => c.number === ch.number + 1);
            if (nextCh) this.glitch(() => this.showSub(nextCh, nextCh.subLevels[0]!, true));
            else this.glitch(() => this.showEnding());
          },
        ),
      ),
    );
  }

  private showEnding(): void {
    const e = ending(this.state);
    const lines =
      e === 'knight'
        ? 'HE KEPT THE OATH AT THE SACK. ON THE LAWN, BAGNASKIZ TURNED; HE ENDS IN THE REST HOME. ZAMPANO DID NOT CHANGE: HE FOUND OUT HE WAS A KNIGHT ALL ALONG, AND TOO THICK-HEADED TO BE STOPPED.'
        : 'HE LOOKED AWAY AT THE SACK. ON THE LAWN, BAGNASKIZ STEPPED ASIDE AND SMILED: THE ALPHA-DOG OFFER IS STILL ON THE TABLE. ZAMPANO WALKED ON ANYWAY, TOO THICK-HEADED TO BE STOPPED.';
    this.game.scenes.replaceAll(
      new StoryCardScene(
        this.game,
        0x000000,
        [
          { text: e === 'knight' ? 'THE KNIGHT' : 'THE ALPHA-DOG', color: e === 'knight' ? C.cyan : C.orange, scale: 2, gap: 14 },
          { text: lines, color: C.white, align: 'justify', gap: 16 },
          { text: `VALUES: ${this.state.book.values.length}  MARVELS: ${this.state.book.marvels.length}`, color: C.yellow, gap: 6 },
          { text: `SUPERVILLAIN ${this.state.meters.supervillain}  GRACE ${this.state.meters.grace}`, color: C.pink, gap: 16 },
          { text: 'THE END', color: C.green, scale: 2 },
        ],
        () => this.glitch(() => this.openMenu()),
      ),
    );
  }

  private pause(ch: ChapterDef, sub: SubLevelDef): void {
    const scene = this.active;
    if (!scene) return;
    scene.suspendControls();
    this.game.audio.play('click');
    this.game.audio.setDuck(0.4);
    const resume = () => {
      while (this.game.scenes.top !== scene && this.game.scenes.top) this.game.scenes.pop();
      this.game.audio.setDuck(1);
      scene.resumeAfterPause();
    };
    this.game.scenes.push(
      new StoryPauseScene(this.game, {
        resume,
        restart: () => this.glitch(() => this.startSub(ch, sub)),
        skip: () => this.glitch(() => this.finishSub(ch, sub)),
        book: () => this.game.scenes.push(new BookScene(this.game, this.state, () => this.game.scenes.pop())),
        sound: () => {
          this.game.settings.muted = !this.game.settings.muted;
          saveSettings(this.game.settings);
          this.game.onSettingsChanged();
        },
        muted: () => this.game.settings.muted,
        menu: () => this.glitch(() => this.openMenu()),
      }),
    );
  }

  private openBook(): void {
    this.game.scenes.push(new BookScene(this.game, this.state, () => this.game.scenes.pop()));
  }

  /** Debug / automation: `?story=3.2` jumps straight into a sub-level. */
  debugPlay(id: string): void {
    this.game.audio.setTrack('medieval');
    for (const ch of CHAPTERS) {
      const sub = ch.subLevels.find((s) => s.id === id);
      if (sub) return this.startSub(ch, sub);
    }
    this.openMenu();
  }

  /** Android back / app hidden: pause a running sub-level. */
  back(): boolean {
    const top = this.game.scenes.top;
    if (top instanceof StoryPauseScene || top instanceof BookScene) {
      this.game.scenes.pop();
      const s = this.active;
      if (s) {
        this.game.audio.setDuck(1);
        s.resumeAfterPause();
      }
      return true;
    }
    const s = this.active;
    if (s) {
      s.requestMenu();
      return true;
    }
    return top instanceof StoryCardScene || top instanceof StoryMenuScene;
  }
}
