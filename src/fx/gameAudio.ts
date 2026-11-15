import type { AudioEngine } from '../core/audio';
import type { Emitter, GameEvents } from '../core/events';

/** Maps gameplay events to sound effects. */
export function bindGameAudio(events: Emitter<GameEvents>, audio: AudioEngine): void {
  events.on('treat', () => audio.play('treat'));
  events.on('poop', () => audio.play('poop'));
  events.on('pee', (e) => audio.play(e.marking ? 'mark' : 'pee'));
  events.on('peeEmpty', () => audio.play('empty'));
  events.on('poopCleaned', () => audio.play('coin', { rate: 1.5, volume: 0.6 }));
  events.on('drink', () => audio.play('drink'));
  events.on('digestWarning', () => audio.play('warning'));
  events.on('lifeLost', () => audio.play('hurt'));
  events.on('bump', () => audio.play('hurt', { rate: 1.3, volume: 0.8 }));
  events.on('bark', () => audio.play('bark', { rate: 0.95 + Math.random() * 0.1 }));
  events.on('barkHit', () => audio.play('hit'));
  events.on('bagnaskizFled', () => audio.play('flee'));
  events.on('cat', () => audio.play('cat'));
  events.on('ballSpawn', () => audio.play('ball'));
  events.on('fetch', () => audio.play('fetch'));
  events.on('attackStart', () => {
    audio.play('alarm');
    audio.setDuck(0.45);
  });
  events.on('attackEnd', () => {
    audio.play('saved');
    audio.setDuck(1);
  });
  events.on('levelComplete', () => {
    audio.play('jingle');
    audio.setDuck(0.35);
  });
  events.on('gameOver', () => {
    audio.stopMusic();
    audio.play('gameover');
  });
}
