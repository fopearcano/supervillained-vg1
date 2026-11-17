import { BLADDER, DIGESTION, ENERGY, HUNGER } from '../config';

/**
 * Zampanò's bodily needs. Pure logic, no rendering: hunger, digestion, bladder and energy.
 */

export type Activity = 'idle' | 'walk' | 'run';

export class Hunger {
  value: number = HUNGER.START;

  /** Drains hunger. Returns true when it just reached zero (starving). */
  update(dt: number, activity: Activity): boolean {
    if (this.value <= 0) return false;
    const rate = activity === 'run' ? HUNGER.DRAIN_RUN : activity === 'walk' ? HUNGER.DRAIN_WALK : HUNGER.DRAIN_IDLE;
    this.value = Math.max(0, this.value - rate * dt);
    return this.value === 0;
  }

  feed(amount: number): void {
    this.value = Math.min(HUNGER.MAX, this.value + amount);
  }

  lose(amount: number): boolean {
    if (this.value <= 0) return false;
    this.value = Math.max(0, this.value - amount);
    return this.value === 0;
  }

  get fraction(): number {
    return this.value / HUNGER.MAX;
  }
}

export type DigestionEvent = 'warning' | 'poop' | null;

/**
 * Hidden digestion meter: treats fill it; when full a warning starts, and when the warning
 * expires Zampanò poops (the caller may postpone the poop while he is busy).
 */
export class Digestion {
  meter = 0;
  warning = false;
  warningLeft = 0;
  /** The warning has expired and a poop is due as soon as possible. */
  due = false;

  add(amount: number): DigestionEvent {
    if (this.warning || this.due) {
      this.meter = Math.min(DIGESTION.MAX * 2, this.meter + amount);
      return null;
    }
    this.meter += amount;
    if (this.meter >= DIGESTION.MAX) {
      this.warning = true;
      this.warningLeft = DIGESTION.WARNING_TIME;
      return 'warning';
    }
    return null;
  }

  update(dt: number): DigestionEvent {
    if (!this.warning) return null;
    this.warningLeft -= dt;
    if (this.warningLeft <= 0) {
      this.warning = false;
      this.due = true;
      return 'poop';
    }
    return null;
  }

  /** Call when the poop actually happened. Overflow carries over to the next one. */
  done(): DigestionEvent {
    this.due = false;
    this.meter = Math.max(0, this.meter - DIGESTION.MAX);
    if (this.meter >= DIGESTION.MAX) {
      this.warning = true;
      this.warningLeft = DIGESTION.WARNING_TIME;
      return 'warning';
    }
    return null;
  }
}

/** Pee charges that regenerate slowly and refill instantly when drinking. */
export class Bladder {
  charges: number = BLADDER.START_CHARGES;
  readonly max: number = BLADDER.MAX_CHARGES;
  private regen = 0;
  private drinkCooldown = 0;

  update(dt: number): void {
    if (this.drinkCooldown > 0) this.drinkCooldown -= dt;
    if (this.charges >= this.max) {
      this.regen = 0;
      return;
    }
    this.regen += dt;
    if (this.regen >= BLADDER.REGEN_TIME) {
      this.regen -= BLADDER.REGEN_TIME;
      this.charges++;
    }
  }

  get canPee(): boolean {
    return this.charges > 0;
  }

  use(): boolean {
    if (this.charges <= 0) return false;
    this.charges--;
    return true;
  }

  /** Progress (0..1) toward the next regenerated charge. */
  get regenFraction(): number {
    return this.charges >= this.max ? 0 : this.regen / BLADDER.REGEN_TIME;
  }

  get canDrink(): boolean {
    return this.charges < this.max && this.drinkCooldown <= 0;
  }

  drink(): boolean {
    if (!this.canDrink) return false;
    this.charges = this.max;
    this.regen = 0;
    this.drinkCooldown = BLADDER.DRINK_COOLDOWN;
    return true;
  }
}

export type EnergyEvent = 'empty' | 'ready' | null;

/**
 * Energy for running: spent while running, recovered while walking or standing. When it hits
 * zero Zampanò is tired and can't run until it is back to ENERGY.MIN_TO_RUN.
 */
export class Energy {
  value: number = ENERGY.MAX;
  /** Emptied: running stays off until the meter recovers to ENERGY.MIN_TO_RUN. */
  exhausted = false;
  /** Recovery multiplier (the arcade halves it while Zampanò is hungry). */
  recovery = 1;

  update(dt: number, activity: Activity): EnergyEvent {
    if (activity === 'run') {
      this.value = Math.max(0, this.value - ENERGY.DRAIN_RUN * dt);
      if (this.value === 0 && !this.exhausted) {
        this.exhausted = true;
        return 'empty';
      }
      return null;
    }
    const rate = (activity === 'walk' ? ENERGY.RECOVER_WALK : ENERGY.RECOVER_IDLE) * this.recovery;
    this.value = Math.min(ENERGY.MAX, this.value + rate * dt);
    if (this.exhausted && this.value >= ENERGY.MIN_TO_RUN) {
      this.exhausted = false;
      return 'ready';
    }
    return null;
  }

  get canRun(): boolean {
    return !this.exhausted && this.value > 0;
  }

  get fraction(): number {
    return this.value / ENERGY.MAX;
  }

  refill(): void {
    this.value = ENERGY.MAX;
    this.exhausted = false;
  }
}
