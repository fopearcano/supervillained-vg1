import { Graphics } from 'pixi.js';
import type { Effects } from '../campaign/state';
import { COMBAT } from '../config';
import type { Actor, Behavior, Point } from '../entities/actor';
import { dirFromGridVector, dirToGridVector, gridToScreen } from '../iso/projection';
import { damageFoe, inArc, isOpen, newFoe, shieldBlocks, staggerFoe, stepFoe } from '../systems/combat';
import { C } from '../ui/retro';
import { call, card } from './steps';
import type { StoryScene } from './storyScene';

/**
 * A fight inside a walk (`walk({ fight })`): these actors chase Zampanò and swing at him.
 * Rules in systems/combat.ts, numbers in COMBAT (config.ts).
 */
export interface FightDef {
  /** Actor names already on the stage. */
  foes: string[];
  /** How many have to be routed to finish (default: all; 0 = only get through). */
  rout?: number;
  /** Zampanò's hearts (default COMBAT.HEALTH). */
  health?: number;
  /** Each foe's HP (default COMBAT.FOE.HP). */
  hp?: number;
  /** How fast they come and from how far (default COMBAT.FOE). */
  speed?: number;
  radius?: number;
  /** They give up this far from where they started. */
  leash?: number;
  /** What a routed foe shouts as he runs (one at random). */
  routLines?: string[];
  /** What each sword blow that lands costs (5.3: drawing on Christians at Zara) and the line shown once. */
  swordCost?: Effects;
  swordCostText?: string;
  /** The knocked-down card's second line. */
  knockedText?: string;
  /** Armed foes parry the sword unless staggered, mid-swing or just after a swing (block, then strike). */
  parry?: boolean;
}

interface Snapshot {
  actor: Actor;
  at: Point;
  behavior: Behavior;
}

/**
 * BARK, the SWORD and the SHIELD in a story walk. They work in every walk (a bark is a bark, a
 * swing at nothing is a swing); with a FightDef, foes take the blows, swing back (a ring fills
 * under them: time to raise the shield) and Zampanò has hearts. Non-lethal: routed foes run.
 */
export class Combat {
  readonly foes: Actor[] = [];
  health = 0;
  maxHealth = 0;
  routed = 0;
  /** The shield is up this step. */
  guarding = false;
  private readonly fx = new Graphics();
  private readonly rings = new Graphics();
  private snapshots: Snapshot[] = [];
  private strikeCD = 0;
  private barkCD = 0;
  private guardPulse = 0;
  private wasGuarding = false;
  private swing = 0;
  private swingAngle = 0;
  private barkRing = 0;
  private invuln = 0;
  private told = new Set<string>();

  constructor(private readonly def: FightDef | null) {}

  get active(): boolean {
    return this.def !== null;
  }

  /** How many routed foes finish the fight. */
  get need(): number {
    return this.def ? Math.min(this.def.rout ?? this.foes.length, this.foes.length) : 0;
  }

  get won(): boolean {
    return !this.def || this.routed >= this.need;
  }

  start(ctx: StoryScene): void {
    const world = ctx.world!;
    world.decalLayer.addChild(this.rings);
    world.fxLayer.addChild(this.fx);
    const d = this.def;
    if (!d) return;
    this.maxHealth = d.health ?? COMBAT.HEALTH;
    this.health = this.maxHealth;
    for (const name of d.foes) {
      const a = ctx.actor(name);
      this.foes.push(a);
      this.snapshots.push({ actor: a, at: { x: a.gx, y: a.gy }, behavior: a.behavior });
    }
    this.arm(ctx);
  }

  /** Every foe at full HP, hostile, coming for him. */
  private arm(ctx: StoryScene): void {
    const d = this.def!;
    for (const s of this.snapshots) {
      const a = s.actor;
      a.foe = newFoe(d.hp ?? COMBAT.FOE.HP);
      a.hostile = true;
      a.setBehavior({
        kind: 'chase',
        speed: d.speed ?? COMBAT.FOE.CHASE_SPEED,
        radius: d.radius ?? COMBAT.FOE.CHASE_RADIUS,
        home: { ...s.at },
        leash: d.leash,
        stopAt: COMBAT.FOE.STOP_AT,
      });
    }
    this.routed = 0;
    this.showHealth(ctx);
  }

  /** Knocked down: everyone back where they started, hearts full (the walk puts him back too). */
  reset(ctx: StoryScene): void {
    if (!this.def) return;
    for (const s of this.snapshots) s.actor.setPosition(s.at.x, s.at.y);
    this.health = this.maxHealth;
    this.invuln = 0;
    this.arm(ctx);
  }

