import { Container, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import { CHARACTERS, textureName, type AnimName, type CharacterKey } from '../assets/manifest';
import type { Rect, Sortable } from '../iso/depth';
import { gridToScreen, type Dir8 } from '../iso/projection';

let nextId = 1;

/**
 * Base for everything that lives in the depth-sorted object layer.
 * Positions are in grid space; `z` lifts the sprite (jumps, bobbing items).
 */
export abstract class Entity implements Sortable {
  readonly id = nextId++;
  gx = 0;
  gy = 0;
  z = 0;
  prevX = 0;
  prevY = 0;
  prevZ = 0;
  depthBias = 0;
  alive = true;
  /** Tall objects fade out when they hide Zampanò. */
  fadeable = false;
  /** Current/target alpha for occlusion fading. */
  fade = 1;
  fadeTarget = 1;
  readonly view = new Container();
  /** Approx. sprite box relative to the anchor (for culling and occlusion), in px. */
  bounds = { x: -16, y: -32, w: 32, h: 32 };

  setPosition(gx: number, gy: number): void {
    this.gx = this.prevX = gx;
    this.gy = this.prevY = gy;
  }

  savePrev(): void {
    this.prevX = this.gx;
    this.prevY = this.gy;
    this.prevZ = this.z;
  }

  update(_dt: number): void {}

  /** Places the view at the interpolated position. */
  sync(alpha: number): void {
    const x = this.prevX + (this.gx - this.prevX) * alpha;
    const y = this.prevY + (this.gy - this.prevY) * alpha;
    const z = this.prevZ + (this.z - this.prevZ) * alpha;
    const s = gridToScreen(x, y);
    this.view.position.set(Math.round(s.x), Math.round(s.y - z));
    this.view.alpha = this.fade;
  }

  screenRect(): Rect {
    const s = gridToScreen(this.gx, this.gy);
    return { x: s.x + this.bounds.x, y: s.y - this.z + this.bounds.y, w: this.bounds.w, h: this.bounds.h };
  }

  destroy(): void {
    this.alive = false;
    this.view.destroy({ children: true });
  }
}

/** Plays a character's directional animations from the texture registry. */
export class CharacterAnimator {
  readonly sprite: Sprite;
  anim: AnimName = 'idle';
  dir: Dir8 = 'S';
  time = 0;
  /** Playback speed multiplier. */
  speed = 1;

  constructor(public key: CharacterKey) {
    this.sprite = new Sprite(textures.get(textureName(key, 'idle', 'S', 0)));
    this.sprite.roundPixels = true;
  }

  play(anim: AnimName, dir: Dir8 = this.dir, restart = false): void {
    if (!(anim in CHARACTERS[this.key].anims)) anim = 'idle';
    if (anim !== this.anim || restart) this.time = 0;
    this.anim = anim;
    this.dir = dir;
  }

  get finished(): boolean {
    const def = (CHARACTERS[this.key].anims as Record<string, { frames: number; fps: number; loop: boolean }>)[this.anim]!;
    return !def.loop && this.time * def.fps >= def.frames;
  }

  update(dt: number): void {
    this.time += dt * this.speed;
    const def = (CHARACTERS[this.key].anims as Record<string, { frames: number; fps: number; loop: boolean }>)[this.anim]!;
    let frame = Math.floor(this.time * def.fps);
    frame = def.loop ? frame % def.frames : Math.min(frame, def.frames - 1);
    this.sprite.texture = textures.get(textureName(this.key, this.anim, this.dir, frame));
  }
}
