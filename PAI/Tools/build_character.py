"""Builds App/Character/character.json + sprite strips from SS14 and fork prototypes.

Every sprite is exported as a 128x32 strip (frame 0 for S, N, E, W) named by content hash.
"""
import sys, os, re, json, hashlib, glob
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from protos import Protos, ROOTS
import rsi as R

OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/PAI/App/Character'
SPR_DIR = os.path.join(OUT_DIR, 'Sprites')
os.makedirs(SPR_DIR, exist_ok=True)
for f in glob.glob(SPR_DIR + '/*.png'): os.remove(f)

SOURCE_LABEL = {'ss14': 'Space Station 14', 'goob': 'Goob Station', 'starlight': 'Starlight', 'n14': 'Nuclear 14'}

# Universal draw order (upstream base.yml + fork extras). "slot:" entries are clothing.
LAYERS = ['TailBehind', 'Groin', 'Chest', 'Head', 'Snout', 'Eyes', 'OverEyes', 'Face',
          'RArm', 'LArm', 'RLeg', 'LLeg', 'UndergarmentBottom', 'UndergarmentTop', 'slot:jumpsuit',
          'LFoot', 'RFoot', 'LHand', 'RHand', 'Overlay', 'slot:gloves', 'slot:shoes', 'slot:ears', 'slot:eyes',
          'slot:belt', 'slot:outerClothing', 'TailBehindBackpack', 'slot:back', 'TailOversuit', 'slot:neck',
          'SnoutCover', 'FacialHair', 'Hair', 'HeadSide', 'HeadTop', 'Tail', 'TailOverlay', 'Wings', 'Special',
          'slot:mask', 'slot:head']
SLOT_STATE = {'head': 'HELMET', 'eyes': 'EYES', 'ears': 'EARS', 'mask': 'MASK', 'outerClothing': 'OUTERCLOTHING',
              'jumpsuit': 'INNERCLOTHING', 'neck': 'NECK', 'back': 'BACKPACK', 'belt': 'BELT', 'gloves': 'HAND',
              'shoes': 'FEET'}
VISIBLE_SLOTS = list(SLOT_STATE)

# ---------------------------------------------------------------- locale
def load_ftl(root):
    d = {}
    for p in glob.glob(os.path.join(root, 'Resources/Locale/en-US/**/*.ftl'), recursive=True):
        try:
            for line in open(p, encoding='utf-8-sig'):
                m = re.match(r'^([A-Za-z0-9_\-]+)\s*=\s*(.+?)\s*$', line)
                if m and m.group(1) not in d: d[m.group(1)] = m.group(2)
        except Exception: pass
    return d
LOC = {k: load_ftl(r) for k, r in ROOTS.items()}
def loc(src, key, fallback=None):
    if not key: return fallback
    for s in [src, 'ss14', 'goob', 'starlight', 'n14']:
        v = LOC[s].get(key)
        if v and '{' not in v: return v
    return fallback if fallback is not None else key

def pretty(i):
    i = re.sub(r'^(Human|Lizard|Vox|Moth|Arachnid|Vulp|Slime|Diona)(Hair|FacialHair)?', '', i)
    return re.sub(r'(?<=[a-z])(?=[A-Z0-9])', ' ', i).strip() or i

# ---------------------------------------------------------------- sprites
SPRITES = {}   # key -> (license, copyright, source)
def save_strip(arr, src, p):
    if arr is None: return None
    if arr.shape != (32, 128, 4): return None
    if arr[:, :, 3].max() == 0: return None
    b = arr.tobytes(); key = hashlib.sha1(b).hexdigest()[:12]
    if key not in SPRITES:
        Image.fromarray(arr, 'RGBA').save(os.path.join(SPR_DIR, key + '.png'), optimize=True)
        lic, cop = R.license_of(p)
        SPRITES[key] = {'license': lic, 'copyright': cop, 'source': src, 'rsi': os.path.relpath(p).split('Textures/')[-1]}
    return key
def roots_for(src):
    return [ROOTS[src]] + [ROOTS[k] for k in ['ss14', 'goob', 'starlight', 'n14'] if k != src]
def sprite(src, rsi_path, state):
    if not rsi_path or not state: return None
    p = R.find_rsi(roots_for(src), rsi_path)
    if not p or R.size_of(p) != (32, 32): return None
    return save_strip(R.strip(p, state), src, p)

