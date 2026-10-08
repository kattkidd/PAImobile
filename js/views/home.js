// Home: the unit, clock, your character, chips and the SS14-style chat box.
import { state, nextReminder, userName, timerRemaining } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as C from '../character.js';
import * as UI from '../ui.js';
import * as P from '../platform.js';
import * as PA from '../paper.js';
import * as CP from '../chatplus.js';
import { esc, icon, fmtTime, fmtDate, relative, fmtDuration, pick } from '../util.js';
import { styled, verb, userVerb, job, deptText, NOT_INSTALLED } from '../ss14.js';

const SUGGEST = ["What's the weather today?", 'Set a 10 minute timer', "What's on my calendar?", 'Remind me tomorrow at 9am to drink water', "What's in the news?"];

function pendingChips() {
  return CP.pending.map((f, i) => `<span class="filechip">${icon(f.kind === 'image' ? 'id' : 'clip', 11)} ${esc(f.name.length > 22 ? f.name.slice(0, 20) + '…' : f.name)} <b data-act="unattach" data-i="${i}" style="cursor:pointer;color:#FF6B6B">×</b></span>`).join('');
}
function refreshChips() { const el = document.getElementById('pendingfiles'); if (el) el.innerHTML = pendingChips(); }
async function attachFiles(files) {
  for (const f of files) { const err = await CP.addFile(f); if (err) X.popup(err, '#FF6B6B'); }
  refreshChips(); document.getElementById('chatinput')?.focus();
}
function deviceBar() {
  const todo = X.deviceTodo(); if (!todo.length) return '';
  const cal = todo.filter(x => x.kind === 'cal'), clock = todo.filter(x => x.kind === 'clock');
  return `<div class="devbar">${cal.length ? `<div class="row-flex"><span class="grow small">${icon('calendar', 13)} ${cal.length === 1 ? esc(cal[0].label) : cal.length + ' reminders'} not in your Calendar yet</span>${UI.btn('Send to Calendar', 'devCal', { cls: 's good' })}${UI.btn('×', 'devSkip', { cls: 's ghost', data: 'data-k="cal"' })}</div>` : ''}
    ${clock.map(t => `<div class="row-flex"><span class="grow small">${icon('timer', 13)} ${esc(t.label)} timer</span>${UI.btn('Start in Clock', 'devClock', { cls: 's good', data: `data-id="${t.id}"` })}</div>`).join('')}</div>`;
}
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
    case 'user': return `<div class="line">${head()}<div><b style="color:${deptCol}">${name}</b> ${userVerb(m.text)}, “${styled(m.text, state)}”${(m.files || []).length ? `<div class="src">${m.files.map(f => `<span class="filechip">${icon('clip', 11)} ${esc(f)}</span>`).join('')}</div>` : ''}</div></div>`;
    case 'announce': return `<div class="announce ${m.kind || ''}"><div class="ah">${esc(m.title || 'Station Announcement')}</div><div>${styled(m.text, state)}</div>${m.sign ? `<div class="asig">${esc(m.sign)}</div>` : ''}${(m.buttons || []).map(b => `<button class="btn s ${b.cls || ''}" data-act="${b.act}" ${b.data || ''}>${esc(b.label)}</button>`).join(' ')}</div>`;
    case 'userEmote': return `<div class="line">${head()}<div class="i"><b style="color:${deptCol}">${name}</b> ${esc(m.text)}</div></div>`;
    case 'emote': return `<div class="line"><span class="av" style="opacity:.85">${avatar()}</span><div class="i">${esc(X.paiName())} ${esc(m.text)}</div></div>`;
    case 'system': return `<div class="line sys">⚠ ${esc(m.text)}</div>`;
    case 'pai': {
      const src = (m.sources || []).slice(0, 5).map(s => `<a href="${esc(s.url)}" data-ext="1">${icon('link', 11)} ${esc(s.title)}</a>`).join('');
      return `<div class="line" data-mid="${m.id}"><span class="av">${avatar()}</span><div class="grow"><div><b style="color:var(--accent)">${esc(X.paiName())}</b> ${verb(m.text, m.id)}, “<span class="msgtext">${styled(m.text, state)}</span>”</div>
        ${src ? `<div class="src">${src}</div>` : ''}${(m.papers || []).map(id => { const p = state.papers.find(x => x.id === id); return p ? `<div class="papertile inchat" data-act="paperOpen" data-id="${p.id}">${PA.paperCard(p, { big: false })}</div>` : ''; }).join('')}<span class="dim" style="cursor:pointer;font-size:11px;margin-right:10px" data-act="readAloud" data-id="${m.id}" title="Read aloud">${icon('speaker', 12)}</span><span class="dim" style="cursor:pointer;font-size:11px" data-act="copyMsg" data-id="${m.id}" title="Copy">${icon('paste', 12)}</span></div></div>`;
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
  if (state.focus.on) out.push(`<button class="btn s ghost chip" style="color:${state.focus.phase === 'work' ? 'var(--accent)' : '#2CDB2C'}" data-act="go" data-v="timers">${icon('bolt', 12)} ${state.focus.phase === 'work' ? 'Focus' : 'Break'} <span data-live-focus>${fmtDuration(Math.max(0, Math.round((state.focus.end - Date.now()) / 1000)))}</span></button>`);
  if (state.antag.emagged) out.push(`<button class="btn s ghost chip" style="color:#f33" data-act="laws">${icon('skull', 12)} EMAGGED</button>`);
  out.push(`<button class="btn s ghost chip" data-act="briefMe">${icon('sun', 12)} Briefing</button>`);
  const run = state.timers.filter(t => t.end && !t.finished);
  if (run.length) out.push(`<button class="btn s ghost chip" data-act="go" data-v="timers">${icon('timer', 12)} <span data-live-timer="${run[0].id}">${fmtDuration(timerRemaining(run[0]))}</span>${run.length > 1 ? ' +' + (run.length - 1) : ''}</button>`);
  if (!state.profile.fullName && !state.profile.preferredName) out.push(`<button class="btn s ghost chip" style="color:var(--gold)" data-act="go" data-v="id">${icon('id', 12)} Register your ID</button>`);
  if (state.settings.music.enabled && A.music.current) out.push(`<button class="btn s ghost chip" data-act="mute" id="npchip">${UI.eq(A.music.playing && !state.settings.music.muted)} ${state.settings.music.muted ? 'Music muted' : esc(A.music.current.title + ' · ' + A.music.current.artist)}</button>`);
  return out.join('');
}

