"""UniPet Tanıtım Filmi v2 (9:16, 1080x1920, 30 fps, ~26.5 sn) kurgu ve motion-graphics motoru.

Claude'un v4 videosunun ötesine geçen yükseltmeler:
- Pillow (PIL) ile ultra keskin, cam-efektli (glassmorphic) RGBA tipografi + altın rozetler + spring pop-in
- Sinematik renk düzeltme (zengin kontrast + sıcak ışıklar + yumuşak vinyet)
- Sahne geçişlerinde hafif ışık flaşı / yumuşak geçiş (xfade)
- Zengin 48 kHz STEREO müzik (make_music_v2.py) + beat'e senkron oyun SFX katmanları
- Modern animasyonlu Kutbi Efsanevi Final & CTA End Card

Kullanım:
  python tools/ad/build_ad_v2.py <godot_v2.avi> <çıktı.mp4>
"""
import math
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_music_v2  # noqa: E402

W, H, FPS = 1080, 1920, 30
GODOT_SKIP = 51 / 30.0  # cinematic_v2.gd hazırlık süresi (30 + 20 + 1 kare)
SFX_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "sfx")

FONT_BLACK = "C:/Windows/Fonts/seguibl.ttf"
FONT_BOLD = "C:/Windows/Fonts/segoeuib.ttf"
FONT_REG = "C:/Windows/Fonts/segoeui.ttf"

# cinematic_v2.gd SHOTS:
#   0. queue    0.0 - 3.0   (3.0 sn)
#   1. drone    3.0 - 6.5   (3.5 sn)
#   2. dressup  6.5 - 10.5  (4.0 sn)
#   3. study    10.5 - 14.0 (3.5 sn)
#   4. gather   14.0 - 18.0 (4.0 sn)
#   5. star     18.0 - 21.5 (3.5 sn)
#   6. kutbi    21.5 - 26.5 (5.0 sn)
TOTAL_DUR = 26.5


def load_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def draw_rounded_glass(draw: ImageDraw.ImageDraw, box, radius: int, fill, outline=None, width: int = 2):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_centered_text(img: Image.Image, text: str, font: ImageFont.FreeTypeFont, cy: int,
                       fill=(255, 255, 255, 255), shadow_offset=(0, 6), shadow_alpha: int = 165,
                       stroke_width: int = 0, stroke_fill=(10, 16, 44, 255)):
    tmp = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    bbox = d.textbbox((0, 0), text, font=font, stroke_width=stroke_width)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (W - tw) // 2 - bbox[0]
    y = cy - th // 2 - bbox[1]

    # Yumuşak gölge
    if shadow_alpha > 0:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        sd.text((x + shadow_offset[0], y + shadow_offset[1]), text, font=font, fill=(6, 10, 28, shadow_alpha))
        sh = sh.filter(ImageFilter.GaussianBlur(radius=8))
        img.alpha_composite(sh)

    d.text((x, y), text, font=font, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)
    img.alpha_composite(tmp)
    return tw, th


def render_badge_and_title(badge: str | None, title: str, y_center: int = 320,
                           accent=(255, 214, 92, 255), title_color=(255, 255, 255, 255)) -> Image.Image:
    """Modern cam-efektli kart + üstte küçük altın rozet + kalın tipografi."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Başlık boyutunu metne göre ayarla
    t_size = 70 if len(title) <= 22 else 60
    f_title = load_font(FONT_BLACK, t_size)
    tb = d.textbbox((0, 0), title, font=f_title)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]

    # Cam kapsül (pill)
    pad_x, pad_y = 54, 30
    box = [W // 2 - tw // 2 - pad_x, y_center - th // 2 - pad_y,
           W // 2 + tw // 2 + pad_x, y_center + th // 2 + pad_y]
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([box[0], box[1] + 10, box[2], box[3] + 10], radius=34, fill=(4, 8, 24, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=14))
    img.alpha_composite(shadow)

    glass = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass)
    draw_rounded_glass(gd, box, radius=34, fill=(11, 18, 44, 188), outline=(255, 255, 255, 70), width=3)
    # Üstte ince parıltı çizgisi
    gd.line([(box[0] + 40, box[1] + 3), (box[2] - 40, box[1] + 3)], fill=(accent[0], accent[1], accent[2], 180), width=4)
    img.alpha_composite(glass)

    draw_centered_text(img, title, f_title, y_center, fill=title_color, shadow_offset=(0, 4), shadow_alpha=120)

    if badge:
        f_badge = load_font(FONT_BOLD, 34)
        bb = d.textbbox((0, 0), badge, font=f_badge)
        bw, bh = bb[2] - bb[0], bb[3] - bb[1]
        by = box[1] - 34
        bbox_r = [W // 2 - bw // 2 - 28, by - bh // 2 - 12, W // 2 + bw // 2 + 28, by + bh // 2 + 12]
        bg_badge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        bd = ImageDraw.Draw(bg_badge)
        draw_rounded_glass(bd, bbox_r, radius=24, fill=accent, outline=(255, 250, 220, 200), width=2)
        img.alpha_composite(bg_badge)
        draw_centered_text(img, badge, f_badge, by, fill=(14, 20, 48, 255), shadow_alpha=0)

    return img


def render_mystery_title(title: str, y_center: int = 330) -> Image.Image:
    """'Ama bir efsane var...' için sade, mistik altın parıltılı başlık."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f_title = load_font(FONT_BLACK, 72)
    # Altın dış parıltı (glow)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    tb = gd.textbbox((0, 0), title, font=f_title)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    x = (W - tw) // 2 - tb[0]
    y = y_center - th // 2 - tb[1]
    gd.text((x, y), title, font=f_title, fill=(255, 208, 90, 175))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=18))
    img.alpha_composite(glow)
    draw_centered_text(img, title, f_title, y_center, fill=(255, 244, 204, 255), shadow_offset=(0, 4), shadow_alpha=180)
    return img