# ---------------------------------------------------------------- coloring
def col_rules(c, default_rules=('skin',)):
    """Turn a LayerColoringDefinition into a list of rule tokens."""
    if not isinstance(c, dict): return list(default_rules)
    rules = []
    def one(t):
        if not isinstance(t, dict): return None
        tag = t.get('__tag', '')
        neg = 'neg:' if t.get('negative') else ''
        if 'SkinColoring' in tag: return neg + 'skin'
        if 'EyeColoring' in tag: return neg + 'eyes'
        if 'TattooColoring' in tag: return neg + 'tattoo'
        if 'CategoryColoring' in tag: return neg + 'cat:' + str(t.get('category'))
        if 'SimpleColoring' in tag: return neg + hexc(t.get('color', '#ffffff'))
        return None
    if c.get('type') is not None:
        r = one(c['type'])
        if r: rules.append(r)
    fb = c.get('fallbackTypes')
    if fb is None: fb = [{'__tag': 'SkinColoring'}]
    for t in fb:
        r = one(t)
        if r: rules.append(r)
    rules.append(hexc(c.get('fallbackColor', '#ffffff')))
    return rules
def hexc(v):
    v = str(v).strip()
    if not v.startswith('#'): v = '#' + v
    return v[:7].upper()

# ---------------------------------------------------------------- markings
MARKINGS = {}
def add_marking(P, m, cat):
    src = P.name; mid = f"{src}:{m['id']}" if src != 'ss14' else m['id']
    if mid in MARKINGS: return mid
    sprites = []; colors = []
    coloring = m.get('coloring') or {}
    default = coloring.get('default') if isinstance(coloring, dict) else None
    layer_over = coloring.get('layers') if isinstance(coloring, dict) else None
    forced = m.get('forcedColoring', False)
    follow = m.get('followSkinColor', False)
    for s in m.get('sprites') or []:
        if not isinstance(s, dict): continue
        key = sprite(src, s.get('sprite'), s.get('state'))
        if not key: continue
        if forced: rules = ['none']
        elif s.get('coloring'): rules = col_rules(s['coloring'])
        elif layer_over and s.get('state') in layer_over: rules = col_rules(layer_over[s['state']])
        elif default: rules = col_rules(default)
        elif follow: rules = ['skin']
        else: rules = ['skin']
        sprites.append(key); colors.append(rules)
    if not sprites: return None
    name = loc(src, f"marking-{m['id']}")
    if name == f"marking-{m['id']}": name = pretty(m['id'])
    MARKINGS[mid] = {'id': mid, 'name': name, 'layer': m.get('bodyPart'), 'cat': cat,
                     'sprites': sprites, 'colors': colors,
                     'sex': (m.get('sexRestriction')[0] if isinstance(m.get('sexRestriction'), list) and m.get('sexRestriction') else m.get('sexRestriction')),
                     'source': SOURCE_LABEL[src]}
    return mid

# ---------------------------------------------------------------- skin
def skin_def(P, sp):
    sc = sp.get('skinColoration')
    strategy = None
    if isinstance(sc, str):
        proto = P.get('skinColoration', sc)
        if proto: strategy = proto.get('strategy', {}).get('__tag', '')
        else: strategy = sc
    mode = 'hue'
    s = str(strategy or sc or '')
    if 'HumanToned' in s: mode = 'human'
    elif 'TintedHues' in s or 'ClampedHsl' in s: mode = 'tinted'
    elif 'None' in s: mode = 'fixed'
    default = sp.get('defaultSkinTone') or ('#C0967F' if mode == 'human' else '#FFFFFF')
    return {'mode': mode, 'default': hexc(default)}

# ---------------------------------------------------------------- displacement
def disp_key(src, d):
    if not isinstance(d, dict): return None
    layer = None
    if 'sizeMaps' in d:
        sm = d['sizeMaps']; layer = sm.get(32) or sm.get('32')
    elif 'layer' in d: layer = d['layer']
    if not isinstance(layer, dict): return None
    return sprite(src, layer.get('sprite'), layer.get('state'))
def disp_map(src, m):
    out = {}
    for slot, d in (m or {}).items():
        k = disp_key(src, d)
        if k: out[slot] = k
    return out

