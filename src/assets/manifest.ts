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
} satisfies Record<string, CharacterDef>;

export type CharacterKey = keyof typeof CHARACTERS;

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
  ball: { key: 'ball', w: 7, h: 7, anchorX: 3, anchorY: 6, variants: 1 },
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
