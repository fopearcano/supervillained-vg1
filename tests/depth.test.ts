import { describe, expect, it } from 'vitest';
import { compareDepth, occludes, sortByDepth, type Sortable } from '../src/iso/depth';

const obj = (id: number, gx: number, gy: number, depthBias = 0): Sortable => ({ id, gx, gy, depthBias });

describe('depth sorting', () => {
  it('sorts back to front by gx + gy', () => {
    const items = [obj(1, 5, 5), obj(2, 1, 1), obj(3, 3, 2)];
    expect(sortByDepth(items).map((o) => o.id)).toEqual([2, 3, 1]);
  });

  it('breaks ties by gx, then by id (stable)', () => {
    const a = obj(7, 2, 3);
    const b = obj(4, 3, 2);
    const c = obj(9, 3, 2);
    expect(sortByDepth([c, a, b]).map((o) => o.id)).toEqual([7, 4, 9]);
    expect(compareDepth(b, c)).toBeLessThan(0);
    expect(compareDepth(c, b)).toBeGreaterThan(0);
  });

  it('uses the depth bias', () => {
    expect(compareDepth(obj(1, 2, 2, 0.1), obj(2, 2, 2))).toBeGreaterThan(0);
  });

  it('a tree in front of the dog occludes it only when their sprites overlap', () => {
    const dog = obj(1, 4.4, 4.4);
    const tree = obj(2, 5.5, 5.5);
    const dogRect = { x: -15, y: -32, w: 30, h: 35 };
    const treeRect = { x: -20, y: -50, w: 40, h: 60 };
    expect(occludes(tree, treeRect, dog, dogRect)).toBe(true);
    expect(occludes(tree, { ...treeRect, x: 200 }, dog, dogRect)).toBe(false);
    const behindTree = obj(3, 2, 2);
    expect(occludes(behindTree, treeRect, dog, dogRect)).toBe(false);
  });
});
