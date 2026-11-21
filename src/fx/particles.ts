import { Container, Sprite, type Texture } from 'pixi.js';
import { textures } from '../core/assets';
import { spriteName, type SpriteKey } from '../assets/manifest';

interface Particle {
  sprite: Sprite;
  x: number;
  y: number;
  vx: number;
  vy: number;
  gravity: number;
  drag: number;
  life: number;
  maxLife: number;
  fade: boolean;
  /** Texture frames to blink through (optional). */
  spin: number;
}

export interface BurstOptions {
  count: number;
  textures: SpriteKey[];
  colors: number[];
  speed: [number, number];
  life: [number, number];
  gravity?: number;
  drag?: number;
  /** Launch angle range in radians (screen space, 0 = right, -PI/2 = up). */
  angle?: [number, number];
  spread?: number;
  fade?: boolean;
}

/**
 * Pooled screen-space particles living in a world-space container (positions in px).
 * Cheap: plain sprites, tint, no rotation (keeps the pixel look).
 */
export class Particles {
  readonly root = new Container();
  private readonly live: Particle[] = [];
  private readonly pool: Sprite[] = [];

  burst(x: number, y: number, o: BurstOptions): void {
    for (let k = 0; k < o.count; k++) {
      const a = o.angle ? o.angle[0] + Math.random() * (o.angle[1] - o.angle[0]) : Math.random() * Math.PI * 2;
      const sp = o.speed[0] + Math.random() * (o.speed[1] - o.speed[0]);
      const tex: Texture = textures.get(spriteName(o.textures[k % o.textures.length]!));
      const sprite = this.pool.pop() ?? new Sprite();
      sprite.texture = tex;
      sprite.anchor.set(0.5);
      sprite.tint = o.colors[k % o.colors.length]!;
      sprite.alpha = 1;
      sprite.visible = true;
      this.root.addChild(sprite);
      const life = o.life[0] + Math.random() * (o.life[1] - o.life[0]);
      const spread = o.spread ?? 0;
      this.live.push({
        sprite,
        x: x + (Math.random() * 2 - 1) * spread,
        y: y + (Math.random() * 2 - 1) * spread * 0.5,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp,
        gravity: o.gravity ?? 0,
        drag: o.drag ?? 1.5,
        life,
        maxLife: life,
        fade: o.fade ?? true,
        spin: 0,
      });
    }
  }

  update(dt: number): void {
    for (let k = this.live.length - 1; k >= 0; k--) {
      const p = this.live[k]!;
      p.life -= dt;
      if (p.life <= 0) {
        p.sprite.visible = false;
        this.root.removeChild(p.sprite);
        this.pool.push(p.sprite);
        this.live.splice(k, 1);
        continue;
      }
      const d = Math.exp(-p.drag * dt);
      p.vx *= d;
      p.vy = p.vy * d + p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.sprite.position.set(Math.round(p.x), Math.round(p.y));
      if (p.fade) {
        const t = p.life / p.maxLife;
        // Pixel-style flicker at the end instead of a smooth fade.
        p.sprite.alpha = t > 0.3 ? 1 : Math.floor(p.life * 30) % 2 ? 1 : 0.2;
      }
    }
  }

  clear(): void {
    for (const p of this.live) {
      this.root.removeChild(p.sprite);
      this.pool.push(p.sprite);
    }
    this.live.length = 0;
  }
}
