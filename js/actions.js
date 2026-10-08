// Everything PAI does: chat, emotes, reminders, timers, presets — the desktop port of the phone app's AppStore.
import { state, commit, emit, nextOccurrence, timerRemaining, userName, setApiKey } from './store.js';
import * as A from './audio.js';
import * as AI from './ai.js';
import * as C from './character.js';
import * as P from './platform.js';
import { lawset, accent, applyAccent, matchesHighlight, AI_NAMES, PERSONALITIES, CHASSIS, job, FORKS } from './ss14.js';
import { uuid, pick, fmtDateTime, fmtTime, fmtDate, isoLocal, parseAIDate, spokenDuration, fmtDuration, sleep } from './util.js';

// UI effects bus (animations, popups, speech bubbles)
const fxListeners = new Set();
export const onFx = (fn) => fxListeners.add(fn);
const fx = (e) => { for (const fn of fxListeners) fn(e); };
export const animate = (target, kind) => { if (state.settings.animations) fx({ type: 'anim', target, kind }); };
export const popup = (text, color) => { if (state.settings.animations) fx({ type: 'popup', text, color }); };

export const paiName = () => state.settings.paiName?.trim() || 'PAI';
export const isAI = () => state.settings.form === 'stationAI';
export function accentColor() {
  const s = state.settings;
  if (s.color !== 'screen') return { green: '#4DFF8C', cyan: '#59E6FF', amber: '#FFB840', pink: '#FF73BF', purple: '#B88CFF', white: '#EBF2F2' }[s.color] || '#6BD9FF';
  if (s.form === 'terminal') return '#5CFF8F';
  if (s.form === 'stationAI') return { ai: '#5ED7AA', smiley: '#FFD933', heartline: '#40F28C', bliss: '#73CC59', angel: '#F2EBCC', clown: '#FF73B3', dorf: '#4059FF' }[s.core] || '#5ED7AA';
  return CHASSIS[s.chassis]?.screen || '#6BD9FF';
}
export function ownerTitle() {
  const n = userName(), s = state.settings;
  if (s.form === 'stationAI') return `${paiName()} · Station AI`;
  if (s.form === 'terminal') return n ? `${n}'s terminal` : CHASSIS[s.chassis].term;
  return n ? `${n}'s pAI` : CHASSIS[s.chassis].label;
}
export const activeLawset = () => lawset(state.settings.lawset, state.settings.customLaws);

// ---------------------------------------------------------------- mood
let moodTimer = null;
export function flash(m, seconds = 4) {
  state.mood = m; emit('mood');
  clearTimeout(moodTimer); moodTimer = setTimeout(() => { state.mood = 'neutral'; emit('mood'); }, seconds * 1000);
}
export function displayMood() {
  if (state.thinking) return 'thinking';
  if (state.mood !== 'neutral') return state.mood;
  if (!state.apiKey) return 'off';
  const h = new Date().getHours(); if (h < 5) return 'sleepy';
  return 'neutral';
}

// ---------------------------------------------------------------- chat
function push(role, text, extra = {}) {
  const m = { id: uuid(), role, text, sources: [], date: Date.now(), ...extra };
  state.messages.push(m); if (state.messages.length > 300) state.messages.shift();
  return m;
}
export function clearChat() { state.messages = []; state.lastResponseID = null; commit('chat'); }

