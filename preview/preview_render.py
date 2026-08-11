#!/usr/bin/env python3
"""Vista previa fiel de la esfera usando las fuentes y coordenadas reales.
Genera un PNG con el modo INTERACTIVO y los ALWAYS-ON en verde y rojo."""
import os
from PIL import Image, ImageDraw, ImageFont

_HERE = os.path.dirname(os.path.abspath(__file__))
_BASE = os.path.dirname(_HERE)
SRC = os.path.join(_BASE, "fonts-src")
OUT = os.path.join(_HERE, "preview.png")

S = 454
ACCENT = (30, 155, 255)   # azul 0x1E9BFF (mes)
WHITE = (255, 255, 255)
GRAY = (170, 170, 170)
GREEN = (0, 255, 0)       # 0x00FF00 (día semana, nº del día, hora AOD verde)
RED = (255, 0, 0)

f_time = ImageFont.truetype(f"{SRC}/RobotoMono-Bold.ttf", 156)   # hora
f_num = ImageFont.truetype(f"{SRC}/RobotoMono-Bold.ttf", 78)     # nº día
f_mon = ImageFont.truetype(f"{SRC}/RobotoMono-Medium.ttf", 70)   # mes y día semana

Y_WDAY, Y_TIME, Y_DATE = 0.20, 0.50, 0.815


def big_time(d, cx, cy, hh, mm, color):
    wHH = f_time.getlength(hh)
    wMM = f_time.getlength(mm)
    cs = int(f_time.getlength(":") * 0.5)
    x0 = cx - (wHH + cs + wMM) / 2
    d.text((x0, cy), hh, font=f_time, fill=color, anchor="lm")
    d.text((x0 + wHH + cs / 2, cy), ":", font=f_time, fill=color, anchor="mm")
    d.text((x0 + wHH + cs, cy), mm, font=f_time, fill=color, anchor="lm")


def weekday(d, cx, cy, full):
    d.text((cx, cy), full, font=f_mon, fill=GREEN, anchor="mm")


def day_month(d, cx, cy, day, mon):
    num = str(day)
    numW = f_num.getlength(num)
    gap = 14
    groupW = numW + gap + f_mon.getlength(mon)
    x0 = cx - groupW / 2
    d.text((x0, cy), num, font=f_num, fill=GREEN, anchor="lm")       # nº en verde
    d.text((x0 + numW + gap, cy), mon, font=f_mon, fill=ACCENT, anchor="lm")  # mes azul


def face(mode, aod_color=None):
    img = Image.new("RGB", (S, S), (0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = S // 2
    if mode == "interactive":
        weekday(d, cx, int(S * Y_WDAY), "LUN")
        big_time(d, cx, int(S * Y_TIME), "9", "24", WHITE)
        day_month(d, cx, int(S * Y_DATE), 9, "AGO")
    else:
        ox, oy = 8, -8
        big_time(d, cx + ox, S // 2 + oy, "9", "24", aod_color)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, S - 1, S - 1], fill=255)
    img.putalpha(mask)
    return img


def watch(mode, aod_color=None):
    pad = 34
    W = S + pad * 2
    c = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.ellipse([0, 0, W - 1, W - 1], fill=(58, 60, 66, 255))
    d.ellipse([6, 6, W - 7, W - 7], fill=(74, 77, 82, 255))
    d.ellipse([pad - 4, pad - 4, pad + S + 3, pad + S + 3], fill=(20, 21, 24, 255))
    tick = ImageFont.truetype(f"{SRC}/RobotoMono-Bold.ttf", 20)
    for txt, (tx, ty) in {"60": (W // 2, 20), "15": (W - 26, W // 2),
                          "30": (W // 2, W - 20), "45": (24, W // 2)}.items():
        d.text((tx, ty), txt, font=tick, fill=(200, 203, 209), anchor="mm")
    c.alpha_composite(face(mode, aod_color), (pad, pad))
    return c


items = [
    ("interactive", None, "INTERACTIVO", "dia semana + hora + fecha"),
    ("aod", GREEN, "ALWAYS-ON - VERDE", "solo hora (~9%)"),
    ("aod", RED, "ALWAYS-ON - ROJO", "solo hora (~9%)"),
]
ws = [watch(m, c) for (m, c, _, _) in items]
gap, margin, lab_h = 50, 40, 70
w0 = ws[0].width
CW = w0 * 3 + gap * 2 + margin * 2
CH = ws[0].height + margin + lab_h
out = Image.new("RGB", (CW, CH), (18, 18, 22))
d = ImageDraw.Draw(out)
lab = ImageFont.truetype(f"{SRC}/RobotoMono-Medium.ttf", 28)
sub = ImageFont.truetype(f"{SRC}/RobotoMono-Regular.ttf", 18)
for i, (w, (_, _, title, subt)) in enumerate(zip(ws, items)):
    x = margin + i * (w0 + gap)
    out.paste(w, (x, margin), w)
    ly = margin + w.height + 12
    d.text((x + w0 // 2, ly), title, font=lab, fill=WHITE, anchor="ma")
    d.text((x + w0 // 2, ly + 32), subt, font=sub, fill=GRAY, anchor="ma")

out.save(OUT)
print("preview escrito:", OUT, out.size)
