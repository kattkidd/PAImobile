// Import a character exported from the SS14 lobby (Starlight / Goob / vanilla .yml profile export).
import { state, commit } from './store.js';
import * as C from './character.js';
import * as A from './audio.js';
import * as UI from './ui.js';
import { animate, popup } from './actions.js';
import { ALL_JOBS } from './ss14.js';
import { esc } from './util.js';

// ---------------------------------------------------------------- tiny YAML reader (the subset SS14 writes)
function scalar(v) {
  v = v.trim();
  if (v.startsWith("'")) return v.slice(1, v.lastIndexOf("'")).replace(/''/g, "'");
  if (v.startsWith('"')) { try { return JSON.parse(v); } catch { return v.slice(1, -1); } }
  if (v === '[]') return []; if (v === '{}') return {};
  if (v === 'null' || v === '~' || v === '') return null;
  if (/^(true|True|TRUE)$/.test(v)) return true;
  if (/^(false|False|FALSE)$/.test(v)) return false;
  if (/^-?\d+(\.\d+)?$/.test(v)) return Number(v);
  return v.replace(/\s+#.*$/, '');
}
const KEY = /^("[^"]*"|'[^']*'|[^'"\s-][^:]*?|-[^\s][^:]*?):(?:\s+(.*))?$/;
export function parseYAML(src) {
  const lines = src.replace(/^﻿/, '').split(/\r?\n/).map(l => l.replace(/\t/g, '  '))
    .filter(l => { const t = l.trim(); return t && !t.startsWith('#') && t !== '...' && t !== '---'; })
    .map(l => ({ ind: l.length - l.trimStart().length, t: l.trim() }));
  let i = 0;
  const isItem = (t) => t === '-' || t.startsWith('- ');
  function block(ind) {
    if (isItem(lines[i].t)) {
      const arr = [];
      while (i < lines.length && lines[i].ind === ind && isItem(lines[i].t)) {
        const rest = lines[i].t.slice(1).trim();
        if (!rest) { i++; arr.push(i < lines.length && lines[i].ind > ind ? block(lines[i].ind) : null); }
        else if (KEY.test(rest)) { lines[i] = { ind: ind + 2, t: rest }; arr.push(block(ind + 2)); }
        else { arr.push(scalar(rest)); i++; }
      }
      return arr;
    }
    const obj = {};
    while (i < lines.length && lines[i].ind === ind && !isItem(lines[i].t)) {
      const m = lines[i].t.match(KEY); i++;
      if (!m) continue;
      const k = scalar(m[1]); const v = m[2];
      if (v === undefined || v === '') {
        obj[k] = (i < lines.length && (lines[i].ind > ind || (lines[i].ind === ind && isItem(lines[i].t)))) ? block(lines[i].ind) : null;
      } else obj[k] = scalar(v);
    }
    return obj;
  }
  return lines.length ? block(lines[0].ind) : {};
}

// ---------------------------------------------------------------- mapping onto PAI's character
const hex = (c) => typeof c === 'string' && /^#[0-9a-f]{6}/i.test(c) ? c.slice(0, 7).toUpperCase() : null;
const PREFIXES = ['', 'starlight:', 'goob:', 'n14:'];
function findIn(table, id, fork) {
  if (!id) return null;
  const order = fork ? [`${fork}:`, ...PREFIXES] : PREFIXES;
  for (const p of order) if (table(p + id)) return table(p + id);
  return null;
}
const findSpecies = (id, fork) => findIn((k) => C.DB.species.find(s => s.id === k), id, fork);
const findMarking = (id, fork) => findIn((k) => C.DB.markings[k], id, fork);
const PRONOUNS = { Male: 'he/him', Female: 'she/her', Epicene: 'they/them', Neuter: 'it/its' };

