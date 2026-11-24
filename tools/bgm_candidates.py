#!/usr/bin/env python3
"""BGM candidate generator (stdlib only). Original melodies, 4 patterns.
Output: /private/tmp/claude-501/bgm_cand/pattern{1..4}.wav
"""
import math, random, re, struct, wave, os

SR = 44100
OUT = "/private/tmp/claude-501/bgm_cand"
NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
ACC = {'#': 1, 'b': -1, '': 0}
random.seed(7)
NOISE = [random.uniform(-1, 1) for _ in range(SR * 2)]


def midi(n):
    m = re.fullmatch(r'([A-G])([#b]?)(-?\d)', n)
    return NOTE[m[1]] + ACC[m[2]] + 12 * (int(m[3]) + 1)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def parse_mel(s):
    out, p = [], 0.0
    for tok in s.replace('|', ' ').split():
        n, d = tok.split(':')
        d = float(d)
        if n != 'R':
            out.append((p, d, midi(n)))
        p += d
    return out, p


def parse_chords(s):
    bars = []
    for bar in s.split('|'):
        chs = []
        for c in bar.split():
            m = re.fullmatch(r'([A-G])([#b]?)(m?)(7?)', c)
            root = 48 + NOTE[m[1]] + ACC[m[2]]
            iv = [0, 3 if m[3] else 4, 7] + ([10] if m[4] else [])
            chs.append((root, iv))
        bars.append(chs)
    return bars


# ---------------- synthesis ----------------
def env(i, n_on, a, r):
    t = i / SR
    if t < a:
        g = t / a
    else:
        g = 1.0
    if i > n_on:
        g *= math.exp(-(i - n_on) / (r * SR) * 5)
    return g


def synth(kind, f, dur, amp):
    rel = {'square': .05, 'sq50': .05, 'tri': .03, 'bell': .9, 'pluck': .3,
           'marimba': .4, 'toy': .6, 'saw': .12, 'pad': .25, 'stab': .04}[kind]
    n_on = int(dur * SR)
    n = n_on + int(rel * SR)
    out = [0.0] * n
    ph = 0.0
    lp = 0.0
    w = 2 * math.pi * f / SR
    if kind in ('square', 'sq50', 'stab'):
        duty = .5 if kind != 'square' else .25
        cut = 0.35 if kind != 'stab' else 0.2
        for i in range(n):
            ph = (ph + f / SR) % 1.0
            x = 1.0 if ph < duty else -1.0
            lp += cut * (x - lp)
            g = env(i, n_on, .004, rel)
            if kind == 'square':
                g *= 0.75 + 0.25 * math.exp(-i / SR * 6)
            out[i] = lp * g * amp
    elif kind == 'tri':
        for i in range(n):
            ph = (ph + f / SR) % 1.0
            x = 4 * abs(ph - .5) - 1
            s1 = math.sin(2 * math.pi * ph)
            out[i] = (0.6 * x + 0.5 * s1) * env(i, n_on, .003, rel) * amp
    elif kind in ('bell', 'toy'):
        ratio = 3.5 if kind == 'bell' else 4.0
        k = 2.2 if kind == 'bell' else 5.0
        for i in range(n):
            t = i / SR
            I = 2.2 * math.exp(-t * 7)
            x = math.sin(w * i + I * math.sin(w * ratio * i))
            g = math.exp(-t * k) * min(1, t / .002)
            if i > n_on:
                g *= math.exp(-(i - n_on) / SR * 6)
            out[i] = x * g * amp
    elif kind == 'pluck':
        for i in range(n):
            t = i / SR
            x = 0.0
            for h in range(1, 7):
                x += math.sin(w * h * i) / h * math.exp(-t * (3 + h * 4))
            out[i] = x * min(1, t / .002) * (1 if i <= n_on else math.exp(-(i - n_on) / SR * 12)) * amp
    elif kind == 'marimba':
        for i in range(n):
            t = i / SR
            x = math.sin(w * i) * math.exp(-t * 7) + 0.35 * math.sin(w * 4 * i) * math.exp(-t * 30) \
                + 0.15 * math.sin(w * 10 * i) * math.exp(-t * 80)
            out[i] = x * min(1, t / .001) * amp
    elif kind in ('saw', 'pad'):
        H = 8 if kind == 'saw' else 6
        for i in range(n):
            t = i / SR
            vib = 1 + (0.004 * math.sin(2 * math.pi * 5.5 * t) * min(1, t / .3) if kind == 'saw' else 0)
            x = 0.0
            for h in range(1, H + 1):
                x += math.sin(w * vib * h * i) / h * (0.85 ** h)
            if kind == 'pad':
                x += 0.6 * math.sin(w * 1.006 * i)
            a = .01 if kind == 'saw' else .06
            out[i] = x * env(i, n_on, a, rel) * amp
    return out


