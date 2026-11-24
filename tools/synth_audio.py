"""AI社員09: 全オリジナル音源をプロシージャル合成（標準ライブラリのみ）。
加算/FM合成, ADSR, ノイズ, ピッチ変化, ディレイ, 簡易リバーブ, ソフトリミッター。"""
import math, random, struct, wave, os, sys
SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "EvolutionDNARun/Audio"
os.makedirs(OUT, exist_ok=True)
random.seed(7)

def env(n, a, d, s, r, total):
    out = []
    for i in range(total):
        t = i / SR
        if t < a: v = t / a if a else 1
        elif t < a + d: v = 1 - (1 - s) * (t - a) / d
        elif t < n: v = s
        else: v = s * max(0.0, 1 - (t - n) / r)
        out.append(v)
    return out

def tone(freq, dur, a=0.005, d=0.08, s=0.3, r=0.1, fm=0.0, ratio=2.0, glide=0.0, harm=(1,), amp=1.0):
    total = int((dur + r) * SR); e = env(dur, a, d, s, r, total); ph = 0; mph = 0; out = []
    for i in range(total):
        t = i / SR; f = freq * (1 + glide * t / max(dur, 1e-3))
        mph += 2 * math.pi * f * ratio / SR
        ph += 2 * math.pi * f / SR + fm * math.sin(mph) * 2 * math.pi * f / SR * e[i]
        v = sum(math.sin(ph * (k + 1)) * h for k, h in enumerate(harm))
        out.append(v * e[i] * amp)
    return out

def noise(dur, a=0.002, r=0.1, amp=1.0, lp=0.3):
    total = int((dur + r) * SR); e = env(dur, a, dur, 0.0, r, total); y = 0; out = []
    for i in range(total):
        y += lp * (random.uniform(-1, 1) - y); out.append(y * e[i] * amp)
    return out

def mix(*parts, length=None):
    L = length or max(len(p) + o for p, o in parts); out = [0.0] * L
    for p, o in parts:
        for i, v in enumerate(p):
            if 0 <= i + o < L: out[i + o] += v
    return out

def delay(x, t=0.18, fb=0.35, wet=0.3):
    D = int(t * SR); y = list(x) + [0.0] * D * 4
    for i in range(D, len(y)): y[i] += y[i - D] * fb * wet / 0.3 * 0.3
    return y

def reverb(x, wet=0.25):
    out = list(x) + [0.0] * int(SR * 0.6)
    for dt, g in ((0.0297, .7), (0.0371, .65), (0.0411, .6), (0.0437, .55)):
        D = int(dt * SR); buf = [0.0] * len(out)
        for i in range(len(out)):
            buf[i] = (out[i] if i < len(x) else 0) + (buf[i - D] * g if i >= D else 0)
        for i in range(len(out)): out[i] += buf[i] * wet / 4
    return out

def save(name, x, peak=0.85):
    m = max(1e-9, max(abs(v) for v in x)); g = peak / m
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(32767 * math.tanh(v * g * 1.1) / math.tanh(1.1))) for v in x))

N = lambda m: 440 * 2 ** ((m - 69) / 12)
PENTA = [72, 74, 76, 79, 81, 84, 86, 88]  # C major pentatonic

# 増殖ポップ 3案（A:バブル FM / B:ガラス加算 / C:ピチカート+ノイズ）
for i, m in enumerate(PENTA):
    f = N(m)
    save(f"pop_a_{i}", tone(f, 0.04, d=0.05, s=0.0, r=0.06, fm=1.5, ratio=1.0, glide=-0.4, amp=.8))
    save(f"pop_b_{i}", tone(f, 0.05, d=0.1, s=0.0, r=0.12, harm=(1, .3, 0, .15)))
    save(f"pop_c_{i}", mix((tone(f, 0.03, d=0.04, s=0, r=0.05, glide=0.6, harm=(1, .4)), 0), (noise(0.01, r=0.02, amp=.3, lp=.6), 0)))

