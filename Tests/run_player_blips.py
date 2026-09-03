"""Compile shared blip code and run marker/rank regressions with Lua 5.1."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / "ZurkMaps_PlayerBlips.lua").read_text(encoding="utf-8-sig"))
lua.execute((root / "Tests/player_blips_spec.lua").read_text(encoding="utf-8-sig"))
