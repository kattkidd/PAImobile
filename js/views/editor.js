// SS14-style "Character Setup": species, body, skin, eyes, hair, markings, loadout, wardrobe, voice, emotes.
import { state, commit } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as C from '../character.js';
import * as UI from '../ui.js';
import { esc, icon, cap } from '../util.js';
import { ALL_DEPARTMENTS, ALL_JOBS, job } from '../ss14.js';

let tab = 'appearance', dir = 0, sub = null, search = '';
const c = () => state.profile.character;
const jobId = () => state.profile.stationJob;
const short = (s) => s === 'Space Station 14' ? 'SS14' : s;

function save(anim) { commit('profile', true); draw(); if (anim) setTimeout(() => X.animate('character', anim), 30); }

function tile(inner, name, on, act, data = '', src = '') {
  return `<div class="tile ${on ? 'on' : ''}" data-act="${act}" ${data}><div style="width:56px;height:56px;margin:0 auto">${inner}</div><div class="nm">${esc(name)}</div>${src ? `<div class="tiny dim">${esc(src)}</div>` : ''}</div>`;
}
function colorRow(label, value, act, presets) {
  return `<div class="srow" style="flex-wrap:wrap"><span class="lab">${label}</span>
    ${presets.map(p => `<span class="swatch ${p.toUpperCase() === value.toUpperCase() ? 'on' : ''}" style="background:${p}" data-act="${act}" data-c="${p}"></span>`).join('')}
    <input type="color" value="${value}" data-color="${act}"><span class="tiny dim mono">${value}</span></div>`;
}
const HAIR_COLORS = ['#1A1A1A', '#2B1B12', '#4E3628', '#7A4E2D', '#B5875A', '#D9C08C', '#8C2F1B', '#C9C9C9', '#4F7FD9', '#D94FA0'];
const EYE_COLORS = ['#5A3A22', '#3B6E8F', '#4A7A3A', '#7A6A3A', '#2E2E2E', '#8F3B3B', '#B7A23A', '#9A5ACD'];
const HEAD = new Set(['Head', 'Eyes', 'Snout', 'Hair', 'FacialHair', 'HeadTop', 'HeadSide', 'SnoutCover', 'Face']);

function preview() {
  const ch = c(); const sp = C.species(ch.species);
  return `<div class="floor" style="height:250px;position:relative;display:flex;align-items:flex-end;justify-content:center;gap:28px;padding-bottom:18px">
    <div style="position:absolute;left:12px;right:12px;top:10px" class="row-flex"><span class="b">${esc(sp.name)}</span><span class="tiny dim">${esc(sp.source)}</span><span class="grow"></span>
      ${UI.btn(icon('rotl', 14), 'rot', { cls: 's', data: 'data-d="-1"', title: 'Rotate' })}${UI.btn(icon('rotr', 14), 'rot', { cls: 's', data: 'data-d="1"', title: 'Rotate' })}</div>
    <div data-anim-char style="width:150px;height:150px">${C.img(ch, jobId(), dir)}</div>
    <div data-anim-char style="width:104px;height:104px">${C.img(ch, jobId(), [2, 3, 0, 1][dir])}</div>
    <div style="position:absolute;left:12px;right:12px;bottom:10px" class="row-flex">${UI.btn(icon('dice', 14) + ' Randomize', 'rand', { cls: 's' })}<span class="grow"></span>
      <span class="row-flex toggle" data-act="clothes" style="cursor:pointer">Clothes <span class="check">${ch.showClothes ? '✓' : ''}</span></span></div></div>
    <div class="row-flex" style="justify-content:center;padding:8px;background:var(--whd);gap:4px">${['appearance', 'markings', 'loadout', 'voice'].map(t => UI.btn(cap(t), 'tab', { cls: 's ' + (tab === t ? 'sel' : ''), data: `data-t="${t}"` })).join('')}</div>`;
}

