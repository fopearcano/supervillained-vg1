import { STORY } from '../config';
import { storage } from '../core/storage';

/**
 * The story campaign's persistent state and its rules (pure, unit-tested).
 *
 * Meters (VG1 "systems taken from the board"):
 *  - Commozione: filled by weeping, wonder and caring; actions spend it; an unmoved Zampanò
 *    cannot act.
 *  - Supervillain: character; rises with nerve, comradeship and kept oaths. When full he cannot
 *    be pushed off the lawn.
 *  - Grace: Forms. Breaking a formal rule costs Grace even when every authority forgives.
 *  - Standing: what the camp thinks of him (dissent costs standing, not the level).
 */

export type MeterKey = 'commozione' | 'supervillain' | 'grace' | 'standing';
export type Ability = 'cross' | 'knight' | 'sermon';
export type FlagValue = string | number | boolean;

export interface Effects {
  commozione?: number;
  supervillain?: number;
  grace?: number;
  standing?: number;
  flags?: Record<string, FlagValue>;
  marvel?: string | string[];
  item?: string;
  value?: string;
  remembered?: string;
  shard?: string;
  unlock?: Ability;
  coins?: number;
}

export interface Book {
  /** Meraviglia: marvels found by looking. Each one becomes an object at home in 8.2. */
  marvels: string[];
  /** Things he carries home: the fresco, the identity card... */
  items: string[];
  /** Values learned (black holes and knightly scenes). */
  values: string[];
  /** The one line per dream scene that makes no sense, and is remembered. */
  remembered: string[];
  /** Scraps of the Professor's lecture, sniffed out in the study (1.2). */
  shards: string[];
}

export interface CampaignState {
  version: 1;
  completed: string[];
  meters: Record<MeterKey, number>;
  flags: Record<string, FlagValue>;
  book: Book;
  abilities: Ability[];
  coins: number;
}

export const METER_START: Readonly<Record<MeterKey, number>> = {
  commozione: 20,
  supervillain: 10,
  grace: 70,
  standing: 50,
};

export const METER_MAX = 100;

export function newCampaign(): CampaignState {
  return {
    version: 1,
    completed: [],
    meters: { ...METER_START },
    flags: {},
    book: { marvels: [], items: [], values: [], remembered: [], shards: [] },
    abilities: [],
    coins: 0,
  };
}

/** A human-readable change, used for popups ("+10 COMMOZIONE"). */
export interface Change {
  label: string;
  positive: boolean;
}

const METER_LABEL: Record<MeterKey, string> = {
  commozione: 'COMMOZIONE',
  supervillain: 'SUPERVILLAIN',
  grace: 'GRACE',
  standing: 'STANDING',
};

function addUnique(list: string[], v: string): boolean {
  if (list.includes(v)) return false;
  list.push(v);
  return true;
}

/** Applies effects in place and returns what changed. */
export function applyEffects(state: CampaignState, fx: Effects): Change[] {
  const out: Change[] = [];
  for (const key of ['commozione', 'supervillain', 'grace', 'standing'] as const) {
    const d = fx[key];
    if (!d) continue;
    const before = state.meters[key];
    state.meters[key] = Math.max(0, Math.min(METER_MAX, before + d));
    const real = state.meters[key] - before;
    if (real !== 0) out.push({ label: `${real > 0 ? '+' : ''}${real} ${METER_LABEL[key]}`, positive: real > 0 });
  }
  if (fx.flags) Object.assign(state.flags, fx.flags);
  for (const m of fx.marvel === undefined ? [] : Array.isArray(fx.marvel) ? fx.marvel : [fx.marvel]) {
    if (addUnique(state.book.marvels, m)) out.push({ label: `MARVEL: ${m.toUpperCase()}`, positive: true });
  }
  if (fx.item && addUnique(state.book.items, fx.item)) out.push({ label: `GOT: ${fx.item.toUpperCase()}`, positive: true });
  if (fx.value && addUnique(state.book.values, fx.value)) out.push({ label: `VALUE: ${fx.value.toUpperCase()}`, positive: true });
  if (fx.remembered) addUnique(state.book.remembered, fx.remembered);
  if (fx.shard && addUnique(state.book.shards, fx.shard)) out.push({ label: `SCRAP: ${fx.shard.toUpperCase()}`, positive: true });
  if (fx.unlock && !state.abilities.includes(fx.unlock)) {
    state.abilities.push(fx.unlock);
    out.push({ label: `UNLOCKED: ${fx.unlock.toUpperCase()}`, positive: true });
  }
  if (fx.coins) {
    state.coins = Math.max(0, state.coins + fx.coins);
    out.push({ label: `${fx.coins > 0 ? '+' : ''}${fx.coins} COINS`, positive: fx.coins > 0 });
  }
  return out;
}