# ---------------------------------------------------------------- species (upstream organ system)
LAYER_FROM_ENUM = lambda s: str(s).split('.')[-1]
def species_upstream(P, sp):
    doll = P.entity(sp.get('dollPrototype') or '')
    if not doll: return None
    comps = doll['components']
    organs = (comps.get('InitialBody') or {}).get('organs') or {}
    parts = []; eyes = None; group = None; body_disp = None; mdisp = {}
    for slot, oid in organs.items():
        o = P.entity(oid)
        if not o: continue
        vo = o['components'].get('VisualOrgan')
        vm = o['components'].get('VisualOrganMarkings') or {}
        if vm.get('markingData', {}).get('group'): group = group or vm['markingData']['group']
        for lay, dd in (vm.get('markingsDisplacement') or {}).items():
            k = disp_key(P.name, dd)
            if k: mdisp[lay] = k
        if not vo or not vo.get('layer'): continue
        lay = LAYER_FROM_ENUM(vo['layer']); data = vo.get('data') or {}
        rsi_path = data.get('sprite'); st = data.get('state')
        if vo.get('displacement'):
            dd = P.get('displacementData', vo['displacement'])
            if dd: body_disp = disp_key(P.name, dd.get('displacement'))
        entry = {'layer': lay, 'color': 'eyes' if lay == 'Eyes' else 'skin'}
        key = sprite(P.name, rsi_path, st)
        sso = vo.get('sexStateOverrides') or {}
        if sso:
            entry['bySex'] = {sx: sprite(P.name, rsi_path, s2) for sx, s2 in sso.items()}
        if not key and not entry.get('bySex'): continue
        entry['sprite'] = key
        if lay == 'Eyes': eyes = entry
        else: parts.append(entry)
    inv = comps.get('Inventory') or {}
    grp = P.get('markingsGroup', group) if group else None
    return finish_species(P, sp, parts, eyes, grp_limits_upstream(P, grp), allowed_upstream(P, grp, group),
                          inv, body_disp, grp)

def grp_chain(P, grp):
    chain = []
    while grp:
        chain.append(grp); par = grp.get('parent')
        if isinstance(par, list): par = par[0] if par else None
        grp = P.get('markingsGroup', par) if par else None
    return chain
def grp_limits_upstream(P, grp):
    limits = {}
    for g in reversed(grp_chain(P, grp)):
        for k, v in (g.get('limits') or {}).items():
            limits[LAYER_FROM_ENUM(k)] = v
    return limits
def allowed_upstream(P, grp, gid):
    chain = grp_chain(P, grp)
    only_all = any(g.get('onlyGroupWhitelisted') for g in chain[:1])
    limits = grp_limits_upstream(P, grp)
    out = []
    for m in P.of('marking').values():
        lay = m.get('bodyPart')
        lim = limits.get(lay)
        if not lim or int(lim.get('limit', 0)) <= 0: continue
        wl = m.get('groupWhitelist')
        only = lim.get('onlyGroupWhitelisted')
        if only is None: only = only_all
        if wl is None and only: continue
        if wl is not None and gid not in wl: continue
        mid = add_marking(P, m, lay)
        if mid: out.append(mid)
    return out

# ---------------------------------------------------------------- species (legacy fork system)
CAT_LAYER_FIX = {'LeftArm': 'LArm', 'RightArm': 'RArm', 'LeftHand': 'LHand', 'RightHand': 'RHand',
                 'LeftLeg': 'LLeg', 'RightLeg': 'RLeg', 'LeftFoot': 'LFoot', 'RightFoot': 'RFoot'}
