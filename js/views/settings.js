// Settings: Customise (every fork's features), Sound & music, Mind (Claude API key), System.
import { state, commit, backupJSON, restoreBackup } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as UI from '../ui.js';
import * as AI from '../ai.js';
import * as P from '../platform.js';
import { esc, icon } from '../util.js';
import { FORKS, THEMES, PERSONALITIES, UNIT_FORMS, CHASSIS, CORES, HOLOGRAMS, ACCENTS, accent, applyAccent, LAWSET_GROUPS, CUSTOM_LAWSET, AI_NAMES, COLORS, BOOT } from '../ss14.js';

let page = 'customise';
let testResult = '';
const PAGES = [['customise', 'Customise'], ['audio', 'Sound & music'], ['mind', 'Mind'], ['system', 'System']];
const VOICES = { auto: ['Match unit', 'pAI → pAI voice, Station AI → borg, Terminal → barks'], pai: ['pAI voice', 'SS14 Voice/Talk/pai*.ogg'], borg: ['Borg voice', 'SS14 Voice/Talk/Silicon/borg*.ogg'],
  bark: ['Barks', 'Nuclear 14 bark system: one blip every few letters'], radio: ['AI radio blip', "Starlight's AI radio blip, then the borg voice"], silent: ['Silent', 'No talk sounds'] };
const PACKS = { ss14: ['Space Station 14', 'SS14 announcements and ID sounds'], starlight: ['Starlight', 'Starlight announce2, attention and ID card handling'], wasteland: ['Wasteland (Nuclear 14)', 'Nuclear 14 ring bark for reminders'] };
const s = () => state.settings;

