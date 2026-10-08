// Notes tab (SS14 PDA "Notekeeper" style): notes, a to-do checklist and paperwork.
import { state, commit } from '../store.js';
import * as X from '../actions.js';
import * as A from '../audio.js';
import * as UI from '../ui.js';
import * as PA from '../paper.js';
import { esc, icon, uuid, relative } from '../util.js';

let tab = 'todo';
const re = () => import('../main.js').then(m => m.rerender());

function todoList() {
  const open = state.todos.filter(t => !t.done), done = state.todos.filter(t => t.done);
  const row = (t, i) => `<div class="srow ${i % 2 ? 'alt' : ''} todo ${t.done ? 'done' : ''}" style="animation:lineIn .25s ${i * 0.03}s both">
    <button class="check ${t.done ? 'on' : ''}" data-act="todoToggle" data-id="${t.id}" title="Done">${t.done ? icon('check', 14) : ''}</button>
    <span class="grow">${esc(t.text)}</span><button class="btn s ghost" data-act="todoDel" data-id="${t.id}" title="Remove">${icon('trash', 12)}</button></div>`;
  return UI.section('To-do', `<div class="srow"><input class="field" id="todo_new" placeholder="Add a task, then Enter"> ${UI.btn(icon('plus', 13), 'todoAdd', { cls: 's good' })}</div>
    ${open.map(row).join('') || `<div class="srow dim">Nothing to do. Ask ${esc(X.paiName())}: “add buy milk to my list”.</div>`}
    ${done.length ? `<div class="srow alt small dim"><span class="grow">${done.length} done</span>${UI.btn('Clear done', 'todoClear', { cls: 's ghost' })}</div>${done.map((t, i) => row(t, i + 1)).join('')}` : ''}`,
    { trailing: `${open.length} open` });
}
function noteList() {
  return UI.section('Notekeeper', `${state.notes.map((n, i) => `<div class="srow click ${i % 2 ? 'alt' : ''}" data-act="noteEdit" data-id="${n.id}" style="animation:lineIn .25s ${i * 0.03}s both">
      ${icon('note', 15)}<div class="grow" style="min-width:0"><div class="b ellipsis">${esc(n.title || 'Untitled')}</div><div class="small dim ellipsis">${esc((n.body || '').slice(0, 120))}</div></div><span class="tiny dis">${esc(relative(new Date(n.date)))}</span></div>`).join('')
      || `<div class="srow dim">No notes yet. Tap New, or tell ${esc(X.paiName())} “note that the wifi password is…”.</div>`}`,
    { trailing: `${state.notes.length} notes` });
}
function paperList() {
  return `${UI.section('Paperwork', `<div class="paperwall">${state.papers.map(p => `<div class="papertile" data-act="paperOpen" data-id="${p.id}">${PA.paperCard(p, { big: false })}</div>`).join('')
      || `<div class="srow dim" style="grid-column:1/-1">No paperwork. Ask ${esc(X.paiName())} “write me a permit to keep a pet carp, stamp it with the Captain’s stamp”.</div>`}</div>`,
    { trailing: `${state.papers.length} papers` })}`;
}

export function editNote(n) {
  UI.modal(n ? 'Edit note' : 'New note', `<div style="padding:14px" class="col">
    <input class="field" id="n_title" value="${esc(n?.title || '')}" placeholder="Title">
    <textarea class="field" id="n_body" rows="10" placeholder="Write anything…">${esc(n?.body || '')}</textarea>
    <div class="row-flex">${n ? UI.btn(icon('trash', 13) + ' Delete', 'noteDel', { cls: 'caution', data: `data-id="${n.id}"` }) : ''}<span class="grow"></span>${UI.btn('Cancel', 'closeModal', { cls: 'ghost' })}${UI.btn(icon('check', 14) + ' Save', 'noteSave', { cls: 'good', data: n ? `data-id="${n.id}"` : '' })}</div></div>`);
}

