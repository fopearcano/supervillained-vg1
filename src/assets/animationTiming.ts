import type { AnimDef } from './manifest';

export function animationDuration(def: AnimDef): number {
  return def.frames / def.fps;
}

/** Frame for an elapsed time in seconds. The sprite viewer can loop one-shots for inspection. */
export function animationFrame(def: AnimDef, seconds: number, loop = def.loop): number {
  const holds = def.frameDurationsMs;
  if (!holds) {
    const frame = Math.floor(seconds * def.fps);
    return loop ? frame % def.frames : Math.min(frame, def.frames - 1);
  }

  const elapsedMs = seconds * 1000;
  let elapsed = loop ? elapsedMs % (animationDuration(def) * 1000) : elapsedMs;
  for (let frame = 0; frame < def.frames - 1; frame++) {
    const hold = holds[frame]!;
    if (elapsed < hold) return frame;
    elapsed -= hold;
  }
  return def.frames - 1;
}