def species_legacy(P, sp):
    sbs = P.get('speciesBaseSprites', sp.get('sprites') or '')
    if not sbs: return None
    parts = []; eyes = None
    for lay, bid in (sbs.get('sprites') or {}).items():
        b = P.get('humanoidBaseSprite', bid)
        if not b or not isinstance(b.get('baseSprite'), dict): continue
        bs = b['baseSprite']
        entry = {'layer': lay, 'color': 'eyes' if lay == 'Eyes' else ('skin' if b.get('matchSkin', True) else 'none')}
        if b.get('layerAlpha') is not None: entry['alpha'] = float(b['layerAlpha'])
        entry['sprite'] = sprite(P.name, bs.get('sprite'), bs.get('state'))
        by = {}
        for sx in ['Male', 'Female']:
            b2 = P.get('humanoidBaseSprite', bid + sx)
            if b2 and isinstance(b2.get('baseSprite'), dict):
                by[sx] = sprite(P.name, b2['baseSprite'].get('sprite'), b2['baseSprite'].get('state'))
        if by: entry['bySex'] = by
        if not entry['sprite'] and not by: continue
        if lay == 'Eyes': eyes = entry
        else: parts.append(entry)
    mp = P.get('markingPoints', sp.get('markingLimits') or '') or {}
    only = mp.get('onlyWhitelisted', False)
    limits = {}
    for cat, v in (mp.get('points') or {}).items():
        limits[cat] = {'limit': v.get('points', 0), 'required': v.get('required', False),
                       'default': v.get('defaultMarkings') or []}
    allowed = []
    for m in P.of('marking').values():
        cat = m.get('markingCategory') or m.get('bodyPart')
        if not isinstance(cat, str) or not isinstance(m.get('bodyPart'), str): continue
        cat = {'LArm': 'LeftArm', 'RArm': 'RightArm', 'LHand': 'LeftHand', 'RHand': 'RightHand', 'LLeg': 'LeftLeg',
               'RLeg': 'RightLeg', 'LFoot': 'LeftFoot', 'RFoot': 'RightFoot'}.get(cat, cat)
        lim = limits.get(cat)
        if not lim or int(lim['limit']) <= 0: continue
        rest = m.get('speciesRestriction')
        if rest is None and only: continue
        if rest is not None and sp['id'] not in rest: continue
        mid = add_marking(P, m, cat)
        if mid: allowed.append(mid)
    mob = P.entity(sp.get('dollPrototype') or '') or P.entity(sp.get('prototype') or '') or {'components': {}}
    inv = mob['components'].get('Inventory') or {}
    if not inv.get('speciesId'):
        mob2 = P.entity(sp.get('prototype') or '')
        if mob2: inv = mob2['components'].get('Inventory') or inv
    return finish_species(P, sp, parts, eyes, limits, allowed, inv, None, None, legacy=True)

# ---------------------------------------------------------------- common
def finish_species(P, sp, parts, eyes, limits, allowed, inv, body_disp, grp, legacy=False):
    lim_out = []
    for cat, v in limits.items():
        n = int(v.get('limit', v.get('points', 0)) or 0)
        if n <= 0: continue
        defaults = []
        for d in v.get('default') or v.get('defaultMarkings') or []:
            mid = d if P.name == 'ss14' else f'{P.name}:{d}'
            if mid in MARKINGS: defaults.append(mid)
        lim_out.append({'cat': CAT_LAYER_FIX.get(cat, cat) if not legacy else cat, 'limit': n,
                        'required': bool(v.get('required')), 'defaults': defaults})
    appearances = {}
    if grp:
        for k, v in (grp.get('appearances') or {}).items():
            appearances[LAYER_FROM_ENUM(k)] = {'alpha': float(v.get('layerAlpha', 1)), 'matchSkin': bool(v.get('matchSkin'))}
    sexes = sp.get('sexes') or ['Male', 'Female']
    name = loc(P.name, sp.get('name'), sp['id'])
    hw = {k: sp[k] for k in ['minHeight', 'maxHeight', 'minWidth', 'maxWidth'] if k in sp}
    return {
        'id': sp['id'] if P.name == 'ss14' else f"{P.name}:{sp['id']}",
        'name': name, 'source': SOURCE_LABEL[P.name], 'sexes': sexes,
        'skin': skin_def(P, sp), 'parts': parts, 'eyes': eyes,
        'limits': lim_out, 'markings': sorted(set(allowed)),
        'clothingSuffix': inv.get('speciesId'),
        'displace': disp_map(P.name, inv.get('displacements')),
        'displaceMale': disp_map(P.name, inv.get('maleDisplacements')),
        'displaceFemale': disp_map(P.name, inv.get('femaleDisplacements')),
        'bodyDisplace': body_disp, 'appearances': appearances, 'size': hw,
    }

