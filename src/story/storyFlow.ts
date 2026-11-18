import { CHAPTERS } from '../campaign/chapters';
import { applyEffects, ending, endingNotes, isComplete, loadCampaign, markComplete, resetCampaign, saveCampaign, type CampaignState } from '../campaign/state';
import type { ChapterDef, SubLevelDef } from '../campaign/types';
import type { Game } from '../core/game';
import { saveSettings, TEXT_SPEEDS } from '../core/settings';
import { C } from '../ui/retro';
import { BookScene, StoryCardScene, StoryChapterScene, StoryMenuScene, StoryPauseScene } from './screens';
import { Autopilot, type PilotPolicy } from './autopilot';
import { StoryScene } from './storyScene';
import { withNames } from './names';
import { SupervillainedScene } from '../scenes/supervillainedScene';

/**
 * Story flow: menu → level card → sub-level card → sub-level → … → the Professor's aside →
 * next level → … → the ending. Progress is saved after every sub-level.
 */
export interface PlaytestEntry {
  id: string;
  time: number;
  metrics: StoryScene['metrics'] | null;
  meters: CampaignState['meters'];
  skipped?: boolean;
  ending?: string;
  /** The Green Zone walk: not played by the autopilot (the screenshot scenarios cover it). */
  greenZone?: boolean;
}

export class StoryFlow {
  state: CampaignState = loadCampaign();
  /** Automated playtest: when set, every sub-level is played by an Autopilot and they chain without cards. */
  autopilot: PilotPolicy | null = null;
  /** One entry per finished sub-level while the autopilot is on. */
  readonly log: PlaytestEntry[] = [];
  /** Replaying a finished sub-level: it plays on a copy of the campaign and nothing is saved. */
  private replaying = false;

  constructor(
    private readonly game: Game,
    private readonly backToTitle: () => void,
    /** Plays the Green Zone walk (1.0) and calls `done` when he reaches the exit. */
    private readonly playGreenZone: (level: number, done: () => void) => void,
  ) {}

  /** A saved story to continue (at least one sub-level finished). */
  hasProgress(): boolean {
    return loadCampaign().completed.length > 0;
  }

  /** Where Continue goes ("LEVEL 3: 3.2 THE PRICE OF PASSAGE"), or null when all is done. */
  nextLabel(): string | null {
    const st = loadCampaign();
    for (const ch of CHAPTERS) for (const sub of ch.subLevels) if (!isComplete(st, sub.id)) return `LEVEL ${ch.number}: ${sub.id} ${sub.title.toUpperCase()}`;
    return null;
  }

  /** New game: a fresh campaign from the Green Zone walk. */
  newGame(): void {
    this.replaying = false;
    this.state = resetCampaign();
    const ch = CHAPTERS[0]!;
    this.showSub(ch, ch.subLevels[0]!, true);
  }

  /** Continue: the next unfinished sub-level (the level select once everything is done). */
  continueGame(): void {
    this.replaying = false;
    this.state = loadCampaign();
    if (this.nextLabel() === null) return this.openMenu();
    this.continueStory();
  }

  /** Coins picked up on the Green Zone walk go to the story's purse. */
  /** The Green Zone walk (1.0) is over: its coins go to the story's purse, its time to the play time. */
  addWalk(coins: number, seconds: number): void {
    if (this.replaying) return;
    if (coins) applyEffects(this.state, { coins });
    this.state.playTime += Math.max(0, seconds);
    saveCampaign(this.state);
  }

  get active(): StoryScene | null {
    const top = this.game.scenes.top;
    return top instanceof StoryScene ? top : null;
  }

  private glitch(mid: () => void): void {
    this.game.audio.play('glitch');
    this.game.transition.play(mid, 0.5, 0.6);
  }

  openMenu(): void {
    this.replaying = false;
    this.state = loadCampaign();
    this.game.audio.setTrack('intro');
    this.game.audio.setDuck(1);
    this.game.audio.startMusic();
    this.game.scenes.replaceAll(
      new StoryMenuScene(this.game, this.state, CHAPTERS, {
        play: (ch) => this.glitch(() => this.openChapter(ch)),
        cont: () => this.glitch(() => this.continueStory()),
        book: () => this.openBook(),
        back: () => this.backToTitle(),
        unlocked: (ch) => this.unlocked(ch),
      }),
    );
  }

  /** Level 1 is always open; a later level opens when the previous one is complete. */
  unlocked(ch: ChapterDef): boolean {
    if (ch.number === 1) return true;
    const prev = CHAPTERS.find((c) => c.number === ch.number - 1);
    return !!prev && prev.subLevels.every((s) => isComplete(this.state, s.id));
  }

  private continueStory(): void {
    for (const ch of CHAPTERS) {
      for (const sub of ch.subLevels) {
        if (!isComplete(this.state, sub.id)) return this.showSub(ch, sub, ch.subLevels[0] === sub);
      }
    }
    this.showEnding();
  }

