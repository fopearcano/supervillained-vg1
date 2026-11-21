import { Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import { spriteName } from '../assets/manifest';
import { POOP } from '../config';
import type { PoopSurface } from '../world/tiles';
import type { GameMap } from '../world/map';
import { Entity } from './entity';

/** A bone floating above the ground. */
export class Treat extends Entity {
  private t = Math.random() * 6;
  readonly sprite: Sprite;

  constructor(gx: number, gy: number) {
    super();
    const shadow = new Sprite(textures.get(spriteName('shadowSmall')));
    this.sprite = new Sprite(textures.get(spriteName('treat')));
    this.view.addChild(shadow, this.sprite);
    this.setPosition(gx, gy);
    this.bounds = { x: -7, y: -14, w: 14, h: 16 };
  }

  override update(dt: number): void {
    this.t += dt;
    this.sprite.y = -4 - Math.round((Math.sin(this.t * 3.2) + 1) * 1.5);
  }
}

/**
 * A poop pile. Its pollution stain slowly spreads until a pee neutralizes it.
 */
export class PoopPile extends Entity {
  readonly sprite: Sprite;
  readonly baseRadius: number;
  readonly strength: number;
  age = 0;
  radius: number;
  cleaned = false;
  private tick = 0;
  private fadeOut = 0;

  constructor(
    gx: number,
    gy: number,
    readonly surface: PoopSurface,
    footprint: { radius: number; strength: number },
  ) {
    super();
    this.sprite = new Sprite(textures.get(spriteName('poop')));
    this.view.addChild(this.sprite);
    this.setPosition(gx, gy);
    this.depthBias = -0.3;
    this.baseRadius = footprint.radius;
    this.strength = footprint.strength;
    this.radius = footprint.radius;
    this.bounds = { x: -5, y: -9, w: 10, h: 10 };
    // Hidden in bushes / tall grass.
    if (surface === 'low') this.sprite.alpha = 0.75;
  }

  /** Spreads pollution over time. Returns true while the entity should stay alive. */
  step(dt: number, map: GameMap): boolean {
    if (this.cleaned) {
      this.fadeOut += dt;
      this.sprite.alpha = Math.max(0, 1 - this.fadeOut * 2.5);
      this.sprite.scale.set(1 + this.fadeOut * 0.6);
      return this.fadeOut < 0.4;
    }
    this.age += dt;
    this.tick += dt;
    if (this.tick >= POOP.GROW_TICK) {
      this.tick = 0;
      const g = Math.min(1, this.age / POOP.GROW_TIME);
      this.radius = this.baseRadius * (1 + (POOP.GROW_FACTOR - 1) * g);
      map.stampDirt(this.gx, this.gy, this.radius, this.strength);
    }
    return true;
  }
}
