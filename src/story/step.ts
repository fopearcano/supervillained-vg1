import type { Autopilot } from './autopilot';
import type { StoryScene } from './storyScene';

export type StepStatus = 'running' | 'done';

/**
 * One beat of a sub-level script: a dialogue line, a choice, a card, a walk objective, a
 * mini-game... Steps run one after another inside a StoryScene.
 */
export interface Step {
  start(ctx: StoryScene): void;
  update(dt: number, ctx: StoryScene): StepStatus;
  /** Called when the step ends (or the scene is torn down while it runs). */
  stop?(ctx: StoryScene): void;
  /** Called when the step resumes after an interruption (see StoryScene.interrupt). */
  resume?(ctx: StoryScene): void;
  /** Automated playtests: play this step through the inputs (see story/autopilot.ts). */
  pilot?(dt: number, ctx: StoryScene, p: Autopilot): void;
}

/** Wraps a suspended step so it continues after the interrupting steps. */
export class ResumeStep implements Step {
  constructor(private readonly inner: Step) {}
  start(ctx: StoryScene): void {
    if (this.inner.resume) this.inner.resume(ctx);
  }
  update(dt: number, ctx: StoryScene): StepStatus {
    return this.inner.update(dt, ctx);
  }
  stop(ctx: StoryScene): void {
    this.inner.stop?.(ctx);
  }
  pilot(dt: number, ctx: StoryScene, p: Autopilot): void {
    this.inner.pilot?.(dt, ctx, p);
  }
}
