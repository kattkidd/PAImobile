// Claude (Anthropic Messages API) with the PAI tool loop (reminders, timers, emotes, web search).
// Tuned for very low usage: cheapest model, short replies, only the last few messages are sent,
// and at most one web search per message.
import { postJSON } from './platform.js';

const ENDPOINT = 'https://api.anthropic.com/v1/messages';
export const DEFAULT_MODEL = 'claude-haiku-5-5';
export const MAX_REPLY_TOKENS = 700;   // ~500 words max per reply (you only pay for what's used)
export const HISTORY = 6;               // how many recent chat lines are sent for context
const LINE_CHARS = 700;                 // long old messages are trimmed before sending

function errorText(code, msg) {
  if (code === 401) return 'Your Claude API key was rejected (401). Check it in Settings → Mind.';
  if (code === 400 && /credit|billing|balance/i.test(msg)) return 'Your Anthropic account is out of credit. Add some at console.anthropic.com → Billing.';
  if (code === 429) return `Too many requests or spend limit reached: ${msg}`;
  if (code === 529 || code === 503) return 'Claude is overloaded right now. Try again in a moment.';
  if (code === 0) return 'Could not reach Claude. Check your internet connection.';
  return `Claude error ${code}: ${msg}`;
}
async function post(key, body) {
  const r = await postJSON(ENDPOINT, {
    'x-api-key': key,
    'anthropic-version': '2023-06-01',
    'anthropic-dangerous-direct-browser-access': 'true',
  }, body);
  let json = {}; try { json = JSON.parse(r.text); } catch { }
  if (r.status < 200 || r.status >= 300) {
    const e = new Error(errorText(r.status, json?.error?.message || r.text?.slice(0, 200) || 'Unknown error'));
    e.status = r.status; throw e;
  }
  return json;
}

/** Turn PAI's chat log into a short, valid Claude message list (alternating, starting with the user). */
export function historyFrom(messages, text) {
  const lines = messages.filter(m => (m.role === 'user' || m.role === 'pai') && m.text).slice(-(HISTORY + 1), -1);
  const out = [];
  for (const m of lines) {
    const role = m.role === 'user' ? 'user' : 'assistant';
    const t = m.text.length > LINE_CHARS ? m.text.slice(0, LINE_CHARS) + '…' : m.text;
    if (out.length && out[out.length - 1].role === role) out[out.length - 1].content += '\n' + t;
    else out.push({ role, content: t });
  }
  while (out.length && out[0].role !== 'user') out.shift();
  if (out.length && out[out.length - 1].role === 'user') out[out.length - 1].content += '\n' + text;
  else out.push({ role: 'user', content: text });
  return out;
}

export async function respond({ key, model, system, messages, tools, onTool }) {
  const convo = [...messages]; const sources = []; let all = '';
  for (let step = 0; step < 6; step++) {
    const json = await post(key, { model: model || DEFAULT_MODEL, max_tokens: MAX_REPLY_TOKENS, system, messages: convo, tools });
    if (!Array.isArray(json.content)) throw new Error('Got an unreadable reply from Claude.');
    let out = ''; const calls = [];
    for (const b of json.content) {
      if (b.type === 'text') {
        out += b.text || '';
        for (const c of b.citations || []) if (c.url && !sources.find(s => s.url === c.url)) sources.push({ title: c.title || c.url, url: c.url });
      }
      if (b.type === 'tool_use') calls.push(b);
    }
    // Claude often writes its answer in the same turn as a tool call (e.g. an emote), so keep text from every step.
    if (out.trim()) all += (all ? '\n\n' : '') + out.trim();
    if (json.stop_reason === 'pause_turn') { convo.push({ role: 'assistant', content: json.content }); continue; }
    if (!calls.length) return { text: all.trim(), sources };
    convo.push({ role: 'assistant', content: json.content });
    const results = [];
    for (const c of calls) results.push({ type: 'tool_result', tool_use_id: c.id, content: await onTool(c.name, c.input || {}) });
    convo.push({ role: 'user', content: results });
  }
  throw new Error('I got stuck in a loop running tools. Try asking again.');
}

export async function test(key, model) {
  const json = await post(key, { model: model || DEFAULT_MODEL, max_tokens: 10, messages: [{ role: 'user', content: 'Reply with exactly: ONLINE' }] });
  return (json.content || []).map(b => b.text || '').join('').trim() || 'Connected.';
}

const fn = (name, description, properties = {}, required = []) => ({ name, description, input_schema: { type: 'object', properties, required } });
const str = (description) => ({ type: 'string', description });
export function tools(webSearch) {
  const t = [
    fn('create_reminder', "Add a reminder to the user's PAI calendar. Their computer shows a notification at that time while PAI is running.", {
      title: str("Short reminder text, e.g. 'Call mom'"),
      datetime: str('Local date and time, ISO 8601 without time zone, e.g. 2026-10-08T17:30:00'),
      notes: str('Optional extra details'),
      repeat: { type: 'string', enum: ['none', 'daily', 'weekly', 'monthly'], description: 'How often it repeats. Default none.' },
    }, ['title', 'datetime']),
    fn('list_reminders', "List the user's reminders for the next 30 days (with ids)."),
    fn('delete_reminder', 'Delete a reminder by id (get ids from list_reminders).', { id: str('Reminder id') }, ['id']),
    fn('start_timer', 'Start a countdown timer. The computer notifies the user when it ends.', {
      seconds: { type: 'integer', description: 'Length in seconds' }, label: str("Short name, e.g. 'Pasta'"),
    }, ['seconds']),
    fn('list_timers', "List the user's running and paused timers (with ids)."),
    fn('cancel_timer', 'Cancel a timer by id.', { id: str('Timer id') }, ['id']),
    fn('emote', 'Do an SS14 silicon emote (shows "PAI beeps." and plays the sound).', {
      emote: { type: 'string', enum: ['beep', 'boop', 'chime', 'ping', 'buzz', 'buzz-two', 'blink'] },
    }, ['emote']),
  ];
  // One search per message at most (each search costs about 1 cent).
  if (webSearch) t.push({ type: 'web_search_20250305', name: 'web_search', max_uses: 1 });
  return t;
}
