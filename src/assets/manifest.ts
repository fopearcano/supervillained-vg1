import type { Dir8 } from '../iso/projection';

/**
 * Sprite manifest: the single place that describes every sprite the game uses.
 *
 * Game logic only ever asks for textures by name (see `textureName`). Each entry here says
 * how big a frame is, where its anchor is, which animations/directions exist and — optionally —
 * which PNG to load instead of the code-generated placeholder. See ASSETS.md.
 *
 * Texture names:
 *   characters: `${key}_${anim}_${dir}_${frame}`   e.g. zampano_walk_NE_2
 *   sprites:    `${key}_${variant}`                e.g. tree_1
 */

export const ANIMS = ['idle', 'walk', 'run', 'sniff', 'pee', 'poop', 'eat', 'bark', 'fetch', 'hurt'] as const;
export type AnimName = (typeof ANIMS)[number];

/** Row order of directions inside a sprite sheet. */
export const SHEET_DIRS: readonly Dir8[] = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

export interface AnimDef {
  frames: number;
  fps: number;
  loop: boolean;
}

export interface CharacterDef {
  key: string;
  frameW: number;
  frameH: number;
  /** Anchor in pixels from the frame's top-left: the ground contact point between the feet. */
  anchorX: number;
  anchorY: number;
  anims: Partial<Record<AnimName, AnimDef>>;
  /**
   * Optional sprite sheet (path relative to /public). Layout: one row per (anim, dir) in the
   * order of `anims` (as listed here) x SHEET_DIRS, one column per frame. Missing → placeholder.
   */
  sheet?: string;
}

export interface SpriteDef {
  key: string;
  w: number;
  h: number;
  anchorX: number;
  anchorY: number;
  variants: number;
  /** Optional PNG strip (variants side by side, each w x h), path relative to /public. */
  file?: string;
}

/** The story cast (generated on demand; same 40x40 frame and anchor as Zampanò). */
export const CAST_KEYS = [
  'zampanoCross',
  'zampanoKnight',
  'sbrimbrulon',
  'jack',
  'watson',
  'santina',
  'confusione',
  'doge',
  'king',
  'emir',
  'legate',
  'cellarer',
  'clerkA',
  'clerkB',
  'preacher',
  'stranger',
  'lady',
  'greek',
  'knight',
  'varangian',
  'marquis',
  'prince',
  'burgher',
  'crowdA',
  'crowdB',
  'crowdC',
  'bagnaskizMarshal',
  'bagnaskizEmperor',
  'bear',
  'leopard',
  'hound',
] as const;
export type CastKey = (typeof CAST_KEYS)[number];
export type CharacterKey = 'zampano' | 'bagnaskiz' | 'cat' | CastKey;

/** Story characters: idle / walk / run / bark, 40x40, anchored like Zampanò. */
function castDefs<K extends string>(keys: readonly K[]): Record<K, CharacterDef> {
  const out = {} as Record<K, CharacterDef>;
  for (const key of keys) {
    out[key] = {
      key,
      frameW: 40,
      frameH: 40,
      anchorX: 20,
      anchorY: 36,
      anims:
        key === 'zampanoCross' || key === 'zampanoKnight'
          ? {
              idle: { frames: 2, fps: 3, loop: true },
              walk: { frames: 4, fps: 9, loop: true },
              run: { frames: 4, fps: 13, loop: true },
              sniff: { frames: 2, fps: 5, loop: true },
              pee: { frames: 2, fps: 6, loop: true },
              poop: { frames: 2, fps: 3, loop: true },
              eat: { frames: 2, fps: 8, loop: true },
              bark: { frames: 2, fps: 10, loop: false },
              fetch: { frames: 4, fps: 13, loop: true },
              hurt: { frames: 2, fps: 10, loop: true },
            }
          : {
              idle: { frames: 2, fps: 3, loop: true },
              walk: { frames: 4, fps: 9, loop: true },
              run: { frames: 4, fps: 13, loop: true },
              bark: { frames: 2, fps: 8, loop: true },
              hurt: { frames: 2, fps: 10, loop: true },
            },
    };
  }
  return out;
}

