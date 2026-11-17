import { existsSync } from 'node:fs';
import { basename } from 'node:path';
import { describe, expect, it } from 'vitest';
import { MUSIC_FILES, SOUND_FILES } from '../src/fx/audioFiles';
import { SOUNDS } from '../src/fx/sounds';

describe('recorded audio', () => {
  it('points every sound and music track at a file in assets/', () => {
    for (const [name, url] of Object.entries(SOUND_FILES)) {
      expect(existsSync(`assets/sounds/${basename(url)}`), name).toBe(true);
    }
    for (const [name, url] of Object.entries(MUSIC_FILES)) {
      expect(existsSync(`assets/music/${basename(url)}`), name).toBe(true);
    }
  });

  it('never has a recorded and a synthesized sound with the same name', () => {
    for (const name of Object.keys(SOUND_FILES)) expect(Object.keys(SOUNDS), name).not.toContain(name);
  });
});
