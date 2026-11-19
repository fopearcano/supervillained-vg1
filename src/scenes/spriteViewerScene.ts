import { Container, Graphics, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import type { Game } from '../core/game';
import type { Scene } from '../core/scene';
import { animationFrame } from '../assets/animationTiming';
import { CHARACTERS, textureName, type AnimName, type CharacterKey } from '../assets/manifest';
import type { Dir8 } from '../iso/projection';
import { PixelText } from '../ui/pixelText';

/** Four distinct source profiles; the runtime atlases retain all eight facing directions. */
const VIEW_DIRS: readonly Dir8[] = ['S', 'W', 'E', 'N'];

/** Fit complete frames into a portrait table without overlapping adjacent rows. */
export function spriteViewerLayout(width: number, height: number, rows: number, frameW: number, frameH: number) {
  const margin = 2;
  const labelWidth = 44;
  const top = 28;
  const columnWidth = Math.max(1, (width - margin * 2 - labelWidth) / VIEW_DIRS.length);
  const rowHeight = Math.max(1, (height - top - margin) / Math.max(1, rows));
  const scale = Math.max(0.01, Math.min(1, (columnWidth - 4) / frameW, (rowHeight - 2) / frameH));
  return { margin, labelWidth, top, columnWidth, rowHeight, scale };
}

/** Debug page: every action playing in front, left, right and back views. */
export class SpriteViewerScene implements Scene {
  readonly root = new Container();
  readonly pausesBelow = true;
  private readonly background = new Graphics();
  private readonly title: PixelText;
  private readonly labels: PixelText[] = [];
  private readonly headings: PixelText[] = [];
  private readonly cells: Array<{ sprite: Sprite; anim: AnimName; dir: Dir8; row: number; col: number }> = [];
  private time = 0;

  constructor(
    readonly game: Game,
    readonly key: CharacterKey,
  ) {
    const def = CHARACTERS[key];
    this.root.addChild(this.background);
    this.title = new PixelText(key.toUpperCase(), { color: '#ffe23a', outline: '#000000' });
    this.root.addChild(this.title);
    VIEW_DIRS.forEach((dir) => {
      const heading = new PixelText(dir, { color: '#ffffff', outline: '#000000' });
      this.root.addChild(heading);
      this.headings.push(heading);
    });
    (Object.keys(def.anims) as AnimName[]).forEach((anim, row) => {
      const label = new PixelText(anim.toUpperCase(), { color: '#ffffff', outline: '#000000' });
      this.root.addChild(label);
      this.labels.push(label);
      VIEW_DIRS.forEach((dir, col) => {
        const sprite = new Sprite(textures.get(textureName(key, anim, dir, 0)));
        sprite.roundPixels = true;
        this.root.addChild(sprite);
        this.cells.push({ sprite, anim, dir, row, col });
      });
    });
    this.resize(game.width, game.height);
  }

  resize(width: number, height: number): void {
    const def = CHARACTERS[this.key];
    const layout = spriteViewerLayout(width, height, this.labels.length, def.frameW, def.frameH);
    const { margin, labelWidth, top, columnWidth, rowHeight, scale } = layout;
    this.background.clear().rect(0, 0, width, height).fill(0x3fcf1f);
    this.title.scale.set(Math.min(1, (width - margin * 2) / this.title.texture.frame.width));
    this.title.position.set(margin, margin);
    this.headings.forEach((heading, col) => {
      const centerX = margin + labelWidth + (col + 0.5) * columnWidth;
      heading.position.set(Math.round(centerX - heading.width / 2), 16);
    });
    this.labels.forEach((label, row) => {
      label.position.set(margin, Math.round(top + row * rowHeight + (rowHeight - label.height) / 2));
    });
    for (const { sprite, row, col } of this.cells) {
      const left = margin + labelWidth + col * columnWidth + (columnWidth - def.frameW * scale) / 2;
      const y = top + row * rowHeight + (rowHeight - def.frameH * scale) / 2;
      sprite.scale.set(scale);
      sprite.position.set(Math.round(left + def.anchorX * scale), Math.round(y + def.anchorY * scale));
    }
  }

  update(dt: number): void {
    this.time += dt;
    const anims = CHARACTERS[this.key].anims;
    for (const c of this.cells) {
      const frame = animationFrame(anims[c.anim]!, this.time, true);
      c.sprite.texture = textures.get(textureName(this.key, c.anim, c.dir, frame));
    }
  }
}