export const CHARACTERS = {
  zampano: {
    key: 'zampano',
    frameW: 40,
    frameH: 40,
    anchorX: 20,
    anchorY: 36,
    anims: {
      idle: { frames: 2, fps: 3, loop: true },
      walk: { frames: 4, fps: 9, loop: true },
      run: { frames: 4, fps: 13, loop: true },
      sniff: { frames: 2, fps: 5, loop: true },
      pee: { frames: 2, fps: 6, loop: true },
      poop: { frames: 2, fps: 3, loop: true },
      eat: { frames: 2, fps: 8, loop: true },
      bark: { frames: 2, fps: 10, loop: false },
      fetch: { frames: 4, fps: 13, loop: true },
      hurt: { frames: 2, fps: 10, loop: true },
    },
  },
  bagnaskiz: {
    key: 'bagnaskiz',
    frameW: 40,
    frameH: 40,
    anchorX: 20,
    anchorY: 36,
    anims: {
      idle: { frames: 2, fps: 3, loop: true },
      walk: { frames: 4, fps: 9, loop: true },
      run: { frames: 4, fps: 13, loop: true },
      bark: { frames: 2, fps: 8, loop: true },
      hurt: { frames: 2, fps: 10, loop: true },
    },
  },
  cat: {
    key: 'cat',
    frameW: 28,
    frameH: 28,
    anchorX: 14,
    anchorY: 25,
    anims: {
      idle: { frames: 2, fps: 3, loop: true },
      walk: { frames: 4, fps: 9, loop: true },
      run: { frames: 4, fps: 14, loop: true },
    },
  },
  ...castDefs(CAST_KEYS),
} satisfies Record<string, CharacterDef> as Record<CharacterKey, CharacterDef>;

