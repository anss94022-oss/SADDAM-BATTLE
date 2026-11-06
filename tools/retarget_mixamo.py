#!/usr/bin/env python3
"""Retarget Mixamo (mixamorig) glTF clips onto the SADDAM BATTLE soldier skeleton.

World-space delta retargeting:
    D = R_src_global(t) * R_src_rest_global^-1
    R_tgt_global(t) = D * R_tgt_rest_global
    R_tgt_local(t) = R_tgt_parent_global(t)^-1 * R_tgt_global(t)
"""
import json, struct, sys, os
import numpy as np

FPS = 30

def load_glb(path):
    d = open(path, 'rb').read()
    off = 12
    js = None; b = None
    while off < len(d):
        clen, ct = struct.unpack('<II', d[off:off + 8]); off += 8
        ch = d[off:off + clen]; off += clen
        if ct == 0x4E4F534A:
            js = json.loads(ch)
        else:
            b = ch
    return js, b

def accessor(j, b, i):
    a = j['accessors'][i]
    bv = j['bufferViews'][a['bufferView']]
    dt = {5126: '<f4', 5123: '<u2', 5125: '<u4', 5121: '<u1'}[a['componentType']]
    n = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[a['type']]
    start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    arr = np.frombuffer(b, dtype=np.dtype(dt), count=a['count'] * n, offset=start)
    return arr.reshape(a['count'], n) if n > 1 else arr

def qnorm(q):
    q = np.asarray(q, dtype=np.float64)
    n = np.linalg.norm(q)
    return q / n if n > 1e-9 else np.array([0, 0, 0, 1.0])

def qmul(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
    return np.array([
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    ])

def qconj(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])

def qrot(q, v):
    qv = np.array([v[0], v[1], v[2], 0.0])
    r = qmul(qmul(q, qv), qconj(q))
    return r[:3]

def slerp(a, b, t):
    a = qnorm(a); b = qnorm(b)
    d = float(np.dot(a, b))
    if d < 0:
        b = -b; d = -d
    if d > 0.9995:
        return qnorm(a + t * (b - a))
    th0 = np.arccos(np.clip(d, -1, 1))
    th = th0 * t
    s0 = np.sin(th0 - th) / np.sin(th0)
    s1 = np.sin(th) / np.sin(th0)
    return qnorm(s0 * a + s1 * b)

def sample(times, vals, t, is_quat):
    if t <= times[0]:
        return vals[0]
    if t >= times[-1]:
        return vals[-1]
    i = int(np.searchsorted(times, t) - 1)
    i = max(0, min(i, len(times) - 2))
    span = times[i + 1] - times[i]
    f = 0.0 if span <= 1e-9 else (t - times[i]) / span
    if is_quat:
        return slerp(vals[i], vals[i + 1], f)
    return vals[i] + (vals[i + 1] - vals[i]) * f

MAP = {
    'Hips': 'Hips', 'Spine': 'Spine02', 'Spine1': 'Spine01', 'Spine2': 'Spine',
    'Neck': 'neck', 'Head': 'Head', 'HeadTop_End': 'head_end',
    'LeftShoulder': 'LeftShoulder', 'LeftArm': 'LeftArm', 'LeftForeArm': 'LeftForeArm',
    'LeftHand': 'LeftHand', 'RightShoulder': 'RightShoulder', 'RightArm': 'RightArm',
    'RightForeArm': 'RightForeArm', 'RightHand': 'RightHand',
    'LeftUpLeg': 'LeftUpLeg', 'LeftLeg': 'LeftLeg', 'LeftFoot': 'LeftFoot',
    'LeftToeBase': 'LeftToeBase', 'RightUpLeg': 'RightUpLeg', 'RightLeg': 'RightLeg',
    'RightFoot': 'RightFoot', 'RightToeBase': 'RightToeBase',
}

def clean(nm):
    return (nm or '').replace('mixamorig:', '')

class Skel:
    def __init__(self, j):
        self.j = j
        self.parent = {}
        for i, n in enumerate(j['nodes']):
            for c in n.get('children', []):
                self.parent[c] = i
        self.rest = []
        for n in j['nodes']:
            self.rest.append(qnorm(np.array(n.get('rotation', [0, 0, 0, 1]), dtype=np.float64)))
        self.rest_global = {}
        self.trans = [np.array(n.get('translation', [0, 0, 0]), dtype=np.float64) for n in j['nodes']]

    def global_rot(self, locals_):
        g = {}
        roots = [i for i in range(len(self.j['nodes'])) if i not in self.parent]
        stack = [(i, np.array([0, 0, 0, 1.0])) for i in roots]
        while stack:
            i, pg = stack.pop()
            gg = qmul(pg, locals_[i])
            g[i] = gg
            for c in self.j['nodes'][i].get('children', []):
                stack.append((c, gg))
        return g

    def rest_global_map(self):
        if not self.rest_global:
            self.rest_global = self.global_rot(self.rest)
        return self.rest_global