def drum(kind, amp):
    if kind == 'kick':
        n = int(.35 * SR); out = [0.0] * n; ph = 0.0
        for i in range(n):
            t = i / SR
            f = 48 + 110 * math.exp(-t * 30)
            ph += 2 * math.pi * f / SR
            out[i] = math.sin(ph) * math.exp(-t * 9) * amp
        return out
    if kind == 'snare':
        n = int(.22 * SR); out = [0.0] * n; lp = 0
        for i in range(n):
            t = i / SR
            lp += 0.5 * (NOISE[i] - lp)
            out[i] = (lp * math.exp(-t * 18) + 0.5 * math.sin(2 * math.pi * 190 * t) * math.exp(-t * 35)) * amp
        return out
    if kind in ('hat', 'ohat', 'shaker', 'crash'):
        d = {'hat': 70, 'ohat': 14, 'shaker': 35, 'crash': 2.2}[kind]
        n = int(min(2, 6 / d) * SR); out = [0.0] * n; prev = 0
        off = random.randint(0, SR // 2)
        for i in range(n):
            x = NOISE[(i + off) % len(NOISE)]
            hp = x - prev; prev = x
            t = i / SR
            g = math.exp(-t * d) * (min(1, t / .01) if kind == 'shaker' else 1)
            out[i] = hp * g * amp * 0.5
        return out
    if kind in ('clap', 'snap'):
        n = int(.2 * SR); out = [0.0] * n; lp = 0; prev = 0
        for i in range(n):
            t = i / SR
            x = NOISE[(i * 3) % len(NOISE)]
            lp += 0.6 * (x - lp)
            bp = lp - prev; prev = lp
            if kind == 'clap':
                g = sum(math.exp(-(t - o) * 120) for o in (0, .011, .022) if t >= o) * 0.5 + math.exp(-t * 20) * 0.4
            else:
                g = math.exp(-t * 90)
            out[i] = bp * g * amp * 1.4
        return out
    if kind == 'tom':
        n = int(.25 * SR); out = [0.0] * n; ph = 0
        for i in range(n):
            t = i / SR
            ph += 2 * math.pi * (110 + 60 * math.exp(-t * 20)) / SR
            out[i] = math.sin(ph) * math.exp(-t * 12) * amp
        return out


class Song:
    def __init__(self, bpm, total8, swing=0.5):
        self.bpm, self.swing = bpm, swing
        self.beat = 60.0 / bpm
        self.n = int(self.t(total8) * SR) + SR * 2
        self.bus = {k: [0.0] * self.n for k in ('lead', 'main')}

    def t(self, p):
        b = math.floor(p / 2); fr = p - 2 * b; sw = self.swing
        x = fr * sw if fr < 1 else sw + (fr - 1) * (1 - sw)
        return (b + x) * self.beat

    def put(self, samples, p, bus='main'):
        i0 = int(self.t(p) * SR); buf = self.bus[bus]
        for i, v in enumerate(samples):
            j = i0 + i
            if j >= self.n:
                break
            buf[j] += v

    def note(self, kind, p, d8, m, amp, bus='main', gate=0.9):
        dur = self.t(p + d8) - self.t(p)
        self.put(synth(kind, hz(m), dur * gate, amp), p, bus)

    def finish(self, path, end8):
        # lead delay (dotted 8th)
        lead = self.bus['lead']; dl = int(self.beat * 0.75 * SR)
        for i in range(dl, self.n):
            lead[i] += 0.28 * lead[i - dl]
        mix = [a + b for a, b in zip(lead, self.bus['main'])]
        # fade tail
        endi = min(self.n, int(self.t(end8) * SR) + int(1.2 * SR))
        mix = mix[:endi]
        fl = int(1.2 * SR)
        for k in range(fl):
            mix[endi - fl + k] *= (1 - k / fl) ** 2
        pk = max(abs(x) for x in mix) or 1
        g = 1.25 / pk
        norm = math.tanh(1.0)
        frames = bytearray()
        for x in mix:
            y = math.tanh(x * g * 0.8) / norm * 0.89
            frames += struct.pack('<h', int(max(-1, min(1, y)) * 32767))
        os.makedirs(OUT, exist_ok=True)
        with wave.open(path, 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes(bytes(frames))
        print(path, len(mix) / SR, 's')


def voicing(root, iv, center=60):
    notes = []
    for v in iv:
        m = root + v
        while m < center - 5: m += 12
        while m > center + 7: m -= 12
        notes.append(m)
    return notes


def render(cfg):
    sections = cfg['sections']
    total = 0
    for s in sections:
        total += len(parse_chords(s['chords'])) * 8
    song = Song(cfg['bpm'], total + 8, cfg.get('swing', 0.5))
    pos = 0
    for si, s in enumerate(sections):
        tr = s.get('tr', 0)
        bars = parse_chords(s['chords'])
        for txt, kind, amp in s['mel']:
            notes, ln = parse_mel(txt)
            assert abs(ln - len(bars) * 8) < 1e-6, (cfg['name'], si, ln)
            for p, d, m in notes:
                song.note(kind, pos + p, d, m + tr, amp, 'lead', s.get('gate', 0.85))
                if s.get('double'):
                    song.note(s['double'][0], pos + p, d, m + tr + s['double'][1], amp * s['double'][2], 'lead', 0.8)
        for b, chs in enumerate(bars):
            bp = pos + b * 8
            for ci, (root, iv) in enumerate(chs):
                cp = bp + ci * (8 / len(chs)); cl = 8 / len(chs)
                cfg['acc'](song, cp, cl, root + tr, iv, s)
            last = (b == len(bars) - 1)
            cfg['drums'](song, bp, b, last, s)
        if s.get('crash', True):
            song.put(drum('crash', 0.35), pos)
        pos += len(bars) * 8
    # ending: tonic hit
    root, iv = cfg['end']
    for m in voicing(root, iv, 66):
        song.note(cfg['endkind'], pos, 6, m, 0.13, 'lead', 1.0)
    song.note('tri', pos, 4, root - 12, 0.4)
    song.put(drum('kick', 0.8), pos)
    song.put(drum('crash', 0.4), pos)
    song.finish(os.path.join(OUT, cfg['name'] + '.wav'), pos + 8)


# ---------------- Pattern 1: folk-dance chiptune (A minor, 150) ----------------
P1_A = ("A4:2 C5:1 E5:1 D5:2 C5:1 B4:1 | G#4:2 B4:1 E5:1 D5:2 B4:2 | A4:1 C5:1 E5:1 A5:1 G5:2 E5:2 | "
        "F5:1 E5:1 D5:1 B4:1 G#4:2 B4:2 | A4:1 F4:1 A4:1 C5:1 F5:2 E5:2 | E5:1 D5:1 C5:1 G4:1 E5:2 C5:2 | "
        "D5:1 F5:1 A5:1 F5:1 E5:1 G#5:1 B5:1 G#5:1 | A5:4 R:2 E5:1 G#5:1")
P1_AC = "Am | E | Am | E | F | C | Dm E | Am"
P1_B = ("E5:3 D5:1 C5:2 E5:2 | D5:3 C5:1 B4:4 | C5:3 B4:1 A4:2 C5:2 | B4:2 G#4:2 E4:4 | "
        "F4:2 A4:2 C5:2 F5:2 | G5:3 F5:1 E5:2 D5:2 | C5:2 E5:2 A5:2 C6:2 | B5:2 G#5:2 E5:2 B4:2")
P1_BC = "C | G | Am | E | F | G | Am | E"


def acc1(s, p, l, root, iv, sec):
    for k in range(int(l)):
        m = root - 12 + (12 if k % 2 else 0)
        s.note('tri', p + k, 1, m, 0.42, gate=0.45)
    for k in range(1, int(l), 2):  # off-beat chord chirps
        for m in voicing(root, iv, 64):
            s.note('stab', p + k, 1, m, 0.045, gate=0.35)


def dr1(s, bp, b, last, sec):
    for k in (0, 4):
        s.put(drum('kick', 0.75), bp + k)
    for k in (2, 6):
        s.put(drum('snare', 0.38), bp + k)
    for k in range(16):
        s.put(drum('hat', 0.22 if k % 2 else 0.12), bp + k / 2)
    if last:
        for k in range(4):
            s.put(drum('snare', 0.2 + 0.05 * k), bp + 6 + k / 2)


PAT1 = dict(name='pattern1', bpm=150, acc=acc1, drums=dr1, end=(57, [0, 3, 7]), endkind='square', sections=[
    dict(chords=P1_AC, mel=[(P1_A, 'square', 0.22)]),
    dict(chords=P1_BC, mel=[(P1_B, 'sq50', 0.2)], gate=0.95),
    dict(chords=P1_AC, mel=[(P1_A, 'square', 0.2)], tr=2, double=('sq50', -12, 0.6)),
    dict(chords=P1_BC, mel=[(P1_B, 'square', 0.2)], tr=2, double=('sq50', 12, 0.35), gate=0.95),
])
PAT1['end'] = (59, [0, 3, 7])

# ---------------- Pattern 2: bright pop anthem (C major, 128) ----------------
P2_A = ("E5:1 E5:1 G5:2 E5:1 D5:1 C5:2 | D5:1 D5:1 G5:2 B4:4 | C5:1 C5:1 E5:2 A5:2 G5:2 | F5:2 E5:1 D5:1 C5:4 | "
        "E5:1 E5:1 G5:2 E5:1 D5:1 C5:2 | D5:1 E5:1 F5:2 G5:4 | A5:1 G5:1 E5:2 C5:1 D5:1 E5:2 | C5:6 R:2")
P2_AC = "C | G | Am | F | C | G | Am | F G"
P2_B = ("A5:3 G5:1 F5:2 C5:2 | B5:3 A5:1 G5:2 D5:2 | G5:2 E5:2 B4:2 E5:2 | A5:2 C6:2 B5:2 A5:2 | "
        "A5:3 G5:1 F5:2 A5:2 | B5:2 D6:2 B5:2 G5:2 | C6:4 G5:2 E5:2 | C6:6 R:2")
P2_BC = "F | G | Em | Am | F | G | C | C"


def acc2(s, p, l, root, iv, sec):
    for k in range(int(l)):
        m = root - 12 + (12 if k % 2 else 0)
        s.note('tri', p + k, 1, m, 0.4, gate=0.55)
    for k in range(1, int(l), 2):
        for m in voicing(root, iv, 62):
            s.note('pluck', p + k, 1, m, 0.06, gate=0.5)
    if sec.get('arp'):
        vs = voicing(root, iv, 74)
        for k in range(int(l * 2)):
            s.note('bell', p + k / 2, 0.5, vs[k % 3] + (12 if k % 6 >= 3 else 0), 0.035, gate=0.5)


def dr2(s, bp, b, last, sec):
    for k in (0, 2, 4, 6):
        s.put(drum('kick', 0.8), bp + k)
    for k in (2, 6):
        s.put(drum('clap', 0.5), bp + k)
    for k in range(16):
        s.put(drum('hat', 0.16 if k % 2 else 0.09), bp + k / 2)
    for k in (1, 3, 5, 7):
        s.put(drum('ohat', 0.12), bp + k)
    if last:
        for k in range(8):
            s.put(drum('clap', 0.18 + 0.03 * k), bp + 4 + k / 2)


PAT2 = dict(name='pattern2', bpm=128, acc=acc2, drums=dr2, end=(50, [0, 4, 7]), endkind='bell', sections=[
    dict(chords=P2_AC, mel=[(P2_A, 'bell', 0.2), (P2_A, 'pluck', 0.1)]),
    dict(chords=P2_BC, mel=[(P2_B, 'bell', 0.2), (P2_B, 'pluck', 0.1)], arp=True),
    dict(chords=P2_AC, mel=[(P2_A, 'bell', 0.19), (P2_A, 'pluck', 0.1)], tr=2, arp=True,
         double=('bell', 12, 0.4)),
])

# ---------------- Pattern 3: cute bouncy shuffle (F major, 115) ----------------
P3_A = ("C5:1 A4:1 C5:2 R:2 F5:2 | E5:1 G5:1 E5:1 C5:1 R:4 | A4:1 C5:1 F5:1 A5:1 G5:2 F5:2 | D5:2 F5:2 E5:2 C5:2 | "
        "C5:1 A4:1 C5:2 R:2 A5:2 | A5:1 F5:1 D5:1 A4:1 R:4 | G4:1 Bb4:1 D5:1 G5:1 E5:2 G5:2 | F5:6 R:2")
P3_AR = ("R:8 | R:4 C6:1 Bb5:1 G5:2 | R:8 | R:8 | R:8 | R:4 D6:1 C6:1 A5:2 | R:8 | R:6 C6:1 F6:1")
P3_AC = "F | C7 | F | Bb C | F | Dm | Gm C7 | F"
P3_B1 = ("D5:1 F5:1 Bb5:2 A5:2 F5:2 | R:8 | Bb4:1 D5:1 G5:2 F5:2 D5:2 | R:8 | "
         "D5:1 F5:1 Bb5:2 C6:2 Bb5:2 | R:8 | Bb4:1 D5:1 G5:1 Bb5:1 C6:2 E5:2 | R:8")
P3_B2 = ("R:8 | C6:1 A5:1 F5:2 C5:4 | R:8 | E5:1 G5:1 C6:2 G5:4 | "
         "R:8 | A5:1 C6:1 A5:1 F5:1 C5:4 | R:8 | F5:1 A5:1 C6:2 F6:2 R:2")
P3_BC = "Bb | F | Gm | C7 | Bb | F | Gm C7 | F"


def acc3(s, p, l, root, iv, sec):
    pat = [(0, 0), (2, 7), (4, 12), (6, 7)] if l >= 8 else [(0, 0), (2, 7)]
    for k, o in pat:
        s.note('tri', p + k, 1, root - 12 + o, 0.45, gate=0.5)
    for k in range(1, int(l), 2):
        for m in voicing(root, iv, 64):
            s.note('pluck', p + k, 1, m, 0.05, gate=0.4)


def dr3(s, bp, b, last, sec):
    for k in (0, 4):
        s.put(drum('kick', 0.65), bp + k)
    for k in (2, 6):
        s.put(drum('snap', 0.55), bp + k)
    for k in range(8):
        s.put(drum('shaker', 0.12 if k % 2 else 0.07), bp + k)
    if last:
        for k in (5, 6, 7):
            s.put(drum('tom', 0.3), bp + k)


PAT3 = dict(name='pattern3', bpm=115, swing=0.64, acc=acc3, drums=dr3, end=(55, [0, 4, 7]), endkind='marimba',
            sections=[
                dict(chords=P3_AC, mel=[(P3_A, 'marimba', 0.32), (P3_AR, 'toy', 0.12)]),
                dict(chords=P3_BC, mel=[(P3_B1, 'marimba', 0.32), (P3_B2, 'toy', 0.14)]),
                dict(chords=P3_AC, mel=[(P3_A, 'marimba', 0.3), (P3_AR, 'toy', 0.12)], tr=2,
                     double=('toy', 12, 0.25)),
            ])

# ---------------- Pattern 4: epic adventure pop (D minor -> F major, 138) ----------------
P4_A = ("D5:3 A4:1 D5:2 F5:2 | E5:3 D5:1 C5:4 | A4:3 C5:1 F5:2 A5:2 | G5:2 E5:2 C5:4 | "
        "D5:3 A4:1 D5:2 F5:2 | Bb5:3 A5:1 F5:4 | G5:2 F5:2 E5:2 D5:2 | C#5:4 E5:2 A5:2")
P4_AC = "Dm | Bb | F | C | Dm | Bb | Gm | A"
P4_B = ("F5:2 G5:2 A5:3 F5:1 | G5:2 A5:2 C6:4 | A5:2 G5:2 E5:3 C5:1 | D5:2 F5:2 A5:4 | "
        "Bb5:2 A5:2 G5:2 F5:2 | E5:2 G5:2 C6:4 | C6:3 A5:1 F5:2 A5:2 | F5:6 R:2")
P4_BC = "Bb | C | Am | Dm | Bb | C | F | F"


def acc4(s, p, l, root, iv, sec):
    for k in range(int(l)):
        s.note('tri', p + k, 1, root - 12, 0.42, gate=0.6)
    for m in voicing(root, iv, 60):
        s.note('pad', p, l, m, 0.035, gate=0.95)


def dr4(s, bp, b, last, sec):
    for k in (0, 3, 4) if not sec.get('big') else (0, 2, 3, 4, 6):
        s.put(drum('kick', 0.8), bp + k)
    for k in (2, 6):
        s.put(drum('snare', 0.45), bp + k)
    for k in range(8):
        s.put(drum('hat', 0.15), bp + k + 0.0)
        s.put(drum('hat', 0.07), bp + k + 0.5)
    if b % 4 == 3 and not last:
        s.put(drum('tom', 0.3), bp + 7); s.put(drum('tom', 0.25), bp + 7.5)
    if last:
        for k in range(8):
            s.put(drum('snare', 0.15 + 0.04 * k), bp + 4 + k / 2)


PAT4 = dict(name='pattern4', bpm=138, acc=acc4, drums=dr4, end=(55, [0, 4, 7]), endkind='saw', sections=[
    dict(chords=P4_AC, mel=[(P4_A, 'saw', 0.14)], double=('square', -12, 0.5)),
    dict(chords=P4_BC, mel=[(P4_B, 'saw', 0.14)], double=('bell', 12, 0.5), big=True),
    dict(chords=P4_BC, mel=[(P4_B, 'saw', 0.14)], tr=2, double=('bell', 12, 0.6), big=True),
])

if __name__ == '__main__':
    for P in (PAT1, PAT2, PAT3, PAT4):
        render(P)
