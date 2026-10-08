// Chat add-ons: talk to PAI (speech in/out), clipboard helper, attaching / dropping files.
import { state } from './store.js';
import * as A from './audio.js';
import * as P from './platform.js';

// ---------------------------------------------------------------- attachments (images, PDFs, text files)
export const pending = [];   // {name, kind: image|pdf|text, block, size}
const MAX_PDF = 20 * 1024 * 1024, MAX_TEXT = 120000;
const TEXT_EXT = /\.(txt|md|csv|json|js|ts|py|html|css|xml|yml|yaml|log|ini|cfg|gd|cs|java|c|cpp|h|lua|sh|bat|ps1|toml|tsv)$/i;

function readAs(file, how) {
  return new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(r.result); r.onerror = () => rej(r.error); r[how](file); });
}
async function imageBlock(file) {
  // Downscale big photos (Claude reads up to ~1568px; smaller = cheaper).
  const url = URL.createObjectURL(file);
  try {
    const img = await new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = url; });
    const max = 1568, k = Math.min(1, max / Math.max(img.width, img.height));
    const cv = document.createElement('canvas'); cv.width = Math.round(img.width * k); cv.height = Math.round(img.height * k);
    cv.getContext('2d').drawImage(img, 0, 0, cv.width, cv.height);
    const data = cv.toDataURL('image/jpeg', 0.85).split(',')[1];
    return { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data } };
  } finally { URL.revokeObjectURL(url); }
}
/** Returns an error message, or null when the file was added. */
export async function addFile(file) {
  if (pending.length >= 5) return 'Up to 5 files per message.';
  const name = file.name || 'file';
  try {
    if (/^image\//.test(file.type) || /\.(png|jpe?g|gif|webp|heic|bmp)$/i.test(name)) pending.push({ name, kind: 'image', block: await imageBlock(file) });
    else if (file.type === 'application/pdf' || /\.pdf$/i.test(name)) {
      if (file.size > MAX_PDF) return `${name} is too big (PDFs up to 20 MB).`;
      const data = (await readAs(file, 'readAsDataURL')).split(',')[1];
      pending.push({ name, kind: 'pdf', block: { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data }, title: name } });
    } else if (/^text\//.test(file.type) || TEXT_EXT.test(name) || file.type === 'application/json') {
      let text = await readAs(file, 'readAsText'); if (text.length > MAX_TEXT) text = text.slice(0, MAX_TEXT) + '\n…(cut off)';
      pending.push({ name, kind: 'text', block: { type: 'text', text: `<file name="${name}">\n${text}\n</file>` } });
    } else return `PAI can read images, PDFs and text files, not ${name}.`;
    A.sfx('id_insert'); return null;
  } catch (e) { return `Couldn't read ${name}.`; }
}
export function addText(name, text) { pending.push({ name, kind: 'text', block: { type: 'text', text: `<${name}>\n${String(text).slice(0, MAX_TEXT)}\n</${name}>` } }); }
export function takePending() { return pending.splice(0); }

// ---------------------------------------------------------------- clipboard
export async function readClipboard() {
  const n = window.Neutralino && window.NL_PORT ? window.Neutralino : null;
  if (n) { try { return await n.clipboard.readText(); } catch { } }
  return navigator.clipboard.readText();
}
export async function copyText(text) {
  const n = window.Neutralino && window.NL_PORT ? window.Neutralino : null;
  if (n) { try { await n.clipboard.writeText(text); return true; } catch { } }
  try { await navigator.clipboard.writeText(text); return true; } catch { return false; }
}
export const CLIP_ACTIONS = [
  ['Summarise this', 'Summarise what I copied in a few bullet points.'],
  ['Fix grammar & spelling', 'Fix the grammar and spelling of what I copied. Reply with only the corrected text.'],
  ['Make it sound nicer', 'Rewrite what I copied so it sounds friendlier and clearer. Reply with only the new text.'],
  ['Explain it simply', 'Explain what I copied in simple terms.'],
  ['Translate to English', 'Translate what I copied into English.'],
  ['Write a reply', 'Write a short reply to the message I copied.'],
];

// ---------------------------------------------------------------- talk: speech recognition + speech synthesis
const SR = typeof window !== 'undefined' && (window.SpeechRecognition || window.webkitSpeechRecognition);
export const canListen = () => !!SR && !(P.isDesktop());   // the Windows app's webview has no speech service; Win+H dictation works there
let rec = null; export let listening = false;
export function listen({ onText, onEnd, onError }) {
  if (!SR) return onError?.('no-sr');
  stopListening();
  rec = new SR(); rec.lang = navigator.language || 'en-US'; rec.interimResults = true; rec.continuous = false;
  let final = '';
  rec.onresult = (e) => { let interim = ''; for (const r of e.results) { if (r.isFinal) final = r[0].transcript; else interim += r[0].transcript; } onText?.(final || interim, !!final); };
  rec.onerror = (e) => { listening = false; onError?.(e.error); };
  rec.onend = () => { listening = false; onEnd?.(final.trim()); };
  try { rec.start(); listening = true; A.sfx('quickbeep'); } catch (e) { listening = false; onError?.(e.message); }
}
export function stopListening() { try { rec?.stop(); } catch { } listening = false; }

export function voices() { try { return speechSynthesis.getVoices(); } catch { return []; } }
export function speak(text) {
  try {
    const clean = String(text).replace(/\*\*|[*#`_>]/g, '').replace(/\[(.*?)\]\(.*?\)/g, '$1');
    const u = new SpeechSynthesisUtterance(clean);
    const v = voices().find(x => x.name === state.settings.ttsVoice); if (v) u.voice = v;
    u.rate = state.settings.ttsRate || 1.05; u.pitch = state.settings.ttsPitch ?? 1.15;
    speechSynthesis.cancel(); speechSynthesis.speak(u);
  } catch { }
}
