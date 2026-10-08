// Home: the unit, clock, your character, chips and the SS14-style chat box.
import { state, nextReminder, userName, timerRemaining } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as C from '../character.js';
import * as UI from '../ui.js';
import { esc, icon, fmtTime, fmtDate, relative, fmtDuration, pick } from '../util.js';
import { styled, verb, userVerb, job, deptText, NOT_INSTALLED } from '../ss14.js';

const SUGGEST = ["What's the weather today?", 'Set a 10 minute timer', "What's on my calendar?", 'Remind me tomorrow at 9am to drink water', "What's in the news?"];

function greeting() {
  const h = new Date().getHours(); const g = h >= 5 && h < 12 ? 'Good morning' : h < 17 && h >= 12 ? 'Good afternoon' : h >= 17 && h < 22 ? 'Good evening' : 'Late shift';
  const n = userName();
  if (X.isAI()) return n ? `${g}, crew member ${n}.` : 'Crew detected.';
  return n ? `${g}, ${n}.` : g + '.';
}

function avatar() {
  const s = state.settings;
  if (s.form === 'stationAI') return `<img class="px" src="img/ai_holo_${s.hologram}.png" style="width:26px;height:30px;object-fit:contain;filter:drop-shadow(0 0 4px rgba(94,215,170,.6))">`;
  return UI.unit({ size: 28 });
}
function head() {
  const j = job(state.profile.stationJob);
  return `<span class="head" style="--dept:${deptText(j.department)}">${C.img(state.profile.character, state.profile.stationJob, 0)}</span>`;
}
function line(m) {
  const name = esc(userName() || 'You');
  const deptCol = deptText(job(state.profile.stationJob).department);
  switch (m.role) {
    case 'user': return `<div class="line">${head()}<div><b style="color:${deptCol}">${name}</b> ${userVerb(m.text)}, “${styled(m.text, state)}”</div></div>`;
    case 'userEmote': return `<div class="line">${head()}<div class="i"><b style="color:${deptCol}">${name}</b> ${esc(m.text)}</div></div>`;
    case 'emote': return `<div class="line"><span class="av" style="opacity:.85">${avatar()}</span><div class="i">${esc(X.paiName())} ${esc(m.text)}</div></div>`;
    case 'system': return `<div class="line sys">⚠ ${esc(m.text)}</div>`;
    case 'pai': {
      const src = (m.sources || []).slice(0, 5).map(s => `<a href="${esc(s.url)}" data-ext="1">${icon('link', 11)} ${esc(s.title)}</a>`).join('');
      return `<div class="line" data-mid="${m.id}"><span class="av">${avatar()}</span><div class="grow"><div><b style="color:var(--accent)">${esc(X.paiName())}</b> ${verb(m.text, m.id)}, “<span class="msgtext">${styled(m.text, state)}</span>”</div>
        ${src ? `<div class="src">${src}</div>` : ''}<span class="dim" style="cursor:pointer;font-size:11px" data-act="readAloud" data-id="${m.id}">${icon('speaker', 12)}</span></div></div>`;
    }
  }
  return '';
}
function emptyState() {
  const boot = state.apiKey ? `${X.paiName()} states, “Online. How can I help${userName() ? ', ' + userName() : ''}?”` : `${NOT_INSTALLED} ${X.paiName()} is running on backup circuits.`;
  return `<div class="col" style="gap:10px"><div style="color:var(--accent)" class="typewrite" data-text="${esc(boot)}"></div>
    ${state.apiKey ? '' : '<div class="small dim">Time, timers and the calendar still work. Install a mind in Settings → Mind to unlock chat and web search.</div>'}
    ${UI.nh('Suggested commands')}
    ${SUGGEST.map(s => `<button class="btn s ghost" style="justify-content:flex-start" data-act="suggest" data-text="${esc(s)}"><span style="color:var(--gold)">&gt;</span> ${esc(s)}</button>`).join('')}</div>`;
}
function chatHTML() {
  return (state.messages.length ? state.messages.map(line).join('') : emptyState())
    + (state.thinking ? `<div class="line" id="thinking"><span class="typing"><span></span><span></span><span></span></span><span class="small dim">${esc(X.paiName())} is ${X.isAI() ? 'computing' : 'processing'}…</span></div>` : '');
}
function chips() {
  const out = [];
  if (X.isAI()) out.push(`<button class="btn s ghost chip" style="color:#5ED7AA" data-act="laws">${icon('flag', 12)} Laws: ${esc(X.activeLawset().name)}</button>`);
  const nr = nextReminder(); if (nr) out.push(`<button class="btn s ghost chip" data-act="go" data-v="calendar">${icon('bell', 12)} ${esc(nr.r.title)} · ${relative(nr.date)}</button>`);
  const run = state.timers.filter(t => t.end && !t.finished);
  if (run.length) out.push(`<button class="btn s ghost chip" data-act="go" data-v="timers">${icon('timer', 12)} <span data-live-timer="${run[0].id}">${fmtDuration(timerRemaining(run[0]))}</span>${run.length > 1 ? ' +' + (run.length - 1) : ''}</button>`);
  if (!state.profile.fullName && !state.profile.preferredName) out.push(`<button class="btn s ghost chip" style="color:var(--gold)" data-act="go" data-v="id">${icon('id', 12)} Register your ID</button>`);
  if (state.settings.music.enabled && A.music.current) out.push(`<button class="btn s ghost chip" data-act="mute" id="npchip">${UI.eq(A.music.playing && !state.settings.music.muted)} ${state.settings.music.muted ? 'Music muted' : esc(A.music.current.title + ' · ' + A.music.current.artist)}</button>`);
  return out.join('');
}