export function presetCards() {
  return Object.entries(FORKS).map(([id, f]) => {
    const on = s().fork === id; const th = THEMES[f.theme];
    return `<div style="padding:12px;background:${on ? 'var(--rowsel)' : 'var(--pd)'};border:1px solid ${on ? 'color-mix(in srgb, var(--gold) 70%, transparent)' : 'rgba(255,255,255,.06)'};margin-bottom:8px">
      <div class="row-flex"><span style="width:8px;height:8px;border-radius:4px;background:${on ? '#2CDB2C' : 'var(--dis)'}"></span><span class="b" style="font-size:16px">${esc(f.name)}</span><span class="grow"></span><span class="small dim mono">${f.players} · ${f.ping} ms</span></div>
      <div class="small dim" style="margin:6px 0 8px">${esc(f.tag)}</div>
      <div class="row-flex">${th.sw.map(c => `<span style="width:16px;height:10px;background:${c};border:1px solid rgba(0,0,0,.4)"></span>`).join('')}<span class="tiny dis">${esc(f.repo)}</span><span class="grow"></span>
        ${on ? '<span class="tiny" style="color:#2CDB2C">Last applied</span>' : ''}${UI.btn(on ? 'Re-apply' : 'Apply', 'preset', { cls: 's good', data: `data-f="${id}"`, disabled: !!state.connecting })}</div></div>`;
  }).join('');
}
export function unitPicker() {
  return `<div class="row-flex" style="padding:10px;gap:8px">${Object.entries(UNIT_FORMS).map(([id, f]) =>
    `<button class="btn grow ${s().form === id ? 'sel' : ''}" data-act="form" data-f="${id}" style="flex-direction:column;padding:10px">${UI.unit({ form: id, size: 44 })}<span class="b small">${f.label}</span></button>`).join('')}</div>`;
}
export function unitCustomizer() {
  const st = s(); let h = '';
  if (st.form !== 'stationAI') {
    h += UI.section('Chassis', `<div class="tiles">${Object.entries(CHASSIS).map(([id, c]) => `<div class="tile ${st.chassis === id ? 'on' : ''}" data-act="chassis" data-c="${id}"><div style="height:58px;display:flex;justify-content:center">${UI.unit({ form: st.form, chassis: id, mood: st.chassis === id ? 'happy' : 'neutral', size: 58 })}</div><div class="nm">${st.form === 'terminal' ? c.term : c.label}</div></div>`).join('')}</div>`,
      { footer: st.form === 'terminal' ? CHASSIS[st.chassis].termFlavor : CHASSIS[st.chassis].flavor });
  } else {
    h += UI.section('Core display', `<div class="tiles">${Object.entries(CORES).map(([id, c]) => `<div class="tile ${st.core === id ? 'on' : ''}" data-act="core" data-c="${id}"><div style="height:58px;display:flex;justify-content:center">${UI.unit({ form: 'stationAI', core: id, size: 58 })}</div><div class="nm">${c.label}</div></div>`).join('')}</div>`);
    h += UI.section('Hologram', `<div class="tiles">${HOLOGRAMS.map(id => `<div class="tile ${st.hologram === id ? 'on' : ''}" data-act="holo" data-c="${id}"><img class="px" src="img/ai_holo_${id}.png" style="height:58px;width:58px;object-fit:contain"><div class="nm">${id[0].toUpperCase() + id.slice(1)}</div></div>`).join('')}</div>`,
      { footer: "Your AI's holopad avatar, shown next to its messages." });
  }
  h += UI.section('Designation', `<div class="srow"><input class="field" data-model="settings.paiName" value="${esc(st.paiName)}" placeholder="Name">${st.form === 'stationAI' ? UI.btn(icon('dice', 14), 'randomName', { cls: 's', title: 'Random SS14 AI name' }) : ''}</div>`);
  return h;
}
export function lawsetPicker() {
  const st = s(); let h = '';
  for (const g of LAWSET_GROUPS) {
    h += `<div class="small b dim" style="margin-top:6px">${g.source}</div>`;
    for (const l of g.sets) {
      const on = st.lawset === l.id;
      h += `<div class="srow click" data-act="lawset" data-l="${l.id}" style="flex-direction:column;align-items:stretch;background:${on ? 'var(--rowsel)' : 'var(--pd)'};border:1px solid ${on ? 'var(--gold)' : 'rgba(255,255,255,.06)'};margin-top:6px">
        <div class="row-flex"><span style="color:${on ? 'var(--gold)' : 'var(--dim)'}">${on ? '☑' : '☐'}</span><span class="b grow">${esc(l.name)}</span><span class="tiny dim">${l.laws.length} laws</span></div>
        ${on ? l.laws.map((x, i) => `<div class="small" style="animation:lineIn .25s ${i * .04}s both"><b>Law ${i + 1}:</b> ${esc(x)}</div>`).join('') : ''}</div>`;
    }
  }
  const on = st.lawset === CUSTOM_LAWSET;
  h += `<div class="small b dim" style="margin-top:6px">Goob Station</div><div style="background:${on ? 'var(--rowsel)' : 'var(--pd)'};border:1px solid ${on ? 'var(--gold)' : 'rgba(255,255,255,.06)'};margin-top:6px;padding:10px" class="col">
    <div class="row-flex" data-act="lawset" data-l="${CUSTOM_LAWSET}" style="cursor:pointer"><span style="color:${on ? 'var(--gold)' : 'var(--dim)'}">${on ? '☑' : '☐'}</span><span class="b grow">Custom lawboard</span></div>
    ${on ? st.customLaws.map((l, i) => `<div class="row-flex"><span class="b" style="color:var(--gold);width:18px">${i + 1}</span><input class="field" data-model="settings.customLaws.${i}" value="${esc(l)}" placeholder="Write a law…">
      ${UI.btn('↑', 'lawUp', { cls: 's', data: `data-i="${i}"`, disabled: i === 0 })}${UI.btn('↓', 'lawDown', { cls: 's', data: `data-i="${i}"`, disabled: i === st.customLaws.length - 1 })}${UI.btn(icon('x', 12), 'lawDel', { cls: 's caution', data: `data-i="${i}"` })}</div>`).join('')
      + UI.btn(icon('plus', 13) + ' Add law', 'lawAdd', { cls: 's good' }) + '<div class="tiny dim">Laws are role-play flavour; real help always comes first.</div>' : ''}</div>`;
  return h;
}
export function accentPicker() {
  const st = s(); const ac = accent(st.accent);
  return `${UI.choice('No accent', 'Plain Nanotrasen standard.', st.accent === 'none', 'accent', 'data-a="none"')}
    ${ACCENTS.map((a, i) => `<div class="srow click ${i % 2 ? '' : 'alt'}" data-act="accent" data-a="${a.id}"><span style="color:${st.accent === a.id ? 'var(--gold)' : 'var(--dim)'};font-size:18px">${st.accent === a.id ? '☑' : '☐'}</span><div class="grow"><div class="b" style="font-size:14px">${esc(a.label)}</div><div class="small dim i">${esc(a.sample)}</div></div><span class="tiny dis">${esc(a.fork)}</span></div>`).join('')}
    ${ac ? `<div style="padding:12px"><div class="small b" style="color:var(--gold)">Preview</div><div class="i">${esc(applyAccent(ac, 'Hello crew member, I have set your reminder for tomorrow. Good luck with the work, my friend.'))}</div></div>` : ''}`;
}

