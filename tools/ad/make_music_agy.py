"""UniPet Tanıtım Filmi (agy kurgusu) — Enerjik kampüs indie-house / synth-funk stereo müzik sentezi (telifsiz, saf numpy).

48 kHz STEREO, 120 BPM (tam 30 fps kare hizalı: 1 vuruş = 0.50 sn = 15 kare!):
- Funky oktav bas yürüyüşü + dört-vuruş (4-on-the-floor) tok kick + keskin clap + açık/kapalı 16'lık hi-hat groove
- Sıcak stereo Rhodes akorları (Fmaj7 – G6 – Em7 – Am7 -> enerjik kampüs marşı hissi!)
- Parlak synth-pluck / marimba ana tema melodisi + sahne geçişlerinde (cut points) davul/zil geçiş vurguları
- Stadyum & Stil şovunda (19.0 - 24.5 sn) çift katmanlı arpej ve yüksek ritim enerjisi
- Kayan yıldız sahnesinde (24.5 - 26.5 sn) nefes kesen sinematik riser + göksel arp + 25.85 sn'de dev sub-bass darbesi
- Kutbi finalinde (26.5 - 30.5 sn) görkemli çanlar, tam orkestral synth nakaratı ve parlak bitiş akoru
"""
import math
import wave
import numpy as np

SR = 48000
BPM = 120.0
BEAT = 60.0 / BPM  # 0.50 sn

# Fmaj7 -> G6 -> Em7 -> Am7 (modern, duygusal ve enerjik festival/kampüs progresyonu)
CHORDS = [
    (53, 57, 60, 64),
    (55, 59, 62, 64),
    (52, 55, 59, 62),
    (57, 60, 64, 67),
]
BASS_ROOTS = [41, 43, 40, 45]
LEAD_NOTES = [72, 74, 76, 79, 81, 84, 86, 88]
HOOK_A = [4, 5, 7, 5, 4, 2, 0, 2, 4, 5, 7, 9, 7, 5, 4, 2]
HOOK_B = [7, 5, 4, 2, 5, 4, 2, 0, 2, 4, 5, 7, 5, 7, 9, 7]


def hz(midi: float) -> float:
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))


def adsr(n: int, a: float, d: float) -> np.ndarray:
    t = np.arange(n, dtype=np.float64) / SR
    return np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-t / max(d, 1e-4))


def epiano(midi: float, dur: float, vol: float = 0.12) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = hz(midi)
    body = (
        np.sin(2.0 * math.pi * f * t)
        + 0.30 * np.sin(2.0 * math.pi * 2.0 * f * t) * np.exp(-t * 3.8)
        + 0.12 * np.sin(2.0 * math.pi * 3.0 * f * t) * np.exp(-t * 8.5)
    )
    tine = 0.14 * np.sin(2.0 * math.pi * 6.0 * f * t) * np.exp(-t * 26.0)
    env = np.minimum(t / 0.006, 1.0) * np.exp(-t / max(dur * 0.8, 0.35))
    fade = np.clip((dur - t) / 0.03, 0.0, 1.0)
    return (body + tine) * env * fade * vol


def synth_pluck(midi: float, dur: float, vol: float = 0.12) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = hz(midi)
    sig = (
        0.65 * np.sin(2.0 * math.pi * f * t)
        + 0.35 * np.sin(2.0 * math.pi * 2.0 * f * t) * np.exp(-t * 8.0)
        + 0.20 * np.sin(2.0 * math.pi * 3.0 * f * t) * np.exp(-t * 15.0)
        + 0.10 * np.sin(2.0 * math.pi * 4.0 * f * t) * np.exp(-t * 25.0)
    )
    return sig * adsr(n, 0.002, 0.21) * vol


def bell(midi: float, dur: float, vol: float = 0.10) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = hz(midi)
    sig = (
        np.sin(2.0 * math.pi * f * t)
        + 0.36 * np.sin(2.0 * math.pi * 2.0 * f * t) * np.exp(-t * 2.4)
        + 0.20 * np.sin(2.0 * math.pi * 3.0 * f * t) * np.exp(-t * 4.5)
        + 0.12 * np.sin(2.0 * math.pi * 5.02 * f * t) * np.exp(-t * 9.5)
    )
    return sig * adsr(n, 0.002, dur * 0.55) * vol


