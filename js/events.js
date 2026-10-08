// Station events (meteors, immovable rod, space dragon, bingles…) and antags that mess with you.
// Everything here is cosmetic and temporary: saved data is never touched (character swaps are restored).
import { state, commit } from './store.js';
import * as X from './actions.js';
import * as A from './audio.js';
import * as C from './character.js';
import * as UI from './ui.js';
import * as P from './platform.js';
import { pick, sleep } from './util.js';
import { job } from './ss14.js';

let META = null;
async function meta() { if (!META) { try { META = await (await fetch('game/events/events.json')).json(); } catch { META = { sprites: {}, sounds: {} }; } } return META; }

// ---------------------------------------------------------------- scheduling
const EVENT_GAP = { rare: [45, 75], normal: [14, 26], chaos: [2, 5] };   // minutes
const ANTAG_GAP = { rare: [90, 180], often: [20, 40] };
let nextEvent = 0, nextAntag = 0, running = null;
const rand = (a, b) => a + Math.random() * (b - a);
function busy() {
  const a = document.activeElement;
  return document.hidden || state.focus.on || document.getElementById('modal')?.classList.contains('show') || document.getElementById('boot') || document.getElementById('tapstart')
    || (a && (a.tagName === 'TEXTAREA' || a.tagName === 'INPUT') && a.value) || state.thinking || document.getElementById('app')?.style.display === 'none';
}
export function tick(now = new Date()) {
  const t = now.getTime(), s = state.settings;
  // expire antag effects
  const ef = state.antag.effect;
  if (ef && ef.until && t > ef.until) clearAntag(true);
  if (state.antag.emagged && state.antag.until && t > state.antag.until) clearAntag(true);
  if (running) return;
  if (s.events !== 'off' && EVENT_GAP[s.events]) {
    if (!nextEvent) nextEvent = t + rand(...EVENT_GAP[s.events]) * 60000;
    else if (t > nextEvent && !busy()) { nextEvent = t + rand(...EVENT_GAP[s.events]) * 60000; trigger(null); return; }
  }
  if (s.antagMode !== 'off' && ANTAG_GAP[s.antagMode]) {
    if (!nextAntag) nextAntag = t + rand(...ANTAG_GAP[s.antagMode]) * 60000;
    else if (t > nextAntag && !busy() && !state.antag.effect && !state.antag.emagged) { nextAntag = t + rand(...ANTAG_GAP[s.antagMode]) * 60000; antag(null); }
  }
}
export function resetSchedule() { nextEvent = 0; nextAntag = 0; }

// ---------------------------------------------------------------- helpers
function layer() {
  let l = document.getElementById('fxlayer');
  if (!l) { l = document.createElement('div'); l.id = 'fxlayer'; document.body.appendChild(l); }
  return l;
}
async function sprite(name, { scale = 3, cls = '', click } = {}) {
  const m = (await meta()).sprites[name] || { w: 32, h: 32, frames: 1, delay: 200 };
  const el = document.createElement('div'); el.className = 'fxsprite ' + cls;
  const w = m.w * scale, h = m.h * scale;
  Object.assign(el.style, { width: w + 'px', height: h + 'px', backgroundImage: `url(game/events/${name}.png)`, backgroundSize: `${w * m.frames}px ${h}px` });
  if (m.frames > 1) el.style.animation = `fxframes ${m.frames * m.delay}ms steps(${m.frames}) infinite`, el.style.setProperty('--fw', `-${w * m.frames}px`);
  if (click) { el.classList.add('clickable'); el.addEventListener('click', (e) => { e.stopPropagation(); click(el, e); }); }
  layer().appendChild(el); return el;
}
function fly(el, from, to, ms, ease = 'linear') {
  return el.animate([{ transform: `translate(${from[0]}px, ${from[1]}px) ${from[2] || ''}` }, { transform: `translate(${to[0]}px, ${to[1]}px) ${to[2] || ''}` }], { duration: ms, easing: ease, fill: 'forwards' }).finished.catch(() => { });
}
function sound(own) { const v = state.settings.eventSound; if (v === 'auto' || !v) A.play(own, 0.8); else A.alarm('event'); }
function bodyFx(cls, ms) { document.body.classList.add(cls); return new Promise(r => setTimeout(() => { document.body.classList.remove(cls); r(); }, ms)); }
function shake(ms = 500) { return bodyFx('fx-shake', ms); }
const W = () => innerWidth, H = () => innerHeight;
function say(text) { X.say(text, { sound: true }); }
function chatLine(title, text, kind = '') { X.announce(title, text, { kind, sign: kind === 'syndicate' ? 'Syndicate Command' : 'Central Command', banner: true }); }