function customise() {
  const st = s();
  return `${UI.section('Quick presets', `<div style="padding:10px 10px 2px">${presetCards()}</div>`, { trailing: '4 servers', footer: "One click applies a whole server's vibe (theme, personality, voice, sounds, boot screen). Everything below stays mix-and-match." })}
  ${UI.section('Interface theme', `<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:8px;padding:10px">${Object.entries(THEMES).map(([id, t]) =>
    `<div data-act="theme" data-t="${id}" style="cursor:pointer;padding:8px;background:${t.bg};border:${st.theme === id ? '2px solid ' + t.sw[3] : '1px solid rgba(255,255,255,.08)'};transition:transform .15s" onmouseover="this.style.transform='translateY(-2px)'" onmouseout="this.style.transform=''">
      <div style="display:flex">${t.sw.map(c => `<span style="flex:1;height:14px;background:${c}"></span>`).join('')}</div><div class="b small" style="color:${t.sw[4]};margin-top:6px">${t.label}</div><div class="tiny" style="color:#999">${t.source}</div></div>`).join('')}</div>
    ${UI.toggle('CRT scanlines & screen sweep', 'settings.crtEffects', st.crtEffects)}${UI.toggle('Action animations & popups', 'settings.animations', st.animations)}`)}
  ${UI.section('Unit', unitPicker(), { footer: `${UNIT_FORMS[st.form].blurb} (${UNIT_FORMS[st.form].source})` })}
  ${unitCustomizer()}
  ${UI.section('Personality', Object.entries(PERSONALITIES).map(([id, p], i) => UI.choice(p.label, p.detail, st.personality === id, 'personality', `data-p="${id}"`, i % 2)).join(''), { footer: `How ${esc(X.paiName())} talks. Each one comes from a fork.` })}
  ${UI.section('Speech accent', accentPicker(), { footer: 'Accents from Goob Station and Starlight. Like in-game, they rewrite what your unit says.' })}
  ${st.form === 'stationAI' ? `<div>${UI.nh('Lawset', esc(X.activeLawset().name))}<div class="col" style="gap:0">${lawsetPicker()}</div></div>` : ''}
  ${UI.section('Interface colour', `<div class="row-flex" style="padding:10px;gap:10px">${Object.entries(COLORS).map(([id, c]) => `<span data-act="color" data-c="${id}" title="${id === 'screen' ? 'Match screen' : id}" class="cham" style="width:34px;height:34px;cursor:pointer;background:${c || X.accentColor()};outline:${st.color === id ? '2.5px solid #fff' : 'none'};outline-offset:-3px"></span>`).join('')}</div>`)}
  ${UI.section('Boot screen', `<div class="row-flex" style="padding:10px;flex-wrap:wrap">${Object.entries(FORKS).map(([id, f]) => UI.btn(f.name, 'boot', { cls: 's ' + (st.bootStyle === id ? 'sel' : ''), data: `data-f="${id}"` })).join('')}</div>${UI.toggle('Boot sequence on launch', 'settings.bootSequence', st.bootSequence)}`)}`;
}

