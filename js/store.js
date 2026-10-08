// App state: ID card, character, reminders, timers, chat, settings. Saved to disk automatically.
import * as P from './platform.js';
import { uuid } from './util.js';

export function defaultSettings() {
  return {
    paiName: 'PAI', form: 'pai', color: 'screen', chassis: 'standard', core: 'ai', hologram: 'face',
    lawset: 'Crewsimov', customLaws: ['Make the crew laugh.', 'Never reveal the location of the snacks.'],
    model: 'claude-haiku-5-5', webSearch: true, speakReplies: false, sounds: true, typingSounds: true,
    bootSequence: true, onboarded: false, highlights: true,
    fork: 'vanilla', bootStyle: 'vanilla', accent: 'none', theme: 'nanotrasen', unitVoice: 'auto', unitBark: '',
    soundPack: 'ss14', personality: 'standard', radioBlips: false, highlightPing: true, emoteSounds: true,
    crtEffects: true, animations: true, trayOnClose: true, startWithWindows: false, notifications: true,
    reminderSound: 'announce', timerSound: 'timer_done', alarmLength: 20, alarmVolume: 0.8, calendarSync: true, clockTimers: false, playWhenSilent: true, clockShortcut: 'PAI Timer',
    music: { enabled: true, muted: false, volume: 0.45, shuffle: true, playlists: [], ambience: null, ambienceVolume: 0.35, autoplay: true },
  };
}
export function defaultProfile() {
  return {
    fullName: '', preferredName: '', pronouns: '', birthday: null, jobTitle: '', stationJob: 'Passenger',
    homeCity: '', interests: '', notes: '', idNumber: uuid().replace(/-/g, '').slice(0, 8), photo: null, showPhoto: false,
    character: null,
  };
}

export const state = {
  profile: defaultProfile(),
  reminders: [],     // {id, title, date(ms), notes, repeat: none|daily|weekly|monthly, lastFired}
  timers: [],        // {id, label, duration, end(ms)|null, paused(sec)|null, finished}
  messages: [],      // {id, role: user|pai|system|emote|userEmote, text, sources, date}
  settings: defaultSettings(),
  apiKey: '',
  lastResponseID: null,
  // runtime only
  mood: 'neutral', thinking: false, freshID: null, bubble: null, connecting: null, transferring: false,
};

const listeners = new Set();
export function subscribe(fn) { listeners.add(fn); return () => listeners.delete(fn); }
export function emit(what = 'all') { for (const fn of listeners) fn(what); }

export async function loadAll() {
  const s = await P.load('state');
  if (s) {
    state.profile = { ...defaultProfile(), ...(s.profile || {}) };
    state.reminders = s.reminders || [];
    state.timers = s.timers || [];
    state.messages = s.messages || [];
    const d = defaultSettings();
    state.settings = { ...d, ...(s.settings || {}), music: { ...d.music, ...(s.settings?.music || {}) } };
    state.lastResponseID = s.lastResponseID || null;
    if (!/^claude/.test(state.settings.model || '')) state.settings.model = 'claude-haiku-5-5'; // moved from OpenAI
  }
  state.apiKey = (await P.load('apikey')) || '';
}

/** Save and notify views. `what` lets views skip work ('settings', 'profile', 'chat', 'timers', 'reminders'). */
export function commit(what = 'all', silent = false) {
  P.save('state', {
    profile: state.profile, reminders: state.reminders, timers: state.timers,
    messages: state.messages.slice(-300), settings: state.settings, lastResponseID: state.lastResponseID,
  });
  if (!silent) emit(what);
}
export function setApiKey(k) { state.apiKey = (k || '').trim(); P.save('apikey', state.apiKey); }

// Reminder occurrence logic (same as the phone app)
export function nextOccurrence(r, now = new Date()) {
  const d = new Date(r.date);
  if (d > now) return d;
  if (r.repeat === 'none' || !r.repeat) return null;
  const c = new Date(now.getFullYear(), now.getMonth(), now.getDate(), d.getHours(), d.getMinutes());
  for (let i = 0; i < 400; i++) {
    if (c > now) {
      if (r.repeat === 'daily') return c;
      if (r.repeat === 'weekly' && c.getDay() === d.getDay()) return c;
      if (r.repeat === 'monthly' && c.getDate() === d.getDate()) return c;
    }
    c.setDate(c.getDate() + 1);
  }
  return null;
}
export function occursOn(r, day) {
  const d = new Date(r.date);
  const s = new Date(day.getFullYear(), day.getMonth(), day.getDate());
  const s0 = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  if (s.getTime() === s0.getTime()) return true;
  if (s < s0) return false;
  if (r.repeat === 'daily') return true;
  if (r.repeat === 'weekly') return day.getDay() === d.getDay();
  if (r.repeat === 'monthly') return day.getDate() === d.getDate();
  return false;
}
export function timeOn(r, day) { const d = new Date(r.date); return new Date(day.getFullYear(), day.getMonth(), day.getDate(), d.getHours(), d.getMinutes()); }
export function nextReminder() {
  let best = null;
  for (const r of state.reminders) { const n = nextOccurrence(r); if (n && (!best || n < best.date)) best = { r, date: n }; }
  return best;
}
export function timerRemaining(t, now = Date.now()) {
  if (t.finished) return 0;
  if (t.end) return Math.max(0, (t.end - now) / 1000);
  return t.paused ?? t.duration;
}
export const userName = () => {
  const p = state.profile;
  return (p.preferredName || '').trim() || (p.fullName || '').trim().split(' ')[0] || '';
};

// ---------------------------------------------------------------- backup file (move your PAI between PC and phone)
export function backupJSON(includeKey = true) {
  return JSON.stringify({ pai: 1, saved: new Date().toISOString(), state: {
    profile: state.profile, reminders: state.reminders, timers: state.timers, messages: state.messages.slice(-300), settings: state.settings,
  }, apiKey: includeKey ? state.apiKey : undefined }, null, 1);
}
export async function restoreBackup(text) {
  const b = JSON.parse(text);
  if (!b || b.pai !== 1 || !b.state) throw new Error("That isn't a PAI backup file.");
  const s = b.state; const local = state.settings;
  // Keep this device's own device settings (tray, startup) when moving between PC and phone.
  for (const k of ['trayOnClose', 'startWithWindows']) if (s.settings) s.settings[k] = local[k];
  P.save('state', { ...s, lastResponseID: null });
  if (b.apiKey) P.save('apikey', b.apiKey);
  await P.flush();
}