# ---------------------------------------------------------------- run species
SPECIES = []
def run_species(P, wanted=None):
    for sid, sp in P.of('species').items():
        if wanted is not None and sid not in wanted: continue
        if wanted is None and not sp.get('roundStart', True) and sid not in ('Skeleton', 'Gingerbread'): continue
        try:
            s = species_upstream(P, sp) if sp.get('dollPrototype') and P.name == 'ss14' else species_legacy(P, sp)
        except Exception as e:
            import traceback; traceback.print_exc(); print('species fail', P.name, sid, e); continue
        if not s or not s['parts']:
            print('skip species', P.name, sid); continue
        SPECIES.append(s)

UP = Protos('ss14')
run_species(UP)
FORK_SPECIES = {
    'goob': ['Felinid', 'Oni', 'Tajaran', 'Shadowkin', 'IPC', 'Plasmaman', 'Chitinid', 'Rodentia', 'Harpy', 'Feroxi',
             'Yowie', 'Hydrakin', 'BananaMen'],
    'starlight': ['Thaven', 'Shadekin', 'Lagomorph', 'Doll', 'Elf', 'Felionoid', 'Experiment', 'Cyclorite', 'Avali',
                  'Resomi'],
    'n14': ['RatFolk', 'Kobold'],
}
for fk, ids in FORK_SPECIES.items():
    FP = Protos(fk)
    have = set(FP.of('species'))
    run_species(FP, [i for i in ids if i in have])
# n14 extra: list what exists so we can decide later
N14 = Protos('n14')
print('n14 species:', sorted(N14.of('species')))

# ---------------------------------------------------------------- clothing items & loadouts (upstream items)
ITEMS = {}
def item(iid, slot):
    if iid in ITEMS: return iid
    e = UP.entity(iid)
    if not e: return None
    sp = e['components'].get('Sprite') or {}; cl = e['components'].get('Clothing') or {}
    rsi_path = cl.get('sprite') or sp.get('sprite')
    if not rsi_path: return None
    p = R.find_rsi([ROOTS['ss14']], rsi_path)
    if not p or R.size_of(p) != (32, 32): return None
    layers = []; species_layers = {}
    vis = cl.get('clothingVisuals') or {}
    if slot in vis and isinstance(vis[slot], list):
        for l in vis[slot]:
            st = l.get('state'); rp = l.get('sprite') or rsi_path
            k = sprite('ss14', rp, st)
            if k: layers.append({'sprite': k, 'color': hexc(l['color']) if l.get('color') else None})
    else:
        st = f'equipped-{SLOT_STATE[slot]}'
        if cl.get('equippedPrefix'): st = f"{cl['equippedPrefix']}-{st}"
        if cl.get('equippedState'): st = cl['equippedState']
        k = sprite('ss14', rsi_path, st)
        if k: layers.append({'sprite': k, 'color': None})
        if R.has_state(p, st):
            for s in R.meta(p)['states']:
                if s['name'].startswith(st + '-'):
                    suf = s['name'][len(st) + 1:]
                    k2 = sprite('ss14', rsi_path, s['name'])
                    if k2: species_layers[suf] = k2
    for slot2 in list(vis):
        if slot2.startswith(slot + '-') and isinstance(vis[slot2], list) and vis[slot2]:
            l = vis[slot2][0]
            k2 = sprite('ss14', l.get('sprite') or rsi_path, l.get('state'))
            if k2: species_layers[slot2[len(slot) + 1:]] = k2
    if not layers: return None
    # icon
    icon = None; st_icon = sp.get('state') or 'icon'
    ip = R.find_rsi([ROOTS['ss14']], sp.get('sprite') or rsi_path)
    if ip and R.size_of(ip) == (32, 32): icon = sprite('ss14', sp.get('sprite') or rsi_path, st_icon)
    ITEMS[iid] = {'id': iid, 'name': (e['name'] or iid).strip(), 'slot': slot, 'layers': layers,
                  'species': species_layers, 'icon': icon}
    return iid

def starting_gear_items(gid):
    g = UP.get('startingGear', gid) or {}
    out = {}
    for slot, iid in (g.get('equipment') or {}).items():
        if slot in VISIBLE_SLOTS:
            k = item(iid, slot)
            if k: out[slot] = k
    return out