function appearance() {
  const ch = c(); const sp = C.species(ch.species); let h = '';
  h += UI.section('Species', `<div class="tiles">${C.DB.species.map(s => {
    const p = { ...C.starter(), showClothes: false }; if (s.id !== 'Human') C.changeSpecies(p, s.id);
    return tile(C.img(p, 'Passenger', 0), s.name, s.id === ch.species, 'species', `data-id="${s.id}"`, short(s.source));
  }).join('')}</div>`, { trailing: `${C.DB.species.length} species` });
  if (sp.sexes.length > 1) h += UI.section('Body type', `<div class="row-flex" style="padding:10px">${sp.sexes.map(sx => UI.btn(sx, 'sex', { cls: 's ' + (ch.sex === sx ? 'sel' : ''), data: `data-s="${sx}"` })).join('')}</div>`);
  if (sp.skin.mode === 'human') {
    const grad = Array.from({ length: 11 }, (_, i) => C.humanTone(i * 10)).join(',');
    h += UI.section('Skin', `<div style="padding:12px"><input type="range" min="0" max="100" step="0.5" value="${ch.skinTone}" data-range="skinTone"><div style="height:6px;margin-top:6px;background:linear-gradient(90deg,${grad})"></div></div>`,
      { footer: 'SS14 human skin tones (HumanToned): slide from pale gold to dark.' });
  } else if (sp.skin.mode !== 'fixed') {
    h += UI.section('Skin', colorRow('Colour', ch.skin, 'skin', [sp.skin.default, '#3F8F3F', '#2F6FA8', '#A83F3F', '#C9A227', '#7A4FA8', '#D9D9D9', '#4A4A4A', '#E08A3C']),
      { footer: sp.skin.mode === 'tinted' ? 'This species only takes light tints.' : 'Very dark colours are brightened like in-game.' });
  }
  if (sp.eyes) h += UI.section('Eyes', colorRow('Eye colour', ch.eyes, 'eyes', EYE_COLORS));
  for (const cat of ['Hair', 'FacialHair']) {
    const lim = C.limit(sp, cat); if (!lim) continue;
    const opts = C.markingsFor(sp, cat, ch.sex); const cur = C.picks(ch, cat)[0]?.id;
    const headOnly = (m) => { const p = { ...ch, markings: ch.markings.filter(x => C.DB.markings[x.id]?.cat !== cat), showClothes: false }; if (m) { p.markings = [...p.markings, { id: m.id, colors: C.defaultColors(p, m) }]; } return `<div style="width:56px;height:56px;overflow:hidden"><div style="width:112px;height:112px;margin-left:-28px;margin-top:-4px">${C.img(p, 'Passenger', 0, { only: HEAD })}</div></div>`; };
    h += UI.section(cat === 'Hair' ? 'Hair' : 'Facial hair', colorRow('Colour', cat === 'Hair' ? ch.hair : ch.facialHair, cat === 'Hair' ? 'hairCol' : 'beardCol', HAIR_COLORS)
      + `<div class="tiles">${lim.required ? '' : tile(`<div style="font-size:26px;line-height:56px" class="dim">⦸</div>`, 'None', !cur, 'style', `data-cat="${cat}" data-id=""`)}${opts.map(m => tile(headOnly(m), m.name, cur === m.id, 'style', `data-cat="${cat}" data-id="${m.id}"`)).join('')}</div>`, { trailing: `${opts.length} styles` });
  }
  const [h0, h1] = C.heightRange(sp), [w0, w1] = C.widthRange(sp);
  h += UI.section('Size', `<div class="srow"><span class="lab">Height</span><input type="range" min="${h0}" max="${h1}" step="0.01" value="${ch.height}" data-range="height"><span class="mono small" style="width:44px">${Math.round(ch.height * 100)}%</span></div>
    <div class="srow alt"><span class="lab">Width</span><input type="range" min="${w0}" max="${w1}" step="0.01" value="${ch.width}" data-range="width"><span class="mono small" style="width:44px">${Math.round(ch.width * 100)}%</span></div>`,
    { footer: 'Height and width sliders from Goob Station / Starlight (Einstein Engines).' });
  return h;
}

