"""UniPet Tanıtım Filmi v3 (9:16, 1080x1920, 30 fps, 31.5 sn) — kurgu, yazılar, harita kartı, müzik ve ses.

Yeni ikonik içerik: A Kapısı'nda gerçek İETT durağı + Mavi Ring, kampüs içi Ring yolculuğu, 11 gerçek durak haritası,
Tarihi Hamam / ARTLAB / ESLAB / Sami, Hokka'da sohbet + Doğrulanmış YTÜ profil kartı, kampüs kedileri,
Stadyum koşu yarışı, pet + aksesuar, efsanevi Kutbi finali.

Kullanım:
  godot_console --path game --write-movie v3.avi --fixed-fps 30 --resolution 1080x1920 -s tools/ad/cinematic_v3.gd
  python tools/ad/build_ad_v3.py v3.avi docs/media/unipet_tanitim_v3.mp4
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import build_ad_v2 as v2  # noqa: E402  (tipografi / cam kart / kapanış yardımcıları)
import make_music_v2  # noqa: E402

W, H, FPS = 1080, 1920, 30
GODOT_SKIP = 51 / 30.0
SFX_DIR = os.path.join(ROOT, "game", "assets", "sfx")
TOTAL_DUR = 31.5
# cinematic_v3.gd SHOTS
T = {"gate": 0.0, "ride": 3.5, "map": 7.0, "hamam": 9.5, "social": 13.5, "cats": 17.0, "race": 20.0, "dressup": 23.5, "kutbi": 26.5}


def render_map_card() -> Image.Image:
    """Tam ekran kart: kampüs araç yolları, Mavi Ring hattı ve 11 gerçek İETT durağı."""
    zone = json.load(open(os.path.join(ROOT, "game", "data", "zones", "davutpasa_campus.json"), encoding="utf8"))
    rt = json.load(open(os.path.join(ROOT, "game", "data", "transit_routes.json"), encoding="utf8"))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    card = [50, 250, W - 50, 1720]
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([card[0], card[1] + 14, card[2], card[3] + 14], radius=48, fill=(2, 6, 20, 170))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(18)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(card, radius=48, fill=(10, 18, 44, 238), outline=(255, 214, 92, 200), width=4)

    xs = [p[0] for p in rt["waypoints"]]
    zs = [p[1] for p in rt["waypoints"]]
    x0, x1, z0, z1 = min(xs) - 40, max(xs) + 40, min(zs) - 40, max(zs) + 40
    box = [card[0] + 40, 520, card[2] - 40, card[3] - 60]
    sc = min((box[2] - box[0]) / (x1 - x0), (box[3] - box[1]) / (z1 - z0))
    ox = box[0] + ((box[2] - box[0]) - (x1 - x0) * sc) / 2
    oy = box[1] + ((box[3] - box[1]) - (z1 - z0) * sc) / 2

    def P(p):
        return (ox + (p[0] - x0) * sc, oy + (p[1] - z0) * sc)

    for b in zone["buildings"]:
        pts = [P(p) for p in b["points"]]
        if len(pts) >= 3:
            d.polygon(pts, fill=(40, 56, 96, 255))
    for p in zone["paths"]:
        if p["kind"] in ("residential", "residential_oneway", "service"):
            d.line([P(q) for q in p["points"]], fill=(78, 96, 140, 255), width=4)
    loop = [P(q) for q in rt["waypoints"]] + [P(rt["waypoints"][0])]
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).line(loop, fill=(70, 150, 255, 200), width=22, joint="curve")
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10)))
    d = ImageDraw.Draw(img)
    d.line(loop, fill=(60, 140, 255, 255), width=10, joint="curve")

    f_num = v2.load_font(v2.FONT_BLACK, 26)
    f_lbl = v2.load_font(v2.FONT_BOLD, 26)
    label_side = {0: "l", 1: "r", 2: "r", 3: "r", 4: "r", 5: "r", 6: "r", 7: "r", 8: "r", 9: "r", 10: "l"}
    short = {"Davutpaşa Kampüsü (A Kapısı)": "A Kapısı", "İktisadi ve İdari Bilimler Fakültesi": "İİBF",
             "YTÜ Davutpaşa Kampüsü (41AT son durak)": "41AT son durak", "Kütüphane (A Kapısı yönü)": "Kütüphane",
             "Yabancı Diller Okulu": "YDYO"}
    for i, s in enumerate(rt["stops"]):
        x, y = P(s["road_pos"])
        d.ellipse([x - 21, y - 21, x + 21, y + 21], fill=(255, 210, 70, 255), outline=(14, 20, 48, 255), width=4)
        num = str(i + 1)
        nb = d.textbbox((0, 0), num, font=f_num)
        d.text((x - (nb[2] - nb[0]) / 2 - nb[0], y - (nb[3] - nb[1]) / 2 - nb[1]), num, font=f_num, fill=(14, 20, 48, 255))
        if i == 10:
            continue  # Kütüphane iki yönlü; tek etiket yeter
        name = short.get(s["name"], s["name"])
        lb = d.textbbox((0, 0), name, font=f_lbl)
        lw = lb[2] - lb[0]
        lx = x + 30 if label_side.get(i, "r") == "r" else x - 30 - lw
        lx = max(card[0] + 20, min(card[2] - 20 - lw, lx))
        d.rounded_rectangle([lx - 10, y - 22, lx + lw + 10, y + 20], radius=12, fill=(8, 14, 36, 215))
        d.text((lx - lb[0], y - (lb[3] - lb[1]) / 2 - lb[1]), name, font=f_lbl, fill=(236, 242, 255, 255))

    # başlık
    v2.draw_centered_text(img, "11 GERÇEK İETT DURAĞI", v2.load_font(v2.FONT_BLACK, 62), 345, fill=(255, 226, 120, 255),
                          shadow_alpha=150)
    v2.draw_centered_text(img, "Mavi Ring ve 41AT gerçek güzergâhta", v2.load_font(v2.FONT_BOLD, 38), 425,
                          fill=(214, 226, 252, 255), shadow_alpha=120)
    return img


def render_profile_card() -> Image.Image:
    """Hokka sahnesinde beliren 'Kampüs Kimliği' kartı (oyundaki profil kartının sadeleştirilmiş hali)."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    card = [150, 1180, W - 150, 1690]
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([card[0], card[1] + 12, card[2], card[3] + 12], radius=40, fill=(2, 6, 20, 160))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(16)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(card, radius=40, fill=(16, 22, 46, 240), outline=(90, 140, 220, 255), width=4)
    cx = W // 2
    pill = [cx - 300, card[1] + 40, cx + 300, card[1] + 104]
    d.rounded_rectangle(pill, radius=30, fill=(20, 60, 140, 255), outline=(250, 210, 82, 255), width=3)
    f_p = v2.load_font(v2.FONT_BLACK, 30)
    # elle çizilmiş onay işareti
    d.line([(pill[0] + 36, pill[1] + 34), (pill[0] + 50, pill[1] + 48), (pill[0] + 76, pill[1] + 18)], fill=(255, 226, 120, 255), width=7)
    v2.draw_centered_text(img, "   DOĞRULANMIŞ YTÜ ÖĞRENCİSİ", f_p, pill[1] + 32, fill=(255, 234, 150, 255), shadow_alpha=0)
    v2.draw_centered_text(img, "@Zeynep", v2.load_font(v2.FONT_BLACK, 64), card[1] + 180, fill=(255, 255, 255, 255), shadow_alpha=0)
    v2.draw_centered_text(img, "Bölüm: Bilgisayar Müh.", v2.load_font(v2.FONT_BOLD, 36), card[1] + 252,
                          fill=(150, 214, 255, 255), shadow_alpha=0)
    v2.draw_centered_text(img, "Pet: Mushnub  ·  Kampüs Keşfi: 31/47", v2.load_font(v2.FONT_REG, 32), card[1] + 308,
                          fill=(196, 206, 228, 255), shadow_alpha=0)
    b1 = [card[0] + 40, card[1] + 360, cx - 14, card[1] + 460]
    b2 = [cx + 14, card[1] + 360, card[2] - 40, card[1] + 460]
    d.rounded_rectangle(b1, radius=26, fill=(48, 110, 230, 255))
    d.rounded_rectangle(b2, radius=26, fill=(36, 44, 76, 255), outline=(110, 130, 180, 255), width=2)
    f_b = v2.load_font(v2.FONT_BOLD, 34)
    for bx, txt in ((b1, "+ Arkadaş Ekle"), (b2, "Özel Mesaj")):
        tb = d.textbbox((0, 0), txt, font=f_b)
        d.text(((bx[0] + bx[2]) / 2 - (tb[2] - tb[0]) / 2 - tb[0], (bx[1] + bx[3]) / 2 - (tb[3] - tb[1]) / 2 - tb[1]), txt,
               font=f_b, fill=(255, 255, 255, 255))
    return img


