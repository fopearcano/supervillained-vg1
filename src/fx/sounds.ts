import { noteFreq, renderVoice, type Sound } from '../core/synth';

/** All sound effects, as synth recipes (sfxr-style chiptune). */
export const SOUNDS = {
  bark: [
    { at: 0, def: { wave: 'square', duty: 0.35, freq: 620, freqEnd: 260, attack: 0.005, sustain: 0.05, decay: 0.08, punch: 0.6, volume: 0.45, crush: 2 } },
    { at: 0.01, def: { wave: 'noise', freq: 1800, freqEnd: 700, attack: 0.002, sustain: 0.03, decay: 0.06, volume: 0.25 } },
    { at: 0.13, def: { wave: 'square', duty: 0.35, freq: 700, freqEnd: 300, attack: 0.005, sustain: 0.04, decay: 0.07, punch: 0.5, volume: 0.4, crush: 2 } },
  ],
  pee: { wave: 'noise', freq: 5200, freqEnd: 3800, attack: 0.04, sustain: 0.45, decay: 0.2, volume: 0.22, lowpass: 0.35, vibratoRate: 18, vibratoDepth: 0.2 },
  mark: [
    { at: 0, def: { wave: 'square', duty: 0.25, freq: noteFreq('C5'), attack: 0.005, sustain: 0.06, decay: 0.05, volume: 0.3 } },
    { at: 0.07, def: { wave: 'square', duty: 0.25, freq: noteFreq('E5'), attack: 0.005, sustain: 0.06, decay: 0.05, volume: 0.3 } },
    { at: 0.14, def: { wave: 'square', duty: 0.25, freq: noteFreq('G5'), attack: 0.005, sustain: 0.06, decay: 0.05, volume: 0.3 } },
    { at: 0.21, def: { wave: 'square', duty: 0.25, freq: noteFreq('C6'), attack: 0.005, sustain: 0.1, decay: 0.15, volume: 0.3 } },
    { at: 0, def: { wave: 'noise', freq: 5200, attack: 0.04, sustain: 0.5, decay: 0.2, volume: 0.16, lowpass: 0.35 } },
  ],
  poop: [
    { at: 0, def: { wave: 'square', duty: 0.5, freq: 180, freqEnd: 70, attack: 0.01, sustain: 0.12, decay: 0.18, volume: 0.45, crush: 3, vibratoRate: 30, vibratoDepth: 0.15 } },
    { at: 0.05, def: { wave: 'noise', freq: 400, freqEnd: 120, attack: 0.01, sustain: 0.1, decay: 0.15, volume: 0.3, lowpass: 0.3 } },
  ],
  treat: [
    { at: 0, def: { wave: 'square', duty: 0.25, freq: noteFreq('E6'), attack: 0.002, sustain: 0.04, decay: 0.04, volume: 0.28 } },
    { at: 0.05, def: { wave: 'square', duty: 0.25, freq: noteFreq('B6'), attack: 0.002, sustain: 0.06, decay: 0.12, volume: 0.28 } },
  ],
  cat: [
    { at: 0, def: { wave: 'saw', freq: 700, freqEnd: 1100, attack: 0.03, sustain: 0.08, decay: 0.05, volume: 0.22, vibratoRate: 9, vibratoDepth: 0.05, lowpass: 0.4 } },
    { at: 0.15, def: { wave: 'saw', freq: 1100, freqEnd: 600, attack: 0.02, sustain: 0.1, decay: 0.15, volume: 0.22, vibratoRate: 9, vibratoDepth: 0.05, lowpass: 0.4 } },
    { at: 0.2, def: { wave: 'square', duty: 0.5, freq: noteFreq('B5'), attack: 0.002, sustain: 0.05, decay: 0.05, volume: 0.2, arp: [[0.05, 1.335]] } },
  ],
  coin: { wave: 'square', duty: 0.5, freq: noteFreq('B5'), attack: 0.002, sustain: 0.05, decay: 0.2, volume: 0.25, arp: [[0.05, 1.335]] },
  ball: [
    { at: 0, def: { wave: 'triangle', freq: 300, freqEnd: 600, attack: 0.002, sustain: 0.03, decay: 0.06, volume: 0.45 } },
    { at: 0.12, def: { wave: 'triangle', freq: 280, freqEnd: 520, attack: 0.002, sustain: 0.02, decay: 0.05, volume: 0.32 } },
    { at: 0.21, def: { wave: 'triangle', freq: 260, freqEnd: 480, attack: 0.002, sustain: 0.02, decay: 0.04, volume: 0.22 } },
  ],
  fetch: { wave: 'square', duty: 0.5, freq: 300, freqEnd: 900, attack: 0.01, sustain: 0.2, decay: 0.15, volume: 0.25, vibratoRate: 12, vibratoDepth: 0.1 },
  drink: [
    { at: 0, def: { wave: 'sine', freq: 500, freqEnd: 900, attack: 0.005, sustain: 0.04, decay: 0.04, volume: 0.35 } },
    { at: 0.1, def: { wave: 'sine', freq: 520, freqEnd: 960, attack: 0.005, sustain: 0.04, decay: 0.04, volume: 0.35 } },
    { at: 0.2, def: { wave: 'sine', freq: 560, freqEnd: 1100, attack: 0.005, sustain: 0.05, decay: 0.08, volume: 0.35 } },
  ],
  warning: [
    { at: 0, def: { wave: 'square', duty: 0.5, freq: noteFreq('A4'), attack: 0.005, sustain: 0.07, decay: 0.03, volume: 0.22 } },
    { at: 0.14, def: { wave: 'square', duty: 0.5, freq: noteFreq('A4'), attack: 0.005, sustain: 0.07, decay: 0.03, volume: 0.22 } },
  ],
  empty: { wave: 'square', duty: 0.5, freq: 200, freqEnd: 120, attack: 0.005, sustain: 0.08, decay: 0.08, volume: 0.25 },
  hurt: [
    { at: 0, def: { wave: 'square', duty: 0.5, freq: 400, freqEnd: 90, attack: 0.002, sustain: 0.1, decay: 0.2, volume: 0.35, crush: 4 } },
    { at: 0, def: { wave: 'noise', freq: 900, freqEnd: 200, attack: 0.002, sustain: 0.08, decay: 0.15, volume: 0.25 } },
  ],
  hit: [
    { at: 0, def: { wave: 'noise', freq: 2400, freqEnd: 300, attack: 0.002, sustain: 0.05, decay: 0.12, volume: 0.35 } },
    { at: 0, def: { wave: 'square', duty: 0.5, freq: 900, freqEnd: 200, attack: 0.002, sustain: 0.04, decay: 0.08, volume: 0.3 } },
  ],
  flee: { wave: 'square', duty: 0.25, freq: 300, freqEnd: 1600, attack: 0.01, sustain: 0.25, decay: 0.2, volume: 0.25, vibratoRate: 20, vibratoDepth: 0.06 },
  alarm: [
    { at: 0, def: { wave: 'square', duty: 0.5, freq: 520, freqEnd: 900, attack: 0.01, sustain: 0.32, decay: 0.05, volume: 0.25, crush: 2 } },
    { at: 0.4, def: { wave: 'square', duty: 0.5, freq: 520, freqEnd: 900, attack: 0.01, sustain: 0.32, decay: 0.05, volume: 0.25, crush: 2 } },
    { at: 0.8, def: { wave: 'square', duty: 0.5, freq: 520, freqEnd: 900, attack: 0.01, sustain: 0.32, decay: 0.1, volume: 0.25, crush: 2 } },
  ],
  saved: [
    { at: 0, def: { wave: 'square', duty: 0.25, freq: noteFreq('G5'), attack: 0.005, sustain: 0.08, decay: 0.04, volume: 0.28 } },
    { at: 0.1, def: { wave: 'square', duty: 0.25, freq: noteFreq('C6'), attack: 0.005, sustain: 0.08, decay: 0.04, volume: 0.28 } },
    { at: 0.2, def: { wave: 'square', duty: 0.25, freq: noteFreq('E6'), attack: 0.005, sustain: 0.2, decay: 0.2, volume: 0.28 } },
  ],
  star: { wave: 'square', duty: 0.25, freq: noteFreq('E6'), attack: 0.002, sustain: 0.06, decay: 0.25, volume: 0.28, arp: [[0.06, 1.5]] },
  jingle: [
    ...['C5', 'E5', 'G5', 'C6', 'G5', 'C6', 'E6'].map((n, i) => ({
      at: i * 0.11,
      def: { wave: 'square' as const, duty: 0.25, freq: noteFreq(n), attack: 0.005, sustain: i === 6 ? 0.3 : 0.07, decay: i === 6 ? 0.35 : 0.03, volume: 0.27 },
    })),
    { at: 0, def: { wave: 'triangle', freq: noteFreq('C3'), attack: 0.005, sustain: 0.6, decay: 0.4, volume: 0.35 } },
  ],
  gameover: [
    ...['G4', 'F#4', 'F4', 'E4'].map((n, i) => ({
      at: i * 0.32,
      def: { wave: 'square' as const, duty: 0.5, freq: noteFreq(n), attack: 0.01, sustain: i === 3 ? 0.5 : 0.22, decay: 0.12, volume: 0.28, vibratoRate: i === 3 ? 6 : 0, vibratoDepth: 0.03 },
    })),
  ],
  click: { wave: 'square', duty: 0.5, freq: 1200, attack: 0.001, sustain: 0.015, decay: 0.02, volume: 0.2 },
  glitch: { wave: 'noise', freq: 3000, freqEnd: 200, attack: 0.001, sustain: 0.08, decay: 0.12, volume: 0.25, crush: 6 },
} satisfies Record<string, Sound>;

