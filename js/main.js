// PAI desktop: app shell, routing, global events, ticker, overlays.
import { state, loadAll, commit, subscribe, emit } from './store.js';
import * as A from './audio.js';
import * as C from './character.js';
import * as X from './actions.js';
import * as P from './platform.js';
import * as UI from './ui.js';
import { icon, esc, sleep } from './util.js';
import { FORKS, job } from './ss14.js';
import home from './views/home.js';
import notes from './views/notes.js';
import calendar from './views/calendar.js';
import timers from './views/timers.js';
import idview from './views/id.js';
import settings from './views/settings.js';
import { runBoot } from './views/boot.js';
import { runOnboarding } from './views/onboarding.js';
import { openEditor } from './views/editor.js';

const VIEWS = { home, calendar, timers, notes, id: idview, settings };
const TABS = [['home', 'cpu', null], ['calendar', 'calendar', 'Calendar'], ['timers', 'timer', 'Timers'], ['notes', 'note', 'Notes'], ['id', 'id', 'ID'], ['settings', 'gear', 'Settings']];
export let current = 'home';
let forward = true;
export const app = { openEditor, go, rerender, renderSide };

function tabLabel(id) { return id === 'home' ? ({ pai: 'pAI', stationAI: 'AI', terminal: 'Terminal' }[state.settings.form]) : TABS.find(t => t[0] === id)[2]; }

export function renderSide() {
  const side = document.getElementById('side');
  const m = A.music;
  side.innerHTML = `
    <div class="brand"><div class="logo"></div><div><div class="b" style="font-size:18px">${esc(X.paiName())}</div><div class="tiny dim">${esc(FORKS[state.settings.fork].name)} · ${esc(state.settings.theme)}</div></div></div>
    ${TABS.map(([id, ic]) => `<div class="tab cham ${current === id ? 'on' : ''}" data-act="go" data-v="${id}">${icon(ic)}<span>${tabLabel(id)}</span></div>`).join('')}
    <div class="spacer"></div>
    <div class="sideextra col" style="gap:8px">
      ${state.settings.music.enabled ? `<div class="srow click" data-act="go" data-v="settings" data-page="audio" style="padding:8px;border:1px solid rgba(255,255,255,.06);gap:8px">${UI.eq(m.playing && !state.settings.music.muted)}<div class="grow"><div class="small ellipsis">${esc(m.current?.title || 'Lobby music')}</div><div class="tiny dim ellipsis">${esc(m.current ? m.current.artist : 'Press play')}</div></div></div>
      <div class="row-flex">${UI.btn(icon('prev', 14), 'musicPrev', { cls: 's ghost' })}${UI.btn(icon(m.playing ? 'pause' : 'play', 14), 'musicToggle', { cls: 's' })}${UI.btn(icon('next', 14), 'musicNext', { cls: 's ghost' })}<span class="grow"></span>${UI.muteBtn()}</div>` : ''}
      ${P.isDesktop() ? UI.btn(icon('mini', 14) + ' Mini mode', 'mini', { cls: 's ghost' }) : ''}
    </div>`;
}

export function go(view, opts = {}) {
  if (!VIEWS[view]) return;
  forward = Object.keys(VIEWS).indexOf(view) >= Object.keys(VIEWS).indexOf(current);
  const changed = view !== current; current = view;
  if (opts.page && VIEWS[view].setPage) VIEWS[view].setPage(opts.page);
  rerender(changed);
  renderSide();
  if (changed && state.settings.crtEffects) { const s = document.getElementById('sweep'); s.classList.remove('go'); void s.offsetWidth; s.classList.add('go'); }
}

export function rerender(animateIn = false) {
  const main = document.getElementById('main');
  const v = VIEWS[current];
  // keep scroll position + focused field when re-rendering the same screen
  const sc = main.querySelector('.content')?.scrollTop || 0;
  const focusPath = document.activeElement?.dataset?.model; const sel = focusPath ? [document.activeElement.selectionStart, document.activeElement.selectionEnd] : null;
  main.innerHTML = v.render();
  const content = main.querySelector('.content');
  if (content) { if (animateIn) content.firstElementChild?.classList.add('screen', ...(forward ? [] : ['back'])); else content.scrollTop = sc; }
  if (focusPath) { const f = main.querySelector(`[data-model="${focusPath}"]`); if (f) { f.focus(); try { f.setSelectionRange(...sel); } catch { } } }
  v.mounted?.(main);
}

