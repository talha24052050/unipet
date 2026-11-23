"""Kedi miyavlaması (sentez, telifsiz): game/assets/sfx/meow.wav

Kullanım: python tools/assets/make_meow.py
"mi-yav": perde önce yükselip sonra düşen, iki formantlı (a→u) harmonik ses + hafif nefes gürültüsü.
"""
import math
import os
import wave

import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "game/assets/sfx/meow.wav")
SR = 44100


def formant(sig, f, bw):
    """İkinci derece rezonatör (biquad bant geçiren)."""
    r = math.exp(-math.pi * bw / SR)
    a1, a2 = -2 * r * math.cos(2 * math.pi * f / SR), r * r
    out = np.zeros_like(sig)
    y1 = y2 = 0.0
    for i, x in enumerate(sig):
        y = x - a1 * y1 - a2 * y2
        out[i] = y
        y2, y1 = y1, y
    return out * (1 - r)


def main():
    dur = 0.62
    n = int(dur * SR)
    t = np.arange(n) / SR
    u = t / dur
    # perde: 520 → 780 (0.35'te) → 470 Hz
    f0 = np.where(u < 0.35, 520 + 260 * np.sin(u / 0.35 * math.pi / 2), 780 - 310 * ((u - 0.35) / 0.65) ** 1.3)
    f0 = f0 * (1 + 0.01 * np.sin(2 * math.pi * 6 * t))  # hafif titreme
    phase = 2 * math.pi * np.cumsum(f0) / SR
    src = sum(np.sin(k * phase) / k ** 1.1 for k in range(1, 12))
    src += np.random.default_rng(3).normal(0, 0.05, n)
    # formantlar "i-a-u" geçişi parça parça (zamanla değişen filtre yerine 3 bölümün karışımı)
    parts = [(1900, 2900), (1100, 2300), (700, 1600)]
    weights = [np.clip(1 - u * 3, 0, 1), np.clip(1 - abs(u - 0.4) * 3, 0, 1), np.clip((u - 0.45) * 2.5, 0, 1)]
    out = np.zeros(n)
    for (fa, fb), w in zip(parts, weights):
        out += (formant(src, fa, 160) + 0.6 * formant(src, fb, 220)) * w
    env = np.minimum(u / 0.06, 1.0) * np.minimum((1 - u) / 0.25, 1.0)
    out *= env
    out = out / (np.max(np.abs(out)) + 1e-9) * 0.7
    pcm = (out * 32767).astype(np.int16)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("OK", OUT)


if __name__ == "__main__":
    main()
