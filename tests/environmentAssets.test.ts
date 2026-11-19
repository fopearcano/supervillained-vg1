import { readFileSync, statSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { STORY_MAPS, THEMES } from '../src/story/maps';
import { parseAsciiMap } from '../src/world/level';

interface FrameDef {
  x: number;
  y: number;
  w: number;
  h: number;
  anchorX: number;
  anchorY: number;
}

interface EnvironmentManifest {
  version: number;
  zones: Record<string, { image: string; frames: Record<string, FrameDef> }>;
  themeFallbacks: Record<string, string>;
  floorDesigns: Record<string, { width: number; height: number; environment: string }>;
}

const manifestUrl = new URL('../public/environment-ink/manifest.json', import.meta.url);
const manifest = JSON.parse(readFileSync(manifestUrl, 'utf8')) as EnvironmentManifest;

describe('delivered Color Ink runtime assets', () => {
  it('ships every local chapter bank with the same native frame contract', () => {
    expect(manifest.version).toBe(1);
    expect(Object.keys(manifest.zones)).toHaveLength(15);

    const baseline = manifest.zones.ch01_greenzone!;
    const nativeNames = Object.keys(baseline.frames).filter((name) => !name.startsWith('floorArt_')).sort();
    expect(nativeNames).toHaveLength(104);

    for (const [id, zone] of Object.entries(manifest.zones)) {
      expect(zone.image, id).toMatch(/^[a-zA-Z0-9_.-]+\.png$/);
      expect(statSync(new URL(zone.image, manifestUrl)).size, id).toBeGreaterThan(0);
      const names = Object.keys(zone.frames).filter((name) => !name.startsWith('floorArt_')).sort();
      expect(names, id).toEqual(nativeNames);
      for (const name of nativeNames) {
        const actual = zone.frames[name]!;
        const expected = baseline.frames[name]!;
        expect(
          [actual.w, actual.h, actual.anchorX, actual.anchorY],
          `${id}/${name}`,
        ).toEqual([expected.w, expected.h, expected.anchorX, expected.anchorY]);
      }
      for (const [name, frame] of Object.entries(zone.frames)) {
        if (!name.startsWith('floorArt_')) continue;
        expect([frame.w, frame.h, frame.anchorX, frame.anchorY], `${id}/${name}`).toEqual([32, 16, 16, 0]);
      }
    }
  });

  it('covers every current story theme and matches story floor dimensions', () => {
    for (const theme of Object.keys(THEMES)) {
      const zone = manifest.themeFallbacks[theme];
      expect(zone, theme).toBeTypeOf('string');
      expect(manifest.zones[zone!], theme).toBeDefined();
    }

    for (const [key, design] of Object.entries(manifest.floorDesigns)) {
      if (key === '1:arcade') continue; // Intentionally not selected by the redesigned Green Zone.
      const mapKey = key.slice(key.indexOf(':') + 1) as keyof typeof STORY_MAPS;
      const def = STORY_MAPS[mapKey];
      expect(def, key).toBeDefined();
      const level = parseAsciiMap(def.rows, { base: def.base, requireExit: false });
      expect([design.width, design.height], key).toEqual([level.width, level.height]);
      expect(manifest.zones[design.environment], key).toBeDefined();
    }
  });
});
