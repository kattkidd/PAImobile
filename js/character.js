// SS14 character customisation + renderer (same layering as SS14's BaseSpeciesLayers, with displacement maps).
import { hexToRgb, rgbToHex, rgbToHsv, hsvToRgb, pick } from './util.js';

export let DB = { layers: [], species: [], markings: {}, items: {}, jobs: {}, wardrobe: {} };
let SPECIES = new Map();
export async function loadCharacters() {
  DB = await (await fetch('game/character.json')).json();
  SPECIES = new Map(DB.species.map(s => [s.id, s]));
}
export const species = (id) => SPECIES.get(id) || SPECIES.get('Human') || DB.species[0];

export const SLOT_ORDER = ['head', 'eyes', 'mask', 'ears', 'neck', 'outerClothing', 'jumpsuit', 'gloves', 'belt', 'back', 'shoes'];
export const SLOT_LABEL = { head: 'Head', eyes: 'Eyes', mask: 'Mask', ears: 'Ears', neck: 'Neck', outerClothing: 'Suit', jumpsuit: 'Jumpsuit', gloves: 'Gloves', belt: 'Belt', back: 'Back', shoes: 'Shoes' };
const CAT_LABEL = { Hair: 'Hair', FacialHair: 'Facial hair', HeadTop: 'Head (top)', HeadSide: 'Head (side)', Head: 'Head', Snout: 'Snout', SnoutCover: 'Snout cover', Chest: 'Chest', Tail: 'Tail', Overlay: 'Overlay', UndergarmentTop: 'Undershirt', UndergarmentBottom: 'Underwear', LArm: 'Left arm', LeftArm: 'Left arm', RArm: 'Right arm', RightArm: 'Right arm', LHand: 'Left hand', LeftHand: 'Left hand', RHand: 'Right hand', RightHand: 'Right hand', LLeg: 'Left leg', LeftLeg: 'Left leg', RLeg: 'Right leg', RightLeg: 'Right leg', LFoot: 'Left foot', LeftFoot: 'Left foot', RFoot: 'Right foot', RightFoot: 'Right foot', Eyes: 'Eyes', OverEyes: 'Over eyes', Wings: 'Wings', Face: 'Face', Special: 'Special' };
export const catLabel = (c) => CAT_LABEL[c] || c.replace(/([a-z])([A-Z])/g, '$1 $2');
export const CAT_ORDER = ['Hair', 'FacialHair', 'HeadTop', 'HeadSide', 'Head', 'Face', 'Snout', 'SnoutCover', 'Eyes', 'OverEyes', 'Chest', 'Wings', 'Tail', 'Overlay', 'UndergarmentTop', 'UndergarmentBottom', 'LArm', 'LeftArm', 'RArm', 'RightArm', 'LHand', 'LeftHand', 'RHand', 'RightHand', 'LLeg', 'LeftLeg', 'RLeg', 'RightLeg', 'LFoot', 'LeftFoot', 'RFoot', 'RightFoot', 'Special'];

export function markingsFor(sp, cat, sex) {
  return sp.markings.map(id => DB.markings[id]).filter(m => m && m.cat === cat && (!m.sex || m.sex === sex))
    .sort((a, b) => a.name.localeCompare(b.name));
}
export const limit = (sp, cat) => sp.limits.find(l => l.cat === cat);
export const heightRange = (sp) => [sp.size.minHeight ?? 0.9, sp.size.maxHeight ?? 1.1];
export const widthRange = (sp) => [sp.size.minWidth ?? 0.9, sp.size.maxWidth ?? 1.1];

// --- SS14 skin colourations (SkinColorationPrototype.cs)
export function humanTone(tone) {
  const t = Math.max(0, Math.min(100, tone)); const o = t - 20;
  let h = 25, s = 20, v = 100; if (o <= 0) h += Math.abs(o); else { s += o; v -= o; }
  return rgbToHex(...hsvToRgb(h / 360, s / 100, v / 100));
}
export function clampSkin(hex, mode) {
  let [h, s, v] = rgbToHsv(...hexToRgb(hex));
  if (mode === 'hue') v = Math.max(0.175, v);
  else if (mode === 'tinted') { s = Math.min(0.1, s); v = Math.max(0.85, v); }
  else if (mode === 'fixed') return '#FFFFFF';
  return rgbToHex(...hsvToRgb(h, s, v));
}
const tattoo = (skin) => { const [h, s] = rgbToHsv(...hexToRgb(skin)); return rgbToHex(...hsvToRgb(h, s, 0.4)); };

