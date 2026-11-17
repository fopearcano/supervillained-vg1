import greenzoneMusic from '../../assets/music/greenzone-music.mp3?url';
import introMusic from '../../assets/music/intro-music.mp3?url';
import alarm from '../../assets/sounds/alarm-greenzone-under-attack.mp3?url';
import ball from '../../assets/sounds/ball.mp3?url';
import cash from '../../assets/sounds/cash-after-cat.mp3?url';
import meow from '../../assets/sounds/cat-meow.mp3?url';
import bark from '../../assets/sounds/dog-bark.mp3?url';
import food from '../../assets/sounds/food-collect.mp3?url';
import laser from '../../assets/sounds/laser-eyes.mp3?url';
import peesCollect from '../../assets/sounds/pees-collect.wav?url';
import peesDrop from '../../assets/sounds/pees-drop.mp3?url';
import poos from '../../assets/sounds/poos.mp3?url';
import siren from '../../assets/sounds/siren.mp3?url';
import water from '../../assets/sounds/water.mp3?url';

/**
 * Recorded audio (assets/music, assets/sounds), named after its use in the game. Sound effects are
 * decoded once into buffers; music is streamed. Everything else stays synthesized (fx/sounds.ts).
 */
export const SOUND_FILES = {
  /** Zampanò barks (arcade and story). */
  bark,
  /** A treat eaten (TREATS +1); story pickups. */
  treat: food,
  /** A poop dropped (POOPS +1). */
  poop: poos,
  /** A pee (PEES +1), plain or marking. */
  pee: peesDrop,
  /** Pee charges collected by drinking at a puddle or fountain. */
  drink: peesCollect,
  /** Stepping into a puddle. */
  splash: water,
  /** A cat caught... */
  meow,
  /** ...and the cash that follows (also coins in the story). */
  coin: cash,
  /** A magnet ball appears. */
  ball,
  /** "GREEN ZONE UNDER ATTACK". */
  alarm,
  /** Looping while the Green Zone is under attack; the fire in Constantinople (7.4). */
  siren,
  /** Bagnaskiz's laser eyes when he knocks Zampanò. */
  laser,
} as const;

export type FileSoundName = keyof typeof SOUND_FILES;

/** Streamed music tracks. */
export const MUSIC_FILES = {
  /** Title screen, briefing, story menu. */
  intro: introMusic,
  /** Green Zone gameplay (arcade) and the Greenzone levels of the story. */
  greenzone: greenzoneMusic,
} as const;

export type FileMusicTrack = keyof typeof MUSIC_FILES;
