"""Split the artist's flat "Amplop coklat.png" into the level select's layers.

The delivered art is one 1080x1920 canvas: the envelope with its flap, crease
and button-and-string seal all baked together. The open animation needs them
apart, so this cuts four same-size layers, cropped to the envelope:

  amplop_body.png       the envelope, with the flap area repainted as the
                        envelope's inside (what shows once the flap lifts)
                        and the seal painted out
  amplop_flap.png       the flap: the top band, hinge at the top edge, down
                        to the crease
  amplop_flap_back.png  the same shape as the flap's plain inside, swapped in
                        as the flap turns past edge-on
  amplop_seal.png       the two red buttons and the string between them

Usage:  python tools/split_amplop.py "<path to Amplop coklat.png>"
Writes into Assets/Images/LevelSelect/. The polygons below are traced on the
2026-09-25 delivery; a redrawn envelope needs them re-traced.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "Assets" / "Images" / "LevelSelect"

# Crop box around the envelope's alpha bounds (122,423)-(940,1499), 1px pad.
CROP = (121, 422, 942, 1501)

# The flap, in source-canvas pixels: the top edge (the hinge), the right fold
# diagonal, the crease, the left fold diagonal.
FLAP = [(139, 423), (942, 440), (941, 452), (922, 470), (895, 565), (880, 577),
        (215, 550), (202, 544), (156, 446), (139, 438)]

# Box holding both buttons and the string (source-canvas pixels).
SEAL_BOX = (508, 470, 630, 672)

# The envelope's inside, shown under a lifted flap: darker kraft, deepest at
# the opening.
INSIDE_TOP = (176, 128, 64)
INSIDE_BOTTOM = (214, 168, 94)
# The flap's plain inside face.
FLAP_BACK = (226, 184, 110)


def _seal_mask(rgb: np.ndarray) -> np.ndarray:
    """Button red, button highlight pink and string brown -- never kraft."""
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    red = (g < 120) & (r > 120)
    pink = (b > 150) & (r > 200)
    string = (r < 195) & (g < 150)
    mask = np.zeros(rgb.shape[:2], bool)
    x0, y0, x1, y1 = SEAL_BOX
    box = np.zeros_like(mask)
    box[y0:y1, x0:x1] = True
    mask[box] = (red | pink | string)[box]
    return mask


def _inpaint_rows(img: np.ndarray, hole: np.ndarray) -> None:
    """Fill each row's run of hole pixels by interpolating its two edges.

    The crease is near-horizontal, so row-wise interpolation carries it
    straight through the painted-out seal."""
    for y in np.where(hole.any(axis=1))[0]:
        row = hole[y]
        x = 0
        while x < row.size:
            if not row[x]:
                x += 1
                continue
            start = x
            while x < row.size and row[x]:
                x += 1
            left = img[y, max(start - 1, 0), :3].astype(float)
            right = img[y, min(x, row.size - 1), :3].astype(float)
            n = x - start
            for i in range(n):
                t = (i + 1) / (n + 1)
                img[y, start + i, :3] = (left * (1 - t) + right * t).astype(np.uint8)


def main(src: str) -> None:
    im = Image.open(src).convert("RGBA")
    px = np.array(im)

    # Seal: its own layer, then painted out of the source.
    # The layer keeps a 1px rim for its anti-aliasing; the paint-out takes
    # 2px so no red fringe is left behind on the body.
    mask = _seal_mask(px[..., :3])
    as_img = Image.fromarray(mask.astype(np.uint8) * 255)
    rim = np.array(as_img.filter(ImageFilter.MaxFilter(3))) > 0
    grown = np.array(as_img.filter(ImageFilter.MaxFilter(5))) > 0
    seal = np.zeros_like(px)
    seal[rim] = px[rim]
    _inpaint_rows(px, grown)

    flap_mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(flap_mask).polygon(FLAP, fill=255)
    flap_mask = flap_mask.filter(ImageFilter.GaussianBlur(0.6))
    fm = np.array(flap_mask).astype(float) / 255.0

    flap = px.copy()
    flap[..., 3] = (flap[..., 3] * fm).astype(np.uint8)

    body = px.copy()
    ys = np.arange(body.shape[0], dtype=float)[:, None]
    top, bottom = min(p[1] for p in FLAP), max(p[1] for p in FLAP)
    t = np.clip((ys - top) / (bottom - top), 0, 1)
    for c in range(3):
        inside = INSIDE_TOP[c] * (1 - t) + INSIDE_BOTTOM[c] * t
        body[..., c] = (body[..., c] * (1 - fm) + inside * fm).astype(np.uint8)

    back = np.zeros_like(px)
    back[..., :3] = FLAP_BACK
    back[..., 3] = (fm * 255).astype(np.uint8)

    OUT.mkdir(parents=True, exist_ok=True)
    for name, arr in [("amplop_body", body), ("amplop_flap", flap),
                      ("amplop_flap_back", back), ("amplop_seal", seal)]:
        Image.fromarray(arr).crop(CROP).save(OUT / f"{name}.png", optimize=True)
        print("wrote", OUT / f"{name}.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Amplop coklat.png")
