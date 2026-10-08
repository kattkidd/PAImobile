// Every sound: SS14 UI/machine sounds, species voices & emotes, barks, lobby music, ambience.
import { state } from './store.js';
import { tone, STARLIGHT_RADIO } from './ss14.js';
import { pick } from './util.js';
import { musicURL, AUDIO_EXT as EXT } from './platform.js';

export let AUDIO = { speech: {}, emoteSets: {}, emotes: {}, species: {}, barks: [], music: [], ambience: [] };
export async function loadAudio() {
  try { AUDIO = await (await fetch('game/audio/audio.json')).json(); } catch (e) { console.warn('audio.json', e); }
}

// Web Audio for low-latency, overlapping one-shots.
let ctx = null; const buffers = new Map(); const loading = new Map();
function ac() { if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)(); if (ctx.state === 'suspended') ctx.resume(); return ctx; }
function urlFor(name) { return name.startsWith('game:') ? `game/audio/${name.slice(5)}.${EXT}` : /^[pam][0-9a-f]{10}$/.test(name) ? `game/audio/${name}.${EXT}` : `sfx/${name}.${EXT}`; }
async function buffer(name) {
  if (buffers.has(name)) return buffers.get(name);
  if (!loading.has(name)) loading.set(name, (async () => {
    const res = await fetch(urlFor(name)); const data = await res.arrayBuffer();
    const b = await ac().decodeAudioData(data); buffers.set(name, b); return b;
  })().catch(e => { console.warn('sound', name, e); return null; }));
  return loading.get(name);
}
export async function play(name, volume = 0.8, rate = 1) {
  if (!state.settings.sounds || !name) return;
  const b = await buffer(name); if (!b) return;
  const c = ac(); const src = c.createBufferSource(); const g = c.createGain();
  src.buffer = b; src.playbackRate.value = rate; g.gain.value = volume;
  src.connect(g).connect(c.destination); src.start();
}

// SS14 sound names (App/Sounds). A sound pack can swap some for a fork's own version.
const VOL = { click: .45, hover: .45, quickbeep: .45, button: .45, pop: .45, power_on: .6, welcome: .6 };
export function sfx(name, volume) {
  const pack = state.settings.soundPack;
  const swap = pack === 'starlight' ? { id_insert: 'sl_id_pickup', id_swipe: 'sl_id_drop', attention: 'sl_attention', announce: 'sl_announce2' }
    : pack === 'wasteland' ? { announce: 'n14_bark_ring' } : {};
  play(swap[name] || name, volume ?? VOL[name] ?? 0.8);
}

let lastKey = 0;
export function keystroke() {
  if (!state.settings.typingSounds || Date.now() - lastKey < 110) return;
  lastKey = Date.now(); play('keyboard' + (1 + Math.floor(Math.random() * 4)), 0.25);
}

/** Nuclear 14 BarkSystem: 0.05s per character, one bark every 0.15s, ±12.5% pitch. */
export function bark(text, sound, speed = 1) {
  const count = Math.min(Math.max(Math.floor(text.length * 0.05 / (0.15 / speed)), 1), 30);
  for (let i = 0; i < count; i++) setTimeout(() => play(sound, 0.45, 0.875 + Math.random() * 0.25), i * 150 / speed);
}

export function unitSpeech(text, form = state.settings.form) {
  let style = state.settings.unitVoice;
  if (style === 'auto') style = form === 'terminal' ? 'bark' : form === 'stationAI' ? 'borg' : 'pai';
  const t = tone(text); const suf = t === 'ask' ? '_ask' : t === 'exclaim' ? '_exclaim' : '_say';
  switch (style) {
    case 'silent': return;
    case 'bark': return bark(text, state.settings.unitBark || 'n14_bark_keytyped');
    case 'radio': play('sl_radio_ai', 0.5); return play('borg' + suf);
    case 'borg': return play('borg' + suf);
    default: return play('pai' + suf);
  }
}

export function voiceID(c) {
  if (c?.voice && AUDIO.speech[c.voice]) return c.voice;
  return AUDIO.species[c?.species]?.speech || 'Alto';
}
export function userSpeech(text, id) {
  const v = AUDIO.speech[id] || AUDIO.speech.Alto; if (!v) return;
  const t = tone(text); play(t === 'ask' ? v.ask : t === 'exclaim' ? v.exclaim : v.say, 0.7);
}
export function userSend(text) {
  const radio = STARLIGHT_RADIO[state.profile.stationJob];
  if (state.settings.radioBlips && radio) play(radio, 0.6);
  userSpeech(text, voiceID(state.profile.character));
}

