import { INPUT } from '../config';

/**
 * Unified input: keyboard + mouse + multi-touch.
 * - Movement is a screen-space vector (x right, y down) with magnitude 0..1.
 * - Discrete actions (pee, bark, menu, confirm, ...) are queued until consumed.
 * - RUN is held, not queued: `runHeld` (RUN button, Shift or K).
 * - Touch: a floating virtual joystick (appears under the thumb) and on-screen buttons.
 */

export type Action = 'pee' | 'bark' | 'run' | 'menu' | 'confirm' | 'back' | 'up' | 'down' | 'left' | 'right';

export interface VirtualButton {
  id: string;
  action: Action;
  /** Circle hit area in logical px. */
  x: number;
  y: number;
  r: number;
  enabled: boolean;
  /** Visual pressed state (held). */
  pressed: boolean;
}

export interface JoystickState {
  active: boolean;
  baseX: number;
  baseY: number;
  knobX: number;
  knobY: number;
}

export interface Tap {
  x: number;
  y: number;
}

interface PointerTrack {
  kind: 'button' | 'joystick' | 'tap';
  buttonId?: string;
  startX: number;
  startY: number;
  x: number;
  y: number;
}

const KEY_ACTIONS: Record<string, Action[]> = {
  Space: ['pee', 'confirm'],
  Enter: ['confirm'],
  NumpadEnter: ['confirm'],
  KeyJ: ['bark'],
  KeyX: ['bark'],
  KeyK: ['run'],
  Escape: ['menu', 'back'],
  KeyP: ['menu'],
  ArrowUp: ['up'],
  KeyW: ['up'],
  ArrowDown: ['down'],
  KeyS: ['down'],
  ArrowLeft: ['left'],
  KeyA: ['left'],
  ArrowRight: ['right'],
  KeyD: ['right'],
};

export class Input {
  readonly move = { x: 0, y: 0 };
  readonly joystick: JoystickState = { active: false, baseX: 0, baseY: 0, knobX: 0, knobY: 0 };
  /** Where the floating joystick may appear (logical px). */
  joystickZone = { x: 0, y: 0, w: 0, h: 0 };
  joystickEnabled = false;
  /** True once a touch was seen: show touch controls. */
  usingTouch = false;
  readonly buttons = new Map<string, VirtualButton>();

  private readonly keys = new Set<string>();
  private readonly pending = new Map<Action, number>();
  private taps: Tap[] = [];
  private readonly pointers = new Map<number, PointerTrack>();
  private joystickPointer: number | null = null;
  private toLogical: (cx: number, cy: number) => { x: number; y: number } = (x, y) => ({ x, y });
  private now = 0;

  attach(el: HTMLElement, toLogical: (clientX: number, clientY: number) => { x: number; y: number }): void {
    this.toLogical = toLogical;
    window.addEventListener('keydown', (e) => this.onKey(e, true));
    window.addEventListener('keyup', (e) => this.onKey(e, false));
    window.addEventListener('blur', () => this.releaseAll());
    el.addEventListener('pointerdown', (e) => this.onPointerDown(e));
    el.addEventListener('pointermove', (e) => this.onPointerMove(e));
    el.addEventListener('pointerup', (e) => this.onPointerUp(e, false));
    el.addEventListener('pointercancel', (e) => this.onPointerUp(e, true));
    el.addEventListener('lostpointercapture', (e) => this.onPointerUp(e, true));
    // No zoom, no scrolling, no long-press menu.
    const prevent = (e: Event) => e.preventDefault();
    el.addEventListener('contextmenu', prevent);
    document.addEventListener('contextmenu', prevent);
    document.addEventListener('touchstart', prevent, { passive: false });
    document.addEventListener('touchmove', prevent, { passive: false });
    document.addEventListener('gesturestart', prevent);
    document.addEventListener('dblclick', prevent);
  }

  /** Automation (story autopilot): when set, replaces keyboard and joystick movement and RUN. */
  override: { x: number; y: number; run?: boolean } | null = null;

  /** RUN is held: the touch button, Shift or K (or the autopilot asks for it). */
  get runHeld(): boolean {
    if (this.override) return !!this.override.run;
    return (
      this.keys.has('ShiftLeft') || this.keys.has('ShiftRight') || this.keys.has('KeyK') || (this.buttons.get('run')?.pressed ?? false)
    );
  }

  /** Called once per logic step. */
  update(dt: number): void {
    this.now += dt;
    for (const [a, t] of this.pending) if (this.now - t > INPUT.ACTION_TTL) this.pending.delete(a);
    if (this.override) {
      this.move.x = this.override.x;
      this.move.y = this.override.y;
      return;
    }
    // Keyboard vector
    let kx = 0;
    let ky = 0;
    if (this.keys.has('ArrowLeft') || this.keys.has('KeyA')) kx -= 1;
    if (this.keys.has('ArrowRight') || this.keys.has('KeyD')) kx += 1;
    if (this.keys.has('ArrowUp') || this.keys.has('KeyW')) ky -= 1;
    if (this.keys.has('ArrowDown') || this.keys.has('KeyS')) ky += 1;
    if (kx !== 0 || ky !== 0) {
      const len = Math.hypot(kx, ky);
      this.move.x = kx / len;
      this.move.y = ky / len;
      return;
    }
    // Joystick vector
    if (this.joystick.active) {
      const dx = this.joystick.knobX - this.joystick.baseX;
      const dy = this.joystick.knobY - this.joystick.baseY;
      const len = Math.hypot(dx, dy);
      let mag = Math.min(1, len / INPUT.JOYSTICK_RADIUS);
      mag = mag < INPUT.JOYSTICK_DEADZONE ? 0 : (mag - INPUT.JOYSTICK_DEADZONE) / (1 - INPUT.JOYSTICK_DEADZONE);
      this.move.x = len > 0 ? (dx / len) * mag : 0;
      this.move.y = len > 0 ? (dy / len) * mag : 0;
      return;
    }
    this.move.x = 0;
    this.move.y = 0;
  }

