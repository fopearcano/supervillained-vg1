import type { Span } from '../ui/pixelText';
import { C } from '../ui/retro';

/**
 * Names shown in yellow in the story's card texts (level intros, scene cards, the Professor,
 * the ending): the cast and the historical people. Whole words; a possessive ('S) counts.
 * Places are not names here.
 */
export const NAMES: ReadonlySet<string> = new Set([
  // The cast
  'ZAMPANO',
  'BAGNASKIZ',
  'SANTINA',
  'JACK',
  'WATSON',
  'SBRIMBRULON',
  'CONFUSIONE',
  'PROFESSOR',
  // History (the Fourth Crusade: docs/STORY.md)
  'ALEAUME',
  'ALEXIOS',
  'BONIFACE',
  'CHONIATES',
  'CLARI',
  'DANDOLO',
  'FULK',
  'GEOFFROI',
  'INNOCENT',
  'ISAAC',
  'MOURTZOUPHLOS',
  'NIKETAS',
  'PIERRE',
  "D'AMIENS",
  'ROBERT',
  'SAINT-POL',
  'VILLEHARDOUIN',
]);

/**
 * Period words the dream's characters use, taken from Alessandro Barbero's lecture on the Fourth
 * Crusade and the chronicles it quotes (docs/STORY-SOURCES.md, "Period words"). Shown in
 * OLD_WORD_COLOR in the dialogue box. Whole words; a longer phrase wins over a shorter one.
 */
export const OLD_WORDS: readonly string[] = [
  'THE HOLY VOYAGE',
  'THE GENERAL PASSAGE',
  'CRUCESIGNATI',
  'PILGRIMS',
  'MESSIRE',
  'DROMONS',
  'UISSIERS',
  'A WEIGHT OF SILVER',
  'OUR COMPANY',
  'IN THRALL TO THE TURKS',
  'OUTREMER',
  'THE LOMBARD',
  'LI RIKE HOMME',
  'LI POVRE CHEVALIER',
  'IN GOD\'S NAME',
  'THOSE OF THE WEST',
  'LATINS',
  'BARBARIANS',
  'ROMANS',
  'THE YEAR 6711',
  'ON THE SAINTS',
  'MERVEILLE',
];

/** Colour of the period words in the dialogue box (parchment amber; names in cards stay yellow). */
export const OLD_WORD_COLOR = '#ffb45a';

const isLetter = (ch: string | undefined): boolean => !!ch && /[A-Z0-9']/.test(ch);

/** [start, end) of every period word in `text`, in order, never overlapping. */
export function oldWordRanges(text: string): Array<[number, number]> {
  const found: Array<[number, number]> = [];
  const words = [...OLD_WORDS].sort((a, b) => b.length - a.length);
  for (const w of words) {
    for (let at = text.indexOf(w); at >= 0; at = text.indexOf(w, at + 1)) {
      const end = at + w.length;
      if (isLetter(text[at - 1]) || isLetter(text[end])) continue;
      if (found.some(([a, b]) => at < b && end > a)) continue;
      found.push([at, end]);
    }
  }
  return found.sort((a, b) => a[0] - b[0]);
}

/**
 * The first `shown` characters of a dialogue line as spans, with the period words in
 * `wordColor` (the typewriter reveals them already coloured).
 */
export function withOldWords(text: string, shown: number, color: string, wordColor: string = OLD_WORD_COLOR): Span[] {
  const spans: Span[] = [];
  const end = Math.max(0, Math.min(shown, text.length));
  let at = 0;
  for (const [a, b] of oldWordRanges(text)) {
    if (a >= end) break;
    if (a > at) spans.push({ text: text.slice(at, a), color });
    spans.push({ text: text.slice(a, Math.min(b, end)), color: wordColor });
    at = Math.min(b, end);
  }
  if (at < end) spans.push({ text: text.slice(at, end), color });
  return spans;
}

/** The text as spans, with the names in `nameColor`. */
export function withNames(text: string, color: string, nameColor: string = C.yellow): Span[] {
  const spans: Span[] = [];
  const push = (t: string, c: string) => {
    const last = spans[spans.length - 1];
    if (last && last.color === c) last.text += t;
    else spans.push({ text: t, color: c });
  };
  for (const part of text.split(/([A-Z][A-Z'-]*)/)) {
    if (!part) continue;
    const bare = part.replace(/'S$/, '').replace(/'$/, '');
    push(part, NAMES.has(bare) ? nameColor : color);
  }
  return spans;
}
