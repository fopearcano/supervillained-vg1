import { Container, Graphics, Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import type { Game } from '../core/game';
import type { Scene } from '../core/scene';
import { CHARACTERS, textureName, type AnimName, type CharacterKey } from '../assets/manifest';
import type { Dir8 } from '../iso/projection';
import { PixelText } from '../ui/pixelText';

/** W, SW and NW are mirrors of E, SE and NE. */
const VIEW_DIRS: Dir8[] = ['S', 'SE', 'E', 'NE', 'N'];

/**
 * Debug page (`?debug=sprites&char=zampano`): every animation x direction of a character,
 * animated. Handy when dropping in final art.
 */
export class SpriteViewerScene implements Scene {
  readonly root = new Container();
  readonly pausesBelow = true;
  private readonly cells: Array<{ sprite: Sprite; anim: AnimName; dir: Dir8 }> = [];
  private time = 0;

  constructor(
    readonly game: Game,
    readonly key: CharacterKey,
  ) {
    const def = CHARACTERS[key];
    const bg = new Graphics().rect(0, 0, 2000, 2000).fill(0x3fcf1f);
    this.root.addChild(bg);
    const title = new PixelText(key.toUpperCase(), { color: '#ffe23a', outline: '#000000' });
    title.position.set(2, 2);
    this.root.addChild(title);
    const anims = Object.keys(def.anims) as AnimName[];
    const cw = def.frameW;
    const ch = def.frameH;
    // Rows overlap a little when a character has many anims (Zampanò: 11), to fit the screen.
    const rowH = Math.min(ch - 4, Math.floor((game.height - 18) / anims.length));
    anims.forEach((anim, row) => {
      const label = new PixelText(anim.slice(0, 4), { color: '#ffffff', outline: '#000000' });
      label.position.set(1, 14 + row * rowH + ch / 2 - 4);
      this.root.addChild(label);
      VIEW_DIRS.forEach((dir, col) => {
        const sprite = new Sprite(textures.get(textureName(key, anim, dir, 0)));
        sprite.position.set(36 + col * (cw - 6) + def.anchorX - 4, 14 + row * rowH + def.anchorY);
        this.root.addChild(sprite);
        this.cells.push({ sprite, anim, dir });
      });
    });
  }

  update(dt: number): void {
    this.time += dt;
    const anims = CHARACTERS[this.key].anims as Record<string, { frames: number; fps: number }>;
    for (const c of this.cells) {
      const a = anims[c.anim]!;
      const f = Math.floor(this.time * a.fps) % a.frames;
      c.sprite.texture = textures.get(textureName(this.key, c.anim, c.dir, f));
    }
  }
}