save("gate_mul", reverb(mix(*[(tone(N(m), 0.08, s=.2, r=.15, harm=(1, .3)), j * 2200) for j, m in enumerate([72, 76, 79, 84])])))
save("gate_big", reverb(mix((tone(N(48), .4, a=.01, d=.3, s=.2, r=.3, harm=(1, .5, .3, .2)), 0), (tone(N(72), .5, glide=1.0, harm=(1, .3), amp=.5), 0), *[(tone(N(m), .08, s=0, r=.3, amp=.4), 4000 + j * 1800) for j, m in enumerate([96, 100, 103, 108])])))
save("gate_bad", tone(N(60), .25, d=.2, s=.3, r=.15, glide=-.35, fm=.8, ratio=1.5, harm=(1, .4)))
save("evolve", reverb(mix((noise(.8, a=.7, r=.1, amp=.5, lp=.05), 0), (tone(N(60), 1.0, a=.6, glide=1.0, fm=.6, ratio=3, amp=.4), 0), *[(tone(N(m), .3, s=.4, r=.6, harm=(1, .3, .1), amp=.5), int(SR * .9)) for m in (72, 76, 79, 84)], (tone(N(36), .4, d=.3, s=.1, r=.3, harm=(1, .6, .4)), int(SR * .9))), wet=.4))
save("fuse", reverb(mix((tone(N(84), .6, a=.5, glide=-.75, fm=1, amp=.4), 0), (tone(N(38), .5, d=.4, s=.1, r=.4, harm=(1, .7, .5, .3)), int(SR * .6)), (noise(.05, r=.3, amp=.6, lp=.2), int(SR * .6)), (tone(N(79), .2, s=.3, r=.5, harm=(1, .2)), int(SR * .65)))))
save("hit", mix((tone(N(45), .06, d=.08, s=0, r=.08, glide=-.5, harm=(1, .5, .3)), 0), (noise(.03, r=.05, amp=.5, lp=.5), 0)))
save("obstacle", mix((noise(.15, r=.15, amp=.7, lp=.4), 0), (tone(N(50), .15, glide=-.5, fm=2, amp=.6), 0)))
save("boss_roar", reverb(mix((tone(N(33), 1.2, a=.1, d=.5, s=.6, r=.4, fm=3, ratio=.51, harm=(1, .6, .5, .4, .3)), 0), (noise(1.2, a=.1, r=.4, amp=.4, lp=.08), 0))))
save("boss_down", reverb(mix((tone(N(30), .8, d=.7, s=.1, r=.6, harm=(1, .8, .6, .4)), 0), (noise(.4, r=.8, amp=.7, lp=.15), 0)), wet=.5))
fan = [(72, 0), (76, .12), (79, .24), (84, .36), (79, .6), (84, .72), (88, .84)]
save("win", reverb(delay(mix(*[(tone(N(m), .16 if k < 6 else .7, s=.5, r=.4, fm=.3, harm=(1, .35, .15), amp=.6), int(t * SR)) for k, (m, t) in enumerate(fan)], (tone(N(48), 1.2, s=.5, r=.6, harm=(1, .5, .2), amp=.4), int(.84 * SR)))), wet=.35))
save("tap", tone(N(91), .02, d=.03, s=0, r=.03, amp=.5))

# 微生物ワールドBGM: 112BPM, 8小節ループ。透明感アルペジオ+パッド+ソフトキック+シェイカー
bpm = 112; beat = 60 / bpm; bars = 8; L = int(bars * 4 * beat * SR)
prog = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]
def layer(fn):
    parts = []; fn(parts); return mix(*parts, length=L)
def arp(p):
    for b in range(bars):
        ch = prog[b % 4]
        for s in range(8):
            m = ch[s % 3] + 12 * (1 + (s // 3) % 2)
            p.append((tone(N(m), beat / 2 * .6, d=.1, s=.2, r=.15, fm=.4, ratio=2, harm=(1, .25), amp=.35), int((b * 4 + s / 2) * beat * SR)))
def pad(p):
    for b in range(bars):
        for m in prog[b % 4]:
            p.append((tone(N(m), 4 * beat - .2, a=.4, d=.5, s=.7, r=.4, harm=(1, .15, .1), amp=.12), int(b * 4 * beat * SR)))
def drums(p):
    for k in range(bars * 4):
        p.append((tone(55, .08, d=.12, s=0, r=.1, glide=-.6, amp=.7), int(k * beat * SR)))
        p.append((noise(.02, r=.04, amp=.12, lp=.9), int((k + .5) * beat * SR)))
def bass(p):
    for b in range(bars):
        r = prog[b % 4][0] - 24
        for s in (0, 1.5, 2, 3):
            p.append((tone(N(r), beat * .4, d=.1, s=.5, r=.08, harm=(1, .5, .25), amp=.35), int((b * 4 + s) * beat * SR)))
base = mix((layer(pad), 0), (layer(bass), 0), length=L)
save("bgm_micro_base", base, peak=.5)
save("bgm_micro_arp", delay(layer(arp), t=beat * .75)[:L], peak=.45)
save("bgm_micro_drums", layer(drums), peak=.45)
print("done")

# ---- ボス撃破演出用（追加）----
# 被弾：低音の肉厚な打撃＋高域のパチッ
save("boss_hit", mix((tone(N(40), .08, d=.12, s=0, r=.1, glide=-.6, harm=(1, .7, .4)), 0), (noise(.04, r=.06, amp=.7, lp=.6), 0), (tone(N(76), .03, d=.05, s=0, r=.05, fm=2, amp=.3), 0)))
# よろめき：うめくような下降FM＋揺れ
save("boss_stagger", reverb(mix((tone(N(38), .9, a=.05, d=.4, s=.5, r=.3, glide=-.3, fm=2.5, ratio=.5, harm=(1, .6, .4, .3)), 0), (noise(.9, a=.1, r=.3, amp=.25, lp=.06), 0))))
# クリスタル粉砕：高音の金属的な粒の連打＋ノイズ
sh = [(tone(N(m), .05, d=.15, s=0, r=.25, fm=3.5, ratio=3.7, amp=.5), int(SR * t)) for m, t in [(96, 0), (101, .03), (93, .06), (103, .1), (98, .14), (105, .19), (91, .24)]]
save("shatter", reverb(mix((noise(.25, r=.3, amp=.8, lp=.9), 0), (tone(N(36), .2, d=.3, s=0, r=.3, harm=(1, .8, .5)), 0), *sh), wet=.45))
# 倒れる：重い着地＋地鳴り
save("boss_fall", reverb(mix((tone(N(28), .6, d=.5, s=.1, r=.6, glide=-.4, harm=(1, .9, .6, .4, .2)), 0), (noise(.8, a=.01, r=.8, amp=.6, lp=.05), 0), (noise(.1, r=.1, amp=.5, lp=.5), 0)), wet=.4))
print("boss sfx done")