JOBS = {}
for jid, j in UP.of('job').items():
    base = starting_gear_items(j.get('startingGear')) if j.get('startingGear') else {}
    groups = []
    rl = UP.get('roleLoadout', f'Job{jid}') or {}
    for gid in rl.get('groups') or []:
        if re.search(r'Survival|BreathTool|Trinket|Assistive|TankHarness|Pet|Instrument|Bible|Book', gid): continue
        g = UP.get('loadoutGroup', gid)
        if not g: continue
        opts = []
        for lid in g.get('loadouts') or []:
            lo = UP.get('loadout', lid)
            if not lo: continue
            eq = dict(lo.get('equipment') or {})
            if lo.get('startingGear'):
                sg = UP.get('startingGear', lo['startingGear']) or {}
                eq.update(sg.get('equipment') or {})
            its = {}
            for slot, iid in eq.items():
                if slot in VISIBLE_SLOTS:
                    k = item(iid, slot)
                    if k: its[slot] = k
            if its:
                nm = loc('ss14', lo.get('name')) if lo.get('name') else None
                if not nm or nm.startswith('loadout-'):
                    nm = ITEMS[next(iter(its.values()))]['name']
                opts.append({'id': lid, 'name': nm, 'items': its})
        if opts:
            groups.append({'id': gid, 'name': loc('ss14', g.get('name'), gid),
                           'min': int(g.get('minLimit', 1)), 'options': opts})
    if base or groups:
        JOBS[jid] = {'base': base, 'groups': groups}

# Nuclear 14 wasteland jobs: outfits assembled from SS14 items (N14's own clothing is Fallout art, not included).
def custom_job(base, groups):
    gs = []
    for gid, name, opts in groups:
        o = []
        for oid, items in opts:
            its = {}
            for iid in items:
                e = UP.entity(iid)
                if not e: print('missing item', iid); continue
                slot = next((s for s in ['head', 'jumpsuit', 'outerClothing', 'shoes', 'gloves', 'mask', 'neck', 'eyes', 'belt', 'back']
                             if s in str(e['components'].get('Clothing', {}).get('slots', '')).lower().replace('outerclothing', 'outerclothing')), None)
                slot = slot or guess_slot(iid)
                k = item(iid, slot)
                if k: its[slot] = k
            if its: o.append({'id': oid, 'name': ITEMS[next(iter(its.values()))]['name'], 'items': its})
        if o: gs.append({'id': gid, 'name': name, 'min': 1, 'options': o})
    b = {}
    for iid in base:
        slot = guess_slot(iid); k = item(iid, slot)
        if k: b[slot] = k
    return {'base': b, 'groups': gs}
def guess_slot(iid):
    for pre, slot in [('ClothingHead', 'head'), ('ClothingUniform', 'jumpsuit'), ('ClothingOuter', 'outerClothing'),
                      ('ClothingShoes', 'shoes'), ('ClothingHands', 'gloves'), ('ClothingMask', 'mask'),
                      ('ClothingNeck', 'neck'), ('ClothingEyes', 'eyes'), ('ClothingBelt', 'belt'), ('ClothingBack', 'back')]:
        if iid.startswith(pre): return slot
    return 'jumpsuit'
HAT = ('WastelandHat', 'Hat', [('cowboy', ['ClothingHeadHatCowboyBrown']), ('cowboyblack', ['ClothingHeadHatCowboyBlack']),
                               ('flatcap', ['ClothingHeadHatBrownFlatcap']), ('fedora', ['ClothingHeadHatFedoraBrown'])])
