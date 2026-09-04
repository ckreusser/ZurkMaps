"""Build anti-aliased WSG hover art and callout masks from hotspot geometry."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
MEDIA = Path(__file__).resolve().parent
GEOMETRY = ROOT / "HotspotGeometry_v8.json"
HIGHLIGHTS = MEDIA / "Highlights"
CALLOUT_MASKS = MEDIA / "CalloutMasks"
SIZE = 512
SUPERSAMPLE = 4
BORDER_WIDTH = 4
DISPLAY_MAP_WIDTH = 334
ALLIANCE_NUDGE_PIXELS = 5

COLORS = {
    "ALLY": ((40, 120, 255, 72), (95, 170, 255, 235)),
    "HORDE": ((245, 65, 65, 72), (255, 105, 105, 235)),
    "MID": ((45, 220, 100, 68), (90, 245, 135, 235)),
}


def region_nudge_x(region: dict) -> float:
    if region["team"] == "ALLY" and region["id"] != "ALLY_TOP_OF_TUNNEL":
        return ALLIANCE_NUDGE_PIXELS * 100 / DISPLAY_MAP_WIDTH
    return 0


def scaled_point(point: list[float], nudge_x: float = 0) -> tuple[float, float]:
    scale = (SIZE * SUPERSAMPLE) / 100
    return (point[0] + nudge_x) * scale, point[1] * scale


def downsample(image: Image.Image) -> Image.Image:
    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def save_rle(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, compression="tga_rle")


def polygon_layers(points: list[list[float]], team: str, nudge_x: float = 0) -> tuple[Image.Image, Image.Image]:
    dimensions = (SIZE * SUPERSAMPLE, SIZE * SUPERSAMPLE)
    fill_color, border_color = COLORS[team]
    artwork = Image.new("RGBA", dimensions, (255, 255, 255, 0))
    draw = ImageDraw.Draw(artwork)
    vertices = [scaled_point(point, nudge_x) for point in points]
    draw.polygon(vertices, fill=fill_color)
    draw.line(
        vertices + [vertices[0]],
        fill=border_color,
        width=BORDER_WIDTH * SUPERSAMPLE,
        joint="curve",
    )

    mask_alpha = Image.new("L", dimensions, 0)
    ImageDraw.Draw(mask_alpha).polygon(vertices, fill=255)
    mask = Image.new("RGBA", dimensions, (255, 255, 255, 255))
    mask.putalpha(mask_alpha)
    return downsample(artwork), downsample(mask)


def ellipse_layers(center: list[float], radius: list[float], team: str, nudge_x: float = 0) -> tuple[Image.Image, Image.Image]:
    dimensions = (SIZE * SUPERSAMPLE, SIZE * SUPERSAMPLE)
    scale = (SIZE * SUPERSAMPLE) / 100
    cx, cy = (center[0] + nudge_x) * scale, center[1] * scale
    rx, ry = radius[0] * scale, radius[1] * scale
    bounds = (cx - rx, cy - ry, cx + rx, cy + ry)
    fill_color, border_color = COLORS[team]
    artwork = Image.new("RGBA", dimensions, (255, 255, 255, 0))
    draw = ImageDraw.Draw(artwork)
    draw.ellipse(bounds, fill=fill_color, outline=border_color, width=BORDER_WIDTH * SUPERSAMPLE)

    mask_alpha = Image.new("L", dimensions, 0)
    ImageDraw.Draw(mask_alpha).ellipse(bounds, fill=255)
    mask = Image.new("RGBA", dimensions, (255, 255, 255, 255))
    mask.putalpha(mask_alpha)
    return downsample(artwork), downsample(mask)


def build_stripes() -> None:
    source = Image.open(MEDIA / "HonorUnrealizedStripes_Horizontal.tga").convert("RGBA")
    stripes = Image.new("RGBA", (source.width, SIZE), (255, 255, 255, 0))
    for y in range(0, SIZE, source.height):
        stripes.paste(source, (0, y))
    save_rle(stripes, MEDIA / "CalloutStripes.tga")


def main() -> None:
    geometry = json.loads(GEOMETRY.read_text(encoding="utf-8"))
    for region in geometry["regions"]:
        artwork, mask = polygon_layers(region["points"], region["team"], region_nudge_x(region))
        save_rle(artwork, HIGHLIGHTS / f"{region['id']}.tga")
        save_rle(mask, CALLOUT_MASKS / f"{region['id']}.tga")
    for region in geometry["nested"]:
        artwork, mask = ellipse_layers(region["center"], region["radius"], region["team"], region_nudge_x(region))
        save_rle(artwork, HIGHLIGHTS / f"{region['id']}.tga")
        save_rle(mask, CALLOUT_MASKS / f"{region['id']}.tga")
    build_stripes()


if __name__ == "__main__":
    main()