// --- profile helpers
export function newCharacter() {
  return { species: 'Human', sex: 'Male', skin: humanTone(20), skinTone: 20, eyes: '#5A3A22', hair: '#4E3628', facialHair: '#4E3628',
    markings: [], outfitJob: null, loadout: {}, wardrobe: {}, showClothes: true, height: 1, width: 1, voice: null };
}
export function starter() {
  const c = newCharacter(); const sp = species(c.species);
  const hairs = markingsFor(sp, 'Hair', c.sex);
  const h = hairs.find(m => m.name.toLowerCase() === 'short hair') || hairs.find(m => /short/i.test(m.name)) || hairs[0];
  if (h) add(c, h);
  applyDefaults(c);
  return c;
}
export function resolve(c, rules) {
  for (const rule of rules) {
    const neg = rule.startsWith('neg:'); const r = neg ? rule.slice(4) : rule;
    let out = null;
    if (r === 'none') out = '#FFFFFF';
    else if (r === 'skin') out = c.skin;
    else if (r === 'eyes') out = c.eyes;
    else if (r === 'tattoo') out = tattoo(c.skin);
    else if (r.startsWith('cat:')) {
      const cat = r.slice(4); const pk = c.markings.find(p => DB.markings[p.id]?.cat === cat);
      if (pk) out = cat === 'Hair' ? c.hair : cat === 'FacialHair' ? c.facialHair : pk.colors[0];
    } else if (r.startsWith('#')) out = r;
    if (out) { if (neg) { const [a, b, d] = hexToRgb(out); out = rgbToHex(1 - a, 1 - b, 1 - d); } return out; }
  }
  return '#FFFFFF';
}
export function defaultColors(c, m) {
  if (m.cat === 'Hair') return m.sprites.map(() => c.hair);
  if (m.cat === 'FacialHair') return m.sprites.map(() => c.facialHair);
  return m.sprites.map((_, i) => resolve(c, m.colors[i] || ['skin']));
}
export const picks = (c, cat) => c.markings.filter(p => DB.markings[p.id]?.cat === cat);
export function add(c, m) {
  const sp = species(c.species); const lim = limit(sp, m.cat); if (!lim) return;
  const cur = picks(c, m.cat);
  if (cur.length >= lim.limit && cur.length) c.markings = c.markings.filter(p => p !== cur[0]);
  c.markings.push({ id: m.id, colors: defaultColors(c, m) });
}
export function remove(c, id) { c.markings = c.markings.filter(p => p.id !== id); }
export function applyDefaults(c) {
  const sp = species(c.species);
  for (const lim of sp.limits) if (lim.required && !picks(c, lim.cat).length) for (const d of lim.defaults) if (DB.markings[d]) add(c, DB.markings[d]);
}
export function changeSpecies(c, id) {
  const sp = SPECIES.get(id); if (!sp) return;
  c.species = id;
  if (!sp.sexes.includes(c.sex)) c.sex = sp.sexes[0] || 'Male';
  c.skin = sp.skin.mode === 'human' ? humanTone(c.skinTone) : sp.skin.default;
  c.markings = c.markings.filter(p => sp.markings.includes(p.id));
  applyDefaults(c);
  const [h0, h1] = heightRange(sp), [w0, w1] = widthRange(sp);
  c.height = Math.min(Math.max(c.height, h0), h1); c.width = Math.min(Math.max(c.width, w0), w1);
  c.voice = null;
}
export function refreshColors(c, oldSkin) {
  c.markings = c.markings.map(p => {
    const m = DB.markings[p.id]; if (!m) return p;
    if (m.cat === 'Hair') return { ...p, colors: p.colors.map(() => c.hair) };
    if (m.cat === 'FacialHair') return { ...p, colors: p.colors.map(() => c.facialHair) };
    if (!oldSkin) return p;
    return { ...p, colors: p.colors.map((col, i) => (col === oldSkin || m.colors[i]?.[0] === 'tattoo') && m.colors[i] ? resolve(c, m.colors[i]) : col) };
  });
}
export function randomize(c) {
  const sp = species(c.species);
  c.sex = pick(sp.sexes);
  if (sp.skin.mode === 'human') { c.skinTone = Math.random() * 100; c.skin = humanTone(c.skinTone); }
  else if (sp.skin.mode !== 'fixed') c.skin = clampSkin(rgbToHex(Math.random(), Math.random(), Math.random()), sp.skin.mode);
  c.hair = pick(['#2B1B12', '#4E3628', '#7A4E2D', '#B5875A', '#D9C08C', '#1A1A1A', '#8C2F1B', '#C9C9C9']); c.facialHair = c.hair;
  c.eyes = pick(['#5A3A22', '#3B6E8F', '#4A7A3A', '#7A6A3A', '#2E2E2E', '#8F3B3B']);
  c.markings = [];
  for (const lim of sp.limits) {
    const opts = markingsFor(sp, lim.cat, c.sex);
    if (lim.required) { const m = pick(opts) || DB.markings[lim.defaults[0]]; if (m) add(c, m); }
    else if (lim.cat === 'Hair' || lim.cat === 'FacialHair') {
      if (lim.cat === 'FacialHair' && (c.sex === 'Female' || Math.random() < .5)) continue;
      const m = pick(opts); if (m) add(c, m);
    }
  }
  const [h0, h1] = heightRange(sp), [w0, w1] = widthRange(sp);
  c.height = h0 + Math.random() * (h1 - h0); c.width = w0 + Math.random() * (w1 - w0);
}
export function outfit(c, idJob) {
  if (!c.showClothes) return {};
  const j = DB.jobs[c.outfitJob || idJob] || DB.jobs.Passenger;
  const out = { ...(j?.base || {}) };
  for (const g of j?.groups || []) {
    // Like SS14's RoleLoadout: optional groups (minLimit 0) start empty, required ones use their first option.
    const ch = c.loadout[g.id]; if (ch === 'none' || (!ch && g.min === 0)) continue;
    const o = g.options.find(x => x.id === ch) || g.options[0]; if (o) Object.assign(out, o.items);
  }
  for (const [slot, it] of Object.entries(c.wardrobe)) { if (it === 'none') delete out[slot]; else if (DB.items[it]) out[slot] = it; }
  return out;
}