export default {
  render() {
    const s = state.settings; const mood = X.displayMood();
    const right = `${P.isDesktop() ? UI.btn(icon('mini', 13), 'mini', { cls: 's ghost', title: 'Mini mode' }) : ''}${state.messages.length ? `<button class="btn s" data-act="newChat" title="New chat">${icon('edit', 13)}</button>` : ''}${UI.muteBtn()}`;
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
      <div class="chatbox">${deviceBar()}
        <div class="chatlog" id="chatlog">${chatHTML()}</div>
        <div class="chattools"><label class="btn s ghost" title="Attach a picture, PDF or text file">${icon('clip', 13)} Attach<input type="file" id="attachfile" multiple accept="image/*,application/pdf,text/*,.md,.csv,.json,.txt,.log,.py,.js,.gd,.cs" style="display:none"></label>
          ${UI.btn(icon('paste', 13) + ' Clipboard', 'clipMenu', { cls: 's ghost', title: 'Do something with what you copied' })}
          ${UI.btn(icon('mic', 13) + ' Talk', 'talk', { cls: 's ghost', title: 'Speak to ' + X.paiName() })}<span class="grow"></span><span id="pendingfiles">${pendingChips()}</span></div>
        <div class="inputbar">
          <span class="chan" data-act="emoteMenu" title="Emotes">${X.isAI() ? 'AI' : s.form === 'terminal' ? '&gt;_' : 'Say'} ▾</span>
          <textarea class="field" id="chatinput" rows="1" placeholder="Message ${esc(X.paiName())}… (Enter to send, *emote)" style="resize:none;min-height:38px;max-height:140px"></textarea>
          ${UI.btn(icon('send', 15), 'send', { cls: 'good', title: 'Send' })}
        </div>
      </div></div></div>`;
  },
  mounted(root) {
    const log = root.querySelector('#chatlog'); log.scrollTop = log.scrollHeight;
    root.querySelector('#attachfile')?.addEventListener('change', (e) => { const fs = [...e.target.files]; e.target.value = ''; attachFiles(fs); });
    const box = root.querySelector('.chatbox');
    box?.addEventListener('dragover', (e) => { e.preventDefault(); box.classList.add('dropping'); });
    box?.addEventListener('dragleave', (e) => { if (!box.contains(e.relatedTarget)) box.classList.remove('dropping'); });
    box?.addEventListener('drop', (e) => { e.preventDefault(); box.classList.remove('dropping'); attachFiles([...(e.dataTransfer?.files || [])]); });
    root.querySelector('#chatinput')?.addEventListener('paste', (e) => { const fs = [...(e.clipboardData?.files || [])]; if (fs.length) { e.preventDefault(); attachFiles(fs); } });
    const inp = root.querySelector('#chatinput');
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); this.act.send(); } });
    inp.addEventListener('input', () => { A.keystroke(); inp.style.height = 'auto'; inp.style.height = Math.min(140, inp.scrollHeight) + 'px'; });
    if (!(navigator.maxTouchPoints > 0)) inp.focus();
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
    const fl = document.querySelector('[data-live-focus]'); if (fl && state.focus.on) fl.textContent = fmtDuration(Math.max(0, Math.round((state.focus.end - Date.now()) / 1000)));
    for (const el of document.querySelectorAll('[data-live-timer]')) { const t = state.timers.find(x => x.id === el.dataset.liveTimer); if (t) el.textContent = fmtDuration(timerRemaining(t)); }
  },
  bubble(m) {
    const b = document.getElementById('bubble'); if (!b) return;
    const text = m.text.replace(/[*`#]/g, '');
    b.innerHTML = `<div class="bubble" style="left:110px;top:-6px">${esc(text.length > 160 ? text.slice(0, 157) + '…' : text)}</div>`;
    clearTimeout(this._bt); this._bt = setTimeout(() => { b.innerHTML = ''; }, Math.min(9000, 3000 + text.length * 40));
  },
  act: {
    devCal() { X.sendToCalendar(X.deviceTodo().filter(x => x.kind === 'cal').map(x => x.id)); },
    devClock(a) { X.sendTimerToClock(a.dataset.id); },
    devSkip() { for (const x of X.deviceTodo()) { const r = state.reminders.find(y => y.id === x.id); if (r) r.calSig = `${r.title}|${r.date}|${r.repeat}|${r.notes}`; } import('../store.js').then(m => m.commit('reminders')); },
    send() {
      const inp = document.getElementById('chatinput'); const t = inp.value; if (!t.trim() && !CP.pending.length) return;
      inp.value = ''; inp.style.height = 'auto'; X.send(t, { files: CP.takePending() }); refreshChips();
    },
    briefMe() { X.runBriefing(true); },
    unattach(a) { CP.pending.splice(+a.dataset.i, 1); A.sfx('pop'); refreshChips(); },
    copyMsg(a) { const m = state.messages.find(x => x.id === a.dataset.id); if (m) CP.copyText(m.text).then(ok => X.popup(ok ? 'Copied' : 'Copy failed', ok ? '#2CDB2C' : '#FF6B6B')); },
    async clipMenu(a) {
      const go = async (instr) => {
        let text = ''; try { text = await CP.readClipboard(); } catch { }
        if (!text?.trim()) { X.popup('Clipboard is empty (or PAI was not allowed to read it)', '#FF6B6B'); return; }
        if (!instr) { const inp = document.getElementById('chatinput'); inp.value += text; inp.focus(); return; }
        CP.addText('clipboard', text); X.send(instr, { files: CP.takePending().map(f => ({ ...f, name: 'clipboard' })) }); refreshChips();
      };
      UI.menu(a, [{ header: 'Do this with what I copied' }, ...CP.CLIP_ACTIONS.map(([l, instr]) => ({ label: l, run: () => go(instr) })), { label: 'Just paste it into the box', run: () => go(null) }]);
    },
    talk(a) {
      if (CP.listening) { CP.stopListening(); return; }
      if (!CP.canListen()) {
        UI.modal('Talk to ' + X.paiName(), `<div style="padding:14px;line-height:1.6">${P.isDesktop() ? 'Windows has voice typing built in: click in the message box and press <b>Windows + H</b>, then talk. Turn on <b>Settings → Sound → Read replies aloud</b> so ' + esc(X.paiName()) + ' talks back.' : 'Voice input isn’t available in this browser. Tap the message box and use the <b>microphone on your keyboard</b> instead.'}</div>`);
        return;
      }
      const inp = document.getElementById('chatinput'); a.classList.add('good'); a.innerHTML = `${icon('mic', 13)} Listening…`;
      CP.listen({
        onText: (t) => { inp.value = t; },
        onEnd: (final) => { a.classList.remove('good'); a.innerHTML = `${icon('mic', 13)} Talk`; if (final) { inp.value = ''; X.send(final, { voice: true, files: CP.takePending() }); refreshChips(); } },
        onError: (err) => { a.classList.remove('good'); a.innerHTML = `${icon('mic', 13)} Talk`; if (err !== 'aborted' && err !== 'no-speech') X.popup(err === 'not-allowed' ? 'Microphone permission was denied' : 'Voice input failed: ' + err, '#FF6B6B'); },
      });
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
