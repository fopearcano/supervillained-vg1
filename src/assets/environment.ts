import type { AtlasEntry } from '../core/assets';
import type { Palette } from '../world/level';
import { PixelBuffer } from './placeholders/pixel';
import { Ground } from '../world/tiles';

/** Visual-only tile choices; ground types, props and collision stay in LevelData. */
export interface FloorDesign {
  environment: string;
  width: number;
  height: number;
  /** Row-major tile index -> native 32x16 floorArt_ atlas entry. */
  tiles: Readonly<Record<string, string>>;
}

interface FrameDef {
  x: number;
  y: number;
  w: number;
  h: number;
  anchorX: number;
  anchorY: number;
}

interface ZoneDef {
  image: string;
  frames: Record<string, FrameDef>;
  palette?: Partial<Palette>;
}

interface EnvironmentManifest {
  version: 1;
  zones: Record<string, ZoneDef>;
  chapterThemes?: Record<string, Record<string, string>>;
  themeFallbacks?: Record<string, string>;
  floorDesigns?: Record<string, FloorDesign>;
}

interface DeliveredFrame extends FrameDef {
  image: PixelBuffer;
}

const framesByZone = new Map<string, Map<string, DeliveredFrame>>();
const palettesByZone = new Map<string, Partial<Palette>>();
const warned = new Set<string>();
const warnings: string[] = [];
const floorDesigns = new Map<string, FloorDesign>();
let chapterThemes: Record<string, Record<string, string>> = {};
let themeFallbacks: Record<string, string> = {};
let preload: Promise<void> | undefined;

function warnOnce(key: string, message: string): void {
  if (warned.has(key)) return;
  warned.add(key);
  warnings.push(message);
  console.warn(`[environment-ink] ${message}`);
}

