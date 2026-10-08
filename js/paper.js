// SS14 paperwork: papers rendered on the in-game paper texture, rubber stamps, export as an image.
import { state, commit } from './store.js';
import * as A from './audio.js';
import * as UI from './ui.js';
import * as P from './platform.js';
import { esc, uuid, fmtDateTime } from './util.js';

// Stamp sprites from SS14's stamps.rsi; colours follow the in-game stamp colours.
export const STAMPS = {
  ok: ['APPROVED', '#00be00'], deny: ['DENIED', '#a23e3e'], cap: ["Captain's stamp", '#3681bb'], centcom: 'CentComm|#006600'.split('|'),
  hop: ['Head of Personnel', '#6ec0ea'], hos: ['Head of Security', '#cc0000'], cmo: ['Chief Medical Officer', '#33ccff'],
  ce: ['Chief Engineer', '#c69b17'], rd: ['Research Director', '#1f66a0'], qm: ['Quartermaster', '#a23e3e'], warden: ['Warden', '#5b0000'],
  detective: ['Detective', '#c1bb8b'], lawyer: ['Lawyer', '#6f6a00'], chaplain: ['Chaplain', '#d70601'], clown: ['HONK!', '#ff33cc'],
  mime: ['...', '#777777'], syndicate: ['Syndicate', '#850000'], greytide: ['Greytide Worldwide', '#828282'],
};
export const PAPER_TYPES = ['Memo', 'Report', 'Form', 'Permit', 'Certificate', 'Letter', 'Note', 'Invoice', 'Warrant'];

