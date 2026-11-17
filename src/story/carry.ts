import { Entity } from '../entities/entity';
import { PixelText } from '../ui/pixelText';
import { call } from './steps';
import type { Step } from './step';
import type { StoryScene } from './storyScene';

/**
 * Something Zampanò carries from one place to another (the scrap of red cloth, the collecting
 * bowl, a message, the rolled sail, a crate of biscuit): a label that rides above his head.
 */
class Carried extends Entity {
  constructor(
    private readonly ctx: StoryScene,
    text: string,
  ) {
    super();
    const label = new PixelText(text, { color: '#ffe23a', outline: '#120818', align: 'center' }).setOrigin(0.5, 1);
    label.y = -34;
    this.view.addChild(label);
    this.depthBias = 0.6;
    const p = ctx.player;
    this.setPosition(p.gx, p.gy);
  }

  override update(): void {
    this.gx = this.ctx.player.gx;
    this.gy = this.ctx.player.gy;
  }
}

const carried = new WeakMap<StoryScene, Carried>();

function drop(ctx: StoryScene): void {
  const c = carried.get(ctx);
  carried.delete(ctx);
  if (c && ctx.world?.entities.includes(c)) ctx.world.removeEntity(c);
}

/** He picks it up: the label shows above him until `dropCarried()` (or the stage changes). */
export function carry(text: string): Step {
  return call((ctx) => {
    drop(ctx);
    if (!ctx.world) return;
    const c = new Carried(ctx, `[${text}]`);
    ctx.world.addEntity(c);
    carried.set(ctx, c);
  });
}

export function dropCarried(): Step {
  return call((ctx) => drop(ctx));
}