function alarmSelect(kind) {
  const cur = s()[kind + 'Sound'];
  const opt = (v, l) => `<option value="${esc(v)}" ${cur === v ? 'selected' : ''}>${esc(l)}</option>`;
  const songs = {};
  for (const t of A.AUDIO.music) (songs[t.playlist] ||= []).push(t);
  return `<select class="field" data-model="settings.${kind}Sound">${opt('none', 'Silent')}<optgroup label="SS14 sounds">${A.ALARM_SOUNDS.map(([v, l]) => opt(v, l)).join('')}</optgroup>
    ${Object.entries(songs).map(([pl, ts]) => `<optgroup label="Songs · ${esc(pl)}">${ts.map(t => opt('music:' + t.file, `${t.title} (${t.artist})`)).join('')}</optgroup>`).join('')}</select>`;
}
function alarms() {
  const st = s();
  return UI.section('Alarms', `<div class="srow"><span class="lab">Reminders</span>${alarmSelect('reminder')}${UI.btn(icon('play', 12), 'testAlarm', { cls: 's', data: 'data-k="reminder"', title: 'Preview' })}</div>
    <div class="srow alt"><span class="lab">Timers</span>${alarmSelect('timer')}${UI.btn(icon('play', 12), 'testAlarm', { cls: 's', data: 'data-k="timer"', title: 'Preview' })}</div>
    <div class="srow"><span class="lab">Song length</span><input type="range" min="5" max="120" step="5" value="${st.alarmLength}" data-model="settings.alarmLength"><span class="small dim" style="width:44px">${st.alarmLength}s</span></div>
    <div class="srow alt"><span class="lab">Alarm volume</span><input type="range" min="0.1" max="1" step="0.05" value="${st.alarmVolume}" data-model="settings.alarmVolume"></div>`,
    { footer: 'Pick any SS14 sound or any lobby song. Songs play until you tap the screen or the time runs out, then your music carries on. These play inside PAI; your phone’s own Calendar and Clock alerts use the phone’s sounds.' });
}
function audio() {
  const st = s(); const m = A.music; const ms = st.music;
  const tracks = m.tracks.map((t, i) => `<div class="srow click ${i % 2 ? 'alt' : ''}" data-act="track" data-f="${t.file}"><span style="color:${m.current?.file === t.file ? 'var(--accent)' : 'var(--dim)'}">${m.current?.file === t.file ? '♪' : '▷'}</span>
    <div class="grow"><div class="small">${esc(t.title)}</div><div class="tiny dim">${esc(t.artist)} · ${esc(t.license)}</div></div><span class="tiny dis">${esc(t.playlist)}</span></div>`).join('');
  const style = st.unitVoice === 'bark' || (st.unitVoice === 'auto' && st.form === 'terminal');
  return `${alarms()}${UI.section('Lobby music', `<div style="padding:12px" class="col" id="musicpanel">${musicNow()}</div>
    ${UI.toggle('Music enabled', 'settings.music.enabled', ms.enabled)}${UI.toggle('Play on launch', 'settings.music.autoplay', ms.autoplay)}${UI.toggle('Shuffle', 'settings.music.shuffle', ms.shuffle)}
    <div class="srow alt"><span class="lab">Playlists</span><div class="row-flex" style="flex-wrap:wrap">${m.playlists.map(p => UI.btn(esc(p), 'playlist', { cls: 's ' + (!ms.playlists.length || ms.playlists.includes(p) ? 'sel' : ''), data: `data-p="${esc(p)}"` })).join('')}</div></div>
    <div class="srow"><span class="lab">Ambience</span><select class="field" id="amb" style="max-width:240px"><option value="">Off</option>${A.AUDIO.ambience.map(a => `<option value="${a.file}" ${ms.ambience === a.file ? 'selected' : ''}>${esc(a.name)}</option>`).join('')}</select>
      ${ms.ambience ? `<input type="range" min="0" max="1" step="0.01" value="${ms.ambienceVolume}" data-model="settings.music.ambienceVolume" style="max-width:200px">` : ''}</div>${tracks}`,
    { trailing: `${A.AUDIO.music.length} tracks`, footer: 'Lobby and jukebox tracks from SS14 and the forks (licences listed per track and in CREDITS).' })}
  ${UI.section('Unit voice', Object.entries(VOICES).map(([id, [l, d]], i) => UI.choice(l, d, st.unitVoice === id, 'unitVoice', `data-v="${id}"`, i % 2)).join(''))}
  ${style ? UI.section('Bark', `<div class="row-flex" style="flex-wrap:wrap;padding:10px">${A.AUDIO.barks.map(b => UI.btn(esc(b.name), 'bark', { cls: 's ' + (st.unitBark === b.sound ? 'sel' : ''), data: `data-b="${b.sound}"`, title: b.source })).join('')}</div>`,
    { trailing: `${A.AUDIO.barks.length} barks`, footer: 'Barks from Nuclear 14 (Misfits & NC sets), Starlight and Goob Station.' }) : ''}
  ${UI.section('Sound pack', Object.entries(PACKS).map(([id, [l, d]], i) => UI.choice(l, d, st.soundPack === id, 'pack', `data-p="${id}"`, i % 2)).join(''), { footer: "Which fork's ID card, announcement and alert sounds to use." })}
  ${UI.section('Sound options', `${UI.toggle('All sounds', 'settings.sounds', st.sounds)}${UI.toggle('Keyboard typing sounds', 'settings.typingSounds', st.typingSounds)}${UI.toggle('Species emote sounds (*scream, *laugh…)', 'settings.emoteSounds', st.emoteSounds)}
    ${UI.toggle('Starlight job radio blips when I talk', 'settings.radioBlips', st.radioBlips)}${UI.toggle('Goob chat ping on highlights', 'settings.highlightPing', st.highlightPing)}${UI.toggle('Read replies aloud (Windows voice)', 'settings.speakReplies', st.speakReplies)}`)}
  ${UI.section('Sound board', soundBoard(), { trailing: 'click to play' })}`;
}
function musicNow() {
  const m = A.music; const ms = s().music;
  return `<div class="row-flex">${UI.eq(m.playing && !ms.muted)}<div class="grow"><div class="b">${esc(m.current?.title || 'Nothing playing')}</div><div class="small dim">${m.current ? esc(m.current.artist + ' · ' + m.current.playlist) : 'Press play'}</div></div></div>
    <div style="height:4px;background:var(--le)"><div style="height:100%;width:${(m.progress * 100).toFixed(1)}%;background:var(--accent)"></div></div>
    <div class="row-flex">${UI.btn(icon('prev', 14), 'musicPrev', { cls: 's' })}${UI.btn(icon(m.playing ? 'pause' : 'play', 14), 'musicToggle', { cls: 's good' })}${UI.btn(icon('next', 14), 'musicNext', { cls: 's' })}<span class="grow"></span>${UI.btn(icon(ms.muted ? 'mute' : 'speaker', 14) + (ms.muted ? ' Muted' : ' Mute'), 'mute', { cls: 's ' + (ms.muted ? 'caution' : '') })}</div>
    <div class="row-flex"><span class="dim">${icon('speaker', 14)}</span><input type="range" min="0" max="1" step="0.01" value="${ms.volume}" data-model="settings.music.volume"></div>`;
}
const BOARD = [['pai_say', 'pAI voice'], ['borg_say', 'Borg voice'], ['twobeep', 'Two beep (beeps)'], ['chime', 'Chime'], ['ping', 'Ping'], ['buzz_sigh', 'Buzz'], ['buzz_two', 'Buzz two'],
  ['announce', 'Announcement (reminders)'], ['attention', 'Attention (laws)'], ['welcome', 'Welcome'], ['power_on', 'Power on (boot)'], ['timer_start', 'Microwave start'], ['timer_done', 'Microwave done'],
  ['id_insert', 'ID insert'], ['id_swipe', 'ID swipe'], ['stamp', 'Stamp'], ['disc_insert', 'Disc insert'], ['scan_finish', 'Scan finish (web search)'], ['print_rip', 'Print & rip (new chat)'],
  ['ding', 'Ding'], ['deny', 'Deny'], ['pop', 'Pop'], ['goob_ping', 'Goob highlight ping'], ['sl_radio_ai', 'Starlight AI radio'], ['sl_announce2', 'Starlight announcement'], ['sl_blink', 'Starlight blink'], ['n14_bark_keytyped', 'N14 terminal bark']];
