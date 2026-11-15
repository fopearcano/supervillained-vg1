import { Assets, Rectangle, Texture, TextureSource } from 'pixi.js';
import { PixelBuffer } from '../assets/placeholders/pixel';

/**
 * Texture registry + atlas packer.
 * Every texture the game uses is registered under a string name (see assets/manifest.ts).
 * Generated pixel buffers are packed into a few big atlas canvases so the renderer can batch.
 */
export class TextureRegistry {
  private readonly map = new Map<string, Texture>();
  private readonly warned = new Set<string>();

  set(name: string, tex: Texture): void {
    this.map.set(name, tex);
  }

  has(name: string): boolean {
    return this.map.has(name);
  }

  get(name: string): Texture {
    const t = this.map.get(name);
    if (t) return t;
    if (!this.warned.has(name)) {
      this.warned.add(name);
      console.warn(`[assets] missing texture '${name}'`);
    }
    return Texture.WHITE;
  }
}

export const textures = new TextureRegistry();

export interface AtlasEntry {
  name: string;
  image: PixelBuffer;
  anchorX: number;
  anchorY: number;
}

const ATLAS_SIZE = 1024;
const PAD = 1;

/**
 * Shelf-packs entries into one or more ATLAS_SIZE² pages and registers a texture per entry.
 * Returns the number of pages created.
 */
export function packAtlas(entries: AtlasEntry[], registry: TextureRegistry, label: string): number {
  const sorted = [...entries].sort((a, b) => b.image.h - a.image.h || b.image.w - a.image.w);
  type Placed = { e: AtlasEntry; x: number; y: number; page: number };
  const placed: Placed[] = [];
  let page = 0;
  let x = PAD;
  let y = PAD;
  let shelfH = 0;
  const pageHeights: number[] = [0];
  for (const e of sorted) {
    const w = e.image.w;
    const h = e.image.h;
    if (x + w + PAD > ATLAS_SIZE) {
      x = PAD;
      y += shelfH + PAD;
      shelfH = 0;
    }
    if (y + h + PAD > ATLAS_SIZE) {
      page++;
      pageHeights.push(0);
      x = PAD;
      y = PAD;
      shelfH = 0;
    }
    placed.push({ e, x, y, page });
    x += w + PAD;
    shelfH = Math.max(shelfH, h);
    pageHeights[page] = Math.max(pageHeights[page]!, y + h + PAD);
  }
  for (let p = 0; p <= page; p++) {
    const h = nextPow2(pageHeights[p]!);
    const buf = new PixelBuffer(ATLAS_SIZE, h);
    const onPage = placed.filter((q) => q.page === p);
    for (const q of onPage) buf.blit(q.e.image, q.x, q.y);
    const source = TextureSource.from(buf.toCanvas());
    source.label = `${label}-${p}`;
    for (const q of onPage) {
      const tex = new Texture({
        source,
        frame: new Rectangle(q.x, q.y, q.e.image.w, q.e.image.h),
        defaultAnchor: { x: q.e.anchorX / q.e.image.w, y: q.e.anchorY / q.e.image.h },
        label: q.e.name,
      });
      registry.set(q.e.name, tex);
    }
  }
  return page + 1;
}

function nextPow2(v: number): number {
  let p = 1;
  while (p < v) p <<= 1;
  return p;
}

/** Loads an image from /public (relative URL). Resolves to null when missing or broken. */
export async function tryLoadTexture(url: string): Promise<Texture | null> {
  try {
    const tex = await Assets.load<Texture>(url);
    return tex ?? null;
  } catch {
    return null;
  }
}

/** Cuts a frame out of a loaded sheet texture. */
export function subTexture(sheet: Texture, x: number, y: number, w: number, h: number, anchorX: number, anchorY: number): Texture {
  return new Texture({
    source: sheet.source,
    frame: new Rectangle(sheet.frame.x + x, sheet.frame.y + y, w, h),
    defaultAnchor: { x: anchorX / w, y: anchorY / h },
  });
}