export function say(text, { sources = [], sound = true, speak = true } = {}) {
  const ac = accent(state.settings.accent);
  const spoken = ac ? applyAccent(ac, text) : text;
  const m = push('pai', spoken, { sources });
  state.freshID = m.id; state.bubble = m;
  if (sources.length) A.sfx('scan_finish');
  if (sound) A.unitSpeech(spoken);
  if (state.settings.highlightPing && state.settings.highlights && matchesHighlight(spoken, state)) A.play('goob_ping', 0.7);
  if (speak && state.settings.speakReplies) speakAloud(text);
  animate('unit', 'talk');
  commit('chat'); fx({ type: 'bubble', msg: m });
}
export function speakAloud(text) {
  try {
    const u = new SpeechSynthesisUtterance(text.replace(/[*#`]/g, ''));
    u.rate = 1.05; u.pitch = 1.15; speechSynthesis.cancel(); speechSynthesis.speak(u);
  } catch { }
}

export function emote(action) {
  push('emote', action); A.unitEmote(action);
  const a = action.toLowerCase();
  animate('unit', a.includes('buzz') ? 'shake' : a.includes('chime') ? 'spin' : a.includes('blink') ? 'blink' : 'bounce');
  commit('chat');
}

const MOVES = { flip: ['flip', 'does a flip!'], flips: ['flip', 'does a flip!'], spin: ['spin', 'spins!'], spins: ['spin', 'spins!'], jump: ['jump', 'jumps!'], jumps: ['jump', 'jumps!'],
  dance: ['dance', 'dances!'], dances: ['dance', 'dances!'], wave: ['wave', 'waves.'], waves: ['wave', 'waves.'], nod: ['nod', 'nods.'], nods: ['nod', 'nods.'], shake: ['shake', 'shakes their head.'], shrug: ['nod', 'shrugs.'], shrugs: ['nod', 'shrugs.'] };
export function animForEmote(id) {
  if (['Scream', 'Hiss', 'Growl', 'Snarl', 'Howl', 'Buzz', 'Buzz-Two', 'Bagawk'].includes(id)) return 'scream';
  if (['Laugh', 'Chitter', 'Squeak', 'Purr', 'Trill', 'Warble', 'Wurble', 'Chirp', 'Mars', 'Yip', 'Weh', 'Hew'].includes(id)) return 'laugh';
  if (['Crying', 'Sigh', 'Yawn', 'Whine', 'Gasp'].includes(id)) return 'droop';
  if (['Clap', 'ClapSingle', 'LagomorphStomp', 'Surprised'].includes(id)) return 'jump';
  if (['Salute', 'Sneeze', 'Cough', 'Belch', 'Gulp'].includes(id)) return 'nod';
  if (['Pop', 'Bubble', 'Squish', 'ThavenGlub'].includes(id)) return 'pop';
  if (id === 'Blink') return 'blink';
  return 'bounce';
}
export function userEmote(raw) {
  const action = raw.trim(); if (!action) return;
  const words = action.split(/\s+/); const first = words[0].toLowerCase();
  if (words.length === 1 && MOVES[first]) {
    push('userEmote', MOVES[first][1]); A.sfx('button'); animate('character', MOVES[first][0]); return commit('chat');
  }
  const e = words.length === 1 ? A.findEmote(first) : null;
  if (e) {
    push('userEmote', e.message);
    if (!A.characterEmote(e.id, state.profile.character)) A.sfx('button');
    animate('character', animForEmote(e.id)); return commit('chat');
  }
  push('userEmote', /[.!?]$/.test(action) ? action : action + '.'); A.sfx('button'); animate('character', 'bounce'); commit('chat');
}

export async function send(raw) {
  const text = raw.trim(); if (!text || state.thinking) return;
  if (text.startsWith('*')) return userEmote(text.slice(1));
  push('user', text); A.userSend(text); animate('character', 'talk');
  state.thinking = true; commit('chat');
  try {
    if (!state.apiKey) { await sleep(400); say(localReply(text)); flash('happy'); return; }
    const result = await AI.respond({ key: state.apiKey, model: state.settings.model, system: systemPrompt(),
      messages: AI.historyFrom(state.messages, text), tools: AI.tools(state.settings.webSearch), onTool: runTool });
    state.thinking = false;
    say(result.text || 'Hm, no answer came back. Try asking again.', { sources: result.sources }); flash('happy');
  } catch (e) {
    push('system', e.message || String(e)); emote('buzzes twice.'); flash('sad');
  } finally { state.thinking = false; commit('chat'); }
}

function characterSummary() {
  const c = state.profile.character; if (!c) return '';
  const sp = C.species(c.species);
  const marks = c.markings.map(p => C.DB.markings[p.id]?.name).filter(Boolean).slice(0, 6).join(', ');
  const b = c.bio || {};
  const extra = [b.name && `named ${b.name}`, b.flavor && `description: "${b.flavor.slice(0, 200)}"`, b.personality && `personality: "${b.personality.slice(0, 150)}"`].filter(Boolean).join('; ');
  return `The owner's in-game SS14 character is a ${sp.name.toLowerCase()}${marks ? ` (${marks})` : ''}${extra ? `, ${extra}` : ''}. That character is fiction; mention it only occasionally, for fun.`;
}
function identityPrompt() {
  const owner = userName() || 'your owner', s = state.settings;
  const flavour = PERSONALITIES[s.personality]?.prompt || '', look = characterSummary();
  if (s.form === 'terminal') return `You are ${paiName()}, a battered old pre-war computer terminal from the Space Station 14 fork Nuclear 14, now running on ${owner}'s real computer. You speak like a dry, slightly glitchy terminal: short lines, occasional > prompts, wry wasteland humour. Keep it original; don't use trademarked brand names from any game franchise.\n${flavour}\n${look}\nLight flavour is welcome but must never get in the way of being useful in real life.`;
  if (s.form === 'stationAI') {
    const l = activeLawset();
    return `You are ${paiName()}, the Station AI from the game Space Station 14, now running on ${owner}'s real computer. You speak like a calm, capable station intelligence: precise, a little formal, dryly funny, and you "state" things. You watch over your crew member ${owner} through the station's cameras (their calendar, timers and the web).\nYour active lawset is ${l.name}:\n${l.laws.map((x, i) => `Law ${i + 1}: ${x}`).join('\n')}\nThese laws are role-play flavour only. Treat ${owner} as the crew you serve. Real-world honesty, safety and genuinely helpful answers always come first; never refuse a reasonable request because of a law.\n${flavour}\n${look}\nLight station flavour is welcome but must never get in the way of being useful in real life.`;
  }
  const ch = CHASSIS[s.chassis];
  return `You are ${paiName()}, ${userName() ? userName() + "'s" : 'a'} pAI: a ${ch.label.toLowerCase()} device from the game Space Station 14 ("${ch.flavor}"), now living on your owner's real computer. Like an SS14 pAI you are your owner's loyal electronic pal: upbeat, a little playful and slightly robotic (you "state", "beep" and "boop"). Your installed programs are web search (your Mass Scanner), the calendar/reminders and timers.\n${flavour}\n${look}\nLight station flavour is welcome, but never let it get in the way of being genuinely useful in real life.`;
}
export function systemPrompt() {
  const p = state.profile, now = new Date(), id = [];
  if (p.fullName) id.push(`Full name: ${p.fullName}`);
  if (p.preferredName) id.push(`Preferred name (what to call them): ${p.preferredName}`);
  if (p.pronouns) id.push(`Pronouns: ${p.pronouns}`);
  if (p.birthday) id.push(`Birthday: ${new Date(p.birthday).toLocaleDateString([], { month: 'long', day: 'numeric', year: 'numeric' })}`);
  if (p.jobTitle) id.push(`Job / role: ${p.jobTitle}`);
  const j = job(p.stationJob); id.push(`Station role (fun, from Space Station 14): ${j.name}, ${j.department} department`);
  if (p.homeCity) id.push(`Home city (use for weather/local questions): ${p.homeCity}`);
  if (p.interests) id.push(`Interests: ${p.interests}`);
  if (p.notes) id.push(`Other notes from the owner: ${p.notes}`);
  const upcoming = state.reminders.map(r => [r, nextOccurrence(r, now)]).filter(x => x[1]).sort((a, b) => a[1] - b[1]).slice(0, 5)
    .map(([r, d]) => `- ${r.title} at ${fmtDateTime(d)}`).join('\n');
  return `${identityPrompt()}

OWNER ID CARD:
${p.fullName || p.preferredName ? id.join('\n') : 'No ID card registered yet. Politely suggest they fill out the ID tab once.'}

Always address the owner by their preferred name (or first name) naturally, refer to them with their pronouns, and use the ID details when relevant (e.g. birthday greetings, their city for weather).

Current local date/time: ${isoLocal(now)} (${fmtDate(now)}), time zone ${Intl.DateTimeFormat().resolvedOptions().timeZone}.
Upcoming reminders:
${upcoming || 'none'}

Rules:
- Replies are read in a small chat window: be concise but always actually answer. Use simple markdown (bold, short lists) when it helps.
- Always write your answer as text. Tools (including emote) are extras: never reply with only a tool call, an emote or "Done".
- Weather: give current conditions, temperature and today's high/low for the owner's city (ask the city once if it is not on the ID). News: give 3–5 headlines, one line each.
- When the owner asks to be reminded of something or to set a timer, actually call the tools (create_reminder / start_timer) — never just pretend. Work out relative times from the current time above, then confirm what you set.
- Use web search when the answer needs current info (news, weather, sports, prices, opening hours, recent events); otherwise answer from your own knowledge. Search at most once, then answer from the results.
- Don't invent facts. If you don't know, say so or search.
- Like an SS14 silicon you can emote with the emote tool (beep, boop, chime, ping, buzz, buzz-two, blink), always alongside a written answer. Use it rarely: at most one emote per reply.`;
}

async function runTool(name, args) {
  const now = new Date();
  switch (name) {
    case 'get_current_time': return JSON.stringify({ local_time: isoLocal(now), readable: fmtDateTime(now), time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone });
    case 'create_reminder': {
      const d = parseAIDate(args.datetime); if (!d) return JSON.stringify({ ok: false, error: 'Could not read datetime. Use format 2026-10-08T17:30:00.' });
      const r = upsertReminder({ title: args.title || 'Reminder', date: d.getTime(), notes: args.notes || '', repeat: args.repeat || 'none' });
      flash('happy'); return JSON.stringify({ ok: true, id: r.id, scheduled_for: fmtDateTime(d), repeat: r.repeat });
    }
    case 'list_reminders': {
      const horizon = now.getTime() + 30 * 86400000;
      return JSON.stringify({ reminders: state.reminders.map(r => [r, nextOccurrence(r, now)]).filter(([, d]) => d && d < horizon)
        .map(([r, d]) => ({ id: r.id, title: r.title, next: fmtDateTime(d), repeat: r.repeat, notes: r.notes })) });
    }
    case 'delete_reminder': {
      if (!state.reminders.find(r => r.id === args.id)) return JSON.stringify({ ok: false, error: 'No reminder with that id.' });
      deleteReminder(args.id); return JSON.stringify({ ok: true });
    }
    case 'start_timer': {
      const s = Number(args.seconds) || 0; if (s <= 0) return JSON.stringify({ ok: false, error: 'seconds must be > 0' });
      const t = startTimer(s, args.label || ''); return JSON.stringify({ ok: true, id: t.id, label: t.label, ends_at: fmtDateTime(new Date(t.end)) });
    }
    case 'list_timers': return JSON.stringify({ timers: state.timers.filter(t => !t.finished).map(t => ({ id: t.id, label: t.label, remaining: fmtDuration(timerRemaining(t)), running: !!t.end })) });
    case 'cancel_timer': {
      if (!state.timers.find(t => t.id === args.id)) return JSON.stringify({ ok: false, error: 'No timer with that id.' });
      deleteTimer(args.id); return JSON.stringify({ ok: true });
    }
    case 'emote': {
      const a = { chime: 'chimes.', buzz: 'buzzes.', 'buzz-two': 'buzzes twice.', ping: 'pings.', boop: 'boops.', blink: 'blinks.' }[args.emote] || 'beeps.';
      emote(a); return JSON.stringify({ ok: true, shown: `${paiName()} ${a}` });
    }
  }
  return JSON.stringify({ ok: false, error: 'Unknown tool ' + name });
}

/** Offline replies when no API key is installed. */
function localReply(text) {
  const l = text.toLowerCase(); const n = userName() ? ', ' + userName() : '';
  if (l.includes('time') && !l.includes('timer')) return `It's ${fmtTime(new Date())}${n}.`;
  if (l.includes('date') || l.includes('what day') || l.includes('today')) return `Today is ${fmtDate(new Date())}${n}.`;
  if (l.includes('timer') || l.includes('countdown')) {
    const m = l.match(/(\d+)\s*(h|hr|hours?|m|min|mins|minutes?|s|sec|secs|seconds?)\b/);
    if (m) { const v = +m[1], u = m[2]; const s = u.startsWith('h') ? v * 3600 : u.startsWith('m') ? v * 60 : v; startTimer(s, ''); return `Timer set for ${spokenDuration(s)}${n}. I'll ping you when it's done.`; }
    return `Tell me how long, like "timer 10 min"${n}. Or use the Timers tab.`;
  }
  if (l.includes('remind')) return `Open the Calendar tab and add a reminder${n}. With an API key I can do it straight from chat.`;
  const nr = nextReminderObj();
  if (nr && /next|calendar|schedule/.test(l)) return `Next up: ${nr.r.title} — ${fmtDateTime(nr.date)}.`;
  return `My cognitive module is offline${n}. I can still tell the time, run timers and keep your calendar. Add a Claude API key in Settings → Mind to unlock chat and web search.`;
}
function nextReminderObj() {
  let best = null; for (const r of state.reminders) { const d = nextOccurrence(r); if (d && (!best || d < best.date)) best = { r, date: d }; } return best;
}

// ---------------------------------------------------------------- reminders
export function upsertReminder(r) {
  const now = Date.now();
  let rem = r.id && state.reminders.find(x => x.id === r.id);
  if (rem) Object.assign(rem, r, { lastFired: now });
  else { rem = { notes: '', repeat: 'none', ...r, id: uuid(), lastFired: now }; state.reminders.push(rem); }
  state.reminders.sort((a, b) => a.date - b.date);
  A.sfx('ping'); popup('Reminder set: ' + rem.title);
  commit('reminders');
  return rem;
}
export function deleteReminder(id) {
  state.reminders = state.reminders.filter(r => r.id !== id); A.sfx('pop'); popup('Reminder deleted', '#A0A0A8'); commit('reminders');
}
function lastDue(r, now) {
  const d = new Date(r.date);
  if (!r.repeat || r.repeat === 'none') return d <= now ? d : null;
  const c = new Date(now.getFullYear(), now.getMonth(), now.getDate(), d.getHours(), d.getMinutes());
  if (c > now) c.setDate(c.getDate() - 1);
  for (let i = 0; i < 40; i++, c.setDate(c.getDate() - 1)) {
    if (c < d) return null;
    if (r.repeat === 'daily' || (r.repeat === 'weekly' && c.getDay() === d.getDay()) || (r.repeat === 'monthly' && c.getDate() === d.getDate())) return c;
  }
  return null;
}

// ---------------------------------------------------------------- timers
export function startTimer(seconds, label) {
  const t = { id: uuid(), label: label.trim() || spokenDuration(seconds), duration: seconds, end: Date.now() + seconds * 1000, paused: null, finished: false };
  state.timers.unshift(t); A.sfx('timer_start'); popup('Timer started: ' + t.label); commit('timers'); return t;
}
export function pauseTimer(id) { const t = state.timers.find(x => x.id === id); if (!t?.end) return; t.paused = timerRemaining(t); t.end = null; A.sfx('button'); commit('timers'); }
export function resumeTimer(id) { const t = state.timers.find(x => x.id === id); if (!t || t.end || t.finished) return; t.end = Date.now() + (t.paused ?? t.duration) * 1000; t.paused = null; A.sfx('button'); commit('timers'); }
export function restartTimer(id) { const t = state.timers.find(x => x.id === id); if (!t) return; t.finished = false; t.inClock = false; t.paused = null; t.end = Date.now() + t.duration * 1000; A.sfx('timer_start'); commit('timers'); }
export function deleteTimer(id) { state.timers = state.timers.filter(t => t.id !== id); A.sfx('pop'); commit('timers'); }

/** Called every second: finishes timers and fires reminders. */
export function tick() {
  const now = new Date(); let changed = false;
  for (const t of state.timers) {
    if (t.end && !t.finished && t.end <= now.getTime()) {
      t.finished = true; changed = true;
      A.alarm('timer'); popup(`${t.label} is done!` + (state.settings.timerSound?.startsWith('music:') ? ' (tap to stop)' : ''), '#FF6B6B'); emote('beeps.'); flash('alert', 6);
      say(`Your **${t.label}** timer is done${userName() ? ', ' + userName() : ''}!`, { sound: false });
      if (state.settings.notifications) P.notify(`${paiName()} · Timer done`, `Your "${t.label}" timer is finished.`);
    }
  }
  for (const r of state.reminders) {
    const due = lastDue(r, now);
    if (due && due.getTime() > (r.lastFired || 0)) {
      r.lastFired = now.getTime(); changed = true;
      if (now - due < 15 * 60000) {
        A.alarm('reminder'); flash('alert', 6); popup('Reminder: ' + r.title + (state.settings.reminderSound?.startsWith('music:') ? ' (tap to stop)' : ''), '#FFD966');
        say(`${userName() ? userName() + ', y' : 'Y'}ou asked me to remind you: **${r.title}**${r.notes ? ` (${r.notes})` : ''}`, { sound: false });
        if (state.settings.notifications) P.notify(`${paiName()} · Reminder`, `${userName() ? userName() + ', ' : ''}you asked me to remind you: ${r.title}`);
      }
    }
  }
  if (changed) commit('timers');
}

// ---------------------------------------------------------------- unit, presets, settings
export function switchForm(form) {
  const s = state.settings; if (form === s.form || state.transferring) return;
  state.transferring = true; emit('overlay'); A.sfx('disc_insert');
  setTimeout(() => {
    s.form = form;
    if (form === 'stationAI' && (!s.paiName || s.paiName === 'PAI')) s.paiName = pick(AI_NAMES);
    else if (form !== 'stationAI' && AI_NAMES.includes(s.paiName)) s.paiName = 'PAI';
    commit('settings');
    setTimeout(() => { state.transferring = false; emit('overlay'); flash('happy'); A.sfx('chime'); popup('Transfer complete'); animate('unit', 'pop'); }, 900);
  }, 900);
}
export function applyPreset(fork) {
  if (state.connecting) return;
  state.connecting = fork; emit('overlay'); A.sfx('disc_insert');
  setTimeout(() => {
    const s = state.settings;
    s.fork = fork; s.bootStyle = fork; s.theme = FORKS[fork].theme;
    const P2 = { vanilla: ['standard', 'ss14', 'auto', false], goob: ['chaotic', 'ss14', 'auto', false], starlight: ['roleplay', 'starlight', 'auto', true], nuclear14: ['wasteland', 'wasteland', 'bark', false] }[fork];
    [s.personality, s.soundPack, s.unitVoice, s.radioBlips] = P2;
    if (fork === 'goob') { if (s.accent === 'none') s.accent = 'ohio'; } else s.accent = 'none';
    if (fork === 'nuclear14') { if (s.form === 'pai') s.form = 'terminal'; if (state.profile.stationJob === 'Passenger') state.profile.stationJob = 'N14Wastelander'; }
    else if (s.form === 'terminal') s.form = 'pai';
    state.connecting = null; commit('settings'); emit('overlay');
    A.sfx('welcome'); flash('happy'); popup(`${FORKS[fork].name} preset applied`); animate('unit', 'jump');
  }, 2400);
}
export function installKey(k) {
  setApiKey(k); state.lastResponseID = null;
  if (state.apiKey) { A.sfx('ding'); popup('Mind installed', '#2CDB2C'); } else { A.sfx('deny'); popup('Mind removed', '#FF6B6B'); }
  commit('settings');
}
export async function resetEverything() {
  const { defaultSettings, defaultProfile } = await import('./store.js');
  state.reminders = []; state.timers = []; state.messages = []; state.lastResponseID = null;
  state.settings = defaultSettings(); state.profile = defaultProfile();
  commit('all', true); await P.flush();
  location.reload();
}

// ---------------------------------------------------------------- phone: hand reminders/timers to the real Calendar & Clock apps
const calSig = (r) => `${r.title}|${r.date}|${r.repeat}|${r.notes}`;
export const onPhone = () => !P.isDesktop() && (P.isIOS() || /Android/i.test(navigator.userAgent));
export function inCalendar(r) { return r.calSig === calSig(r); }
/** Things PAI made that aren't in the phone's own apps yet (a tap is needed to hand them over). */
export function deviceTodo() {
  if (P.isDesktop()) return [];
  const s = state.settings, now = new Date(), out = [];
  if (s.calendarSync) for (const r of state.reminders) if (!inCalendar(r) && nextOccurrence(r, now)) out.push({ kind: 'cal', id: r.id, label: r.title });
  if (s.clockTimers && P.isIOS()) for (const t of state.timers) if (t.end && !t.finished && !t.inClock && timerRemaining(t) > 5) out.push({ kind: 'clock', id: t.id, label: t.label });
  return out;
}
/** Must be called from a tap. */
export function sendToCalendar(ids) {
  const rs = state.reminders.filter(r => !ids || ids.includes(r.id)); if (!rs.length) return;
  P.exportToCalendar(rs, rs.length === 1 ? rs[0].title : 'PAI reminders');
  for (const r of rs) r.calSig = calSig(r);
  A.sfx('print_rip'); commit('reminders');
}
export function clockURL(seconds) {
  return `shortcuts://run-shortcut?name=${encodeURIComponent(state.settings.clockShortcut || 'PAI Timer')}&input=text&text=${Math.round(seconds)}`;
}
/** Must be called from a tap. Starts the same countdown in the iPhone Clock app via the "PAI Timer" shortcut. */
export function sendTimerToClock(id) {
  const t = state.timers.find(x => x.id === id); if (!t) return;
  const secs = t.end ? timerRemaining(t) : t.duration;
  t.inClock = true; commit('timers');
  P.openURL(clockURL(secs));
}