  private showHealth(ctx: StoryScene): void {
    if (!this.def) return;
    ctx.hud.setMode({ label: this.need > 0 ? `HEALTH  ROUTED ${this.routed}/${this.need}` : 'HEALTH', value: this.health / this.maxHealth, color: 0xff4a4a });
  }

  private knighted(ctx: StoryScene, what: 'SWORD' | 'SHIELD'): boolean {
    if (ctx.knighted) return true;
    if (!this.told.has(what)) {
      this.told.add(what);
      ctx.notice(`NO ${what} YET: THE ARMOURER LEFT THEM ON THE ROAD (2.3)`, '#9aa4c0');
    }
    return false;
  }

  /** Turns him toward the nearest fighting foe within `range` (aim help for thumbs). */
  private faceNearest(ctx: StoryScene, range: number): Actor | null {
    const p = ctx.player;
    let best: Actor | null = null;
    let bd = range;
    for (const a of this.foes) {
      if (!a.foe || a.foe.routed) continue;
      const d = Math.hypot(a.gx - p.gx, a.gy - p.gy);
      if (d < bd) {
        bd = d;
        best = a;
      }
    }
    if (best) p.face(dirFromGridVector(best.gx - p.gx, best.gy - p.gy, p.facing));
    return best;
  }

  /** BARK: a woof everywhere; in a fight it staggers and pushes back everyone near. */
  bark(ctx: StoryScene, text = 'WOOF!'): void {
    const p = ctx.player;
    if (this.def && this.barkCD > 0) return;
    p.startAction('bark', 0.3);
    ctx.game.audio.play('bark');
    ctx.say(text, { x: p.gx, y: p.gy });
    if (!this.def) return;
    this.barkCD = COMBAT.BARK.COOLDOWN;
    this.barkRing = 1;
    const B = COMBAT.BARK;
    for (const a of this.foes) {
      if (!a.foe || a.foe.routed) continue;
      const dx = a.gx - p.gx;
      const dy = a.gy - p.gy;
      const d = Math.hypot(dx, dy);
      if (d > B.RADIUS) continue;
      a.knock((dx / (d || 1)) * B.KNOCK, (dy / (d || 1)) * B.KNOCK);
      this.land(ctx, a, damageFoe(a.foe, B.DAMAGE, B.STUN, false));
    }
  }

  /** SWORD: a swing in front of him (knights only). Foes in the arc are hit and pushed back. */
  strike(ctx: StoryScene): void {
    if (!this.knighted(ctx, 'SWORD') || this.strikeCD > 0) return;
    const S = COMBAT.SWORD;
    const p = ctx.player;
    this.strikeCD = S.COOLDOWN;
    this.faceNearest(ctx, S.RANGE + 0.6);
    p.startAction('bark', S.ACTION_TIME);
    p.bump(0.25);
    ctx.game.audio.play('swish');
    const f = dirToGridVector(p.facing);
    const sf = gridToScreen(f.x, f.y);
    this.swingAngle = Math.atan2(sf.y, sf.x);
    this.swing = 1;
    if (!this.def) return;
    let landed = false;
    for (const a of this.foes) {
      if (!a.foe || a.foe.routed) continue;
      if (!inArc(p.gx, p.gy, f.x, f.y, a.gx, a.gy, S.RANGE, S.HALF_ARC)) continue;
      const dx = a.gx - p.gx;
      const dy = a.gy - p.gy;
      const d = Math.hypot(dx, dy) || 1;
      if (this.def.parry && !isOpen(a.foe)) {
        // Parried: wood on wood (or steel on steel), both give a step.
        a.knock((dx / d) * S.PARRY_KNOCK, (dy / d) * S.PARRY_KNOCK);
        p.knockback(-dx, -dy, S.PARRY_KNOCK);
        ctx.game.audio.play('clang');
        ctx.say('PARRIED', { x: a.gx, y: a.gy }, '#9aa4c0');
        if (!this.told.has('parry')) {
          this.told.add('parry');
          ctx.notice('HE PARRIES: BLOCK HIS BLOW, OR CATCH HIM MID-SWING, THEN STRIKE', '#9ad8ff');
        }
        continue;
      }
      a.knock((dx / d) * S.KNOCK, (dy / d) * S.KNOCK);
      this.land(ctx, a, damageFoe(a.foe, S.DAMAGE, S.STUN));
      landed = true;
    }
    if (landed && this.def.swordCost) {
      ctx.apply(this.def.swordCost);
      if (this.def.swordCostText && !this.told.has('cost')) {
        this.told.add('cost');
        ctx.notice(this.def.swordCostText, C.orange);
      }
    }
  }