def draw_star(draw: ImageDraw.ImageDraw, cx: float, cy: float, r_out: float, r_in: float, fill):
    pts = []
    for i in range(10):
        ang = -math.pi / 2.0 + i * math.pi / 5.0
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    draw.polygon(pts, fill=fill)


def render_endcard_top() -> Image.Image:
    """Kapanış üst blok: altın yıldızlı 'EFSANEVİ PET: KUTBİ' + büyük altın 'UniPet' + alt başlık."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Üstte altın EFSANEVİ rozet (vektör yıldızlı)
    badge_txt = "EFSANEVİ PET: KUTBİ"
    f_b = load_font(FONT_BOLD, 34)
    bb = d.textbbox((0, 0), badge_txt, font=f_b)
    bw, bh = bb[2] - bb[0], bb[3] - bb[1]
    by = 200
    b_box = [W // 2 - bw // 2 - 64, by - bh // 2 - 14, W // 2 + bw // 2 + 64, by + bh // 2 + 14]
    draw_rounded_glass(d, b_box, radius=28, fill=(255, 208, 76, 240), outline=(255, 248, 214, 230), width=3)
    draw_star(d, b_box[0] + 32, by, 13, 5.5, (14, 20, 50, 255))
    draw_star(d, b_box[2] - 32, by, 13, 5.5, (14, 20, 50, 255))
    draw_centered_text(img, badge_txt, f_b, by, fill=(14, 20, 50, 255), shadow_alpha=0)

    # Büyük parlayan UniPet başlığı
    f_logo = load_font(FONT_BLACK, 162)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    lb = gd.textbbox((0, 0), "UniPet", font=f_logo)
    lw, lh = lb[2] - lb[0], lb[3] - lb[1]
    lx = (W - lw) // 2 - lb[0]
    ly = 345 - lh // 2 - lb[1]
    gd.text((lx, ly), "UniPet", font=f_logo, fill=(255, 202, 70, 190))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=22))
    img.alpha_composite(glow)
    draw_centered_text(img, "UniPet", f_logo, 345, fill=(255, 234, 148, 255),
                       shadow_offset=(0, 8), shadow_alpha=210, stroke_width=8, stroke_fill=(12, 18, 52, 255))

    # Alt başlık
    f_sub = load_font(FONT_BOLD, 48)
    draw_centered_text(img, "Davutpaşa'yı petinle keşfet", f_sub, 468,
                       fill=(232, 240, 255, 255), shadow_offset=(0, 4), shadow_alpha=180)
    return img


def render_endcard_cta() -> Image.Image:
    """Kapanış alt CTA hapı: modern cam + altın kenar."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    txt = "KAPALI TESTTE  •  HEMEN KATIL"
    f_cta = load_font(FONT_BLACK, 44)
    cb = d.textbbox((0, 0), txt, font=f_cta)
    cw, ch = cb[2] - cb[0], cb[3] - cb[1]
    cy = 1605
    box = [W // 2 - cw // 2 - 58, cy - ch // 2 - 30, W // 2 + cw // 2 + 58, cy + ch // 2 + 30]

    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([box[0], box[1] + 8, box[2], box[3] + 8], radius=46, fill=(255, 205, 70, 95))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=18))
    img.alpha_composite(sh)

    draw_rounded_glass(d, box, radius=46, fill=(14, 22, 56, 220), outline=(255, 214, 92, 255), width=5)
    draw_centered_text(img, txt, f_cta, cy, fill=(255, 232, 140, 255), shadow_alpha=0)

    f_small = load_font(FONT_BOLD, 30)
    draw_centered_text(img, "YTÜ Davutpaşa  ·  Android", f_small, 1705,
                       fill=(210, 222, 248, 225), shadow_offset=(0, 3), shadow_alpha=140)
    return img


