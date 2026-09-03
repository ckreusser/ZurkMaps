"""Run the real parser, highlight renderer, and event lifecycle with Lua 5.1."""
from pathlib import Path
import re
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval("function(s,n) local f,e=loadstring(s,n); return f~=nil,e end")
for name in ("ZurkMaps_WSGIncoming.lua", "ZurkMaps_WSG.lua"):
    ok, error = compile_lua((root / name).read_text(encoding="utf-8-sig"), name)
    if not ok:
        raise AssertionError(error)

lua.execute((root / "ZurkMaps_WSGIncoming.lua").read_text(encoding="utf-8-sig"))
wsg = (root / "ZurkMaps_WSG.lua").read_text(encoding="utf-8-sig")
geometry = wsg[wsg.index("local ZONES = {"):wsg.index("local function Report(")]
lua.execute(geometry + "\nTEST_ZONES = ZONES; TEST_NESTED_ZONES = NESTED_ZONES")
renderer = wsg[wsg.index("local function CreateWSGHighlight()"):wsg.index("local highlightTexture = CreateWSGHighlight()")]
lua.execute(renderer.replace("local function CreateWSGHighlight()", "function CreateWSGHighlight()", 1))
lua.execute((root / "Tests/wsg_incoming_spec.lua").read_text(encoding="utf-8-sig"))

# Check that all alias results refer to existing regions and packaged textures.
zones = lua.globals().TEST_ZONES
nested = lua.globals().TEST_NESTED_ZONES
known = {zone["id"] for group in (zones, nested) for zone in group.values()}
alias_count = 0
module = (root / "ZurkMaps_WSGIncoming.lua").read_text(encoding="utf-8-sig")
for group in re.findall(r'^Add\(\{[^}]*\}, \{([^}]*)\}', module, re.MULTILINE):
    for alias in re.findall(r'"([^"]+)"', group):
        alias_count += 1
        for faction in ("Alliance", "Horde"):
            ids = list(lua.globals().ZurkMapsWSGIncoming.Parse("efc " + alias, faction).values())
            assert ids and set(ids) <= known, (alias, faction, ids)
for zone in list(zones.values()) + list(nested.values()):
    if not zone["drawPolygon"]:
        assert (root / "Media/Highlights" / (zone["id"] + ".tga")).is_file(), zone["id"]
toc = (root / "ZurkMaps.toc").read_text(encoding="utf-8-sig")
assert toc.index("ZurkMaps_WSGIncoming.lua") < toc.index("ZurkMaps_WSG.lua")
print("Lua 5.1 compilation, packaged area assets, and TOC order passed.")
print(f"All {alias_count} accepted aliases resolve to packaged regions for both factions.")