// ---------------------------------------------------------------- generic bindings
function getPath(path) { return path.split('.').reduce((o, k) => o?.[k], state); }
function setPath(path, value) {
  const ks = path.split('.'); const last = ks.pop(); const o = ks.reduce((o2, k) => o2[k], state); o[last] = value;
}
function bindGlobal() {
  document.addEventListener('click', (e) => {
    const ext = e.target.closest('a[data-ext], a[href^="http"]');
    if (ext) { e.preventDefault(); P.openLink(ext.getAttribute('href')); return; }
    const t = e.target.closest('[data-toggle]');
    if (t) {
      const path = t.dataset.toggle; setPath(path, !getPath(path)); A.sfx('click');
      afterSettingChange(path); return;
    }
    const a = e.target.closest('[data-act]');
    if (!a || a.disabled) return;
    const name = a.dataset.act;
    if (a.tagName === 'BUTTON' || a.classList.contains('tab')) A.sfx('click');
    if (window.__editorAct?.[name] && a.closest('#modal')) return window.__editorAct[name](a, e);
    const v = VIEWS[current];
    if (v.act?.[name]) return v.act[name](a, e);
    if (GLOBAL[name]) return GLOBAL[name](a, e);
    // Onboarding and pop-ups reuse Settings/ID controls, so check those first.
    for (const k of ['settings', 'id', ...Object.keys(VIEWS)]) if (VIEWS[k]?.act?.[name]) return VIEWS[k].act[name](a, e);
    if (window.__editorAct?.[name]) return window.__editorAct[name](a, e);
  });
  document.addEventListener('input', (e) => {
    const el = e.target; const path = el.dataset?.model; if (!path) return;
    let val = el.type === 'checkbox' ? el.checked : el.type === 'range' || el.type === 'number' ? parseFloat(el.value) : el.value;
    setPath(path, val);
    if (el.tagName === 'INPUT' && el.type === 'text' || el.tagName === 'TEXTAREA') A.keystroke();
    commit('field', true);
    afterSettingChange(path, true);
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') { UI.closeModal(); UI.closeMenu(); } });
  // Dropping a file anywhere else must not navigate the window away from PAI.
  for (const ev of ['dragover', 'drop']) document.addEventListener(ev, (e) => { if (!e.target.closest?.('.chatbox')) e.preventDefault(); });
}
function afterSettingChange(path, silent = false) {
  if (path.startsWith('settings.music')) A.music.apply(prevMusic), prevMusic = { ...state.settings.music };
  if (path === 'settings.theme') applyTheme();
  if (path === 'settings.crtEffects') document.getElementById('scan').style.display = state.settings.crtEffects ? '' : 'none';
  if (path === 'settings.startWithWindows') P.setStartup(state.settings.startWithWindows);
  if (path === 'profile.preferredName' || path === 'profile.fullName' || path === 'settings.paiName') { renderSide(); }
  commit(path.split('.')[0], silent);
}
let prevMusic = null;

const GLOBAL = {
  go: (a) => go(a.dataset.v, { page: a.dataset.page }),
  closeModal: () => { UI.closeModal(); if (window.__editorAct) { window.__editorAct = null; commit('profile'); window.dispatchEvent(new Event('pai-editor-closed')); } },
  pickJob: (a) => { UI.closeModal(); window.__jobPick?.(a.dataset.id); },
  mute: () => { const m = state.settings.music; prevMusic = { ...m }; m.muted = !m.muted; A.music.apply(prevMusic); prevMusic = { ...m }; commit('settings'); },
  musicToggle: () => { if (state.settings.music.muted) { state.settings.music.muted = false; commit('settings'); } A.music.toggle(); },
  musicNext: () => A.music.next(),
  musicPrev: () => A.music.previous(),
  mini: () => setMini(!document.body.classList.contains('mini')),
  editChar: () => { if (state.antag.effect?.original) import('./events.js').then(E => E.clearAntag(true)); openEditor(); },
  antagResolve: () => import('./events.js').then(E => E.clearAntag()),
};

export function applyTheme() {
  document.documentElement.dataset.theme = state.settings.theme;
  document.documentElement.style.setProperty('--accent', X.accentColor());
}

// ---------------------------------------------------------------- fx: animations, popups, bubbles
function bindFx() {
  X.onFx((e) => {
    if (e.type === 'popup') {
      const p = document.createElement('div'); p.className = 'popup'; p.textContent = e.text; p.style.color = e.color || X.accentColor();
      document.getElementById('popups').appendChild(p); setTimeout(() => p.remove(), 1800);
    }
    if (e.type === 'anim') {
      const sel = e.target === 'unit' ? '[data-anim-unit]' : '[data-anim-char]';
      for (const el of document.querySelectorAll(sel)) {
        el.className = el.className.replace(/\banim-\w+/g, '').trim(); void el.offsetWidth; el.classList.add('anim-' + e.kind);
      }
      if (e.target === 'character' && (e.kind === 'spin' || e.kind === 'dance')) spinCharacters(e.kind === 'dance' ? 160 : 90);
    }
    if (e.type === 'bubble' && current === 'home') home.bubble?.(e.msg);
  });
}
async function spinCharacters(ms) {
  const els = [...document.querySelectorAll('[data-anim-char] img.charimg')]; if (!els.length) return;
  const c = state.profile.character; const urls = [];
  for (const d of [0, 1, 2, 3]) urls[d] = await C.render(c, state.profile.stationJob, d);
  const orig = els.map(e => e.src);
  for (const d of [2, 1, 3, 0, 2, 1, 3, 0]) { els.forEach(e => e.src = urls[d]); await sleep(ms); }
  els.forEach((e, i) => e.src = orig[i]);
}

// ---------------------------------------------------------------- overlays (preset connect, intellicard transfer)
function renderOverlay() {
  const o = document.getElementById('overlay');
  if (state.connecting) {
    const f = FORKS[state.connecting];
    o.style.display = 'flex';
    o.innerHTML = `<div style="width:380px">${UI.win('Space Station 14 Launcher', `<div style="padding:16px" class="col">
      <div class="b" style="font-size:17px">Connecting to ${esc(f.name)}…</div>
      ${['Resolving ' + f.name.toLowerCase().replace(/[^a-z0-9]/g, '') + '.ss14', `Downloading resources (${(40 + Math.random() * 80).toFixed(1)} MB)`, 'Loading prototypes', `Joining as ${esc(X.ownerTitle().split("'")[0] || 'Unknown')}`]
        .map((s, i) => `<div class="small conn-step" style="opacity:.35;transition:opacity .2s" data-i="${i}">☐ ${s}</div>`).join('')}
      <div style="height:8px;background:var(--le);border:1px solid var(--leb)"><div id="connbar" style="height:100%;width:0;background:var(--good);transition:width .5s"></div></div>
      <div class="small i dim">${esc(f.tag)}</div></div>`)}</div>`;
    let i = 0;
    const step = () => {
      const el = o.querySelector(`.conn-step[data-i="${i}"]`); if (!el) return;
      el.style.opacity = 1; el.textContent = '☑' + el.textContent.slice(1); A.play('keyboard' + (1 + i % 4), 0.3);
      o.querySelector('#connbar').style.width = ((i + 1) * 25) + '%'; i++; if (i < 4) setTimeout(step, 520);
    };
    setTimeout(step, 400);
  } else if (state.transferring) {
    o.style.display = 'flex';
    o.innerHTML = `<div style="width:340px">${UI.win('Intellicard transfer', `<div style="padding:16px" class="col">
      <div class="row-flex" style="justify-content:center;gap:20px">${UI.unit({ form: state.settings.form === 'stationAI' ? 'pai' : state.settings.form, mood: 'thinking', size: 70 })}<span style="color:var(--gold);font-size:22px">⇄</span>${UI.unit({ form: 'stationAI', mood: 'thinking', size: 70 })}</div>
      <div class="small" style="color:#5ED7AA">Transferring consciousness…</div>
      <div style="height:10px;background:var(--le);border:1px solid var(--leb)"><div style="height:100%;width:0;background:var(--good);animation:fill 1.7s linear forwards"></div></div></div>`)}</div><style>@keyframes fill{to{width:100%}}</style>`;
  } else { o.style.display = 'none'; o.innerHTML = ''; }
}

// ---------------------------------------------------------------- mini mode (desktop widget)
async function setMini(on) {
  document.body.classList.toggle('mini', on);
  await P.setMini(on); P.setTray(on);
  if (on) go('home'); else rerender();
}

// ---------------------------------------------------------------- start
async function start() {
  await P.init((ev, id) => {
    if (ev === 'close') { if (state.settings.trayOnClose && P.isDesktop()) P.hide(); else P.quit(); }
    if (ev === 'tray') { if (id === 'open') P.show(); if (id === 'mini') { P.show(); setMini(!document.body.classList.contains('mini')); } if (id === 'quit') P.quit(); }
  });
  await loadAll(); P.persistStorage();
  fitViewport();
  await Promise.all([C.loadCharacters(), A.loadAudio()]);
  if (!state.profile.character) { state.profile.character = C.starter(); commit('profile', true); }
  applyTheme(); import('./events.js').then(E => E.applyAntagLook());
  document.getElementById('scan').style.display = state.settings.crtEffects ? '' : 'none';
  bindGlobal(); bindFx();
  subscribe((what) => {
    if (what === 'overlay') return renderOverlay();
    if (what === 'mood') return;
    if (what === 'settings') { applyTheme(); renderSide(); }
    if (what === 'field') return;
    if (current === 'home' && what === 'chat') return home.updateChat?.();
    rerender();
  });
  A.music.onChange(() => { if (!document.hidden) { updateSideMusic(); VIEWS[current].musicChanged?.(); } });
  P.setTray(false);

  if (!P.isDesktop() && (navigator.maxTouchPoints > 0 || 'ontouchstart' in window)) await tapToStart();
  if (state.settings.bootSequence) await runBoot();
  if (!state.settings.onboarded) await runOnboarding();
  document.getElementById('app').style.display = '';
  { const app = document.getElementById('app'); app.classList.add('crt-on'); app.addEventListener('animationend', (e) => { if (e.animationName === 'crtOn') app.classList.remove('crt-on'); }); setTimeout(() => app.classList.remove('crt-on'), 1500); }
  renderSide(); go('home');
  prevMusic = { ...state.settings.music }; A.music.apply(null);
  setInterval(() => { X.tick(); VIEWS[current].live?.(); }, 1000);
  const loop = () => { UI.animateUnits(X.displayMood()); setTimeout(loop, 100); };
  loop();
}
/** Phones block sound until a real tap, so the first screen asks for one (like inserting the pAI). */
function tapToStart() {
  return new Promise((done) => {
    const el = document.createElement('div'); el.id = 'tapstart';
    el.innerHTML = `<div class="logo" style="width:72px;height:72px"></div><div class="b" style="font-size:22px;letter-spacing:3px;margin-top:18px">${esc(X.paiName())}</div>
      <div class="btn good" style="margin-top:26px;padding:14px 28px;font-size:17px">Tap to power on</div><div class="small dim" style="margin-top:14px">Turns on sound too</div>`;
    document.body.appendChild(el);
    el.addEventListener('click', () => { A.unlockAudio(); if (!state.settings.bootSequence) A.sfx('power_on'); el.style.opacity = '0'; setTimeout(() => { el.remove(); done(); }, 250); }, { once: true });
  });
}
/** Phones: size the app to the *visible* area so the on-screen keyboard never covers the message box. */
function fitViewport() {
  const vv = window.visualViewport; const root = document.documentElement;
  const upd = () => {
    const h = vv ? vv.height : innerHeight;
    root.style.setProperty('--vvh', h + 'px'); root.style.setProperty('--vvt', (vv ? vv.offsetTop : 0) + 'px');
    const kbd = innerHeight - h > 120 && /^(TEXTAREA|INPUT)$/.test(document.activeElement?.tagName || '');
    if (kbd !== document.body.classList.contains('kbd')) {
      document.body.classList.toggle('kbd', kbd);
      const log = document.getElementById('chatlog'); if (log) requestAnimationFrame(() => { log.scrollTop = log.scrollHeight; });
    }
  };
  upd(); vv?.addEventListener('resize', upd); vv?.addEventListener('scroll', upd); addEventListener('resize', upd);
  document.addEventListener('focusin', () => setTimeout(upd, 50)); document.addEventListener('focusout', () => setTimeout(upd, 120));
}
let sideMusicTimer = 0;
function updateSideMusic() {
  if (Date.now() - sideMusicTimer < 1000) return; sideMusicTimer = Date.now(); renderSide();
}
window.__pai = { state, go, X, A, C };
start();
