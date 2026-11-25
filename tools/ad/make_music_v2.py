"""UniPet Tanıtım Filmi v2 — Zengin stereo indie-pop / sinematik müzik sentezi (telifsiz, saf numpy).

48 kHz STEREO:
- Sıcak Rhodes / elektrik piyano akorları (Cmaj7 – G6 – Am7 – Fmaj7) + stereo chorus + multi-tap reverb
- Modern kick (sub + tıklama), 2 ve 4. vuruşlarda yumuşak clap/snare, hafif swing'li hi-hat
- Sıcak bas hattı + parlak kalimba/marimba melodisi
- 'Dress-up' sahnesinde enerjik arpej + beat vurgusu
- 'Kayan yıldız' anında davul susar, yükselen sinematik riser + harp glissando + inişte derin sub-drop
- 'Kutbi' finalinde göksel çanlar + tam armonik nakarat + parlak bitiş akoru
"""
import math
import wave
import numpy as np

SR = 48000
BPM = 120.0
BEAT = 60.0 / BPM  # 0.5 sn

# Cmaj7 -> G6 -> Am7 -> Fmaj7 (sıcak, modern, umutlu)
CHORDS = [
    (60, 64, 67, 71),
    (55, 59, 62, 64),
    (57, 60, 64, 67),
    (53, 57, 60, 64),
]
BASS_ROOTS = [36, 43, 45, 41]
MELODY_PENTA = [72, 74, 76, 79, 81, 84, 86, 88]
MELODY_SEQ = [0, 2, 4, 2, 5, 4, 3, 2, 4, 5, 7, 5, 4, 2, 1, 0]


def hz(midi: float) -> float:
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))


def adsr(n: int, a: float, d: float) -> np.ndarray:
    t = np.arange(n, dtype=np.float64) / SR
    return np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-t / max(d, 1e-4))


def rhodes(midi: float, dur: float, vol: float = 0.14) -> np.ndarray:
    """Sıcak elektrik piyano (temel + yumuşak 2. ve 3. armonik + hafif tremolo)."""
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = hz(midi)
    body = (
        np.sin(2.0 * math.pi * f * t)
        + 0.28 * np.sin(2.0 * math.pi * 2.0 * f * t) * np.exp(-t * 3.5)
        + 0.10 * np.sin(2.0 * math.pi * 3.0 * f * t) * np.exp(-t * 8.0)
    )
    tine = 0.12 * np.sin(2.0 * math.pi * 7.0 * f * t) * np.exp(-t * 28.0)
    trem = 1.0 - 0.08 * np.sin(2.0 * math.pi * 4.5 * t)
    env = np.minimum(t / 0.008, 1.0) * np.exp(-t / max(dur * 0.75, 0.35))
    fade_out = np.minimum((dur - t) / 0.04, 1.0)
    return (body + tine) * trem * env * np.clip(fade_out, 0.0, 1.0) * vol


def kalimba(midi: float, dur: float, vol: float = 0.12) -> np.ndarray:
    """Parlak, sevimli marimba/kalimba tınısı."""
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = hz(midi)
    sig = (
        np.sin(2.0 * math.pi * f * t)
        + 0.32 * np.sin(2.0 * math.pi * 2.0 * f * t) * np.exp(-t * 10.0)
        + 0.16 * np.sin(2.0 * math.pi * 3.98 * f * t) * np.exp(-t * 24.0)
    )
    return sig * adsr(n, 0.002, 0.19) * vol


def celestial_bell(midi: float, dur: float, vol: float = 0.10) -> np.ndarray:
    """Kutbi ve yıldız için parlak göksel çan/harp tınısı."""
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = hz(midi)
    sig = (
        np.sin(2.0 * math.pi * f * t)
        + 0.35 * np.sin(2.0 * math.pi * 2.0 * f * t) * np.exp(-t * 2.2)
        + 0.22 * np.sin(2.0 * math.pi * 3.0 * f * t) * np.exp(-t * 4.0)
        + 0.12 * np.sin(2.0 * math.pi * 5.04 * f * t) * np.exp(-t * 9.0)
    )
    return sig * adsr(n, 0.003, dur * 0.55) * vol


def warm_bass(midi: float, dur: float, vol: float = 0.22) -> np.ndarray:
    """Yuvarlak sub + sıcak üst armonikli bas."""
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = hz(midi)
    sig = (
        0.78 * np.sin(2.0 * math.pi * f * t)
        + 0.22 * np.sin(2.0 * math.pi * 2.0 * f * t) * np.exp(-t * 4.0)
        + 0.08 * np.sin(2.0 * math.pi * 3.0 * f * t) * np.exp(-t * 7.0)
    )
    env = np.minimum(t / 0.006, 1.0) * np.exp(-t / 0.36) * np.minimum((dur - t) / 0.02, 1.0)
    return sig * np.clip(env, 0.0, 1.0) * vol


