import { Rectangle, Texture } from 'pixi.js';
import gifUrl from '../../assets/starting-page-images/Zampano-Samemala-3.gif?url';

/**
 * The title page's animated portrait of Zampanò (assets/starting-page-images/
 * Zampano-Samemala-3.gif, 99 frames, about 4 s). The GIF is large (1024 x 1536 per frame); its frames are
 * decoded by the browser (WebCodecs `ImageDecoder`, in Chromium and the Android WebView), cropped
 * to the dog (the union of every frame's opaque area), scaled down to the size the title needs
 * on this screen and packed into one texture. Until it is ready (a second or two on a slow
 * phone) and where `ImageDecoder` is missing (Safari, a page served over plain http on the LAN)
 * the title shows the GIF's first frame (`titleStill`).
 */
export interface TitleAnim {
  frames: Texture[];
  /** Seconds each frame stays. */
  durations: number[];
  /** Total loop length, seconds. */
  length: number;
}

export const TITLE_GIF_URL: string = gifUrl;

/** The bits of WebCodecs' ImageDecoder used here (not in every TypeScript DOM library). */
interface DecodedFrame {
  image: CanvasImageSource & { displayWidth: number; displayHeight: number; duration: number | null; close(): void };
}
interface ImageDecoderLike {
  readonly completed: Promise<void>;
  readonly tracks: { readonly ready: Promise<void>; readonly selectedTrack: { frameCount: number } | null };
  decode(options: { frameIndex: number }): Promise<DecodedFrame>;
  close(): void;
}
type ImageDecoderCtor = new (init: { data: ArrayBuffer; type: string }) => ImageDecoderLike;

/**
 * Frames are first reduced to this width (by halving: smooth and sharp), cropped from there. 192
 * keeps the cropped dog wider than the widest title portrait (124 px) and the 99 reduced frames
 * small in memory (about 20 MB while they are packed).
 */
const WORK_WIDTH = 192;
/** Alpha at or above this becomes opaque, below it transparent (crisp edges, like the pixel art). */
const ALPHA_CUT = 110;

const cache = new Map<string, Promise<TitleAnim | null>>();

function cached(key: string, make: () => Promise<TitleAnim | null>): Promise<TitleAnim | null> {
  let p = cache.get(key);
  if (!p) {
    p = make().catch((err) => {
      console.warn('[title anim]', err);
      return null;
    });
    cache.set(key, p);
  }
  return p;
}

/** The animation with frames `width` logical px wide (cached per width). */
export function titleAnimation(width: number): Promise<TitleAnim | null> {
  return cached(`anim@${width}`, async () => {
    const got = await decodedFrames();
    return got ? pack(got.work, got.durations, width) : null;
  });
}

/**
 * The GIF's first frame alone, cropped and scaled the same way: quick to make, shown while the
 * animation decodes (and for good where ImageDecoder is missing).
 */
export function titleStill(width: number): Promise<TitleAnim | null> {
  return cached(`still@${width}`, async () => {
    const img = new Image();
    img.src = gifUrl;
    await img.decode();
    return pack([reduce(img, img.naturalWidth, img.naturalHeight)], [1], width);
  });
}

function canvas(w: number, h: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = Math.max(1, Math.round(w));
  c.height = Math.max(1, Math.round(h));
  return c;
}

function smooth(c: HTMLCanvasElement): CanvasRenderingContext2D {
  const g = c.getContext('2d', { willReadFrequently: true })!;
  g.imageSmoothingEnabled = true;
  g.imageSmoothingQuality = 'high';
  return g;
}

/** A frame reduced to WORK_WIDTH by halving (smooth and sharp). */
function reduce(src0: CanvasImageSource, w: number, h: number): HTMLCanvasElement {
  let src = src0;
  let sw = w;
  let sh = h;
  while (sw / 2 >= WORK_WIDTH) {
    const c = canvas(sw / 2, sh / 2);
    smooth(c).drawImage(src, 0, 0, c.width, c.height);
    [src, sw, sh] = [c, c.width, c.height];
  }
  const c = canvas(WORK_WIDTH, (sh * WORK_WIDTH) / sw);
  smooth(c).drawImage(src, 0, 0, c.width, c.height);
  return c;
}

/** Every frame, reduced (null where ImageDecoder is missing). */
async function decodedFrames(): Promise<{ work: HTMLCanvasElement[]; durations: number[] } | null> {
  const Decoder = (globalThis as { ImageDecoder?: ImageDecoderCtor }).ImageDecoder;
  if (!Decoder) return null;
  const data = await (await fetch(gifUrl)).arrayBuffer();
  const decoder = new Decoder({ data, type: 'image/gif' });
  try {
    // The track list first (selectedTrack is null until then), then the whole file.
    await decoder.tracks.ready;
    await decoder.completed;
    const count = decoder.tracks.selectedTrack?.frameCount ?? 0;
    const work: HTMLCanvasElement[] = [];
    const durations: number[] = [];
    for (let i = 0; i < count; i++) {
      const { image } = await decoder.decode({ frameIndex: i });
      durations.push(Math.max(0.02, (image.duration ?? 100_000) / 1e6));
      work.push(reduce(image, image.displayWidth, image.displayHeight));
      image.close();
    }
    return count ? { work, durations } : null;
  } finally {
    decoder.close();
  }
}

/** Crops the reduced frames to the dog, scales them to `width` and packs them in one texture. */
function pack(work: HTMLCanvasElement[], durations: number[], width: number): TitleAnim | null {
  // The union of every frame's opaque area: the crop.
  let x0 = Infinity;
  let y0 = Infinity;
  let x1 = -1;
  let y1 = -1;
  for (const c of work) {
    const a = smooth(c).getImageData(0, 0, c.width, c.height).data;
    for (let y = 0; y < c.height; y++) {
      for (let x = 0; x < c.width; x++) {
        if (a[(y * c.width + x) * 4 + 3]! < ALPHA_CUT) continue;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < 0) return null;

  // Crop to the dog, scale to `width`, pack the frames into one atlas.
  const count = work.length;
  const cw = x1 - x0 + 1;
  const ch = y1 - y0 + 1;
  const fw = width;
  const fh = Math.max(1, Math.round((ch * width) / cw));
  const cols = Math.max(1, Math.min(count, Math.floor(2048 / (fw + 1))));
  const rows = Math.ceil(count / cols);
  const atlas = canvas(cols * (fw + 1), rows * (fh + 1));
  const g = smooth(atlas);
  work.forEach((c, i) => g.drawImage(c, x0, y0, cw, ch, (i % cols) * (fw + 1), Math.floor(i / cols) * (fh + 1), fw, fh));
  const img = g.getImageData(0, 0, atlas.width, atlas.height);
  for (let k = 3; k < img.data.length; k += 4) img.data[k] = img.data[k]! >= ALPHA_CUT ? 255 : 0;
  g.putImageData(img, 0, 0);
  const base = Texture.from(atlas);
  const frames = work.map(
    (_, i) => new Texture({ source: base.source, frame: new Rectangle((i % cols) * (fw + 1), Math.floor(i / cols) * (fh + 1), fw, fh) }),
  );
  return { frames, durations, length: durations.reduce((s, d) => s + d, 0) };
}

/** The frame showing `t` seconds into the loop. */
export function frameAt(anim: TitleAnim, t: number): Texture {
  let r = anim.length > 0 ? t % anim.length : 0;
  for (let i = 0; i < anim.frames.length; i++) {
    r -= anim.durations[i]!;
    if (r < 0) return anim.frames[i]!;
  }
  return anim.frames[anim.frames.length - 1]!;
}
