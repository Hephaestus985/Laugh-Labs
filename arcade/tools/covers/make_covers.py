#!/usr/bin/env python3
"""Make the cover art (Steam-style header, 920x430) and info-page screenshots.

Usage: python3 -I make_covers.py <screenshots_dir> <provided_art_dir>

<screenshots_dir> holds <id>_title.jpg / <id>_play.jpg taken from the running
games (1280x720, see capture.gd). Games by others use the art they ship with
where it is good (Open RPG's banner, Outpost Assault's cover and logo); the rest
get a cover made here: a gameplay shot, a colour wash in the game's colour and
its title. Writes, per game:
  <game folder>/cover.jpg          920x430, shown on the cards and the info page
  <game folder>/shots/1.jpg, 2.jpg 640x360 screenshots for the info page
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ARCADE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
W, H = 920, 430
FONT_TITLE = "/usr/share/fonts/truetype/noto/NotoSans-Black.ttf"
FONT_SMALL = "/usr/share/fonts/truetype/noto/NotoSans-SemiBold.ttf"

# where the interesting part of each game's screenshot is (x0, y0, x1, y1 in 1280x720)
CROPS = {
    "default": (0, 60, 1280, 720),
    "puzzle": (0, 60, 990, 720),
}
PUZZLE = {"game_2048", "sudoku", "minesweeper", "solitaire", "nonogram", "lights_out", "sliding_puzzle", "mahjong", "sokoban", "flow", "block_stacker", "connect_four"}
# crops that leave out on-screen text (level banners, number pads, HUDs)
CROPS.update({
    "sudoku": (40, 60, 676, 720),
    "the_last_knight": (0, 330, 1280, 720),
    "escape_velocity": (0, 300, 1280, 720),
    "lighthouse_keeper": (0, 320, 1280, 720),
    "escape_the_cavity": (0, 60, 1280, 520),
})
USE_TITLE = set()


# ---- hand-drawn backgrounds for games whose screenshots are mostly empty space

def _canvas(top, bottom):
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)))
    return im, d


def art_block_stacker():
    im, d = _canvas((20, 18, 45), (35, 30, 80))
    cols = [(50, 210, 225), (240, 215, 50), (175, 75, 225), (75, 215, 75), (225, 60, 60), (60, 100, 240), (240, 140, 40)]
    c = 40
    x0 = 520
    import random
    rnd = random.Random(4)
    heights = [5, 6, 4, 7, 6, 5, 8, 6, 5]
    for i, hgt in enumerate(heights):
        for j in range(hgt):
            if i == 4 and j == hgt - 1:
                continue
            col = cols[rnd.randrange(len(cols))]
            r = (x0 + i * c, H - 20 - (j + 1) * c, x0 + (i + 1) * c - 3, H - 20 - j * c - 3)
            d.rectangle(r, fill=col)
            d.rectangle((r[0], r[1], r[2], r[1] + 6), fill=tuple(min(255, v + 60) for v in col))
    # a falling T piece
    for (dx, dy) in [(1, 0), (0, 1), (1, 1), (2, 1)]:
        r = (x0 + (3 + dx) * c, 40 + dy * c, x0 + (4 + dx) * c - 3, 40 + (dy + 1) * c - 3)
        d.rectangle(r, fill=(175, 75, 225))
    return im


def art_nonogram():
    im, d = _canvas((40, 30, 50), (70, 40, 70))
    pic = ["..XX..XX..", ".XXXXXXXX.", "XXXXXXXXXX", "XXXXXXXXXX", ".XXXXXXXX.", "..XXXXXX..", "...XXXX...", "....XX...."]
    c = 40
    ox, oy = 470, 60
    f = ImageFont.truetype(FONT_SMALL, 18)
    for y, row in enumerate(pic):
        for x, ch in enumerate(row):
            r = (ox + x * c, oy + y * c, ox + (x + 1) * c - 2, oy + (y + 1) * c - 2)
            d.rectangle(r, fill=(235, 235, 245))
            if ch == "X" and not (y > 5 and x > 5):
                d.rectangle((r[0] + 3, r[1] + 3, r[2] - 3, r[3] - 3), fill=(200, 50, 90))
            elif ch == "." and (x + y) % 3 == 0:
                d.line((r[0] + 12, r[1] + 12, r[2] - 12, r[3] - 12), fill=(170, 120, 140), width=3)
    return im


def art_orbit_courier():
    im, d = _canvas((8, 10, 30), (20, 15, 50))
    import random
    rnd = random.Random(2)
    for i in range(140):
        x, y = rnd.randrange(W), rnd.randrange(H)
        v = rnd.randrange(120, 255)
        d.point((x, y), fill=(v, v, v))
    planets = [((560, 300), 70, (230, 120, 70)), ((800, 120), 46, (90, 170, 240)), ((690, 70), 20, (200, 200, 120))]
    for (x, y), r, col in planets:
        d.ellipse((x - r * 1.9, y - r * 1.9, x + r * 1.9, y + r * 1.9), outline=(80, 90, 140), width=2)
        d.ellipse((x - r, y - r, x + r, y + r), fill=col)
        d.ellipse((x - r * 0.7, y - r * 0.8, x + r * 0.2, y - r * 0.1), fill=tuple(min(255, v + 40) for v in col))
    # the courier's path and ship with an invitation
    pts = [(560 + 133 * __import__("math").cos(a / 10), 300 + 133 * __import__("math").sin(a / 10)) for a in range(-25, -5)]
    pts += [(pts[-1][0] + k * 14, pts[-1][1] - k * 9) for k in range(1, 14)]
    d.line(pts, fill=(255, 220, 120), width=3)
    sx, sy = pts[-1]
    d.polygon([(sx, sy - 12), (sx + 22, sy), (sx, sy + 12)], fill=(240, 240, 255))
    d.rectangle((sx - 30, sy - 8, sx - 12, sy + 6), fill=(255, 235, 200))
    d.line((sx - 30, sy - 8, sx - 21, sy), fill=(200, 120, 90), width=2)
    d.line((sx - 12, sy - 8, sx - 21, sy), fill=(200, 120, 90), width=2)
    return im


def art_bend_einstein():
    import math
    im, d = _canvas((6, 6, 20), (15, 10, 35))
    cx, cy = 640, 215
    for k in range(9):
        y0 = 40 + k * 44
        pts = []
        for x in range(380, W, 6):
            dx, dy = x - cx, y0 - cy
            dist = max(40.0, math.hypot(dx, dy))
            bend = 5200.0 / dist
            pts.append((x, y0 + (cy - y0) * min(0.9, bend / 160.0)))
        d.line(pts, fill=(255, 220 - k * 10, 120 + k * 12), width=3)
    d.ellipse((cx - 60, cy - 60, cx + 60, cy + 60), fill=(0, 0, 0), outline=(255, 170, 90), width=4)
    d.ellipse((cx - 85, cy - 22, cx + 85, cy + 22), outline=(255, 120, 60), width=3)
    d.rectangle((W - 60, cy - 30, W, cy + 30), fill=(90, 200, 230))
    return im


def art_waveguide_snake():
    import math
    im, d = _canvas((10, 18, 35), (8, 30, 50))
    d.rectangle((380, 150, W, 290), fill=(18, 40, 70))
    d.line((380, 150, W, 150), fill=(70, 160, 220), width=4)
    d.line((380, 290, W, 290), fill=(70, 160, 220), width=4)
    for k in range(14):
        x = 470 + k * 30
        y = 220 + 34 * math.sin(k * 0.6)
        r = 13 if k < 13 else 17
        d.ellipse((x - r, y - r, x + r, y + r), fill=(120, 220, 255) if k < 13 else (255, 255, 255))
    for (x, y) in [(870, 190), (820, 260)]:
        d.ellipse((x - 9, y - 9, x + 9, y + 9), fill=(255, 210, 90))
    d.ellipse((410, 240, 440, 270), fill=(220, 60, 90))
    return im


ART = {
    "block_stacker": art_block_stacker,
    "nonogram": art_nonogram,
    "orbit_courier": art_orbit_courier,
    "bend_it_like_einstein": art_bend_einstein,
    "waveguide_snake": art_waveguide_snake,
}


def cover_crop(im, box, focus_x=0.62):
    """Crop to the cover's shape inside box, keeping the right-hand side (the title
    sits on the left)."""
    im = im.crop(box)
    tw = im.height * W / H
    if tw <= im.width:
        x0 = int((im.width - tw) * focus_x)
        im = im.crop((x0, 0, x0 + int(tw), im.height))
    else:
        th = im.width * H / W
        y0 = int((im.height - th) / 2)
        im = im.crop((0, y0, im.width, y0 + int(th)))
    return im.resize((W, H), Image.LANCZOS)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def fit_font(draw, text, max_w, size, path=FONT_TITLE, min_size=36):
    while size > min_size:
        f = ImageFont.truetype(path, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 2
    return ImageFont.truetype(path, min_size)


def wrap_title(draw, title, max_w):
    """One line if it fits big enough, else two balanced lines."""
    f = ImageFont.truetype(FONT_TITLE, 84)
    if draw.textlength(title, font=f) <= max_w or " " not in title:
        return [title], fit_font(draw, title, max_w, 84)
    words = title.split()
    best = None
    for i in range(1, len(words)):
        a, b = " ".join(words[:i]), " ".join(words[i:])
        w = max(draw.textlength(a, font=f), draw.textlength(b, font=f))
        if best is None or w < best[0]:
            best = (w, [a, b])
    lines = best[1]
    longest = max(lines, key=lambda s: draw.textlength(s, font=f))
    return lines, fit_font(draw, longest, max_w, 76)


def make_cover(bg, g, badge="LAB ARCADE", wash=0.9, logo=None):
    col = hex_rgb(g["color"])
    dark = tuple(int(c * 0.25) for c in col)
    im = bg.convert("RGB").copy()
    # colour wash: solid on the left, clear on the right
    grad = Image.new("L", (W, 1))
    for x in range(W):
        t = x / W
        a = 1.0 if t < 0.28 else max(0.0, 1.0 - (t - 0.28) / 0.42)
        grad.putpixel((x, 0), int(255 * wash * a))
    grad = grad.resize((W, H))
    im = Image.composite(Image.new("RGB", (W, H), dark), im, grad)
    # a soft vignette at the bottom
    vig = Image.new("L", (1, H))
    for y in range(H):
        vig.putpixel((0, y), int(140 * max(0.0, (y / H - 0.6) / 0.4)))
    im = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), im, vig.resize((W, H)))
    d = ImageDraw.Draw(im)
    if logo is not None:
        lg = logo.copy()
        lg.thumbnail((470, 180))
        im.paste(lg, (36, (H - lg.height) // 2 - 10), lg)
    else:
        lines, f = wrap_title(d, g["name"].upper(), 470)
        lh = f.size * 1.02
        top = (H - lh * len(lines)) / 2 - 6
        genre = ImageFont.truetype(FONT_SMALL, 22)
        light = tuple(min(255, int(c * 0.6 + 255 * 0.4)) for c in col)
        d.text((40, top - 34), g.get("genre", "").upper(), font=genre, fill=light)
        for i, line in enumerate(lines):
            y = top + i * lh
            d.text((43, y + 4), line, font=f, fill=(0, 0, 0))
            d.text((40, y), line, font=f, fill=(255, 255, 255))
    small = ImageFont.truetype(FONT_SMALL, 18)
    tw = d.textlength(badge, font=small)
    d.rounded_rectangle((36, H - 46, 36 + tw + 24, H - 16), radius=6, fill=(0, 0, 0))
    d.text((48, H - 44), badge, font=small, fill=(255, 255, 255))
    return im


def shot(im):
    im = im.convert("RGB")
    im.thumbnail((640, 360), Image.LANCZOS)
    return im


def main():
    caps, provided = sys.argv[1], sys.argv[2]
    cat = json.load(open(os.path.join(ARCADE, "catalog.json")))
    for kind in ("lab", "external"):
        for g in cat[kind]:
            gid = g["id"]
            folder = os.path.join(ARCADE, "games" if kind == "lab" else "external", gid)
            play = Image.open(os.path.join(caps, gid + "_play.jpg"))
            title = Image.open(os.path.join(caps, gid + "_title.jpg"))
            shots = [play] if gid in PUZZLE else [play, title]
            badge = "LAB ARCADE" if kind == "lab" else "BY " + g["publisher"].upper()
            box = CROPS.get(gid, CROPS["puzzle" if gid in PUZZLE else "default"])
            src = title if gid in USE_TITLE else play
            if gid == "open_rpg":
                art = Image.open(os.path.join(provided, "open_rpg.png")).convert("RGB")
                cover = cover_crop(art, (0, 0, art.width, art.height), 0.5)
            elif gid == "outpost_assault":
                bg = cover_crop(Image.open(os.path.join(provided, "outpost_bg.jpg")), (0, 0, 1920, 1080), 0.85)
                logo = Image.open(os.path.join(provided, "outpost_title.png")).convert("RGBA")
                cover = make_cover(bg, g, badge, wash=0.55, logo=logo)
            elif gid == "tactical_rpg":
                big = Image.open(os.path.join(provided, "tactical_1.png")).convert("RGB")
                bg = cover_crop(big, (300, 200, 2880, 1800), 0.7)
                cover = make_cover(bg, g, badge)
                shots = [big, play]
            elif gid in ("platformer_3d", "racing"):
                ps = Image.open(os.path.join(provided, gid.split("_")[0] + "_shot.png")).convert("RGB")
                bg = cover_crop(ps, (0, 0, ps.width, int(ps.height * 0.9)), 0.75)
                cover = make_cover(bg, g, badge)
                shots = [ps, play]
            elif gid in ART:
                cover = make_cover(ART[gid](), g, badge, wash=0.75)
            else:
                cover = make_cover(cover_crop(src, box), g, badge)
            cover.save(os.path.join(folder, "cover.jpg"), quality=86)
            os.makedirs(os.path.join(folder, "shots"), exist_ok=True)
            for i, s in enumerate(shots):
                shot(s).save(os.path.join(folder, "shots", "%d.jpg" % (i + 1)), quality=82)
            print("cover", gid)


if __name__ == "__main__":
    main()
