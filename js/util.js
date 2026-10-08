// Small helpers shared by every module.
export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : 'id' + Math.random().toString(36).slice(2) + Date.now().toString(36));
export const sleep = (ms) => new Promise(r => setTimeout(r, ms));
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
export const cap = (s) => s ? s[0].toUpperCase() + s.slice(1) : s;

export function hexToRgb(h) {
  h = String(h || '#ffffff').replace('#', '');
  const v = parseInt(h.slice(0, 6), 16) || 0;
  return [(v >> 16 & 255) / 255, (v >> 8 & 255) / 255, (v & 255) / 255];
}
export function rgbToHex(r, g, b) {
  const t = x => Math.round(clamp(x, 0, 1) * 255).toString(16).padStart(2, '0');
  return ('#' + t(r) + t(g) + t(b)).toUpperCase();
}
export function rgbToHsv(r, g, b) {
  const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
  let h = 0;
  if (d) {
    if (max === r) h = ((g - b) / d) % 6; else if (max === g) h = (b - r) / d + 2; else h = (r - g) / d + 4;
    h /= 6; if (h < 0) h += 1;
  }
  return [h, max ? d / max : 0, max];
}
export function hsvToRgb(h, s, v) {
  const i = Math.floor(h * 6), f = h * 6 - i, p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
  return [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][((i % 6) + 6) % 6];
}

// Dates
export const pad2 = n => String(n).padStart(2, '0');
export function fmtTime(d) { return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }); }
export function fmtDate(d) { return d.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' }); }
export function fmtDateTime(d) { return d.toLocaleString([], { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' }); }
export function fmtDuration(sec) {
  const t = Math.max(0, Math.ceil(sec)); const h = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60), s = t % 60;
  return h ? `${h}:${pad2(m)}:${pad2(s)}` : `${pad2(m)}:${pad2(s)}`;
}
export function spokenDuration(sec) {
  const t = Math.round(sec); const h = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60), s = t % 60; const p = [];
  if (h) p.push(`${h} hour${h === 1 ? '' : 's'}`);
  if (m) p.push(`${m} minute${m === 1 ? '' : 's'}`);
  if (s || !p.length) p.push(`${s} second${s === 1 ? '' : 's'}`);
  return p.join(' ');
}
export function isoLocal(d) {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}
export function parseAIDate(s) {
  if (!s) return null;
  const m = String(s).trim().match(/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?/);
  if (m) return new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0));
  const d = new Date(s); return isNaN(d) ? null : d;
}
export function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
export function startOfDay(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }
export function relative(d) {
  const diff = (d - Date.now()) / 1000, a = Math.abs(diff);
  const r = new Intl.RelativeTimeFormat([], { numeric: 'auto', style: 'short' });
  if (a < 60) return r.format(Math.round(diff), 'second');
  if (a < 3600) return r.format(Math.round(diff / 60), 'minute');
  if (a < 86400) return r.format(Math.round(diff / 3600), 'hour');
  return r.format(Math.round(diff / 86400), 'day');
}

// Inline SVG icons (simple line icons)
const P = {
  cpu: 'M9 3v2M15 3v2M9 19v2M15 19v2M3 9h2M3 15h2M19 9h2M19 15h2M7 5h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2zM9 9h6v6H9z',
  calendar: 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4',
  timer: 'M12 8v5l3 2M9 2h6M12 22a8 8 0 1 0 0-16 8 8 0 0 0 0 16z',
  id: 'M3 5h18v14H3zM7 10a2 2 0 1 0 4 0 2 2 0 0 0-4 0M6 16c.6-1.6 1.8-2.4 3-2.4s2.4.8 3 2.4M14 9h5M14 13h4',
  gear: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z',
  music: 'M9 18V5l12-2v13M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM21 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z',
  mute: 'M11 5 6 9H2v6h4l5 4zM23 9l-6 6M17 9l6 6',
  send: 'M22 2 11 13M22 2l-7 20-4-9-9-4z',
  plus: 'M12 5v14M5 12h14', x: 'M18 6 6 18M6 6l12 12', check: 'M20 6 9 17l-5-5',
  play: 'M6 4l14 8-14 8z', pause: 'M6 4h4v16H6zM14 4h4v16h-4z', next: 'M5 4l10 8-10 8zM19 5v14', prev: 'M19 20 9 12l10-8zM5 19V5',
  bell: 'M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0',
  edit: 'M12 20h9M16.5 3.5a2.1 2.1 0 1 1 3 3L7 19l-4 1 1-4z', dice: 'M4 4h16v16H4zM8.5 8.5h.01M15.5 15.5h.01M15.5 8.5h.01M8.5 15.5h.01M12 12h.01',
  rotl: 'M1 4v6h6M3.5 15a9 9 0 1 0 2.1-9.4L1 10', rotr: 'M23 4v6h-6M20.5 15a9 9 0 1 1-2.1-9.4L23 10',
  mini: 'M4 14h6v6M20 10h-6V4M14 10l7-7M3 21l7-7', speaker: 'M11 5 6 9H2v6h4l5 4zM15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14',
  link: 'M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7',
  trash: 'M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14', clock: 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM12 6v6l4 2',
  stop: 'M5 5h14v14H5z', flag: 'M4 22V4M4 4h13l-2 4 2 4H4',
  note: 'M6 2h9l5 5v15H6zM14 2v6h6M9 13h8M9 17h6',
  check: 'M4 12l5 5L20 6',
  mic: 'M12 2a3 3 0 0 1 3 3v7a3 3 0 0 1-6 0V5a3 3 0 0 1 3-3zM5 11a7 7 0 0 0 14 0M12 18v4',
  clip: 'M21 11l-9 9a5 5 0 0 1-7-7l9-9a3.5 3.5 0 0 1 5 5l-9 9a2 2 0 0 1-3-3l8-8',
  paste: 'M9 3h6v3H9zM7 5H5v16h14V5h-2M9 12h6M9 16h4',
  brain: 'M9 3a3 3 0 0 0-3 3 3 3 0 0 0-2 5 3 3 0 0 0 2 5 3 3 0 0 0 6 2V3zM15 3a3 3 0 0 1 3 3 3 3 0 0 1 2 5 3 3 0 0 1-2 5 3 3 0 0 1-6 2',
  sun: 'M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10zM12 1v2M12 21v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M1 12h2M21 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4',
  bolt: 'M13 2L4 14h7l-1 8 9-12h-7z',
  skull: 'M12 2a8 8 0 0 0-8 8v4l2 2v4h12v-4l2-2v-4a8 8 0 0 0-8-8zM9 11h.01M15 11h.01M10 20v-3M14 20v-3',
  stamp: 'M9 3h6v6l3 3v3H6v-3l3-3zM5 18h14v3H5z',
  speaker2: 'M11 5L6 9H2v6h4l5 4zM15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14',
};
export function icon(name, size = 18, extra = '') {
  return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" ${extra}><path d="${P[name] || ''}"/></svg>`;
}
