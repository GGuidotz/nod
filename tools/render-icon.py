#!/usr/bin/env python3
"""Disegna l'icona di Nod (1024 px) con effetto vetro statico: il fallback .icns quando Icon Composer non c'è.
Concetto: la spunta è il percorso di un cenno del capo (giù, poi su), in vetro chiaro, con due eco più in alto che
svaniscono (il movimento della testa), su un fondo blu notte che vira al ciano. Stessa geometria degli strati SVG di Resources/Icon/Nod.icon.
    python3 tools/render-icon.py Resources/Icon/AppIcon-1024.png
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 3                      # supersampling
N = 1024 * S

def lerp(a, b, t):
    return a + (b - a) * t

def gradient_bg(size):
    y, x = np.mgrid[0:size, 0:size] / (size - 1)
    top = np.array([12, 18, 52], float)        # blu notte
    mid = np.array([30, 44, 120], float)       # indaco
    glow = np.array([40, 214, 236], float)     # ciano aurora
    t = np.clip((x * 0.35 + y * 0.65), 0, 1)[..., None]
    base = lerp(top, mid, t)
    # bagliore ciano in basso a destra
    d = np.sqrt((x - 0.85) ** 2 + (y - 0.95) ** 2)
    g = np.clip(1 - d / 0.75, 0, 1)[..., None] ** 2.2
    base = lerp(base, glow, g * 0.85)
    # bagliore viola in alto a sinistra
    d2 = np.sqrt((x - 0.12) ** 2 + (y - 0.08) ** 2)
    g2 = np.clip(1 - d2 / 0.6, 0, 1)[..., None] ** 2
    base = lerp(base, np.array([110, 70, 220], float), g2 * 0.45)
    a = np.full((size, size, 1), 255.0)
    return Image.fromarray(np.concatenate([base, a], 2).astype(np.uint8), "RGBA")

def check_points(scale):
    # coordinate sulla tela 1024, centro ottico leggermente in basso
    pts = [(292, 590), (448, 744), (748, 404)]
    return [(x * scale, y * scale) for x, y in pts]

def stroke_mask(size, pts, width):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.line(pts, fill=255, width=int(width), joint="curve")
    r = width / 2
    for x, y in (pts[0], pts[-1], pts[1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return m

def vertical(size, top, bottom):
    t = np.linspace(0, 1, size)[:, None, None]
    rgb = lerp(np.array(top, float), np.array(bottom, float), t) * np.ones((1, size, 1))
    a = np.full((size, size, 1), 255.0)
    return Image.fromarray(np.concatenate([rgb, a], 2).astype(np.uint8), "RGBA")

def glass(base, mask, tint=(255, 255, 255), fill=0.30, rim=0.9, blur_bg=28 * S, tint_bottom=None):
    """Vetro: lo sfondo sotto sfocato e schiarito, riempimento traslucido, bordo luminoso, riflesso in alto."""
    size = base.size[0]
    refr = base.filter(ImageFilter.GaussianBlur(blur_bg))
    paint = vertical(size, tint, tint_bottom) if tint_bottom else Image.new("RGBA", base.size, tint + (255,))
    refr = Image.blend(refr, paint, fill)
    out = Image.composite(refr, base, mask)
    # bordo: differenza tra la maschera e la sua erosione
    er = mask.filter(ImageFilter.MinFilter(9 * S + 1 if (9 * S) % 2 == 0 else 9 * S))
    edge = ImageChops.subtract(mask, er).filter(ImageFilter.GaussianBlur(2 * S))
    rim_layer = Image.new("RGBA", base.size, (255, 255, 255, 0))
    rim_layer.putalpha(edge.point(lambda v: int(v * rim)))
    out = Image.alpha_composite(out, rim_layer)
    # riflesso speculare: la parte alta della forma, schiarita
    shift = mask.transform(mask.size, Image.AFFINE, (1, 0, 0, 0, 1, 14 * S))
    spec = ImageChops.subtract(mask, shift).filter(ImageFilter.GaussianBlur(6 * S))
    spec_layer = Image.new("RGBA", base.size, (255, 255, 255, 0))
    spec_layer.putalpha(spec.point(lambda v: int(v * 0.75)))
    return Image.alpha_composite(out, spec_layer)

def shadow(base, mask, offset=18, blur=34, opacity=0.45):
    sh = mask.transform(mask.size, Image.AFFINE, (1, 0, 0, 0, 1, -offset * S)).filter(ImageFilter.GaussianBlur(blur * S))
    layer = Image.new("RGBA", base.size, (4, 8, 30, 0))
    layer.putalpha(sh.point(lambda v: int(v * opacity)))
    return Image.alpha_composite(base, layer)

def render(squircle=True):
    img = gradient_bg(N)
    pts = check_points(S)
    # eco del movimento: la stessa spunta più in alto, sempre più trasparente
    for dy, fill, rim in ((-150, 0.10, 0.35), (-78, 0.20, 0.55)):
        echo = stroke_mask(N, [(x, y + dy * S) for x, y in pts], 128 * S)
        img = glass(img, echo, tint=(190, 235, 255), fill=fill, rim=rim, blur_bg=22 * S)
    # spunta di vetro, il protagonista
    chk = stroke_mask(N, pts, 128 * S)
    img = shadow(img, chk, offset=22, blur=36, opacity=0.55)
    img = glass(img, chk, tint=(255, 255, 255), fill=0.86, rim=1.0, blur_bg=16 * S, tint_bottom=(150, 236, 255))
    img = img.resize((1024, 1024), Image.LANCZOS)
    if not squircle:
        return img
    # fallback .icns: squircle macOS (824 px nella griglia 1024) con ombra
    size, inset, radius = 1024, 100, 185
    mask = Image.new("L", (size * S, size * S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([inset * S, inset * S, (size - inset) * S, (size - inset) * S],
                                           radius=radius * S, fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    art = img.resize((size - 2 * inset, size - 2 * inset), Image.LANCZOS)
    canvas_art = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas_art.paste(art, (inset, inset))
    canvas_art.putalpha(mask)
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sh.putalpha(mask.transform(mask.size, Image.AFFINE, (1, 0, 0, 0, 1, -12)).filter(ImageFilter.GaussianBlur(14))
                .point(lambda v: int(v * 0.35)))
    return Image.alpha_composite(sh, canvas_art)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "AppIcon-1024.png"
    render(squircle=True).save(out)
    if len(sys.argv) > 2:
        render(squircle=False).save(sys.argv[2])
    print("scritto", out)
