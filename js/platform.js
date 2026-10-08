// Desktop integration through Neutralinojs (falls back to plain browser APIs when run in a browser).
const N = () => (typeof window !== 'undefined' && window.Neutralino && window.NL_PORT) ? window.Neutralino : null;
export const isDesktop = () => !!N();
/** Web build for phones ships .m4a audio (iPhones can't play .ogg everywhere). */
export const AUDIO_EXT = (typeof window !== 'undefined' && window.PAI_AUDIO_EXT) || 'ogg';
export const isIOS = () => /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
export const isStandalone = () => window.matchMedia?.('(display-mode: standalone)').matches || navigator.standalone === true;

export async function init(onEvent) {
  const n = N(); if (!n) return;
  try { n.init(); } catch (e) { console.warn(e); }
  try {
    n.events.on('windowClose', () => onEvent('close'));
    n.events.on('trayMenuItemClicked', (ev) => onEvent('tray', ev.detail.id));
  } catch (e) { console.warn(e); }
}

// Storage: Neutralino storage (in the app folder's .storage) with localStorage fallback.
export async function load(key) {
  const n = N();
  if (n) { try { return JSON.parse(await n.storage.getData(key)); } catch { /* not saved yet */ } }
  try { const v = localStorage.getItem('pai.' + key); return v ? JSON.parse(v) : null; } catch { return null; }
}
let pending = {}; let timer = null;
export function save(key, value) {
  pending[key] = value;
  clearTimeout(timer);
  timer = setTimeout(flush, 250);
}
export let saveError = null;
function writeLocal(k, v) {
  try { localStorage.setItem('pai.' + k, JSON.stringify(v)); saveError = null; return; } catch (e) { saveError = e; }
  // Storage full: drop old chat lines first, then the photo, and try again (everything else is small).
  if (k === 'state' && v && typeof v === 'object') {
    for (const shrink of [(x) => ({ ...x, messages: (x.messages || []).slice(-60) }), (x) => ({ ...x, messages: [], profile: { ...x.profile, photo: null } })]) {
      try { localStorage.setItem('pai.' + k, JSON.stringify(shrink(v))); saveError = null; return; } catch (e) { saveError = e; }
    }
  }
  console.warn('save failed', k, saveError);
}
export async function flush() {
  const p = pending; pending = {}; clearTimeout(timer);
  for (const [k, v] of Object.entries(p)) {
    const s = JSON.stringify(v);
    writeLocal(k, v);
    const n = N(); if (n) { try { await n.storage.setData(k, s); } catch (e) { console.warn('save', e); } }
  }
}

// Save right away when the app is backgrounded or closed (phones can kill it a moment later).
if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden') flush(); });
  window.addEventListener('pagehide', () => flush());
}
/** Ask the browser to never auto-delete PAI's saved data. */
export async function persistStorage() {
  try { if (navigator.storage?.persist && !(await navigator.storage.persisted())) await navigator.storage.persist(); } catch { }
}
/** Save a text file: Save dialog on PC, the Share sheet (Save to Files / AirDrop) on phones, a download elsewhere. */
export async function saveFile(name, text, type = 'application/json') {
  const n = N();
  if (n) {
    try { const f = await n.os.showSaveDialog('Save PAI backup', { defaultPath: name, filters: [{ name: 'PAI backup', extensions: ['json'] }] }); if (f) { await n.filesystem.writeFile(f, text); return true; } return false; }
    catch (e) { console.warn(e); }
  }
  const file = new File([text], name, { type });
  if (isIOS() && navigator.canShare?.({ files: [file] })) { try { await navigator.share({ files: [file], title: name }); return true; } catch (e) { if (e.name === 'AbortError') return false; } }
  const a = document.createElement('a'); a.href = URL.createObjectURL(file); a.download = name; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000); return true;
}

export async function notify(title, body) {
  const n = N();
  if (n) { try { await n.os.showNotification(title, body); return; } catch (e) { console.warn(e); } }
  try {
    if ('Notification' in window) {
      if (Notification.permission === 'default') await Notification.requestPermission();
      if (Notification.permission !== 'granted') return;
      // Phones (and iOS home-screen apps) only allow notifications through the service worker.
      const reg = navigator.serviceWorker && await navigator.serviceWorker.getRegistration();
      if (reg?.showNotification) await reg.showNotification(title, { body, icon: 'img/icon.png', badge: 'img/icon.png', tag: title + body });
      else new Notification(title, { body, icon: 'img/icon.png', silent: true });
    }
  } catch { }
}

export async function openLink(url) {
  const n = N();
  if (n) { try { await n.os.open(url); return; } catch { } }
  window.open(url, '_blank');
}

export async function setTray(mini) {
  const n = N(); if (!n) return;
  try {
    await n.os.setTray({
      icon: '/resources/img/tray.png',
      menuItems: [
        { id: 'open', text: 'Open PAI' },
        { id: 'mini', text: mini ? 'Full window' : 'Mini mode' },
        { id: 'sep', text: '-' },
        { id: 'quit', text: 'Quit' },
      ],
    });
  } catch (e) { console.warn('tray', e); }
}
export async function hide() { const n = N(); if (n) { try { await n.window.hide(); } catch { } } }
export async function show() { const n = N(); if (n) { try { await n.window.show(); await n.window.focus(); } catch { } } }
export async function quit() { await flush(); const n = N(); if (n) { try { await n.app.exit(); } catch { } } else window.close(); }

let fullSize = null;
export async function setMini(on) {
  const n = N(); if (!n) return;
  try {
    if (on) {
      fullSize = await n.window.getSize();
      await n.window.setSize({ width: 380, height: 300, minWidth: 300, minHeight: 220 });
      await n.window.setAlwaysOnTop(true);
    } else {
      await n.window.setAlwaysOnTop(false);
      await n.window.setSize({ width: fullSize?.width || 1200, height: fullSize?.height || 800, minWidth: 380, minHeight: 560 });
      await n.window.center();
    }
  } catch (e) { console.warn('mini', e); }
}