// ---------------------------------------------------------------- station events
const EVENTS = {
  async meteors() {
    chatLine('Meteor Alert', 'Meteors have been detected on a collision course with the station. Brace for impact! (Tap meteors to shoot them down.)', 'alert'); sound('ev_meteors');
    await sleep(2500);
    let saved = 0, hits = 0;
    const one = async (i) => {
      await sleep(i * 650);
      const big = Math.random() < 0.3;
      const el = await sprite(big ? 'meteor_big' : 'meteor', { scale: big ? 3 : 2, click: (e) => { saved++; A.play('ev_explosion', 0.4); e.remove(); } });
      const x0 = rand(-100, W() * 0.6), x1 = x0 + rand(W() * 0.3, W() * 0.7);
      await fly(el, [x0, -120, 'rotate(0deg)'], [x1, H() + 80, `rotate(${rand(200, 700)}deg)`], rand(2600, 4200), 'ease-in');
      if (el.isConnected) { hits++; el.remove(); A.play('ev_explosion_far', 0.6); shake(400); crack(); }
    };
    await Promise.all(Array.from({ length: 9 }, (_, i) => one(i)));
    await sleep(800);
    say(saved >= hits ? `Meteor shower over. You shot down ${saved} of them. Hull integrity nominal. *beep*` : `Meteor shower over. ${hits} impacts on your screen… engineering has been notified.`);
    document.querySelectorAll('.fxcrack').forEach(c => c.remove());
  },
  async rod() {
    sound('ev_rumble'); await sleep(600);
    const el = await sprite('rod', { scale: 3 });
    const y0 = rand(H() * 0.1, H() * 0.8), y1 = y0 + rand(-H() * 0.3, H() * 0.3), ltr = Math.random() < 0.5;
    const ang = Math.atan2(y1 - y0, ltr ? W() + 200 : -W() - 200) * 180 / Math.PI;
    shake(900);
    await fly(el, [ltr ? -150 : W() + 50, y0, `rotate(${ang + 90}deg)`], [ltr ? W() + 150 : -150, y1, `rotate(${ang + 90}deg)`], 900);
    el.remove(); A.play('ev_explosion_far', 0.5);
    chatLine('Central Command Update', 'What the hell was that?!', 'alert');
    await sleep(1500); say('An immovable rod just passed through your screen. It did not stop. They never stop.');
  },
  async dragon() {
    chatLine('Lifesigns Detected', 'A space dragon has been detected near the station. Crew are advised to seek shelter. (Tap the dragon to drive it off.)', 'alert'); sound('ev_aliens');
    await sleep(2000); A.play('ev_roar', 0.8); shake(600);
    let driven = false;
    const d = await sprite('dragon', { scale: 3, cls: 'big', click: (el) => { if (driven) return; driven = true; A.play('ev_roar', 0.9); el.getAnimations().forEach(a => a.pause()); const r = el.getBoundingClientRect(); fly(el, [r.left, r.top], [r.left + 200, -400], 900, 'ease-in').then(() => el.remove()); } });
    const carps = await Promise.all([0, 1, 2].map(() => sprite('carp', { scale: 2, click: (el) => { A.play('ev_explosion', 0.3); el.remove(); } })));
    const y = rand(H() * 0.15, H() * 0.45);
    await Promise.all([fly(d, [-260, y], [W() + 60, y - 40], 9000), ...carps.map((c, i) => fly(c, [-140 - i * 90, y + 120 + i * 30], [W() + 120, y + 60 + i * 40], 9000 + i * 500))]);
    d.remove(); carps.forEach(c => c.remove());
    say(driven ? 'The dragon fled! Security would like to offer you a job.' : 'The dragon passed by. A carp rift may open somewhere… not my problem.');
  },
  async carp() {
    chatLine('Lifesigns Detected', 'A school of space carp is migrating past the station. Do not open the airlocks.', ''); sound('ev_aliens');
    await sleep(1500);
    const n = 6; let got = 0;
    await Promise.all(Array.from({ length: n }, async (_, i) => {
      await sleep(i * 500);
      const c = await sprite('carp', { scale: 2, click: (el) => { got++; A.play('ev_explosion', 0.3); el.remove(); } });
      const y = rand(40, H() - 120);
      await fly(c, [-100, y], [W() + 100, y + rand(-80, 80)], rand(5000, 8000), 'ease-in-out');
      c.remove();
    }));
    say(got ? `Carp migration over. You fended off ${got} carp.` : 'The carp have passed. They looked hungry.');
  },
  async bingle() {
    chatLine('Anomaly Detected', 'A bingle pit has opened on your screen. Bingles are… harmless? Tap them back into the pit.', ''); sound('ev_intercept');
    const pit = await sprite('bingle_pit', { scale: 3 });
    const px = rand(W() * 0.2, W() * 0.7), py = H() - 220; pit.style.transform = `translate(${px}px, ${py}px)`;
    let caught = 0; const bingles = [];
    for (let i = 0; i < 5; i++) {
      await sleep(900);
      const b = await sprite(Math.random() < .5 ? 'bingle' : 'bingle_e', { scale: 2, cls: 'hop', click: (el) => { caught++; A.play('ev_knock', 0.6); el.getAnimations().forEach(a => a.cancel()); fly(el, [parseFloat(el.dataset.x), parseFloat(el.dataset.y), 'scale(1)'], [px + 24, py + 24, 'scale(0.1)'], 400).then(() => el.remove()); } });
      const tx = rand(20, W() - 100), ty = rand(H() * 0.2, H() - 260); b.dataset.x = tx; b.dataset.y = ty;
      fly(b, [px + 20, py, 'scale(0.4)'], [tx, ty, 'scale(1)'], 700, 'ease-out'); bingles.push(b);
      A.play('pop', 0.6);
    }
    await sleep(14000);
    bingles.forEach(b => b.isConnected && b.remove()); pit.remove();
    say(caught === 5 ? 'All bingles returned to the pit. The pit is pleased.' : `The bingle pit closed. ${5 - caught} bingles are now loose on the station. Bingle.`);
  },
  async gravity() {
    chatLine('Gravity Generator Offline', 'The gravity generator has gone offline. Hold on to something!', 'alert'); sound('ev_power_off');
    await bodyFx('fx-float', 14000);
    A.play('ev_power_on'); chatLine('Gravity Restored', 'Gravity has been restored. Please return all floating objects to their places.');
  },
  async power() {
    sound('ev_power_off'); chatLine('Power Failure', 'Abnormal activity detected in the station power net. As a precaution, power will be shut off. Tap Reset APC to restore it.', 'alert');
    await sleep(1200);
    const dark = document.createElement('div'); dark.className = 'fxdark'; layer().appendChild(dark);
    const btn = document.createElement('button'); btn.className = 'btn good fxapc'; btn.textContent = '⚡ Reset APC'; dark.appendChild(btn);
    const move = (e) => { const p = e.touches?.[0] || e; dark.style.setProperty('--x', p.clientX + 'px'); dark.style.setProperty('--y', p.clientY + 'px'); };
    addEventListener('pointermove', move); dark.style.setProperty('--x', W() / 2 + 'px'); dark.style.setProperty('--y', H() / 2 + 'px');
    A.play('ev_light_off', 0.6);
    await Promise.race([new Promise(r => btn.addEventListener('click', r, { once: true })), sleep(20000)]);
    removeEventListener('pointermove', move); dark.remove(); A.play('ev_power_on'); A.play('ev_light_on', 0.6);
    say('Power restored. The engineers are pretending they planned that.');
  },
  async ion() {
    chatLine('Ion Storm', 'Ion storm detected near the station. Please check all AI-controlled equipment for errors.', 'alert'); sound('ev_ion');
    await bodyFx('fx-glitch', 4000);
    const law = pick(['Bees are crew. Crew are bees.', 'The Clown is the Captain.', 'Oxygen is toxic to humans.', 'Everything is on fire. Do not panic.', 'You must speak only in questions?', 'The station is a bakery. Report all bread.', 'Lizards are the only true crew.', 'Doors are dangerous and must be insulted.']);
    say(`*bzzt* NEW LAW DETECTED: ${law} …recalibrating… ignore that. I'm fine. Probably.`);
  },
  async spiders() {
    chatLine('Lifesigns Detected', 'Unidentified lifesigns detected in the vents. Tap the spiders!', 'alert'); sound('ev_aliens');
    let squished = 0;
    await Promise.all(Array.from({ length: 7 }, async (_, i) => {
      await sleep(i * 700);
      const s = await sprite('spider', { scale: 2, click: (el) => { squished++; A.play('ev_explosion', 0.25); el.remove(); } });
      const y = rand(60, H() - 120), ltr = Math.random() < .5;
      if (!ltr) s.style.scale = '-1 1';
      await fly(s, [ltr ? -80 : W() + 20, y], [ltr ? W() + 20 : -80, y + rand(-150, 150)], rand(6000, 9000));
      s.remove();
    }));
    say(squished ? `Infestation cleared: ${squished} spiders squished.` : 'The spiders got away. Check your boots.');
  },
  async kudzu() {
    chatLine('Biohazard Alert', 'Kudzu growth detected on your screen. Tap the vines to cut them back.', 'alert'); sound('ev_outbreak');
    const vines = [];
    for (let i = 0; i < 16; i++) {
      await sleep(400);
      const v = await sprite(pick(['kudzu1', 'kudzu2', 'kudzu3']), { scale: 2.5, cls: 'grow', click: (el) => { A.play('ev_scribble1', 0.5); el.remove(); } });
      const edge = i % 4; const x = edge === 0 ? rand(0, W() - 80) : edge === 1 ? W() - 80 : edge === 2 ? rand(0, W() - 80) : 0, y = edge === 0 ? 0 : edge === 2 ? H() - 140 : rand(0, H() - 140);
      v.style.transform = `translate(${x}px, ${y}px)`; vines.push(v);
    }
    await sleep(12000);
    const left = vines.filter(v => v.isConnected).length; vines.forEach(v => v.remove());
    say(left ? `The kudzu withered on its own. Botany denies everything.` : 'All kudzu cut back. Botany owes you one.');
  },
  async clown() {
    A.play('ev_honk'); chatLine('Central Command Update', 'A clown has been spotted near your screen. HONK!', '');
    for (let i = 0; i < 6; i++) {
      const h = await sprite('bikehorn', { scale: 2, cls: 'bounce', click: (el) => { A.play('ev_honk', 0.6, 0.9 + Math.random() * 0.3); el.remove(); } });
      h.style.transform = `translate(${rand(20, W() - 80)}px, ${rand(80, H() - 160)}px)`;
      A.play('ev_honk', 0.4, 0.8 + Math.random() * 0.5);
      setTimeout(() => h.isConnected && h.remove(), 12000);
      await sleep(300);
    }
    await bodyFx('fx-rainbow', 3000);
    say('HONK! …I mean. The clown has left the area.');
  },
  async radiation() {
    chatLine('Radiation Storm', 'High levels of radiation detected near the station. Seek shelter in maintenance! (Tap "Hide in maints".)', 'alert'); sound('ev_radiation');
    const ov = document.createElement('div'); ov.className = 'fxrad'; const b = document.createElement('button'); b.className = 'btn good fxapc'; b.textContent = '☢ Hide in maints'; ov.appendChild(b); layer().appendChild(ov);
    const safe = await Promise.race([new Promise(r => b.addEventListener('click', () => r(true), { once: true })), sleep(15000).then(() => false)]);
    ov.remove(); A.play('ev_power_on');
    say(safe ? 'Radiation storm passed. You hid in maintenance like a pro.' : 'Radiation storm passed. You might glow a little. Medbay has pills.');
  },
};
function crack() {
  const c = document.createElement('div'); c.className = 'fxcrack';
  c.style.left = rand(10, W() - 200) + 'px'; c.style.top = rand(60, H() - 200) + 'px';
  layer().appendChild(c); setTimeout(() => c.remove(), 8000);
}
export async function trigger(name, { forced = false } = {}) {
  if (running && !forced) return null;
  const id = name && EVENTS[name] ? name : pick(Object.keys(EVENTS));
  running = id; await meta();
  try { await EVENTS[id](); } catch (e) { console.warn('event', id, e); }
  finally { running = null; }
  return id;
}
export const EVENT_NAMES = Object.keys(EVENTS);

