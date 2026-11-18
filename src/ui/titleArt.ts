import { Texture } from 'pixi.js';
// A 384-px copy of the still portrait (shown at most ~124 px wide); the original is kept beside it.
import dogUrl from '../../assets/starting-page-images/app/Retro-16-Bit Ivory Dog Sprite-3-4-front-384.png?url';
import logoUrl from '../../assets/starting-page-images/Youve_Been_Supervillained_Logo.png?url';

/**
 * Art from assets/starting-page-images: Zampanò's portrait over the title's buttons and the
 * "You've been supervillained" logo shown at the end of every level (SupervillainedScene). The
 * source PNGs are large; they are scaled down here to the exact size needed on this screen (the
 * game draws at a low logical resolution), so a replaced file needs no other step.
 */
export interface TitleArt {
  dog: HTMLImageElement;
  logo: HTMLImageElement;
}

let loading: Promise<TitleArt | null> | null = null;

function loadImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`could not load ${url}`));
    img.src = url;
  });
}

/** Loads both images once (null if they are missing: the title then simply goes without). */
export function loadTitleArt(): Promise<TitleArt | null> {
  loading ??= Promise.all([loadImage(dogUrl), loadImage(logoUrl)])
    .then(([dog, logo]) => ({ dog, logo }))
    .catch((err) => {
      console.warn('[title art]', err);
      return null;
    });
  return loading;
}

const cache = new Map<string, Texture>();

/**
 * The image scaled to `width` logical px: halved step by step (smooth, sharp result), then the
 * edge made crisp (alpha 0 or 255) so it sits with the pixel art.
 */
export function titleTexture(img: HTMLImageElement, width: number): Texture {
  const key = `${img.src}@${width}`;
  const hit = cache.get(key);
  if (hit) return hit;
  let src: CanvasImageSource = img;
  let sw = img.naturalWidth;
  let sh = img.naturalHeight;
  const height = Math.max(1, Math.round((sh * width) / sw));
  while (sw / 2 >= width) {
    const c = document.createElement('canvas');
    c.width = Math.round(sw / 2);
    c.height = Math.round(sh / 2);
    const g = c.getContext('2d')!;
    g.imageSmoothingEnabled = true;
    g.imageSmoothingQuality = 'high';
    g.drawImage(src, 0, 0, c.width, c.height);
    [src, sw, sh] = [c, c.width, c.height];
  }
  const out = document.createElement('canvas');
  out.width = width;
  out.height = height;
  const g = out.getContext('2d')!;
  g.imageSmoothingEnabled = true;
  g.imageSmoothingQuality = 'high';
  g.drawImage(src, 0, 0, width, height);
  const data = g.getImageData(0, 0, width, height);
  for (let k = 3; k < data.data.length; k += 4) data.data[k] = data.data[k]! >= 110 ? 255 : 0;
  g.putImageData(data, 0, 0);
  const tex = Texture.from(out);
  cache.set(key, tex);
  return tex;
}