def lush_pad(chord, dur: float, vol: float = 0.055) -> tuple[np.ndarray, np.ndarray]:
    """Stereo detuned yaylı/pad akoru."""
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    L = np.zeros(n, dtype=np.float64)
    R = np.zeros(n, dtype=np.float64)
    env = np.minimum(t / 0.45, 1.0) * np.minimum((dur - t) / 0.45, 1.0)
    env = np.clip(env, 0.0, 1.0)
    for idx, m in enumerate(chord):
        f = hz(m)
        l_osc = np.sin(2.0 * math.pi * f * 0.9975 * t) + 0.25 * np.sin(2.0 * math.pi * 2.0 * f * 0.998 * t)
        r_osc = np.sin(2.0 * math.pi * f * 1.0025 * t) + 0.25 * np.sin(2.0 * math.pi * 2.0 * f * 1.002 * t)
        pan = 0.35 + 0.3 * (idx / max(len(chord) - 1, 1))
        L += l_osc * (1.0 - pan * 0.4)
        R += r_osc * (0.6 + pan * 0.4)
    return L * env * vol, R * env * vol


def kick(vol: float = 0.52) -> np.ndarray:
    n = int(0.28 * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = 135.0 * np.exp(-t * 24.0) + 46.0
    sub = np.sin(2.0 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 10.5)
    click = np.sin(2.0 * math.pi * 1600.0 * t) * np.exp(-t * 180.0) * 0.16
    return (sub + click) * vol


def clap_snare(rng: np.random.Generator, vol: float = 0.22) -> np.ndarray:
    n = int(0.18 * SR)
    t = np.arange(n, dtype=np.float64) / SR
    noise = rng.uniform(-1.0, 1.0, n)
    # Basit bant-geçiş hissiyatı (fark filtresi)
    hp = np.diff(noise, prepend=0.0)
    body = np.sin(2.0 * math.pi * 210.0 * t) * np.exp(-t * 32.0) * 0.35
    burst = (np.exp(-t * 24.0) + 0.5 * np.exp(-np.maximum(t - 0.012, 0.0) * 30.0))
    return (hp * burst * 0.55 + body) * vol


def hihat(rng: np.random.Generator, open_hat: bool = False, vol: float = 0.075) -> np.ndarray:
    dur = 0.14 if open_hat else 0.045
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    noise = rng.uniform(-1.0, 1.0, n)
    hp = np.diff(np.diff(noise, prepend=0.0), prepend=0.0)
    decay = 22.0 if open_hat else 95.0
    return hp * np.exp(-t * decay) * vol


def riser(rng: np.random.Generator, dur: float, vol: float = 0.16) -> tuple[np.ndarray, np.ndarray]:
    """Yıldız düşerken nefes kesen yükselen sinematik riser."""
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    k = t / max(dur, 0.1)
    # Yükselen armonik sweep + stereo gürültü
    f = 220.0 * (2.0 ** (2.5 * (k ** 1.6)))
    sweep = np.sin(2.0 * math.pi * np.cumsum(f) / SR) * (k ** 1.8) * 0.35
    nL = np.diff(rng.uniform(-1.0, 1.0, n), prepend=0.0) * (k ** 2.2) * 0.32
    nR = np.diff(rng.uniform(-1.0, 1.0, n), prepend=0.0) * (k ** 2.2) * 0.32
    return (sweep + nL) * vol, (sweep + nR) * vol


def sub_drop(vol: float = 0.55) -> np.ndarray:
    """Yıldız yere çarpınca derin sinematik sub-bass darbesi."""
    n = int(1.1 * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = 95.0 * np.exp(-t * 3.2) + 34.0
    return np.sin(2.0 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 2.6) * vol


def add_stereo(L: np.ndarray, R: np.ndarray, sig_l: np.ndarray, sig_r: np.ndarray, at: float) -> None:
    i = int(at * SR)
    if i >= len(L) or i < 0:
        return
    j = min(len(L), i + len(sig_l))
    L[i:j] += sig_l[: j - i]
    R[i:j] += sig_r[: j - i]


def add_pan(L: np.ndarray, R: np.ndarray, sig: np.ndarray, at: float, pan: float = 0.0) -> None:
    """pan: -1 (sol) .. +1 (sağ)."""
    gl = math.sqrt(0.5 * (1.0 - pan))
    gr = math.sqrt(0.5 * (1.0 + pan))
    add_stereo(L, R, sig * gl, sig * gr, at)


def apply_reverb(L: np.ndarray, R: np.ndarray, wet: float = 0.22) -> tuple[np.ndarray, np.ndarray]:
    """Hafif, temiz multi-tap stereo reverb."""
    outL = L.copy()
    outR = R.copy()
    taps = [(0.029, 0.34, True), (0.053, 0.26, False), (0.089, 0.20, True), (0.141, 0.14, False), (0.211, 0.09, True)]
    for delay_s, gain, cross in taps:
        d = int(delay_s * SR)
        if d >= len(L):
            continue
        if cross:
            outL[d:] += R[:-d] * (gain * wet)
            outR[d:] += L[:-d] * (gain * wet)
        else:
            outL[d:] += L[:-d] * (gain * wet)
            outR[d:] += R[:-d] * (gain * wet)
    return outL, outR


def make(path: str, dressup_start: float, star_start: float, impact_at: float, outro_start: float, total: float) -> None:
    rng = np.random.default_rng(2026)
    n_total = int((total + 1.0) * SR)
    L = np.zeros(n_total, dtype=np.float64)
    R = np.zeros(n_total, dtype=np.float64)

    beat = 0
    t = 0.0
    while t < total:
        bar = beat // 4
        chord = CHORDS[bar % 4]
        root = BASS_ROOTS[bar % 4]
        in_star = star_start <= t < outro_start
        in_dressup = dressup_start <= t < dressup_start + 4.0
        in_outro = t >= outro_start

        # Her ölçünün başında sıcak stereo pad + Rhodes akoru
        if beat % 4 == 0:
            pL, pR = lush_pad(chord, BEAT * 4.0, 0.065 if not in_star else 0.09)
            add_stereo(L, R, pL, pR, t)
            if not in_star:
                for idx, m in enumerate(chord):
                    pan = -0.35 + 0.7 * (idx / max(len(chord) - 1, 1))
                    add_pan(L, R, rhodes(m, BEAT * 3.8, 0.085), t + idx * 0.014, pan)

        if not in_star:
            # Ritim: 4-on-the-floor'a yakın sıcak indie-pop groove
            if beat % 4 in (0, 2):
                add_pan(L, R, kick(0.50 if (in_dressup or in_outro) else 0.42), t, 0.0)
            if beat % 4 in (1, 3):
                add_pan(L, R, clap_snare(rng, 0.22 if (in_dressup or in_outro) else 0.16), t, 0.08)
            # Swung hi-hats
            add_pan(L, R, hihat(rng, False, 0.065), t + BEAT * 0.52, -0.25)
            if in_dressup or in_outro:
                add_pan(L, R, hihat(rng, beat % 4 == 3, 0.055), t + BEAT * 0.25, 0.22)

            # Sıcak bas
            bass_note = root if beat % 4 != 3 else root + 7
            add_pan(L, R, warm_bass(bass_note, BEAT * 0.92, 0.23), t, 0.0)

            # Melodi (kalimba; outro'da göksel çanlarla destekli)
            for s in range(2):
                step = MELODY_SEQ[(beat * 2 + s) % len(MELODY_SEQ)]
                note = MELODY_PENTA[step % len(MELODY_PENTA)]
                pan = -0.3 if s == 0 else 0.3
                vol = 0.11 if in_dressup else 0.085
                add_pan(L, R, kalimba(note, BEAT * 0.55, vol), t + s * BEAT * 0.5, pan)
                if in_outro:
                    add_pan(L, R, celestial_bell(note + 12, BEAT * 1.1, 0.055), t + s * BEAT * 0.5, -pan)
        else:
            # Yıldız düşerken göksel arp (16'lık pırıltılar)
            k = (t - star_start) / max(outro_start - star_start, 0.1)
            for s in range(4):
                note = 72 + int(k * 12) + [0, 4, 7, 11, 14][(beat * 4 + s) % 5]
                pan = math.sin((beat * 4 + s) * 0.8) * 0.55
                add_pan(L, R, celestial_bell(note, 0.45, 0.052), t + s * BEAT * 0.25, pan)

        beat += 1
        t = beat * BEAT

    # Sinematik riser + yıldız çarpma sub-drop + Kutbi giriş çanı
    r_dur = max(0.5, impact_at - star_start)
    rL, rR = riser(rng, r_dur, 0.24)
    add_stereo(L, R, rL, rR, star_start)
    add_pan(L, R, sub_drop(0.62), impact_at, 0.0)
    for idx, m in enumerate((72, 76, 79, 83, 88)):
        add_pan(L, R, celestial_bell(m, 2.2, 0.075), outro_start + idx * 0.045, -0.4 + idx * 0.2)

    # Sıcak final akoru
    for idx, m in enumerate((60, 64, 67, 71, 76, 84)):
        add_pan(L, R, celestial_bell(m, 2.2, 0.06), max(total - 2.0, 0.0) + idx * 0.03, -0.5 + idx * 0.2)

    L, R = apply_reverb(L, R, wet=0.25)

    end = int(total * SR)
    L, R = L[:end], R[:end]
    fade = int(0.55 * SR)
    ramp = np.linspace(1.0, 0.0, fade)
    L[-fade:] *= ramp
    R[-fade:] *= ramp

    # Yumuşak mastering limiter
    L = np.tanh(L * 1.25) * 0.86
    R = np.tanh(R * 1.25) * 0.86

    stereo = np.empty(end * 2, dtype=np.int16)
    stereo[0::2] = (L * 32767.0).astype(np.int16)
    stereo[1::2] = (R * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(stereo.tobytes())
