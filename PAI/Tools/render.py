"""Reference renderer — same algorithm as CharacterRenderer.swift. Used to verify layering/alignment."""
import json, os, colorsys
import numpy as np
from PIL import Image

class DB:
    def __init__(self, out):
        self.out = out
        self.d = json.load(open(os.path.join(out, 'character.json')))
        self.species = {s['id']: s for s in self.d['species']}
        self._cache = {}
    def strip(self, key):
        if key not in self._cache:
            self._cache[key] = np.array(Image.open(os.path.join(self.out, 'Sprites', key + '.png')).convert('RGBA')).astype(np.float32) / 255
        return self._cache[key]
    def tile(self, key, d):
        return self.strip(key)[:, d * 32:(d + 1) * 32]

def hx(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] + [1.0], np.float32)

def displace(img, dmap):
    out = np.zeros_like(img)
    a = (dmap[:, :, 3] > 0)
    dx = np.round(dmap[:, :, 0] * 255 - 128).astype(int); dy = np.round(dmap[:, :, 1] * 255 - 128).astype(int)
    for y in range(32):
        for x in range(32):
            if not a[y, x]: continue
            sx, sy = x + dx[y, x], y + dy[y, x]
            if 0 <= sx < 32 and 0 <= sy < 32:
                out[y, x] = img[sy, sx] * dmap[y, x, 3]
    return out

def over(dst, src):
    # straight alpha over
    sa = src[:, :, 3:4]; da = dst[:, :, 3:4]
    oa = sa + da * (1 - sa)
    rgb = np.where(oa > 0, (src[:, :, :3] * sa + dst[:, :, :3] * da * (1 - sa)) / np.maximum(oa, 1e-6), 0)
    return np.concatenate([rgb, oa], 2)

def resolve_rules(rules, prof, db):
    for r in rules:
        neg = r.startswith('neg:'); r2 = r[4:] if neg else r
        c = None
        if r2 == 'none': c = '#FFFFFF'
        elif r2 == 'skin': c = prof['skin']
        elif r2 == 'eyes': c = prof['eyes']
        elif r2 == 'tattoo':
            rgb = hx(prof['skin'])[:3]; h, s, v = colorsys.rgb_to_hsv(*rgb); rr = colorsys.hsv_to_rgb(h, s, 0.4)
            c = '#%02X%02X%02X' % tuple(int(x * 255) for x in rr)
        elif r2.startswith('cat:'):
            cat = r2[4:]
            for mid, cols in prof['markings']:
                m = db.d['markings'].get(mid)
                if m and m['cat'] == cat:
                    c = prof['hair'] if cat in ('Hair', 'FacialHair') else (cols[0] if cols else None); break
        elif r2.startswith('#'): c = r2
        if c:
            if neg:
                v = hx(c); c = '#%02X%02X%02X' % tuple(int((1 - x) * 255) for x in v[:3])
            return c
    return '#FFFFFF'

def default_marking_colors(mid, prof, db):
    m = db.d['markings'][mid]
    if m['cat'] in ('Hair', 'FacialHair'): return [prof['hair']] * len(m['sprites'])
    return [resolve_rules(r, prof, db) for r in m['colors']]

def render(db, prof, d):
    sp = db.species[prof['species']]; sex = prof['sex']
    canvas = np.zeros((32, 32, 4), np.float32)
    def draw(key, color, disp=None, alpha=1.0):
        nonlocal canvas
        if not key: return
        t = db.tile(key, d).copy()
        t = t * hx(color)
        t[:, :, 3] *= alpha
        if disp: t = displace(t, db.tile(disp, d))
        canvas = over(canvas, t)
    bd = sp.get('bodyDisplace')
    for layer in db.d['layers']:
        if layer.startswith('slot:'):
            slot = layer[5:]; iid = prof['outfit'].get(slot)
            if not iid: continue
            it = db.d['items'][iid]
            suf = sp.get('clothingSuffix')
            if suf and suf in it['species']:
                draw(it['species'][suf], '#FFFFFF'); continue
            disp = (sp['displaceFemale'] if sex == 'Female' else sp['displaceMale']).get(slot) or sp['displace'].get(slot)
            for l in it['layers']: draw(l['sprite'], l['color'] or '#FFFFFF', disp)
            continue
        for p in sp['parts'] + ([sp['eyes']] if sp.get('eyes') else []):
            if p['layer'] != layer: continue
            key = (p.get('bySex') or {}).get(sex) or p.get('sprite')
            col = {'skin': prof['skin'], 'eyes': prof['eyes'], 'none': '#FFFFFF'}[p['color']]
            draw(key, col, bd, p.get('alpha', 1.0))
        app = sp.get('appearances', {}).get(layer, {})
        for mid, cols in prof['markings']:
            m = db.d['markings'].get(mid)
            if not m or m['layer'] != layer: continue
            for i, key in enumerate(m['sprites']):
                c = prof['skin'] if app.get('matchSkin') else cols[min(i, len(cols) - 1)]
                draw(key, c, bd, app.get('alpha', 1.0))
    return canvas

def default_profile(db, sid, sex=None, job='Captain'):
    sp = db.species[sid]
    prof = {'species': sid, 'sex': sex or sp['sexes'][0], 'skin': sp['skin']['default'], 'eyes': '#4A7A3A',
            'hair': '#4E3628', 'markings': [], 'outfit': {}}
    for lim in sp['limits']:
        for mid in lim['defaults']:
            prof['markings'].append((mid, None))
    # pick a hair
    hair = [m for m in sp['markings'] if db.d['markings'][m]['cat'] == 'Hair']
    if hair: prof['markings'].append((hair[min(5, len(hair) - 1)], None))
    prof['markings'] = [(m, default_marking_colors(m, prof, db)) for m, _ in prof['markings']]
    j = db.d['jobs'].get(job)
    if j:
        prof['outfit'].update(j['base'])
        for g in j['groups']:
            prof['outfit'].update(g['options'][0]['items'])
    return prof

def to_img(c, scale=4):
    a = (np.clip(c, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(a, 'RGBA').resize((32 * scale, 32 * scale), Image.NEAREST)
