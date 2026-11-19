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
