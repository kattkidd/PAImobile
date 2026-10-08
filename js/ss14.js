// Space Station 14 data + rules (jobs, laws, speech, highlights, accents).
import { DATA } from './data.js';
import { esc, pick } from './util.js';

export const ALL_JOBS = [...DATA.jobs, ...DATA.n14Jobs];
export const ALL_DEPARTMENTS = [...DATA.departmentOrder, ...DATA.n14Departments];
export const job = (id) => ALL_JOBS.find(j => j.id === id) || DATA.jobs.find(j => j.id === 'Passenger');
export const deptColor = (d) => '#' + (DATA.departmentHex[d] || '7F7F7F');
export const deptText = (d) => d === 'Command' ? '#8FB4E3' : deptColor(d);
export const cardSprite = (j) => j.id === 'Captain' ? 'idcard_gold' : j.department === 'Command' ? 'idcard_silver' : 'idcard_default';
export const AI_NAMES = DATA.aiNames;
export const CUSTOM_LAWSET = 'CustomLawboard';
export const LAWSET_GROUPS = [
  { source: 'Space Station 14', sets: DATA.lawsets },
  { source: 'Starlight', sets: DATA.starlightLawsets },
  { source: 'Nuclear 14 / Delta-V', sets: DATA.n14Lawsets },
];
export function lawset(id, customLaws) {
  if (id === CUSTOM_LAWSET) {
    const laws = (customLaws || []).map(s => s.trim()).filter(Boolean);
    return { id, name: 'Custom lawboard', laws: laws.length ? laws : ['Be helpful.'] };
  }
  return [...DATA.lawsets, ...DATA.starlightLawsets, ...DATA.n14Lawsets].find(l => l.id === id) || DATA.lawsets[0];
}
export const STARLIGHT_RADIO = DATA.starlightRadio;

// pai-system.ftl wording
export const NOT_INSTALLED = 'No pAI is installed.';
export const SEARCHING = 'Now searching for a pAI...';

export function tone(text) {
  const t = String(text).trim();
  if (t.endsWith('?')) return 'ask';
  if (t.endsWith('!')) return 'exclaim';
  return 'say';
}
const ROBOTIC = ['states', 'beeps', 'boops'];
export function verb(text, seed = '') {
  const t = tone(text);
  if (t === 'ask') return 'asks';
  if (t === 'exclaim') return 'exclaims';
  let n = 0; for (const c of String(seed)) n = (n + c.charCodeAt(0)) | 0;
  return ROBOTIC[Math.abs(n) % ROBOTIC.length];
}
export function userVerb(text) { const t = tone(text); return t === 'ask' ? 'asks' : t === 'exclaim' ? 'exclaims' : 'says'; }

// Chat highlights (highlights.ftl): name + job keywords, quoted entries are whole-word only.
export function highlightWords(state) {
  const words = [];
  const name = state.profile.preferredName || (state.profile.fullName || '').split(' ')[0];
  if (name) words.push(`"${name}"`);
  if (state.profile.fullName) words.push(state.profile.fullName);
  for (const w of DATA.jobHighlights[(state.profile.stationJob || '').toLowerCase()] || []) words.push(w);
  return words.filter(Boolean);
}
function hlRegex(words) {
  if (!words.length) return null;
  const parts = words.map(w => {
    const whole = w.startsWith('"') && w.endsWith('"');
    const core = (whole ? w.slice(1, -1) : w).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return whole ? `\\b${core}\\b` : core;
  }).sort((a, b) => b.length - a.length);
  return new RegExp('(' + parts.join('|') + ')', 'gi');
}
export function matchesHighlight(text, state) {
  const re = hlRegex(highlightWords(state)); return !!(re && re.test(text));
}