  /** Returns true (once) if the action was triggered recently. */
  consume(action: Action): boolean {
    if (!this.pending.has(action)) return false;
    this.pending.delete(action);
    return true;
  }

  /** Returns and clears the taps (pointer press+release without much movement). */
  consumeTaps(): Tap[] {
    const t = this.taps;
    this.taps = [];
    return t;
  }

  /** Forget queued actions/taps (call on scene changes so a key press doesn't leak). */
  clearPending(): void {
    this.pending.clear();
    this.taps = [];
  }

  trigger(action: Action): void {
    this.pending.set(action, this.now);
  }

  /** Automation: a tap at a logical position, as if a finger pressed and released there. */
  pushTap(x: number, y: number): void {
    this.taps.push({ x, y });
  }

  setButton(b: Omit<VirtualButton, 'pressed'>): void {
    const old = this.buttons.get(b.id);
    this.buttons.set(b.id, { ...b, pressed: old?.pressed ?? false });
  }

  isKeyDown(code: string): boolean {
    return this.keys.has(code);
  }

  private onKey(e: KeyboardEvent, down: boolean): void {
    const code = e.code;
    if (code.startsWith('Arrow') || code === 'Space') e.preventDefault();
    if (down) {
      if (!e.repeat) for (const a of KEY_ACTIONS[code] ?? []) this.trigger(a);
      this.keys.add(code);
    } else {
      this.keys.delete(code);
    }
  }

  private onPointerDown(e: PointerEvent): void {
    e.preventDefault();
    if (e.pointerType === 'touch') this.usingTouch = true;
    const p = this.toLogical(e.clientX, e.clientY);
    try {
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
    } catch {
      /* ignore */
    }
    for (const b of this.buttons.values()) {
      if (!b.enabled) continue;
      if (Math.hypot(p.x - b.x, p.y - b.y) <= b.r) {
        b.pressed = true;
        this.trigger(b.action);
        this.pointers.set(e.pointerId, { kind: 'button', buttonId: b.id, startX: p.x, startY: p.y, x: p.x, y: p.y });
        return;
      }
    }
    const z = this.joystickZone;
    if (
      this.joystickEnabled &&
      this.joystickPointer === null &&
      p.x >= z.x &&
      p.x <= z.x + z.w &&
      p.y >= z.y &&
      p.y <= z.y + z.h
    ) {
      this.joystickPointer = e.pointerId;
      Object.assign(this.joystick, { active: true, baseX: p.x, baseY: p.y, knobX: p.x, knobY: p.y });
      this.pointers.set(e.pointerId, { kind: 'joystick', startX: p.x, startY: p.y, x: p.x, y: p.y });
      return;
    }
    this.pointers.set(e.pointerId, { kind: 'tap', startX: p.x, startY: p.y, x: p.x, y: p.y });
  }

  private onPointerMove(e: PointerEvent): void {
    const t = this.pointers.get(e.pointerId);
    if (!t) return;
    const p = this.toLogical(e.clientX, e.clientY);
    t.x = p.x;
    t.y = p.y;
    if (t.kind === 'joystick') {
      const j = this.joystick;
      j.knobX = p.x;
      j.knobY = p.y;
      // The base follows the thumb when dragged beyond the radius.
      const dx = j.knobX - j.baseX;
      const dy = j.knobY - j.baseY;
      const len = Math.hypot(dx, dy);
      const R = INPUT.JOYSTICK_RADIUS;
      if (len > R) {
        j.baseX = j.knobX - (dx / len) * R;
        j.baseY = j.knobY - (dy / len) * R;
      }
    }
  }

  private onPointerUp(e: PointerEvent, cancelled: boolean): void {
    const t = this.pointers.get(e.pointerId);
    if (!t) return;
    this.pointers.delete(e.pointerId);
    if (t.kind === 'button' && t.buttonId) {
      const b = this.buttons.get(t.buttonId);
      if (b) b.pressed = false;
    } else if (t.kind === 'joystick') {
      this.joystickPointer = null;
      this.joystick.active = false;
    } else if (!cancelled && Math.hypot(t.x - t.startX, t.y - t.startY) <= INPUT.TAP_SLOP) {
      this.taps.push({ x: t.x, y: t.y });
    }
  }

  private releaseAll(): void {
    this.keys.clear();
    this.pointers.clear();
    this.joystickPointer = null;
    this.joystick.active = false;
    for (const b of this.buttons.values()) b.pressed = false;
  }
}