def quat_from_two_vectors(a, b):
    a = a / max(np.linalg.norm(a), 1e-9)
    b = b / max(np.linalg.norm(b), 1e-9)
    d = float(np.dot(a, b))
    if d > 0.999999:
        return np.array([0, 0, 0, 1.0])
    if d < -0.999999:
        axis = np.cross(np.array([1.0, 0, 0]), a)
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(np.array([0, 1.0, 0]), a)
        axis = axis / np.linalg.norm(axis)
        return np.array([axis[0], axis[1], axis[2], 0.0])
    axis = np.cross(a, b)
    ang = np.arccos(np.clip(d, -1.0, 1.0))
    n = np.linalg.norm(axis)
    axis = axis / n
    s2 = np.sin(ang / 2.0)
    return np.array([axis[0] * s2, axis[1] * s2, axis[2] * s2, np.cos(ang / 2.0)])


IDENT = np.array([0.0, 0.0, 0.0, 1.0])


def retarget(src_path, clip_name, tgt_j, tgt_b, tgt_skel):
    sj, sb = load_glb(src_path)
    src = Skel(sj)
    names = {clean(n.get('name')): i for i, n in enumerate(sj['nodes'])}
    anim = sj['animations'][0]

    # gather channels
    rot_ch = {}   # node index -> (times, values)
    trans_ch = {}
    duration = 0.0
    for ch in anim['channels']:
        s = anim['samplers'][ch['sampler']]
        node = ch['target']['node']
        times = accessor(sj, sb, s['input']).astype(np.float64)
        vals = accessor(sj, sb, s['output']).astype(np.float64)
        duration = max(duration, float(times[-1]))
        if ch['target']['path'] == 'rotation':
            rot_ch[node] = (times, vals)
        elif ch['target']['path'] == 'translation':
            trans_ch[node] = (times, vals)
    if duration <= 0:
        duration = 1.0

    src_rest_g = src.rest_global_map()
    tgt_rest_g = tgt_skel.rest_global_map()

    # build name->index maps
    tgt_idx = {}
    for i, n in enumerate(tgt_j['nodes']):
        tgt_idx[clean(n.get('name'))] = i

    pairs = []  # (src_node, tgt_node)
    for sname, tname in MAP.items():
        if sname in names and tname in tgt_idx:
            pairs.append((names[sname], tgt_idx[tname]))

    hips_src = names.get('Hips')
    hips_tgt = tgt_idx.get('Hips')
    hips_rest_tgt = np.array(tgt_j['nodes'][hips_tgt].get('translation', [0, 0, 0]), dtype=np.float64)
    hips_rest_src = np.array(sj['nodes'][hips_src].get('translation', [0, 0, 0]), dtype=np.float64)

    nframes = int(round(duration * FPS)) + 1
    times_out = np.array([i / FPS for i in range(nframes)])
    rot_out = {tgt: np.zeros((nframes, 4)) for (_, tgt) in pairs}
    trans_out = None
    if hips_src in trans_ch:
        trans_out = np.zeros((nframes, 3))

    # target hierarchy traversal order (root first)
    order = []
    def walk(i):
        order.append(i)
        for c in tgt_j['nodes'][i].get('children', []):
            walk(c)
    for r in tgt_j['scenes'][0]['nodes']:
        walk(r)
    pos_in_order = {n: k for k, n in enumerate(order)}
    pairs_sorted = sorted(pairs, key=lambda p: pos_in_order[p[1]])

    # fixed per-bone correction: rotate the target rest bone direction onto the
    # source rest bone direction (grip3d A-pose -> mixamo T-pose)
    CORR = {}
    for s_node, t_node in pairs:
        d_src = qrot(src_rest_g[s_node], np.array([0.0, 1.0, 0.0]))
        d_tgt = qrot(tgt_rest_g[t_node], np.array([0.0, 1.0, 0.0]))
        c = quat_from_two_vectors(d_tgt, d_src)
        if abs(1.0 - float(np.dot(qnorm(c), np.array([0, 0, 0, 1.0])))) > 1e-6:
            CORR[t_node] = qnorm(c)
        print('   corr', tgt_j['nodes'][t_node].get('name'), round(np.degrees(2*np.arccos(min(1.0, abs(c[3])))), 1))

    tgt_parent = tgt_skel.parent

    for fi, t in enumerate(times_out):
        # source global rotations at t
        src_local = list(src.rest)
        for node, (times, vals) in rot_ch.items():
            src_local[node] = qnorm(sample(times, vals, t, True))
        sg = src.global_rot(src_local)

        tgt_global = {}
        for s_node, t_node in pairs:
            d = qmul(sg[s_node], qconj(src_rest_g[s_node]))
            if fi == 0:
                pass
            corr = CORR.get(t_node, IDENT)
            tgt_global[t_node] = qmul(qmul(d, corr), tgt_rest_g[t_node])

        for t_node in order:
            if t_node in tgt_global:
                p = tgt_parent.get(t_node)
                pg = tgt_global.get(p, tgt_rest_g[p]) if p is not None else np.array([0, 0, 0, 1.0])
                rot_out[t_node][fi] = qnorm(qmul(qconj(pg), tgt_global[t_node]))
            else:
                rot_out.setdefault(t_node, np.zeros((nframes, 4)))
                rot_out[t_node][fi] = tgt_skel.rest[t_node]

        if trans_out is not None:
            times, vals = trans_ch[hips_src]
            tr = sample(times, vals, t, False)
            delta = (tr - hips_rest_src) * 100.0
            # keep in-place: drop horizontal drift (gameplay moves the character)
            delta[0] = 0.0
            delta[2] = 0.0
            trans_out[fi] = hips_rest_tgt + delta

    return clip_name, times_out, rot_out, trans_out, duration


