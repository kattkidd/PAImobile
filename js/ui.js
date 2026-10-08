// SS14 UI components (HTML strings) + modal/menu helpers.
import { esc, icon } from './util.js';
import { state } from './store.js';
import { CHASSIS, AI_DELAYS, job as jobOf } from './ss14.js';
import * as A from './audio.js';

export const nh = (title, trailing = '') => `<div class="nh"><div class="t"><span>${title}</span><span>${trailing}</span></div>
  <svg viewBox="0 0 100 6" preserveAspectRatio="none"><polyline points="0,6 96,6 100,0" fill="none" stroke="var(--gold)" stroke-width="1.5" vector-effect="non-scaling-stroke"/></svg></div>`;
export const section = (title, inner, { trailing = '', footer = '', id = '' } = {}) =>
  `<div class="section" ${id ? `id="${id}"` : ''}>${nh(esc(title), esc(trailing))}<div class="panel">${inner}</div>${footer ? `<div class="foot">${footer}</div>` : ''}</div>`;
export const win = (title, inner, { right = '', alert = false, cls = '', style = '' } = {}) =>
  `<div class="win ${cls}" style="${style}"><div class="whead ${alert ? 'alert' : ''}"><span class="grow ellipsis">${state.settings.theme === 'terminal' ? '[ ' + esc(title).toUpperCase() + ' ]' : esc(title)}</span>${right}</div>${inner}</div>`;
export const btn = (label, action, { cls = '', title = '', data = '', disabled = false } = {}) =>
  `<button class="btn ${cls}" data-act="${action}" ${data} ${title ? `title="${esc(title)}"` : ''} ${disabled ? 'disabled' : ''}>${label}</button>`;
export const toggle = (label, path, on) =>
  `<div class="srow toggle ${on ? 'on' : ''}" data-toggle="${path}"><span class="grow">${label}</span><span class="check">${on ? '✓' : ''}</span></div>`;
export const field = (label, path, value, placeholder = '', { alt = false, type = 'text' } = {}) =>
  `<div class="srow ${alt ? 'alt' : ''}"><span class="lab">${label}</span><input class="field" type="${type}" data-model="${path}" value="${esc(value ?? '')}" placeholder="${esc(placeholder)}"></div>`;
export const choice = (title, detail, on, action, data, alt) =>
  `<div class="srow click ${alt ? 'alt' : ''}" data-act="${action}" ${data}><span style="color:${on ? 'var(--gold)' : 'var(--dim)'};font-size:18px">${on ? '☑' : '☐'}</span><div class="grow"><div class="b" style="font-size:14px">${title}</div><div class="small dim">${detail}</div></div></div>`;
export const header = (title, sub, right = '') =>
  `<div class="header stripe"><div class="logo"></div><div class="grow"><h1>${state.settings.theme === 'terminal' ? '&gt; ' + esc(title).toUpperCase() : esc(title)}</h1><div class="small dim">${esc(sub)}</div></div>${right}${muteBtn()}</div>`;
export const muteBtn = () => state.settings.music.enabled
  ? `<button class="btn s ${state.settings.music.muted ? 'ghost' : ''}" data-act="mute" title="${state.settings.music.muted ? 'Unmute music' : 'Mute music'}">${icon(state.settings.music.muted ? 'mute' : 'music', 15)}</button>` : '';
export const jobIcon = (j, s = 16) => `<img class="px" src="img/${j.icon}.png" width="${s}" height="${s}" alt="">`;
export const eq = (playing) => `<span class="eq ${playing ? '' : 'paused'}"><i></i><i></i><i></i><i></i></span>`;

