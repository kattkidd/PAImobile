// Calendar with reminders (one-off, daily, weekly, monthly).
import { state, occursOn, timeOn } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as UI from '../ui.js';
import * as P from '../platform.js';
import { esc, icon, fmtTime, pad2, sameDay } from '../util.js';

let month = new Date(); month.setDate(1);
let selected = new Date();
let slide = '';

const REPEAT = { none: 'Never', daily: 'Every day', weekly: 'Every week', monthly: 'Every month' };

function grid() {
  const first = new Date(month.getFullYear(), month.getMonth(), 1);
  const start = new Date(first); start.setDate(1 - ((first.getDay() + 6) % 7));
  const today = new Date(); let html = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map(d => `<div class="dow">${d}</div>`).join('');
  for (let i = 0; i < 42; i++) {
    const d = new Date(start); d.setDate(start.getDate() + i);
    const n = state.reminders.filter(r => occursOn(r, d)).length;
    html += `<div class="day ${d.getMonth() !== month.getMonth() ? 'out' : ''} ${sameDay(d, today) ? 'today' : ''} ${sameDay(d, selected) ? 'sel' : ''}" data-act="pick" data-d="${d.getTime()}">
      ${d.getDate()}${n ? `<div class="dots">${'<i></i>'.repeat(Math.min(n, 4))}</div>` : ''}</div>`;
  }
  return html;
}
function dayList() {
  const items = state.reminders.filter(r => occursOn(r, selected)).map(r => ({ r, t: timeOn(r, selected) })).sort((a, b) => a.t - b.t);
  if (!items.length) return `<div class="srow dim">No reminders. ${UI.btn(icon('plus', 13) + ' Add one', 'add', { cls: 's good' })}</div>`;
  return items.map(({ r, t }, i) => `<div class="srow click ${i % 2 ? 'alt' : ''}" data-act="edit" data-id="${r.id}" style="animation:lineIn .3s ${i * 0.04}s both">
    <span class="b mono" style="color:var(--accent);width:74px">${fmtTime(t)}</span>
    <div class="grow"><div>${esc(r.title)}</div>${r.notes ? `<div class="small dim">${esc(r.notes)}</div>` : ''}</div>
    ${r.repeat !== 'none' ? `<span class="tiny dim">${REPEAT[r.repeat]}</span>` : ''}
    <button class="btn s ${X.inCalendar(r) ? 'good' : ''}" data-act="ics" data-id="${r.id}" title="${X.inCalendar(r) ? 'In your Calendar app (tap to send again)' : 'Add to my phone/computer calendar'}">${icon('calendar', 13)}</button>
    <button class="btn s caution" data-act="del" data-id="${r.id}" title="Delete">${icon('trash', 13)}</button></div>`).join('');
}