export function importProfile(text) {
  const doc = parseYAML(text);
  const p = doc.profile || doc;
  if (!p || !p.appearance || !p.species) throw new Error("That doesn't look like an SS14 character file (no species/appearance found).");
  const fork = (doc.forkId || '').toLowerCase().replace(/[^a-z0-9]/g, '') || null;
  const ap = p.appearance; const skipped = []; const notes = [];

  const sp = findSpecies(p.species, fork);
  if (!sp) throw new Error(`Species "${p.species}" isn't in PAI's character data.`);
  const c = C.newCharacter();
  C.changeSpecies(c, sp.id);
  if (sp.sexes.includes(p.sex)) c.sex = p.sex;
  c.markings = [];
  c.skin = hex(ap.skinColor) || c.skin;
  c.eyes = hex(ap.eyeColor) || c.eyes;
  c.hair = hex(ap.hairColor) || c.hair;
  c.facialHair = hex(ap.facialHairColor) || c.facialHair;

  const place = (id, colors) => {
    const m = findMarking(id, fork);
    if (!m) { skipped.push(id); return; }
    if (!C.limit(sp, m.cat) && !sp.markings.includes(m.id)) { notes.push(`${m.name} (the ${sp.name} can't wear it in-game either)`); return; }
    if (C.limit(sp, m.cat)) C.add(c, m); else c.markings.push({ id: m.id, colors: [] });
    const pk = c.markings.find(x => x.id === m.id); if (!pk) { notes.push(`${m.name} (no room for it on this species)`); return; }
    const n = Math.max(m.colors.length, m.sprites.length, 1);
    pk.colors = Array.from({ length: n }, (_, k) => colors[k] || colors[colors.length - 1] || pk.colors[k] || c.skin);
  };
  if (ap.hair && !/bald/i.test(ap.hair)) place(ap.hair, [c.hair]);
  if (ap.facialHair && !/shaved/i.test(ap.facialHair)) place(ap.facialHair, [c.facialHair]);
  for (const mk of ap.markings || []) place(mk.markingId, (mk.markingColor || []).map(hex).filter(Boolean));
  C.applyDefaults(c);
  if (typeof ap.height === 'number') c.height = Math.min(Math.max(ap.height, 0.5), 1.5);
  if (typeof ap.width === 'number') c.width = Math.min(Math.max(ap.width, 0.5), 1.5);

  // Job + loadout: first preferred job PAI knows, using that job's saved loadout from the file.
  const loadouts = p._loadouts || {};
  const wanted = [...(p._jobPreferences || []), ...Object.keys(loadouts).map(k => k.replace(/^Job/, ''))];
  const jobKey = (j) => [fork && `${fork}:${j}`, j].find(k => k && C.DB.jobs[k]);
  const jobId = wanted.find(j => jobKey(j));
  const LO = C.DB.loadouts || {};
  if (jobId) {
    const key = jobKey(jobId); c.outfitJob = key;
    const sel = loadouts['Job' + jobId]?.selectedLoadouts || {};
    const groups = C.DB.jobs[key].groups || [];
    for (const [gid, pick] of Object.entries(sel)) {
      const g = groups.find(x => x.id === gid);
      if (!Array.isArray(pick) || !pick.length) { if (g && g.min === 0) c.loadout[gid] = 'none'; continue; }
      const proto = pick[0]?.prototype; if (!proto) continue;
      if (g?.options.find(o => o.id === proto)) { c.loadout[gid] = proto; continue; }
      // Not in the group list (fork-specific or newer option): dress the items directly.
      const its = (fork && LO[fork]?.[proto]) || LO.ss14?.[proto] || LO.starlight?.[proto] || LO.goob?.[proto];
      if (its) for (const [slot, it] of Object.entries(its)) { if (C.DB.items[it]) c.wardrobe[slot] = it; }
      else if (g) skipped.push(proto);
    }
  }
  const unknownJobs = (p._jobPreferences || []).filter(j => !jobKey(j));

  c.bio = {
    name: p.name || '', age: p.age ?? null, gender: p.gender || '', fork: doc.forkId || '',
    flavor: p.flavorText || p.physicalDescription || '', personality: p.personalityDescription || '',
    traits: (p._traitPreferences || []).map(t => t.replace(/([a-z])([A-Z])/g, '$1 $2')),
  };
  return { character: c, name: p.name || '', pronouns: PRONOUNS[p.gender] || '', jobId, unknownJobs, skipped, notes, species: sp };
}

// ---------------------------------------------------------------- UI glue
export function applyImport(r) {
  const prof = state.profile;
  prof.character = r.character;
  if (r.name) { prof.fullName = r.name; prof.preferredName = r.name.replace(/^#\S*\s*/, '').split(/\s+/)[0] || r.name; }
  if (r.pronouns) prof.pronouns = r.pronouns;
  if (r.jobId && ALL_JOBS.find(j => j.id === r.jobId)) prof.stationJob = r.jobId;
  prof.showPhoto = false;
  A.sfx('id_insert'); commit('profile');
  setTimeout(() => animate('character', 'spin'), 300);
  popup(`Imported ${r.name || 'character'}`, '#2CDB2C');
  const lines = [
    `<b>${esc(r.name || 'Unnamed')}</b>, ${esc(r.species.name)}${r.character.bio.age != null ? `, age ${r.character.bio.age}` : ''}`,
    `${r.character.markings.length} markings · height ${r.character.height.toFixed(2)} · width ${r.character.width.toFixed(2)}`,
    r.jobId ? `Outfit: ${esc(C.DB.jobs[r.character.outfitJob]?.name || r.jobId)} loadout (${Object.keys(C.outfit(r.character, r.jobId)).length} items)` : 'No job PAI knows. Wearing the Passenger outfit.',
  ];
  if (r.unknownJobs.length) lines.push(`<span class="dim">Jobs PAI doesn't have: ${esc(r.unknownJobs.join(', '))}</span>`);
  if (r.notes.length) lines.push(`<span class="dim">Hidden like in-game: ${esc(r.notes.join(', '))}</span>`);
  if (r.skipped.length) lines.push(`<span class="dim">Couldn't find: ${esc([...new Set(r.skipped)].join(', '))}</span>`);
  UI.modal('Character imported', `<div style="padding:14px;display:flex;gap:16px;align-items:center">
    <div class="floor" style="width:128px;height:128px;flex:none">${C.img(r.character, state.profile.stationJob, 0)}</div>
    <div class="col" style="gap:6px">${lines.map(l => `<div>${l}</div>`).join('')}
    <div class="small dis">Your ID name, pronouns and station job were updated too. Change anything on the ID tab or in Edit character.</div>
    <div>${UI.btn('Done', 'closeModal', { cls: 'good' })}</div></div></div>`);
}

document.addEventListener('change', (e) => {
  if (e.target?.id !== 'charimport') return;
  const f = e.target.files?.[0]; e.target.value = ''; if (!f) return;
  const rd = new FileReader();
  rd.onload = () => {
    try { applyImport(importProfile(String(rd.result))); }
    catch (err) { A.sfx('deny'); UI.modal('Import failed', `<div style="padding:14px">${esc(err.message || String(err))}</div>`); }
  };
  rd.readAsText(f);
});

export const importButton = (label = 'Import SS14 file') =>
  `<label class="btn ghost" style="cursor:pointer" title="Load a character exported from the SS14 lobby (Starlight, Goob, vanilla)">${label}<input type="file" id="charimport" style="display:none"></label>`;