export function emoteSounds(emote, species, sex) {
  const sa = AUDIO.species[species];
  if (!sa) return AUDIO.emoteSets.UnisexSilicon?.[emote] || [];
  const set = sa.emotes[sex] || sa.emotes.Unsexed || Object.values(sa.emotes)[0];
  if (set && AUDIO.emoteSets[set]?.[emote]) return AUDIO.emoteSets[set][emote];
  if (sa.body && AUDIO.emoteSets[sa.body]?.[emote]) return AUDIO.emoteSets[sa.body][emote];
  return AUDIO.emoteSets.GeneralBodyEmotes?.[emote] || [];
}
export function availableEmotes(species, sex) {
  return Object.entries(AUDIO.emotes).filter(([id]) => emoteSounds(id, species, sex).length)
    .map(([id, e]) => ({ id, ...e })).sort((a, b) => a.name.localeCompare(b.name));
}
export function findEmote(word) {
  const w = word.toLowerCase().replace(/[^\w\s-]/g, '');
  for (const [id, e] of Object.entries(AUDIO.emotes)) if (e.triggers.includes(w)) return { id, ...e };
  return null;
}
export function characterEmote(id, c) {
  const files = emoteSounds(id, c.species, c.sex); if (!files.length) return false;
  if (state.settings.emoteSounds) play(pick(files), 0.75, 0.94 + Math.random() * 0.12);
  return true;
}
/** Silicon emote sounds for the unit ("PAI beeps."). */
export function unitEmote(action) {
  const a = action.toLowerCase();
  if (a.includes('blink')) return play('sl_blink');
  if (a.includes('twice') || a.includes('buzz-two')) return sfx('buzz_two');
  if (a.includes('buzz')) return sfx('buzz_sigh');
  if (a.includes('chime')) return sfx('chime');
  if (a.includes('ping')) return sfx('ping');
  if (a.includes('beep') || a.includes('boop')) return sfx('twobeep');
}

// ---------------------------------------------------------------- music
class Music {
  constructor() {
    this.el = new Audio(); this.el.preload = 'auto';
    this.amb = new Audio(); this.amb.loop = true;
    this.current = null; this.history = []; this.started = false; this.listeners = new Set();
    this.el.addEventListener('ended', () => this.next());
    this.el.addEventListener('timeupdate', () => this.changed());
    this.el.addEventListener('play', () => this.changed());
    this.el.addEventListener('pause', () => this.changed());
  }
  get s() { return state.settings.music; }
  get playing() { return !this.el.paused && !!this.current; }
  get progress() { return this.el.duration ? this.el.currentTime / this.el.duration : 0; }
  get tracks() {
    const all = AUDIO.music; const pl = this.s.playlists;
    const f = pl.length ? all.filter(t => pl.includes(t.playlist)) : all;
    return f.length ? f : all;
  }
  get playlists() { return [...new Set(AUDIO.music.map(t => t.playlist))]; }
  onChange(fn) { this.listeners.add(fn); }
  changed() { for (const fn of this.listeners) fn(); }
  audible() { return this.s.enabled && !this.s.muted && state.settings.sounds; }
  apply(prev) {
    this.el.volume = this.s.volume;
    if (!this.audible()) { if (this.playing) this.el.pause(); }
    else if (!this.playing) {
      const unmuted = prev && ((prev.muted && !this.s.muted) || (!prev.enabled && this.s.enabled));
      if ((!this.started && this.s.autoplay) || unmuted) this.play();
    }
    this.started = true;
    this.updateAmbience();
    this.changed();
  }
  play() {
    if (!this.audible()) return;
    if (this.current && this.el.src) { this.el.play().catch(() => this.waitForClick()); return; }
    this.next();
  }
  waitForClick() {
    // Webviews may block autoplay until the first click.
    const go = () => { document.removeEventListener('pointerdown', go); if (this.audible()) this.el.play().catch(() => { }); this.updateAmbience(); };
    document.addEventListener('pointerdown', go);
  }
  pause() { this.el.pause(); }
  toggle() { this.playing ? this.pause() : this.play(); }
  next() {
    const list = this.tracks; if (!list.length) return;
    let t;
    if (this.s.shuffle) {
      const recent = this.history.slice(-(list.length - 1));
      const fresh = list.filter(x => !recent.includes(x.file));
      t = pick(fresh.length ? fresh : list);
    } else {
      const i = list.findIndex(x => x.file === this.current?.file);
      t = list[(i + 1) % list.length];
    }
    this.start(t);
  }
  previous() {
    if (this.el.currentTime > 3) { this.el.currentTime = 0; return; }
    if (this.history.length >= 2) { this.history.pop(); const f = this.history.pop(); const t = AUDIO.music.find(x => x.file === f); if (t) return this.start(t); }
    this.el.currentTime = 0;
  }
  async start(t) {
    this.current = t; this.history.push(t.file);
    this.changed();
    const src = await musicURL(t.file);
    if (this.current !== t) return;
    this.el.src = src;
    this.el.volume = 0;
    if (!this.audible()) return;
    this.el.play().then(() => this.fadeIn()).catch(() => this.waitForClick());
  }
  fadeIn() {
    const target = this.s.volume; let v = 0;
    const step = () => { v = Math.min(target, v + target / 24); this.el.volume = v; if (v < target) setTimeout(step, 50); };
    step();
  }
  updateAmbience() {
    const f = this.s.ambience;
    if (!f || !this.s.enabled || this.s.muted || !state.settings.sounds) { this.amb.pause(); return; }
    const src = `game/audio/${f}.${EXT}`;
    if (!this.amb.src.endsWith(src)) this.amb.src = src;
    this.amb.volume = this.s.ambienceVolume;
    this.amb.play().catch(() => this.waitForClick());
  }
}
export const music = new Music();
