"""UniPet reklam filmi (Reels/TikTok, 9:16, ~20 sn) kurgusu: Flow (Veo) klipleri + Godot sinematiği + yazılar.

Kullanım:  python tools/ad/build_ad.py <veo_klasörü> <godot.avi> <çıktı.mp4>
Veo klipleri (Talha, 2026-11-22, Downloads):
  Student_waiting_in_cafeteria_queue_*.mp4      S1 kanca
  Student_buried_under_textbooks_*.mp4           S3 kütüphane
  Star_creature_emerges_in_courtyard_*.mp4       S6 Kutbi'nin gelişi
  Student_holds_glowing_smartphone*_*.mp4        S2 Kutbi avuçta
  Golden_star_revealing_silhouette*_*.mp4        S7 kapanış
Godot: tools/ad/cinematic.gd ile Movie Maker kaydı (ilk GODOT_SKIP kare hazırlık).
"""
import glob
import os
import subprocess
import sys

W, H, FPS = 1080, 1920, 30
FONT = "C\\:/Windows/Fonts/seguibl.ttf"   # Segoe UI Black (Türkçe karakterli)
FONT2 = "C\\:/Windows/Fonts/segoeuib.ttf"
GODOT_SKIP = 51 / 30.0                       # cinematic.gd hazırlık süresi
SFX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "sfx")

# (kaynak anahtarı, başlangıç, bitiş, hız, ekrandaki yazı)
# cinematic.gd SHOTS: queue 0–2.8, drone 2.8–7.4, dance 7.4–9.4, gather 9.4–11.8, star 11.8–15.0
# (Talha: Veo'nun 1., 2. ve 4. videosu çıkarıldı; yerlerine Godot çekimleri)
SEGMENTS = [
    ("godot", 0.0, 2.8, 1.0, "Yemekhane sırası: 45 dk..."),
    ("godot", 3.0, 7.3, 1.0, "Bu kampüsü petinle gez"),
    ("godot", 7.5, 9.3, 1.0, "Petin sırada beklemez"),
    ("library", 0.0, 1.4, 1.0, "Vize haftası mı?"),
    ("library", 6.2, 7.8, 1.0, "Vize haftası mı?"),
    ("godot", 9.4, 11.7, 1.0, "Tüm Davutpaşa burada"),
    ("godot", 11.8, 15.0, 1.0, "Ama bir efsane var..."),
    ("outro", 1.3, 7.8, 2.0, None),          # None = kapanış kartı yazıları (Kutbi siluetten çıkıyor)
]


def find(folder, pattern):
    hits = sorted(glob.glob(os.path.join(folder, pattern)))
    if not hits:
        sys.exit("bulunamadı: " + pattern)
    return hits[-1]


def esc(text):
    return text.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


def caption(text, start, dur):
    """Üst üçte bir: kalın beyaz yazı + koyu kenar; hafif belirme."""
    if not text:
        return ""
    fade = "alpha='if(lt(t-%.2f,0.18),(t-%.2f)/0.18,1)'" % (start, start)
    # Segoe UI Black'te karakter ~0.6×boyut genişlikte: kenarlardan en az ~60 px boşluk kalsın
    size = min(76, int((W - 140) / (len(text) * 0.6)))
    return (",drawtext=fontfile='%s':text='%s':fontsize=%d:fontcolor=white:borderw=7:bordercolor=0x10183a:"
            "x=(w-text_w)/2:y=h*0.17:enable='between(t,%.2f,%.2f)':%s") % (FONT, esc(text), size, start, start + dur, fade)


def outro_text(start, dur):
    parts = []
    for txt, size, y, delay, font in (("UniPet", 150, 0.13, 0.3, FONT), ("Efsanevi pet geliyor", 64, 0.235, 0.7, FONT2),
                                      ("YAKINDA  -  Takip et", 58, 0.82, 1.1, FONT)):
        s = start + delay
        parts.append((",drawtext=fontfile='%s':text='%s':fontsize=%d:fontcolor=0xFFD86B:borderw=6:bordercolor=0x0b1030:"
                      "x=(w-text_w)/2:y=h*%.3f:enable='gte(t,%.2f)':alpha='min(1,(t-%.2f)/0.35)'")
                     % (font, esc(txt), size, y, s, s))
    return "".join(parts)