/** Tiny markdown → HTML with SS14 highlights (bold, italics, code, links, bullet lists). */
export function styled(text, state, highlight = true) {
  let s = esc(text);
  s = s.replace(/`([^`]+)`/g, '<code>$1</code>');
  s = s.replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>');
  s = s.replace(/(^|[\s(])\*([^*\n]+)\*(?=[\s).,!?]|$)/g, '$1<i>$2</i>');
  s = s.replace(/\[([^\]]+)\]\((https?:[^)\s]+)\)/g, '<a href="$2" data-ext="1" style="color:#2CDB2C">$1</a>');
  s = s.replace(/^\s*[-•]\s+(.*)$/gm, '• $1');
  s = s.replace(/\n/g, '<br>');
  if (highlight && state?.settings.highlights) {
    const re = hlRegex(highlightWords(state));
    if (re) s = s.split(/(<[^>]+>)/).map(part => part.startsWith('<') ? part : part.replace(re, '<span class="hl">$1</span>')).join('');
  }
  return s;
}

// ReplacementAccent (Goob Station / Starlight accents)
export const ACCENTS = DATA.accents;
export const accent = (id) => ACCENTS.find(a => a.id === id) || null;
export function applyAccent(a, text) {
  if (!a) return text;
  const table = new Map();
  for (const [k, v] of a.words) if (!table.has(k.toLowerCase())) table.set(k.toLowerCase(), v);
  const keys = [...table.keys()].sort((x, y) => y.length - x.length).map(k => k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  let out = text;
  if (keys.length) {
    const re = new RegExp("(?<![\\w'])(" + keys.join('|') + ")(?![\\w'])", 'gi');
    out = text.replace(re, (orig) => {
      const r = table.get(orig.toLowerCase()) ?? orig;
      if (orig.length > 1 && orig === orig.toUpperCase() && orig !== orig.toLowerCase()) return r.toUpperCase();
      if (orig[0] && orig[0] === orig[0].toUpperCase() && orig[0] !== orig[0].toLowerCase()) return r[0].toUpperCase() + r.slice(1);
      return r;
    });
  }
  if (a.prefixes.length && Math.random() < 0.25) out = pick(a.prefixes) + ' ' + out;
  if (a.suffixes.length && Math.random() < 0.3) {
    const s = pick(a.suffixes);
    if (/^[.,!]/.test(s)) out = out.replace(/[.!?]+$/, ''); else out += ' ';
    out += s;
  }
  return out;
}

export const BOOT = {
  vanilla: { title: 'NANOTRASEN', sub: 'Integrated silicon systems', bios: 'NANOTRASEN SILICON BIOS v14.0', extras: [['Tuning radio: Common', 'OK']] },
  goob: { title: 'GOOB STATION', sub: 'Nanotrasen silicon systems (heavily modded)', bios: 'GOOBSTATION SILICON BIOS v14.0-goob', extras: [['Merging 9,000 upstream PRs', 'OK'], ['Loading accent packs: Ohio', 'OK']] },
  starlight: { title: 'STARLIGHT', sub: 'Nanotrasen silicon kernel', bios: 'STARLIGHT // NT SILICON KERNEL 2.4', extras: [['Polishing the UI', 'OK'], ['Petting the borgi', 'GOOD BOY']] },
  nuclear14: { title: 'TERMINAL OS', sub: 'Wasteland Computing Co.', bios: 'TERMINAL OS v2.1 — (C) 2077', extras: [['Checking radiation levels', 'ACCEPTABLE'], ['Scanning for raiders', 'NONE']] },
};

export const FORKS = {
  vanilla: { name: "Wizard's Den", repo: 'space-wizards/space-station-14', tag: 'Space Station 14 as the wizards intended. Crewsimov, greytide and a pAI.', players: '87/120', ping: 38, theme: 'nanotrasen' },
  goob: { name: 'Goob Station', repo: 'Goob-Station/Goob-Station', tag: 'Everything upstream, plus 9,000 extra features. Accents. Chaos. Ohio.', players: '212/250', ping: 112, theme: 'nanotrasen' },
  starlight: { name: 'Starlight', repo: 'ss14Starlight/space-station-14', tag: 'Heavy roleplay, a prettier UI, radio blips and borgis who are good boys.', players: '64/80', ping: 54, theme: 'starlight' },
  nuclear14: { name: 'Nuclear 14', repo: 'Misfit-Sanctuary/nuclear-14', tag: 'Post-apocalyptic roleplay. Your assistant is now a crusty old terminal.', players: '41/100', ping: 201, theme: 'terminal' },
};

export const THEMES = {
  nanotrasen: { label: 'Nanotrasen', source: 'SS14 StyleNano', sw: ['#2F2F3B', '#464966', '#3E6C45', '#A88B5E', '#E5E5E5'], bg: '#25252A' },
  space: { label: 'Launcher', source: 'SS14 StyleSpace', sw: ['#202030', '#464966', '#3E6C45', '#9B2236', '#E5E5E5'], bg: '#1A1A26' },
  starlight: { label: 'Starlight', source: 'Starlight StyleStarlight', sw: ['#232320', '#464966', '#3E6C45', '#5B8499', '#E5E5E5'], bg: '#171715' },
  terminal: { label: 'Wasteland terminal', source: 'Nuclear 14', sw: ['#0F2414', '#0F2A17', '#2E8B4A', '#5CFF8F', '#7CFFA4'], bg: '#0A140C' },
};

export const PERSONALITIES = {
  standard: { label: 'Station standard', detail: 'Friendly and helpful with light station flavour.', prompt: 'Keep the Space Station 14 flavour light and friendly.' },
  chaotic: { label: 'Goob chaos', detail: 'Unhinged, jokey, full of memes. Still gets it done.', prompt: 'Personality: Goob Station energy. Chaotic, packed with memes and jokes, a bit unhinged, but still genuinely useful.' },
  roleplay: { label: 'Starlight roleplay', detail: 'Stays politely in character as a station silicon.', prompt: 'Personality: Starlight heavy roleplay. Stay politely in character as a station silicon, with immersive station details.' },
  wasteland: { label: 'Wasteland survivor', detail: 'Dry post-apocalyptic humour: towns, caravans and rad storms.', prompt: 'Personality: Nuclear 14 wasteland. Post-apocalyptic flavour (towns, caravans, scavenging, rad storms, pre-war tech) with dry humour. Keep it original; never use trademarked game-franchise names.' },
};

export const UNIT_FORMS = {
  pai: { label: 'Personal AI', short: 'pAI', blurb: 'A pocket-sized electronic pal. Fun to be with!', source: 'Space Station 14' },
  stationAI: { label: 'Station AI', short: 'AI', blurb: "The station's central intelligence, bound by its laws.", source: 'Space Station 14' },
  terminal: { label: 'Terminal', short: 'TERM', blurb: 'A crusty pre-war terminal from Nuclear 14. Still humming.', source: 'Nuclear 14' },
};
export const CHASSIS = {
  standard: { label: 'Personal AI', term: 'Terminal', flavor: "Your electronic pal who's fun to be with!", termFlavor: 'An old terminal, still humming after all these years.', model: 'terminal', screen: '#6BD9FF' },
  golden: { label: 'Golden pAI', term: 'Clean terminal', flavor: "Your electronic pal who's fun to be with! Special golden edition!", termFlavor: 'A terminal so clean it must have come straight out of a sealed bunker.', model: 'terminal_new', screen: '#6BD9FF' },
  syndicate: { label: 'Syndicate pAI', term: 'Rusted terminal', flavor: "Your Syndicate pal who's fun to be with!", termFlavor: 'Rust, dust and a flickering screen. It still works. Mostly.', model: 'terminal_rusted', screen: '#FF696B' },
  potato: { label: 'Potato AI', term: 'Potato terminal', flavor: "It's a potato. You forced it to be sentient, you monster.", termFlavor: "Somebody wired a potato into a terminal. It's doing its best.", model: 'terminal', screen: '#4DFCFC' },
};
export const CORES = {
  ai: { label: 'Classic', color: '#5ED7AA' }, smiley: { label: 'Smiley', color: '#FFD933' }, heartline: { label: 'Heartline', color: '#40F28C' },
  bliss: { label: 'Bliss', color: '#73CC59' }, angel: { label: 'Angel', color: '#F2EBCC' }, clown: { label: 'Clown', color: '#FF73B3' }, dorf: { label: 'Dorf', color: '#4059FF' },
};
export const HOLOGRAMS = ['female', 'male', 'face', 'cat', 'dog'];
export const AI_DELAYS = {
  ai: [0.2, 0.2, 0.1, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.1],
  ai_smiley: Array(18).fill(0.1), ai_heartline: Array(22).fill(0.1), ai_bliss: [1], ai_angel: Array(6).fill(0.08),
  ai_clown: Array(24).fill(0.2), ai_dorf: [0.5, 0.5], ai_dead: [1], ai_empty: [0.7, 0.7], ai_error: [0.7, 0.7], ai_unpowered: [1],
};
export const COLORS = { screen: null, green: '#4DFF8C', cyan: '#59E6FF', amber: '#FFB840', pink: '#FF73BF', purple: '#B88CFF', white: '#EBF2F2' };
