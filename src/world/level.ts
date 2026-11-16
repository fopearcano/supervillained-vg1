import { Ground, LEGEND, type PropKind } from './tiles';

/** Colors used by the code-generated tile/prop textures of a zone. */
export type Swatch = [base: string, dark: string, light: string];

export interface Palette {
  grass: [base: string, dark: string, light: string];
  tallGrass: [base: string, dark: string, light: string];
  path: [base: string, dark: string, light: string];
  water: [base: string, dark: string, light: string];
  forest: [base: string, dark: string, light: string];
  foliage: [dark: string, mid: string, light: string];
  pollution: [base: string, dark: string, light: string];
  flowers: string[];
  /** Story themes (optional; sensible defaults are used when missing). */
  floor?: Swatch;
  stone?: Swatch;
  sand?: Swatch;
  snow?: Swatch;
  deep?: Swatch;
  wall?: Swatch;
  roof?: Swatch;
  cloth?: Swatch;
  dock?: Swatch;
  carpet?: Swatch;
}

export interface SpawnSettings {
  treats: {
    count: number;
    /** Max lateral distance (tiles) of a treat from the path. */
    maxOffset: number;
    /** Min distance (tiles) between treats. */
    minSpacing: number;
  };
  cats: {
    /** Seconds before the first cat. */
    first: number;
    /** Random delay range between cats. */
    interval: [number, number];
    max: number;
  };
  balls: {
    first: number;
    interval: [number, number];
    max: number;
  };
}

export interface EventSettings {
  underAttack: {
    /** Overrides config ATTACK.HEALTH_THRESHOLD when set. */
    threshold?: number;
    /** Level progress (0..1 along start→exit) at which a scripted attack starts; null = none. */
    scriptedProgress: number | null;
    bagnaskizHits: number;
  };
}

/** Where the map comes from. Only ASCII is implemented; Tiled is reserved for later. */
export type LevelSource =
  | { format: 'ascii'; rows: readonly string[] }
  | { format: 'tiled'; url: string };

export interface LevelDef {
  id: string;
  number: number;
  zoneName: string;
  palette: Palette;
  source: LevelSource;
  /** RNG seed for deterministic treat placement and decoration. */
  seed: number;
  /** Seconds; finishing faster earns a time bonus. */
  parTime: number;
  spawns: SpawnSettings;
  events: EventSettings;
}

export interface PropPlacement {
  kind: PropKind;
  i: number;
  j: number;
}

/** Engine-facing, format-independent level description (what any loader must produce). */
export interface LevelData {
  /** The arcade level definition (absent for story maps). */
  def?: LevelDef;
  width: number;
  height: number;
  /** Row-major ground types, index = j * width + i (j = gy row, i = gx column). */
  ground: Uint8Array;
  props: PropPlacement[];
  start: { i: number; j: number };
  exit: { i: number; j: number };
  /** Digit markers ('0'..'9') used by story scripts. */
  markers: Record<string, { i: number; j: number }>;
}

export interface ParseOptions {
  /** Ground symbol used under props, markers, S and E (default '.'). */
  base?: string;
  /** Require an exit 'E' (default true). Without it, the exit is the start. */
  requireExit?: boolean;
}

export class LevelFormatError extends Error {}

/**
 * Parses an ASCII map. Rows are gy (top to bottom), columns are gx (left to right).
 * Shorter rows are padded with void.
 */
export function parseAsciiMap(rows: readonly string[], opts: ParseOptions = {}): Omit<LevelData, 'def'> {
  const baseEntry = LEGEND[opts.base ?? '.'];
  if (!baseEntry || baseEntry.ground === 'base') throw new LevelFormatError(`Bad base ground '${opts.base}'`);
  const baseGround = baseEntry.ground;
  const markers: Record<string, { i: number; j: number }> = {};
  const height = rows.length;
  if (height === 0) throw new LevelFormatError('Empty map');
  const width = Math.max(...rows.map((r) => r.length));
  const ground = new Uint8Array(width * height);
  const props: PropPlacement[] = [];
  let start: { i: number; j: number } | null = null;
  let exit: { i: number; j: number } | null = null;

  for (let j = 0; j < height; j++) {
    const row = rows[j]!;
    for (let i = 0; i < width; i++) {
      const ch = i < row.length ? row[i]! : ' ';
      if (ch >= '0' && ch <= '9') {
        ground[j * width + i] = baseGround;
        markers[ch] = { i, j };
        continue;
      }
      const entry = LEGEND[ch];
      if (!entry) throw new LevelFormatError(`Unknown map symbol '${ch}' at row ${j}, column ${i}`);
      ground[j * width + i] = entry.ground === 'base' ? baseGround : entry.ground;
      if (entry.prop) props.push({ kind: entry.prop, i, j });
      if (entry.marker === 'start') {
        if (start) throw new LevelFormatError(`Duplicate start 'S' at row ${j}, column ${i}`);
        start = { i, j };
      } else if (entry.marker === 'exit') {
        if (exit) throw new LevelFormatError(`Duplicate exit 'E' at row ${j}, column ${i}`);
        exit = { i, j };
      }
    }
  }
  if (!start) throw new LevelFormatError("Map has no start 'S'");
  if (!exit && opts.requireExit !== false) throw new LevelFormatError("Map has no exit 'E'");
  return { width, height, ground, props, start, exit: exit ?? { ...start }, markers };
}

/**
 * Turns a level definition into engine data. New formats (e.g. a Tiled isometric JSON importer)
 * plug in here and must return the same LevelData shape.
 */
export function loadLevel(def: LevelDef): LevelData {
  switch (def.source.format) {
    case 'ascii':
      return { def, ...parseAsciiMap(def.source.rows) };
    case 'tiled':
      throw new LevelFormatError('Tiled import is not implemented yet');
  }
}

export function groundAt(level: Pick<LevelData, 'width' | 'height' | 'ground'>, i: number, j: number): Ground {
  if (i < 0 || j < 0 || i >= level.width || j >= level.height) return Ground.Void;
  return level.ground[j * level.width + i] as Ground;
}