function markings() {
  const ch = c(); const sp = C.species(ch.species);
  const cats = sp.limits.map(l => l.cat).filter(x => x !== 'Hair' && x !== 'FacialHair').sort((a, b) => (C.CAT_ORDER.indexOf(a) + 99) % 999 - (C.CAT_ORDER.indexOf(b) + 99) % 999);
  if (!cats.length) return '<div class="dim">This species has no markings.</div>';
  return cats.map(cat => {
    const lim = C.limit(sp, cat); const pk = C.picks(ch, cat); const avail = C.markingsFor(sp, cat, ch.sex).length;
    const rows = pk.map((p, i) => {
      const m = C.DB.markings[p.id]; if (!m) return '';
      return `<div class="srow ${i % 2 ? 'alt' : ''}"><div style="width:34px;height:34px;position:relative;background:var(--row);flex:none">${m.sprites.map((k, j) => `<div style="position:absolute;inset:0">${C.stripIcon(k, p.colors[j])}</div>`).join('')}</div>
        <div class="grow"><div>${esc(m.name)}</div><div class="tiny dim">${esc(m.source)}</div></div>
        ${p.colors.map((col, j) => `<input type="color" value="${col}" data-mcolor="${p.id}" data-j="${j}" title="Layer ${j + 1}">`).join('')}
        ${lim.required && pk.length <= 1 ? '' : `<button class="btn s caution" data-act="unmark" data-id="${p.id}">${icon('x', 12)}</button>`}</div>`;
    }).join('');
    return UI.section(C.catLabel(cat), rows + `<div class="srow click" data-act="markPicker" data-cat="${cat}"><span style="color:var(--goodl)">${icon('plus', 16)}</span><span class="grow">${pk.length >= lim.limit ? 'Swap marking' : 'Add marking'}</span><span class="small dim">${avail} available</span></div>`,
      { trailing: `${pk.length}/${lim.limit}${lim.required ? ' · required' : ''}` });
  }).join('');
}

function loadout() {
  const ch = c(); const j = C.DB.jobs[ch.outfitJob || jobId()] || C.DB.jobs.Passenger; const fit = C.outfit(ch, jobId());
  let h = UI.section('Outfit', `<div class="srow toggle" data-act="clothes"><span class="grow">Show clothing</span><span class="check">${ch.showClothes ? '✓' : ''}</span></div>
    <div class="srow alt click" data-act="outfitJob"><span class="lab">Wear</span>${UI.jobIcon(jobOf(ch.outfitJob || jobId()), 18)}<span class="grow">${esc(jobName(ch.outfitJob || jobId()))}${ch.outfitJob ? '' : ' (my ID job)'}</span><span class="dim">›</span></div>`,
    { footer: 'SS14 job loadouts. Wasteland jobs are dressed in SS14 gear.' });
  for (const g of j?.groups || []) {
    const cur = ch.loadout[g.id] ?? (g.min === 0 ? 'none' : g.options[0]?.id);
    h += UI.section(g.name, `<div class="tiles">${g.min === 0 ? tile(`<div style="font-size:26px;line-height:56px" class="dim">⦸</div>`, 'None', cur === 'none', 'loadout', `data-g="${g.id}" data-o="none"`) : ''}
      ${g.options.map(o => tile(C.stripIcon(Object.values(o.items).map(i => C.DB.items[i]?.icon).find(Boolean)), cap(o.name), cur === o.id, 'loadout', `data-g="${g.id}" data-o="${o.id}"`)).join('')}</div>`);
  }
  h += UI.section('Wardrobe', C.SLOT_ORDER.filter(s => C.DB.wardrobe[s]).map((s, i) => {
    const it = C.DB.items[fit[s]];
    return `<div class="srow click ${i % 2 ? 'alt' : ''}" data-act="wardrobe" data-slot="${s}"><span class="lab" style="width:80px">${C.SLOT_LABEL[s]}</span><div style="width:30px;height:30px;flex:none">${it ? C.stripIcon(it.icon) : ''}</div>
      <span class="grow ${it ? '' : 'dis'}">${it ? esc(cap(it.name)) : 'Nothing'}</span>${ch.wardrobe[s] ? '<span class="tiny" style="color:var(--gold)">custom</span>' : ''}<span class="dim">›</span></div>`;
  }).join('') + (Object.keys(ch.wardrobe).length ? `<div style="padding:10px">${UI.btn('Reset to job loadout', 'resetWardrobe', { cls: 's caution' })}</div>` : ''),
    { footer: 'Put anything from any job (plus some wasteland extras) in any slot.' });
  return h;
}

