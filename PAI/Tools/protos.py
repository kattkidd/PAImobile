import yaml, os, glob, pickle
class L(yaml.CSafeLoader): pass
def _any(loader, suffix, node):
    if isinstance(node, yaml.MappingNode):
        d = loader.construct_mapping(node, deep=True); d['__tag'] = suffix; return d
    if isinstance(node, yaml.SequenceNode): return loader.construct_sequence(node, deep=True)
    v = loader.construct_scalar(node)
    return {'__tag': suffix} if v == '' else v
L.add_multi_constructor('!', _any)
SCR = '/tmp/claude-0/-home-claude/f57db88d-1d63-5e65-b707-f8c4973692a2/scratchpad'
ROOTS = {'ss14': SCR + '/ss14/repo', 'goob': SCR + '/forks/goob', 'starlight': SCR + '/forks/starlight', 'n14': SCR + '/forks/n14'}
def load_all(name):
    cache = f'{SCR}/char/cache_{name}.pkl'
    if os.path.exists(cache):
        return pickle.load(open(cache, 'rb'))
    root = ROOTS[name]; out = []
    for p in glob.glob(os.path.join(root, 'Resources/Prototypes/**/*.yml'), recursive=True):
        try:
            with open(p, encoding='utf-8-sig') as f:
                d = yaml.load(f, Loader=L)
        except Exception:
            continue
        if isinstance(d, list):
            for x in d:
                if isinstance(x, dict) and 'type' in x:
                    x['__file'] = os.path.relpath(p, root); out.append(x)
    pickle.dump(out, open(cache, 'wb'))
    return out
class Protos:
    def __init__(self, name):
        self.name = name; self.root = ROOTS[name]
        self.all = load_all(name)
        self.t = {}
        for p in self.all:
            if isinstance(p.get('id'), str):
                self.t.setdefault(p['type'], {})[p['id']] = p
        self._ent = {}
    def get(self, t, i): return self.t.get(t, {}).get(i)
    def of(self, t): return self.t.get(t, {})
    def entity(self, eid, depth=0):
        """Resolved entity: dict with name, description, components{type: merged dict}."""
        if eid in self._ent: return self._ent[eid]
        raw = self.get('entity', eid)
        if raw is None or depth > 40: return None
        parents = raw.get('parent') or []
        if isinstance(parents, str): parents = [parents]
        res = {'id': eid, 'name': None, 'description': None, 'components': {}, 'abstract': raw.get('abstract', False)}
        for par in parents:
            pr = self.entity(par, depth + 1)
            if not pr: continue
            if pr['name'] and not res['name']: res['name'] = pr['name']
            if pr['description'] and not res['description']: res['description'] = pr['description']
            for ct, c in pr['components'].items():
                res['components'][ct] = merge_keep(res['components'].get(ct), c)
        if raw.get('name'): res['name'] = raw['name']
        if raw.get('description'): res['description'] = raw['description']
        for c in raw.get('components') or []:
            if not isinstance(c, dict) or 'type' not in c: continue
            ct = c['type']
            res['components'][ct] = merge_keep(c, res['components'].get(ct))
        self._ent[eid] = res
        return res

def merge_keep(a, b):
    """Recursive merge where a's values win; b fills gaps."""
    if a is None: return b
    if b is None: return a
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(b)
        for k, v in a.items():
            out[k] = merge_keep(v, b.get(k)) if isinstance(v, dict) else v
        return out
    return a
