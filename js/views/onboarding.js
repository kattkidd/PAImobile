// First-run setup as a series of SS14 windows.
import { state, commit } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as C from '../character.js';
import * as UI from '../ui.js';
import * as P from '../platform.js';
import { esc, sleep, icon } from '../util.js';
import { SEARCHING, AI_NAMES, job, UNIT_FORMS } from '../ss14.js';
import { presetCards, unitCustomizer, lawsetPicker } from './settings.js';
import { idCard, characterCard, jobPicker } from './id.js';
import { openEditor } from './editor.js';

const STEPS = ['welcome', 'style', 'unit', 'search', 'id', 'character', 'laws', 'alerts', 'mind', 'done'];

export function runOnboarding() {
  return new Promise((resolve) => {
    let step = 0, found = false;
    const el = document.createElement('div');
    el.style.cssText = 'position:fixed;inset:0;z-index:60;background:var(--space);display:flex;flex-direction:column;align-items:center';
    document.body.appendChild(el);
    const steps = () => STEPS.filter(s => s !== 'laws' || state.settings.form === 'stationAI');
    const title = (t, sub) => `<div class="col" style="gap:6px"><div class="b" style="font-size:28px">${t}</div><div class="dim">${sub}</div>${UI.nh('')}</div>`;

    function page(s) {
      switch (s) {
        case 'welcome': return `<div class="col" style="align-items:center;text-align:center;gap:18px;padding-top:6vh"><div class="logo" style="width:72px;height:72px"></div>
          <div class="b" style="font-size:32px;letter-spacing:4px">NANOTRASEN</div><div class="dim">Personal assistance division · desktop terminal</div>
          <div class="row-flex" style="gap:30px;align-items:flex-end">${UI.unit({ form: 'pai', mood: 'happy', size: 90 })}${UI.unit({ form: 'stationAI', size: 90 })}${UI.unit({ form: 'terminal', size: 90 })}</div>
          <div style="max-width:480px">Welcome aboard, crew member. Let's get your silicon assistant installed and registered to your ID.</div></div>`;
        case 'style': return title('Pick a style', 'Each server is a Space Station 14 fork. Applying one sets its look, voice, sounds and personality, but every fork’s species, jobs, laws, accents and music are always available. Mix and match any time in Settings.') + `<div>${presetCards()}</div>`;
        case 'unit': return title('Choose your unit', 'You can change this any time in Settings.') + `<div class="row-flex" style="gap:10px;align-items:stretch">${Object.entries(UNIT_FORMS).map(([id, f]) => `<div data-ob="form" data-f="${id}" class="cham" style="flex:1;cursor:pointer;padding:14px;text-align:center;background:${state.settings.form === id ? 'color-mix(in srgb, var(--good) 40%, transparent)' : 'var(--pd)'};border:2px solid ${state.settings.form === id ? 'var(--goodl)' : 'var(--btn)'}">
          <div data-anim-unit style="display:flex;justify-content:center">${UI.unit({ form: id, mood: state.settings.form === id ? 'happy' : 'neutral', size: 80 })}</div><div class="b" style="margin-top:6px">${f.label}</div><div class="small dim">${f.blurb}</div></div>`).join('')}</div>` + unitCustomizer();
        case 'search': return `<div class="col" style="align-items:center;padding-top:10vh;gap:20px"><div data-unit="1">${UI.unit({ size: 170, mood: found ? 'happy' : 'thinking', live: true })}</div>
          <div class="b" style="color:${found ? '#2CDB2C' : 'var(--dim)'};font-size:16px">${found ? { pai: 'A pAI is installed.', stationAI: 'Station AI core online.', terminal: '> TERMINAL ONLINE.' }[state.settings.form] : { pai: SEARCHING, stationAI: 'Locating an AI core…', terminal: '> SCANNING FOR TERMINALS…' }[state.settings.form]}</div></div>`;
        case 'id': return title('Register your ID', `${esc(X.paiName())} uses this to know who you are.`) + idCard() + UI.section('Identity', `${UI.field('Full name', 'profile.fullName', state.profile.fullName, 'Alex Morgan')}${UI.field('Call me', 'profile.preferredName', state.profile.preferredName, 'Alex', { alt: true })}${UI.field('Pronouns', 'profile.pronouns', state.profile.pronouns, 'they/them')}
          <div class="srow click alt" data-ob="jobs"><span class="lab">Station job</span>${UI.jobIcon(job(state.profile.stationJob), 18)}<span class="grow">${esc(job(state.profile.stationJob).name)}</span><span class="dim">›</span></div>`);
        case 'character': return title('Create your character', `Your SS14 crew member appears on your ID card, in chat and next to your unit, and reacts to emotes like *flip and *scream. ${C.DB.species.length} species from SS14, Goob Station, Starlight and Nuclear 14.`) + characterCard();
        case 'laws': return title('Upload a lawset', 'Station AIs follow laws. Pick the board to install.') + `<div class="col" style="gap:0">${lawsetPicker()}</div>`;
        case 'alerts': return title('Station alerts', 'Reminders and timers pop up as Windows notifications while PAI is running (it keeps running in the tray when you close the window).') +
          UI.section('Desktop', `${UI.toggle('Keep running in the tray when I close the window', 'settings.trayOnClose', state.settings.trayOnClose)}${UI.toggle('Start PAI when Windows starts', 'settings.startWithWindows', state.settings.startWithWindows)}<div class="srow">${UI.btn(icon('bell', 14) + ' Send a test notification', '', { cls: 'good', data: 'data-ob="notify"' })}</div>`);
        case 'mind': return title('Install a mind', `Optional. Without one, ${esc(X.paiName())} runs on backup circuits: clock, calendar and timers only.`) +
          UI.section('Claude API key', `<div class="srow"><input class="field" type="password" id="ob_key" placeholder="sk-ant-…">${UI.btn(state.apiKey ? 'Installed ✓' : 'Install', '', { cls: state.apiKey ? 'good' : '', data: 'data-ob="key"' })}</div>`,
            { footer: 'Get one at console.anthropic.com → API Keys and add a few dollars of credit under Billing. A Claude.ai subscription does not include API access. PAI uses the cheapest model with short replies, so a few dollars lasts a very long time. The key stays on this computer.' });
        case 'done': return `<div class="col" style="align-items:center;padding-top:8vh;gap:18px;text-align:center"><div data-anim-unit>${UI.unit({ size: 180, mood: 'happy' })}</div>
          <div class="b" style="font-size:28px;color:var(--accent)">${esc(X.paiName())} online</div><div>${esc(X.paiName())} states, “${state.profile.preferredName || state.profile.fullName ? `Hello, ${esc(state.profile.preferredName || state.profile.fullName.split(' ')[0])}. ` : ''}Ready to assist.”</div></div>`;
      }
    }
    function draw(dirFwd = true) {
      const list = steps(); const cur = list[step];
      el.innerHTML = `<div style="width:min(860px,94vw);display:flex;gap:5px;padding:14px 0 6px">${list.map((s2, i) => `<div class="cham" style="flex:1;height:6px;background:${i <= step ? 'var(--good)' : 'var(--btn)'};transition:background .3s"></div>`).join('')}</div>
        <div style="flex:1;overflow-y:auto;width:min(860px,94vw)" id="obpage"><div class="col screen ${dirFwd ? '' : 'back'}" style="padding:12px 0 30px">${page(cur)}</div></div>
        <div class="row-flex" style="width:min(860px,94vw);padding:12px 0 18px">${step > 0 && cur !== 'done' ? UI.btn('Back', '', { data: 'data-ob="back"' }) : ''}<span class="grow"></span>
          ${cur === 'mind' && !state.apiKey ? UI.btn('Skip', '', { cls: 'ghost', data: 'data-ob="next"' }) : ''}
          ${UI.btn(cur === 'welcome' ? 'Begin' : cur === 'done' ? 'Start shift' : 'Next', '', { cls: 'good', data: 'data-ob="next"', disabled: cur === 'search' && !found })}</div>`;
      if (cur === 'search' && !found) setTimeout(() => { found = true; A.unitSpeech('Found!'); draw(); }, 1800);
      if (cur === 'id') A.sfx('id_insert');
      if (cur === 'done') A.unitSpeech('Ready.');
    }
    function go(d) { const list = steps(); step = Math.max(0, Math.min(list.length - 1, step + d)); draw(d > 0); }
    el.addEventListener('click', (e) => {
      const t = e.target.closest('[data-ob]'); if (!t || t.disabled) return; A.sfx('click');
      const k = t.dataset.ob;
      if (k === 'next') { if (steps()[step] === 'done') { state.settings.onboarded = true; commit('settings', true); A.sfx('welcome'); el.style.transition = 'opacity .5s'; el.style.opacity = 0; setTimeout(() => { el.remove(); resolve(); }, 500); return; } go(1); }
      if (k === 'back') { A.sfx('hover'); go(-1); }
      if (k === 'form') {
        const f = t.dataset.f; state.settings.form = f;
        if (f === 'stationAI' && state.settings.paiName === 'PAI') state.settings.paiName = AI_NAMES[Math.floor(Math.random() * AI_NAMES.length)];
        else if (f !== 'stationAI' && AI_NAMES.includes(state.settings.paiName)) state.settings.paiName = 'PAI';
        commit('settings', true); A.unitSpeech('Hello!', f); draw(); setTimeout(() => X.animate('unit', 'jump'), 30);
      }
      if (k === 'jobs') jobPicker((id) => { state.profile.stationJob = id; A.sfx('id_swipe'); commit('profile', true); draw(); });
      if (k === 'notify') P.notify(`${X.paiName()} · Reminder`, 'This is what reminders look like. Beep!');
      if (k === 'key') { const v = el.querySelector('#ob_key').value.trim(); if (v) { X.installKey(v); draw(); } }
    });
    // Settings-page buttons reused inside onboarding (presets, chassis, laws, character)
    const off = (e) => {
      const a = e.target.closest('[data-act]'); if (!a || !el.contains(a)) return;
      setTimeout(() => draw(), a.dataset.act === 'preset' ? 2600 : 30);
    };
    el.addEventListener('click', off);
    const unsub = setInterval(() => { if (!document.body.contains(el)) clearInterval(unsub); else if (!document.getElementById('modal').classList.contains('show') && el._needs) { el._needs = false; draw(); } }, 300);
    window.addEventListener('pai-editor-closed', () => { el._needs = true; });
    draw();
  });
}
