import { Sprite } from 'pixi.js';
import { textures } from '../core/assets';
import { spriteName, SPRITES, type SpriteKey } from '../assets/manifest';
import type { MapProp } from '../world/map';
import { Entity } from './entity';

/** Static scenery: trees, bushes, poles, fountains, forest trees, the exit flag. */
export class PropEntity extends Entity {
  readonly sprite: Sprite;
  readonly kind: SpriteKey;
  readonly mapProp: MapProp | null;

  constructor(kind: SpriteKey, variant: number, gx: number, gy: number, mapProp: MapProp | null, fadeable: boolean) {
    super();
    this.kind = kind;
    this.mapProp = mapProp;
    this.sprite = new Sprite(textures.get(spriteName(kind, variant)));
    this.sprite.roundPixels = true;
    this.view.addChild(this.sprite);
    this.setPosition(gx, gy);
    this.fadeable = fadeable;
    const def = SPRITES[kind];
    this.bounds = { x: -def.anchorX, y: -def.anchorY, w: def.w, h: def.h };
    this.sync(1);
  }
}
