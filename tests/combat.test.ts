import { describe, expect, it } from 'vitest';
import { COMBAT } from '../src/config';
import { damageFoe, inArc, newFoe, shieldBlocks, staggerFoe, stepFoe } from '../src/systems/combat';

describe('the sword arc', () => {
  it('hits in front, within range, and misses behind or too far', () => {
    const R = COMBAT.SWORD.RANGE;
    const A = COMBAT.SWORD.HALF_ARC;
    expect(inArc(0, 0, 1, 0, 1, 0.2, R, A)).toBe(true);
    expect(inArc(0, 0, 1, 0, -1, 0, R, A)).toBe(false);
    expect(inArc(0, 0, 1, 0, R + 0.2, 0, R, A)).toBe(false);
    // Nearly on top of him counts as in front.
    expect(inArc(0, 0, 1, 0, -0.1, 0.1, R, A)).toBe(true);
  });
});

describe('foes', () => {
  it('are routed, not killed, when their HP runs out', () => {
    const f = newFoe(2);
    expect(damageFoe(f, 1, 0.5)).toBe('hit');
    expect(f.stun).toBe(0.5);
    expect(damageFoe(f, 1, 0.5)).toBe('routed');
    expect(f.routed).toBe(true);
    expect(damageFoe(f, 1, 0.5)).toBe('none');
  });

  it('two barks rout what one sword blow only wounds', () => {
    const a = newFoe(1);
    expect(damageFoe(a, COMBAT.BARK.DAMAGE, COMBAT.BARK.STUN, false)).toBe('hit');
    expect(damageFoe(a, COMBAT.BARK.DAMAGE, COMBAT.BARK.STUN, false)).toBe('routed');
  });

  it('a bark does not stop a swing already coming; a sword blow does, and costs the swing', () => {
    const f = newFoe(3);
    f.windup = 0.2;
    damageFoe(f, COMBAT.BARK.DAMAGE, COMBAT.BARK.STUN, false);
    expect(f.windup).toBe(0.2);
    expect(f.stun).toBe(0);
    damageFoe(f, COMBAT.SWORD.DAMAGE, COMBAT.SWORD.STUN);
    expect(f.windup).toBe(0);
    expect(f.cooldown).toBeCloseTo(COMBAT.FOE.COOLDOWN - COMBAT.FOE.RECOVER);
  });

  it('wind up when close and off cooldown, then strike, then wait', () => {
    const f = newFoe();
    f.cooldown = 0;
    expect(stepFoe(f, 0.01, 3)).toBe('none');
    expect(stepFoe(f, 0.01, COMBAT.FOE.ATTACK_RANGE - 0.1)).toBe('windup');
    let ev = 'none';
    for (let t = 0; t < COMBAT.FOE.WINDUP + 0.05 && ev === 'none'; t += 0.01) ev = stepFoe(f, 0.01, 0.5);
    expect(ev).toBe('strike');
    expect(f.cooldown).toBeCloseTo(COMBAT.FOE.COOLDOWN);
    expect(stepFoe(f, 0.01, 0.5)).toBe('none');
  });

  it('a stagger interrupts the swing', () => {
    const f = newFoe();
    f.cooldown = 0;
    stepFoe(f, 0.01, 0.5);
    expect(f.windup).toBeGreaterThan(0);
    staggerFoe(f, 0.4);
    expect(f.windup).toBe(0);
    expect(stepFoe(f, 0.1, 0.5)).toBe('none');
  });
});

describe('the shield', () => {
  it('takes blows from in front and from the sides, not from behind', () => {
    expect(shieldBlocks(0, 0, 0, 1, 0, 1)).toBe(true);
    expect(shieldBlocks(0, 0, 0, 1, 0.9, 0.5)).toBe(true);
    expect(shieldBlocks(0, 0, 0, 1, 0, -1)).toBe(false);
  });
});

describe('parries', () => {
  it('a foe is open while staggered, mid-swing or just after a swing, guarded otherwise', async () => {
    const { isOpen } = await import('../src/systems/combat');
    const f = newFoe();
    expect(isOpen(f)).toBe(false);
    staggerFoe(f, 0.2);
    expect(isOpen(f)).toBe(true);
    f.stun = 0;
    f.windup = 0.3;
    expect(isOpen(f)).toBe(true);
    f.windup = 0;
    f.cooldown = COMBAT.FOE.COOLDOWN;
    expect(isOpen(f)).toBe(true);
    f.cooldown = COMBAT.FOE.COOLDOWN - COMBAT.FOE.RECOVER - 0.1;
    expect(isOpen(f)).toBe(false);
  });

  it('one blow uses up the opening: its stagger is shorter than the sword cooldown', () => {
    const f = newFoe(3);
    staggerFoe(f, COMBAT.SHIELD.BLOCK_STUN);
    damageFoe(f, COMBAT.SWORD.DAMAGE, COMBAT.SWORD.STUN);
    expect(f.stun).toBe(COMBAT.SWORD.STUN);
    expect(COMBAT.SWORD.STUN).toBeLessThan(COMBAT.SWORD.COOLDOWN);
  });
});