  /** SHIELD: up for a moment (held: as long as it is held); raising it shoves whoever is in front. */
  raiseShield(ctx: StoryScene): void {
    if (!this.knighted(ctx, 'SHIELD')) return;
    this.guardPulse = COMBAT.SHIELD.PULSE;
  }

  private land(ctx: StoryScene, a: Actor, result: 'hit' | 'routed' | 'none'): void {
    if (result === 'none') return;
    a.flash();
    a.emote('hurt', 0.3);
    ctx.game.audio.play('hit');
    const s = gridToScreen(a.gx, a.gy);
    ctx.particles.burst(s.x, s.y - 14, { count: 6, textures: ['pixel'], colors: [0xffffff, 0xffe23a], speed: [30, 80], life: [0.2, 0.4], drag: 4 });
    if (result !== 'routed') return;
    this.routed++;
    a.hostile = false;
    a.setBehavior({ kind: 'flee', speed: 3.2, radius: 99 });
    const lines = this.def?.routLines ?? ['ENOUGH!'];
    ctx.say(lines[Math.floor(Math.random() * lines.length)]!, { x: a.gx, y: a.gy }, C.orange);
    ctx.game.audio.play('flee');
    this.showHealth(ctx);
  }

  /** One logic step: the shield, the foes' swings, the hearts, the drawing. */
  update(dt: number, ctx: StoryScene, guardHeld: boolean): void {
    const p = ctx.player;
    this.strikeCD = Math.max(0, this.strikeCD - dt);
    this.barkCD = Math.max(0, this.barkCD - dt);
    this.guardPulse = Math.max(0, this.guardPulse - dt);
    this.invuln = Math.max(0, this.invuln - dt);
    this.guarding = ctx.knighted && (guardHeld || this.guardPulse > 0);
    p.guarding = this.guarding;
    if (this.guarding) {
      // Behind the shield he turns to the nearest threat (the shield faces it).
      this.faceNearest(ctx, 2.6);
      if (!this.wasGuarding) {
        ctx.game.audio.play('click');
        // The bash: whoever stands right in front is shoved back (room, not an opening:
        // the opening is a blow taken on the shield).
        const f = dirToGridVector(p.facing);
        const Sh = COMBAT.SHIELD;
        for (const a of this.foes) {
          if (!a.foe || a.foe.routed) continue;
          if (!inArc(p.gx, p.gy, f.x, f.y, a.gx, a.gy, Sh.BASH_RANGE, Sh.HALF_ARC)) continue;
          const dx = a.gx - p.gx;
          const dy = a.gy - p.gy;
          const d = Math.hypot(dx, dy) || 1;
          a.knock((dx / d) * Sh.BASH_KNOCK, (dy / d) * Sh.BASH_KNOCK);
        }
      }
    }
    this.wasGuarding = this.guarding;
    if (this.def) this.updateFoes(dt, ctx);
    this.draw(dt, ctx);
  }

  private updateFoes(dt: number, ctx: StoryScene): void {
    const p = ctx.player;
    const F = COMBAT.FOE;
    for (const a of this.foes) {
      const f = a.foe;
      if (!f || f.routed) continue;
      const d = Math.hypot(a.gx - p.gx, a.gy - p.gy);
      const ev = stepFoe(f, dt, d);
      if (ev === 'windup') a.emote('bark', F.WINDUP);
      if (ev !== 'strike' || d > F.REACH) continue;
      const face = dirToGridVector(p.facing);
      if (this.guarding && shieldBlocks(p.gx, p.gy, face.x, face.y, a.gx, a.gy)) {
        const Sh = COMBAT.SHIELD;
        ctx.game.audio.play('clang');
        staggerFoe(f, Sh.BLOCK_STUN);
        a.knock(((a.gx - p.gx) / (d || 1)) * Sh.BLOCK_KNOCK, ((a.gy - p.gy) / (d || 1)) * Sh.BLOCK_KNOCK);
        const s = gridToScreen((a.gx + p.gx) / 2, (a.gy + p.gy) / 2);
        ctx.particles.burst(s.x, s.y - 14, { count: 8, textures: ['pixel'], colors: [0xffffff, 0xffe23a, 0x9ad8ff], speed: [40, 100], life: [0.15, 0.35], drag: 5 });
        ctx.say('CLANG!', { x: p.gx, y: p.gy }, C.yellow);
        continue;
      }
      if (this.invuln > 0) continue;
      this.health = Math.max(0, this.health - 1);
      this.invuln = COMBAT.HURT.INVULN;
      p.knockback(p.gx - a.gx, p.gy - a.gy, COMBAT.HURT.KNOCK);
      p.startAction('hurt', COMBAT.HURT.TIME);
      ctx.game.audio.play('hurt');
      ctx.shake(2);
      ctx.metrics.caught++;
      this.showHealth(ctx);
      if (this.health <= 0) {
        ctx.metrics.restarts++;
        ctx.interrupt([
          card('KNOCKED DOWN', this.def!.knockedText ?? 'UP AGAIN. RAISE THE SHIELD WHEN THE RING FILLS.', { color: C.red, seconds: 1.8 }),
          call(() => this.onKnockedDown?.()),
        ]);
        return;
      }
    }
  }

