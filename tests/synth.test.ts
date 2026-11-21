import { describe, expect, it } from 'vitest';
import { noteFreq, renderSound, soundDuration } from '../src/core/synth';
import { SOUNDS, renderMedievalMusic } from '../src/fx/sounds';

describe('synth', () => {
  it('converts notes to frequencies', () => {
    expect(noteFreq('A4')).toBeCloseTo(440, 6);
    expect(noteFreq('A5')).toBeCloseTo(880, 6);
    expect(noteFreq('C4')).toBeCloseTo(261.63, 1);
    expect(noteFreq('C#4')).toBeCloseTo(277.18, 1);
    expect(() => noteFreq('H2')).toThrow();
  });

  it('renders every sound effect with bounded, non-silent samples', () => {
    for (const [name, sound] of Object.entries(SOUNDS)) {
      const data = renderSound(sound, 22050);
      expect(data.length, name).toBe(Math.ceil(soundDuration(sound) * 22050) + 1);
      let peak = 0;
      for (const v of data) {
        expect(Number.isFinite(v), name).toBe(true);
        peak = Math.max(peak, Math.abs(v));
      }
      expect(peak, name).toBeGreaterThan(0.05);
      expect(peak, name).toBeLessThanOrEqual(1);
      expect(soundDuration(sound), name).toBeLessThan(2.5);
    }
  });

  it('is deterministic', () => {
    expect(renderSound(SOUNDS.jingle, 22050)).toEqual(renderSound(SOUNDS.jingle, 22050));
  });

  it('renders the dream music loop (8 bars of 6 eighths at 104 bpm)', () => {
    const data = renderMedievalMusic(8000);
    expect(data.length / 8000).toBeCloseTo((8 * 6 * 60) / 104 / 2, 1);
    expect(data.every((v: number) => Number.isFinite(v) && Math.abs(v) <= 1)).toBe(true);
  });
});
