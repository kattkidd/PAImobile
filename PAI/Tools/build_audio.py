"""Builds App/Audio (emotes, species voices, barks, music) + audio.json manifest."""
import sys, os, re, json, hashlib, glob, subprocess
sys.path.insert(0, os.path.dirname(__file__))
from protos import Protos, ROOTS
import yaml

APP = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/PAI/App'
OUT = os.path.join(APP, 'Audio'); os.makedirs(OUT, exist_ok=True)
DRY = '--dry' in sys.argv
CHAR = json.load(open(os.path.join(APP, 'Character/character.json')))
SRC_OF = {'Space Station 14': 'ss14', 'Goob Station': 'goob', 'Starlight': 'starlight', 'Nuclear 14': 'n14'}
LABEL = {v: k for k, v in SRC_OF.items()}
P = {k: Protos(k) for k in ROOTS}

def ftl(root):
    d = {}
    for p in glob.glob(os.path.join(root, 'Resources/Locale/en-US/**/*.ftl'), recursive=True):
        try:
            for line in open(p, encoding='utf-8-sig'):
                m = re.match(r'^([A-Za-z0-9_\-]+)\s*=\s*(.+?)\s*$', line)
                if m and m.group(1) not in d: d[m.group(1)] = m.group(2)
        except Exception: pass
    return d
LOC = {k: ftl(r) for k, r in ROOTS.items()}
def loc(src, key, fb=None):
    for s in [src, 'ss14', 'goob', 'starlight', 'n14']:
        v = LOC[s].get(key or '')
        if v: return v
    return fb

# ---------------------------------------------------------------- licences
_attr = {}
def attribution(path):
    d = os.path.dirname(path); name = os.path.basename(path)
    if d not in _attr:
        entries = []
        for fn in ('attributions.yml', 'attribution.yml', 'licenses.yml'):
            f = os.path.join(d, fn)
            if os.path.exists(f):
                try: entries = yaml.safe_load(open(f, encoding='utf-8-sig')) or []
                except Exception: entries = []
                break
        _attr[d] = entries if isinstance(entries, list) else []
    for e in _attr[d]:
        if isinstance(e, dict) and (name in (e.get('files') or []) or any(str(x).startswith('All files') for x in (e.get('files') or []))):
            return str(e.get('license', '')), str(e.get('copyright', '')).strip()
    return 'CC-BY-SA-3.0 (repository default)', ''

# ---------------------------------------------------------------- conversion
FILES = {}  # key -> {license, copyright, source, path}
def convert(src, rel, kind):
    """rel like /Audio/Voice/Human/x.ogg. kind: 'pcm' (caf) or 'aac' (m4a) or 'music'."""
    rel = rel.lstrip('/')
    if rel.startswith('Audio/'): rel = 'Resources/' + rel
    elif not rel.startswith('Resources/'): rel = 'Resources/Audio/' + rel
    for s in [src, 'ss14', 'goob', 'starlight', 'n14']:
        f = os.path.join(ROOTS[s], rel)
        if os.path.exists(f): break
    else:
        return None
    lic, cop = attribution(f)
    if re.search(r'fallout|bethesda|inon zur', cop, re.I): return None
    if re.search(r'/Weapons/|voice_(sans|papyrus|toriel|asgore|undyne|alphys|flowey|gaster|metta|ralsei|susie|temmie|monster)|(wilson|wolfgang|woodie|wurt|wx78)_bark|bulletflyby', f): return None
    if lic == 'Custom' and 'Sampling Plus' not in cop: return None
    h = hashlib.sha1(open(f, 'rb').read()).hexdigest()[:10]
    ext = 'caf' if kind == 'pcm' else 'm4a'
    key = f'{kind[0]}{h}'
    out = os.path.join(OUT, f'{key}.{ext}')
    if not DRY and not os.path.exists(out):
        if kind == 'pcm':
            cmd = ['ffmpeg', '-v', 'error', '-y', '-i', f, '-ac', '1', '-ar', '44100', '-c:a', 'pcm_s16le', '-t', '4', out]
        elif kind == 'aac':
            cmd = ['ffmpeg', '-v', 'error', '-y', '-i', f, '-ac', '1', '-ar', '44100', '-c:a', 'aac', '-b:a', '64k', '-t', '8', out]
        else:
            cmd = ['ffmpeg', '-v', 'error', '-y', '-i', f, '-ac', '2', '-ar', '44100', '-c:a', 'aac', '-b:a', '64k', out]
        subprocess.run(cmd, check=True)
    FILES[key] = {'license': lic, 'copyright': cop, 'source': LABEL[s], 'path': rel.replace('Resources/', '')}
    return key