function voice() {
  const ch = c(); const cur = A.voiceID(ch);
  const voices = Object.entries(A.AUDIO.speech).sort((a, b) => a[1].name.localeCompare(b[1].name));
  let h = UI.section('Voice', `<div class="srow click" data-act="voice" data-id=""><span style="color:${!ch.voice ? 'var(--gold)' : 'var(--dim)'}">${!ch.voice ? '☑' : '☐'}</span><span class="grow">Species default</span><span class="small dim">${esc(A.AUDIO.speech[A.AUDIO.species[ch.species]?.speech]?.name || '')}</span></div>`
    + `<div class="gridtiles" style="grid-template-columns:repeat(auto-fill,minmax(180px,1fr))">${voices.map(([id, v]) => `<div class="srow click ${ch.voice === id ? 'alt' : ''}" data-act="voice" data-id="${id}" style="border:1px solid ${ch.voice === id ? 'var(--gold)' : 'transparent'}">
      <span>${cur === id ? icon('speaker', 14) : '·'}</span><span class="grow">${esc(v.name)}</span><span class="tiny dim">${esc(short(v.source))}</span></div>`).join('')}</div>`,
    { trailing: `${voices.length} voices`, footer: "Talk sounds from SS14's speech_sounds.yml and the forks. Plays whenever you send a message." });
  const em = A.availableEmotes(ch.species, ch.sex);
  h += UI.section('Emotes', `<div class="row-flex" style="flex-wrap:wrap;padding:10px">${em.map(e => UI.btn(esc(e.name), 'tryEmote', { cls: 's', data: `data-id="${e.id}"` })).join('')}
    ${['Flip', 'Spin', 'Jump', 'Dance'].map(m => UI.btn(m, 'tryMove', { cls: 's good', data: `data-m="${m.toLowerCase()}"` })).join('')}</div>`,
    { trailing: String(em.length), footer: 'Type these in chat with a * (like *scream). Movement emotes *flip, *spin, *jump and *dance work too.' });
  return h;
}

function picker() {
  const ch = c(); const sp = C.species(ch.species);
  if (sub.type === 'mark') {
    const all = C.markingsFor(sp, sub.cat, ch.sex).filter(m => !search || m.name.toLowerCase().includes(search.toLowerCase()));
    const side = ['Tail', 'TailBehind', 'Wings', 'TailOverlay'];
    return `<div class="row-flex" style="padding:10px">${UI.btn('‹ Back', 'back', { cls: 's' })}<span class="b grow">${esc(C.catLabel(sub.cat))}</span><input class="field" id="esearch" placeholder="Search ${all.length} markings" value="${esc(search)}" style="max-width:260px"></div>
      <div class="gridtiles">${all.map(m => {
        const p = { ...ch, showClothes: false, markings: ch.markings.some(x => x.id === m.id) ? ch.markings : [...ch.markings, { id: m.id, colors: C.defaultColors(ch, m) }] };
        return `<div class="tile ${ch.markings.some(x => x.id === m.id) ? 'on' : ''}" data-act="mark" data-id="${m.id}"><div style="width:64px;height:64px;margin:0 auto">${C.img(p, jobId(), side.includes(m.layer) ? 2 : 0)}</div><div class="nm">${esc(m.name)}</div>${m.source !== 'Space Station 14' ? `<div class="tiny dim">${esc(m.source)}</div>` : ''}</div>`;
      }).join('')}</div>`;
  }
  const all = (C.DB.wardrobe[sub.slot] || []).map(i => C.DB.items[i]).filter(it => it && (!search || it.name.toLowerCase().includes(search.toLowerCase())));
  return `<div class="row-flex" style="padding:10px">${UI.btn('‹ Back', 'back', { cls: 's' })}<span class="b grow">${C.SLOT_LABEL[sub.slot]}</span>${UI.btn('Job default', 'wear', { cls: 's', data: 'data-id=""' })}${UI.btn('Nothing', 'wear', { cls: 's caution', data: 'data-id="none"' })}<input class="field" id="esearch" placeholder="Search ${all.length} items" value="${esc(search)}" style="max-width:220px"></div>
    <div class="gridtiles">${all.map(it => { const p = { ...ch, showClothes: true, wardrobe: { ...ch.wardrobe, [sub.slot]: it.id } };
      return `<div class="tile ${ch.wardrobe[sub.slot] === it.id ? 'on' : ''}" data-act="wear" data-id="${it.id}"><div style="width:64px;height:64px;margin:0 auto">${C.img(p, jobId(), 0)}</div><div class="nm">${esc(cap(it.name))}</div></div>`; }).join('')}</div>`;
}

