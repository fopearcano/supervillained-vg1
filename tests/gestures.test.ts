import { describe, expect, it } from 'vitest';
import { bindingAction, classifySwipe, isDoubleTap } from '../src/core/input';
import { INPUT } from '../src/config';

describe('right-hand gestures', () => {
  it('reads a quick vertical stroke as a swipe up or down', () => {
    expect(classifySwipe(2, -INPUT.SWIPE_MIN - 4, 0.15)).toBe('swipeUp');
    expect(classifySwipe(-3, INPUT.SWIPE_MIN + 1, 0.2)).toBe('swipeDown');
  });

  it('ignores short, slow or sideways strokes', () => {
    expect(classifySwipe(0, -(INPUT.SWIPE_MIN - 1), 0.1)).toBeNull();
    expect(classifySwipe(0, -40, INPUT.SWIPE_MAX_TIME + 0.05)).toBeNull();
    expect(classifySwipe(30, -24, 0.1)).toBeNull();
  });

  it('counts a second tap close in time and place as a double tap', () => {
    const first = { x: 180, y: 200, at: 10 };
    expect(isDoubleTap(first, 184, 203, 10 + INPUT.DOUBLE_TAP_TIME * 0.5)).toBe(true);
    expect(isDoubleTap(first, 184, 203, 10 + INPUT.DOUBLE_TAP_TIME + 0.05)).toBe(false);
    expect(isDoubleTap(first, 180 + INPUT.DOUBLE_TAP_DIST + 5, 200, 10.1)).toBe(false);
    expect(isDoubleTap(null, 180, 200, 10)).toBe(false);
  });

  it('maps every CONTROLS choice to an input action', () => {
    expect(bindingAction('sword')).toBe('strike');
    expect(bindingAction('shield')).toBe('guard');
    expect(bindingAction('bark')).toBe('bark');
    expect(bindingAction('action')).toBe('action');
    expect(bindingAction('switch')).toBe('switch');
    expect(bindingAction('run')).toBe('runToggle');
    expect(bindingAction('off')).toBeNull();
  });
});
