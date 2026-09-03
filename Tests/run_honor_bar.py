"""Exercise actual honor renderers and clipping with a Lua 5.1 UI geometry mock."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
from PIL import Image

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / "Tests/honor_bar_spec.lua").read_text(encoding="utf-8-sig"))
for name in ("InteriorMask", "HonorWidget", "WSGHonor", "ABHonor", "AVHonor"):
    lua.execute((root / f"ZurkMaps_{name}.lua").read_text(encoding="utf-8-sig"))
lua.globals().RunHonorBarTests()

for orientation, size in (("Vertical", (128, 1024)), ("Horizontal", (1024, 128))):
    with Image.open(root / f"Media/HonorUnrealizedStripes_{orientation}.tga") as im:
        assert im.size == size
        alpha = im.getchannel("A")
        assert alpha.crop((0, 0, 16, 16)).getextrema() == (0, 210)
print("Packaged stripe textures contain visible, transparent repeating stripes.")
