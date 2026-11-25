"""UniPet Tanıtım Filmi (agy kurgusu) (9:16, 1080x1920, 30 fps, 30.5 sn) motion-graphics ve ses kurgu motoru.

Öne çıkan özellikler:
- 10 ikonik YTÜ Davutpaşa sahnesi (41AT & Mavi Ring, Yıldız Store, I ❤ YTU & Kediler, Yeni Merkez Kütüphanesi,
  Tarihi Hamam & ARTLAB & ESLAB & Sami NPC, Hokka Kafe & Kampüs Kimliği & Canlı Harita v2, Stadyum Yarış & Frizbi,
  6 Pet & 11 Aksesuar, Gece Sokak Lambaları & Kayan Yıldız, Efsanevi Kutbi Finali)
- Pillow (PIL) ile cam-efektli (glassmorphic) başlık kartları + gerçek veriden çizilen Canlı Harita v2 mini radarı
  + ✓ Doğrulanmış YTÜ Öğrencisi Kampüs Kimliği kartı + canlı Ring/Yarış/Yıldız Tozu durum rozetleri
- Zengin 48 kHz STEREO müzik (make_music_agy.py) + kedi miyavlaması (meow.wav) dahil tam oyun SFX katmanları

Kullanım:
  python tools/ad/build_ad_agy.py <godot_v3.avi> <çıktı.mp4> [önizleme.gif]
"""
import json
import math
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_music_agy  # noqa: E402

W, H, FPS = 1080, 1920, 30
GODOT_SKIP = 51 / 30.0  # cinematic_agy.gd ısınma süresi (1 + 30 + 20 = 51 kare)
TOTAL_DUR = 30.5

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SFX_DIR = os.path.join(REPO_ROOT, "game", "assets", "sfx")
TRANSIT_JSON = os.path.join(REPO_ROOT, "game", "data", "transit_routes.json")
CAMPUS_JSON = os.path.join(REPO_ROOT, "game", "data", "zones", "davutpasa_campus.json")

FONT_BLACK = "C:/Windows/Fonts/seguibl.ttf"
FONT_BOLD = "C:/Windows/Fonts/segoeuib.ttf"
FONT_REG = "C:/Windows/Fonts/segoeui.ttf"

# cinematic_agy.gd SHOTS zaman tablosu:
#   0. gate          0.0 -  3.0  (3.0 sn)
#   1. yildiz_store  3.0 -  6.0  (3.0 sn)
#   2. love_cats     6.0 -  9.0  (3.0 sn)
#   3. merkez_lib    9.0 - 11.5  (2.5 sn)
#   4. hamam        11.5 - 15.5  (4.0 sn)
#   5. social       15.5 - 19.0  (3.5 sn)
#   6. stadium      19.0 - 22.0  (3.0 sn)
#   7. dressup      22.0 - 24.5  (2.5 sn)
#   8. star         24.5 - 26.5  (2.0 sn)
#   9. kutbi        26.5 - 30.5  (4.0 sn)
CUT_TIMES = [0.0, 3.0, 6.0, 9.0, 11.5, 13.0, 15.5, 19.0, 22.0, 24.5, 26.5]


def load_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def draw_rounded_glass(draw: ImageDraw.ImageDraw, box, radius: int, fill, outline=None, width: int = 2) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_star(draw: ImageDraw.ImageDraw, cx: float, cy: float, r_out: float, r_in: float, fill) -> None:
    pts = []
    for i in range(10):
        ang = -math.pi / 2.0 + i * math.pi / 5.0
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    draw.polygon(pts, fill=fill)


def draw_checkmark(draw: ImageDraw.ImageDraw, cx: float, cy: float, size: float, fill, width: int = 4) -> None:
    p1 = (cx - size * 0.55, cy + size * 0.05)
    p2 = (cx - size * 0.12, cy + size * 0.48)
    p3 = (cx + size * 0.62, cy - size * 0.45)
    draw.line([p1, p2, p3], fill=fill, width=width, joint="curve")


def draw_centered_text(
    img: Image.Image,
    text: str,
    font: ImageFont.FreeTypeFont,
    cy: int,
    fill=(255, 255, 255, 255),
    shadow_offset=(0, 6),
    shadow_alpha: int = 165,
    stroke_width: int = 0,
    stroke_fill=(10, 16, 44, 255),
):
    tmp = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    bbox = d.textbbox((0, 0), text, font=font, stroke_width=stroke_width)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (W - tw) // 2 - bbox[0]
    y = cy - th // 2 - bbox[1]

    if shadow_alpha > 0:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        sd.text((x + shadow_offset[0], y + shadow_offset[1]), text, font=font, fill=(6, 10, 28, shadow_alpha))
        sh = sh.filter(ImageFilter.GaussianBlur(radius=8))
        img.alpha_composite(sh)

    d.text((x, y), text, font=font, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)
    img.alpha_composite(tmp)
    return tw, th