/** Actions that need feeling: "an unmoved Zampanò cannot act". */
export function canSpend(state: CampaignState, meter: MeterKey, amount: number): boolean {
  return state.meters[meter] >= amount;
}

export function spend(state: CampaignState, meter: MeterKey, amount: number): boolean {
  if (!canSpend(state, meter, amount)) return false;
  state.meters[meter] -= amount;
  return true;
}

export function markComplete(state: CampaignState, id: string): void {
  if (!state.completed.includes(id)) state.completed.push(id);
}

export function isComplete(state: CampaignState, id: string): boolean {
  return state.completed.includes(id);
}

/** Supervillain full: he cannot be pushed off the lawn. */
export function unshakeable(state: CampaignState): boolean {
  return state.meters.supervillain >= METER_MAX;
}

/** The 7.8 choice decides the ending: he called the oath himself (knight), or stood silent (alpha: "the witness"). */
export type Ending = 'knight' | 'alpha';
export function ending(state: CampaignState): Ending {
  return state.flags.oath === 'enforced' ? 'knight' : 'alpha';
}

/** Skin Zampanò wears in the dream given his unlocked costume. */
export function dreamSkin(state: CampaignState): 'zampano' | 'zampanoCross' | 'zampanoKnight' {
  if (state.abilities.includes('knight')) return 'zampanoKnight';
  if (state.abilities.includes('cross')) return 'zampanoCross';
  return 'zampano';
}

/**
 * The feeling fades: every dream sub-level (levels 2 to 7) starts with a little less Commozione,
 * so wonder and weeping must keep filling it. Returns the amount actually lost.
 */
export function fadeCommozione(state: CampaignState, chapter: number): number {
  if (chapter < 2 || chapter > 7) return 0;
  const before = state.meters.commozione;
  state.meters.commozione = Math.max(0, before - STORY.COMMOZIONE_FADE);
  return before - state.meters.commozione;
}

/** Grace, as the 8.2 altar and the ending show it. */
export type GraceTier = 'high' | 'mid' | 'low';
export function graceTier(state: CampaignState): GraceTier {
  const g = state.meters.grace;
  return g >= STORY.GRACE.HIGH ? 'high' : g >= STORY.GRACE.LOW ? 'mid' : 'low';
}

/** Extra ending lines from Grace and Standing. */
export function endingNotes(state: CampaignState): string[] {
  const out: string[] = [];
  const tier = graceTier(state);
  out.push(
    tier === 'high'
      ? 'HE KEPT THE FORMS, EVEN WHEN EVERY AUTHORITY FORGAVE HIM. THE ALTAR UNDER THE DESK STILL GLOWS.'
      : tier === 'mid'
        ? 'HE KEPT MOST OF THE FORMS. THE ALTAR UNDER THE DESK IS A LITTLE CROOKED, LIKE HIM.'
        : 'HE BROKE THE FORMS AND NOBODY MINDED, EXCEPT THE BURGHER. THE ALTAR IS MADE OF CHEW TOYS.',
  );
  const st = state.meters.standing;
  out.push(
    st >= STORY.STANDING.FOND
      ? 'THE CAMP REMEMBERS HIM FONDLY. THE DOGS AT THE FENCES WATCH HIM DRINK AND SAY NOTHING.'
      : st >= STORY.STANDING.FAIR
        ? 'THE CAMP REMEMBERS HIM, MORE OR LESS.'
        : 'THE MARSHAL REMEMBERS WHO SPOKE AGAINST HIM. HE WALKED ON ANYWAY.',
  );
  return out;
}

const KEY = 'story';

export function loadCampaign(): CampaignState {
  const raw = storage.get<Partial<CampaignState> | null>(KEY, null);
  const base = newCampaign();
  if (!raw || raw.version !== 1) return base;
  return {
    ...base,
    ...raw,
    meters: { ...base.meters, ...(raw.meters ?? {}) },
    flags: { ...(raw.flags ?? {}) },
    book: { ...base.book, ...(raw.book ?? {}) },
    abilities: Array.isArray(raw.abilities) ? raw.abilities : [],
    completed: Array.isArray(raw.completed) ? raw.completed : [],
  };
}

export function saveCampaign(state: CampaignState): void {
  storage.set(KEY, state);
}

export function resetCampaign(): CampaignState {
  const s = newCampaign();
  saveCampaign(s);
  return s;
}
