"""Reklam için kendi ürettiğimiz arka plan müziği (telif yok): neşeli 120 BPM döngü, 'efsane' anında
davul susar ve yükselen pırıltı gelir, Kutbi'nin çıkışında döngü zillerle geri döner, akorla biter.

build_ad.py çağırır: make(path, star_start, outro_start, total)
"""
import math
import wave

import numpy as np

SR = 48000
BPM = 120.0
BEAT = 60.0 / BPM
# I–V–vi–IV (Do majör), her akor 2 ölçü değil 1 ölçü (4 vuruş)
CHORDS = [(60, 64, 67), (55, 59, 62), (57, 60, 64), (53, 57, 60)]
# pentatonik, akora göre seçilen basit motif (vuruş başına 2 nota)
MOTIF = [0, 2, 4, 2, 5, 4, 2, 0]
PENTA = [0, 2, 4, 7, 9, 12, 14, 16]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def env(n, a=0.005, d=0.25):
    t = np.arange(n) / SR
    e = np.minimum(t / a, 1.0) * np.exp(-t / d)
    return e


def tone(m, dur, kind="pluck", vol=0.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    if kind == "pluck":
        w = np.sign(np.sin(2 * math.pi * f * t)) * 0.35 + np.sin(2 * math.pi * f * t) * 0.65
        return w * env(n, 0.003, 0.18) * vol
    if kind == "bass":
        w = 2 * (t * f % 1.0) - 1.0
        return w * env(n, 0.005, 0.3) * vol
    if kind == "pad":
        w = sum(np.sin(2 * math.pi * f * (1 + dt) * t) for dt in (-0.004, 0.0, 0.004)) / 3
        a = np.minimum(t / 0.4, 1.0) * np.minimum((dur - t) / 0.4, 1.0)
        return w * np.clip(a, 0, 1) * vol
    if kind == "bell":
        w = np.sin(2 * math.pi * f * t) + 0.4 * np.sin(2 * math.pi * f * 2.76 * t)
        return w * env(n, 0.002, 0.6) * vol
    raise ValueError(kind)


def kick():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = 120 * np.exp(-t * 18) + 45
    return np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 12) * 0.55


def hat(rng):
    n = int(0.05 * SR)
    return rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / SR * 90) * 0.08


def add(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def make(path, star_start, outro_start, total):
    rng = np.random.default_rng(7)
    buf = np.zeros(int((total + 0.5) * SR))
    beat = 0
    t = 0.0
    while t < total:
        bar = beat // 4
        chord = CHORDS[bar % 4]
        in_star = star_start <= t < outro_start
        outro = t >= outro_start
        if not in_star:
            if beat % 4 in (0, 2):
                add(buf, kick(), t)
            add(buf, hat(rng), t + BEAT / 2)
            add(buf, tone(chord[0] - 24, BEAT * 0.9, "bass", 0.16), t)
            for s in range(2):
                step = MOTIF[(beat * 2 + s) % len(MOTIF)]
                note = chord[0] + 12 + PENTA[step % len(PENTA)]
                add(buf, tone(note, BEAT * 0.5, "bell" if outro else "pluck", 0.08 if outro else 0.07), t + s * BEAT / 2)
        if beat % 4 == 0:
            for m in chord:
                add(buf, tone(m, BEAT * 4, "pad", 0.05 if not in_star else 0.08), t)
        if in_star:
            # yükselen pırıltı (vuruş başına 4 nota, gittikçe tize)
            k = (t - star_start) / max(outro_start - star_start, 0.1)
            for s in range(4):
                add(buf, tone(72 + int(k * 14) + PENTA[(beat * 4 + s) % 5], BEAT / 4, "bell", 0.05), t + s * BEAT / 4)
        beat += 1
        t = beat * BEAT
    # bitiş akoru
    add(buf, sum(tone(m + 12, 1.6, "bell", 0.06) for m in CHORDS[0]), max(total - 1.6, 0))
    fade = int(0.4 * SR)
    end = int(total * SR)
    buf[end - fade:end] *= np.linspace(1, 0, fade)
    buf[end:] = 0
    buf = buf[: end]
    buf = np.tanh(buf * 1.3) * 0.8
    pcm = (buf * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
