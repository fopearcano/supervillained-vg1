import { AUDIO } from '../config';
import { SOUNDS, renderMusic, type SoundName } from '../fx/sounds';
import type { Settings } from './settings';
import { renderSound } from './synth';

const SFX_RATE = 22050;
const MUSIC_RATE = 22050;

/**
 * WebAudio output. Sounds are synthesized once into AudioBuffers (on first use) and played as
 * buffer sources: no assets, minimal CPU. The context is created/resumed on the first user
 * gesture (browser autoplay rules) and suspended while the app is in the background.
 */
export class AudioEngine {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private sfx: GainNode | null = null;
  private music: GainNode | null = null;
  private readonly buffers = new Map<SoundName, AudioBuffer>();
  private readonly lastPlayed = new Map<SoundName, number>();
  private musicBuffer: AudioBuffer | null = null;
  private musicSource: AudioBufferSourceNode | null = null;
  private wantMusic = false;
  private duck = 1;

  constructor(private settings: Settings) {
    const unlock = () => this.unlock();
    window.addEventListener('pointerdown', unlock, { capture: true });
    window.addEventListener('keydown', unlock, { capture: true });
    document.addEventListener('visibilitychange', () => {
      if (!this.ctx) return;
      if (document.hidden) void this.ctx.suspend().catch(() => {});
      else void this.ctx.resume().catch(() => {});
    });
  }

  get ready(): boolean {
    return this.ctx !== null && this.ctx.state === 'running';
  }

  unlock(): void {
    try {
      if (!this.ctx) {
        const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
        if (!Ctor) return;
        this.ctx = new Ctor();
        this.master = this.ctx.createGain();
        this.sfx = this.ctx.createGain();
        this.music = this.ctx.createGain();
        this.sfx.gain.value = AUDIO.SFX_VOLUME;
        this.music.gain.value = AUDIO.MUSIC_VOLUME;
        this.sfx.connect(this.master);
        this.music.connect(this.master);
        this.master.connect(this.ctx.destination);
        this.applySettings(this.settings);
        // Render the music a moment later so the first tap stays snappy.
        setTimeout(() => this.prepareMusic(), 60);
      }
      if (this.ctx.state !== 'running') void this.ctx.resume().catch(() => {});
    } catch (err) {
      console.warn('[audio] unavailable', err);
    }
  }

  applySettings(s: Settings): void {
    this.settings = s;
    if (this.master && this.ctx) {
      this.master.gain.setTargetAtTime(s.muted ? 0 : s.volume, this.ctx.currentTime, 0.02);
    }
  }

  play(name: SoundName, opts: { volume?: number; rate?: number } = {}): void {
    const ctx = this.ctx;
    if (!ctx || !this.sfx || this.settings.muted || ctx.state !== 'running') return;
    const now = ctx.currentTime;
    if (now - (this.lastPlayed.get(name) ?? -1) < 0.045) return;
    this.lastPlayed.set(name, now);
    let buf = this.buffers.get(name);
    if (!buf) {
      const data = renderSound(SOUNDS[name], SFX_RATE);
      buf = ctx.createBuffer(1, data.length, SFX_RATE);
      buf.copyToChannel(data as Float32Array<ArrayBuffer>, 0);
      this.buffers.set(name, buf);
    }
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.playbackRate.value = opts.rate ?? 1;
    if (opts.volume !== undefined && opts.volume !== 1) {
      const g = ctx.createGain();
      g.gain.value = opts.volume;
      src.connect(g).connect(this.sfx);
    } else {
      src.connect(this.sfx);
    }
    src.start();
  }

  startMusic(): void {
    this.wantMusic = true;
    this.ensureMusicPlaying();
  }

  stopMusic(): void {
    this.wantMusic = false;
    try {
      this.musicSource?.stop();
    } catch {
      /* already stopped */
    }
    this.musicSource = null;
  }

  /** Lowers the music (e.g. 0.4 during "under attack"). */
  setDuck(amount: number): void {
    if (Math.abs(amount - this.duck) < 0.01) return;
    this.duck = amount;
    if (this.music && this.ctx) this.music.gain.setTargetAtTime(AUDIO.MUSIC_VOLUME * amount, this.ctx.currentTime, 0.15);
  }

  private prepareMusic(): void {
    const ctx = this.ctx;
    if (!ctx || this.musicBuffer) return;
    const data = renderMusic(MUSIC_RATE);
    const buf = ctx.createBuffer(1, data.length, MUSIC_RATE);
    buf.copyToChannel(data as Float32Array<ArrayBuffer>, 0);
    this.musicBuffer = buf;
    this.ensureMusicPlaying();
  }

  private ensureMusicPlaying(): void {
    const ctx = this.ctx;
    if (!ctx || !this.music || !this.musicBuffer || !this.wantMusic || this.musicSource) return;
    const src = ctx.createBufferSource();
    src.buffer = this.musicBuffer;
    src.loop = true;
    src.connect(this.music);
    src.start();
    this.musicSource = src;
  }
}