function body() {
  if (sub) return picker();
  return preview() + `<div style="padding:12px" class="col">${{ appearance, markings, loadout, voice }[tab]()}</div>`;
}
function draw() {
  const b = document.querySelector('#modal .body'); if (!b) return;
  const st = b.scrollTop; const focus = document.activeElement?.id === 'esearch';
  b.innerHTML = body(); b.scrollTop = st;
  bindInputs(b);
  if (focus) { const s = b.querySelector('#esearch'); s.focus(); s.setSelectionRange(s.value.length, s.value.length); }
}
function bindInputs(b) {
  b.querySelectorAll('[data-range]').forEach(r => r.addEventListener('input', () => {
    const ch = c(); const k = r.dataset.range; const v = parseFloat(r.value);
    if (k === 'skinTone') { const old = ch.skin; ch.skinTone = v; ch.skin = C.humanTone(v); C.refreshColors(ch, old); } else ch[k] = v;
    clearTimeout(r._t); r._t = setTimeout(() => save(), 60);
  }));
  b.querySelectorAll('input[type=color][data-color]').forEach(i => i.addEventListener('change', () => ACT[i.dataset.color]({ dataset: { c: i.value.toUpperCase() } })));
  b.querySelectorAll('input[type=color][data-mcolor]').forEach(i => i.addEventListener('change', () => {
    const p = c().markings.find(x => x.id === i.dataset.mcolor); if (p) { p.colors[+i.dataset.j] = i.value.toUpperCase(); save(); }
  }));
  b.querySelector('#esearch')?.addEventListener('input', (e) => { search = e.target.value; clearTimeout(e.target._t); e.target._t = setTimeout(draw, 150); });
}

