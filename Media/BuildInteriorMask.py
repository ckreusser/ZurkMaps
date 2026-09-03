"""Generate four oriented corner masks; WoW ignores UV transforms on masks."""
from pathlib import Path
import math
import struct


def build():
    size = 64
    # Uncompressed, top-origin, 32-bit BGRA with eight alpha bits.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 40)
    variants = (
        ("InteriorCornerMask", False, False),
        ("InteriorCornerMask_TopRight", True, False),
        ("InteriorCornerMask_BottomLeft", False, True),
        ("InteriorCornerMask_BottomRight", True, True),
    )
    for name, flip_x, flip_y in variants:
        pixels = bytearray()
        for y in range(size):
            for x in range(size):
                sx = size - 1 - x if flip_x else x
                sy = size - 1 - y if flip_y else y
                distance = math.hypot(size - sx - 0.5, size - sy - 0.5)
                alpha = round(255 * max(0, min(1, size + 0.5 - distance)))
                # Interior-facing edges remain fully opaque, including their
                # endpoints. The cutout belongs only at the outer corner.
                if sx == size - 1 or sy == size - 1:
                    alpha = 255
                pixels.extend((255, 255, 255, alpha))
        Path(__file__).with_name(name + ".tga").write_bytes(header + pixels)


if __name__ == "__main__":
    build()
