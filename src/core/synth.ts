/**
 * Tiny sfxr-style synthesizer. Pure functions that render samples into a Float32Array, so the
 * sounds are deterministic, cheap to play (pre-rendered AudioBuffers) and unit-testable.
 */

export type Wave = 'square' | 'saw' | 'triangle' | 'sine' | 'noise';

export interface SfxDef {
  wave: Wave;
  /** Square duty cycle 0..1 (default 0.5). */
  duty?: number;
  /** Start frequency (Hz). */
  freq: number;
  /** End frequency (Hz): exponential slide over the whole sound. */
  freqEnd?: number;
  attack: number;
  sustain: number;
  decay: number;
  /** Extra loudness during sustain (0..1). */
  punch?: number;
  vibratoRate?: number;
  /** Vibrato depth as a fraction of the frequency. */
  vibratoDepth?: number;
  /** Frequency multipliers applied from a given time on: [time, multiplier]. */
  arp?: Array<[number, number]>;
  volume?: number;
  /** One-pole low-pass amount 0..1 (1 = off). */
  lowpass?: number;
  /** Sample-and-hold factor for a crunchy, lo-fi sound (1 = off). */
  crush?: number;
}

export interface SfxPart {
  at: number;
  def: SfxDef;
}

export type Sound = SfxDef | SfxPart[];

/** Deterministic PRNG for noise (so renders are reproducible). */
function noiseGen(seed: number): () => number {
  let s = seed >>> 0 || 1;
  return () => {
    s ^= s << 13;
    s ^= s >>> 17;
    s ^= s << 5;
    return ((s >>> 0) / 4294967296) * 2 - 1;
  };
}

export function soundDuration(sound: Sound): number {
  if (Array.isArray(sound)) return Math.max(0, ...sound.map((p) => p.at + p.def.attack + p.def.sustain + p.def.decay));
  return sound.attack + sound.sustain + sound.decay;
}

/** Renders one voice, mixing into `out` starting at sample `offset`. */
export function renderVoice(def: SfxDef, sampleRate: number, out: Float32Array, offset = 0, seed = 1): void {
  const total = def.attack + def.sustain + def.decay;
  const n = Math.floor(total * sampleRate);
  const noise = noiseGen(seed);
  let phase = 0;
  let noiseValue = noise();
  let lp = 0;
  let held = 0;
  const crush = Math.max(1, Math.floor(def.crush ?? 1));
  const vol = def.volume ?? 0.5;
  const duty = def.duty ?? 0.5;
  const lpA = def.lowpass ?? 1;
  const f0 = def.freq;
  const f1 = def.freqEnd ?? def.freq;
  for (let k = 0; k < n && offset + k < out.length; k++) {
    const t = k / sampleRate;
    // Envelope
    let env: number;
    if (t < def.attack) env = t / Math.max(1e-6, def.attack);
    else if (t < def.attack + def.sustain) env = 1 + (def.punch ?? 0) * (1 - (t - def.attack) / Math.max(1e-6, def.sustain));
    else env = Math.max(0, 1 - (t - def.attack - def.sustain) / Math.max(1e-6, def.decay));
    // Frequency: exponential slide, vibrato, arpeggio
    let f = f0 * Math.pow(f1 / f0, t / total);
    if (def.vibratoRate && def.vibratoDepth) f *= 1 + Math.sin(t * def.vibratoRate * Math.PI * 2) * def.vibratoDepth;
    if (def.arp) for (const [at, mul] of def.arp) if (t >= at) f = f * mul;
    const prev = phase;
    phase = (phase + f / sampleRate) % 1;
    let v: number;
    switch (def.wave) {
      case 'square':
        v = phase < duty ? 1 : -1;
        break;
      case 'saw':
        v = phase * 2 - 1;
        break;
      case 'triangle':
        v = phase < 0.5 ? phase * 4 - 1 : 3 - phase * 4;
        break;
      case 'sine':
        v = Math.sin(phase * Math.PI * 2);
        break;
      case 'noise':
        if (phase < prev) noiseValue = noise();
        v = noiseValue;
        break;
    }
    lp += (v - lp) * lpA;
    if (k % crush === 0) held = lp;
    out[offset + k]! += held * env * vol;
  }
}

/** Renders a full sound (single voice or several parts) into a new buffer, soft-clipped. */
export function renderSound(sound: Sound, sampleRate: number): Float32Array {
  const out = new Float32Array(Math.ceil(soundDuration(sound) * sampleRate) + 1);
  if (Array.isArray(sound)) sound.forEach((p, i) => renderVoice(p.def, sampleRate, out, Math.floor(p.at * sampleRate), 7 + i));
  else renderVoice(sound, sampleRate, out);
  for (let k = 0; k < out.length; k++) out[k] = Math.tanh(out[k]!);
  return out;
}

/** Note name (e.g. 'A4', 'C#5') to frequency. */
export function noteFreq(note: string): number {
  const m = /^([A-G])(#?)(-?\d)$/.exec(note);
  if (!m) throw new Error(`bad note ${note}`);
  const semis: Record<string, number> = { C: -9, D: -7, E: -5, F: -4, G: -2, A: 0, B: 2 };
  const n = semis[m[1]!]! + (m[2] ? 1 : 0) + (Number(m[3]) - 4) * 12;
  return 440 * Math.pow(2, n / 12);
}