def render_top_watermark() -> Image.Image:
    """Sağ üstte çok zarif, yarı saydam 'UniPet' köşe rozeti (ilk 21.5 sn)."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = load_font(FONT_BLACK, 34)
    txt = "UniPet"
    b = d.textbbox((0, 0), txt, font=f)
    tw, th = b[2] - b[0], b[3] - b[1]
    rx = W - 46
    box = [rx - tw - 44, 62, rx, 62 + th + 26]
    draw_rounded_glass(d, box, radius=24, fill=(11, 18, 44, 125), outline=(255, 214, 92, 140), width=2)
    d.text((box[0] + 22 - b[0], box[1] + 13 - b[1]), txt, font=f, fill=(255, 236, 168, 230))
    return img


def main() -> None:
    godot_avi, out_mp4 = sys.argv[1], sys.argv[2]
    tmp_dir = tempfile.mkdtemp(prefix="unipet_ad_v2_")

    # 1. RGBA motion-graphics katmanlarını üret
    overlays = [
        ("ov_wm.png", render_top_watermark(), 0.2, 21.3, 0.3, 0.3, False),
        ("ov_queue.png", render_badge_and_title("YEMEKHANE", "Sıra yine 45 dk..."), 0.2, 2.85, 0.22, 0.2, True),
        ("ov_drone.png", render_badge_and_title("YTÜ DAVUTPAŞA", "Kampüsü petinle keşfet!"), 3.15, 6.35, 0.24, 0.2, True),
        ("ov_dress.png", render_badge_and_title("6 PET  ·  8 AKSESUAR", "Tarzını kendin yarat!"), 6.65, 10.35, 0.20, 0.2, True),
        ("ov_study1.png", render_badge_and_title("KÜTÜPHANE", "Vize haftası mı?"), 10.65, 11.95, 0.18, 0.12, True),
        ("ov_study2.png", render_badge_and_title("MOLA ZAMANI", "Petinle stres at!"), 12.05, 13.85, 0.16, 0.2, True),
        ("ov_gather.png", render_badge_and_title("ORTABAHÇE · CANLI", "Tüm Davutpaşa burada!"), 14.2, 17.8, 0.24, 0.25, True),
        ("ov_star.png", render_mystery_title("Ama bir efsane var..."), 18.25, 21.1, 0.45, 0.35, False),
        ("ov_end_top.png", render_endcard_top(), 21.75, 26.5, 0.35, 0.01, True),
        ("ov_end_cta.png", render_endcard_cta(), 22.55, 26.5, 0.35, 0.01, True),
    ]

    ov_paths = []
    for fname, im, *_rest in overlays:
        p = os.path.join(tmp_dir, fname)
        im.save(p, "PNG")
        ov_paths.append(p)

    # 2. Zengin STEREO müzik üret
    music_wav = os.path.join(tmp_dir, "music_v2.wav")
    make_music_v2.make(
        music_wav,
        dressup_start=6.5,
        star_start=18.0,
        impact_at=20.35,
        outro_start=21.5,
        total=TOTAL_DUR,
    )

    # 3. FFmpeg filter_complex oluştur
    inputs = ["-ss", "%.3f" % GODOT_SKIP, "-t", "%.3f" % TOTAL_DUR, "-i", godot_avi]
    for p in ov_paths:
        inputs += ["-loop", "1", "-t", "%.3f" % TOTAL_DUR, "-i", p]

    music_idx = 1 + len(ov_paths)
    inputs += ["-i", music_wav]

    # Oyun SFX'leri (tam sahne aksiyonlarına kilitli)
    sfx_events = [
        ("care_fail.ogg", 1.85, 0.55),     # kuyruk sonu üzgün
        ("teleport.ogg", 3.00, 0.45),      # drone geçişi
        ("ui_click.ogg", 6.50, 0.55),      # dressup beat 1
        ("emote.ogg", 7.00, 0.48),         # dressup beat 2
        ("ui_click.ogg", 7.50, 0.55),      # dressup beat 3
        ("emote.ogg", 8.00, 0.48),         # dressup beat 4
        ("ui_click.ogg", 8.50, 0.55),      # dressup beat 5
        ("emote.ogg", 9.00, 0.48),         # dressup beat 6
        ("care_ok.ogg", 9.50, 0.65),       # dressup final combo!
        ("care_fail.ogg", 10.60, 0.55),    # kütüphane üzgün
        ("teleport.ogg", 12.00, 0.70),     # kitaplar savrulur!
        ("emote.ogg", 12.15, 0.65),        # dans
        ("chat_receive.ogg", 14.25, 0.60), # balon 1
        ("chat_receive.ogg", 14.95, 0.60), # balon 2
        ("chat_send.ogg", 15.70, 0.60),    # balon 3
        ("chat_receive.ogg", 16.45, 0.60), # balon 4
        ("teleport.ogg", 18.20, 0.55),     # yıldız süzülür
        ("care_ok.ogg", 20.38, 0.85),      # yıldız çarpma parıltısı
        ("care_ok.ogg", 21.55, 0.85),      # Kutbi belirir
        ("emote.ogg", 22.25, 0.70),        # Kutbi el sallar
        ("emote.ogg", 23.85, 0.70),        # Kutbi dans
    ]
    sfx_base_idx = music_idx + 1
    for fname, _at, _vol in sfx_events:
        inputs += ["-i", os.path.join(SFX_DIR, fname)]

    filters = []
    # Temel video: ölçek + sinematik renk tonlaması (canlı kontrast, hafif keskinlik, zarif vinyet)
    filters.append(
        "[0:v]setpts=PTS-STARTPTS,fps=%d,scale=%d:%d:flags=lanczos:force_original_aspect_ratio=increase,"
        "crop=%d:%d,setsar=1,"
        "eq=contrast=1.08:saturation=1.18:brightness=0.01,"
        "unsharp=5:5:0.45:5:5:0.0,"
        "vignette=PI/6.5,"
        "format=rgba[base0]" % (FPS, W, H, W, H)
    )

    # Yıldız çarpma & Kutbi geçişinde (21.35 - 21.65) beyaz-altın sinematik flaş
    filters.append(
        "color=c=0xFFF6D6:s=%dx%d:d=%.3f,format=rgba,"
        "geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':"
        "a='if(between(T,21.28,21.72), 255*pow(sin((T-21.28)/0.44*PI),1.6), 0)'[flash]"
        % (W, H, TOTAL_DUR)
    )
    filters.append("[base0][flash]overlay=0:0:shortest=1[v_flashed]")

    # Motion-graphics overlay'lerini hafif yukarı kayma + fade-in/out ile bindir
    cur = "v_flashed"
    for i, (_fname, _im, t0, t1, fin, fout, slide) in enumerate(overlays):
        idx = 1 + i
        ov_tag = "ovf%d" % i
        nxt = "v_ov%d" % i
        f_chain = "[%d:v]format=rgba,fade=t=in:st=%.3f:d=%.3f:alpha=1" % (idx, t0, fin)
        if fout > 0.02:
            f_chain += ",fade=t=out:st=%.3f:d=%.3f:alpha=1" % (max(t1 - fout, t0), fout)
        f_chain += "[%s]" % ov_tag
        filters.append(f_chain)

        if slide:
            # 26 px yukarıdan yumuşak kayma (ease-out)
            y_expr = "if(lt(t-%.3f,%.3f), 26*pow(1-(t-%.3f)/%.3f,2), 0)" % (t0, fin, t0, fin)
        else:
            y_expr = "0"
        filters.append(
            "[%s][%s]overlay=x=0:y='%s':enable='between(t,%.3f,%.3f)':shortest=1[%s]"
            % (cur, ov_tag, y_expr, t0, t1, nxt)
        )
        cur = nxt

    filters.append("[%s]format=yuv420p[vout]" % cur)

    # Ses miksajı: stereo müzik + oyun SFX'leri
    filters.append("[%d:a]aresample=48000,aformat=channel_layouts=stereo,volume=0.82[mus]" % music_idx)
    mix = ["[mus]"]
    for j, (_fname, at, vol) in enumerate(sfx_events):
        ms = int(at * 1000)
        filters.append(
            "[%d:a]aresample=48000,aformat=channel_layouts=stereo,volume=%.2f,adelay=%d|%d[fx%d]"
            % (sfx_base_idx + j, vol, ms, ms, j)
        )
        mix.append("[fx%d]" % j)
    filters.append("%samix=inputs=%d:normalize=0:duration=first,alimiter=limit=0.95[aout]" % ("".join(mix), len(mix)))

    cmd = (
        ["ffmpeg", "-v", "warning", "-y"]
        + inputs
        + [
            "-filter_complex", ";".join(filters),
            "-map", "[vout]", "-map", "[aout]",
            "-c:v", "libx264", "-preset", "medium", "-crf", "21",
            "-maxrate", "3500k", "-bufsize", "7000k",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "192k",
            "-movflags", "+faststart",
            "-r", str(FPS),
            out_mp4,
        ]
    )
    subprocess.run(cmd, check=True)
    print("TAMAM: %s (%.1f sn)" % (out_mp4, TOTAL_DUR))


if __name__ == "__main__":
    main()