N14_OUTFITS = {
    'N14TownMayor': (['ClothingShoesLeather'], [('MayorSuit', 'Suit', [('suit', ['ClothingUniformJumpsuitLawyerBlack']), ('flannel', ['ClothingUniformJumpsuitFlannel'])]),
                                                ('MayorHat', 'Hat', [('fedora', ['ClothingHeadHatFedoraGrey']), ('cowboy', ['ClothingHeadHatCowboyWhite'])])]),
    'N14TownSheriff': (['ClothingShoesBootsCowboyBrown'], [('MarshalClothes', 'Clothes', [('flannel', ['ClothingUniformJumpsuitFlannel']), ('detective', ['ClothingUniformJumpsuitDetective'])]),
                                                          ('MarshalHat', 'Hat', [('bounty', ['ClothingHeadHatCowboyBountyHunter']), ('cowboy', ['ClothingHeadHatCowboyBrown'])]),
                                                          ('MarshalVest', 'Vest', [('vest', ['ClothingOuterVestDetective']), ('poncho', ['ClothingOuterPonchoClassic'])])]),
    'N14TownDeputy': (['ClothingShoesBootsCowboyBlack'], [('GuardClothes', 'Clothes', [('flannel', ['ClothingUniformJumpsuitFlannel'])]), ('GuardHat', 'Hat', [('cowboy', ['ClothingHeadHatCowboyBlack'])]),
                                                         ('GuardVest', 'Vest', [('web', ['ClothingOuterVestWeb'])])]),
    'N14TownDoctor': (['ClothingShoesColorBrown'], [('DocClothes', 'Clothes', [('doctor', ['ClothingUniformJumpsuitMedicalDoctor'])]), ('DocCoat', 'Coat', [('lab', ['ClothingOuterCoatLab'])])]),
    'N14TownMechanic': (['ClothingShoesBootsWork', 'ClothingHandsGlovesColorBrown'], [('MechClothes', 'Clothes', [('overalls', ['ClothingUniformOveralls'])]), ('MechHat', 'Headgear', [('welding', ['ClothingHeadHatWelding']), ('band', ['ClothingHeadBandBrown'])])]),
    'N14TownShopkeeper': (['ClothingShoesColorBrown'], [('ShopClothes', 'Clothes', [('flannel', ['ClothingUniformJumpsuitFlannel'])]), ('ShopApron', 'Vest', [('vest', ['ClothingOuterVest'])])]),
    'N14TownBartender': (['ClothingShoesColorBlack'], [('BarClothes', 'Clothes', [('bartender', ['ClothingUniformJumpsuitBartender'])]), HAT]),
    'N14TownReporter': (['ClothingShoesLeather'], [('RepClothes', 'Clothes', [('reporter', ['ClothingUniformJumpsuitJournalist'])]), ('RepHat', 'Hat', [('press', ['ClothingHeadHatFedoraPress'])]), ('RepVest', 'Vest', [('press', ['ClothingOuterVestPress'])])]),
    'N14Farmer': (['ClothingShoesBootsCowboyBrown'], [('FarmClothes', 'Clothes', [('overalls', ['ClothingUniformOveralls'])]), ('FarmHat', 'Hat', [('sombrero', ['ClothingHeadHatSombrero']), ('cowboy', ['ClothingHeadHatCowboyBrown'])])]),
    'N14Townsperson': (['ClothingShoesColorBrown'], [('TownClothes', 'Clothes', [('flannel', ['ClothingUniformJumpsuitFlannel']), ('overalls', ['ClothingUniformOveralls'])]), HAT]),
    'N14CaravanLeader': (['ClothingShoesBootsCowboyFancy'], [('CaravanClothes', 'Clothes', [('flannel', ['ClothingUniformJumpsuitFlannel'])]), ('CaravanHat', 'Hat', [('white', ['ClothingHeadHatCowboyWhite'])]), ('CaravanCoat', 'Coat', [('poncho', ['ClothingOuterPonchoClassic']), ('bomber', ['ClothingOuterCoatBomber'])])]),
    'N14CaravanTrader': (['ClothingShoesBootsCowboyBrown'], [('TraderClothes', 'Clothes', [('flannel', ['ClothingUniformJumpsuitFlannel'])]), HAT, ('TraderCoat', 'Coat', [('poncho', ['ClothingOuterPoncho'])])]),
    'N14CaravanGuard': (['ClothingShoesBootsCowboyBlack'], [('CGuardClothes', 'Clothes', [('merc', ['ClothingUniformJumpsuitMercenary'])]), ('CGuardVest', 'Vest', [('web', ['ClothingOuterVestWebMerc'])]), ('CGuardMask', 'Mask', [('bandana', ['ClothingMaskBandanaBase'])])]),
    'N14Scavenger': (['ClothingShoesBootsWork', 'ClothingHandsGlovesLeather'], [('ScavClothes', 'Clothes', [('overalls', ['ClothingUniformOveralls'])]), ('ScavMask', 'Mask', [('gas', ['ClothingMaskGasExplorer']), ('bandana', ['ClothingMaskBandanaBase'])]), ('ScavBag', 'Bag', [('satchel', ['ClothingBackpackSatchelLeather'])])]),
    'N14Wastelander': (['ClothingShoesBootsCowboyBrown'], [('WasteClothes', 'Clothes', [('flannel', ['ClothingUniformJumpsuitFlannel']), ('overalls', ['ClothingUniformOveralls'])]), ('WasteCoat', 'Coat', [('poncho', ['ClothingOuterPonchoClassic'])]), HAT]),
    'N14WasteTrader': (['ClothingShoesBootsCowboyBrown'], [('WTClothes', 'Clothes', [('flannel', ['ClothingUniformJumpsuitFlannel'])]), ('WTCoat', 'Coat', [('poncho', ['ClothingOuterPoncho'])]), HAT]),
    'N14Musician': (['ClothingShoesLeather'], [('MusClothes', 'Clothes', [('musician', ['ClothingUniformJumpsuitMusician'])]), HAT]),
    'N14Survivor': (['ClothingShoesColorBrown'], [('SurvClothes', 'Clothes', [('overalls', ['ClothingUniformOveralls']), ('flannel', ['ClothingUniformJumpsuitFlannel'])]), ('SurvMask', 'Mask', [('gas', ['ClothingMaskGas'])])]),
}
for jid, (base, groups) in N14_OUTFITS.items():
    JOBS[jid] = custom_job(base, groups)