def punch_bass(midi: float, dur: float, vol: float = 0.24) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = hz(midi)
    # Zengin synth-funk bas (temel + 2. ve 3. harmonik zarflı filtre hissi)
    sig = (
        0.74 * np.sin(2.0 * math.pi * f * t)
        + 0.30 * np.sin(2.0 * math.pi * 2.0 * f * t) * np.exp(-t * 6.5)
        + 0.14 * np.sin(2.0 * math.pi * 3.0 * f * t) * np.exp(-t * 12.0)
    )
    env = np.minimum(t / 0.004, 1.0) * np.exp(-t / 0.28) * np.clip((dur - t) / 0.015, 0.0, 1.0)
    return np.tanh(sig * 1.35) * env * vol


def stereo_pad(chord, dur: float, vol: float = 0.055) -> tuple[np.ndarray, np.ndarray]:
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    L = np.zeros(n, dtype=np.float64)
    R = np.zeros(n, dtype=np.float64)
    env = np.clip(np.minimum(t / 0.30, 1.0) * np.minimum((dur - t) / 0.35, 1.0), 0.0, 1.0)
    for idx, m in enumerate(chord):
        f = hz(m)
        l_osc = np.sin(2.0 * math.pi * f * 0.997 * t) + 0.28 * np.sin(2.0 * math.pi * 2.0 * f * 0.998 * t)
        r_osc = np.sin(2.0 * math.pi * f * 1.003 * t) + 0.28 * np.sin(2.0 * math.pi * 2.0 * f * 1.002 * t)
        pan = idx / max(len(chord) - 1, 1)
        L += l_osc * (0.85 - 0.35 * pan)
        R += r_osc * (0.50 + 0.35 * pan)
    return L * env * vol, R * env * vol