export const SPRITES = {
  // Props (level palette)
  tree: { key: 'tree', w: 40, h: 60, anchorX: 20, anchorY: 56, variants: 3 },
  forestTree: { key: 'forestTree', w: 36, h: 56, anchorX: 18, anchorY: 52, variants: 2 },
  bush: { key: 'bush', w: 26, h: 18, anchorX: 13, anchorY: 14, variants: 2 },
  pole: { key: 'pole', w: 12, h: 52, anchorX: 6, anchorY: 50, variants: 1 },
  fountain: { key: 'fountain', w: 18, h: 26, anchorX: 9, anchorY: 22, variants: 1 },
  exitFlag: { key: 'exitFlag', w: 26, h: 40, anchorX: 6, anchorY: 38, variants: 1 },
  // Items
  treat: { key: 'treat', w: 13, h: 8, anchorX: 6, anchorY: 7, variants: 1 },
  ball: { key: 'ball', w: 9, h: 9, anchorX: 4, anchorY: 8, variants: 1 },
  poop: { key: 'poop', w: 10, h: 9, anchorX: 5, anchorY: 8, variants: 1 },
  coin: { key: 'coin', w: 7, h: 7, anchorX: 3, anchorY: 3, variants: 1 },
  // Shadows
  shadow: { key: 'shadow', w: 20, h: 7, anchorX: 10, anchorY: 3, variants: 1 },
  shadowSmall: { key: 'shadowSmall', w: 10, h: 4, anchorX: 5, anchorY: 2, variants: 1 },
  shadowBig: { key: 'shadowBig', w: 24, h: 8, anchorX: 12, anchorY: 4, variants: 1 },
  // FX / popups
  rainbow: { key: 'rainbow', w: 26, h: 14, anchorX: 13, anchorY: 13, variants: 1 },
  thought: { key: 'thought', w: 13, h: 14, anchorX: 6, anchorY: 13, variants: 1 },
  wave: { key: 'wave', w: 16, h: 16, anchorX: 8, anchorY: 8, variants: 8 },
  sparkle: { key: 'sparkle', w: 5, h: 5, anchorX: 2, anchorY: 2, variants: 1 },
  tri: { key: 'tri', w: 7, h: 6, anchorX: 3, anchorY: 3, variants: 1 },
  cross: { key: 'cross', w: 5, h: 5, anchorX: 2, anchorY: 2, variants: 1 },
  ring: { key: 'ring', w: 6, h: 6, anchorX: 3, anchorY: 3, variants: 1 },
  pixel: { key: 'pixel', w: 2, h: 2, anchorX: 1, anchorY: 1, variants: 1 },
  // HUD
  star: { key: 'star', w: 11, h: 11, anchorX: 0, anchorY: 0, variants: 3 },
  dogFace: { key: 'dogFace', w: 17, h: 14, anchorX: 0, anchorY: 0, variants: 1 },
  peeIcon: { key: 'peeIcon', w: 9, h: 11, anchorX: 4, anchorY: 5, variants: 1 },
  barkIcon: { key: 'barkIcon', w: 13, h: 11, anchorX: 6, anchorY: 5, variants: 1 },
  drop: { key: 'drop', w: 5, h: 7, anchorX: 2, anchorY: 3, variants: 2 },
  // Story props (zone palette)
  column: { key: 'column', w: 16, h: 52, anchorX: 8, anchorY: 48, variants: 1 },
  desk: { key: 'desk', w: 40, h: 30, anchorX: 20, anchorY: 22, variants: 1 },
  shelf: { key: 'shelf', w: 32, h: 48, anchorX: 16, anchorY: 42, variants: 1 },
  house: { key: 'house', w: 40, h: 58, anchorX: 20, anchorY: 48, variants: 2 },
  tent: { key: 'tent', w: 40, h: 40, anchorX: 20, anchorY: 34, variants: 2 },
  galley: { key: 'galley', w: 72, h: 60, anchorX: 36, anchorY: 44, variants: 2 },
  rock: { key: 'rock', w: 24, h: 18, anchorX: 12, anchorY: 14, variants: 1 },
  statue: { key: 'statue', w: 20, h: 50, anchorX: 10, anchorY: 46, variants: 1 },
  crate: { key: 'crate', w: 20, h: 20, anchorX: 10, anchorY: 16, variants: 1 },
  palm: { key: 'palm', w: 36, h: 56, anchorX: 18, anchorY: 52, variants: 1 },
  altar: { key: 'altar', w: 28, h: 26, anchorX: 14, anchorY: 20, variants: 1 },
  stall: { key: 'stall', w: 36, h: 40, anchorX: 18, anchorY: 32, variants: 1 },
  throne: { key: 'throne', w: 28, h: 40, anchorX: 14, anchorY: 34, variants: 1 },
  vine: { key: 'vine', w: 26, h: 24, anchorX: 13, anchorY: 20, variants: 1 },
  gate: { key: 'gate', w: 64, h: 66, anchorX: 32, anchorY: 58, variants: 1 },
  bones: { key: 'bones', w: 22, h: 10, anchorX: 11, anchorY: 6, variants: 1 },
  table: { key: 'table', w: 40, h: 24, anchorX: 20, anchorY: 16, variants: 1 },
  wallBlock: { key: 'wallBlock', w: 32, h: 40, anchorX: 16, anchorY: 32, variants: 2 },
  // Story specials (palette-independent)
  legs: { key: 'legs', w: 28, h: 64, anchorX: 14, anchorY: 62, variants: 4 },
  fortune: { key: 'fortune', w: 26, h: 66, anchorX: 13, anchorY: 63, variants: 2 },
  falcon: { key: 'falcon', w: 18, h: 12, anchorX: 9, anchorY: 6, variants: 2 },
  stag: { key: 'stag', w: 48, h: 46, anchorX: 24, anchorY: 42, variants: 1 },
  shard: { key: 'shard', w: 9, h: 13, anchorX: 4, anchorY: 12, variants: 1 },
  relic: { key: 'relic', w: 12, h: 12, anchorX: 6, anchorY: 11, variants: 1 },
  banner: { key: 'banner', w: 12, h: 26, anchorX: 2, anchorY: 25, variants: 2 },
  flame: { key: 'flame', w: 16, h: 22, anchorX: 8, anchorY: 20, variants: 3 },
  professorFace: { key: 'professorFace', w: 24, h: 24, anchorX: 0, anchorY: 0, variants: 1 },
  bee: { key: 'bee', w: 5, h: 4, anchorX: 2, anchorY: 2, variants: 1 },
  tear: { key: 'tear', w: 5, h: 7, anchorX: 2, anchorY: 3, variants: 1 },
  mask: { key: 'mask', w: 9, h: 7, anchorX: 4, anchorY: 3, variants: 1 },
  halo: { key: 'halo', w: 9, h: 7, anchorX: 4, anchorY: 3, variants: 1 },
} satisfies Record<string, SpriteDef>;

export type SpriteKey = keyof typeof SPRITES;

export function textureName(key: string, anim: AnimName, dir: Dir8, frame: number): string {
  return `${key}_${anim}_${dir}_${frame}`;
}

export function spriteName(key: SpriteKey, variant = 0): string {
  return `${key}_${variant}`;
}

/** Ground tile texture names (generated per level palette). */
export const TILE_VARIANTS = {
  grass: 4,
  tallGrass: 3,
  water: 2,
  forest: 3,
  /** Path: 16 edge masks x 2 variants → `path_${mask}_${v}`. */
  path: 2,
  dirt: 4,
} as const;
