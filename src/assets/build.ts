import { packAtlas, subTexture, textures, tryLoadTexture, type AtlasEntry } from '../core/assets';
import { DIRS8, TW } from '../iso/projection';
import type { Palette } from '../world/level';
import type { TextureSource } from 'pixi.js';
import { drawCritter, drawShadow, poseFor } from './placeholders/critters';
import { CAST_SPECS } from './placeholders/cast';
import { drawSpecial, drawStoryProp, drawStoryTile } from './placeholders/storyArt';
import * as items from './placeholders/items';
import * as props from './placeholders/props';
import * as tiles from './placeholders/tiles';
import type { PixelBuffer } from './placeholders/pixel';
import {
  CHARACTERS,
  SHEET_DIRS,
  SPRITES,
  TILE_VARIANTS,
  spriteName,
  textureName,
  type AnimName,
  type CharacterDef,
  type SpriteDef,
  type SpriteKey,
} from './manifest';

/**
 * Builds every texture: loads optional final art listed in the manifest, and generates
 * placeholders for everything else.
 */

/** Characters generated at boot; the story cast is generated on demand (ensureCharacters). */
const BOOT_CHARACTERS = ['zampano', 'bagnaskiz', 'cat'];
const builtCharacters = new Set<string>();

function characterEntries(def: CharacterDef): AtlasEntry[] {
  const spec = CAST_SPECS[def.key]!;
  const entries: AtlasEntry[] = [];
  for (const [anim, ad] of Object.entries(def.anims) as Array<[AnimName, { frames: number }]>) {
    for (const dir of DIRS8) {
      for (let f = 0; f < ad.frames; f++) {
        entries.push({
          name: textureName(def.key, anim, dir, f),
          image: drawCritter(spec, dir, poseFor(anim, f)),
          anchorX: def.anchorX,
          anchorY: def.anchorY,
        });
      }
    }
  }
  return entries;
}

/** Makes sure the given characters have textures (loads their sheet or generates placeholders). */
export async function ensureCharacters(keys: Iterable<string>): Promise<void> {
  const entries: AtlasEntry[] = [];
  for (const key of keys) {
    if (builtCharacters.has(key)) continue;
    const def = (CHARACTERS as Record<string, CharacterDef>)[key];
    if (!def) continue;
    builtCharacters.add(key);
    if (def.sheet && (await loadCharacterSheet(def))) continue;
    entries.push(...characterEntries(def));
  }
  if (entries.length) packAtlas(entries, textures, 'cast');
}

function sprite(def: SpriteDef, variant: number, image: PixelBuffer): AtlasEntry {
  return { name: spriteName(def.key as SpriteKey, variant), image, anchorX: def.anchorX, anchorY: def.anchorY };
}

/** Palette-independent textures: characters, items, FX, HUD icons. */
export async function buildGlobalTextures(): Promise<void> {
  const entries: AtlasEntry[] = [];
  for (const key of BOOT_CHARACTERS) {
    const def = (CHARACTERS as Record<string, CharacterDef>)[key]!;
    builtCharacters.add(key);
    if (def.sheet && (await loadCharacterSheet(def))) continue;
    entries.push(...characterEntries(def));
  }
  const S = SPRITES;
  const gen: Array<[SpriteDef, (v: number) => PixelBuffer]> = [
    [S.treat, () => items.drawTreat()],
    [S.ball, () => items.drawBall()],
    [S.poop, () => items.drawPoop()],
    [S.coin, () => items.drawCoin()],
    [S.shadow, () => drawShadow(20, 7, 70)],
    [S.shadowSmall, () => drawShadow(10, 4, 70)],
    [S.shadowBig, () => drawShadow(24, 8, 60)],
    [S.rainbow, () => items.drawRainbow()],
    [S.thought, () => items.drawThought()],
    [S.wave, (v) => items.drawWave(DIRS8[v]!)],
    [S.sparkle, () => items.drawSparkle()],
    [S.tri, () => items.drawTri()],
    [S.cross, () => items.drawCross()],
    [S.ring, () => items.drawRing()],
    [S.pixel, () => items.drawPixel()],
    [S.star, (v) => items.drawStar(v)],
    [S.dogFace, () => items.drawDogFace()],
    [S.peeIcon, () => items.drawPeeIcon()],
    [S.barkIcon, () => items.drawBarkIcon()],
    [S.drop, (v) => items.drawDrop(v)],
    ...(['legs', 'fortune', 'falcon', 'stag', 'shard', 'relic', 'bowl', 'banner', 'flame', 'professorFace', 'bee', 'tear', 'mask', 'halo'] as const).map(
      (k) => [S[k], (v: number) => drawSpecial(k, v)] as [SpriteDef, (v: number) => PixelBuffer],
    ),
    [S.pole, () => props.drawPole()],
    [S.fountain, () => props.drawFountain()],
    [S.exitFlag, () => props.drawExitFlag()],
  ];
  for (const [def, draw] of gen) {
    if (def.file && (await loadSpriteStrip(def))) continue;
    for (let v = 0; v < def.variants; v++) entries.push(sprite(def, v, draw(v)));
  }
  packAtlas(entries, textures, 'global');
}