def main():
    folder, godot_avi, out = sys.argv[1], sys.argv[2], sys.argv[3]
    src = {
        "library": find(folder, "Student_buried_under_textbooks_*.mp4"),
        "outro": find(folder, "Golden_star_revealing_silhouette*.mp4"),
        "godot": godot_avi,
    }
    inputs, filters, concat = [], [], []
    t = 0.0
    sfx_inputs = []
    for i, (key, a, b, speed, text) in enumerate(SEGMENTS):
        off = GODOT_SKIP if key == "godot" else 0.0
        inputs += ["-ss", "%.3f" % (a + off), "-t", "%.3f" % (b - a), "-i", src[key]]
        dur = (b - a) / speed
        v = ("[%d:v]setpts=(PTS-STARTPTS)/%.3f,fps=%d,scale=%d:%d:flags=lanczos:force_original_aspect_ratio=increase,"
             "crop=%d:%d,setsar=1,format=yuv420p" % (i, speed, FPS, W, H, W, H))
        v += caption(text, 0.0, dur) if text else ""
        if text is None:
            v += outro_text(0.0, dur)
        v += "[v%d]" % i  # temiz kesme (karartmalı açılış her geçişte tek karelik siyah yanıp sönme yapıyordu)
        filters.append(v)
        if key == "godot":
            # Godot kaydında ses yok: sessiz taban + oyunun kendi efektleri (emote/sohbet)
            filters.append("anullsrc=r=48000:cl=stereo,atrim=0:%.3f[a%d]" % (dur, i))
            sfx_inputs.append((t, key, a))
        else:
            filters.append("[%d:a]atempo=%.3f,aresample=48000,aformat=channel_layouts=stereo,atrim=0:%.3f,"
                           "afade=t=in:d=0.05,afade=t=out:st=%.3f:d=0.08[a%d]"
                           % (i, speed if speed <= 2.0 else 2.0, dur, max(dur - 0.08, 0), i))
        concat.append("[v%d][a%d]" % (i, i))
        t += dur
    n = len(SEGMENTS)
    filters.append("%sconcat=n=%d:v=1:a=1[vout][abase]" % ("".join(concat), n))
    # oyun efektleri: dans anında emote, toplanmada sohbet sesleri
    def seg_start(i):
        return sum((b - a) / sp for (_k, a, b, sp, _t) in SEGMENTS[:i])
    # segment sırası: 0 kuyruk, 1 drone, 2 dans, 3-4 kütüphane, 5 toplanma, 6 kayan yıldız, 7 kapanış
    fx = [("care_fail.ogg", seg_start(0) + 2.0),                       # sondaki mantar üzülüyor
          ("teleport.ogg", seg_start(1) + 0.05),                       # drone'a geçiş
          ("emote.ogg", seg_start(2) + 0.1), ("emote.ogg", seg_start(2) + 1.0),
          ("chat_receive.ogg", seg_start(5) + 0.3), ("chat_receive.ogg", seg_start(5) + 0.9), ("chat_send.ogg", seg_start(5) + 1.5),
          ("teleport.ogg", seg_start(6) + 0.3), ("care_ok.ogg", seg_start(6) + 2.4)]   # yıldız düşer, iniş parıltısı
    base = len(SEGMENTS)
    mix = ["[abase]"]
    for j, (f, at) in enumerate(fx):
        inputs += ["-i", os.path.join(SFX, f)]
        filters.append("[%d:a]aresample=48000,aformat=channel_layouts=stereo,volume=0.7,adelay=%d|%d[fx%d]"
                       % (base + j, int(at * 1000), int(at * 1000), j))
        mix.append("[fx%d]" % j)
    filters.append("%samix=inputs=%d:normalize=0:duration=first[aout]" % ("".join(mix), len(mix)))
    cmd = ["ffmpeg", "-v", "error", "-y"] + inputs + ["-filter_complex", ";".join(filters), "-map", "[vout]", "-map", "[aout]",
                                                      "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
                                                      "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-r", str(FPS), out]
    subprocess.run(cmd, check=True)
    print("tamam: %s (%.1f sn)" % (out, t))


if __name__ == "__main__":
    main()