  /** Set by the walk: put him back at the start (the foes are reset by `reset`). */
  onKnockedDown: (() => void) | null = null;

  private draw(dt: number, ctx: StoryScene): void {
    const p = ctx.player;
    const ps = gridToScreen(p.gx, p.gy);
    const g = this.fx;
    g.clear();
    // The sword's arc.
    if (this.swing > 0) {
      // A crescent sweeping across the front, fading.
      this.swing = Math.max(0, this.swing - dt / (COMBAT.SWORD.ACTION_TIME * 1.6));
      const a0 = this.swingAngle - 1.1;
      const sweep = 2.2 * Math.min(1, (1 - this.swing) * 2.2 + 0.25);
      const cx = ps.x;
      const cy = ps.y - 10;
      const pts: number[] = [];
      const n = 10;
      for (let k = 0; k <= n; k++) {
        const a = a0 + (sweep * k) / n;
        const r = 14 + 11 * Math.sin((Math.PI * k) / n);
        pts.push(cx + Math.cos(a) * r, cy + Math.sin(a) * r * 0.75);
      }
      for (let k = n; k >= 0; k--) {
        const a = a0 + (sweep * k) / n;
        pts.push(cx + Math.cos(a) * 13, cy + Math.sin(a) * 13 * 0.75);
      }
      g.poly(pts).fill({ color: 0xffffff, alpha: 0.75 * this.swing });
      g.poly(pts).stroke({ width: 1, color: 0x9ad8ff, alpha: this.swing });
    }
    // The bark's ring.
    if (this.barkRing > 0) {
      this.barkRing = Math.max(0, this.barkRing - dt * 2.5);
      const r = (1 - this.barkRing) * COMBAT.BARK.RADIUS * 22;
      g.ellipse(ps.x, ps.y, r, r * 0.5).stroke({ width: 2, color: 0x3ff0ff, alpha: this.barkRing });
    }
    // The raised shield: a kite in front of him.
    if (this.guarding) {
      const f = dirToGridVector(p.facing);
      const s = gridToScreen(p.gx + f.x * 0.42, p.gy + f.y * 0.42);
      const x = s.x;
      const y = s.y - 14;
      g.poly([x - 6, y - 8, x + 6, y - 8, x + 6, y + 1, x, y + 8, x - 6, y + 1]).fill({ color: 0x3050c0, alpha: 0.85 }).stroke({ width: 1, color: 0xffc23a });
      g.rect(x - 0.5, y - 7, 1.5, 12).fill({ color: 0xffffff });
      g.rect(x - 4, y - 4, 8, 1.5).fill({ color: 0xffffff });
    }
    // Under each foe: the swing's ring filling (red), stagger stars (yellow).
    const r = this.rings;
    r.clear();
    for (const a of this.foes) {
      const f = a.foe;
      if (!f || f.routed) continue;
      const s = gridToScreen(a.gx, a.gy);
      if (f.windup > 0) {
        const k = 1 - f.windup / COMBAT.FOE.WINDUP;
        r.ellipse(s.x, s.y, 13, 6.5).stroke({ width: 1, color: 0xff3b3b, alpha: 0.9 });
        r.ellipse(s.x, s.y, 13 * k, 6.5 * k).fill({ color: 0xff3b3b, alpha: 0.45 });
      } else if (f.stun > 0) {
        r.ellipse(s.x, s.y, 11, 5.5).stroke({ width: 1, color: 0xffe23a, alpha: 0.7 });
      }
      // HP pips over the head.
      for (let k = 0; k < Math.ceil(f.maxHp); k++) {
        const left = f.hp - k;
        const color = left >= 1 ? 0xff4a4a : left > 0 ? 0xff9a6a : 0x3a2a2a;
        g.rect(Math.round(s.x - Math.ceil(f.maxHp) * 2.5 + k * 5), Math.round(s.y - 40), 4, 2).fill({ color });
      }
    }
  }

  stop(ctx: StoryScene): void {
    ctx.player.guarding = false;
    for (const a of this.foes) {
      const routed = a.foe?.routed ?? false;
      a.foe = null;
      a.hostile = false;
      a.sprite.tint = 0xffffff;
      if (!routed) a.setBehavior({ kind: 'idle', face: 'player' });
    }
    this.fx.destroy();
    this.rings.destroy();
  }
}