  /** The level's sub-level list (replays and the next scene). */
  private openChapter(ch: ChapterDef): void {
    this.replaying = false;
    this.game.scenes.replaceAll(
      new StoryChapterScene(this.game, this.state, ch, {
        play: (sub) =>
          this.glitch(() => {
            this.replaying = isComplete(this.state, sub.id);
            this.showSub(ch, sub, !this.replaying && ch.subLevels[0] === sub);
          }),
        back: () => this.glitch(() => this.openMenu()),
      }),
    );
  }

  /** Intro music while the player reads the cards; the level's own music plays in the scene. */
  private reading(): void {
    this.game.audio.setTrack('intro');
    this.game.audio.setDuck(1);
    this.game.audio.startMusic();
  }

  private showSub(ch: ChapterDef, sub: SubLevelDef, withChapterCard: boolean): void {
    if (this.autopilot) return this.startSub(ch, sub);
    this.reading();
    const start = () => this.glitch(() => this.startSub(ch, sub));
    const replayNote = this.replaying ? [{ text: 'REPLAY: THE CAMPAIGN WILL NOT CHANGE', color: C.cyan }] : [];
    // The Green Zone walk (1.0): one page, the level and what the walk is.
    if (sub.greenZone) {
      this.game.scenes.replaceAll(
        new StoryCardScene(
          this.game,
          0x140a24,
          [
            { text: `LEVEL ${ch.number}`, color: C.hotPink, scale: 3, gap: 6 },
            { text: ch.title, color: C.green, scale: 2, gap: 16 },
            { text: withNames(sub.happens, C.white), color: C.white, gap: 12 },
            ...replayNote,
          ],
          start,
        ),
      );
      return;
    }
    const subCard = () =>
      this.game.scenes.replaceAll(
        new StoryCardScene(
          this.game,
          sub.blackHole ? 0x12062a : 0x0a0a14,
          [
            { text: sub.blackHole ? 'BLACK HOLE' : `LEVEL ${ch.number}`, color: sub.blackHole ? '#b070ff' : '#9aa4c0' },
            { text: `${sub.id} ${sub.title.toUpperCase()}`, color: C.yellow, scale: 1, gap: 14 },
            { text: withNames(sub.happens, C.white), color: C.white, gap: 14 },
            { text: `SOURCE: ${sub.source}`, color: '#7a84a0', gap: this.replaying ? 12 : 8 },
            ...replayNote,
          ],
          start,
        ),
      );
    if (!withChapterCard) return subCard();
    // The level card (the cast list in the chapter data is design information, not shown).
    this.game.scenes.replaceAll(
      new StoryCardScene(
        this.game,
        0x140a24,
        [
          { text: `LEVEL ${ch.number}`, color: C.hotPink, scale: 3, gap: 6 },
          { text: ch.title, color: C.green, scale: 2, gap: 16 },
          { text: withNames(ch.intro, C.white), color: C.white },
        ],
        () => this.glitch(subCard),
      ),
    );
  }

  private startSub(ch: ChapterDef, sub: SubLevelDef, restart = false): void {
    if (sub.greenZone) {
      // The Green Zone walk is played by the walk's own scenes; the autopilot does not play it.
      if (this.autopilot) {
        this.log.push({ id: sub.id, time: 0, metrics: null, meters: { ...this.state.meters }, greenZone: true });
        return this.finishSub(ch, sub, false, true);
      }
      return this.playGreenZone(sub.greenZone, () => this.finishSub(ch, sub));
    }
    this.game.audio.setTrack(ch.music);
    this.game.audio.setDuck(1);
    this.game.audio.startMusic();
    const scene = new StoryScene(this.game, this.replaying ? structuredClone(this.state) : this.state, ch, sub, {
      onFinished: () => this.finishSub(ch, sub),
      onMenu: () => this.pause(ch, sub),
    });
    scene.persist = !this.replaying;
    scene.fade = !restart;
    if (this.autopilot) scene.pilot = new Autopilot({ ...this.autopilot, seed: (this.autopilot.seed ?? 1) + this.log.length });
    this.game.scenes.replaceAll(scene);
  }