function soundBoard() { return `<div class="row-flex" style="flex-wrap:wrap;padding:10px">${BOARD.map(([f, n]) => UI.btn(icon('speaker', 12) + ' ' + n, 'board', { cls: 's ghost', data: `data-f="${f}"` })).join('')}</div>`; }

const MODELS = [['claude-haiku-5-5', 'Cheap · Haiku'], ['claude-sonnet-5-5', 'Smart · Sonnet']];
function mind() {
  const st = s();
  return `${UI.section('Neural uplink', `<div class="srow"><span style="color:${state.apiKey ? '#2CDB2C' : 'var(--caution)'}">${state.apiKey ? '✔' : '✘'}</span><span class="grow">${state.apiKey ? 'Mind installed' : 'No pAI is installed.'}</span>${state.apiKey ? UI.btn('Remove', 'removeKey', { cls: 's caution' }) : ''}</div>
    <div class="srow alt"><input class="field" type="password" id="keydraft" placeholder="Paste Claude API key (sk-ant-…)" autocomplete="off">${UI.btn('Save', 'saveKey', { cls: 's good' })}</div>
    <div class="srow"><span class="lab">Brain</span><div class="row-flex grow" style="flex-wrap:wrap">${MODELS.map(([id, n]) => UI.btn(n, 'setModel', { cls: 's' + (st.model === id ? ' good' : ' ghost'), data: `data-m="${id}"` })).join('')}</div></div>
    ${UI.field('Model ID', 'settings.model', st.model, 'claude-haiku-5-5', { alt: true })}${UI.toggle('Web search', 'settings.webSearch', st.webSearch)}
    <div class="srow alt">${UI.btn('Run diagnostics', 'test', { cls: 's', disabled: !state.apiKey })}<span class="small dim" id="testres">${esc(testResult)}</span></div>`,
    { footer: 'Get a key at console.anthropic.com → API Keys and add a few dollars of credit under Billing (set a monthly limit there too). A Claude.ai subscription does not include API access. Haiku is the cheapest (a fraction of a cent per message). Sonnet is smarter and costs about 20× more (still under a cent per message). Either way only the last few messages are sent and there is at most one web search per message (about 1¢ each). The key is saved only on this computer.' })}`;
}