// --- renderer
const strips = new Map(); const pendingStrips = new Map();
function loadStrip(key) {
  if (strips.has(key)) return Promise.resolve(strips.get(key));
  if (!pendingStrips.has(key)) pendingStrips.set(key, new Promise((res) => {
    const img = new Image();
    img.onload = () => {
      const cv = document.createElement('canvas'); cv.width = 128; cv.height = 32;
      const g = cv.getContext('2d', { willReadFrequently: true }); g.drawImage(img, 0, 0);
      const d = g.getImageData(0, 0, 128, 32).data; strips.set(key, d); res(d);
    };
    img.onerror = () => { strips.set(key, null); res(null); };
    img.src = `game/sprites/${key}.png`;
  }));
  return pendingStrips.get(key);
}

function plan(c, idJob, only) {
  const sp = species(c.species); const fit = outfit(c, idJob); const steps = [];
  for (const layer of DB.layers) {
    if (only && !only.has(layer)) continue;
    if (layer.startsWith('slot:')) {
      const slot = layer.slice(5); const it = DB.items[fit[slot]]; if (!it) continue;
      if (sp.clothingSuffix && it.species[sp.clothingSuffix]) { steps.push([it.species[sp.clothingSuffix], '#FFFFFF', null, 1]); continue; }
      const disp = (c.sex === 'Female' && sp.displaceFemale[slot]) || (c.sex === 'Male' && sp.displaceMale[slot]) || sp.displace[slot] || null;
      for (const l of it.layers) steps.push([l.sprite, l.color || '#FFFFFF', disp, 1]);
      continue;
    }
    for (const p of sp.parts) if (p.layer === layer) steps.push([(p.bySex && p.bySex[c.sex]) || p.sprite, p.color === 'none' ? '#FFFFFF' : c.skin, sp.bodyDisplace, p.alpha ?? 1]);
    if (sp.eyes && sp.eyes.layer === layer) steps.push([(sp.eyes.bySex && sp.eyes.bySex[c.sex]) || sp.eyes.sprite, c.eyes, sp.bodyDisplace, 1]);
    const app = sp.appearances[layer];
    for (const pk of c.markings) {
      const m = DB.markings[pk.id]; if (!m || m.layer !== layer) continue;
      m.sprites.forEach((k, i) => steps.push([k, app?.matchSkin ? c.skin : (pk.colors[i] || pk.colors[pk.colors.length - 1] || '#FFFFFF'), sp.bodyDisplace, app?.alpha ?? 1]));
    }
  }
  return steps.filter(s => s[0]);
}

