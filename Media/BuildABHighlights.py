"""Build smooth AB hover artwork, contested artwork, and animation masks."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


MEDIA = Path(__file__).resolve().parent
HIGHLIGHTS = MEDIA / "Highlights"
CONTESTED = MEDIA / "Contested"
MASKS = MEDIA / "CalloutMasks"
SIZE = 512
SUPERSAMPLE = 4
BORDER_WIDTH = 4
ROAD_HALF_WIDTH = 1.20

BRIDGE_COLOR = ((118, 164, 217, 68), (137, 186, 255, 235))
WATER_COLOR = ((106, 190, 205, 68), (115, 231, 247, 235))

COLORS = {
    "STABLES": ((103, 202, 197, 68), (120, 245, 245, 235)),
    "GOLD_MINE": ((214, 176, 62, 68), (255, 213, 77, 235)),
    "LUMBER_MILL": ((214, 146, 57, 68), (255, 171, 78, 235)),
    "BLACKSMITH": ((172, 122, 196, 68), (216, 149, 255, 235)),
    "FARM": ((214, 84, 73, 68), (255, 78, 66, 235)),
    "BS_BRIDGE_ST": BRIDGE_COLOR,
    "BS_GY_WATER": WATER_COLOR,
    "BS_LM_FARM_INTERSECTION": BRIDGE_COLOR,
    "BS_LM_WATER": WATER_COLOR,
    "ROAD": ((166, 206, 84, 68), (208, 247, 109, 235)),
}

POLYGONS = {
    "STABLES": [(35.20, 16.30), (32.90, 14.90), (29.90, 14.80), (22.20, 18.10), (11.90, 25.30), (11.10, 30.10), (13.30, 33.40), (15.90, 34.60), (29.40, 37.20), (33.40, 36.80), (36.80, 33.70), (38.10, 29.80)],
    "GOLD_MINE": [(52.30, 21.10), (51.40, 25.90), (64.30, 37.30), (71.40, 49.50), (75.80, 50.10), (81.70, 46.70), (82.10, 29.60), (84.00, 20.60), (74.00, 18.50), (68.30, 21.90)],
    "LUMBER_MILL": [(22.30, 57.50), (20.40, 60.40), (20.00, 65.90), (22.30, 70.00), (22.80, 76.00), (24.60, 79.50), (30.90, 82.90), (35.30, 83.90), (47.80, 80.70), (48.80, 74.40), (47.10, 71.90), (42.10, 71.90), (34.90, 68.30), (29.70, 61.40), (28.90, 55.70), (24.60, 56.00)],
    "BLACKSMITH": [(45.90, 39.50), (43.90, 40.70), (42.20, 43.30), (40.70, 51.10), (44.70, 57.60), (48.00, 59.40), (52.70, 60.50), (55.00, 59.50), (57.30, 56.50), (57.70, 49.40), (51.80, 39.00)],
    "FARM": [(86.80, 66.70), (82.30, 61.60), (74.60, 61.80), (70.70, 63.90), (65.00, 64.90), (59.50, 69.00), (57.10, 77.70), (58.70, 79.70), (67.50, 82.30), (71.40, 86.00), (73.80, 86.10), (80.10, 82.50), (85.20, 76.70), (87.20, 73.00)],
    "BS_BRIDGE_ST": [(47.30, 28.40), (45.70, 31.20), (45.80, 38.60), (51.30, 38.60), (54.10, 35.40), (54.00, 31.40), (51.70, 28.00)],
    "BS_GY_WATER": [(57.10, 43.00), (56.30, 45.50), (57.10, 58.30), (61.80, 58.90), (65.20, 55.80), (65.00, 49.60), (62.60, 42.80)],
    "BS_LM_FARM_INTERSECTION": [(48.80, 59.80), (47.00, 61.60), (47.50, 72.80), (50.60, 75.40), (54.60, 75.10), (57.50, 71.80), (59.90, 66.70), (57.40, 64.30), (54.70, 61.60)],
    "BS_LM_WATER": [(32.40, 42.00), (31.20, 44.20), (31.70, 52.60), (34.20, 55.40), (39.80, 55.50), (40.30, 44.30), (38.00, 41.80)],
}

ROADS = {
    "ROAD_ST_TO_LM": [[(24.40, 37.55), (24.45, 39.45), (25.20, 41.55), (26.45, 43.75), (27.55, 45.95), (28.05, 47.75), (27.55, 49.20), (26.40, 50.75), (25.20, 52.35), (24.25, 54.05), (24.10, 56.35), (24.60, 57.85)]],
    "ROAD_ST_TO_GM": [[(51.00, 24.00), (48.50, 23.80), (46.00, 23.90), (43.50, 24.00), (41.00, 24.40), (39.20, 25.00), (38.00, 26.00), (37.80, 26.80), (38.70, 27.70), (40.50, 28.40), (42.60, 28.90), (44.80, 29.10), (47.10, 29.20)]],
    "ROAD_ABOVE_GM": [[(53.20, 31.55), (55.30, 32.75), (57.45, 34.55), (59.45, 37.10), (61.55, 39.90), (63.90, 42.35), (65.75, 45.05), (66.45, 47.55), (66.80, 49.55), (68.45, 52.15)]],
    # The road visibly splits around a narrow grass island before rejoining.
    # Both centerlines are unioned before the border is calculated, avoiding
    # doubled outlines on the shared approach and exit.
    "ROAD_GM_TO_FARM": [
        [(66.80, 46.35), (67.10, 47.90), (67.75, 49.65), (68.70, 51.75), (70.25, 53.55), (72.55, 55.35), (73.30, 55.85)],
        [(71.55, 44.55), (71.55, 46.65), (71.70, 48.80), (72.10, 50.85), (72.70, 53.10), (73.30, 55.85)],
        [(73.25, 55.70), (74.55, 57.45), (75.85, 59.35), (76.55, 60.65), (76.55, 61.30)],
    ],
    "ROAD_BELOW_LM": [[(27.80, 50.05), (29.60, 52.15), (31.75, 55.10), (33.55, 56.95), (37.10, 59.85), (38.70, 60.75), (40.10, 62.00), (44.55, 65.30), (46.05, 66.25)]],
}

# Forked roads are flattened into one finished mask before their border is
# drawn. No branch draws over another branch in the packaged artwork.
ROAD_OUTLINES = {
    "ROAD_ST_TO_GM": [
        (36.40, 25.35), (38.20, 24.70), (40.40, 23.85), (43.20, 23.30),
        (46.10, 23.05), (49.00, 23.05), (51.00, 23.45), (51.70, 24.05),
        (51.50, 24.80), (50.70, 25.20), (48.20, 25.35), (45.40, 25.45),
        (42.60, 25.75), (40.20, 26.30), (38.90, 26.75), (40.50, 27.40),
        (42.80, 28.00), (45.10, 28.45), (47.10, 28.65), (47.85, 29.15),
        (47.65, 29.90), (46.85, 30.20), (44.60, 29.95), (42.20, 29.55),
        (39.95, 28.95), (38.15, 28.30), (36.85, 27.70), (36.15, 26.85),
    ],
}

ROAD_HALF_WIDTHS = {
    "ROAD_ST_TO_LM": 1.25,
    "ROAD_ABOVE_GM": 1.28,
    "ROAD_BELOW_LM": 1.38,
}

ROAD_UNION_HALF_WIDTHS = {
    "ROAD_GM_TO_FARM": [1.05, 1.05, 1.12],
}


def smooth(points: list[tuple[float, float]], iterations: int = 2) -> list[tuple[float, float]]:
    result = list(points)
    for _ in range(iterations):
        result = [
            mixed
            for index, point in enumerate(result)
            for mixed in (
                (point[0] * 0.75 + result[(index + 1) % len(result)][0] * 0.25, point[1] * 0.75 + result[(index + 1) % len(result)][1] * 0.25),
                (point[0] * 0.25 + result[(index + 1) % len(result)][0] * 0.75, point[1] * 0.25 + result[(index + 1) % len(result)][1] * 0.75),
            )
        ]
    return result


def smooth_open(points: list[tuple[float, float]], iterations: int = 2) -> list[tuple[float, float]]:
    result = list(points)
    for _ in range(iterations):
        smoothed = [result[0]]
        for point, following in zip(result, result[1:]):
            smoothed.extend(
                (
                    (point[0] * 0.75 + following[0] * 0.25, point[1] * 0.75 + following[1] * 0.25),
                    (point[0] * 0.25 + following[0] * 0.75, point[1] * 0.25 + following[1] * 0.75),
                )
            )
        smoothed.append(result[-1])
        result = smoothed
    return result


def road_contour(path: list[tuple[float, float]], half_width: float = ROAD_HALF_WIDTH) -> list[tuple[float, float]]:
    centers = smooth_open(path, 2)
    left, right, tangents, normals = [], [], [], []
    for index, point in enumerate(centers):
        before, after = centers[max(0, index - 1)], centers[min(len(centers) - 1, index + 1)]
        dx, dy = after[0] - before[0], after[1] - before[1]
        length = math.hypot(dx, dy)
        tx, ty = (dx / length, dy / length) if length else (0, 0)
        nx, ny = -ty * half_width, tx * half_width
        tangents.append((tx, ty))
        normals.append((nx, ny))
        left.append((point[0] + nx, point[1] + ny))
        right.append((point[0] - nx, point[1] - ny))
    contour = list(left)
    finish, finish_tangent, finish_normal = centers[-1], tangents[-1], normals[-1]
    for step in range(1, 7):
        angle = math.pi * step / 6
        contour.append(
            (
                finish[0] + finish_normal[0] * math.cos(angle) + finish_tangent[0] * half_width * math.sin(angle),
                finish[1] + finish_normal[1] * math.cos(angle) + finish_tangent[1] * half_width * math.sin(angle),
            )
        )
    contour.extend(reversed(right[:-1]))
    start, start_tangent, start_normal = centers[0], tangents[0], normals[0]
    for step in range(1, 6):
        angle = math.pi * step / 6
        contour.append(
            (
                start[0] - start_normal[0] * math.cos(angle) - start_tangent[0] * half_width * math.sin(angle),
                start[1] - start_normal[1] * math.cos(angle) - start_tangent[1] * half_width * math.sin(angle),
            )
        )
    return contour


def pixels(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    scale = SIZE * SUPERSAMPLE / 100
    return [(x * scale, y * scale) for x, y in points]


def render(contours: list[list[tuple[float, float]]], colors: tuple[tuple[int, ...], tuple[int, ...]]) -> tuple[Image.Image, Image.Image]:
    dimensions = (SIZE * SUPERSAMPLE, SIZE * SUPERSAMPLE)
    artwork = Image.new("RGBA", dimensions, (255, 255, 255, 0))
    mask_alpha = Image.new("L", dimensions, 0)
    art_draw, mask_draw = ImageDraw.Draw(artwork), ImageDraw.Draw(mask_alpha)
    fill, border = colors
    for contour in contours:
        vertices = pixels(contour)
        art_draw.polygon(vertices, fill=fill)
        art_draw.line(vertices + [vertices[0]], fill=border, width=BORDER_WIDTH * SUPERSAMPLE, joint="curve")
        mask_draw.polygon(vertices, fill=255)
    artwork = artwork.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    mask_alpha = mask_alpha.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    mask = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
    mask.putalpha(mask_alpha)
    return artwork, mask


def render_union(contours: list[list[tuple[float, float]]], colors: tuple[tuple[int, ...], tuple[int, ...]]) -> tuple[Image.Image, Image.Image]:
    """Render intersecting branch polygons as one final, seam-free shape."""
    dimensions = (SIZE * SUPERSAMPLE, SIZE * SUPERSAMPLE)
    union_alpha = Image.new("L", dimensions, 0)
    union_draw = ImageDraw.Draw(union_alpha)
    for contour in contours:
        union_draw.polygon(pixels(contour), fill=255)

    fill, border = colors
    erosion_size = (3 * SUPERSAMPLE * 2) + 1
    inner_alpha = union_alpha.filter(ImageFilter.MinFilter(erosion_size))
    border_alpha = ImageChops.subtract(union_alpha, inner_alpha)

    artwork = Image.new("RGBA", dimensions, fill)
    artwork.putalpha(Image.eval(union_alpha, lambda value: (value * fill[3]) // 255))
    border_layer = Image.new("RGBA", dimensions, border)
    border_layer.putalpha(Image.eval(border_alpha, lambda value: (value * border[3]) // 255))
    artwork = Image.alpha_composite(artwork, border_layer).resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    mask_alpha = union_alpha.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    mask = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
    mask.putalpha(mask_alpha)
    return artwork, mask


def road_contours(name: str, paths: list[list[tuple[float, float]]]) -> list[list[tuple[float, float]]]:
    if name in ROAD_OUTLINES:
        return [ROAD_OUTLINES[name]]
    if name in ROAD_UNION_HALF_WIDTHS:
        return [road_contour(path, width) for path, width in zip(paths, ROAD_UNION_HALF_WIDTHS[name])]
    return [road_contour(paths[0], ROAD_HALF_WIDTHS[name])]


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, compression="tga_rle")


def main() -> None:
    all_contours = {name: [smooth(points)] for name, points in POLYGONS.items()}
    all_contours.update({name: road_contours(name, paths) for name, paths in ROADS.items()})
    for name, contours in all_contours.items():
        if name.startswith("ROAD_"):
            artwork, mask = render_union(contours, COLORS["ROAD"]) if name in ROAD_UNION_HALF_WIDTHS else render(contours, COLORS["ROAD"])
        else:
            artwork, mask = render(contours, COLORS[name])
        save(artwork, HIGHLIGHTS / f"{name}.tga")
        save(mask, MASKS / f"{name}.tga")
        if name in POLYGONS and name in {"STABLES", "GOLD_MINE", "BLACKSMITH", "LUMBER_MILL", "FARM"}:
            contested, _ = render(contours, ((255, 255, 255, 68), (255, 255, 255, 235)))
            save(contested, CONTESTED / f"{name}.tga")
    print(f"Built {len(all_contours)} smooth AB highlights and animation masks.")


if __name__ == "__main__":
    main()