function editor(r) {
  const d = r ? new Date(r.date) : new Date(selected.getFullYear(), selected.getMonth(), selected.getDate(), Math.max(9, new Date().getHours() + 1), 0);
  const ds = `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`, ts = `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
  UI.modal(r ? 'Edit reminder' : 'New reminder', `<div style="padding:14px" class="col">
    <div class="srow"><span class="lab">Title</span><input class="field" id="r_title" value="${esc(r?.title || '')}" placeholder="Take out the bins"></div>
    <div class="srow alt"><span class="lab">Date</span><input class="field" type="date" id="r_date" value="${ds}"></div>
    <div class="srow"><span class="lab">Time</span><input class="field" type="time" id="r_time" value="${ts}"></div>
    <div class="srow alt"><span class="lab">Repeat</span><select class="field" id="r_rep">${Object.entries(REPEAT).map(([k, v]) => `<option value="${k}" ${(r?.repeat || 'none') === k ? 'selected' : ''}>${v}</option>`).join('')}</select></div>
    <div class="srow"><span class="lab">Notes</span><textarea class="field" id="r_notes" placeholder="Optional">${esc(r?.notes || '')}</textarea></div>
    <div class="row-flex" style="flex-wrap:wrap">${r ? UI.btn(icon('trash', 13) + ' Delete', 'delInModal', { cls: 'caution', data: `data-id="${r.id}"` }) + UI.btn(icon('calendar', 13) + ' Add to Calendar', 'ics', { cls: 'ghost', data: `data-id="${r.id}"` }) : ''}<span class="grow"></span>${UI.btn('Cancel', 'closeModal', { cls: 'ghost' })}${UI.btn(icon('check', 14) + ' Save', 'save', { cls: 'good', data: r ? `data-id="${r.id}"` : '' })}</div>
  </div>`);
  setTimeout(() => document.getElementById('r_title')?.focus(), 50);
}

export default {
  render() {
    const sub = P.isDesktop() ? 'Reminders arrive as Windows notifications while PAI is running' : 'Tap the calendar button on a reminder to add it to your phone’s Calendar so it alerts even when PAI is closed';
    const all = state.reminders.length ? UI.btn(icon('calendar', 14) + ' All to Calendar', 'icsAll', { cls: 'ghost' }) : '';
    return `${UI.header('Calendar', sub, all + UI.btn(icon('plus', 14) + ' New', 'add', { cls: 'good' }))}
    <div class="content"><div style="display:grid;grid-template-columns:minmax(320px,1.2fr) minmax(280px,1fr);gap:16px" class="calwrap">
      <div>${UI.win(month.toLocaleDateString([], { month: 'long', year: 'numeric' }), `<div style="padding:10px"><div class="cal" style="animation:${slide ? `screenIn${slide === 'back' ? 'Back' : ''} .3s` : 'none'}">${grid()}</div></div>`,
        { right: `${UI.btn('‹', 'prevMonth', { cls: 's ghost' })}${UI.btn('Today', 'today', { cls: 's ghost' })}${UI.btn('›', 'nextMonth', { cls: 's ghost' })}` })}</div>
      <div>${UI.section(selected.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' }), dayList(), { trailing: `${state.reminders.filter(r => occursOn(r, selected)).length} reminders` })}
        <div class="foot" style="margin-top:10px">Tip: ask ${esc(X.paiName())} in chat, e.g. “remind me every Monday at 8 to water the plants”.</div></div>
    </div></div><style>@media (max-width:900px){.calwrap{grid-template-columns:1fr!important}}</style>`;
  },
  act: {
    pick(a) { selected = new Date(+a.dataset.d); if (selected.getMonth() !== month.getMonth()) { slide = selected > month ? 'fwd' : 'back'; month = new Date(selected.getFullYear(), selected.getMonth(), 1); } else slide = ''; A.sfx('hover'); this._re(); },
    prevMonth() { month = new Date(month.getFullYear(), month.getMonth() - 1, 1); slide = 'back'; this._re(); },
    nextMonth() { month = new Date(month.getFullYear(), month.getMonth() + 1, 1); slide = 'fwd'; this._re(); },
    today() { selected = new Date(); month = new Date(selected.getFullYear(), selected.getMonth(), 1); slide = ''; this._re(); },
    add() { editor(null); },
    ics(a, e) { e?.stopPropagation(); X.sendToCalendar([a.dataset.id]); },
    icsAll() { X.sendToCalendar(); },
    edit(a, e) { if (e.target.closest('[data-act="del"],[data-act="ics"]')) return; editor(state.reminders.find(r => r.id === a.dataset.id)); },
    del(a, e) { e.stopPropagation(); X.deleteReminder(a.dataset.id); },
    delInModal(a) { UI.closeModal(); X.deleteReminder(a.dataset.id); },
    save(a) {
      const title = document.getElementById('r_title').value.trim(); if (!title) { A.sfx('deny'); return; }
      const [y, mo, d] = document.getElementById('r_date').value.split('-').map(Number); const [h, mi] = document.getElementById('r_time').value.split(':').map(Number);
      const date = new Date(y, mo - 1, d, h, mi);
      const rem = X.upsertReminder({ id: a.dataset.id || undefined, title, date: date.getTime(), repeat: document.getElementById('r_rep').value, notes: document.getElementById('r_notes').value });
      selected = date; month = new Date(date.getFullYear(), date.getMonth(), 1); UI.closeModal();
      if (X.onPhone() && state.settings.calendarSync && !X.inCalendar(rem)) X.sendToCalendar([rem.id]);
    },
    _re() { import('../main.js').then(m => m.rerender()); },
  },
};