function system() {
  const st = s();
  const device = P.isDesktop()
    ? UI.section('Desktop', `${UI.toggle('Keep running in the tray when I close the window (so reminders still fire)', 'settings.trayOnClose', st.trayOnClose)}
    ${UI.toggle('Start PAI when Windows starts', 'settings.startWithWindows', st.startWithWindows)}${UI.toggle('Windows notifications for reminders & timers', 'settings.notifications', st.notifications)}
    <div class="srow alt">${UI.btn(icon('mini', 13) + ' Mini mode', 'mini', { cls: 's' })}<span class="small dim">A small always-on-top window with your unit, clock, next reminder and timers.</span></div>
    <div class="srow">${UI.btn('Test notification', 'testNotify', { cls: 's' })}</div>`)
    : `${UI.section('Phone', `${UI.toggle('Play sounds even when my iPhone is on silent', 'settings.playWhenSilent', st.playWhenSilent)}${UI.toggle('Notifications for reminders & timers (while PAI is open)', 'settings.notifications', st.notifications)}
    <div class="srow alt">${UI.btn('Test notification', 'testNotify', { cls: 's' })}</div>
    ${P.isIOS() && !P.isStandalone() ? `<div class="srow" style="color:var(--caution)">Tip: tap Share → Add to Home Screen in Safari to install PAI as an app.</div>` : ''}`,
      { footer: 'With “play on silent” on, PAI’s sounds pause other audio (like Spotify) while they play; turn it off to let the silent switch mute PAI instead. Phones pause web apps in the background, so PAI itself can only ring while it is open. The two options below hand your reminders and timers to the phone’s own apps, which alert you any time.' })}
    ${UI.section('iPhone Calendar (reminders)', `${UI.toggle('Send new reminders to my Calendar app', 'settings.calendarSync', st.calendarSync)}
    <div class="srow alt">${state.reminders.length ? UI.btn(icon('calendar', 13) + ' Send all reminders now', 'icsAll', { cls: 's' }) : '<span class="small dim">No reminders yet.</span>'}</div>`,
      { footer: 'When you save a reminder, iPhone shows an “Add to Calendar” screen. Tap Add and Calendar alerts you at that time, even with PAI closed. Reminders PAI makes from chat show a “Send to Calendar” button on the chat screen.' })}
    ${UI.section('iPhone Clock (timers)', `${UI.toggle('Also start timers in the Clock app', 'settings.clockTimers', st.clockTimers)}
      ${UI.field('Shortcut name', 'settings.clockShortcut', st.clockShortcut, 'PAI Timer', { alt: true })}
      <div class="srow">${UI.btn('Test (10 second timer)', 'clockTest', { cls: 's' })}</div>
      <div class="srow alt" style="display:block;line-height:1.55"><b>One-time setup (1 minute):</b><br>
        1. Open the <b>Shortcuts</b> app and tap <b>+</b>.<br>
        2. Name it <b>PAI Timer</b> (tap the name at the top).<br>
        3. Search for the action <b>Start Timer</b> and add it.<br>
        4. Tap the <b>30</b> in it, choose <b>Select Variable → Shortcut Input</b>, then tap <b>minutes</b> and change it to <b>seconds</b>.<br>
        5. Tap <b>Done</b>. Then press <b>Test</b> above.</div>`,
      { footer: 'PAI opens Shortcuts for a moment to start the real Clock timer, then swipe back to PAI. The Clock app rings with your phone’s timer sound even if PAI is closed.' })}`;
  return `${device}
  ${UI.section('Chat', `${UI.toggle('Highlight my name & job in chat', 'settings.highlights', st.highlights)}<div class="srow alt">${UI.btn('Run setup again', 'rerunSetup', { cls: 's' })}<span class="small dim">Takes effect next launch</span></div>`,
    { footer: "Highlights work like SS14's chat highlights: your name and your station job's keywords show in #17FFC1." })}
  ${UI.section('Backup & move', `<div class="row-flex" style="padding:10px;flex-wrap:wrap">${UI.btn(icon('plus', 13) + ' Save backup file', 'backup', { cls: 's good' })}
      <label class="btn s" style="cursor:pointer">Load backup file<input type="file" id="restorefile" accept=".json,application/json" style="display:none"></label>
      <span class="small ${P.saveError ? '' : 'dim'}" style="${P.saveError ? 'color:#FF6B6B' : ''}">${P.saveError ? 'Last save failed: storage is full.' : '✔ Everything saves automatically on this device.'}</span></div>`,
    { footer: 'A backup holds your ID, character, reminders, timers, chat, settings and your API key, so keep it private. Save one on your PC, send it to your phone (email, OneDrive, iCloud Drive…), then Load it in PAI on the phone. Loading replaces what is on this device.' })}
  ${UI.section('Data', `<div class="row-flex" style="padding:10px">${UI.btn('Credits', 'credits', { cls: 's' })}${UI.btn('Clear chat', 'clearChat', { cls: 's' })}<span class="grow"></span>${UI.btn('Reset all', 'reset', { cls: 's caution' })}</div>`)}`;
}