def add_clip(j, bin_chunks, name, times, rot_out, trans_out, tgt_idx):
    bufviews = j['bufferViews']
    accessors = j['accessors']
    offset = sum(len(c) for c in bin_chunks)
    new_bins = []
    blob = bytearray()

    def push(arr, typ, comp=5126):
        nonlocal blob
        raw = np.ascontiguousarray(arr, dtype='<f4').tobytes()
        while len(blob) % 4:
            blob += b'\0'
        bv_index = len(bufviews)
        bufviews.append({'buffer': 0, 'byteOffset': offset + len(blob), 'byteLength': len(raw)})
        blob += raw
        acc = {'bufferView': bv_index, 'componentType': comp, 'count': int(arr.shape[0]),
               'type': typ}
        if typ == 'VEC4':
            acc['min'] = [float(x) for x in arr.min(0)]
            acc['max'] = [float(x) for x in arr.max(0)]
        accessors.append(acc)
        return len(accessors) - 1

    time_acc = push(times.reshape(-1, 1), 'SCALAR')
    samplers = []
    channels = []
    for t_node, frames in rot_out.items():
        val_acc = push(frames, 'VEC4')
        samplers.append({'input': time_acc, 'output': val_acc, 'interpolation': 'LINEAR'})
        channels.append({'sampler': len(samplers) - 1,
                         'target': {'node': t_node, 'path': 'rotation'}})
    if trans_out is not None:
        tacc = push(trans_out, 'VEC3')
        samplers.append({'input': time_acc, 'output': tacc, 'interpolation': 'LINEAR'})
        channels.append({'sampler': len(samplers) - 1,
                         'target': {'node': tgt_idx['Hips'], 'path': 'translation'}})

    j.setdefault('animations', []).append({
        'name': name, 'samplers': samplers, 'channels': channels
    })
    return bytes(blob)


def main():
    hero = sys.argv[1]
    out = sys.argv[2]
    clips = sys.argv[3:]   # name=path

    j, b = load_glb(hero)
    tgt = Skel(j)
    tgt_idx = {clean(n.get('name')): i for i, n in enumerate(j['nodes'])}
    bin_chunks = [b]
    j['animations'] = []   # drop the original grab3d clips, Mixamo ones replace them

    for spec in clips:
        name, path = spec.split('=', 1)
        cname, times, rot_out, trans_out, dur = retarget(path, name, j, b, tgt)
        extra = add_clip(j, bin_chunks, cname, times, rot_out, trans_out, tgt_idx)
        bin_chunks.append(extra)
        print(f'  {name}: {dur:.2f}s, {len(times)} frames, {len(rot_out)} bones')

    # rebuild binary
    total = sum(len(c) for c in bin_chunks)
    raw = b''.join(bin_chunks)
    while len(raw) % 4:
        raw += b'\0'
    j['buffers'] = [{'byteLength': len(raw)}]

    js = json.dumps(j, separators=(',', ':')).encode('utf-8')
    while len(js) % 4:
        js += b' '
    total_len = 12 + 8 + len(js) + 8 + len(raw)
    with open(out, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total_len))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(raw), 0x004E4942)); f.write(raw)
    print('wrote', out, os.path.getsize(out), 'bytes; animations:',
          [a['name'] for a in j['animations']])

if __name__ == '__main__':
    main()
