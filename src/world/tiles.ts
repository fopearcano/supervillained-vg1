/** Ground types (one per tile) and props (at most one per tile). */

export const Ground = {
  Void: 0,
  Grass: 1,
  Path: 2,
  TallGrass: 3,
  Water: 4,
  /** Dense forest border: never walkable. */
  Forest: 5,
} as const;
export type Ground = (typeof Ground)[keyof typeof Ground];

export type PropKind = 'tree' | 'bush' | 'pole' | 'fountain' | 'forestTree';

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

export const PROP_INFO: Record<PropKind, PropInfo> = {
  tree: { solid: true, radius: 0.32, tall: true, vertical: true },
  forestTree: { solid: true, radius: 0.4, tall: true, vertical: true },
  bush: { solid: false, radius: 0, tall: true, vertical: true },
  pole: { solid: true, radius: 0.16, tall: true, vertical: true },
  fountain: { solid: true, radius: 0.36, tall: false, vertical: true },
};

export interface LegendEntry {
  ground: Ground;
  prop?: PropKind;
  marker?: 'start' | 'exit';
}

/**
 * ASCII legend. Spec symbols plus two documented extensions:
 *   ','  tall grass        'F'  drinking fountain (W is a puddle)
 *   ' '  void (nothing, outside the map)
 */
export const LEGEND: Readonly<Record<string, LegendEntry>> = {
  '.': { ground: Ground.Grass },
  '=': { ground: Ground.Path },
  ',': { ground: Ground.TallGrass },
  T: { ground: Ground.Grass, prop: 'tree' },
  B: { ground: Ground.Grass, prop: 'bush' },
  P: { ground: Ground.Grass, prop: 'pole' },
  W: { ground: Ground.Water },
  F: { ground: Ground.Grass, prop: 'fountain' },
  S: { ground: Ground.Path, marker: 'start' },
  E: { ground: Ground.Path, marker: 'exit' },
  '#': { ground: Ground.Forest },
  ' ': { ground: Ground.Void },
};

export function isGroundWalkable(g: Ground): boolean {
  return g !== Ground.Void && g !== Ground.Forest;
}

/** Surfaces where a poop does little harm ("in bushes or tall grass"). */
export type PoopSurface = 'low' | 'medium' | 'heavy';
