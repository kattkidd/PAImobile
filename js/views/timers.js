// Timers (presets, custom, pause/resume) and a stopwatch with laps.
import { state, timerRemaining } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as UI from '../ui.js';
import { esc, icon, fmtDuration } from '../util.js';

const PRESETS = [[60, '1 min'], [180, '3 min'], [300, '5 min'], [600, '10 min'], [900, '15 min'], [1500, 'Pomodoro'], [1800, '30 min'], [3600, '1 hour']];
let mode = 'timers';
const sw = { start: null, acc: 0, laps: [] };
const swElapsed = () => sw.acc + (sw.start ? (Date.now() - sw.start) / 1000 : 0);
const fmtSW = (s) => { const m = Math.floor(s / 60), x = s % 60; return `${String(m).padStart(2, '0')}:${x.toFixed(2).padStart(5, '0')}`; };

function ring(t) {
  const p = t.duration ? 1 - timerRemaining(t) / t.duration : 0; const C = 2 * Math.PI * 26;
  return `<svg class="ring" viewBox="0 0 64 64"><circle cx="32" cy="32" r="26" stroke="var(--le)"/><circle data-ring="${t.id}" cx="32" cy="32" r="26" stroke="${t.finished ? 'var(--caution)' : 'var(--accent)'}" stroke-dasharray="${C}" stroke-dashoffset="${C * (1 - p)}" transform="rotate(-90 32 32)" style="transition:stroke-dashoffset 1s linear"/></svg>`;
}
function timerList() {
  if (!state.timers.length) return `<div class="srow dim">No timers yet. Pick a preset above, or ask ${esc(X.paiName())} (“15 minute pasta timer”).</div>`;
  return state.timers.map(t => `<div class="timer-card ${t.finished ? 'done-flash' : ''}">${ring(t)}
    <div class="grow"><div class="b">${esc(t.label)}</div><div class="bignum mono" data-tl="${t.id}" style="color:${t.finished ? '#FF6B6B' : 'var(--accent)'}">${t.finished ? 'DONE' : fmtDuration(timerRemaining(t))}</div></div>
    ${state.settings.clockTimers && X.onPhone() && t.end && !t.finished ? UI.btn(icon('timer', 13) + (t.inClock ? ' In Clock' : ' Clock'), 'clock', { cls: 's' + (t.inClock ? ' good' : ''), data: `data-id="${t.id}"`, title: 'Start this timer in the iPhone Clock app' }) : ''}
    ${t.finished ? UI.btn('Restart', 'restart', { cls: 's', data: `data-id="${t.id}"` }) : t.end ? UI.btn(icon('pause', 13) + ' Pause', 'pause', { cls: 's', data: `data-id="${t.id}"` }) : UI.btn(icon('play', 13) + ' Resume', 'resume', { cls: 's good', data: `data-id="${t.id}"` })}
    <button class="btn s caution" data-act="del" data-id="${t.id}">${icon('trash', 13)}</button></div>`).join('');
}