export function environmentDiagnostics(): { loadedZones: string[]; warnings: string[] } {
  return { loadedZones: [...framesByZone.keys()], warnings: [...warnings] };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

const SWATCHES = new Set(['grass', 'tallGrass', 'path', 'water', 'forest', 'foliage', 'pollution', 'floor', 'stone', 'sand', 'snow', 'deep', 'wall', 'roof', 'cloth', 'dock', 'carpet']);
const HEX = /^#[0-9a-fA-F]{6}$/;
const FLOOR_FRAME = /^floorArt_[a-z][A-Za-z0-9_]*$/;

/** Optional design data can fail independently of the chapter art banks. */
function readFloorDesigns(raw: unknown, manifest: EnvironmentManifest): void {
  if (raw === undefined) return;
  if (!isRecord(raw)) { warnOnce('floor:metadata', 'bad floorDesigns; using native ground choices'); return; }
  for (const [key, candidate] of Object.entries(raw)) {
    try {
      if (!/^[1-9][0-9]*:[a-zA-Z][a-zA-Z0-9_]*$/.test(key) || !isRecord(candidate)) throw new Error('invalid chapter/map key');
      const { environment, width, height, tiles } = candidate;
      if (typeof environment !== 'string' || !manifest.zones[environment]) throw new Error('unknown environment');
      if (typeof width !== 'number' || !Number.isSafeInteger(width) || width < 1 || typeof height !== 'number' || !Number.isSafeInteger(height) || height < 1 || !Number.isSafeInteger(width * height)) throw new Error('invalid dimensions');
      if (!isRecord(tiles)) throw new Error('invalid tile choices');
      const chapter = key.slice(0, key.indexOf(':'));
      if (!Object.values(manifest.chapterThemes?.[chapter] ?? {}).includes(environment)) throw new Error('environment is not selected by this chapter');
      const choices: Record<string, string> = {};
      for (const [index, name] of Object.entries(tiles)) {
        if (!/^(0|[1-9][0-9]*)$/.test(index) || !Number.isSafeInteger(Number(index)) || Number(index) >= width * height) throw new Error(`invalid tile index '${index}'`);
        if (typeof name !== 'string' || !FLOOR_FRAME.test(name)) throw new Error(`invalid floor frame '${String(name)}'`);
        const frame = manifest.zones[environment]!.frames[name];
        if (!frame || frame.w !== 32 || frame.h !== 16 || frame.anchorX !== 16 || frame.anchorY !== 0) throw new Error(`missing or non-native frame '${name}'`);
        choices[index] = name;
      }
      floorDesigns.set(key, Object.freeze({ environment, width, height, tiles: Object.freeze(choices) }));
    } catch (error) {
      warnOnce(`floor:${key}`, `${key}: ${String(error)}; using native ground choices`);
    }
  }
}

/** A design is only valid for the exact current map dimensions and chapter art. */
export function floorDesignForMap(chapter: number, mapKey: string, palette: Palette, level: { width: number; height: number }): FloorDesign | undefined {
  const key = `${chapter}:${mapKey}`;
  const design = floorDesigns.get(key);
  if (!design) return undefined;
  if (design.environment !== palette.environment || design.width !== level.width || design.height !== level.height || !framesByZone.has(design.environment)) {
    warnOnce(`floor:selection:${key}`, `${key}: floor layout does not match the current map/art bank; using native ground choices`);
    return undefined;
  }
  return design;
}

/** Preserve wet, tall, blocked and void ground cues even if authoring data is wrong. */
export function floorFrameForGround(design: FloorDesign | undefined, index: number, ground: Ground): string | undefined {
  if (!design || !Number.isInteger(index) || index < 0 || index >= design.width * design.height) return undefined;
  switch (ground) {
    case Ground.Grass: case Ground.Path: case Ground.Floor: case Ground.Stone:
    case Ground.Sand: case Ground.Snow: case Ground.Dock: case Ground.Carpet:
      return design.tiles[String(index)];
    default:
      return undefined;
  }
}

/** Validate colours as well as geometry so malformed metadata cannot break fallback art. */
function parseManifest(raw: unknown): EnvironmentManifest {
  if (!isRecord(raw) || raw.version !== 1 || !isRecord(raw.zones) || !Object.keys(raw.zones).length) throw new Error('unsupported or malformed manifest');
  for (const [id, zone] of Object.entries(raw.zones)) {
    if (!isRecord(zone) || typeof zone.image !== 'string' || !/^[a-zA-Z0-9][a-zA-Z0-9_.-]*\.png$/.test(zone.image) || !isRecord(zone.frames) || !Object.keys(zone.frames).length) throw new Error(`bad zone '${id}'`);
    for (const [name, frame] of Object.entries(zone.frames)) {
      if (!isRecord(frame)) throw new Error(`bad frame '${id}/${name}'`);
      for (const k of ['x', 'y', 'w', 'h', 'anchorX', 'anchorY'] as const) {
        const v = frame[k];
        if (typeof v !== 'number' || !Number.isInteger(v) || v < 0) throw new Error(`bad ${k} in '${id}/${name}'`);
      }
      if ((frame.w as number) < 1 || (frame.h as number) < 1 || (frame.anchorX as number) > (frame.w as number) || (frame.anchorY as number) > (frame.h as number)) throw new Error(`empty frame or invalid anchor '${id}/${name}'`);
    }
    if (zone.palette !== undefined) {
      if (!isRecord(zone.palette)) throw new Error(`bad palette '${id}'`);
      for (const [name, value] of Object.entries(zone.palette)) {
        if (name === 'background') {
          if (typeof value !== 'string' || !HEX.test(value)) throw new Error(`bad palette '${id}/${name}'`);
          continue;
        }
        if ((!SWATCHES.has(name) && name !== 'flowers') || !Array.isArray(value) || (name === 'flowers' ? !value.length : value.length !== 3) || value.some((c: unknown) => typeof c !== 'string' || !HEX.test(c))) throw new Error(`bad palette '${id}/${name}'`);
      }
    }
  }
  const validateLookup = (value: unknown, name: string): void => {
    if (value === undefined) return;
    if (!isRecord(value)) throw new Error(`bad ${name}`);
    for (const [theme, id] of Object.entries(value)) if (typeof id !== 'string' || !(id in (raw.zones as Record<string, unknown>))) throw new Error(`bad atlas in '${name}/${theme}'`);
  };
  validateLookup(raw.themeFallbacks, 'themeFallbacks');
  if (raw.chapterThemes !== undefined) {
    if (!isRecord(raw.chapterThemes)) throw new Error('bad chapterThemes');
    for (const [chapter, lookup] of Object.entries(raw.chapterThemes)) validateLookup(lookup, `chapterThemes/${chapter}`);
  }
  return raw as unknown as EnvironmentManifest;
}

function clonePalette(palette: Palette): Palette {
  return Object.fromEntries(Object.entries(palette).map(([name, value]) => [name, Array.isArray(value) ? [...value] : value])) as unknown as Palette;
}

/** Same map can have its own opening, dream and homecoming colour identity. */
export function paletteForChapter(chapter: number, theme: string, fallback: Palette): Palette {
  const id = chapterThemes[String(chapter)]?.[theme] ?? themeFallbacks[theme] ?? fallback.environment;
  if (!id) return clonePalette(fallback);
  return clonePalette({ ...fallback, ...(palettesByZone.get(id) ?? {}), environment: id });
}

async function decodeZone(id: string, def: ZoneDef, manifestUrl: URL): Promise<void> {
  const image = new Image();
  image.decoding = 'async';
  image.src = new URL(def.image, manifestUrl).href;
  await image.decode();
  const canvas = document.createElement('canvas');
  canvas.width = image.naturalWidth;
  canvas.height = image.naturalHeight;
  try {
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) throw new Error('canvas 2D context unavailable');
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(image, 0, 0);
    const decoded = new Map<string, DeliveredFrame>();
    for (const [name, frame] of Object.entries(def.frames)) {
      if (frame.x + frame.w > canvas.width || frame.y + frame.h > canvas.height) throw new Error(`frame '${name}' exceeds ${def.image}`);
      const rgba = ctx.getImageData(frame.x, frame.y, frame.w, frame.h);
      const buffer = new PixelBuffer(frame.w, frame.h);
      new Uint8ClampedArray(buffer.data.buffer).set(rgba.data);
      decoded.set(name, { ...frame, image: buffer });
    }
    framesByZone.set(id, decoded);
  } finally {
    canvas.width = 0;
    canvas.height = 0;
  }
}

