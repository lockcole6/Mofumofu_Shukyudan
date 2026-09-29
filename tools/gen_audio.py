"""もふもふ蹴球団の音（BGM・効果音）を合成するスクリプト。外部素材なし。

使い方:  python tools/gen_audio.py
出力先:  assets/audio/*.wav（22050Hz / 16bit / モノラル）
  bgm_*.wav はループ用（smpl チャンクにループ位置を書くので、Godot が自動でループ再生する）

ドット絵に合わせたチップチューン寄りの音。後で本番の音に差し替える場合は、同じファイル名で置き換えるだけで鳴る。
"""
import math
import os
import random
import struct

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = random.Random(7)

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq(name):
    """'C5' 'F#4' → Hz"""
    n = NOTE[name[0]] + (1 if "#" in name else 0) - (1 if "b" in name[1:] else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((12 * (octave + 1) + n - 69) / 12)


# ------------------------------------------------------------ 音色

def pulse(f, t, duty=0.25):
    return 1.0 if (f * t) % 1.0 < duty else -1.0


def tri(f, t):
    p = (f * t) % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def sine(f, t):
    return math.sin(2 * math.pi * f * t)


def bell(f, t):
    """オルゴール／鈴っぽい音"""
    return (sine(f, t) * math.exp(-t * 4.0)
            + 0.4 * sine(f * 2.0, t) * math.exp(-t * 7.0)
            + 0.18 * sine(f * 3.01, t) * math.exp(-t * 11.0))


def adsr(t, dur, a=0.005, d=0.08, s=0.6, r=0.05):
    if t < a:
        return t / a
    if t < a + d:
        return 1.0 - (1.0 - s) * (t - a) / d
    if t < dur:
        return s
    if t < dur + r:
        return s * (1.0 - (t - dur) / r)
    return 0.0


def buf(sec):
    return [0.0] * int(SR * sec)


def add(b, start, samples, gain=1.0):
    i0 = int(start * SR)
    for i, v in enumerate(samples):
        j = i0 + i
        if 0 <= j < len(b):
            b[j] += v * gain


def render(sec, fn):
    return [fn(i / SR) for i in range(int(SR * sec))]


class Noise:
    """ローパスをかけられるノイズ"""
    def __init__(self, cutoff=1.0):
        self.a = cutoff
        self.y = 0.0

    def __call__(self):
        self.y += self.a * (rng.uniform(-1, 1) - self.y)
        return self.y


# ------------------------------------------------------------ 楽器（音符1つ分のサンプル列）

def lead(f, dur, duty=0.25, vib=True):
    def fn(t):
        v = 1.0 + (0.004 * sine(5.5, t) if vib and t > 0.12 else 0.0)
        return pulse(f * v, t, duty) * adsr(t, dur, 0.004, 0.06, 0.55, 0.04) * 0.5
    return render(dur + 0.05, fn)


def bass(f, dur):
    return render(dur, lambda t: tri(f, t) * adsr(t, dur - 0.02, 0.003, 0.05, 0.8, 0.02) * 0.9)


def arp(f, dur):
    return render(dur + 0.25, lambda t: bell(f, t) * 0.35)


def kick():
    def fn(t):
        f = 50 + 110 * math.exp(-t * 35)
        return math.sin(2 * math.pi * f * t) * math.exp(-t * 14)
    return render(0.25, fn)


def snare():
    n = Noise(0.7)
    return render(0.18, lambda t: (n() * 0.8 + 0.3 * sine(190, t)) * math.exp(-t * 22))


def hat(open_=False):
    n = Noise(1.0)
    prev = [0.0]
    def fn(t):
        x = n()
        y = x - prev[0]   # 高い音だけ残す
        prev[0] = x
        return y * math.exp(-t * (18 if open_ else 60)) * 0.5
    return render(0.2 if open_ else 0.06, fn)


# ------------------------------------------------------------ BGM

def song(bpm, chords, melody, bass_pat, drums, lead_duty=0.25, swing=0.0):
    """chords: 小節ごとのルート音, melody: 小節ごとの [(音 or None, 8分の長さ)]"""
    beat = 60.0 / bpm
    e8 = beat / 2
    bars = len(chords)
    total = bars * 4 * beat
    b = buf(total + 1.0)
    for bar in range(bars):
        t0 = bar * 4 * beat
        # メロディ
        t = t0
        for note, ln in melody[bar]:
            if note:
                add(b, t, lead(freq(note), ln * e8 * 0.92, lead_duty), 0.32)
            t += ln * e8
        # ベース
        root = chords[bar]
        for k, step in enumerate(bass_pat):
            if step is None:
                continue
            f = freq(root + "2") * (2 if step == "hi" else 1)
            add(b, t0 + k * e8, bass(f, e8 * 0.95), 0.36)
        # 和音のアルペジオ（小さく）
        tones = CHORD_TONES[root]
        for k in range(8):
            if k % 2 == 1:
                add(b, t0 + k * e8, arp(freq(tones[(k // 2) % 3] + "5"), e8), 0.18)
        # ドラム
        for k in range(16):
            ts = t0 + k * e8 / 2
            d = drums(k)
            if "K" in d:
                add(b, ts, kick(), 0.55)
            if "S" in d:
                add(b, ts, snare(), 0.32)
            if "H" in d:
                add(b, ts, hat(), 0.18)
            if "O" in d:
                add(b, ts, hat(True), 0.14)
    # ループ：最後の余韻を頭に重ねて、継ぎ目を目立たなくする
    n = int(total * SR)
    tail = b[n:]
    out = b[:n]
    for i, v in enumerate(tail):
        if i < len(out):
            out[i] += v
    return out


CHORD_TONES = {"C": ["C", "E", "G"], "A": ["A", "C", "E"], "F": ["F", "A", "C"], "G": ["G", "B", "D"],
               "E": ["E", "G", "B"], "D": ["D", "F", "A"]}


def bgm_menu():
    chords = ["C", "A", "F", "G", "C", "A", "F", "G", "F", "G", "E", "A", "F", "G", "C", "C"]
    m = [
        [("E5", 2), ("G5", 2), ("C6", 2), ("G5", 2)],
        [("A5", 3), ("G5", 1), ("E5", 2), ("C5", 2)],
        [("F5", 2), ("A5", 2), ("C6", 3), ("A5", 1)],
        [("G5", 3), ("F5", 1), ("E5", 2), ("D5", 2)],
        [("E5", 2), ("G5", 2), ("C6", 2), ("E6", 2)],
        [("D6", 3), ("C6", 1), ("A5", 4)],
        [("F5", 2), ("G5", 2), ("A5", 2), ("C6", 2)],
        [("B5", 4), ("G5", 2), (None, 2)],
        [("A5", 2), ("C6", 2), ("F6", 2), ("E6", 2)],
        [("D6", 2), ("B5", 2), ("G5", 4)],
        [("E6", 2), ("D6", 2), ("B5", 2), ("G5", 2)],
        [("A5", 4), ("C6", 2), ("E6", 2)],
        [("F6", 3), ("E6", 1), ("D6", 2), ("C6", 2)],
        [("D6", 2), ("E6", 2), ("D6", 2), ("B5", 2)],
        [("C6", 4), ("G5", 2), ("E5", 2)],
        [("C6", 6), (None, 2)],
    ]
    def drums(k):
        s = "H" if k % 2 == 0 else ""
        if k in (0, 8):
            s += "K"
        if k in (4, 12):
            s += "S"
        if k == 14:
            s += "O"
        return s
    return song(124, chords, m, ["lo", None, "hi", "lo", None, "lo", "hi", None], drums, 0.25)


def bgm_match():
    chords = ["A", "F", "C", "G"] * 4
    base = [
        [("A4", 1), ("C5", 1), ("E5", 2), ("A5", 2), ("E5", 2)],
        [("F5", 2), ("E5", 1), ("D5", 1), ("C5", 2), ("A4", 2)],
        [("G4", 1), ("C5", 1), ("E5", 2), ("G5", 3), ("E5", 1)],
        [("D5", 2), ("G5", 2), ("B5", 2), ("D6", 2)],
        [("E6", 3), ("D6", 1), ("C6", 2), ("A5", 2)],
        [("C6", 2), ("A5", 1), ("F5", 1), ("A5", 2), ("C6", 2)],
        [("E6", 2), ("G6", 2), ("E6", 2), ("C6", 2)],
        [("D6", 4), ("B5", 2), ("G5", 2)],
    ]
    m = base + base[:7] + [[("B5", 2), ("D6", 2), ("E6", 4)]]
    def drums(k):
        s = "H"
        if k % 4 == 0:
            s += "K"
        if k in (4, 12):
            s += "S"
        if k in (6, 14):
            s += "O"
        return s
    return song(148, chords, m, ["lo", "lo", "hi", "lo", "lo", "hi", "lo", "hi"], drums, 0.5)


# ------------------------------------------------------------ 効果音

def seq(notes, step, fn, tail=0.3):
    """音を順に鳴らす"""
    b = buf(len(notes) * step + tail)
    for i, n in enumerate(notes):
        if n:
            add(b, i * step, fn(freq(n)))
    return b


def sfx():
    s = {}
    s["tap"] = render(0.05, lambda t: pulse(1400 + 600 * t / 0.05, t, 0.5) * math.exp(-t * 60) * 0.35)
    s["open"] = seq(["E6", "B6"], 0.05, lambda f: render(0.18, lambda t: bell(f, t) * 0.5), 0.15)
    s["close"] = seq(["B6", "E6"], 0.05, lambda f: render(0.15, lambda t: bell(f, t) * 0.4), 0.12)
    s["toast"] = seq(["G6", "C7"], 0.08, lambda f: render(0.4, lambda t: bell(f, t) * 0.5), 0.3)
    s["error"] = render(0.2, lambda t: pulse(150, t, 0.5) * adsr(t, 0.15, 0.002, 0.02, 0.8, 0.05) * 0.35)

    def whistle(dur):
        n = Noise(0.3)
        return render(dur, lambda t: (sine(2900 + 60 * sine(32, t), t) * 0.8 + n() * 0.15) * adsr(t, dur - 0.05, 0.01, 0.02, 0.9, 0.05) * 0.5)
    s["whistle"] = whistle(0.55)
    b = buf(1.4)
    add(b, 0.0, whistle(0.18))
    add(b, 0.28, whistle(0.18))
    add(b, 0.56, whistle(0.75))
    s["whistle_end"] = b

    # ゴール：上がっていくアルペジオ＋歓声
    b = buf(1.8)
    for i, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"]):
        add(b, i * 0.06, render(0.6, lambda t, f=freq(n): pulse(f, t, 0.25) * adsr(t, 0.12, 0.003, 0.05, 0.5, 0.2) * 0.35))
    crowd = Noise(0.12)
    add(b, 0.0, render(1.8, lambda t: crowd() * min(t * 6, 1.0) * math.exp(-max(t - 0.4, 0) * 2.2) * 1.6))
    s["goal"] = b
    b = buf(0.9)
    for i, n in enumerate(["E5", "C5", "A4"]):
        add(b, i * 0.12, render(0.35, lambda t, f=freq(n): tri(f, t) * adsr(t, 0.2, 0.005, 0.05, 0.6, 0.1) * 0.5))
    crowd = Noise(0.08)
    add(b, 0.0, render(0.9, lambda t: crowd() * math.exp(-t * 4) * 0.8))
    s["opp_goal"] = b
    thud = render(0.3, lambda t: sine(90 + 60 * math.exp(-t * 30), t) * math.exp(-t * 12) * 0.8)
    clap = Noise(0.8)
    b = buf(0.5)
    add(b, 0, thud)
    add(b, 0.02, render(0.12, lambda t: clap() * math.exp(-t * 30) * 0.6))
    add(b, 0.1, seq(["G6", "D7"], 0.06, lambda f: render(0.25, lambda t: bell(f, t) * 0.3), 0.1))
    s["save"] = b
    s["skill"] = seq(["C6", "E6", "G6", "C7", "E7"], 0.035, lambda f: render(0.3, lambda t: bell(f, t) * 0.35), 0.3)

    s["win"] = _fanfare(["C5", "E5", "G5", "C6"], ["C4", "E4", "G4"], 0.11, 1.0)
    s["draw"] = seq(["G5", "C6"], 0.16, lambda f: render(0.6, lambda t: bell(f, t) * 0.5), 0.5)
    s["lose"] = seq(["E5", "D5", "C5", "G4"], 0.2, lambda f: render(0.45, lambda t: tri(f, t) * adsr(t, 0.25, 0.01, 0.08, 0.6, 0.15) * 0.45), 0.5)
    s["promote"] = _fanfare(["G4", "C5", "E5", "G5", "C6", "E6"], ["C4", "G4", "E5"], 0.09, 1.5)
    s["champion"] = _fanfare(["C5", "E5", "G5", "C6", "E6", "G6", "C7"], ["C4", "G4", "C5", "E5"], 0.08, 2.0)

    # ガチャ
    rum = Noise(0.05)
    s["door_shake"] = render(1.1, lambda t: rum() * (0.6 + 0.4 * sine(18, t)) * min(t * 4, 1) * 1.8)
    wh = Noise(0.5)
    s["door_open"] = render(0.35, lambda t: wh() * math.sin(math.pi * t / 0.35) * 0.35)
    s["reveal1"] = seq(["E6"], 0.0, lambda f: render(0.4, lambda t: bell(f, t) * 0.55), 0.3)
    s["reveal2"] = seq(["C6", "G6"], 0.07, lambda f: render(0.5, lambda t: bell(f, t) * 0.5), 0.4)
    b = buf(1.3)
    for i, n in enumerate(["C6", "E6", "G6", "C7"]):
        add(b, i * 0.07, render(0.9, lambda t, f=freq(n): bell(f, t) * 0.4))
    add(b, 0.0, _shimmer(1.2, 0.25))
    s["reveal3"] = b
    b = buf(2.0)
    for i, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6", "C7"]):
        add(b, i * 0.06, render(0.5, lambda t, f=freq(n): pulse(f, t, 0.25) * adsr(t, 0.1, 0.003, 0.04, 0.5, 0.2) * 0.3))
    for n in ["C6", "E6", "G6", "C7"]:
        add(b, 0.45, render(1.4, lambda t, f=freq(n): bell(f, t) * 0.3))
    add(b, 0.3, _shimmer(1.6, 0.35))
    s["reveal4"] = b
    s["new"] = seq(["G6", "C7"], 0.07, lambda f: render(0.3, lambda t: pulse(f, t, 0.5) * math.exp(-t * 14) * 0.25), 0.2)

    # スカウト
    s["scout_ok"] = seq(["C5", "E5", "G5", "E5", "C6"], 0.08, lambda f: render(0.25, lambda t: pulse(f, t, 0.25) * adsr(t, 0.07, 0.003, 0.03, 0.6, 0.05) * 0.4), 0.3)
    s["scout_ng"] = render(0.5, lambda t: sine(420 * math.exp(-t * 2.5) * (1 + 0.06 * sine(14, t)), t) * math.exp(-t * 3) * 0.5)

    # 編成
    s["lift"] = render(0.09, lambda t: sine(500 + 900 * t / 0.09, t) * math.exp(-t * 25) * 0.4)
    s["drop"] = render(0.12, lambda t: sine(260 - 100 * t / 0.12, t) * math.exp(-t * 30) * 0.6)
    wh2 = Noise(0.4)
    s["remove"] = render(0.25, lambda t: (wh2() * 0.4 + sine(600 - 400 * t / 0.25, t) * 0.3) * math.exp(-t * 9))
    s["levelup"] = seq(["C6", "E6", "G6", "C7"], 0.05, lambda f: render(0.2, lambda t: pulse(f, t, 0.5) * math.exp(-t * 12) * 0.3), 0.25)
    s["coin"] = seq(["B6", "E7"], 0.07, lambda f: render(0.3, lambda t: pulse(f, t, 0.5) * math.exp(-t * 10) * 0.25), 0.2)
    return s


def _fanfare(melody, chord, step, sustain):
    b = buf(len(melody) * step + sustain + 0.4)
    for i, n in enumerate(melody):
        last = i == len(melody) - 1
        dur = sustain if last else step * 0.9
        add(b, i * step, render(dur + 0.2, lambda t, f=freq(n), d=dur: pulse(f, t, 0.25) * adsr(t, d, 0.003, 0.05, 0.6, 0.2) * 0.35))
    for n in chord:
        add(b, (len(melody) - 1) * step, render(sustain + 0.2, lambda t, f=freq(n): tri(f, t) * adsr(t, sustain, 0.01, 0.1, 0.6, 0.2) * 0.3))
    return b


def _shimmer(sec, gain):
    b = buf(sec)
    for i in range(14):
        f = freq(rng.choice(["C7", "E7", "G7", "C8"]))
        add(b, rng.uniform(0, sec - 0.3), render(0.3, lambda t, f=f: bell(f, t) * gain))
    return b


# ------------------------------------------------------------ 書き出し

def write(name, data, loop=False):
    peak = max(1e-6, max(abs(v) for v in data))
    g = 0.89 / peak
    pcm = b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in data)
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(pcm)) + pcm
    if loop:
        smpl = struct.pack("<9I", 0, 0, 0, 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, len(data) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)
    print(f"{name}.wav  {len(data) / SR:.1f}s")


if __name__ == "__main__":
    write("bgm_menu", bgm_menu(), loop=True)
    write("bgm_match", bgm_match(), loop=True)
    for k, v in sfx().items():
        write("sfx_" + k, v)
