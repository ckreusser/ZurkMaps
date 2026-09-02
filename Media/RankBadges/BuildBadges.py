"""Rebuild helmet-only class textures from the original badges and audited masks."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parent
COLORS = {
    "WARRIOR": (199, 156, 110), "PALADIN": (245, 140, 186),
    "HUNTER": (171, 212, 115), "ROGUE": (255, 245, 105),
    "PRIEST": (255, 255, 255), "SHAMAN": (0, 112, 222),
    "MAGE": (64, 199, 235), "WARLOCK": (135, 135, 237),
    "DRUID": (255, 125, 10),
}

def build():
    masks = json.loads((ROOT / "HelmetMasks.json").read_text())
    for rank in (12, 13, 14):
        original = Image.open(ROOT / f"Rank{rank}_Original.png").convert("RGBA")
        mask = {tuple(point) for point in masks[str(rank)]}
        for token, color in COLORS.items():
            output = original.copy()
            for x, y in mask:
                r, g, b, alpha = original.getpixel((x, y))
                # Extract neutral brightness instead of multiplying gold into RGB.
                shade = (max(r, g, b) / 255) ** 0.35
                glint = max(0, (min(r, g, b) / 255 - 0.38) / 0.62) * 0.16
                rgb = tuple(round(c * shade + (255 - c * shade) * glint) for c in color)
                output.putpixel((x, y), rgb + (alpha,))
            assert output.getchannel("A").tobytes() == original.getchannel("A").tobytes()
            for y in range(32):
                for x in range(32):
                    if (x, y) not in mask:
                        assert output.getpixel((x, y)) == original.getpixel((x, y))
            output.save(ROOT / f"Rank{rank}_{token}.tga", compression=None)

if __name__ == "__main__":
    build()