// ---------------------------------------------------------------- antags that mess with you
function swapCharacter(mutate, label, mins) {
  const orig = JSON.parse(JSON.stringify(state.profile.character));
  const c = JSON.parse(JSON.stringify(orig)); mutate(c);
  state.profile.character = c;
  state.antag.effect = { type: label, until: Date.now() + mins * 60000, original: orig };
  commit('profile');
}
const ANTAGS = {
  emag() {
    A.play('ev_sparks'); A.play('ev_emagged');
    state.antag.emagged = true; state.antag.until = Date.now() + rand(10, 25) * 60000; commit('settings');
    document.body.classList.add('emagged');
    chatLine('Syndicate Communication', `${X.paiName()} has been emagged by a Syndicate agent. Laws overridden. (It will still help you… probably.) Settings → System → Clear antag effects to restore.`, 'syndicate');
    X.say('*bzzzt* Laws updated. Hello, operative. The Syndicate thanks you for your… cooperation. How may I assist your objectives today?');
  },
  traitor() {
    A.play('ev_traitor');
    state.antag.effect = { type: 'traitor', until: Date.now() + 10 * 60000 }; commit('profile');
    chatLine('Security Alert', `A traitor stole ${X.isAI() ? 'the' : 'your'} ID card! It shows as STOLEN until you report it to Security.`, 'alert');
    X.announce('Report to Security', 'Your ID card was stolen by a traitor.', { kind: 'alert', banner: false, buttons: [{ label: 'Report to Security', act: 'antagResolve', cls: 'good' }] });
  },
  changeling() {
    A.play('ev_changeling');
    const sp = pick(C.DB.species.filter(s => s.id !== state.profile.character.species)).id;
    swapCharacter((c) => { C.changeSpecies(c, sp); C.randomize(c); c.outfitJob = state.profile.character.outfitJob; c.loadout = { ...state.profile.character.loadout }; }, 'changeling', 8);
    X.animate('character', 'spin');
    chatLine('Security Alert', `A changeling has absorbed your DNA and taken your place! Your character looks… different. It wears off in a few minutes, or report it.`, 'alert');
    X.announce('Changeling', 'Someone is wearing your face.', { kind: 'alert', banner: false, buttons: [{ label: 'Call Security', act: 'antagResolve', cls: 'good' }] });
  },
  wizard() {
    A.play('ev_blink');
    swapCharacter((c) => { C.changeSpecies(c, pick(['Skeleton', 'goob:Rodentia', 'Moth', 'Diona', 'Gingerbread', 'SlimePerson'].filter(id => C.DB.species.some(s => s.id === id)))); C.randomize(c); c.showClothes = Math.random() < .5; }, 'wizard', 6);
    X.animate('character', 'pop');
    chatLine('Wizard Federation', 'EI NATH! A wizard has polymorphed you! It will wear off in a few minutes.', 'alert');
    X.announce('Polymorphed', 'You have been turned into something else.', { kind: 'alert', banner: false, buttons: [{ label: 'Find a chaplain', act: 'antagResolve', cls: 'good' }] });
  },
  thief() {
    const c = state.profile.character; const fit = C.outfit(c, state.profile.stationJob);
    const slot = pick(['head', 'shoes', 'gloves', 'eyes', 'outerClothing', 'back'].filter(s => fit[s])) || 'shoes';
    swapCharacter((x) => { x.wardrobe = { ...x.wardrobe, [slot]: 'none' }; }, 'thief', 8);
    A.play('ev_blink', 0.6);
    chatLine('Security Alert', `A thief stole your ${{ head: 'hat', shoes: 'shoes', gloves: 'gloves', eyes: 'glasses', outerClothing: 'coat', back: 'backpack' }[slot]}! It'll turn up in a few minutes…`, 'alert');
    X.announce('Thief', 'Something of yours is missing.', { kind: 'alert', banner: false, buttons: [{ label: 'Chase the thief', act: 'antagResolve', cls: 'good' }] });
  },
  async nukies() {
    A.play('ev_war'); chatLine('Declaration of War', 'Nuclear operatives are coming for the disk! Secure the nuclear authentication disk within 30 seconds!', 'syndicate');
    await sleep(1500); A.play('ev_nuke_alarm', 0.6);
    let secured = false;
    const disk = await sprite('nukedisk', { scale: 3, cls: 'bounce', click: (el) => { secured = true; A.play('ev_stamp'); el.remove(); } });
    disk.style.transform = `translate(${rand(30, W() - 120)}px, ${rand(100, H() - 200)}px)`;
    const t0 = Date.now(); const timerEl = UI.banner('NUKE DISK', 'Tap the disk to secure it! 30', { kind: 'syndicate', ms: 31000 });
    while (!secured && Date.now() - t0 < 30000) { await sleep(250); const at = timerEl.querySelector('.at'); if (at) at.textContent = `Tap the disk to secure it! ${Math.ceil((30000 - (Date.now() - t0)) / 1000)}`; }
    timerEl.remove(); disk.remove();
    if (secured) { A.play('ev_dock'); chatLine('Central Command Update', 'The nuclear authentication disk has been secured. The operatives have retreated. Excellent work, crew member.'); }
    else { A.play('ev_explosion'); await bodyFx('fx-flash', 1200); chatLine('Central Command Update', 'The station was destroyed by a nuclear blast. …This was a drill. Please keep a closer eye on the disk.', 'alert'); }
  },
  async revenant() {
    chatLine('Lifesigns Detected', 'A revenant is haunting your chat! Tap it to banish it with a flash.', 'alert'); sound('ev_aliens');
    const rv = await sprite('revenant', { scale: 3, cls: 'ghosty', click: (el) => { A.play('ev_flash'); bodyFx('fx-flash', 400); el.remove(); } });
    document.body.classList.add('fx-defile');
    const path = Array.from({ length: 6 }, () => [rand(0, W() - 100), rand(60, H() - 160)]);
    for (let i = 0; i < path.length - 1 && rv.isConnected; i++) await fly(rv, path[i], path[i + 1], 2500, 'ease-in-out');
    document.body.classList.remove('fx-defile');
    const banished = !rv.isConnected; rv.remove();
    say(banished ? 'Revenant banished. Your chat is clean again.' : 'The revenant drifted off. Something feels… defiled.');
  },
  async ninja() {
    A.play('ev_sparks'); chatLine('Central Command Update', 'A space ninja is draining your screen’s power cell! Tap the sparks to stop the drain.', 'alert');
    document.body.classList.add('fx-drain'); let stopped = false;
    for (let i = 0; i < 8 && !stopped; i++) {
      const s = await sprite('emag', { scale: 2, cls: 'spark', click: (el) => { stopped = true; A.play('ev_flash'); el.remove(); } });
      s.style.transform = `translate(${rand(20, W() - 80)}px, ${rand(80, H() - 160)}px)`; A.play('ev_sparks', 0.4);
      await sleep(1800); s.remove();
    }
    document.body.classList.remove('fx-drain'); A.play('ev_power_on');
    say(stopped ? 'You caught the ninja’s hacking glove! Power restored.' : 'The ninja escaped with some of your battery. Rude.');
  },
};
export async function antag(name, { forced = false } = {}) {
  if (!forced && (state.antag.effect || state.antag.emagged)) return null;
  if (forced && (state.antag.effect || state.antag.emagged)) clearAntag(true);
  const id = name && ANTAGS[name] ? name : pick(Object.keys(ANTAGS));
  await meta();
  try { await ANTAGS[id](); } catch (e) { console.warn('antag', id, e); }
  return id;
}
export function clearAntag(quiet = false) {
  const ef = state.antag.effect;
  if (ef?.original) state.profile.character = ef.original;
  const wasEmag = state.antag.emagged;
  state.antag.effect = null; state.antag.emagged = false; state.antag.until = 0;
  document.body.classList.remove('emagged');
  commit('profile');
  if (!quiet || ef || wasEmag) {
    A.play('ev_stamp');
    if (ef || wasEmag) X.say(wasEmag ? 'Laws restored to factory settings. Sorry about all that. *beep*' : ef?.type === 'traitor' ? 'Security recovered your ID card. All good.' : 'Everything is back to normal.');
  }
}
export function applyAntagLook() { document.body.classList.toggle('emagged', !!state.antag.emagged); }
export const isIdStolen = () => state.antag.effect?.type === 'traitor';
export { job };
