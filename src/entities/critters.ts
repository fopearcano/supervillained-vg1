import { Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import { spriteName } from '../assets/manifest';
import { BAGNASKIZ, BALL, CAT } from '../config';
import { dirFromGridVector } from '../iso/projection';
import { fleeDirection } from '../systems/threatLogic';
import type { GameMap } from '../world/map';
import { CharacterAnimator, Entity } from './entity';

/** A cat: sits until Zampanò gets close, then flees around obstacles. Touch it for coins. */
export class Cat extends Entity {
  readonly animator = new CharacterAnimator('cat');
  state: 'idle' | 'flee' | 'startled' | 'leave' = 'idle';
  age = 0;
  private dir = { x: 0, y: 0 };
  private think = 0;
  private stateTime = 0;
  caught = false;

  constructor(gx: number, gy: number, variantTint: number) {
    super();
    const shadow = new Sprite(textures.get(spriteName('shadowSmall')));
    this.view.addChild(shadow, this.animator.sprite);
    this.animator.sprite.tint = variantTint;
    this.setPosition(gx, gy);
    this.bounds = { x: -12, y: -24, w: 24, h: 26 };
  }

  startle(): void {
    if (this.state === 'leave') return;
    this.state = 'startled';
    this.stateTime = 0;
  }

  step(dt: number, map: GameMap, px: number, py: number): boolean {
    this.age += dt;
    this.stateTime += dt;
    const d = Math.hypot(px - this.gx, py - this.gy);
    if (this.state !== 'leave' && this.age > CAT.LIFETIME) {
      this.state = 'leave';
      this.stateTime = 0;
    }
    let speed = 0;
    if (this.state === 'idle') {
      if (d < CAT.ALERT_DISTANCE) this.state = 'flee';
    } else if (this.state === 'startled') {
      if (this.stateTime > 0.8) this.state = 'flee';
    } else {
      this.think -= dt;
      if (this.think <= 0) {
        this.think = CAT.THINK_INTERVAL;
        this.dir = fleeDirection(map, this.gx, this.gy, px, py, this.dir, CAT.RADIUS, Math.random);
      }
      // Relax when far away.
      speed = this.state === 'leave' ? CAT.SPEED : d < CAT.ALERT_DISTANCE * 1.4 ? CAT.SPEED : CAT.SPEED * 0.4;
    }
    if (speed > 0 && (this.dir.x || this.dir.y)) {
      const r = map.moveCircle(this.gx, this.gy, this.dir.x * speed * dt, this.dir.y * speed * dt, CAT.RADIUS);
      this.gx = r.x;
      this.gy = r.y;
      this.animator.play(speed > CAT.SPEED * 0.6 ? 'run' : 'walk', dirFromGridVector(this.dir.x, this.dir.y, this.animator.dir));
    } else {
      this.animator.play('idle', this.state === 'idle' ? dirFromGridVector(px - this.gx, py - this.gy) : this.animator.dir);
    }
    this.animator.update(dt);
    // Startled: little hop.
    this.z = this.state === 'startled' ? Math.max(0, Math.sin(Math.min(1, this.stateTime / 0.3) * Math.PI) * 5) : 0;
    if (this.state === 'leave') {
      this.fade = Math.max(0, 1 - this.stateTime / 1.2);
      return this.stateTime < 1.2;
    }
    return true;
  }
}

/** A tennis ball: pulls Zampanò in like a magnet. */
export class Ball extends Entity {
  readonly sprite: Sprite;
  age = 0;
  taken = false;
  private t = 0;

  constructor(gx: number, gy: number) {
    super();
    const shadow = new Sprite(textures.get(spriteName('shadowSmall')));
    this.sprite = new Sprite(textures.get(spriteName('ball')));
    this.view.addChild(shadow, this.sprite);
    this.setPosition(gx, gy);
    this.bounds = { x: -5, y: -14, w: 10, h: 16 };
  }

  step(dt: number): boolean {
    this.age += dt;
    this.t += dt;
    // Bouncing in place.
    this.sprite.y = -Math.round(Math.abs(Math.sin(this.t * 4)) * 6);
    if (this.age > BALL.LIFETIME) {
      this.fade = Math.max(0, 1 - (this.age - BALL.LIFETIME) / 0.8);
      return this.age < BALL.LIFETIME + 0.8;
    }
    return !this.taken;
  }
}

/** Bagnaskiz, the bully pug: goes for the greenest spots and leaves a trail of pollution. */
export class Bagnaskiz extends Entity {
  readonly animator = new CharacterAnimator('bagnaskiz');
  state: 'roam' | 'stunned' | 'flee' | 'gone' = 'roam';
  hits = 0;
  target = { x: 0, y: 0 };
  private retarget = 0;
  private trail = 0;
  private stateTime = 0;
  private kx = 0;
  private ky = 0;
  private bumpCooldown = 0;
  private lastDir = { x: 0, y: 0 };

  constructor(gx: number, gy: number) {
    super();
    const shadow = new Sprite(textures.get(spriteName('shadow')));
    this.view.addChild(shadow, this.animator.sprite);
    this.setPosition(gx, gy);
    this.bounds = { x: -15, y: -32, w: 30, h: 35 };
  }

  get active(): boolean {
    return this.state === 'roam' || this.state === 'stunned';
  }

  hit(fromX: number, fromY: number): void {
    if (!this.active) return;
    this.hits++;
    const dx = this.gx - fromX;
    const dy = this.gy - fromY;
    const len = Math.hypot(dx, dy) || 1;
    this.kx = (dx / len) * BAGNASKIZ.KNOCKBACK_SPEED;
    this.ky = (dy / len) * BAGNASKIZ.KNOCKBACK_SPEED;
    this.stateTime = 0;
    this.state = this.hits >= BAGNASKIZ.HITS_TO_FLEE ? 'flee' : 'stunned';
    this.animator.play('hurt', this.animator.dir, true);
  }

  /**
   * @returns 'bump' when he runs into Zampanò this step.
   */
  step(dt: number, map: GameMap, px: number, py: number, pickTarget: () => { x: number; y: number }): 'bump' | null {
    this.stateTime += dt;
    if (this.bumpCooldown > 0) this.bumpCooldown -= dt;
    let vx = 0;
    let vy = 0;
    let anim: 'walk' | 'run' | 'hurt' | 'idle' = 'walk';
    if (this.state === 'roam') {
      this.retarget -= dt;
      const td = Math.hypot(this.target.x - this.gx, this.target.y - this.gy);
      if (this.retarget <= 0 || td < 0.5) {
        this.retarget = BAGNASKIZ.RETARGET;
        this.target = pickTarget();
      }
      const dx = this.target.x - this.gx;
      const dy = this.target.y - this.gy;
      const len = Math.hypot(dx, dy);
      if (len > 0.1) {
        vx = (dx / len) * BAGNASKIZ.SPEED;
        vy = (dy / len) * BAGNASKIZ.SPEED;
      }
      this.trail -= dt;
      if (this.trail <= 0) {
        this.trail = BAGNASKIZ.TRAIL_INTERVAL;
        map.stampDirt(this.gx, this.gy, BAGNASKIZ.TRAIL_RADIUS, BAGNASKIZ.TRAIL_STRENGTH);
      }
    } else if (this.state === 'stunned') {
      anim = 'hurt';
      if (this.stateTime > BAGNASKIZ.STUN_TIME) this.state = 'roam';
    } else if (this.state === 'flee') {
      anim = this.stateTime < 0.4 ? 'hurt' : 'run';
      if (this.stateTime >= 0.4) {
        const dx = this.gx - px;
        const dy = this.gy - py;
        const dir = fleeDirection(map, this.gx, this.gy, px, py, this.lastDir, BAGNASKIZ.RADIUS, Math.random);
        const len = Math.hypot(dx, dy) || 1;
        const fx = dir.x || dx / len;
        const fy = dir.y || dy / len;
        vx = fx * BAGNASKIZ.FLEE_SPEED;
        vy = fy * BAGNASKIZ.FLEE_SPEED;
        this.fade = Math.max(0, 1 - Math.max(0, this.stateTime - 2.2) / 0.8);
        if (this.stateTime > 3) this.state = 'gone';
      }
    }
    // Knockback
    const kd = Math.exp(-BAGNASKIZ.KNOCKBACK_DECAY * dt);
    this.kx *= kd;
    this.ky *= kd;
    const mx = (vx + this.kx) * dt;
    const my = (vy + this.ky) * dt;
    if (mx || my) {
      const r = map.moveCircle(this.gx, this.gy, mx, my, BAGNASKIZ.RADIUS);
      this.gx = r.x;
      this.gy = r.y;
    }
    if (Math.hypot(vx, vy) > 0.1) this.lastDir = { x: vx / Math.hypot(vx, vy), y: vy / Math.hypot(vx, vy) };
    if (anim !== 'hurt' && Math.hypot(vx, vy) < 0.1) anim = 'idle';
    const face = Math.hypot(vx, vy) > 0.1 ? dirFromGridVector(vx, vy, this.animator.dir) : this.animator.dir;
    this.animator.play(anim, face);
    this.animator.update(dt);
    this.animator.sprite.tint = this.state === 'stunned' && Math.floor(this.stateTime * 16) % 2 === 0 ? 0xff9090 : 0xffffff;

    if (this.state === 'roam' && this.bumpCooldown <= 0 && Math.hypot(px - this.gx, py - this.gy) < BAGNASKIZ.RADIUS + 0.35) {
      this.bumpCooldown = BAGNASKIZ.BUMP_COOLDOWN;
      return 'bump';
    }
    return null;
  }
}
