import { LOOP } from '../config';

/**
 * Fixed-timestep accumulator. Pure (no DOM) so it can be unit-tested.
 * Returns how many logic steps to run for a frame and the interpolation alpha for rendering.
 */
export class FixedStep {
  private acc = 0;

  constructor(
    readonly step: number = LOOP.STEP,
    readonly maxFrame: number = LOOP.MAX_FRAME,
    readonly maxSteps: number = LOOP.MAX_STEPS,
  ) {}

  advance(elapsedSeconds: number): { steps: number; alpha: number } {
    this.acc += Math.min(Math.max(elapsedSeconds, 0), this.maxFrame);
    let steps = 0;
    while (this.acc >= this.step && steps < this.maxSteps) {
      this.acc -= this.step;
      steps++;
    }
    // Drop the backlog if we are too far behind (prevents the spiral of death).
    if (steps === this.maxSteps && this.acc >= this.step) this.acc = 0;
    return { steps, alpha: this.acc / this.step };
  }

  reset(): void {
    this.acc = 0;
  }
}

/** requestAnimationFrame driver around FixedStep. */
export class GameLoop {
  private readonly fixed = new FixedStep();
  private last = 0;
  private raf = 0;
  private running = false;

  constructor(
    private readonly update: (dt: number) => void,
    private readonly render: (alpha: number, frameDt: number) => void,
  ) {}

  start(): void {
    if (this.running) return;
    this.running = true;
    this.last = performance.now();
    this.fixed.reset();
    const frame = (now: number) => {
      if (!this.running) return;
      const elapsed = (now - this.last) / 1000;
      this.last = now;
      const { steps, alpha } = this.fixed.advance(elapsed);
      for (let k = 0; k < steps; k++) this.update(this.fixed.step);
      this.render(alpha, Math.min(Math.max(elapsed, 0), LOOP.MAX_FRAME));
      this.raf = requestAnimationFrame(frame);
    };
    this.raf = requestAnimationFrame(frame);
  }

  stop(): void {
    this.running = false;
    cancelAnimationFrame(this.raf);
  }

  /** Runs `n` logic steps synchronously (used by automated tests/screenshots). */
  stepNow(n: number): void {
    for (let k = 0; k < n; k++) this.update(this.fixed.step);
    this.render(1, this.fixed.step);
  }
}