def kick(vol: float = 0.56) -> np.ndarray:
    n = int(0.26 * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = 150.0 * np.exp(-t * 28.0) + 47.0
    sub = np.sin(2.0 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 11.0)
    click = np.sin(2.0 * math.pi * 1850.0 * t) * np.exp(-t * 210.0) * 0.18
    return (sub + click) * vol


def clap_snare(rng: np.random.Generator, vol: float = 0.24) -> np.ndarray:
    n = int(0.17 * SR)
    t = np.arange(n, dtype=np.float64) / SR
    noise = rng.uniform(-1.0, 1.0, n)
    hp = np.diff(noise, prepend=0.0)
    body = np.sin(2.0 * math.pi * 220.0 * t) * np.exp(-t * 34.0) * 0.36
    burst = np.exp(-t * 25.0) + 0.55 * np.exp(-np.maximum(t - 0.011, 0.0) * 32.0)
    return (hp * burst * 0.58 + body) * vol


def hihat(rng: np.random.Generator, open_hat: bool = False, vol: float = 0.075) -> np.ndarray:
    dur = 0.15 if open_hat else 0.042
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    noise = rng.uniform(-1.0, 1.0, n)
    hp = np.diff(np.diff(noise, prepend=0.0), prepend=0.0)
    decay = 20.0 if open_hat else 100.0
    return hp * np.exp(-t * decay) * vol


def crash_shimmer(rng: np.random.Generator, dur: float = 0.85, vol: float = 0.11) -> tuple[np.ndarray, np.ndarray]:
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    nL = np.diff(np.diff(rng.uniform(-1.0, 1.0, n), prepend=0.0), prepend=0.0)
    nR = np.diff(np.diff(rng.uniform(-1.0, 1.0, n), prepend=0.0), prepend=0.0)
    env = np.minimum(t / 0.005, 1.0) * np.exp(-t * 4.2)
    return nL * env * vol, nR * env * vol


def whoosh_transition(rng: np.random.Generator, dur: float = 0.28, vol: float = 0.12) -> tuple[np.ndarray, np.ndarray]:
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    env = np.sin(np.clip(t / dur, 0.0, 1.0) * math.pi) ** 1.6
    nL = np.diff(rng.uniform(-1.0, 1.0, n), prepend=0.0) * env * vol
    nR = np.diff(rng.uniform(-1.0, 1.0, n), prepend=0.0) * env * vol
    return nL, nR


def riser(rng: np.random.Generator, dur: float, vol: float = 0.24) -> tuple[np.ndarray, np.ndarray]:
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    k = t / max(dur, 0.1)
    f = 240.0 * (2.0 ** (2.6 * (k ** 1.5)))
    sweep = np.sin(2.0 * math.pi * np.cumsum(f) / SR) * (k ** 1.7) * 0.38
    nL = np.diff(rng.uniform(-1.0, 1.0, n), prepend=0.0) * (k ** 2.1) * 0.34
    nR = np.diff(rng.uniform(-1.0, 1.0, n), prepend=0.0) * (k ** 2.1) * 0.34
    return (sweep + nL) * vol, (sweep + nR) * vol


def sub_drop(vol: float = 0.64) -> np.ndarray:
    n = int(1.05 * SR)
    t = np.arange(n, dtype=np.float64) / SR
    f = 105.0 * np.exp(-t * 3.5) + 35.0
    return np.sin(2.0 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 2.8) * vol


def bus_horn_chord(vol: float = 0.11) -> np.ndarray:
    """Açılışta neşeli iki tonlu sıcak otobüs selamlama kornası."""
    n = int(0.24 * SR)
    t = np.arange(n, dtype=np.float64) / SR
    sig = 0.55 * np.sin(2.0 * math.pi * hz(65) * t) + 0.45 * np.sin(2.0 * math.pi * hz(69) * t)
    sig += 0.20 * np.sin(2.0 * math.pi * 2.0 * hz(65) * t)
    env = np.minimum(t / 0.012, 1.0) * np.minimum((0.24 - t) / 0.03, 1.0)
    return np.tanh(sig * 1.4) * np.clip(env, 0.0, 1.0) * vol


def air_door_hiss(rng: np.random.Generator, vol: float = 0.11) -> np.ndarray:
    """Ring durağa yanaşıp kapısını açarken gerçekçi pnömatik 'pısss' kapı sesi."""
    n = int(0.38 * SR)
    t = np.arange(n, dtype=np.float64) / SR
    hp = np.diff(np.diff(rng.uniform(-1.0, 1.0, n), prepend=0.0), prepend=0.0)
    env = np.minimum(t / 0.015, 1.0) * np.exp(-t * 7.5)
    return hp * env * vol


def add_stereo(L: np.ndarray, R: np.ndarray, sig_l: np.ndarray, sig_r: np.ndarray, at: float) -> None:
    i = int(at * SR)
    if i >= len(L) or i < 0:
        return
    j = min(len(L), i + len(sig_l))
    L[i:j] += sig_l[: j - i]
    R[i:j] += sig_r[: j - i]


def add_pan(L: np.ndarray, R: np.ndarray, sig: np.ndarray, at: float, pan: float = 0.0) -> None:
    gl = math.sqrt(0.5 * (1.0 - pan))
    gr = math.sqrt(0.5 * (1.0 + pan))
    add_stereo(L, R, sig * gl, sig * gr, at)


def apply_reverb(L: np.ndarray, R: np.ndarray, wet: float = 0.21) -> tuple[np.ndarray, np.ndarray]:
    outL = L.copy()
    outR = R.copy()
    taps = [(0.027, 0.34, True), (0.051, 0.25, False), (0.086, 0.19, True), (0.137, 0.13, False), (0.203, 0.08, True)]
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


def make(
    path: str,
    cut_times: list[float],
    high_energy_start: float = 19.0,
    star_start: float = 24.5,
    impact_at: float = 25.85,
    outro_start: float = 26.5,
    total: float = 30.5,
) -> None:
    rng = np.random.default_rng(20261125)
    n_total = int((total + 1.0) * SR)
    L = np.zeros(n_total, dtype=np.float64)
    R = np.zeros(n_total, dtype=np.float64)

    # Açılış otobüs kornası (t=0.18, 0.42) + Ring kapı açılış pnömatik sesi (t=1.18)
    add_pan(L, R, bus_horn_chord(0.10), 0.18, -0.25)
    add_pan(L, R, bus_horn_chord(0.08), 0.44, -0.25)
    add_pan(L, R, air_door_hiss(rng, 0.13), 1.18, 0.20)

    # Sahne kesmelerinde hafif sinematik whoosh + parlak crash vurgusu
    for ct in cut_times:
        if 0.5 < ct < star_start - 0.1:
            wL, wR = whoosh_transition(rng, 0.26, 0.10)
            add_stereo(L, R, wL, wR, max(0.0, ct - 0.13))
        if ct in (0.0, 9.0, 11.5, 19.0, 26.5):
            cL, cR = crash_shimmer(rng, 0.9, 0.095)
            add_stereo(L, R, cL, cR, ct)

    beat = 0
    t = 0.0
    while t < total:
        bar = beat // 4
        chord = CHORDS[bar % 4]
        root = BASS_ROOTS[bar % 4]
        in_star = star_start <= t < outro_start
        in_high = high_energy_start <= t < star_start
        in_outro = t >= outro_start

        if beat % 4 == 0:
            pL, pR = stereo_pad(chord, BEAT * 4.0, 0.062 if not in_star else 0.095)
            add_stereo(L, R, pL, pR, t)
            if not in_star:
                for idx, m in enumerate(chord):
                    pan = -0.36 + 0.72 * (idx / max(len(chord) - 1, 1))
                    add_pan(L, R, epiano(m + 12, BEAT * 3.6, 0.075), t + idx * 0.012, pan)

        if not in_star:
            # 4-on-the-floor enerjik dans/indie-pop kick!
            add_pan(L, R, kick(0.54 if (in_high or in_outro) else 0.48), t, 0.0)
            if beat % 2 == 1:
                add_pan(L, R, clap_snare(rng, 0.24 if (in_high or in_outro) else 0.19), t, 0.06)

            # Off-beat açık hi-hat + 16'lık kapalı hi-hat sürüşü
            add_pan(L, R, hihat(rng, in_high or in_outro, 0.072), t + BEAT * 0.5, -0.24)
            add_pan(L, R, hihat(rng, False, 0.048), t + BEAT * 0.25, 0.22)
            if in_high or in_outro or (beat % 2 == 1):
                add_pan(L, R, hihat(rng, False, 0.052), t + BEAT * 0.75, 0.18)

            # Funky oktav bas hattı (vuruşta kök nota, yarım vuruşta +12 oktav zıplaması!)
            add_pan(L, R, punch_bass(root, BEAT * 0.46, 0.24), t, 0.0)
            off_note = root + 12 if (beat % 4 != 3) else root + 7
            add_pan(L, R, punch_bass(off_note, BEAT * 0.42, 0.18), t + BEAT * 0.5, 0.0)

            # Akılda kalıcı melodi motifi
            seq = HOOK_B if (bar % 2 == 1) else HOOK_A
            for s in range(2):
                step = seq[(beat * 2 + s) % len(seq)]
                note = LEAD_NOTES[step % len(LEAD_NOTES)]
                pan = -0.28 if s == 0 else 0.28
                vol = 0.115 if (in_high or in_outro) else 0.092
                add_pan(L, R, synth_pluck(note, BEAT * 0.48, vol), t + s * BEAT * 0.5, pan)
                if in_high:
                    # Stadyum & Stil şovunda 16'lık parlak arpej
                    arp_m = chord[(beat * 2 + s) % len(chord)] + 24
                    add_pan(L, R, bell(arp_m, 0.28, 0.048), t + s * BEAT * 0.5 + BEAT * 0.25, -pan)
                if in_outro:
                    add_pan(L, R, bell(note + 12, BEAT * 0.95, 0.062), t + s * BEAT * 0.5, -pan)
        else:
            # Kayan yıldız sahnesinde göksel arp pırıltıları
            k = (t - star_start) / max(outro_start - star_start, 0.1)
            for s in range(4):
                note = 72 + int(k * 12) + [0, 4, 7, 11, 14][(beat * 4 + s) % 5]
                pan = math.sin((beat * 4 + s) * 0.85) * 0.55
                add_pan(L, R, bell(note, 0.42, 0.056), t + s * BEAT * 0.25, pan)

        beat += 1
        t = beat * BEAT

    # Yıldız düşüşü riser + çarpma sub-drop + Kutbi giriş göksel fanfarı
    r_dur = max(0.4, impact_at - star_start)
    rL, rR = riser(rng, r_dur, 0.26)
    add_stereo(L, R, rL, rR, star_start)
    add_pan(L, R, sub_drop(0.66), impact_at, 0.0)
    for idx, m in enumerate((72, 76, 79, 84, 88)):
        add_pan(L, R, bell(m, 2.2, 0.082), outro_start + idx * 0.04, -0.4 + idx * 0.2)

    # Parlak bitiş akoru
    for idx, m in enumerate((60, 64, 67, 71, 76, 84)):
        add_pan(L, R, bell(m, 2.0, 0.065), max(total - 1.8, 0.0) + idx * 0.03, -0.5 + idx * 0.2)

    L, R = apply_reverb(L, R, wet=0.22)

    end = int(total * SR)
    L, R = L[:end], R[:end]
    fade = int(0.55 * SR)
    ramp = np.linspace(1.0, 0.0, fade)
    L[-fade:] *= ramp
    R[-fade:] *= ramp

    L = np.tanh(L * 1.28) * 0.88
    R = np.tanh(R * 1.28) * 0.88

    stereo = np.empty(end * 2, dtype=np.int16)
    stereo[0::2] = (L * 32767.0).astype(np.int16)
    stereo[1::2] = (R * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(stereo.tobytes())