def render_cta() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    txt = "YAKINDA GOOGLE PLAY'DE"
    f_cta = v2.load_font(v2.FONT_BLACK, 50)
    cb = d.textbbox((0, 0), txt, font=f_cta)
    cw, ch = cb[2] - cb[0], cb[3] - cb[1]
    cy = 1600
    box = [W // 2 - cw // 2 - 60, cy - ch // 2 - 32, W // 2 + cw // 2 + 60, cy + ch // 2 + 32]
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([box[0], box[1] + 8, box[2], box[3] + 8], radius=48, fill=(255, 205, 70, 95))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(18)))
    d.rounded_rectangle(box, radius=48, fill=(14, 22, 56, 225), outline=(255, 214, 92, 255), width=5)
    v2.draw_centered_text(img, txt, f_cta, cy, fill=(255, 232, 140, 255), shadow_alpha=0)
    v2.draw_centered_text(img, "YTÜ Davutpaşa  ·  Android  ·  Ücretsiz", v2.load_font(v2.FONT_BOLD, 32), 1705,
                          fill=(210, 222, 248, 230), shadow_offset=(0, 3), shadow_alpha=140)
    v2.draw_centered_text(img, "Bağımsız öğrenci projesidir · YTÜ'nün resmî uygulaması değildir",
                          v2.load_font(v2.FONT_REG, 24), 1835, fill=(190, 200, 225, 200), shadow_alpha=120)
    return img


