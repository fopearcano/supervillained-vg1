import { DISPLAY } from '../config';

export interface Viewport {
  /** Logical (game) resolution. */
  width: number;
  height: number;
  /** Integer upscale from logical px to device px. */
  scale: number;
  /** Canvas placement in CSS px. */
  cssLeft: number;
  cssTop: number;
  cssWidth: number;
  cssHeight: number;
}

/**
 * Picks a low logical resolution and an INTEGER device-pixel scale so nearest-neighbor
 * upscaling is exact (pixel-perfect). Wide windows are pillarboxed to a portrait aspect.
 */
export function computeViewport(cssW: number, cssH: number, dpr: number): Viewport {
  const devW = Math.max(1, Math.floor(cssW * dpr));
  const devH = Math.max(1, Math.floor(cssH * dpr));
  // Usable device area, constrained to the allowed aspect range.
  let areaW = devW;
  let areaH = devH;
  if (areaW / areaH > DISPLAY.MAX_ASPECT) areaW = Math.floor(areaH * DISPLAY.MAX_ASPECT);
  if (areaW / areaH < DISPLAY.MIN_ASPECT) areaH = Math.floor(areaW / DISPLAY.MIN_ASPECT);

  let scale = Math.max(1, Math.round(areaW / DISPLAY.TARGET_WIDTH));
  while (scale > 1 && Math.floor(areaW / scale) < DISPLAY.MIN_WIDTH) scale--;
  while (Math.floor(areaW / scale) > DISPLAY.MAX_WIDTH) scale++;
  const width = Math.floor(areaW / scale);
  const height = Math.floor(areaH / scale);
  const cssWidth = (width * scale) / dpr;
  const cssHeight = (height * scale) / dpr;
  return {
    width,
    height,
    scale,
    cssWidth,
    cssHeight,
    cssLeft: Math.floor((cssW - cssWidth) / 2),
    cssTop: Math.floor((cssH - cssHeight) / 2),
  };
}

export interface Insets {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

let probe: HTMLDivElement | null = null;

/**
 * The screen's safe-area insets in CSS px (an iPhone's notch or Dynamic Island, rounded
 * corners, the home indicator; a camera cutout on Android), read from CSS `env()`; all 0 where
 * the browser has none. The game is laid out inside them, the black page fills the rest.
 */
export function safeAreaInsets(): Insets {
  if (typeof document === 'undefined') return { top: 0, right: 0, bottom: 0, left: 0 };
  if (!probe) {
    probe = document.createElement('div');
    probe.style.cssText =
      'position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;pointer-events:none;' +
      'padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
    document.body.appendChild(probe);
  }
  const cs = getComputedStyle(probe);
  const px = (v: string) => Math.max(0, parseFloat(v) || 0);
  return { top: px(cs.paddingTop), right: px(cs.paddingRight), bottom: px(cs.paddingBottom), left: px(cs.paddingLeft) };
}
