import { AUDIO } from '../config';
import type { AudioEngine } from '../core/audio';
import type { Emitter, GameEvents } from '../core/events';

/** Maps gameplay events to sound effects. */
export function bindGameAudio(events: Emitter<GameEvents>, audio: AudioEngine): void {
  // Recorded sounds (assets/sounds); the rest stays synthesized.
  events.on('treat', () => audio.play('treat'));
  events.on('poop', () => audio.play('poop'));
  events.on('pee', (e) => {
    audio.play('pee');
    if (e.marking) audio.play('star', { delay: 0.12 });
  });
  events.on('peeEmpty', () => audio.play('empty'));
  events.on('tired', () => audio.play('empty', { rate: 0.8 }));
  events.on('poopCleaned', () => audio.play('coin', { rate: 1.5, volume: 0.5 }));
  events.on('drink', () => audio.play('drink'));
  events.on('splash', () => audio.play('splash', { volume: 0.7 }));
  events.on('digestWarning', () => audio.play('warning'));
  events.on('lifeLost', () => audio.play('hurt'));
  events.on('bump', () => audio.play('laser'));
  events.on('bark', () => audio.play('bark', { rate: 0.95 + Math.random() * 0.1 }));
  events.on('barkHit', () => audio.play('hit'));
  events.on('bagnaskizFled', () => audio.play('flee'));
  events.on('cat', () => {
    audio.play('meow');
    audio.play('coin', { delay: AUDIO.CASH_DELAY });
  });
  events.on('ballSpawn', () => audio.play('ball'));
  events.on('fetch', () => audio.play('fetch'));
  events.on('pollutionSurge', () => audio.play('warning', { rate: 0.82, volume: 0.75 }));
  events.on('attackStart', () => {
    audio.play('alarm');
    audio.loop('siren', { volume: AUDIO.SIREN_VOLUME, delay: AUDIO.SIREN_DELAY });
    audio.setDuck(0.45);
  });
  events.on('attackEnd', () => {
    audio.stopLoop('siren');
    audio.play('saved');
    audio.setDuck(1);
  });
  events.on('levelComplete', () => {
    audio.stopLoop('siren');
    audio.play('jingle');
    audio.setDuck(0.35);
  });
  events.on('gameOver', () => {
    audio.stopLoop('siren');
    audio.stopMusic();
    audio.play('gameover');
  });
}