# Wardrobe: every item any job can wear, plus extras, grouped by slot.
EXTRAS = ['ClothingHeadHatCowboyBrown', 'ClothingHeadHatCowboyBlack', 'ClothingHeadHatCowboyGrey', 'ClothingHeadHatCowboyRed',
          'ClothingHeadHatCowboyWhite', 'ClothingHeadHatCowboyBountyHunter', 'ClothingHeadHatSombrero', 'ClothingHeadHatFedoraBrown',
          'ClothingHeadHatFedoraGrey', 'ClothingHeadHatBrownFlatcap', 'ClothingHeadHatWelding', 'ClothingHeadHatAnimalCatBrown',
          'ClothingHeadBandBrown', 'ClothingOuterPonchoClassic', 'ClothingOuterPoncho', 'ClothingOuterCoatBomber',
          'ClothingOuterFlannelRed', 'ClothingOuterFlannelBlue', 'ClothingOuterFlannelGreen', 'ClothingOuterVest',
          'ClothingOuterVestWeb', 'ClothingUniformJumpsuitFlannel', 'ClothingUniformOveralls', 'ClothingUniformJumpsuitMercenary',
          'ClothingShoesBootsCowboyBrown', 'ClothingShoesBootsCowboyBlack', 'ClothingShoesBootsCowboyWhite', 'ClothingShoesBootsCowboyFancy',
          'ClothingShoesSandalsBrown', 'ClothingMaskBandanaBase', 'ClothingMaskGas', 'ClothingEyesGlassesMercenary',
          'ClothingHandsGlovesLeather', 'ClothingHandsGlovesColorBrown', 'ClothingBackpackSatchelLeather']
for iid in EXTRAS: item(iid, guess_slot(iid))
for iid, slot in [(i, guess_slot(i)) for i in UP.of('entity') if re.match(r'ClothingUniformJumpsuitColor|ClothingUniformJumpskirtColor|ClothingHeadHatBeret|ClothingHeadHatHood|ClothingNeckScarfStriped|ClothingHeadHatAnimal|ClothingNeckCloak', i)]:
    e = UP.entity(iid)
    if e and not e.get('abstract') and not UP.get('entity', iid).get('abstract'): item(iid, slot)
WARDROBE = {}
for iid, it in ITEMS.items():
    WARDROBE.setdefault(it['slot'], []).append(iid)
for k in WARDROBE: WARDROBE[k].sort(key=lambda i: ITEMS[i]['name'].lower())

# ---------------------------------------------------------------- write
db = {'layers': LAYERS, 'species': SPECIES, 'markings': MARKINGS, 'items': ITEMS, 'jobs': JOBS, 'wardrobe': WARDROBE}
json.dump(db, open(os.path.join(OUT_DIR, 'character.json'), 'w'), separators=(',', ':'))
json.dump(SPRITES, open(os.path.join(os.path.dirname(__file__), 'sprite_licenses.json'), 'w'), indent=0)
print('species', len(SPECIES), [s['id'] for s in SPECIES])
print('markings', len(MARKINGS), 'items', len(ITEMS), 'jobs', len(JOBS), 'sprites', len(SPRITES))