  private finishSub(ch: ChapterDef, sub: SubLevelDef, skipped = false, logged = false): void {
    if (this.replaying) {
      this.replaying = false;
      return this.glitch(() => this.openChapter(ch));
    }
    if (this.autopilot && !logged) {
      const s = this.active;
      this.log.push({ id: sub.id, time: s?.time ?? 0, metrics: s ? structuredClone(s.metrics) : null, meters: { ...this.state.meters }, skipped });
    }
    markComplete(this.state, sub.id);
    saveCampaign(this.state);
    const idx = ch.subLevels.indexOf(sub);
    const nextSub = ch.subLevels[idx + 1];
    if (nextSub) return this.glitch(() => this.showSub(ch, nextSub, false));
    if (this.autopilot) {
      const nextCh = CHAPTERS.find((c) => c.number === ch.number + 1);
      return this.glitch(() => (nextCh ? this.showSub(nextCh, nextCh.subLevels[0]!, true) : this.showEnding()));
    }
    // End of the level: "You've been supervillained" snaps in, then the Professor's aside.
    this.reading();
    this.supervillained(() =>
      this.game.scenes.replaceAll(
        new StoryCardScene(
          this.game,
          0x1a1206,
          [
            { text: '', portrait: true, gap: 10 },
            { text: ch.professor.after ? `THE PROFESSOR (AFTER ${ch.professor.after})` : 'THE PROFESSOR', color: '#f0d8a0', gap: 12 },
            { text: withNames(ch.professor.text, C.white), color: C.white, align: 'justify' },
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

  /**
   * The end of a level: the "You've been supervillained" logo over the frozen last scene (menus
   * opened over it are closed first), then a glitch into `next`.
   */
  private supervillained(next: () => void): void {
    const scenes = this.game.scenes;
    while (scenes.all.length > 1 && !(scenes.top instanceof StoryScene)) scenes.pop();
    scenes.push(new SupervillainedScene(this.game, () => this.glitch(next)));
  }

  private showEnding(): void {
    this.reading();
    const e = ending(this.state);
    if (this.autopilot) this.log.push({ id: 'ending', time: 0, metrics: null, meters: { ...this.state.meters }, ending: e });
    const lines =
      e === 'knight'
        ? 'IN A LULL IN THE LOOTING HE CALLED THE PILGRIMS TO THEIR OATH, IN HIS OWN WORDS, AND AT THE DESK HE READ THEM BACK IN HIS OWN VOICE. ON THE LAWN BAGNASKIZ STEPPED ASIDE AND THE LANE STAYED OPEN. ZAMPANO DID NOT CHANGE: HE FOUND OUT HE WAS A KNIGHT ALL ALONG, AND TOO THICK-HEADED TO BE STOPPED.'
        : 'HE STOOD SILENT WHILE NIKETAS CALLED THE PILGRIMS TO THEIR OATH. AT THE DESK HE READ THE LINE IN ITS OWNER\'S VOICE AND SAID SO. ON THE LAWN BAGNASKIZ STEPPED ASIDE ANYWAY, AND THE LANE STAYED OPEN. THE GIRL IS WITH HER FAMILY EITHER WAY; WHAT DIFFERS IS THE STORY HE CAN HONESTLY TELL.';
    this.game.scenes.replaceAll(
      new StoryCardScene(
        this.game,
        0x000000,
        [
          { text: e === 'knight' ? 'THE KNIGHT' : 'THE WITNESS', color: e === 'knight' ? C.cyan : '#c8a0ff', scale: 2, gap: 14 },
          { text: withNames(lines, C.white), color: C.white, align: 'justify', gap: 10 },
          { text: withNames(endingNotes(this.state).join(' '), '#c8c0e0'), color: '#c8c0e0', align: 'justify', gap: 14 },
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
        restart: () => this.glitch(() => this.startSub(ch, sub, true)),
        skip: () => this.glitch(() => this.finishSub(ch, sub)),
        book: () => this.game.scenes.push(new BookScene(this.game, this.state, () => this.game.scenes.pop())),
        sound: () => {
          this.game.settings.muted = !this.game.settings.muted;
          saveSettings(this.game.settings);
          this.game.onSettingsChanged();
        },
        muted: () => this.game.settings.muted,
        textSpeed: () => {
          const s = this.game.settings;
          s.textSpeed = TEXT_SPEEDS[(TEXT_SPEEDS.indexOf(s.textSpeed) + 1) % TEXT_SPEEDS.length]!;
          saveSettings(s);
        },
        textSpeedLabel: () => this.game.settings.textSpeed.toUpperCase(),
        menu: () => this.backToTitle(),
      }),
    );
  }

  private openBook(): void {
    this.game.scenes.push(new BookScene(this.game, this.state, () => this.game.scenes.pop()));
  }

  /** Automation: give up on the running sub-level (counted as skipped) and move on. */
  debugSkipCurrent(): void {
    const s = this.active;
    if (s) this.finishSub(s.chapter, s.sub, true);
  }

  /** Automation: a fresh campaign. */
  debugReset(): void {
    this.state = resetCampaign();
    this.log.length = 0;
  }

  /** Debug / automation: `?story=3.2` jumps straight into a sub-level. */
  debugPlay(id: string): void {
    for (const ch of CHAPTERS) {
      const sub = ch.subLevels.find((s) => s.id === id);
      if (!sub) continue;
      this.game.audio.setTrack(ch.music);
      this.game.audio.startMusic();
      return this.startSub(ch, sub);
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