export default {
  setPage(p) { page = p; },
  render() {
    const tabs = PAGES.map(([id, l]) => UI.btn(l, 'page', { cls: 's ' + (page === id ? 'sel' : ''), data: `data-p="${id}"` })).join('');
    return `${UI.header('Settings', 'Silicon configuration')}<div style="background:var(--pd);padding:8px 18px;display:flex;gap:4px;flex-wrap:wrap">${tabs}</div>
      <div class="content"><div class="col" style="max-width:860px">${{ customise, audio, mind, system }[page]()}</div></div>`;
  },
  mounted(root) {
    root.querySelector('#restorefile')?.addEventListener('change', (e) => {
      const f = e.target.files?.[0]; e.target.value = ''; if (!f) return;
      const rd = new FileReader(); rd.onload = async () => {
        try { await restoreBackup(String(rd.result)); A.sfx('id_insert'); X.popup('Backup loaded, restarting…', '#2CDB2C'); setTimeout(() => location.reload(), 900); }
        catch (err) { A.sfx('deny'); UI.modal('Could not load backup', `<div style="padding:14px">${esc(err.message || String(err))}</div>`); }
      }; rd.readAsText(f);
    });
    root.querySelector('#amb')?.addEventListener('change', (e) => { const prev = { ...s().music }; s().music.ambience = e.target.value || null; A.music.apply(prev); commit('settings'); });
    root.querySelector('#keydraft')?.addEventListener('keydown', (e) => { if (e.key === 'Enter') this.act.saveKey(); });
  },
  musicChanged() { const p = document.getElementById('musicpanel'); if (p && !p.contains(document.activeElement)) p.innerHTML = musicNow(); },
  act: {
    page(a) { page = a.dataset.p; re(true); },
    setModel(a) { s().model = a.dataset.m; A.sfx('disc_insert'); commit('settings'); },
    preset(a) { X.applyPreset(a.dataset.f); },
    theme(a) { s().theme = a.dataset.t; A.sfx('disc_insert'); commit('settings'); },
    form(a) { X.switchForm(a.dataset.f); A.unitSpeech('Hello!', a.dataset.f); },
    chassis(a) { s().chassis = a.dataset.c; A.unitSpeech('Hi!'); commit('settings'); },
    core(a) { s().core = a.dataset.c; A.unitSpeech('Hi!'); commit('settings'); },
    holo(a) { s().hologram = a.dataset.c; A.sfx('ping'); commit('settings'); },
    randomName() { s().paiName = AI_NAMES[Math.floor(Math.random() * AI_NAMES.length)]; commit('settings'); },
    personality(a) { s().personality = a.dataset.p; X.animate('unit', 'bounce'); commit('settings'); },
    accent(a) { s().accent = a.dataset.a; const ac = accent(a.dataset.a); if (ac) A.unitSpeech(ac.sample); commit('settings'); },
    lawset(a) { s().lawset = a.dataset.l; A.sfx('disc_insert'); commit('settings'); },
    lawAdd() { s().customLaws.push(''); A.sfx('button'); commit('settings'); },
    lawDel(a) { s().customLaws.splice(+a.dataset.i, 1); A.sfx('pop'); commit('settings'); },
    lawUp(a) { const i = +a.dataset.i, l = s().customLaws; [l[i - 1], l[i]] = [l[i], l[i - 1]]; A.sfx('hover'); commit('settings'); },
    lawDown(a) { const i = +a.dataset.i, l = s().customLaws; [l[i + 1], l[i]] = [l[i], l[i + 1]]; A.sfx('hover'); commit('settings'); },
    color(a) { s().color = a.dataset.c; commit('settings'); },
    boot(a) { s().bootStyle = a.dataset.f; commit('settings'); },
    unitVoice(a) { s().unitVoice = a.dataset.v; commit('settings'); A.unitSpeech('Testing, testing!'); X.animate('unit', 'talk'); },
    bark(a) { s().unitBark = a.dataset.b; A.bark('Hello there friend', a.dataset.b); commit('settings'); },
    pack(a) { s().soundPack = a.dataset.p; commit('settings'); A.sfx('announce'); },
    board(a) { A.play(a.dataset.f); },
    track(a) { const t = A.AUDIO.music.find(x => x.file === a.dataset.f); const prev = { ...s().music }; s().music.muted = false; A.music.apply(prev); commit('settings', true); A.music.start(t); },
    playlist(a) {
      const all = A.music.playlists; let l = s().music.playlists.length ? [...s().music.playlists] : [...all]; const p = a.dataset.p;
      l = l.includes(p) ? l.filter(x => x !== p) : [...l, p]; if (!l.length || l.length === all.length) l = [];
      s().music.playlists = l; commit('settings');
    },
    saveKey() { const k = document.getElementById('keydraft').value.trim(); if (!k) return A.sfx('deny'); X.installKey(k); },
    removeKey() { X.installKey(''); testResult = ''; },
    async test() {
      const el = document.getElementById('testres'); el.textContent = 'Testing…';
      try { testResult = '✓ ' + await AI.test(state.apiKey, s().model); X.flash('happy'); A.sfx('chime'); }
      catch (e) { testResult = '✗ ' + e.message; X.flash('sad'); A.sfx('buzz_two'); }
      el.textContent = testResult;
    },
    testAlarm(a) { if (A.alarmPlaying) return A.stopAlarm(); if (Date.now() - A.lastStop < 600) return; A.alarm(a.dataset.k); },
    async backup() { const d = new Date(); const ok = await P.saveFile(`PAI backup ${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}.json`, backupJSON(true)); if (ok) { A.sfx('print_rip'); X.popup('Backup saved', '#2CDB2C'); } },
    icsAll() { X.sendToCalendar(); },
    clockTest() { P.openURL(X.clockURL(10)); },
    testNotify() { P.notify(`${X.paiName()} · Test`, 'Notifications are working. Beep boop!'); A.sfx('announce'); },
    rerunSetup() { s().onboarded = false; A.sfx('boot_beep'); commit('settings'); X.popup('Setup runs on next launch'); },
    credits() { creditsWindow(); },
    clearChat() { X.clearChat(); },
    reset() { if (confirm('Erase your ID, character, calendar, timers, chat and settings?')) X.resetEverything(); },
  },
};
function re(anim) { import('../main.js').then(m => m.rerender(anim)); }

