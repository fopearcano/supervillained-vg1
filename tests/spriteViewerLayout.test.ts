import { describe, expect, it } from 'vitest';
import { spriteViewerLayout } from '../src/scenes/spriteViewerScene';

describe('portrait sprite viewer frame layout', () => {
  it.each([[192, 312], [216, 400], [270, 600]])('fits twelve complete 40px rows and all four profiles at %s × %s', (width, height) => {
    const layout = spriteViewerLayout(width, height, 12, 40, 40);
    const { margin, labelWidth, top, columnWidth, rowHeight, scale } = layout;
    const boxes: Array<{ left: number; top: number; right: number; bottom: number }> = [];
    for (let row = 0; row < 12; row++) {
      for (let col = 0; col < 4; col++) {
        const x = margin + labelWidth + col * columnWidth + (columnWidth - 40 * scale) / 2;
        const y = top + row * rowHeight + (rowHeight - 40 * scale) / 2;
        const left = Math.round(x + 20 * scale) - 20 * scale;
        const frameTop = Math.round(y + 36 * scale) - 36 * scale;
        const box = { left, top: frameTop, right: left + 40 * scale, bottom: frameTop + 40 * scale };
        expect(box.left).toBeGreaterThanOrEqual(margin + labelWidth);
        expect(box.top).toBeGreaterThanOrEqual(top);
        expect(box.right).toBeLessThanOrEqual(width - margin);
        expect(box.bottom).toBeLessThanOrEqual(height - margin);
        if (col) expect(box.left).toBeGreaterThan(boxes[boxes.length - 1]!.right);
        if (row) expect(box.top).toBeGreaterThan(boxes[(row - 1) * 4 + col]!.bottom);
        boxes.push(box);
      }
    }
    expect(boxes).toHaveLength(48);
  });

  it('recomputes frame scale when the game viewport changes', () => {
    const compact = spriteViewerLayout(192, 312, 12, 40, 40);
    const tall = spriteViewerLayout(216, 500, 12, 40, 40);
    expect(tall.scale).toBeGreaterThan(compact.scale);
    expect(tall.rowHeight).toBeGreaterThan(compact.rowHeight);
  });
});
