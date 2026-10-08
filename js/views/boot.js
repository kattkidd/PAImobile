// Power-on: a BIOS log types out (style per boot screen setting), then the unit powers on.
import { state, nextOccurrence } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as C from '../character.js';
import * as UI from '../ui.js';
import { esc, sleep } from '../util.js';
import { BOOT, accent, job, CHASSIS } from '../ss14.js';

export async function runBoot() {
  const s = state.settings; const b = BOOT[s.bootStyle] || BOOT.vanilla;
  const ok = '#2CDB2C';
  const lines = [[b.bios, '', 'var(--gold)'], ['CPU  positronic matrix', 'OK'], ['MEM  640K ought to be enough', 'OK'], [`Loading personality: ${X.paiName()}`, 'OK'],
    s.form === 'stationAI' ? [`Uploading lawset: ${X.activeLawset().name}`, 'OK'] : [`Chassis: ${s.form === 'terminal' ? CHASSIS[s.chassis].term : CHASSIS[s.chassis].label}`, 'OK'],
    state.profile.fullName ? [`Reading ID card: ${state.profile.fullName}`, 'OK'] : ['Reading ID card', 'NO ID', 'var(--gold)'],
    [`Crew manifest: ${C.species(state.profile.character.species).name.toLowerCase()}, ${job(state.profile.stationJob).name}`, 'OK'],
    [`Syncing calendar: ${state.reminders.filter(r => nextOccurrence(r)).length} reminders`, 'OK'],
    ...b.extras,
    ...(accent(s.accent) ? [[`Speech synthesiser: ${accent(s.accent).label} accent`, 'OK']] : []),
    ...(s.music.enabled && !s.music.muted ? [[`Lobby music: ${A.AUDIO.music.length} tracks`, 'OK']] : []),
    state.apiKey ? ['Neural uplink', 'ONLINE'] : ['Neural uplink', 'OFFLINE', '#FF6B6B']];
  const el = document.createElement('div'); el.id = 'boot';
  el.innerHTML = `<div class="row-flex" style="gap:14px;margin-bottom:24px"><div class="logo" style="width:48px;height:48px"></div><div><div class="b" style="font-size:24px;letter-spacing:3px">${esc(b.title)}</div><div class="small dim">${esc(b.sub)}</div></div></div>
    <div class="log" style="display:flex;flex-direction:column;gap:4px;max-width:640px"></div>
    <div style="height:6px;background:#111;margin-top:18px;max-width:640px"><div id="bootbar" style="height:100%;width:0;background:var(--good);transition:width .1s"></div></div>
    <div id="bootunit" style="margin-top:30px;display:flex;justify-content:center;max-width:640px"></div>
    <div class="tiny dim" style="position:absolute;bottom:20px;left:60px">Click to skip</div>`;
  document.body.appendChild(el);
  let skip = false; el.addEventListener('click', () => skip = true);
  A.sfx('power_on');
  const log = el.querySelector('.log');
  for (let i = 0; i < lines.length; i++) {
    const [t, r, col] = lines[i];
    log.insertAdjacentHTML('beforeend', `<div class="row-flex" style="color:${i === 0 ? 'var(--gold)' : 'var(--txt)'}"><span class="grow">${esc(t)}</span><span class="b" style="color:${col || ok}">${r ? '[ ' + esc(r) + ' ]' : ''}</span></div>`);
    el.querySelector('#bootbar').style.width = ((i + 1) / lines.length * 100) + '%';
    if (i > 0) A.play('keyboard' + (1 + i % 4), 0.25);
    if (!skip) await sleep(i === 0 ? 350 : 140 + Math.random() * 120);
  }
  el.querySelector('#bootunit').innerHTML = `<div class="crt-on">${UI.unit({ size: 120, mood: 'happy' })}</div>`;
  A.sfx('boot_beep');
  if (!skip) await sleep(900);
  el.style.transition = 'opacity .5s'; el.style.opacity = 0; await sleep(500); el.remove();
}
