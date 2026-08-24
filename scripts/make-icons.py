#!/usr/bin/env python3
"""Generate PWA icons: kurva naik emas di atas latar gelap aplikasi.

Jalankan ulang setelah mengubah warna:  python3 scripts/make-icons.py
"""
from PIL import Image, ImageDraw

BG = (11, 13, 20)          # hsl(222 30% 6%)  — --background
GOLD = (251, 189, 35)      # hsl(43 96% 56%)  — --gold
CYAN = (40, 222, 246)      # hsl(187 92% 56%) — --cyan
SS = 4                     # supersampling

LINE = [(0.13, 0.73), (0.33, 0.51), (0.47, 0.62), (0.65, 0.33), (0.87, 0.21)]
BASELINE = 0.84


def draw_icon(size: int, *, rounded: bool, pad: float) -> Image.Image:
    px = size * SS
    base = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)

    if rounded:
        d.rounded_rectangle([0, 0, px - 1, px - 1], radius=int(px * 0.22), fill=BG)
    else:
        d.rectangle([0, 0, px, px], fill=BG)

    # Kotak isi: menyusut sesuai pad supaya versi maskable aman dari pemotongan.
    inner = px * (1 - 2 * pad)
    off = px * pad

    def p(x: float, y: float) -> tuple[float, float]:
        return (off + x * inner, off + y * inner)

    pts = [p(x, y) for x, y in LINE]

    # Bagian tembus pandang digambar di lapisan sendiri lalu dikomposit —
    # ImageDraw menimpa piksel, bukan membaurkannya.
    glow = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.polygon([*pts, p(LINE[-1][0], BASELINE), p(LINE[0][0], BASELINE)], fill=(*GOLD, 38))
    g.line([p(0.08, BASELINE), p(0.92, BASELINE)], fill=(*CYAN, 110), width=max(1, int(inner * 0.016)))
    base = Image.alpha_composite(base, glow)

    # Kurva emas, digambar padat di atasnya.
    d = ImageDraw.Draw(base)
    d.line(pts, fill=GOLD, width=int(inner * 0.082), joint="curve")
    r_join = inner * 0.041
    for point in pts[:-1]:
        d.ellipse(
            [point[0] - r_join, point[1] - r_join, point[0] + r_join, point[1] + r_join],
            fill=GOLD,
        )

    # Penanda harga terakhir: cincin emas berlubang.
    last = pts[-1]
    r = inner * 0.095
    d.ellipse([last[0] - r, last[1] - r, last[0] + r, last[1] + r], fill=GOLD)
    d.ellipse(
        [last[0] - r * 0.44, last[1] - r * 0.44, last[0] + r * 0.44, last[1] + r * 0.44],
        fill=BG,
    )

    return base.resize((size, size), Image.LANCZOS)


def main() -> None:
    for size in (192, 512):
        draw_icon(size, rounded=True, pad=0.10).save(f"public/icons/icon-{size}.png")

    # Maskable: latar penuh, isi ditarik ke dalam safe zone (~80%).
    for size in (192, 512):
        draw_icon(size, rounded=False, pad=0.20).save(f"public/icons/maskable-{size}.png")

    draw_icon(180, rounded=True, pad=0.12).save("public/icons/apple-touch-icon.png")

    favicon = draw_icon(64, rounded=True, pad=0.06)
    favicon.save("public/favicon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])
    favicon.resize((32, 32), Image.LANCZOS).save("public/icons/icon-32.png")

    print("ikon dibuat di public/icons/")


if __name__ == "__main__":
    main()