const rendered = new Map();
/** Renders a character to a data URL (32×32, one of 4 directions: 0 S, 1 N, 2 E, 3 W). */
export async function render(c, idJob, dir = 0, only = null) {
  const key = JSON.stringify([c, idJob, dir, only ? [...only] : 0]);
  if (rendered.has(key)) return rendered.get(key);
  const steps = plan(c, idJob, only);
  await Promise.all(steps.flatMap(s => [loadStrip(s[0]), s[2] ? loadStrip(s[2]) : null]));
  const out = new Float32Array(32 * 32 * 4); const x0 = dir * 32;
  for (const [key2, hex, disp, alpha] of steps) {
    const s = strips.get(key2); if (!s) continue;
    const dm = disp ? strips.get(disp) : null; const [tr, tg, tb] = hexToRgb(hex);
    for (let y = 0; y < 32; y++) for (let x = 0; x < 32; x++) {
      let sx = x, sy = y, k = 1;
      if (dm) {
        const di = (y * 128 + x0 + x) * 4; const da = dm[di + 3];
        if (!da) continue;
        sx = x + dm[di] - 128; sy = y + dm[di + 1] - 128; k = da / 255;
        if (sx < 0 || sx > 31 || sy < 0 || sy > 31) continue;
      }
      const si = (sy * 128 + x0 + sx) * 4; const a = s[si + 3] / 255 * alpha * k;
      if (a <= 0) continue;
      const oi = (y * 32 + x) * 4; const da2 = out[oi + 3]; const oa = a + da2 * (1 - a);
      for (let ch = 0; ch < 3; ch++) {
        const src = s[si + ch] / 255 * [tr, tg, tb][ch];
        out[oi + ch] = (src * a + out[oi + ch] * da2 * (1 - a)) / oa;
      }
      out[oi + 3] = oa;
    }
  }
  const cv = document.createElement('canvas'); cv.width = 32; cv.height = 32;
  const g = cv.getContext('2d'); const id = g.createImageData(32, 32);
  for (let i = 0; i < out.length; i++) id.data[i] = Math.round(out[i] * 255) * (i % 4 === 3 ? 1 : 1);
  g.putImageData(id, 0, 0);
  const url = cv.toDataURL();
  if (rendered.size > 1500) rendered.clear();
  rendered.set(key, url);
  return url;
}

/** <img> placeholder filled in asynchronously. */
let seq = 0;
export function img(c, idJob, dir = 0, opts = {}) {
  const id = 'ch' + (++seq);
  const style = `transform:scale(${c.width ?? 1},${c.height ?? 1});${opts.style || ''}`;
  render(c, idJob, dir, opts.only || null).then(url => { const el = document.getElementById(id); if (el) el.src = url; });
  return `<img id="${id}" class="charimg ${opts.cls || ''}" style="${style}" alt="">`;
}
export function stripIcon(key, tint) {
  if (!key) return '';
  const id = 'si' + (++seq);
  loadStrip(key).then(d => {
    const el = document.getElementById(id); if (!el || !d) return;
    const cv = document.createElement('canvas'); cv.width = 32; cv.height = 32; const g = cv.getContext('2d'); const im = g.createImageData(32, 32);
    const [r, gg, b] = hexToRgb(tint || '#FFFFFF');
    for (let y = 0; y < 32; y++) for (let x = 0; x < 32; x++) { const si = (y * 128 + x) * 4, oi = (y * 32 + x) * 4; im.data[oi] = d[si] * r; im.data[oi + 1] = d[si + 1] * gg; im.data[oi + 2] = d[si + 2] * b; im.data[oi + 3] = d[si + 3]; }
    g.putImageData(im, 0, 0); el.src = cv.toDataURL();
  });
  return `<img id="${id}" class="px" style="width:100%;height:100%" alt="">`;
}
