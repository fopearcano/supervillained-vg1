// Minimal display-object stand-ins (no rendering). Only what entity constructors touch.
class Point { constructor() { this.x = 0; this.y = 0; } set(x = 0, y = x) { this.x = x; this.y = y; } copyFrom(p) { this.x = p.x; this.y = p.y; } }
export class Container {
  constructor() { this.position = new Point(); this.scale = new Point(); this.scale.set(1, 1); this.children = []; this.alpha = 1; this.visible = true; this.zIndex = 0; }
  addChild(...c) { this.children.push(...c); return c[0]; }
  removeChild() {}
  destroy() {}
  get x() { return this.position.x; } set x(v) { this.position.x = v; }
  get y() { return this.position.y; } set y(v) { this.position.y = v; }
}
export class Sprite extends Container { constructor(texture) { super(); this.texture = texture; this.tint = 0xffffff; this.roundPixels = false; } }
export class Graphics extends Container { clear() { return this; } }
export class Texture { static EMPTY = new Texture(); }
export class TextureSource {}
export class CanvasSource extends TextureSource {}
export class Rectangle {}
export const Assets = {};