/** Very small markup: # heading, **bold**, *italic*, - list, blank line = paragraph. Same spirit as SS14's paper tags. */
export function paperHTML(text) {
  const inline = (t) => esc(t).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>').replace(/\*(.+?)\*/g, '<i>$1</i>').replace(/\[bold\](.+?)\[\/bold\]/gi, '<b>$1</b>').replace(/\[italic\](.+?)\[\/italic\]/gi, '<i>$1</i>');
  const out = []; let list = false;
  for (const raw of String(text || '').split('\n')) {
    const line = raw.trimEnd();
    if (/^\s*[-*•]\s+/.test(line)) { if (!list) { out.push('<ul>'); list = true; } out.push(`<li>${inline(line.replace(/^\s*[-*•]\s+/, ''))}</li>`); continue; }
    if (list) { out.push('</ul>'); list = false; }
    const h = line.match(/^(#{1,3})\s+(.*)$/) || line.match(/^\[head=(\d)\](.*?)\[\/head\]$/i);
    if (h) { const n = typeof h[1] === 'string' && h[1].startsWith('#') ? h[1].length : +h[1]; out.push(`<div class="ph${n}">${inline(h[2])}</div>`); continue; }
    out.push(line.trim() ? `<div>${inline(line)}</div>` : '<div class="pgap"></div>');
  }
  if (list) out.push('</ul>');
  return out.join('');
}

export function paperCard(p, { big = true } = {}) {
  const stamps = (p.stamps || []).map((s, i) => {
    const [label, col] = STAMPS[s.id] || ['STAMPED', '#555'];
    return `<div class="pstamp" style="--sc:${col};transform:rotate(${s.r ?? (i % 2 ? 6 : -5)}deg)"><img src="game/events/stamp-${s.id}.png" class="px">${esc(label)}</div>`;
  }).join('');
  return `<div class="paper ${big ? '' : 'small'}">
    <div class="ptitle">${esc(p.title || 'Paper')}</div>
    <div class="pbody">${paperHTML(p.body)}</div>
    <div class="pfoot">${esc(p.author || 'Written by your pAI')} · ${esc(fmtDateTime(new Date(p.date)))}</div>
    ${stamps ? `<div class="pstamps">${stamps}</div>` : ''}</div>`;
}

export function addPaper({ title, body, stamp, author }) {
  const p = { id: uuid(), title: title || 'Paper', body: body || '', stamps: [], date: Date.now(), author: author || '' };
  if (stamp && STAMPS[stamp]) p.stamps.push({ id: stamp, r: Math.round(Math.random() * 14 - 7) });
  state.papers.unshift(p); A.play('ev_scribble1'); commit('papers');
  return p;
}
export function stampPaper(id, stamp) {
  const p = state.papers.find(x => x.id === id); if (!p || !STAMPS[stamp]) return;
  p.stamps = (p.stamps || []).filter(s => s.id !== stamp); p.stamps.push({ id: stamp, r: Math.round(Math.random() * 14 - 7) });
  A.play('ev_stamp'); commit('papers', true);
}

export function openPaper(id) {
  const p = state.papers.find(x => x.id === id); if (!p) return;
  A.play('ev_scribble2', 0.6);
  UI.modal(p.title || 'Paper', `<div class="paperwrap" id="paperwrap">${paperCard(p)}</div>
    <div class="row-flex" style="padding:10px;flex-wrap:wrap;gap:6px">
      ${UI.btn('Stamp', 'paperStampMenu', { cls: 's good', data: `data-id="${p.id}"` })}${UI.btn('Edit', 'paperEdit', { cls: 's', data: `data-id="${p.id}"` })}
      ${UI.btn('Save image', 'paperImage', { cls: 's', data: `data-id="${p.id}"` })}<span class="grow"></span>${UI.btn('Shred', 'paperDelete', { cls: 's caution', data: `data-id="${p.id}"` })}</div>`, { wide: false });
}
export function editPaper(id) {
  const p = id ? state.papers.find(x => x.id === id) : null;
  UI.modal(p ? 'Edit paper' : 'New paper', `<div style="padding:14px" class="col">
    <div class="srow"><span class="lab">Title</span><input class="field" id="pp_title" value="${esc(p?.title || '')}" placeholder="Shift report"></div>
    <div class="srow alt" style="display:block"><textarea class="field" id="pp_body" rows="12" style="width:100%;font-family:var(--mono, monospace)" placeholder="# Heading&#10;Write here. **bold**, *italic*, - lists">${esc(p?.body || '')}</textarea></div>
    <div class="row-flex"><span class="small dim grow">Tip: ask your pAI “write me a permit to keep a pet carp”.</span>${UI.btn('Cancel', 'closeModal', { cls: 'ghost' })}${UI.btn('Save', 'paperSave', { cls: 'good', data: p ? `data-id="${p.id}"` : '' })}</div></div>`);
}

/** Draws the paper onto a canvas (for sharing / saving as PNG). */
export async function paperPNG(p) {
  const W = 800, pad = 56, lh = 26; const cv = document.createElement('canvas'); const g = cv.getContext('2d');
  const lines = [];
  g.font = '18px Noto, sans-serif';
  const wrap = (t, font) => { g.font = font; const words = t.split(/\s+/); let cur = ''; const out = []; for (const w of words) { const nx = cur ? cur + ' ' + w : w; if (g.measureText(nx).width > W - pad * 2 && cur) { out.push(cur); cur = w; } else cur = nx; } out.push(cur); return out; };
  for (const raw of String(p.body || '').split('\n')) {
    const h = raw.match(/^(#{1,3})\s+(.*)$/); const li = raw.match(/^\s*[-*•]\s+(.*)$/);
    const clean = (t) => t.replace(/\*\*(.+?)\*\*/g, '$1').replace(/\*(.+?)\*/g, '$1');
    if (h) for (const l of wrap(clean(h[2]), 'bold 22px Noto, sans-serif')) lines.push(['bold 22px Noto, sans-serif', l]);
    else if (li) wrap('• ' + clean(li[1]), '18px Noto, sans-serif').forEach(l => lines.push(['18px Noto, sans-serif', l]));
    else if (!raw.trim()) lines.push(['18px Noto, sans-serif', '']);
    else wrap(clean(raw), '18px Noto, sans-serif').forEach(l => lines.push(['18px Noto, sans-serif', l]));
  }
  const stampsH = (p.stamps || []).length ? 110 : 0;
  cv.width = W; cv.height = pad * 2 + 50 + lines.length * lh + 40 + stampsH;
  g.fillStyle = '#ece6d4'; g.fillRect(0, 0, cv.width, cv.height);
  g.strokeStyle = '#b8ad8f'; g.lineWidth = 3; g.strokeRect(8, 8, cv.width - 16, cv.height - 16);
  g.fillStyle = '#1a1a1a'; g.font = 'bold 28px Noto, sans-serif'; g.fillText(p.title || 'Paper', pad, pad + 10);
  let y = pad + 56;
  for (const [font, l] of lines) { g.font = font; g.fillText(l, pad, y); y += lh; }
  g.font = '14px Noto, sans-serif'; g.fillStyle = '#6b6352'; g.fillText(`${p.author || 'Written by your pAI'} · ${fmtDateTime(new Date(p.date))}`, pad, y + 14);
  let x = pad; y += 40;
  for (const s of p.stamps || []) {
    const [label, col] = STAMPS[s.id] || ['STAMPED', '#555'];
    g.save(); g.translate(x + 90, y + 40); g.rotate((s.r || -5) * Math.PI / 180);
    g.strokeStyle = col; g.lineWidth = 4; g.strokeRect(-90, -32, 180, 64); g.fillStyle = col; g.font = 'bold 18px Noto, sans-serif'; g.textAlign = 'center'; g.fillText(label.toUpperCase().slice(0, 18), 0, 7);
    g.restore(); x += 200; if (x > W - 200) { x = pad; y += 90; }
  }
  return new Promise(r => cv.toBlob(b => r(b), 'image/png'));
}
export async function savePaperImage(id) {
  const p = state.papers.find(x => x.id === id); if (!p) return;
  const blob = await paperPNG(p);
  await P.saveBlob((p.title || 'paper').replace(/[^\w -]/g, '') + '.png', blob);
  A.play('ev_scribble1');
}