let builtPalette = '';
/** Atlases of the last two palettes: older ones are destroyed (their scenes are gone). */
const paletteAtlases: TextureSource[][] = [];

const STORY_TILES = ['floor', 'stone', 'sand', 'snow', 'deep', 'dock', 'carpet', 'wallBase'] as const;
const STORY_PROPS = [
  'column',
  'desk',
  'shelf',
  'house',
  'tent',
  'galley',
  'rock',
  'statue',
  'crate',
  'palm',
  'altar',
  'stall',
  'throne',
  'vine',
  'gate',
  'wicket',
  'bones',
  'table',
  'wallBlock',
] as const;

/** Zone-specific textures: ground tiles and props, colored by the level palette. */
export function buildLevelTextures(pal: Palette): void {
  const key = JSON.stringify(pal);
  if (key === builtPalette) return;
  builtPalette = key;
  const entries: AtlasEntry[] = [];
  const tile = (name: string, image: PixelBuffer, anchorY = 0) => entries.push({ name, image, anchorX: TW / 2, anchorY });
  for (let v = 0; v < TILE_VARIANTS.grass; v++) tile(`grass_${v}`, tiles.drawGrass(pal, v));
  for (let v = 0; v < TILE_VARIANTS.tallGrass; v++) tile(`tallGrass_${v}`, tiles.drawTallGrass(pal, v), tiles.TALL_GRASS_OFFSET);
  for (let v = 0; v < TILE_VARIANTS.water; v++) tile(`water_${v}`, tiles.drawWater(pal, v));
  for (let v = 0; v < TILE_VARIANTS.forest; v++) tile(`forest_${v}`, tiles.drawForest(pal, v));
  for (let m = 0; m < 16; m++) for (let v = 0; v < TILE_VARIANTS.path; v++) tile(`path_${m}_${v}`, tiles.drawPath(pal, m, v));
  for (let v = 0; v < TILE_VARIANTS.dirt; v++) tile(`dirt_${v}`, tiles.drawDirt(pal, v));
  tile('fresh_0', tiles.drawFresh());
  tile('exitRing_0', tiles.drawExitRing());
  const S = SPRITES;
  for (let v = 0; v < S.tree.variants; v++) entries.push(sprite(S.tree, v, props.drawTree(pal, v)));
  for (let v = 0; v < S.forestTree.variants; v++) entries.push(sprite(S.forestTree, v, props.drawForestTree(pal, v)));
  for (let v = 0; v < S.bush.variants; v++) entries.push(sprite(S.bush, v, props.drawBush(pal, v)));
  for (const kind of STORY_TILES) {
    const variants = kind === 'deep' ? 2 : kind === 'wallBase' ? 1 : 3;
    for (let v = 0; v < variants; v++) tile(`${kind}_${v}`, drawStoryTile(pal, kind, v));
  }
  for (const kind of STORY_PROPS) {
    const def = S[kind];
    for (let v = 0; v < def.variants; v++) entries.push(sprite(def, v, drawStoryProp(pal, kind, v)));
  }
  paletteAtlases.push(packAtlas(entries, textures, 'level'));
  while (paletteAtlases.length > 2) for (const src of paletteAtlases.shift()!) src.destroy();
}

async function loadCharacterSheet(def: CharacterDef): Promise<boolean> {
  const sheet = await tryLoadTexture(def.sheet!);
  if (!sheet) {
    console.warn(`[assets] could not load ${def.sheet}, using placeholder for ${def.key}`);
    return false;
  }
  let row = 0;
  for (const [anim, ad] of Object.entries(def.anims) as Array<[AnimName, { frames: number }]>) {
    for (const dir of SHEET_DIRS) {
      for (let f = 0; f < ad.frames; f++) {
        textures.set(
          textureName(def.key, anim, dir, f),
          subTexture(sheet, f * def.frameW, row * def.frameH, def.frameW, def.frameH, def.anchorX, def.anchorY),
        );
      }
      row++;
    }
  }
  return true;
}

async function loadSpriteStrip(def: SpriteDef): Promise<boolean> {
  const strip = await tryLoadTexture(def.file!);
  if (!strip) return false;
  for (let v = 0; v < def.variants; v++) {
    textures.set(spriteName(def.key as SpriteKey, v), subTexture(strip, v * def.w, 0, def.w, def.h, def.anchorX, def.anchorY));
  }
  return true;
}