export default {
  setPage(p) { tab = p; },
  render() {
    const tabs = [['todo', 'To-do'], ['notes', 'Notes'], ['paper', 'Paperwork']].map(([id, l]) => UI.btn(l, 'ntab', { cls: 's ' + (tab === id ? 'sel' : ''), data: `data-t="${id}"` })).join('');
    const add = tab === 'notes' ? UI.btn(icon('plus', 14) + ' New', 'noteNew', { cls: 'good' }) : tab === 'paper' ? UI.btn(icon('plus', 14) + ' New paper', 'paperNew', { cls: 'good' }) : '';
    return `${UI.header('Notes', 'PDA notekeeper · to-do · paperwork', add)}<div style="background:var(--pd);padding:8px 18px;display:flex;gap:4px;flex-wrap:wrap">${tabs}</div>
      <div class="content"><div class="col" style="max-width:900px">${{ todo: todoList, notes: noteList, paper: paperList }[tab]()}</div></div>`;
  },
  mounted(root) {
    const inp = root.querySelector('#todo_new');
    inp?.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); this.act.todoAdd(); } });
  },
  act: {
    ntab(a) { tab = a.dataset.t; A.sfx('click'); re(); },
    todoAdd() { const el = document.getElementById('todo_new'); const t = el?.value.trim(); if (!t) return; X.addTodo(t); setTimeout(() => document.getElementById('todo_new')?.focus(), 30); },
    todoToggle(a) { X.toggleTodo(a.dataset.id); },
    todoDel(a) { state.todos = state.todos.filter(t => t.id !== a.dataset.id); A.sfx('pop'); commit('todos'); },
    todoClear() { state.todos = state.todos.filter(t => !t.done); A.play('ev_scribble2', 0.5); commit('todos'); },
    noteNew() { editNote(null); },
    noteEdit(a) { editNote(state.notes.find(n => n.id === a.dataset.id)); },
    noteSave(a) {
      const title = document.getElementById('n_title').value.trim(), body = document.getElementById('n_body').value;
      if (!title && !body.trim()) return A.sfx('deny');
      X.saveNote({ id: a.dataset.id || null, title, body }); UI.closeModal();
    },
    noteDel(a) { state.notes = state.notes.filter(n => n.id !== a.dataset.id); UI.closeModal(); A.sfx('pop'); commit('notes'); },
    paperNew() { PA.editPaper(null); },
    paperOpen(a) { PA.openPaper(a.dataset.id); },
    paperEdit(a) { PA.editPaper(a.dataset.id); },
    paperSave(a) {
      const title = document.getElementById('pp_title').value.trim(), body = document.getElementById('pp_body').value;
      if (a.dataset.id) { const p = state.papers.find(x => x.id === a.dataset.id); if (p) { p.title = title; p.body = body; A.play('ev_scribble1'); commit('papers'); PA.openPaper(p.id); return; } }
      const p = PA.addPaper({ title, body, author: 'Written by you' }); PA.openPaper(p.id);
    },
    paperStampMenu(a) {
      UI.menu(a, Object.entries(PA.STAMPS).map(([id, [label]]) => ({ label: `<img src="game/events/stamp-${id}.png" class="px" style="width:20px;height:20px;vertical-align:middle;margin-right:6px">${esc(label)}`, html: true, run: () => { PA.stampPaper(a.dataset.id, id); const w = document.getElementById('paperwrap'); const p = state.papers.find(x => x.id === a.dataset.id); if (w && p) { w.innerHTML = PA.paperCard(p); const s = w.querySelector('.pstamp:last-child'); s?.classList.add('anim-stamp'); } } })));
    },
    paperImage(a) { PA.savePaperImage(a.dataset.id); },
    paperDelete(a) { state.papers = state.papers.filter(p => p.id !== a.dataset.id); UI.closeModal(); A.play('ev_scribble2'); commit('papers'); },
  },
};
