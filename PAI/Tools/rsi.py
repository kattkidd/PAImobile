import json, os
import numpy as np
from PIL import Image
_meta = {}
def tex_root(root): return os.path.join(root, 'Resources/Textures')
def find_rsi(roots, path):
    """roots: ordered list of repo roots to search. path like Mobs/Species/Human/parts.rsi (optionally leading /Textures/)."""
    path = path.replace('/Textures/', '').lstrip('/')
    for r in roots:
        p = os.path.join(tex_root(r), path)
        if os.path.exists(os.path.join(p, 'meta.json')): return p
    return None
def meta(p):
    if p not in _meta:
        with open(os.path.join(p, 'meta.json'), encoding='utf-8-sig') as f: _meta[p] = json.load(f)
    return _meta[p]
def has_state(p, state):
    return any(s['name'] == state for s in meta(p)['states'])
def strip(p, state):
    """Returns (H x 4W x 4) uint8 array with frame 0 for dirs S,N,E,W, or None."""
    m = meta(p); size = (m['size']['x'], m['size']['y'])
    st = next((s for s in m['states'] if s['name'] == state), None)
    if st is None: return None
    f = os.path.join(p, state + '.png')
    if not os.path.exists(f): return None
    img = Image.open(f).convert('RGBA'); a = np.array(img)
    w, h = size; cols = max(1, a.shape[1] // w)
    dirs = st.get('directions', 1)
    delays = st.get('delays')
    nframes = len(delays[0]) if delays else 1
    out = np.zeros((h, w * 4, 4), np.uint8)
    for d in range(4):
        sd = d if d < dirs else 0
        idx = sd * nframes
        r, c = divmod(idx, cols)
        tile = a[r*h:(r+1)*h, c*w:(c+1)*w]
        if tile.shape[:2] != (h, w): return None
        out[:, d*w:(d+1)*w] = tile
    return out
def size_of(p): m = meta(p); return (m['size']['x'], m['size']['y'])
def license_of(p): m = meta(p); return m.get('license', ''), m.get('copyright', '')