def spec_files(pr, spec):
    if isinstance(spec, str): return [spec]
    if not isinstance(spec, dict): return []
    if spec.get('path'): return [spec['path']]
    if spec.get('collection'):
        c = pr.get('soundCollection', spec['collection'])
        if c: return c.get('files') or []
    return []

# ---------------------------------------------------------------- emotes + voices per species
EMOTE_SETS = {}  # setId -> {emoteId: [keys]}
def emote_set(src, sid):
    if not sid: return None
    key = f'{src}:{sid}' if src != 'ss14' else sid
    if key in EMOTE_SETS: return key
    pr = P[src]; es = pr.get('emoteSounds', sid)
    if not es: return None
    out = {}
    for emote, spec in (es.get('sounds') or {}).items():
        if emote in ('DefaultDeathgasp',): continue
        ks = [k for k in (convert(src, f, 'aac') for f in spec_files(pr, spec)[:4]) if k]
        if ks: out[emote] = ks
    if not out: return None
    EMOTE_SETS[key] = out
    return key

SPEECH = {}  # id -> {name, say, ask, exclaim, source}
def speech(src, sid):
    if not sid: return None
    key = f'{src}:{sid}' if src != 'ss14' else sid
    if key in SPEECH: return key
    s = P[src].get('speechSounds', sid)
    if not s: return None
    d = {}
    for k in ('saySound', 'askSound', 'exclaimSound'):
        fs = spec_files(P[src], s.get(k))
        if fs:
            c = convert(src, fs[0], 'pcm')
            if c: d[k[:-5]] = c
    if 'say' not in d: return None
    d.setdefault('ask', d['say']); d.setdefault('exclaim', d['say'])
    d['name'] = re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', sid); d['source'] = LABEL[src]
    SPEECH[key] = d
    return key

SPECIES_AUDIO = {}
for sp in CHAR['species']:
    src = SRC_OF[sp['source']]; sid = sp['id'].split(':')[-1]
    pr = P[src]; proto = pr.get('species', sid) or {}
    mob = pr.entity(proto.get('prototype') or '') or {'components': {}}
    comps = mob['components']
    sp_speech = speech(src, (comps.get('Speech') or {}).get('speechSounds'))
    vocal = comps.get('Vocal') or {}
    bysex = {}
    if proto.get('defaultSoundsBySex'):
        for sx, v in zip(['Male', 'Female', 'Unsexed'], proto['defaultSoundsBySex']): bysex[sx] = v
    elif isinstance(vocal.get('sounds'), dict):
        bysex = dict(vocal['sounds'])
    elif vocal.get('emoteSounds'):
        bysex = {'Male': vocal['emoteSounds'], 'Female': vocal['emoteSounds'], 'Unsexed': vocal['emoteSounds']}
    if src == 'ss14' and not proto.get('defaultSoundsBySex') and sid in ('Human', 'Dwarf'):
        bysex = {'Male': 'MaleHuman', 'Female': 'FemaleHuman', 'Unsexed': 'MaleHuman'}
        if sid == 'Dwarf': bysex = {'Male': 'UnisexDwarf', 'Female': 'FemaleDwarf', 'Unsexed': 'UnisexDwarf'}
    sets = {sx: emote_set(src, v) for sx, v in bysex.items()}
    body = emote_set(src, (comps.get('BodyEmotes') or {}).get('soundsId'))
    SPECIES_AUDIO[sp['id']] = {'speech': sp_speech, 'emotes': {k: v for k, v in sets.items() if v}, 'body': body}

# Silicon emote set for the unit itself
emote_set('ss14', 'UnisexSilicon')

# all upstream speech sounds as selectable voices
for sid in P['ss14'].of('speechSounds'): speech('ss14', sid)

# ---------------------------------------------------------------- emote definitions
used = set()
for s in EMOTE_SETS.values(): used |= set(s)
EMOTES = {}
for src in ['ss14', 'goob', 'starlight', 'n14']:
    for eid, e in P[src].of('emote').items():
        if eid in EMOTES or eid not in used: continue
        msgs = [loc(src, m) for m in (e.get('chatMessages') or [])]
        msgs = [m for m in msgs if m and '{' not in m]
        triggers = [t for t in (e.get('chatTriggers') or []) if isinstance(t, str)]
        name = loc(src, e.get('name'), eid)
        if not msgs or not triggers: continue
        EMOTES[eid] = {'name': name, 'message': msgs[0], 'triggers': sorted(set(triggers + [eid.lower()])),
                       'category': e.get('category', 'Vocal')}