function creditsWindow() {
  UI.modal('Credits', `<div style="padding:16px" class="col">${[
    ['About', 'PAI uses content from Space Station 14 (github.com/space-wizards/space-station-14) and its forks Goob Station, Starlight and Nuclear 14. It is a fan project and isn’t affiliated with Space Wizards or the fork teams.'],
    ['Sprites — CC BY-SA 3.0', 'pAI (tgstation; Syndicate by fedKotikeD; potato by Doru991; golden from ScrapPAIGold by AsnDen), Station AI cores and holograms (vgstation, modified by chromiumboy; base by monotheonist), ID cards and job icons (/tg/station with SS14 edits), NT logo. N14 terminals from Mojave Sun 13 (CC BY-NC-SA 3.0).'],
    ['Characters', 'Species, hair, markings, clothing and displacement maps from SS14, Goob Station (incl. Delta-V, Nyanotrasen, Einstein Engines ports), Starlight and Nuclear 14. Mostly CC BY-SA 3.0; some fork sprites are CC BY-NC-SA. Full per-file list in tools/sprite_licenses.json.'],
    ['Sounds', 'SS14 talk, machine and announcement sounds (CC0 / CC BY / CC BY-SA; Goonstation voices CC BY-NC-SA). Fork sounds from Goob Station, Starlight (radio blips by JustAdler) and Nuclear 14 barks. Per-file list in tools/audio_licenses.json.'],
    ['Music', A.AUDIO.music.map(t => `${t.title} — ${t.artist} (${t.license})`).join('; ')],
    ['Fonts', 'Noto Sans (SIL OFL / Apache 2.0), as bundled with SS14.'],
    ['Code & data', 'Stylesheets recreated from SS14 (MIT). Jobs, lawsets, AI names, highlights and wording from SS14/fork locale files. Goob accent lists AGPL-3.0; Starlight accents MIT. Desktop shell: Neutralinojs (MIT).'],
  ].map(([t, b]) => `<div>${UI.nh(t)}<div class="small" style="margin-top:6px;line-height:1.5">${esc(b)}</div></div>`).join('')}</div>`);
}