def main() -> None:
    godot_avi, out_mp4 = sys.argv[1], sys.argv[2]
    tmp = tempfile.mkdtemp(prefix="unipet_ad_v3_")
    bt = v2.render_badge_and_title
    # (dosya, görüntü, başlangıç, bitiş, fade-in, fade-out, kayma)
    overlays = [
        ("wm.png", v2.render_top_watermark(), 0.2, T["kutbi"] - 0.1, 0.3, 0.3, False),
        ("gate.png", bt("YTÜ DAVUTPAŞA  ·  A KAPISI", "Ring geldi, atla!"), 0.25, T["ride"] - 0.15, 0.22, 0.2, True),
        ("ride.png", bt("MAVİ RİNG  &  41AT", "Kampüs artık canlı!"), T["ride"] + 0.15, T["map"] - 0.1, 0.22, 0.2, True),
        ("map.png", render_map_card(), T["map"] + 0.02, T["hamam"] - 0.02, 0.3, 0.3, False),
        ("hamam.png", bt("TARİHİ HAMAM", "ARTLAB Yapay Zeka Zirvesi"), T["hamam"] + 0.2, T["social"] - 0.15, 0.24, 0.2, True),
        ("social.png", bt("HOKKA  ·  CANLI SOHBET", "Arkadaş ekle, buluş!"), T["social"] + 0.15, T["cats"] - 0.15, 0.22, 0.2, True),
        ("card.png", render_profile_card(), T["social"] + 1.1, T["cats"] - 0.2, 0.25, 0.2, True),
        ("cats.png", bt("KAMPÜS KEDİLERİ", "Sev, oyna, miyavla!"), T["cats"] + 0.15, T["race"] - 0.15, 0.22, 0.2, True),
        ("race.png", bt("STADYUM", "Koşu yarışına katıl!"), T["race"] + 0.15, T["dressup"] - 0.15, 0.22, 0.2, True),
        ("dress.png", bt("7 PET  ·  11 AKSESUAR", "Tarzını kendin yarat!"), T["dressup"] + 0.1, T["kutbi"] - 0.2, 0.2, 0.2, True),
        ("end_top.png", v2.render_endcard_top(), T["kutbi"] + 0.3, TOTAL_DUR, 0.35, 0.01, True),
        ("end_cta.png", render_cta(), T["kutbi"] + 1.1, TOTAL_DUR, 0.35, 0.01, True),
    ]
    paths = []
    for fname, im, *_ in overlays:
        p = os.path.join(tmp, fname)
        im.save(p, "PNG")
        paths.append(p)

    music = os.path.join(tmp, "music.wav")
    make_music_v2.make(music, dressup_start=T["dressup"], star_start=T["kutbi"] - 0.9, impact_at=T["kutbi"],
                       outro_start=T["kutbi"], total=TOTAL_DUR)

    inputs = ["-ss", "%.3f" % GODOT_SKIP, "-t", "%.3f" % TOTAL_DUR, "-i", godot_avi]
    for p in paths:
        inputs += ["-loop", "1", "-t", "%.3f" % TOTAL_DUR, "-i", p]
    music_idx = 1 + len(paths)
    inputs += ["-i", music]
    sfx = [
        ("teleport.ogg", 1.7, 0.40), ("ui_click.ogg", 2.25, 0.55), ("emote.ogg", 2.4, 0.55),
        ("teleport.ogg", T["ride"], 0.45), ("ui_click.ogg", T["map"], 0.6), ("care_ok.ogg", T["map"] + 0.35, 0.45),
        ("care_ok.ogg", T["hamam"] + 0.2, 0.5), ("chat_receive.ogg", T["hamam"] + 1.6, 0.6),
        ("chat_receive.ogg", T["social"] + 0.15, 0.6), ("chat_send.ogg", T["social"] + 0.8, 0.6),
        ("ui_click.ogg", T["social"] + 1.1, 0.6), ("chat_receive.ogg", T["social"] + 1.5, 0.6),
        ("chat_receive.ogg", T["social"] + 2.2, 0.6),
        ("meow.wav", T["cats"] + 0.1, 0.55), ("meow.wav", T["cats"] + 1.1, 0.5), ("meow.wav", T["cats"] + 2.1, 0.5),
        ("teleport.ogg", T["race"], 0.45), ("step.ogg", T["race"] + 0.4, 0.5), ("step.ogg", T["race"] + 0.8, 0.5),
        ("step.ogg", T["race"] + 1.2, 0.5), ("step.ogg", T["race"] + 1.6, 0.5),
    ] + [("ui_click.ogg" if i % 2 == 0 else "emote.ogg", T["dressup"] + 0.5 * i, 0.55) for i in range(6)] + [
        ("care_ok.ogg", T["kutbi"], 0.85), ("emote.ogg", T["kutbi"] + 0.75, 0.7), ("emote.ogg", T["kutbi"] + 2.35, 0.7),
    ]
    sfx_base = music_idx + 1
    for fname, _a, _v in sfx:
        inputs += ["-i", os.path.join(SFX_DIR, fname)]

    f = []
    f.append("[0:v]setpts=PTS-STARTPTS,fps=%d,scale=%d:%d:flags=lanczos:force_original_aspect_ratio=increase,crop=%d:%d,setsar=1,"
             "eq=contrast=1.07:saturation=1.16:brightness=0.01,unsharp=5:5:0.4:5:5:0.0,vignette=PI/7,format=rgba[b0]"
             % (FPS, W, H, W, H))
    fk = T["kutbi"]
    f.append("color=c=0xFFF6D6:s=%dx%d:d=%.3f,format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':"
             "a='if(between(T,%.2f,%.2f), 255*pow(sin((T-%.2f)/0.44*PI),1.6), 0)'[fl]" % (W, H, TOTAL_DUR, fk - 0.22, fk + 0.22, fk - 0.22))
    f.append("[b0][fl]overlay=0:0:shortest=1[v0]")
    cur = "v0"
    for i, (_n, _im, t0, t1, fin, fout, slide) in enumerate(overlays):
        tag, nxt = "o%d" % i, "v%d" % (i + 1)
        chain = "[%d:v]format=rgba,fade=t=in:st=%.3f:d=%.3f:alpha=1" % (1 + i, t0, fin)
        if fout > 0.02:
            chain += ",fade=t=out:st=%.3f:d=%.3f:alpha=1" % (max(t1 - fout, t0), fout)
        f.append(chain + "[%s]" % tag)
        y = "if(lt(t-%.3f,%.3f), 26*pow(1-(t-%.3f)/%.3f,2), 0)" % (t0, fin, t0, fin) if slide else "0"
        f.append("[%s][%s]overlay=x=0:y='%s':enable='between(t,%.3f,%.3f)':shortest=1[%s]" % (cur, tag, y, t0, t1, nxt))
        cur = nxt
    f.append("[%s]format=yuv420p[vout]" % cur)
    f.append("[%d:a]aresample=48000,aformat=channel_layouts=stereo,volume=0.82[mus]" % music_idx)
    mix = ["[mus]"]
    for j, (_n, at, vol) in enumerate(sfx):
        ms = int(at * 1000)
        f.append("[%d:a]aresample=48000,aformat=channel_layouts=stereo,volume=%.2f,adelay=%d|%d[x%d]" % (sfx_base + j, vol, ms, ms, j))
        mix.append("[x%d]" % j)
    f.append("%samix=inputs=%d:normalize=0:duration=first,alimiter=limit=0.95[aout]" % ("".join(mix), len(mix)))

    cmd = ["ffmpeg", "-v", "warning", "-y"] + inputs + [
        "-filter_complex", ";".join(f), "-map", "[vout]", "-map", "[aout]",
        "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-maxrate", "4000k", "-bufsize", "8000k",
        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-r", str(FPS), out_mp4]
    subprocess.run(cmd, check=True)
    print("TAMAM: %s (%.1f sn)" % (out_mp4, TOTAL_DUR))


if __name__ == "__main__":
    main()
