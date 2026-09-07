"""Compile shared blip code and run marker/rank regressions with Lua 5.1."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
from PIL import Image

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / "ZurkMaps_PlayerBlips.lua").read_text(encoding="utf-8-sig"))
lua.execute((root / "Tests/player_blips_spec.lua").read_text(encoding="utf-8-sig"))

rank_badges = list((root / "Media" / "RankBadges").glob("Rank??_*.tga"))
assert len(rank_badges) == 27
assert {Image.open(path).size for path in rank_badges} == {(64, 64)}
rank_shadows = list((root / "Media" / "RankBadgeShadows").glob("Rank??.tga"))
assert len(rank_shadows) == 3
for path in rank_shadows:
    with Image.open(path).convert("RGBA") as shadow:
        assert shadow.size == (64, 64) and shadow.getchannel("A").getbbox()