function focusPanel() {
  const f = state.focus, st = state.settings;
  if (!f.on) return UI.section('Focus mode', `<div class="srow"><span class="small dim grow">Pomodoro shifts: work, short break, repeat. Every 4th break is long. Station events pause while you focus.</span></div>
    <div class="srow alt"><span class="lab">Work</span><input class="field" type="number" min="1" max="180" value="${st.focusWork}" data-model="settings.focusWork" style="width:80px;flex:none"><span class="dim">min</span>
      <span class="lab" style="margin-left:10px">Break</span><input class="field" type="number" min="1" max="60" value="${st.focusBreak}" data-model="settings.focusBreak" style="width:70px;flex:none"><span class="dim">min</span></div>
    <div class="srow"><span class="lab">Long break</span><input class="field" type="number" min="1" max="90" value="${st.focusLong}" data-model="settings.focusLong" style="width:80px;flex:none"><span class="dim">min</span><span class="grow"></span>${UI.btn(icon('play', 13) + ' Start focus shift', 'focusStart', { cls: 'good' })}</div>`,
    { trailing: f.todayCount ? `${f.todayCount} done today` : '' });
  const left = Math.max(0, Math.round((f.end - Date.now()) / 1000)); const total = (f.phase === 'work' ? f.work : (f.cycle % 4 === 0 ? st.focusLong : f.brk)) * 60;
  const C = 2 * Math.PI * 26;
  return UI.section(f.phase === 'work' ? 'Focus shift' : 'Break room', `<div class="timer-card" style="border-color:${f.phase === 'work' ? 'var(--accent)' : '#2CDB2C'}">
    <svg class="ring" viewBox="0 0 64 64"><circle cx="32" cy="32" r="26" stroke="var(--le)"/><circle data-focusring cx="32" cy="32" r="26" stroke="${f.phase === 'work' ? 'var(--accent)' : '#2CDB2C'}" stroke-dasharray="${C}" stroke-dashoffset="${C * (left / total)}" transform="rotate(-90 32 32)" style="transition:stroke-dashoffset 1s linear"/></svg>
    <div class="grow"><div class="b">${f.phase === 'work' ? 'Working · session ' + (f.todayCount + 1) : 'On break'}</div><div class="bignum mono" data-focusleft style="color:${f.phase === 'work' ? 'var(--accent)' : '#2CDB2C'}">${fmtDuration(left)}</div></div>
    ${UI.btn(f.phase === 'work' ? 'Skip to break' : 'Skip break', 'focusSkip', { cls: 's' })}${UI.btn(icon('stop', 13) + ' Stop', 'focusStop', { cls: 's caution' })}</div>`,
    { trailing: `${f.todayCount} done today` });
}
export default {
  render() {
    const tabs = `${UI.btn('Timers', 'mode', { cls: 's ' + (mode === 'timers' ? 'sel' : ''), data: 'data-m="timers"' })}${UI.btn('Stopwatch', 'mode', { cls: 's ' + (mode === 'sw' ? 'sel' : ''), data: 'data-m="sw"' })}`;
    if (mode === 'sw') {
      return `${UI.header('Timers', 'Microwave-grade countdowns', tabs)}<div class="content"><div class="col" style="max-width:680px">
        ${UI.win('Stopwatch', `<div style="padding:24px;text-align:center"><div class="mono b" id="swtime" style="font-size:64px;color:var(--accent)">${fmtSW(swElapsed())}</div>
          <div class="row-flex" style="justify-content:center;margin-top:12px">${sw.start ? UI.btn('Lap', 'lap') + UI.btn(icon('stop', 13) + ' Stop', 'swStop', { cls: 'caution' }) : UI.btn(icon('play', 13) + (sw.acc ? ' Resume' : ' Start'), 'swStart', { cls: 'good' }) + (sw.acc ? UI.btn('Reset', 'swReset') : '')}</div></div>`)}
        ${sw.laps.length ? UI.section('Laps', sw.laps.map((l, i) => `<div class="srow ${i % 2 ? 'alt' : ''}"><span class="dim">Lap ${sw.laps.length - i}</span><span class="grow"></span><span class="mono">${fmtSW(l)}</span></div>`).join('')) : ''}
      </div></div>`;
    }
    return `${UI.header('Timers', 'Microwave-grade countdowns', tabs)}<div class="content"><div class="col" style="max-width:820px">
      ${focusPanel()}
      ${UI.section('Presets', `<div class="row-flex" style="flex-wrap:wrap;padding:10px">${PRESETS.map(([s, l]) => UI.btn(l, 'timerPreset', { data: `data-s="${s}" data-l="${l === 'Pomodoro' ? 'Pomodoro' : ''}"` })).join('')}</div>
        <div class="srow alt"><span class="lab">Custom</span><input class="field" id="t_label" placeholder="Label (optional)" style="flex:2"><input class="field" id="t_min" type="number" min="0" value="5" style="width:80px;flex:none"><span class="dim">min</span><input class="field" id="t_sec" type="number" min="0" max="59" value="0" style="width:70px;flex:none"><span class="dim">sec</span>${UI.btn('Start', 'custom', { cls: 'good' })}</div>`)}
      ${UI.section('Running', timerList(), { trailing: `${state.timers.filter(t => t.end && !t.finished).length} running` })}
    </div></div>`;
  },
  live() {
    const f = state.focus;
    if (f.on && f.end) { const el = document.querySelector('[data-focusleft]'); const left = Math.max(0, Math.round((f.end - Date.now()) / 1000)); if (el) el.textContent = fmtDuration(left);
      const total = (f.phase === 'work' ? f.work : (f.cycle % 4 === 0 ? state.settings.focusLong : f.brk)) * 60; const r = document.querySelector('[data-focusring]'); if (r) r.setAttribute('stroke-dashoffset', 2 * Math.PI * 26 * (left / total)); }
    for (const t of state.timers) {
      const el = document.querySelector(`[data-tl="${t.id}"]`); if (el && !t.finished) el.textContent = fmtDuration(timerRemaining(t));
      const r = document.querySelector(`[data-ring="${t.id}"]`); if (r && t.duration) r.setAttribute('stroke-dashoffset', 2 * Math.PI * 26 * (timerRemaining(t) / t.duration));
    }
  },
  act: {
    mode(a) { mode = a.dataset.m; re(); },
    focusStart() { X.startFocus(); },
    focusStop() { X.stopFocus(); },
    focusSkip() { state.focus.end = Date.now(); X.tick(); },
    timerPreset(a) { const t = X.startTimer(+a.dataset.s, a.dataset.l || ''); toClock(t); },
    custom() {
      const s = (parseInt(document.getElementById('t_min').value) || 0) * 60 + (parseInt(document.getElementById('t_sec').value) || 0);
      if (s <= 0) return A.sfx('deny'); toClock(X.startTimer(s, document.getElementById('t_label').value));
    },
    clock(a) { X.sendTimerToClock(a.dataset.id); },
    pause(a) { X.pauseTimer(a.dataset.id); }, resume(a) { X.resumeTimer(a.dataset.id); }, restart(a) { X.restartTimer(a.dataset.id); }, del(a) { X.deleteTimer(a.dataset.id); },
    swStart() { sw.start = Date.now(); A.sfx('timer_start'); re(); tickSW(); },
    swStop() { sw.acc = swElapsed(); sw.start = null; A.sfx('button'); re(); },
    swReset() { sw.acc = 0; sw.laps = []; re(); },
    lap() { sw.laps.unshift(swElapsed()); A.sfx('quickbeep'); re(); },
  },
};
function re() { import('../main.js').then(m => m.rerender()); }
function tickSW() {
  const el = document.getElementById('swtime'); if (el) el.textContent = fmtSW(swElapsed());
  if (sw.start) requestAnimationFrame(tickSW);
}

function toClock(t) { if (t && state.settings.clockTimers && X.onPhone()) X.sendTimerToClock(t.id); }
