import type { Behavior, Point } from '../../entities/actor';
import type { StoryScene } from '../../story/storyScene';

/** Small helpers shared by the chapter scripts. */

export function at(ctx: StoryScene, ...markers: string[]): Point[] {
  return markers.map((m) => ctx.marker(m));
}

export function patrol(ctx: StoryScene, markers: string[], speed = 1.4, pause = 0.8): Behavior {
  return { kind: 'patrol', points: at(ctx, ...markers), speed, pause };
}

export function wander(ctx: StoryScene, center: string, radius: number, speed = 1): Behavior {
  return { kind: 'wander', center: ctx.marker(center), radius, speed };
}

export function near(ctx: StoryScene, name: string, radius: number): boolean {
  const a = ctx.actors.get(name);
  if (!a) return false;
  return Math.hypot(a.gx - ctx.player.gx, a.gy - ctx.player.gy) <= radius;
}

/** Zampanò's bark (sound, animation, popup). */
export function bark(ctx: StoryScene, text = 'WOOF!'): void {
  ctx.player.startAction('bark', 0.3);
  ctx.game.audio.play('bark');
  ctx.say(text, { x: ctx.player.gx, y: ctx.player.gy });
}