export type SoundName = keyof typeof SOUNDS;

/**
 * Simple chiptune loop (C - Am - F - G), 8 bars at 132 BPM: square lead, triangle bass,
 * noise hats. Rendered once into a buffer that loops.
 */
export function renderMusic(sampleRate: number): Float32Array {
  const bpm = 132;
  const eighth = 60 / bpm / 2;
  const bars = 8;
  const out = new Float32Array(Math.ceil(bars * 8 * eighth * sampleRate));
  const lead = [
    'E5 G5 C6 G5 E5 G5 A5 G5',
    'E5 C5 E5 A5 G5 E5 C5 E5',
    'F5 A5 C6 A5 F5 A5 G5 F5',
    'D5 G5 B5 G5 D5 G5 A5 B5',
    'C6 B5 G5 E5 G5 C6 D6 C6',
    'A5 G5 E5 C5 E5 A5 G5 E5',
    'F5 A5 C6 F6 E6 C6 A5 C6',
    'B5 D6 G5 B5 D6 - G5 -',
  ];
  const bassRoots = ['C3', 'A2', 'F2', 'G2', 'C3', 'A2', 'F2', 'G2'];
  for (let bar = 0; bar < bars; bar++) {
    const notes = lead[bar]!.split(' ');
    notes.forEach((n, i) => {
      if (n === '-') return;
      const at = (bar * 8 + i) * eighth;
      renderVoice(
        { wave: 'square', duty: 0.25, freq: noteFreq(n), attack: 0.005, sustain: eighth * 0.55, decay: eighth * 0.35, volume: 0.13 },
        sampleRate,
        out,
        Math.floor(at * sampleRate),
      );
    });
    const root = noteFreq(bassRoots[bar]!);
    for (let i = 0; i < 8; i++) {
      const at = (bar * 8 + i) * eighth;
      renderVoice(
        { wave: 'triangle', freq: i % 2 ? root * 2 : root, attack: 0.004, sustain: eighth * 0.6, decay: eighth * 0.3, volume: 0.22 },
        sampleRate,
        out,
        Math.floor(at * sampleRate),
      );
      // Hats on every eighth, accented off-beats; kick on beats 1 and 3.
      renderVoice(
        { wave: 'noise', freq: 8000, attack: 0.001, sustain: 0.01, decay: 0.03, volume: i % 2 ? 0.07 : 0.035 },
        sampleRate,
        out,
        Math.floor(at * sampleRate),
        bar * 8 + i + 1,
      );
      if (i % 4 === 0) {
        renderVoice({ wave: 'sine', freq: 140, freqEnd: 45, attack: 0.002, sustain: 0.03, decay: 0.08, volume: 0.35 }, sampleRate, out, Math.floor(at * sampleRate));
      }
    }
  }
  for (let k = 0; k < out.length; k++) out[k] = Math.tanh(out[k]! * 1.1);
  return out;
}

