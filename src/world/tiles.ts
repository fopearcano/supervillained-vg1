/** Ground types (one per tile) and props (at most one per tile). */

export const Ground = {
  Void: 0,
  Grass: 1,
  Path: 2,
  TallGrass: 3,
  Water: 4,
  /** Dense forest border: never walkable. */
  Forest: 5,
  /** Wooden floor (study, ship deck). */
  Floor: 6,
  /** Stone / marble paving. */
  Stone: 7,
  Sand: 8,
  Snow: 9,
  /** Deep water (sea, lagoon): never walkable. */
  Deep: 10,
  /** City walls and buildings: never walkable, drawn as blocks. */
  Wall: 11,
  /** Wooden quay / pier planks. */
  Dock: 12,
  Carpet: 13,
} as const;
export type Ground = (typeof Ground)[keyof typeof Ground];

export type PropKind =
  | 'tree'
  | 'bush'
  | 'pole'
  | 'fountain'
  | 'forestTree'
  | 'column'
  | 'desk'
  | 'shelf'
  | 'house'
  | 'tent'
  | 'galley'
  | 'rock'
  | 'statue'
  | 'crate'
  | 'palm'
  | 'altar'
  | 'stall'
  | 'throne'
  | 'vine'
  | 'gate'
  | 'bones'
  | 'table';

export interface PropInfo {
  /** Blocks movement (as a circle at the tile center). */
  solid: boolean;
  /** Collision radius in tiles (if solid). */
  radius: number;
  /** Tall enough to hide Zampanò; fades when it does. */
  tall: boolean;
  /** Counts as a vertical object for marking (leg-lift pee). */
  vertical: boolean;
}

const P = (solid: boolean, radius: number, tall: boolean, vertical: boolean): PropInfo => ({ solid, radius, tall, vertical });

export const PROP_INFO: Record<PropKind, PropInfo> = {
  tree: P(true, 0.32, true, true),
  forestTree: P(true, 0.4, true, true),
  bush: P(false, 0, true, true),
  pole: P(true, 0.16, true, true),
  fountain: P(true, 0.36, false, true),
  column: P(true, 0.25, true, true),
  desk: P(true, 0.45, false, false),
  shelf: P(true, 0.45, true, false),
  house: P(true, 0.5, true, true),
  tent: P(true, 0.42, true, true),
  galley: P(true, 0.5, true, false),
  rock: P(true, 0.35, false, true),
  statue: P(true, 0.3, true, true),
  crate: P(true, 0.35, false, true),
  palm: P(true, 0.25, true, true),
  altar: P(true, 0.4, false, false),
  stall: P(true, 0.45, true, false),
  throne: P(true, 0.4, true, false),
  vine: P(false, 0, true, true),
  gate: P(true, 0.5, true, true),
  bones: P(false, 0, false, false),
  table: P(true, 0.42, false, false),
};

/** Sprite (manifest key) and variant count drawn for each prop kind. */
export const PROP_SPRITE: Record<PropKind, { key: string; variants: number }> = {
  tree: { key: 'tree', variants: 3 },
  forestTree: { key: 'forestTree', variants: 2 },
  bush: { key: 'bush', variants: 2 },
  pole: { key: 'pole', variants: 1 },
  fountain: { key: 'fountain', variants: 1 },
  column: { key: 'column', variants: 1 },
  desk: { key: 'desk', variants: 1 },
  shelf: { key: 'shelf', variants: 1 },
  house: { key: 'house', variants: 2 },
  tent: { key: 'tent', variants: 2 },
  galley: { key: 'galley', variants: 2 },
  rock: { key: 'rock', variants: 1 },
  statue: { key: 'statue', variants: 1 },
  crate: { key: 'crate', variants: 1 },
  palm: { key: 'palm', variants: 1 },
  altar: { key: 'altar', variants: 1 },
  stall: { key: 'stall', variants: 1 },
  throne: { key: 'throne', variants: 1 },
  vine: { key: 'vine', variants: 1 },
  gate: { key: 'gate', variants: 1 },
  bones: { key: 'bones', variants: 1 },
  table: { key: 'table', variants: 1 },
};

export interface LegendEntry {
  /** 'base' = the map's base ground (story maps choose it). */
  ground: Ground | 'base';
  prop?: PropKind;
  marker?: 'start' | 'exit';
}

/**
 * ASCII legend. Spec symbols plus documented extensions (see DECISIONS.md):
 *   ground: ','  tall grass   '_' wood floor   ':' stone   '-' sand   '*' snow
 *           '~' deep water    '%' wall/building   '^' dock planks   '+' carpet   ' ' void
 *   props (on the map's base ground): F fountain  C column  D desk  K bookshelf  H house
 *           N tent  G galley (on deep water)  R rock  U statue  X crate  Y palm  A altar
 *           M market stall  O throne  V vine/fig  Q city gate  Z bones  L table
 *   digits 0-9: named markers (on base ground) used by story scripts.
 */
export const LEGEND: Readonly<Record<string, LegendEntry>> = {
  '.': { ground: Ground.Grass },
  '=': { ground: Ground.Path },
  ',': { ground: Ground.TallGrass },
  T: { ground: Ground.Grass, prop: 'tree' },
  B: { ground: Ground.Grass, prop: 'bush' },
  P: { ground: 'base', prop: 'pole' },
  W: { ground: Ground.Water },
  F: { ground: 'base', prop: 'fountain' },
  S: { ground: 'base', marker: 'start' },
  E: { ground: 'base', marker: 'exit' },
  '#': { ground: Ground.Forest },
  ' ': { ground: Ground.Void },
  _: { ground: Ground.Floor },
  ':': { ground: Ground.Stone },
  '-': { ground: Ground.Sand },
  '*': { ground: Ground.Snow },
  '~': { ground: Ground.Deep },
  '%': { ground: Ground.Wall },
  '^': { ground: Ground.Dock },
  '+': { ground: Ground.Carpet },
  C: { ground: 'base', prop: 'column' },
  D: { ground: 'base', prop: 'desk' },
  K: { ground: 'base', prop: 'shelf' },
  H: { ground: 'base', prop: 'house' },
  N: { ground: 'base', prop: 'tent' },
  G: { ground: Ground.Deep, prop: 'galley' },
  R: { ground: 'base', prop: 'rock' },
  U: { ground: 'base', prop: 'statue' },
  X: { ground: 'base', prop: 'crate' },
  Y: { ground: 'base', prop: 'palm' },
  A: { ground: 'base', prop: 'altar' },
  M: { ground: 'base', prop: 'stall' },
  O: { ground: 'base', prop: 'throne' },
  V: { ground: 'base', prop: 'vine' },
  Q: { ground: 'base', prop: 'gate' },
  Z: { ground: 'base', prop: 'bones' },
  L: { ground: 'base', prop: 'table' },
};

export function isGroundWalkable(g: Ground): boolean {
  return g !== Ground.Void && g !== Ground.Forest && g !== Ground.Deep && g !== Ground.Wall;
}

/** Surfaces where a poop does little harm ("in bushes or tall grass"). */
export type PoopSurface = 'low' | 'medium' | 'heavy';
