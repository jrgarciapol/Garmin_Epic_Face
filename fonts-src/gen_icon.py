#!/usr/bin/env python3
"""Genera el icono de lanzador (launcher icon) para el Epix Pro 51 mm.
El dispositivo lo pide a 60x60 px. Dibuja un reloj minimalista: cara oscura,
anillo y agujas en azul de acento. PNG RGBA, sin dependencias externas.
"""
import zlib, struct, math, os

W = H = 60
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "resources", "drawables", "launcher_icon.png")

px = [[(0, 0, 0, 0) for _ in range(W)] for _ in range(H)]
cx, cy = (W - 1) / 2.0, (H - 1) / 2.0
accent = (30, 155, 255, 255)   # azul 0x1E9BFF
dark = (18, 18, 22, 255)       # cara casi negra

ring_out = 29.0
ring_in = 23.5


def dist(x, y):
    return math.hypot(x - cx, y - cy)


for y in range(H):
    for x in range(W):
        d = dist(x, y)
        if d <= ring_in:
            px[y][x] = dark
        elif d <= ring_out:
            px[y][x] = accent


def line(x0, y0, x1, y1, color, thick):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 4) + 1
    for i in range(steps + 1):
        t = i / steps
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                xx, yy = int(round(x)) + dx, int(round(y)) + dy
                if 0 <= xx < W and 0 <= yy < H and math.hypot(dx, dy) <= thick:
                    px[yy][xx] = color


line(cx, cy, cx, cy - 13.0, accent, 2.4)      # aguja horaria (arriba)
line(cx, cy, cx + 14.5, cy - 7.0, accent, 2.1) # aguja minutera (~2 en punto)
for y in range(H):                              # punto central
    for x in range(W):
        if dist(x, y) <= 3.2:
            px[y][x] = accent

raw = bytearray()
for y in range(H):
    raw.append(0)
    for x in range(W):
        raw += bytes(px[y][x])


def chunk(typ, data):
    c = struct.pack(">I", len(data)) + typ + data
    return c + struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff)


png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
png += chunk(b"IEND", b"")
with open(OUT, "wb") as f:
    f.write(png)
print("icono", W, "x", H, "escrito en", OUT, "(", len(png), "bytes )")
