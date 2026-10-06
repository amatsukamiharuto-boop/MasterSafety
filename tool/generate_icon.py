"""Generator ikon MasterSafety (perisai + mata).

Edit nilai di bagian KONFIGURASI, lalu jalankan dari root proyek:
    pip install pillow
    python3 tool/generate_icon.py

Output:
    assets/icon/icon.png             ikon penuh (latar gradien)
    assets/icon/icon_foreground.png  layer depan adaptive icon (transparan)

Di GitHub Actions, skrip ini dijalankan otomatis sebelum build, jadi cukup
edit file ini di GitHub lalu commit.
"""
import os

from PIL import Image, ImageDraw, ImageFilter

# ========================= KONFIGURASI (silakan ubah) =========================
BG_TOP = (14, 28, 52)         # warna latar atas
BG_BOTTOM = (6, 12, 24)       # warna latar bawah
ACCENT = (34, 211, 238)       # warna garis perisai & mata (cyan)
ACCENT_DARK = (14, 116, 144)  # warna iris
SHIELD_FILL = (10, 24, 46)    # isi perisai
EYE_FILL = (6, 16, 32)        # isi mata
HIGHLIGHT = (240, 250, 255)   # kilau pada iris

SHIELD_SCALE = 0.64   # tinggi perisai pada ikon penuh (0..1 dari kanvas)
FG_SCALE = 0.50       # tinggi perisai pada layer foreground (aman dari crop)
SHOW_SCAN_LINE = True # garis pemindai horizontal di mata
OUT_DIR = "assets/icon"
SIZE = 1024
# ==============================================================================

SS = 2  # supersampling agar tepi halus


def bez2(p0, p1, p2, n):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        pts.append((x, y))
    return pts


def bez3(p0, p1, p2, p3, n):
    pts = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def shield_points(cx, cy, w, h):
    """Bentuk perisai; sama persis dengan MasterSafetyLogo di Flutter."""
    top, bot, r = cy - h / 2, cy + h / 2, cx + w / 2
    right = []
    right += bez2((cx, top), (cx + 0.32 * w, top + 0.03 * h), (r, top + 0.15 * h), 30)
    right += [(r, cy + 0.06 * h)]
    right += bez3((r, cy + 0.06 * h), (r, cy + 0.30 * h),
                  (cx + 0.25 * w, bot - 0.10 * h), (cx, bot), 40)
    left = [(2 * cx - x, y) for x, y in reversed(right)]
    pts = right + left[1:-1]
    # buang titik ganda berurutan agar tidak ada goresan kecil di sambungan
    clean = [pts[0]]
    for p in pts[1:]:
        if abs(p[0] - clean[-1][0]) > 1e-6 or abs(p[1] - clean[-1][1]) > 1e-6:
            clean.append(p)
    return clean


def eye_points(cx, cy, ew, eh, n=80):
    """Mata bentuk lensa (parabola), puncak = eh."""
    top, bottom = [], []
    for i in range(n + 1):
        t = -1 + 2 * i / n
        x = cx + t * ew
        y = eh * (1 - t * t)
        top.append((x, cy - y))
        bottom.append((x, cy + y))
    return top + list(reversed(bottom))


def circle(d, c, r, **kw):
    d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], **kw)


def render(scale, with_bg):
    S = SIZE * SS
    if with_bg:
        img = Image.new("RGBA", (S, S))
        gd = ImageDraw.Draw(img)
        for y in range(S):
            t = y / (S - 1)
            col = tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3))
            gd.line([(0, y), (S, y)], fill=col + (255,))
    else:
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    cx = S / 2
    sh_h = S * scale
    sh_w = sh_h * 0.86
    sh_cy = S / 2 + sh_h * 0.02
    lw = max(2, int(sh_h * 0.035))
    pts = shield_points(cx, sh_cy, sh_w, sh_h)

    # cahaya (glow) di sekitar garis perisai
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).line(pts + [pts[0]], fill=ACCENT + (255,), width=lw * 2, joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(sh_h * 0.035))
    img = Image.alpha_composite(img, glow)

    # isi + garis perisai
    fill = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(fill).polygon(pts, fill=SHIELD_FILL + (240,))
    img = Image.alpha_composite(img, fill)
    d = ImageDraw.Draw(img)
    d.line(pts + [pts[0]], fill=ACCENT + (255,), width=lw, joint="curve")

    # mata
    ew, eh = sh_w * 0.36, sh_h * 0.17
    ecy = sh_cy - sh_h * 0.04
    eye = eye_points(cx, ecy, ew, eh)
    d.polygon(eye, fill=EYE_FILL + (255,))

    # iris, pupil, kilau
    ir = eh * 0.90
    circle(d, (cx, ecy), ir, fill=ACCENT_DARK + (255,), outline=ACCENT + (255,), width=max(2, lw // 2))
    circle(d, (cx, ecy), ir * 0.42, fill=(4, 10, 20, 255))
    circle(d, (cx - ir * 0.30, ecy - ir * 0.30), ir * 0.14, fill=HIGHLIGHT + (255,))

    # garis pemindai
    if SHOW_SCAN_LINE:
        x0, x1 = cx - sh_w * 0.46, cx + sh_w * 0.46
        sl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(sl).line([(x0, ecy), (x1, ecy)], fill=ACCENT + (255,), width=lw)
        blur = sl.filter(ImageFilter.GaussianBlur(sh_h * 0.012))
        img = Image.alpha_composite(img, blur)
        ImageDraw.Draw(img).line([(x0, ecy), (x1, ecy)], fill=HIGHLIGHT + (230,), width=max(2, lw // 3))

    # garis tepi mata di atas iris/scan agar rapi
    ImageDraw.Draw(img).line(eye + [eye[0]], fill=ACCENT + (255,), width=max(2, int(lw * 0.7)), joint="curve")

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    render(SHIELD_SCALE, True).convert("RGB").save(os.path.join(OUT_DIR, "icon.png"))
    render(FG_SCALE, False).save(os.path.join(OUT_DIR, "icon_foreground.png"))
    print("Ikon dibuat di", OUT_DIR)


if __name__ == "__main__":
    main()
