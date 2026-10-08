// ID card: identity fields, station job, photo, your SS14 character and voice.
import { state, commit } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as C from '../character.js';
import * as UI from '../ui.js';
import { esc, icon } from '../util.js';
import { job, deptColor, deptText, cardSprite, ALL_DEPARTMENTS, ALL_JOBS } from '../ss14.js';
import { openEditor } from './editor.js';
import { importButton } from '../importer.js';

let flip = false;

export function idCard(p = state.profile) {
  const j = job(p.stationJob); const dc = deptColor(j.department);
  const pic = p.photo && p.showPhoto ? `<img src="${p.photo}" style="width:100%;height:100%;object-fit:cover" class="anim-stamp">`
    : `<div data-anim-char style="width:104px;height:104px;margin-bottom:-8px">${C.img(p.character, p.stationJob, 0)}</div>`;
  return `<div class="idcard ${flip ? 'flip' : ''}" style="--dept:${dc}">
    <div class="top"><img class="px" src="img/${cardSprite(j)}.png" width="34" height="34"><span class="grow">NANOTRASEN ID</span>${UI.jobIcon(j)}<span>${esc(j.department)}</span></div>
    <div class="row-flex" style="gap:16px;padding:14px;align-items:flex-start">
      <div style="width:92px;height:110px;border:2px solid ${dc};background:linear-gradient(var(--row), color-mix(in srgb, ${dc} 35%, transparent));display:flex;align-items:flex-end;justify-content:center;overflow:hidden;flex:none">${pic}</div>
      <div class="grow" style="display:flex;flex-direction:column;gap:3px;min-height:110px">
        <div class="b" style="font-size:20px">${esc(p.fullName || 'UNREGISTERED')}</div>
        <div class="b" style="color:${deptText(j.department)}">(${esc(j.name)})</div>
        ${p.jobTitle ? `<div class="small dim">${esc(p.jobTitle)}</div>` : ''}${p.pronouns ? `<div class="small dim">${esc(p.pronouns)}</div>` : ''}
        ${p.birthday ? `<div class="small dim">DOB ${new Date(p.birthday).toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })}</div>` : ''}
        <span class="grow"></span><div class="tiny dis">ID# ${esc(p.idNumber.toUpperCase())}</div>
      </div></div></div>`;
}

export function characterCard() {
  const c = state.profile.character; const sp = C.species(c.species);
  return UI.section('Character', `<div class="row-flex" style="padding:12px;gap:14px">
    <div class="floor" style="width:120px;height:120px;flex:none;cursor:pointer" data-act="turn" title="Click to turn"><div data-anim-char style="width:100%;height:100%" id="cardchar">${C.img(c, state.profile.stationJob, turnDir)}</div></div>
    <div class="col grow" style="gap:6px"><div class="b" style="font-size:16px">${esc(sp.name)}</div><div class="small dim">${esc(c.sex)} · ${c.markings.length} markings · voice: ${esc(A.AUDIO.speech[A.voiceID(c)]?.name || '')}</div>
      ${c.bio?.name ? `<div class="small"><b>${esc(c.bio.name)}</b>${c.bio.age != null ? `, ${esc(String(c.bio.age))}` : ''}${c.bio.fork ? ` <span class="dis">· from ${esc(c.bio.fork)}</span>` : ''}</div>` : ''}
      ${c.bio?.flavor ? `<div class="small dim" style="font-style:italic">${esc(c.bio.flavor)}</div>` : ''}
      ${c.bio?.traits?.length ? `<div class="tiny dis">Traits: ${esc(c.bio.traits.join(', '))}</div>` : ''}
      <div class="small dis">Click the sprite to turn it. Type *flip or *scream in chat.</div>
      <div class="row-flex" style="flex-wrap:wrap">${UI.btn(icon('edit', 13) + ' Edit character', 'editChar', { cls: 'good' })}${UI.btn(icon('dice', 13) + ' Randomize', 'randomChar', { cls: 'ghost' })}${importButton()}</div></div></div>`, { trailing: sp.source });
}
let turnDir = 0;

export function jobPicker(onPick) {
  UI.modal('Station job', `<div style="padding:12px" class="col">${ALL_DEPARTMENTS.map(d => `<div><div class="row-flex b" style="color:${deptText(d)};margin-bottom:6px"><span style="width:10px;height:10px;background:${deptColor(d)};display:inline-block"></span>${esc(d)}</div>
    <div class="gridtiles" style="padding:0;grid-template-columns:repeat(auto-fill,minmax(170px,1fr))">${ALL_JOBS.filter(j => j.department === d).map(j => `<div class="srow click ${j.id === state.profile.stationJob ? 'alt' : ''}" data-act="pickJob" data-id="${j.id}" style="border:1px solid ${j.id === state.profile.stationJob ? 'var(--gold)' : 'transparent'}">${UI.jobIcon(j, 24)}<span>${esc(j.name)}</span></div>`).join('')}</div></div>`).join('')}</div>`, { wide: true });
  window.__jobPick = onPick;
}