/** Decode once at asynchronous boot; World and level texture construction stay synchronous. */
export function preloadEnvironmentArt(): Promise<void> {
  preload ??= (async () => {
    const url = new URL('environment-ink/manifest.json', document.baseURI);
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`manifest HTTP ${response.status}`);
      const manifest = parseManifest(await response.json());
      chapterThemes = manifest.chapterThemes ?? {};
      themeFallbacks = manifest.themeFallbacks ?? {};
      readFloorDesigns(manifest.floorDesigns, manifest);
      for (const [id, zone] of Object.entries(manifest.zones)) palettesByZone.set(id, zone.palette ?? {});
      await Promise.all(Object.entries(manifest.zones).map(async ([id, zone]) => {
        try { await decodeZone(id, zone, url); }
        catch (error) { warnOnce(`load:${id}`, `${id}: ${String(error)}; using generated art for this zone`); }
      }));
      console.info(`[environment-ink] loaded ${framesByZone.size}/${Object.keys(manifest.zones).length} delivered zones`);
    } catch (error) {
      warnOnce('manifest', `${String(error)}; using generated environment art`);
    }
  })();
  return preload;
}

/** Only replace existing native frames; geometry and gameplay footprints remain authoritative. */
export function withEnvironmentArt(palette: Palette, entries: AtlasEntry[]): AtlasEntry[] {
  const id = palette.environment;
  if (!id) return entries;
  const delivered = framesByZone.get(id);
  if (!delivered) {
    warnOnce(`missing:${id}`, `no delivered atlas for '${id}'; using generated art`);
    return entries;
  }
  const missing: string[] = [];
  const result = entries.map((entry): AtlasEntry => {
    const frame = delivered.get(entry.name);
    if (!frame) { missing.push(entry.name); return entry; }
    if (frame.w !== entry.image.w || frame.h !== entry.image.h || frame.anchorX !== entry.anchorX || frame.anchorY !== entry.anchorY) {
      warnOnce(`shape:${id}:${entry.name}`, `${id}/${entry.name}: dimensions or anchor differ from the game contract; using generated frame`);
      return entry;
    }
    return { ...entry, image: frame.image };
  });
  if (missing.length) warnOnce(`partial:${id}`, `${id}: atlas lacks ${missing.join(', ')}; using generated art for those frames`);
  // Extra authored floor frames have their own namespace and exactly the ground contract.
  const names = new Set(result.map((entry) => entry.name));
  for (const [name, frame] of delivered) {
    if (!FLOOR_FRAME.test(name) || names.has(name)) continue;
    if (frame.w !== 32 || frame.h !== 16 || frame.anchorX !== 16 || frame.anchorY !== 0) {
      warnOnce(`floor:shape:${id}:${name}`, `${id}/${name}: non-native floor frame; ignoring it`);
      continue;
    }
    result.push({ name, image: frame.image, anchorX: 16, anchorY: 0 });
  }
  return result;
}