const ACT = {
  tab: (a) => { tab = a.dataset.t; draw(); },
  rot: (a) => { const order = [0, 2, 1, 3]; dir = order[(order.indexOf(dir) + +a.dataset.d + 4) % 4]; draw(); },
  rand: () => { C.randomize(c()); A.sfx('print_rip'); save('spin'); },
  clothes: () => { c().showClothes = !c().showClothes; save('bounce'); },
  species: (a) => { if (a.dataset.id === c().species) return; C.changeSpecies(c(), a.dataset.id); save('jump'); A.characterEmote('Laugh', c()); },
  sex: (a) => { c().sex = a.dataset.s; save('bounce'); },
  skin: (a) => { const ch = c(); const old = ch.skin; ch.skin = C.clampSkin(a.dataset.c, C.species(ch.species).skin.mode); C.refreshColors(ch, old); save(); },
  eyes: (a) => { c().eyes = a.dataset.c; save(); },
  hairCol: (a) => { c().hair = a.dataset.c; C.refreshColors(c()); save(); },
  beardCol: (a) => { c().facialHair = a.dataset.c; C.refreshColors(c()); save(); },
  style: (a) => { const ch = c(); for (const p of C.picks(ch, a.dataset.cat)) C.remove(ch, p.id); if (a.dataset.id) C.add(ch, C.DB.markings[a.dataset.id]); save('bounce'); },
  unmark: (a) => { C.remove(c(), a.dataset.id); A.sfx('pop'); save(); },
  markPicker: (a) => { sub = { type: 'mark', cat: a.dataset.cat }; search = ''; draw(); document.querySelector('#modal .body').scrollTop = 0; },
  mark: (a) => { C.add(c(), C.DB.markings[a.dataset.id]); sub = null; save('bounce'); },
  back: () => { sub = null; draw(); },
  outfitJob: (a) => {
    const items = [{ label: `My ID job (${job(jobId()).name})`, run: () => { c().outfitJob = null; c().loadout = {}; save('spin'); } }];
    for (const d of ALL_DEPARTMENTS) { items.push({ header: d }); for (const j of ALL_JOBS.filter(x => x.department === d && C.DB.jobs[x.id])) items.push({ label: j.name, run: () => { c().outfitJob = j.id; c().loadout = {}; A.sfx('id_swipe'); save('spin'); } }); }
    for (const [pre, label] of [['starlight', 'Starlight jobs'], ['goob', 'Goob Station jobs']]) {
      items.push({ header: label });
      for (const [id, j] of Object.entries(C.DB.jobs).filter(([k]) => k.startsWith(pre + ':')).sort((x, y) => x[1].name.localeCompare(y[1].name)))
        items.push({ label: j.name, run: () => { c().outfitJob = id; c().loadout = {}; A.sfx('id_swipe'); save('spin'); } });
    }
    UI.menu(a, items);
  },
  loadout: (a) => { const ch = c(); ch.loadout[a.dataset.g] = a.dataset.o; const g = (C.DB.jobs[ch.outfitJob || jobId()]?.groups || []).find(x => x.id === a.dataset.g); const o = g?.options.find(x => x.id === a.dataset.o); for (const s of Object.keys(o?.items || {})) delete ch.wardrobe[s]; save('bounce'); },
  wardrobe: (a) => { sub = { type: 'wear', slot: a.dataset.slot }; search = ''; draw(); document.querySelector('#modal .body').scrollTop = 0; },
  wear: (a) => { const ch = c(); if (a.dataset.id) ch.wardrobe[sub.slot] = a.dataset.id; else delete ch.wardrobe[sub.slot]; if (a.dataset.id && a.dataset.id !== 'none') ch.showClothes = true; sub = null; save('bounce'); },
  resetWardrobe: () => { c().wardrobe = {}; save('spin'); },
  voice: (a) => { c().voice = a.dataset.id || null; save(); A.userSpeech(['Hello there.', 'How are you?', 'Hey!'][Math.floor(Math.random() * 3)], A.voiceID(c())); X.animate('character', 'talk'); },
  tryEmote: (a) => { A.characterEmote(a.dataset.id, c()); X.animate('character', X.animForEmote(a.dataset.id)); },
  tryMove: (a) => { A.sfx('button'); X.animate('character', a.dataset.m); },
  done: () => { A.sfx('id_insert'); X.popup('Character saved'); sub = null; UI.closeModal(); window.__editorAct = null; commit('profile'); window.dispatchEvent(new Event('pai-editor-closed')); setTimeout(() => X.animate('character', 'jump'), 50); },
};

const jobOf = (id) => job(String(id).replace(/^[a-z0-9]+:/, ''));
const jobName = (id) => C.DB.jobs[id]?.name || job(id).name;
export function openEditor() {
  sub = null; search = '';
  window.__editorAct = ACT;
  const m = UI.modal('Character Setup', body(), { wide: true, right: UI.btn('Done', 'done', { cls: 's good' }) });
  bindInputs(m.querySelector('.body'));
}