export default {
  render() {
    const s = state.settings; const mood = X.displayMood();
    const right = `${UI.btn(icon('mini', 13), 'mini', { cls: 's ghost', title: 'Mini mode' })}${state.messages.length ? `<button class="btn s" data-act="newChat" title="New chat">${icon('edit', 13)}</button>` : ''}${UI.muteBtn()}`;
    return `<div class="content pad0"><div class="home-grid">
      <div class="col" style="min-height:0">
        ${UI.win(X.ownerTitle(), `<div style="padding:14px;position:relative" id="statuswin">
          <div class="row-flex" style="gap:16px;align-items:center">
            <div data-act="examine" style="cursor:pointer" data-anim-unit>${UI.unit({ size: 120, mood, live: true, cls: '' })}</div>
            <div class="grow"><div class="clock" id="clock">${fmtTime(new Date())}</div><div class="small dim" id="date">${fmtDate(new Date())}</div><div class="b" style="margin-top:6px">${esc(greeting())}</div></div>
          </div>
          <div class="row-flex" style="flex-wrap:wrap;gap:6px;margin-top:12px" id="chips">${chips()}</div>
          <div id="bubble"></div><div id="examine"></div>
        </div>`, { right })}
        ${UI.section('You', `<div class="row-flex" style="padding:10px;gap:14px">
          <div class="floor" style="width:96px;height:96px;cursor:pointer;flex:none" data-act="charEmote" title="Click to emote"><div data-anim-char style="width:100%;height:100%">${C.img(state.profile.character, state.profile.stationJob, 0)}</div></div>
          <div class="col grow" style="gap:6px"><div class="b">${esc(C.species(state.profile.character.species).name)} · ${esc(job(state.profile.stationJob).name)}</div>
            <div class="small dim">Type *flip, *scream, *laugh… in chat, or click your character.</div>
            <div class="row-flex">${UI.btn(icon('edit', 13) + ' Edit character', 'editChar', { cls: 's good' })}${UI.btn('*flip', 'quickEmote', { cls: 's ghost', data: 'data-e="flip"' })}${UI.btn('*spin', 'quickEmote', { cls: 's ghost', data: 'data-e="spin"' })}</div></div></div>`)}
      </div>
      <div class="chatbox">
        <div class="chatlog" id="chatlog">${chatHTML()}</div>
        <div class="inputbar">
          <span class="chan" data-act="emoteMenu" title="Emotes">${X.isAI() ? 'AI' : s.form === 'terminal' ? '&gt;_' : 'Say'} ▾</span>
          <textarea class="field" id="chatinput" rows="1" placeholder="Message ${esc(X.paiName())}… (Enter to send, *emote)" style="resize:none;min-height:38px;max-height:140px"></textarea>
          ${UI.btn(icon('send', 15), 'send', { cls: 'good', title: 'Send' })}
        </div>
      </div></div></div>`;
  },
  mounted(root) {
    const log = root.querySelector('#chatlog'); log.scrollTop = log.scrollHeight;
    const inp = root.querySelector('#chatinput');
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); this.act.send(); } });
    inp.addEventListener('input', () => { A.keystroke(); inp.style.height = 'auto'; inp.style.height = Math.min(140, inp.scrollHeight) + 'px'; });
    inp.focus();
    typewrite(root);
  },
  updateChat() {
    const log = document.getElementById('chatlog'); if (!log) return;
    const atBottom = log.scrollHeight - log.scrollTop - log.clientHeight < 80;
    log.innerHTML = chatHTML();
    const fresh = state.freshID && log.querySelector(`[data-mid="${state.freshID}"] .msgtext`);
    if (fresh) { typeOut(fresh); state.freshID = null; }
    if (atBottom || true) log.scrollTop = log.scrollHeight;
    const c = document.getElementById('chips'); if (c) c.innerHTML = chips();
    typewrite(document);
  },
  musicChanged() { const c = document.getElementById('npchip'); if (c) document.getElementById('chips').innerHTML = chips(); },
  live() {
    const now = new Date();
    const ck = document.getElementById('clock'); if (ck) { const t = fmtTime(now); if (ck.textContent !== t) ck.textContent = t; }
    for (const el of document.querySelectorAll('[data-live-timer]')) { const t = state.timers.find(x => x.id === el.dataset.liveTimer); if (t) el.textContent = fmtDuration(timerRemaining(t)); }
  },
  bubble(m) {
    const b = document.getElementById('bubble'); if (!b) return;
    const text = m.text.replace(/[*`#]/g, '');
    b.innerHTML = `<div class="bubble" style="left:110px;top:-6px">${esc(text.length > 160 ? text.slice(0, 157) + '…' : text)}</div>`;
    clearTimeout(this._bt); this._bt = setTimeout(() => { b.innerHTML = ''; }, Math.min(9000, 3000 + text.length * 40));
  },
  act: {
    send() {
      const inp = document.getElementById('chatinput'); const t = inp.value; if (!t.trim()) return;
      inp.value = ''; inp.style.height = 'auto'; X.send(t);
    },
    suggest(a) { X.send(a.dataset.text); },
    newChat() { A.sfx('print_rip'); X.clearChat(); },
    readAloud(a) { const m = state.messages.find(x => x.id === a.dataset.id); if (m) X.speakAloud(m.text); },
    laws() { A.sfx('attention'); lawsWindow(); },
    examine() {
      const s = state.settings; const l = [];
      if (s.form === 'stationAI') { l.push(userName() ? `This is the AI core. It serves ${userName()}.` : "This is the station's AI core."); l.push(`It is running the <b>${esc(X.activeLawset().name)}</b> lawset.`); }
      else { l.push(`This is ${esc(X.ownerTitle())}.`); l.push(state.apiKey ? 'A pAI is installed.' : NOT_INSTALLED); }
      const nr = nextReminder(); if (nr) l.push(`Its screen shows a reminder: ${esc(nr.r.title)}.`);
      const e = document.getElementById('examine');
      e.innerHTML = `<div class="bubble" style="left:14px;top:140px;max-width:320px;pointer-events:auto">${l.join('<br>')}</div>`;
      setTimeout(() => { e.innerHTML = ''; }, 6000);
    },
    charEmote() {
      const c = state.profile.character; const em = A.availableEmotes(c.species, c.sex);
      const fav = em.filter(e => ['Laugh', 'Whistle', 'Chirp', 'Purr', 'Weh', 'Meow', 'Squeak', 'Click', 'Chitter', 'Hiss'].includes(e.id));
      const e = pick(fav.length ? fav : em); X.userEmote(e ? e.id.toLowerCase() : 'flip');
    },
    quickEmote(a) { X.userEmote(a.dataset.e); },
    emoteMenu(a) {
      const c = state.profile.character;
      const items = [{ header: 'Emotes (or type *scream)' }, ...A.availableEmotes(c.species, c.sex).map(e => ({ label: e.name, run: () => X.userEmote(e.id.toLowerCase()) })),
        { header: 'Moves' }, ...['flip', 'spin', 'jump', 'dance', 'wave', 'nod'].map(m => ({ label: '*' + m, run: () => X.userEmote(m) }))];
      UI.menu(a, items);
    },
  },
};

function lawsWindow() {
  const l = X.activeLawset();
  UI.modal(`Laws — ${l.name}`, `<div style="padding:16px" class="col">
    <div class="row-flex">${UI.unit({ form: 'stationAI', size: 54 })}<div><div class="b" style="font-size:18px">${esc(X.paiName())}</div><div class="small" style="color:#5ED7AA">Obeys: ${esc(userName() || 'the crew')}</div></div></div>
    ${UI.nh('Active laws')}${l.laws.map((x, i) => `<div><b>Law ${i + 1}:</b> ${esc(x)}</div>`).join('')}
    <div class="small dim">Change the lawset in Settings → Customise.</div></div>`);
}

/** New AI replies type out like an SS14 console. */
function typeOut(el) {
  const html = el.innerHTML; const text = el.textContent; if (!text) return;
  let n = 0; const step = Math.max(1, Math.floor(text.length / 120));
  el.textContent = '';
  const t = setInterval(() => { n = Math.min(text.length, n + step); el.textContent = text.slice(0, n); if (n >= text.length) { clearInterval(t); el.innerHTML = html; } }, 14);
}
function typewrite(root) {
  for (const el of root.querySelectorAll('.typewrite:not([data-done])')) {
    el.dataset.done = 1; const text = el.dataset.text; let n = 0;
    const t = setInterval(() => { n++; el.textContent = text.slice(0, n); if (n >= text.length) clearInterval(t); }, 18);
  }
}