# ---------------------------------------------------------------- barks (N14 / Starlight / Goob)
BARKS = []
for src, pat in [('n14', 'Resources/Audio/_Misfits/Voice/Barks/*'), ('n14', 'Resources/Audio/_NC/Voice/Barks/*'),
                 ('starlight', 'Resources/Audio/_Starlight/Effects/Bark/*'), ('goob', 'Resources/Audio/_Goobstation/Voice/Barks/*')]:
    for d in sorted(glob.glob(os.path.join(ROOTS[src], pat))):
        if os.path.isdir(d):
            fs = sorted(glob.glob(d + '/*.ogg'))
            name = os.path.basename(d)
        else:
            if not d.endswith('.ogg'): continue
            fs = [d]; name = os.path.splitext(os.path.basename(d))[0]
        if not fs: continue
        k = convert(src, os.path.relpath(fs[0], ROOTS[src]), 'pcm')
        if k and not any(b['sound'] == k for b in BARKS):
            BARKS.append({'name': re.sub(r'[_\-]+', ' ', name).strip().title(), 'sound': k, 'source': LABEL[src]})

# ---------------------------------------------------------------- music
MUSIC = [
    # (repo, path, title, artist, album/playlist)
    ('ss14', 'Audio/Lobby/endless_space.ogg', 'Endless Space', 'SolusLunes', 'Wizard\'s Den'),
    ('ss14', 'Audio/Lobby/absconditus.ogg', 'Absconditus', 'ZhayTee', 'Wizard\'s Den'),
    ('ss14', 'Audio/Lobby/atomicamnesiammx.ogg', 'Atomic Amnesia MMX', 'Philip Dyer', 'Wizard\'s Den'),
    ('ss14', 'Audio/Lobby/singuloose.ogg', 'Singuloose', 'Janis Schiedková', 'Wizard\'s Den'),
    ('ss14', 'Audio/Lobby/comet_haley.ogg', 'Comet Halley', 'Stellardrone', 'Wizard\'s Den'),
    ('ss14', 'Audio/Lobby/title3.ogg', 'Title3', 'Cuboos', 'Wizard\'s Den'),
    ('ss14', 'Audio/Lobby/Spac_Stac.ogg', 'Spac Stac', 'Hayabusa', 'Wizard\'s Den'),
    ('ss14', 'Audio/Lobby/pwmur.ogg', 'phoron will make us rich', 'Sunbeamstress', 'Wizard\'s Den'),
    ('ss14', 'Audio/Lobby/lasers_rip_apart_the_bulkhead.ogg', 'lasers rip apart the bulkhead', 'Sunbeamstress', 'Wizard\'s Den'),
    ('ss14', 'Audio/Lobby/every_light_is_blinking_at_once.ogg', 'every light is blinking at once', 'Sunbeamstress', 'Wizard\'s Den'),
    ('goob', 'Audio/_Goobstation/Music/the_gray_tide_song.ogg', 'The Gray Tide', 'mrjajkes', 'Goob Station'),
    ('goob', 'Audio/_Goobstation/Music/91476_Glorious_morning.ogg', 'Glorious Morning', 'Waterflame', 'Goob Station'),
    ('goob', 'Audio/_Goobstation/Music/Abductor.ogg', 'Abductor', 'Crockitz', 'Goob Station'),
    ('goob', 'Audio/_Goobstation/Music/Black_Swarm.ogg', 'Black Swarm', 'Bobik-music', 'Goob Station'),
    ('goob', 'Audio/_Goobstation/Music/future_perception.ogg', 'Future Perception', 'Merct', 'Goob Station'),
    ('goob', 'Audio/_Goobstation/Music/mind_crawler.ogg', 'Mind Crawler', 'Merct', 'Goob Station'),
    ('goob', 'Audio/Lobby/clownalwayswins.ogg', 'Clown Always Wins', 'NИTRODE', 'Goob Station'),
    ('goob', 'Audio/Lobby/horn.ogg', 'Honk!', 'SlendyMawn, remastered by Scruq', 'Goob Station'),
    ('goob', 'Audio/Lobby/skubstep.ogg', 'skubstep', 'finket', 'Goob Station'),
    ('goob', 'Audio/Lobby/the_future_soon.ogg', 'The Future Soon', 'Jonathan Coulton', 'Goob Station'),
    ('starlight', 'Audio/_Starlight/Lobby/thestation.ogg', 'The Station', 'A-Guy173', 'Starlight'),
    ('starlight', 'Audio/_Starlight/Lobby/timefracture.ogg', 'Timefracture', 'Bad History', 'Starlight'),
    ('starlight', 'Audio/_Starlight/Lobby/Liberation.ogg', 'Liberation', 'Bolgarich', 'Starlight'),
    ('starlight', 'Audio/_Starlight/Lobby/Bluespace.ogg', 'Bluespace', 'Beptol Corporation Acoustics', 'Starlight'),
    ('starlight', 'Audio/_Starlight/Lobby/RedefiningLines.ogg', 'Redefining Lines', 'Beptol Corporation Acoustics', 'Starlight'),
    ('starlight', 'Audio/_Starlight/Lobby/Null_Scar_Gaze.ogg', 'Null Scar Gaze', 'Beptol Corporation Acoustics', 'Starlight'),
    ('starlight', 'Audio/_Starlight/Music/Jukebox/drunk_reflections_by_JAM.ogg', 'Drunk Reflections', 'JAM', 'Starlight'),
    ('starlight', 'Audio/_Starlight/Lobby/stenchOfWhiskey.ogg', 'Stench of Whiskey', 'hermitsabee', 'Wasteland'),
    ('goob', 'Audio/_Goobstation/Music/cowboy_western_background.ogg', 'Cowboy Western', 'SOULFULJAMTRACKS', 'Wasteland'),
    ('n14', 'Audio/DeltaV/Jukebox/a_different_reality_lagoona_remix.xm-MONO.ogg', 'A.D.R (Lagoona rmx)', 'Andreas Viklund', 'Wasteland'),
    ('n14', 'Audio/DeltaV/Jukebox/Patricia_Taxxon_-_Minute_-_MONO.ogg', 'Minute', 'Patricia Taxxon', 'Wasteland'),
    ('n14', 'Audio/DeltaV/Jukebox/Scratch_Post_-_OST_MONO.ogg', 'Scratch Post', 'Ghirardelli7', 'Wasteland'),
    ('n14', 'Audio/DeltaV/Jukebox/psirius_-_nymphs_of_the_forest.mptm-MONO.ogg', 'Nymphs of the Forest', 'Psirius', 'Wasteland'),
]
TRACKS = []
for src, path, title, artist, album in MUSIC:
    k = convert(src, path, 'music')
    if not k: print('MISSING music', src, path); continue
    lic = FILES[k]['license']
    if 'ND' in lic.upper(): print('skip ND', title); continue
    TRACKS.append({'title': title, 'artist': artist, 'playlist': album, 'file': k, 'license': lic, 'source': LABEL[src]})