/** Launch with Windows: a shortcut in the Startup folder (PowerShell). */
export async function setStartup(on) {
  const n = N(); if (!n || window.NL_OS !== 'Windows') return false;
  const exe = `${window.NL_PATH}\\PAI.exe`.replace(/\//g, '\\');
  const lnk = `$env:APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\PAI.lnk`;
  const ps = on
    ? `$s=(New-Object -ComObject WScript.Shell).CreateShortcut("${lnk}");$s.TargetPath='${exe}';$s.WorkingDirectory='${window.NL_PATH.replace(/\//g, '\\')}';$s.Save()`
    : `Remove-Item "${lnk}" -ErrorAction SilentlyContinue`;
  try { await n.os.execCommand(`powershell -NoProfile -WindowStyle Hidden -Command "${ps.replace(/"/g, '\\"')}"`, { background: true }); return true; }
  catch (e) { console.warn(e); return false; }
}

/**
 * HTTPS POST. Uses fetch; if the webview blocks it, falls back to Windows' built-in curl.exe.
 */
export async function postJSON(url, headers, body, signal) {
  try {
    const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body), signal });
    const text = await r.text();
    return { status: r.status, text };
  } catch (e) {
    const n = N();
    if (!n || e.name === 'AbortError') throw e;
    const dir = (await n.os.getPath('temp')).replace(/\\/g, '/');
    const reqFile = `${dir}/pai_req_${Date.now()}.json`;
    await n.filesystem.writeFile(reqFile, JSON.stringify(body));
    const hdr = Object.entries({ 'Content-Type': 'application/json', ...headers }).map(([k, v]) => `-H "${k}: ${v}"`).join(' ');
    const out = await n.os.execCommand(`curl -s -w "\\n%{http_code}" -X POST ${hdr} --data-binary "@${reqFile}" "${url}"`);
    try { await n.filesystem.remove(reqFile); } catch { }
    const lines = out.stdOut.trimEnd().split('\n');
    const status = parseInt(lines.pop(), 10) || 0;
    return { status, text: lines.join('\n') };
  }
}

/** Navigate to a URL (calendar file, Shortcuts link). Tests can intercept via window.__paiOpen. */
export function openURL(url) { (window.__paiOpen || ((u) => { window.location.href = u; }))(url); }

// ---------------------------------------------------------------- calendar export (.ics)
const icsDate = (d) => `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}T${String(d.getHours()).padStart(2, '0')}${String(d.getMinutes()).padStart(2, '0')}00`;
const icsText = (s) => String(s || '').replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/([,;])/g, '\\$1');
export function reminderICS(reminders) {
  const now = new Date(); const lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//PAI//Space Station 14 pAI//EN', 'CALSCALE:GREGORIAN'];
  for (const r of reminders) {
    const d = new Date(r.date); const end = new Date(d.getTime() + 15 * 60000);
    lines.push('BEGIN:VEVENT', `UID:${r.id}@pai`, `DTSTAMP:${icsDate(now)}`, `DTSTART:${icsDate(d)}`, `DTEND:${icsDate(end)}`,
      `SUMMARY:${icsText(r.title)}`);
    if (r.notes) lines.push(`DESCRIPTION:${icsText(r.notes)}`);
    const rule = { daily: 'DAILY', weekly: 'WEEKLY', monthly: 'MONTHLY' }[r.repeat]; if (rule) lines.push(`RRULE:FREQ=${rule}`);
    lines.push('BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${icsText(r.title)}`, 'TRIGGER:PT0M', 'END:VALARM', 'END:VEVENT');
  }
  lines.push('END:VCALENDAR');
  return lines.join('\r\n');
}
/** Hand reminders to the phone's / computer's own calendar app so it alerts even when PAI is closed. */
export async function exportToCalendar(reminders, name = 'PAI reminders') {
  const ics = reminderICS(reminders);
  if (isIOS()) {
    // Served by our service worker as a real text/calendar page: iPhone then shows its "Add to Calendar" sheet.
    if (navigator.serviceWorker?.controller) return openURL('pai-event.ics?d=' + encodeURIComponent(ics));
    return openURL('data:text/calendar;charset=utf-8,' + encodeURIComponent(ics));
  }
  const n = N();
  if (n) {
    try {
      const dir = (await n.os.getPath('temp')).replace(/\\/g, '/'); const f = `${dir}/${name.replace(/[^\w ]/g, '')}.ics`;
      await n.filesystem.writeFile(f, ics); await n.os.open(f); return;
    } catch (e) { console.warn(e); }
  }
  const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([ics], { type: 'text/calendar' }));
  a.download = name + '.ics'; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 5000);
}

/** Music lives in a "music" folder next to PAI.exe (kept outside resources.neu so downloads stay small). */
const blobCache = new Map();
export async function musicURL(file) {
  const n = N();
  if (!n) return `game/audio/${file}.${AUDIO_EXT}`;
  if (blobCache.has(file)) return blobCache.get(file);
  try {
    const buf = await n.filesystem.readBinaryFile(`${window.NL_PATH}/music/${file}.ogg`);
    const url = URL.createObjectURL(new Blob([buf], { type: 'audio/ogg' }));
    if (blobCache.size > 3) { const [k, v] = blobCache.entries().next().value; URL.revokeObjectURL(v); blobCache.delete(k); }
    blobCache.set(file, url); return url;
  } catch (e) { console.warn('music file missing', file, e); return `game/audio/${file}.${AUDIO_EXT}`; }
}