export default {
  render() {
    const p = state.profile;
    return `${UI.header('ID Card', 'Crew registration terminal')}
    <div class="content"><div style="display:grid;grid-template-columns:minmax(320px,440px) 1fr;gap:18px;align-items:start" class="idwrap">
      <div class="col">${idCard()}${characterCard()}
        <div class="row-flex"><label class="btn grow" style="cursor:pointer">${icon('plus', 14)} ${p.photo ? 'Change photo' : 'Add photo'}<input type="file" accept="image/*" id="photo" style="display:none"></label>
          ${p.photo ? UI.btn(p.showPhoto ? 'Use character' : 'Use photo', 'togglePhoto') + UI.btn('Remove', 'removePhoto', { cls: 'caution' }) : ''}</div></div>
      <div class="col">
        ${UI.section('Identity', `${UI.field('Full name', 'profile.fullName', p.fullName, 'Alex Morgan')}${UI.field('Call me', 'profile.preferredName', p.preferredName, 'Alex', { alt: true })}
          ${UI.field('Pronouns', 'profile.pronouns', p.pronouns, 'they/them')}
          <div class="srow alt"><span class="lab">Birthday</span><input class="field" type="date" id="bday" value="${p.birthday ? new Date(p.birthday).toISOString().slice(0, 10) : ''}"></div>
          <div class="srow"><span class="lab">Voice</span><span class="grow b">${esc(A.AUDIO.speech[A.voiceID(p.character)]?.name || 'Default')}</span>${UI.btn('Change', 'voiceMenu', { cls: 's' })}${UI.btn(icon('speaker', 13), 'previewVoice', { cls: 's' })}</div>`,
          { footer: `${esc(X.paiName())} uses “Call me” when talking to you.` })}
        ${UI.section('Assignment', `<div class="srow click" data-act="jobs"><span class="lab">Station job</span>${UI.jobIcon(job(p.stationJob), 18)}<span class="grow">${esc(job(p.stationJob).name)}</span><span class="dim">›</span></div>
          ${UI.field('Real-life job', 'profile.jobTitle', p.jobTitle, 'Student, Mechanic…', { alt: true })}${UI.field('Home city', 'profile.homeCity', p.homeCity, 'Denver, CO')}`,
          { footer: 'Your station job sets your ID card, department colour, job icon, chat highlights and your character’s outfit.' })}
        ${UI.section('Records', `<div class="srow"><textarea class="field" data-model="profile.interests" placeholder="Interests: games, music, food…">${esc(p.interests)}</textarea></div>
          <div class="srow"><textarea class="field" data-model="profile.notes" placeholder="Anything else ${esc(X.paiName())} should know">${esc(p.notes)}</textarea></div>`,
          { footer: 'Saved on this computer. When you chat, your ID is sent to Claude (Anthropic) with your message so replies can be personalised.' })}
      </div></div></div><style>@media (max-width:900px){.idwrap{grid-template-columns:1fr!important}}</style>`;
  },
  mounted(root) {
    flip = false;
    root.querySelector('#photo')?.addEventListener('change', (e) => {
      const f = e.target.files[0]; if (!f) return;
      const r = new FileReader(); r.onload = () => {
        const img = new Image(); img.onload = () => {
          const s = 400, cv = document.createElement('canvas'); cv.width = s; cv.height = s; const g = cv.getContext('2d');
          const m = Math.min(img.width, img.height); g.drawImage(img, (img.width - m) / 2, (img.height - m) / 2, m, m, 0, 0, s, s);
          state.profile.photo = cv.toDataURL('image/jpeg', 0.85); state.profile.showPhoto = true; A.sfx('stamp'); commit('profile');
        }; img.src = r.result;
      }; r.readAsDataURL(f);
    });
    root.querySelector('#bday')?.addEventListener('change', (e) => { state.profile.birthday = e.target.value ? new Date(e.target.value + 'T12:00').getTime() : null; commit('profile', true); });
  },
  act: {
    jobs() { jobPicker((id) => { state.profile.stationJob = id; flip = true; A.sfx('id_swipe'); commit('profile'); }); },
    pickJob(a) { UI.closeModal(); window.__jobPick?.(a.dataset.id); },
    togglePhoto() { state.profile.showPhoto = !state.profile.showPhoto; A.sfx('stamp'); commit('profile'); },
    removePhoto() { state.profile.photo = null; state.profile.showPhoto = false; commit('profile'); },
    editChar() { openEditor(); },
    randomChar() { C.randomize(state.profile.character); A.sfx('print_rip'); commit('profile'); X.animate('character', 'spin'); },
    turn() { turnDir = { 0: 2, 2: 1, 1: 3, 3: 0 }[turnDir]; A.sfx('click'); const el = document.getElementById('cardchar'); if (el) el.innerHTML = C.img(state.profile.character, state.profile.stationJob, turnDir); },
    voiceMenu(a) { voiceMenu(a); },
    previewVoice() { A.userSpeech(['Hello.', 'Hello?', 'Hello!'][Math.floor(Math.random() * 3)], A.voiceID(state.profile.character)); X.animate('character', 'talk'); },
  },
};

export function voiceMenu(anchor) {
  const items = [{ label: 'Species default', run: () => setVoice(null) }];
  for (const src of ['Space Station 14', 'Goob Station', 'Starlight', 'Nuclear 14']) {
    const list = Object.entries(A.AUDIO.speech).filter(([, v]) => v.source === src).sort((a, b) => a[1].name.localeCompare(b[1].name));
    if (list.length) { items.push({ header: src }); for (const [id, v] of list) items.push({ label: v.name, run: () => setVoice(id) }); }
  }
  UI.menu(anchor, items);
}
function setVoice(id) {
  state.profile.character.voice = id; commit('profile');
  A.userSpeech('Hello there.', A.voiceID(state.profile.character)); X.animate('character', 'talk');
}