def render_badge_and_title(
    badge: str,
    title: str,
    subtitle: str | None = None,
    y_center: int = 295,
    accent=(255, 212, 84, 255),
) -> Image.Image:
    """Üstte renkli kategori rozeti + cam kapsül içinde keskin ana başlık + isteğe bağlı alt satır."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    t_size = 64 if len(title) <= 22 else (56 if len(title) <= 27 else 50)
    f_title = load_font(FONT_BLACK, t_size)
    tb = d.textbbox((0, 0), title, font=f_title)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]

    f_sub = load_font(FONT_BOLD, 31) if subtitle else None
    sw, sh_h = 0, 0
    if subtitle and f_sub:
        sb = d.textbbox((0, 0), subtitle, font=f_sub)
        sw, sh_h = sb[2] - sb[0], sb[3] - sb[1]

    inner_w = max(tw, sw)
    inner_h = th + (sh_h + 16 if subtitle else 0)
    pad_x, pad_y = 50, 28
    box = [
        max(36, W // 2 - inner_w // 2 - pad_x),
        y_center - inner_h // 2 - pad_y,
        min(W - 36, W // 2 + inner_w // 2 + pad_x),
        y_center + inner_h // 2 + pad_y,
    ]

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([box[0], box[1] + 10, box[2], box[3] + 10], radius=36, fill=(4, 8, 24, 165))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=14))
    img.alpha_composite(shadow)

    glass = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass)
    draw_rounded_glass(gd, box, radius=36, fill=(10, 17, 42, 198), outline=(255, 255, 255, 78), width=3)
    gd.line([(box[0] + 42, box[1] + 3), (box[2] - 42, box[1] + 3)], fill=(accent[0], accent[1], accent[2], 195), width=4)
    img.alpha_composite(glass)

    title_y = y_center - (sh_h // 2 + 8) if subtitle else y_center
    draw_centered_text(img, title, f_title, title_y, fill=(255, 255, 255, 255), shadow_offset=(0, 4), shadow_alpha=130)
    if subtitle and f_sub:
        draw_centered_text(
            img,
            subtitle,
            f_sub,
            title_y + th // 2 + sh_h // 2 + 16,
            fill=(208, 226, 255, 245),
            shadow_offset=(0, 2),
            shadow_alpha=100,
        )

    # Üst rozet
    f_badge = load_font(FONT_BLACK, 31)
    bb = d.textbbox((0, 0), badge, font=f_badge)
    bw, bh = bb[2] - bb[0], bb[3] - bb[1]
    by = box[1] - 32
    bbox_r = [W // 2 - bw // 2 - 30, by - bh // 2 - 12, W // 2 + bw // 2 + 30, by + bh // 2 + 12]
    bg_badge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bg_badge)
    draw_rounded_glass(bd, bbox_r, radius=24, fill=accent, outline=(255, 250, 224, 220), width=2)
    img.alpha_composite(bg_badge)
    draw_centered_text(img, badge, f_badge, by, fill=(12, 18, 46, 255), shadow_alpha=0)

    return img


def render_bottom_hud_pill(left_tag: str, right_text: str, tag_bg=(28, 118, 236, 255), y_pos: int = 1715) -> Image.Image:
    """Alt kısımda oyun içi canlı sistem bilgisini gösteren şık HUD hapı."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f_tag = load_font(FONT_BLACK, 28)
    f_txt = load_font(FONT_BOLD, 30)

    tb1 = d.textbbox((0, 0), left_tag, font=f_tag)
    w1, h1 = tb1[2] - tb1[0], tb1[3] - tb1[1]
    tb2 = d.textbbox((0, 0), right_text, font=f_txt)
    w2, h2 = tb2[2] - tb2[0], tb2[3] - tb2[1]

    total_w = w1 + 42 + 24 + w2 + 44
    box = [W // 2 - total_w // 2, y_pos - 40, W // 2 + total_w // 2, y_pos + 40]

    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([box[0], box[1] + 6, box[2], box[3] + 6], radius=40, fill=(4, 8, 22, 160))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=10))
    img.alpha_composite(sh)

    draw_rounded_glass(d, box, radius=40, fill=(11, 18, 42, 215), outline=(255, 255, 255, 75), width=2)
    pill_in = [box[0] + 12, box[1] + 11, box[0] + 12 + w1 + 36, box[3] - 11]
    draw_rounded_glass(d, pill_in, radius=29, fill=tag_bg)
    d.text((pill_in[0] + 18 - tb1[0], y_pos - h1 // 2 - tb1[1]), left_tag, font=f_tag, fill=(255, 255, 255, 255))
    d.text((pill_in[2] + 20 - tb2[0], y_pos - h2 // 2 - tb2[1]), right_text, font=f_txt, fill=(238, 245, 255, 255))
    return img


def render_social_showcase_cards() -> Image.Image:
    """Hokka sahnesinde (15.5-19.0 sn) alt kısımda yan yana beliren:
    Sol: Canlı Kampüs Haritası v2 mini radarı (gerçek 11 Ring durağı + Mavi Ring + 41AT)
    Sağ: ✓ Doğrulanmış YTÜ Öğrencisi Kampüs Kimliği v2 kartı!
    """
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Gölge katmanı
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    map_box = [44, 1340, 464, 1790]
    prof_box = [492, 1340, 1036, 1790]
    sd.rounded_rectangle([map_box[0], map_box[1] + 10, map_box[2], map_box[3] + 10], radius=32, fill=(4, 8, 22, 175))
    sd.rounded_rectangle([prof_box[0], prof_box[1] + 10, prof_box[2], prof_box[3] + 10], radius=32, fill=(4, 8, 22, 175))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=14))
    img.alpha_composite(sh)

    d = ImageDraw.Draw(img)
    # --- SOL KART: CANLI HARİTA v2 ---
    draw_rounded_glass(d, map_box, radius=32, fill=(12, 20, 46, 228), outline=(92, 168, 255, 190), width=3)
    f_hdr = load_font(FONT_BLACK, 25)
    f_small = load_font(FONT_BOLD, 21)
    d.text((map_box[0] + 24, map_box[1] + 18), "HARİTA v2  ·  CANLI", font=f_hdr, fill=(138, 202, 255, 255))

    # Harita çizim alanı
    canvas = [map_box[0] + 20, map_box[1] + 62, map_box[2] - 20, map_box[3] - 62]
    draw_rounded_glass(d, canvas, radius=20, fill=(28, 48, 36, 240), outline=(255, 255, 255, 45), width=2)

    try:
        tr = json.load(open(TRANSIT_JSON, encoding="utf-8"))
        wps = tr.get("waypoints", [])
        stops = tr.get("stops", [])
        if wps:
            xs = [p[0] for p in wps]
            zs = [p[1] for p in wps]
            min_x, max_x = min(xs), max(xs)
            min_z, max_z = min(zs), max(zs)
            cw = canvas[2] - canvas[0] - 36
            ch = canvas[3] - canvas[1] - 36
            sc = min(cw / max(max_x - min_x, 1.0), ch / max(max_z - min_z, 1.0))
            ox = canvas[0] + 18 + (cw - (max_x - min_x) * sc) * 0.5
            oz = canvas[1] + 18 + (ch - (max_z - min_z) * sc) * 0.5

            def proj(px, pz):
                return (ox + (px - min_x) * sc, oz + (pz - min_z) * sc)

            # Binalardan hafif siluet
            if os.path.exists(CAMPUS_JSON):
                camp = json.load(open(CAMPUS_JSON, encoding="utf-8"))
                for b in camp.get("buildings", [])[:90]:
                    pts = b.get("footprint") or b.get("points") or []
                    if len(pts) >= 3:
                        p2 = [proj(pt[0], pt[1]) for pt in pts]
                        d.polygon(p2, fill=(210, 214, 206, 85))

            # Mavi Ring güzergah çizgisi
            route_pts = [proj(p[0], p[1]) for p in wps] + [proj(wps[0][0], wps[0][1])]
            d.line(route_pts, fill=(46, 148, 255, 235), width=6)

            # 11 gerçek İETT / Ring durağı
            for st in stops:
                sx, sz = proj(st["road_pos"][0], st["road_pos"][1])
                d.ellipse([sx - 5, sz - 5, sx + 5, sz + 5], fill=(255, 255, 255, 245), outline=(14, 48, 112, 255), width=2)

            # Canlı otobüs ikonları (3 Mavi Ring + 1 Sarı 41AT)
            for wi, col in [(22, (36, 146, 255, 255)), (110, (36, 146, 255, 255)), (195, (36, 146, 255, 255)), (64, (255, 196, 28, 255))]:
                bx, bz = proj(wps[wi % len(wps)][0], wps[wi % len(wps)][1])
                d.ellipse([bx - 9, bz - 9, bx + 9, bz + 9], fill=col, outline=(255, 255, 255, 255), width=2)
    except Exception:
        pass

    d.text((map_box[0] + 24, map_box[3] - 46), "11 Durak  ·  Ring & 41AT", font=f_small, fill=(224, 236, 255, 240))

    # --- SAĞ KART: KAMPÜS KİMLİĞİ v2 ---
    draw_rounded_glass(d, prof_box, radius=32, fill=(14, 21, 46, 234), outline=(255, 210, 88, 205), width=3)
    d.text((prof_box[0] + 26, prof_box[1] + 18), "KAMPÜS KİMLİĞİ", font=f_hdr, fill=(182, 208, 248, 255))

    # Doğrulanmış YTÜ Öğrencisi rozeti (vektör onay ikonlu — sıfır eksik glif!)
    v_box = [prof_box[0] + 26, prof_box[1] + 62, prof_box[2] - 26, prof_box[1] + 114]
    draw_rounded_glass(d, v_box, radius=24, fill=(20, 92, 64, 240), outline=(88, 236, 168, 220), width=2)
    draw_checkmark(d, v_box[0] + 28, (v_box[1] + v_box[3]) * 0.5, 15.0, (176, 255, 214, 255), width=4)
    f_ver = load_font(FONT_BLACK, 22)
    d.text((v_box[0] + 50, v_box[1] + 12), "DOĞRULANMIŞ YTÜ ÖĞRENCİSİ", font=f_ver, fill=(176, 255, 214, 255))

    f_nick = load_font(FONT_BLACK, 42)
    f_role = load_font(FONT_BOLD, 25)
    f_meta = load_font(FONT_REG, 23)
    d.text((prof_box[0] + 28, prof_box[1] + 132), "Zeynep", font=f_nick, fill=(255, 255, 255, 255))
    d.text((prof_box[0] + 28, prof_box[1] + 188), "Bilgisayar Mühendisliği  ·  3. Sınıf", font=f_role, fill=(130, 214, 255, 255))
    d.text((prof_box[0] + 28, prof_box[1] + 228), "Keşif: 42/47   ·   Hokka Kafe Salonu", font=f_meta, fill=(214, 224, 242, 245))

    # Aksiyon butonları
    btn1 = [prof_box[0] + 26, prof_box[3] - 152, prof_box[2] - 26, prof_box[3] - 90]
    btn2 = [prof_box[0] + 26, prof_box[3] - 76, prof_box[2] - 26, prof_box[3] - 22]
    draw_rounded_glass(d, btn1, radius=22, fill=(38, 118, 242, 245), outline=(140, 196, 255, 220), width=2)
    draw_rounded_glass(d, btn2, radius=20, fill=(26, 38, 76, 235), outline=(110, 146, 210, 180), width=2)
    f_btn = load_font(FONT_BLACK, 25)
    f_btn2 = load_font(FONT_BOLD, 23)
    b1t = "+ Arkadaş Ekle"
    b1b = d.textbbox((0, 0), b1t, font=f_btn)
    d.text(((btn1[0] + btn1[2] - (b1b[2] - b1b[0])) // 2, btn1[1] + 14), b1t, font=f_btn, fill=(255, 255, 255, 255))
    b2t = "Özel Mesaj  ·  YKS Adayı & Öğrenci"
    b2b = d.textbbox((0, 0), b2t, font=f_btn2)
    d.text(((btn2[0] + btn2[2] - (b2b[2] - b2b[0])) // 2, btn2[1] + 12), b2t, font=f_btn2, fill=(214, 228, 255, 245))

    return img


def render_mystery_title(title: str, y_center: int = 320) -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f_title = load_font(FONT_BLACK, 68)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    tb = gd.textbbox((0, 0), title, font=f_title)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    x = (W - tw) // 2 - tb[0]
    y = y_center - th // 2 - tb[1]
    gd.text((x, y), title, font=f_title, fill=(255, 208, 90, 185))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=18))
    img.alpha_composite(glow)
    draw_centered_text(img, title, f_title, y_center, fill=(255, 244, 204, 255), shadow_offset=(0, 4), shadow_alpha=185)
    return img


def render_endcard_top() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    badge_txt = "EFSANEVİ PET: KUTBİ"
    f_b = load_font(FONT_BLACK, 33)
    bb = d.textbbox((0, 0), badge_txt, font=f_b)
    bw, bh = bb[2] - bb[0], bb[3] - bb[1]
    by = 185
    b_box = [W // 2 - bw // 2 - 64, by - bh // 2 - 14, W // 2 + bw // 2 + 64, by + bh // 2 + 14]
    draw_rounded_glass(d, b_box, radius=28, fill=(255, 208, 76, 245), outline=(255, 248, 214, 235), width=3)
    draw_star(d, b_box[0] + 32, by, 13, 5.5, (14, 20, 50, 255))
    draw_star(d, b_box[2] - 32, by, 13, 5.5, (14, 20, 50, 255))
    draw_centered_text(img, badge_txt, f_b, by, fill=(14, 20, 50, 255), shadow_alpha=0)

    f_logo = load_font(FONT_BLACK, 164)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    lb = gd.textbbox((0, 0), "UniPet", font=f_logo)
    lw, lh = lb[2] - lb[0], lb[3] - lb[1]
    gd.text(((W - lw) // 2 - lb[0], 330 - lh // 2 - lb[1]), "UniPet", font=f_logo, fill=(255, 202, 70, 195))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=22))
    img.alpha_composite(glow)
    draw_centered_text(
        img,
        "UniPet",
        f_logo,
        330,
        fill=(255, 236, 152, 255),
        shadow_offset=(0, 8),
        shadow_alpha=215,
        stroke_width=8,
        stroke_fill=(12, 18, 52, 255),
    )

    f_sub = load_font(FONT_BOLD, 46)
    draw_centered_text(
        img,
        "YTÜ Davutpaşa Cebinde!",
        f_sub,
        452,
        fill=(236, 244, 255, 255),
        shadow_offset=(0, 4),
        shadow_alpha=185,
    )
    return img


def render_endcard_cta() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Üst özellik çipleri satırı
    chips_txt = "Ring & 41AT   •   Tarihi Hamam   •   Kediler   •   Kafeler   •   Yarış"
    f_ch = load_font(FONT_BOLD, 27)
    chb = d.textbbox((0, 0), chips_txt, font=f_ch)
    chw, chh = chb[2] - chb[0], chb[3] - chb[1]
    chy = 1500
    ch_box = [W // 2 - chw // 2 - 34, chy - chh // 2 - 14, W // 2 + chw // 2 + 34, chy + chh // 2 + 14]
    draw_rounded_glass(d, ch_box, radius=26, fill=(10, 18, 44, 195), outline=(132, 184, 255, 130), width=2)
    draw_centered_text(img, chips_txt, f_ch, chy, fill=(218, 234, 255, 250), shadow_alpha=0)

    txt = "ÇOK YAKINDA  •  ÜCRETSİZ"
    f_cta = load_font(FONT_BLACK, 44)
    cb = d.textbbox((0, 0), txt, font=f_cta)
    cw, ch = cb[2] - cb[0], cb[3] - cb[1]
    cy = 1622
    box = [W // 2 - cw // 2 - 56, cy - ch // 2 - 28, W // 2 + cw // 2 + 56, cy + ch // 2 + 28]

    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([box[0], box[1] + 8, box[2], box[3] + 8], radius=46, fill=(255, 205, 70, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=18))
    img.alpha_composite(sh)

    draw_rounded_glass(d, box, radius=46, fill=(14, 22, 56, 232), outline=(255, 214, 92, 255), width=5)
    draw_centered_text(img, txt, f_cta, cy, fill=(255, 234, 144, 255), shadow_alpha=0)

    f_small = load_font(FONT_BOLD, 30)
    draw_centered_text(
        img,
        "Android  ·  Kapalı Testte Kutbi Hediye!",
        f_small,
        1722,
        fill=(216, 228, 252, 235),
        shadow_offset=(0, 3),
        shadow_alpha=150,
    )
    draw_centered_text(img, "Bağımsız öğrenci projesidir · YTÜ'nün resmî uygulaması değildir",
                       load_font(FONT_REG, 24), 1840, fill=(196, 206, 230, 205), shadow_offset=(0, 2), shadow_alpha=120)
    return img


def render_top_watermark() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = load_font(FONT_BLACK, 33)
    txt = "UniPet"
    b = d.textbbox((0, 0), txt, font=f)
    tw, th = b[2] - b[0], b[3] - b[1]
    rx = W - 42
    box = [rx - tw - 48, 56, rx, 56 + th + 26]
    draw_rounded_glass(d, box, radius=24, fill=(11, 18, 44, 138), outline=(255, 214, 92, 155), width=2)
    d.text((box[0] + 24 - b[0], box[1] + 13 - b[1]), txt, font=f, fill=(255, 236, 168, 238))
    return img


def main() -> None:
    godot_avi = sys.argv[1]
    out_mp4 = sys.argv[2]
    out_gif = sys.argv[3] if len(sys.argv) > 3 else None
    tmp_dir = tempfile.mkdtemp(prefix="unipet_ad_agy_")

    # 1. RGBA motion-graphics katmanları
    overlays = [
        ("ov_wm.png", render_top_watermark(), 0.15, 26.2, 0.25, 0.25, False),
        # 0. gate (0.0 - 3.0)
        (
            "ov_gate.png",
            render_badge_and_title("A KAPISI  ·  11 GERÇEK DURAK", "Ring'e ve 41AT'ye atla!", "Mavi YTÜ Ring ve efsane İETT 41AT kampüste", accent=(72, 186, 255, 255)),
            0.12, 2.88, 0.18, 0.18, True,
        ),
        (
            "ov_gate_hud.png",
            render_bottom_hud_pill("41AT & RİNG", "A Kapısı  →  Kütüphane  →  Yabancı Diller", tag_bg=(238, 168, 18, 255)),
            0.30, 2.85, 0.22, 0.18, True,
        ),
        # 1. yildiz_store (3.0 - 6.0)
        (
            "ov_store.png",
            render_badge_and_title("YILDIZ STORE & MEYDAN", "Birebir gerçek Davutpaşa!", "Ahşap amfi, Yemekhane, Büyük Ev ve A101", accent=(255, 212, 84, 255)),
            3.12, 5.88, 0.18, 0.18, True,
        ),
        # 2. love_cats (6.0 - 9.0)
        (
            "ov_cats.png",
            render_badge_and_title("ORTABAHÇE  ·  KAMPÜS İKONU", "Kampüs kedilerini sev!", "14 Davutpaşa kedisi  ·  Her gün 40 Yıldız Tozu", accent=(255, 118, 152, 255)),
            6.12, 8.88, 0.18, 0.18, True,
        ),
        (
            "ov_dust_hud.png",
            render_bottom_hud_pill("YILDIZ TOZU +2", "Yürüyerek 47 noktayı keşfet, ödülleri topla!", tag_bg=(218, 152, 22, 255)),
            7.25, 8.88, 0.20, 0.16, True,
        ),
        # 3. merkez_lib (9.0 - 11.5)
        (
            "ov_lib1.png",
            render_badge_and_title("YENİ MERKEZ KÜTÜPHANESİ", "Vize haftası bunalttı mı?", "-1. kat çökük avlu ve ahşap amfi", accent=(120, 214, 255, 255)),
            9.10, 10.05, 0.14, 0.10, True,
        ),
        (
            "ov_lib2.png",
            render_badge_and_title("MOLA ZAMANI!", "Kitapları fırlat, dans et!", "Arkadaşlarınla amfide stres at", accent=(255, 212, 84, 255)),
            10.08, 11.38, 0.14, 0.16, True,
        ),
        # 4. hamam (11.5 - 15.5)
        (
            "ov_hamam.png",
            render_badge_and_title("TARİHİ HAMAM  ·  ARTLAB", "Sami ile tanış, kahveni kap!", "ESLAB kahve minibüsü & SKY LAB ARTLAB Zirvesi", accent=(168, 132, 255, 255)),
            11.62, 15.36, 0.20, 0.20, True,
        ),
        (
            "ov_hamam_hud.png",
            render_bottom_hud_pill("SAMİ NPC", "Tarihi Hamam çökük avlusunda seni bekliyor!", tag_bg=(124, 88, 232, 255)),
            12.10, 15.32, 0.22, 0.18, True,
        ),
        # 5. social (15.5 - 19.0)
        (
            "ov_social.png",
            render_badge_and_title("KAFE ODALARI & KİMLİK", "YTÜ'lülerle tanış, sohbet et!", "Hokka, Büyük Ev, Eskafe otomatik sohbet salonları", accent=(86, 232, 184, 255)),
            15.62, 18.88, 0.18, 0.18, True,
        ),
        (
            "ov_social_cards.png",
            render_social_showcase_cards(),
            15.85, 18.88, 0.26, 0.20, True,
        ),
        # 6. stadium (19.0 - 22.0)
        (
            "ov_stadium.png",
            render_badge_and_title("YTÜ STADYUMU  ·  CANLI", "Koşu yarışı ve Frizbi!", "6 kulvarlı pistte kapış, yıldız tozu kazan", accent=(255, 146, 72, 255)),
            19.12, 21.88, 0.18, 0.18, True,
        ),
        (
            "ov_race_hud.png",
            render_bottom_hud_pill("CANLI YARIŞ", "Kapı 2/6  ·  6 Koşucu  ·  Birinciye +3 Yıldız Tozu", tag_bg=(232, 96, 38, 255)),
            19.35, 21.85, 0.20, 0.16, True,
        ),
        # 7. dressup (22.0 - 24.5)
        (
            "ov_dress.png",
            render_badge_and_title("6 PET  ·  11 AKSESUAR", "Tarzını kendin yarat!", "Çiçek tacı, yıldız taç, pelerin, kanatlar ve fazlası", accent=(255, 212, 84, 255)),
            22.10, 24.38, 0.16, 0.16, True,
        ),
        # 8. star (24.5 - 26.5)
        (
            "ov_star.png",
            render_mystery_title("Ve kampüsün efsanesi..."),
            24.62, 26.15, 0.30, 0.22, False,
        ),
        # 9. kutbi (26.5 - 30.5)
        ("ov_end_top.png", render_endcard_top(), 26.72, 30.5, 0.32, 0.01, True),
        ("ov_end_cta.png", render_endcard_cta(), 27.30, 30.5, 0.32, 0.01, True),
    ]

    ov_paths = []
    for fname, im, *_rest in overlays:
        p = os.path.join(tmp_dir, fname)
        im.save(p, "PNG")
        ov_paths.append(p)

    # 2. 48 kHz STEREO müzik üret
    music_wav = os.path.join(tmp_dir, "music_agy.wav")
    make_music_agy.make(
        music_wav,
        cut_times=CUT_TIMES,
        high_energy_start=19.0,
        star_start=24.5,
        impact_at=25.85,
        outro_start=26.5,
        total=TOTAL_DUR,
    )

    # 3. FFmpeg girdileri ve oyun içi SFX olayları
    inputs = ["-ss", "%.3f" % GODOT_SKIP, "-t", "%.3f" % TOTAL_DUR, "-i", godot_avi]
    for p in ov_paths:
        inputs += ["-loop", "1", "-t", "%.3f" % TOTAL_DUR, "-i", p]

    music_idx = 1 + len(ov_paths)
    inputs += ["-i", music_wav]

    sfx_events = [
        # Shot 0: A Kapısı Ring & 41AT
        ("chat_receive.ogg", 0.30, 0.58),
        ("emote.ogg", 1.22, 0.62),
        # Shot 1: Yıldız Store
        ("chat_send.ogg", 3.22, 0.55),
        ("emote.ogg", 3.55, 0.48),
        ("chat_receive.ogg", 4.28, 0.52),
        # Shot 2: I ❤ YTU & Kediler + Yıldız Tozu
        ("meow.wav", 6.32, 0.80),
        ("care_ok.ogg", 7.36, 0.72),   # yıldız tozu 1
        ("meow.wav", 7.72, 0.78),
        ("care_ok.ogg", 8.16, 0.72),   # yıldız tozu 2
        # Shot 3: Yeni Merkez Kütüphanesi
        ("care_fail.ogg", 9.12, 0.52),
        ("teleport.ogg", 10.05, 0.72), # kitaplar patlar!
        ("emote.ogg", 10.18, 0.68),
        # Shot 4: Tarihi Hamam & Sami
        ("chat_send.ogg", 11.88, 0.65),
        ("emote.ogg", 12.05, 0.58),
        ("chat_receive.ogg", 13.35, 0.58),
        ("emote.ogg", 13.78, 0.60),
        # Shot 5: Hokka Kafe & Kampüs Kimliği
        ("chat_receive.ogg", 15.68, 0.58),
        ("ui_click.ogg", 15.92, 0.58), # kartlar açılır
        ("chat_send.ogg", 16.40, 0.58),
        ("chat_receive.ogg", 17.20, 0.55),
        ("care_ok.ogg", 17.95, 0.58),
        # Shot 6: Stadyum Yarış & Frizbi
        ("teleport.ogg", 19.05, 0.58),
        ("step.ogg", 19.45, 0.50),
        ("step.ogg", 19.85, 0.50),
        ("care_ok.ogg", 20.75, 0.82),  # Frizbi yakalandı!
        ("emote.ogg", 20.85, 0.65),
        # Shot 7: 6 Pet & 11 Aksesuar beat-sync
        ("ui_click.ogg", 22.02, 0.58),
        ("emote.ogg", 22.43, 0.52),
        ("ui_click.ogg", 22.85, 0.58),
        ("emote.ogg", 23.26, 0.52),
        ("ui_click.ogg", 23.68, 0.58),
        ("care_ok.ogg", 24.08, 0.70),
        # Shot 8 & 9: Kayan Yıldız & Kutbi
        ("teleport.ogg", 24.62, 0.55),
        ("care_ok.ogg", 25.86, 0.88),
        ("care_ok.ogg", 26.55, 0.88),
        ("emote.ogg", 27.18, 0.72),
        ("emote.ogg", 28.62, 0.72),
    ]
    sfx_base_idx = music_idx + 1
    for fname, _at, _vol in sfx_events:
        inputs += ["-i", os.path.join(SFX_DIR, fname)]

    filters = []
    # Temel görüntü işleme: keskin Lanczos ölçekleme + canlı kontrast/doygunluk + sinematik vinyet
    filters.append(
        "[0:v]setpts=PTS-STARTPTS,fps=%d,scale=%d:%d:flags=lanczos:force_original_aspect_ratio=increase,"
        "crop=%d:%d,setsar=1,"
        "eq=contrast=1.07:saturation=1.16:brightness=0.01,"
        "unsharp=5:5:0.42:5:5:0.0,"
        "vignette=PI/7.0,"
        "format=rgba[base0]" % (FPS, W, H, W, H)
    )

    # Yıldız çarpma & Kutbi geçişinde (26.28 - 26.74 sn) hızlı sinematik altın-beyaz ışık flaşı (geq yerine fade: ~10x hızlı!)
    filters.append(
        "color=c=0xFFF5D2:s=%dx%d:r=%d:d=%.3f,format=rgba,"
        "fade=t=in:st=26.28:d=0.22:alpha=1,fade=t=out:st=26.50:d=0.24:alpha=1[flash]"
        % (W, H, FPS, TOTAL_DUR)
    )
    filters.append("[base0][flash]overlay=0:0:enable='between(t,26.28,26.74)':shortest=1[v_flashed]")

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
            y_expr = "if(lt(t-%.3f,%.3f), 28*pow(1-(t-%.3f)/%.3f,2), 0)" % (t0, fin, t0, fin)
        else:
            y_expr = "0"
        filters.append(
            "[%s][%s]overlay=x=0:y='%s':enable='between(t,%.3f,%.3f)':shortest=1[%s]"
            % (cur, ov_tag, y_expr, t0, t1, nxt)
        )
        cur = nxt

    filters.append("[%s]format=yuv420p[vout]" % cur)

    # Ses miksajı: stereo müzik + oyun SFX olayları + yumuşak limiter
    filters.append("[%d:a]aresample=48000,aformat=channel_layouts=stereo,volume=0.80[mus]" % music_idx)
    mix = ["[mus]"]
    for j, (_fname, at, vol) in enumerate(sfx_events):
        ms = int(at * 1000)
        filters.append(
            "[%d:a]aresample=48000,aformat=channel_layouts=stereo,volume=%.2f,adelay=%d|%d[fx%d]"
            % (sfx_base_idx + j, vol, ms, ms, j)
        )
        mix.append("[fx%d]" % j)
    filters.append("%samix=inputs=%d:normalize=0:duration=first,alimiter=limit=0.95[aout]" % ("".join(mix), len(mix)))

    os.makedirs(os.path.dirname(os.path.abspath(out_mp4)), exist_ok=True)
    cmd = (
        ["ffmpeg", "-v", "warning", "-y"]
        + inputs
        + [
            "-filter_complex", ";".join(filters),
            "-map", "[vout]", "-map", "[aout]",
            "-c:v", "libx264", "-preset", "medium", "-crf", "20",
            "-maxrate", "4500k", "-bufsize", "9000k",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "192k",
            "-movflags", "+faststart",
            "-r", str(FPS),
            out_mp4,
        ]
    )
    subprocess.run(cmd, check=True)
    print("TAMAM (MP4): %s (%.1f sn)" % (out_mp4, TOTAL_DUR))

    if out_gif:
        os.makedirs(os.path.dirname(os.path.abspath(out_gif)), exist_ok=True)
        gif_cmd = [
            "ffmpeg", "-v", "warning", "-y",
            "-i", out_mp4,
            "-vf", "fps=12,scale=360:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3",
            out_gif,
        ]
        subprocess.run(gif_cmd, check=True)
        print("TAMAM (GIF): %s" % out_gif)


if __name__ == "__main__":
    main()