# ---------------------------------------------------------------- ambience loops
AMB = []
for src, path, name in [('ss14', 'Audio/Ambience/ambigen1.ogg', 'Station hum'), ('ss14', 'Audio/Ambience/ambigen8.ogg', 'Corridors'),
                        ('ss14', 'Audio/Ambience/ambiatmos.ogg', 'Atmospherics'), ('ss14', 'Audio/Ambience/ambispace.ogg', 'Open space'),
                        ('ss14', 'Audio/Ambience/ambimaint.ogg', 'Maintenance'), ('ss14', 'Audio/Ambience/ambidet1.ogg', 'Detective office')]:
    k = convert(src, path, 'music')
    if k: AMB.append({'name': name, 'file': k, 'license': FILES[k]['license']})
    else: print('missing amb', path)

manifest = {'speech': SPEECH, 'emoteSets': EMOTE_SETS, 'emotes': EMOTES, 'species': SPECIES_AUDIO,
            'barks': BARKS, 'music': TRACKS, 'ambience': AMB}
if not DRY:
    json.dump(manifest, open(os.path.join(OUT, 'audio.json'), 'w'), separators=(',', ':'))
json.dump(FILES, open(os.path.join(os.path.dirname(__file__), 'audio_licenses.json'), 'w'), indent=0)
print('speech', len(SPEECH), 'emoteSets', len(EMOTE_SETS), 'emotes', len(EMOTES), 'barks', len(BARKS), 'tracks', len(TRACKS), 'amb', len(AMB), 'files', len(FILES))
from collections import Counter
print(Counter(v['license'] for v in FILES.values()))