/**
 * Medieval loop for the dream (D dorian): a recorder-like lead over a drone fifth and a tabor.
 * Estampie-ish, 6/8 feel, 8 bars.
 */
export function renderMedievalMusic(sampleRate: number): Float32Array {
  const bpm = 104;
  const beat = 60 / bpm / 2; // eighth notes, 6 per bar
  const bars = 8;
  const out = new Float32Array(Math.ceil(bars * 6 * beat * sampleRate));
  const lead = [
    'D5 E5 F5 E5 D5 A4',
    'C5 D5 E5 D5 C5 A4',
    'D5 F5 G5 A5 G5 F5',
    'E5 D5 C5 D5 - -',
    'A5 G5 F5 G5 A5 C6',
    'B5 A5 G5 A5 F5 E5',
    'D5 E5 F5 G5 E5 C5',
    'D5 - A4 D5 - -',
  ];
  for (let bar = 0; bar < bars; bar++) {
    lead[bar]!.split(' ').forEach((n, i) => {
      if (n === '-') return;
      const at = (bar * 6 + i) * beat;
      renderVoice(
        { wave: 'triangle', freq: noteFreq(n), attack: 0.02, sustain: beat * 0.7, decay: beat * 0.25, volume: 0.2, vibratoRate: 5, vibratoDepth: 0.012 },
        sampleRate,
        out,
        Math.floor(at * sampleRate),
      );
    });
    // Drone: D3 + A3, re-struck each bar.
    for (const n of ['D3', 'A3']) {
      renderVoice({ wave: 'saw', freq: noteFreq(n), attack: 0.08, sustain: beat * 5.2, decay: beat * 0.6, volume: 0.05, lowpass: 0.08 }, sampleRate, out, Math.floor(bar * 6 * beat * sampleRate));
    }
    // Tabor: strong on 1 and 4, light on 6.
    for (const [i, v] of [
      [0, 0.32],
      [3, 0.24],
      [5, 0.1],
    ] as const) {
      renderVoice({ wave: 'sine', freq: 120, freqEnd: 60, attack: 0.002, sustain: 0.02, decay: 0.09, volume: v }, sampleRate, out, Math.floor((bar * 6 + i) * beat * sampleRate));
      renderVoice({ wave: 'noise', freq: 2400, attack: 0.001, sustain: 0.01, decay: 0.04, volume: v * 0.25 }, sampleRate, out, Math.floor((bar * 6 + i) * beat * sampleRate), bar * 6 + i + 3);
    }
  }
  for (let k = 0; k < out.length; k++) out[k] = Math.tanh(out[k]! * 1.1);
  return out;
}