// --- units (pAI device, Station AI core, N14 terminal)
export function aiFrame(state2, t = performance.now() / 1000) {
  const d = AI_DELAYS[state2] || [1]; if (d.length < 2) return 0;
  const total = d.reduce((a, b) => a + b, 0); let x = t % total;
  for (let i = 0; i < d.length; i++) { if (x < d[i]) return i; x -= d[i]; }
  return 0;
}
export function aiState(mood, core) {
  if (mood === 'thinking') return 'ai_empty';
  if (mood === 'off') return 'ai_unpowered';
  if (mood === 'sad') return 'ai_dead';
  if (mood === 'surprised') return 'ai_error';
  return core === 'ai' ? 'ai' : 'ai_' + core;
}
export function screenImg(chassis, mood, frame) {
  if (chassis === 'potato') return mood === 'thinking' ? 'screen_potato_thinking_0' : mood === 'off' ? 'screen_potato_off_0' : 'screen_potato_on_0';
  const skin = chassis === 'syndicate' ? 'syndicate' : 'standard';
  return mood === 'off' ? `screen_${skin}_off_0` : `screen_${skin}_${mood}_${frame % 2}`;
}
/** Unit sprite HTML. `live` units get updated by the animation loop (data-unit attrs). */
export function unit({ form = state.settings.form, mood = 'neutral', chassis = state.settings.chassis, core = state.settings.core, size = 100, live = false, cls = '' } = {}) {
  const attrs = live ? `data-unit="1"` : '';
  if (form === 'stationAI') {
    const st = aiState(mood, core);
    return `<span class="dev ${cls}" ${attrs} style="width:${size}px;height:${size}px"><img src="img/ai_core_base.png"><img data-screen src="img/aiscreen_${st}_${aiFrame(st)}.png"></span>`;
  }
  if (form === 'terminal') {
    const m = CHASSIS[chassis].model;
    if (mood === 'off') return `<span class="dev ${cls}" ${attrs} style="width:${size}px;height:${size}px"><img src="img/n14_${m}_broken.png"></span>`;
    return `<span class="dev ${cls}" ${attrs} style="width:${size}px;height:${size}px"><img src="img/n14_${m}_computer.png"><img data-screen src="img/n14_${m}_screen_0.png" style="${mood === 'sleepy' ? 'opacity:.4' : ''}"></span>`;
  }
  return `<span class="dev ${cls}" ${attrs} style="width:${size}px;height:${size}px"><img src="img/pai_base_${chassis}.png"><img data-screen src="img/${screenImg(chassis, mood, 0)}.png"></span>`;
}
/** Advances live unit screens: pAI flips every 0.8s (and blinks), AI core plays its animation, terminals flicker. */
export function animateUnits(mood) {
  const t = performance.now() / 1000; const s = state.settings;
  for (const el of document.querySelectorAll('[data-unit] [data-screen]')) {
    let src;
    if (s.form === 'stationAI') { const st = aiState(mood, s.core); src = `img/aiscreen_${st}_${aiFrame(st, t)}.png`; }
    else if (s.form === 'terminal') src = `img/n14_${CHASSIS[s.chassis].model}_screen_${Math.floor(t / (mood === 'thinking' ? 0.15 : 0.8)) % 2}.png`;
    else { const m = (mood === 'neutral' && (t % 5) < 0.2) ? 'blink' : mood; src = `img/${screenImg(s.chassis, m, Math.floor(t / 0.8))}.png`; }
    if (!el.src.endsWith(src)) el.src = src;
  }
}

// --- modal windows & popup menus
export function modal(title, inner, { wide = false, right = '' } = {}) {
  const m = document.getElementById('modal');
  m.innerHTML = win(title, `<div class="body">${inner}</div>`, { cls: wide ? 'wide' : '', right: right + `<button class="btn s ghost" data-act="closeModal">${icon('x', 14)}</button>` });
  m.classList.add('show');
  return m;
}
export function closeModal() { const m = document.getElementById('modal'); m.classList.remove('show'); m.innerHTML = ''; }
export function menu(anchor, items) {
  closeMenu();
  const el = document.createElement('div'); el.className = 'menu'; el.id = 'menu';
  el.innerHTML = items.map(it => it.header ? `<div class="mh">${esc(it.header)}</div>` : `<div class="mi" data-i="${items.indexOf(it)}">${it.html ? it.label : esc(it.label)}</div>`).join('');
  document.body.appendChild(el);
  const r = anchor.getBoundingClientRect(); const h = el.offsetHeight, w = el.offsetWidth;
  el.style.left = Math.min(r.left, innerWidth - w - 8) + 'px';
  el.style.top = (r.bottom + h + 8 > innerHeight ? Math.max(8, r.top - h - 4) : r.bottom + 4) + 'px';
  el.addEventListener('click', e => { const i = e.target.closest('.mi')?.dataset.i; if (i != null) { A.sfx('click'); closeMenu(); items[i].run?.(); } });
  setTimeout(() => document.addEventListener('pointerdown', outside), 0);
  function outside(e) { if (!el.contains(e.target)) { closeMenu(); } }
  el._outside = outside;
}
export function closeMenu() { const m = document.getElementById('menu'); if (m) { document.removeEventListener('pointerdown', m._outside); m.remove(); } }


/** Big SS14-style announcement across the top of the screen (tap to dismiss). */
export function banner(title, text, { kind = '', sign = '', ms = 9000 } = {}) {
  document.querySelectorAll('.sbanner').forEach(b => b.remove());
  const el = document.createElement('div'); el.className = 'sbanner ' + kind;
  el.innerHTML = `<div class="ah">${esc(title)}</div><div class="at">${esc(text)}</div>${sign ? `<div class="asig">${esc(sign)}</div>` : ''}`;
  document.body.appendChild(el);
  const close = () => { el.classList.add('out'); setTimeout(() => el.remove(), 300); };
  el.addEventListener('click', close); setTimeout(close, ms);
  return el;
}
