"""Run the real parser, highlight renderer, and event lifecycle with Lua 5.1."""
from pathlib import Path
import re
from lupa.lua51 import LuaRuntime
from PIL import Image

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
renderer = wsg[wsg.index("ZurkMapsWSGIncoming.Visual = {"):wsg.index("local highlightTexture = CreateWSGHighlight()")]
lua.execute("local MAP_WIDTH = 330\n" + renderer.replace("local function CreateWSGHighlight()", "function CreateWSGHighlight()", 1))
lua.execute((root / "Tests/wsg_incoming_spec.lua").read_text(encoding="utf-8-sig"))

health_lua = LuaRuntime(unpack_returned_tuples=True)
health_lua.execute((root / "Tests/wsg_health_coordination_spec.lua").read_text(encoding="utf-8-sig"))
health_block = wsg[wsg.index("-- Automatic EFC health callouts"):wsg.index("local function GetCarrierAssignments()")]
health_lua.execute(health_block)
health_lua.globals().RunWSGHealthCoordinationTests()

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
    highlight_path = root / "Media/Highlights" / (zone["id"] + ".tga")
    assert highlight_path.is_file(), zone["id"]
    with Image.open(highlight_path).convert("RGBA") as artwork:
        assert all(pixel[:3] == (255, 255, 255) for pixel in artwork.get_flattened_data() if pixel[3]), zone["id"]
    assert (root / "Media/CalloutMasks" / (zone["id"] + ".tga")).is_file(), zone["id"]
assert (root / "Media/CalloutStripes.tga").is_file()
options = (root / "ZurkMaps_Options.lua").read_text(encoding="utf-8-sig")
assert 'CreateValueRow(frame, "Auto EFC Health")' in options
assert "getAutoEFCHealthEnabled" in wsg and "setAutoEFCHealthEnabled" in wsg
assert "ZurkMapsWSGTestSim.Advance(elapsed)" in wsg
assert "ZurkMapsWSGTestSim.movementElapsed < 0.05" not in wsg
assert "ZurkMapsWSGRank.GetRankBadgeSize()" in wsg
assert "local MOVE_HANDLE_HEIGHT = 22" in wsg
assert "local MOVE_HANDLE_FONT_SIZE = 11" in wsg
assert "getAddonFrame = function() return frame end" in wsg
assert "local endExtension = math.max(0, filigreeWidth - filigreeOverlap)" in wsg
assert "(map:GetWidth() or MAP_WIDTH) - (2 * endExtension)" in wsg
assert wsg.count('if id:match("^ALLY_") then return 0.12, 0.36, 1.00 end') == 2
assert wsg.count('if id:match("^HORDE_") then return 1.00, 0.20, 0.16 end') == 2
assert "self.texture:SetVertexColor(r, g, b, 1)" in wsg
assert "getAutoEFCHealthEnabled" not in (root / "ZurkMaps_AB.lua").read_text(encoding="utf-8-sig")
assert "getAutoEFCHealthEnabled" not in (root / "ZurkMaps_AV.lua").read_text(encoding="utf-8-sig")
assert "for i = 1, 8 do\n    local optionText = tostring(i) .. \"+\"" in wsg
assert "local row = math.floor((i - 1) / 2)" in wsg
assert "local column = (i - 1) % 2" in wsg
assert 'turtleMenuHeading:SetText("WITH EFC")' in wsg
assert "optionHeight = 25" in wsg and "padding = 4" in wsg
assert "columnGap = 1" in wsg and "rowGap = 1" in wsg
assert "headerGap = 4" in wsg
assert "function option:AnimatePressTo(target, duration, onFinished)" in wsg
assert 'option.face = CreateFrame("Button", nil, option, "UIPanelButtonTemplate")' in wsg
assert 'option.label = option.face:CreateFontString(nil, "OVERLAY", "GameFontNormal")' in wsg
assert "self.face:LockHighlight()" in wsg
assert 'self.face:SetButtonState(depth >= (TURTLE_MENU_STYLE.pressDepth * 0.42) and "PUSHED" or "NORMAL")' in wsg
assert "self:AnimatePressTo(TURTLE_MENU_STYLE.pressDepth, TURTLE_MENU_STYLE.downSeconds)" in wsg
assert "self:AnimatePressTo(0, TURTLE_MENU_STYLE.upSeconds, function()" in wsg
turtle_click = wsg[
    wsg.index('for i = 1, 8 do\n    local optionText = tostring(i) .. "+"'):
    wsg.index('turtleButton:SetScript("OnEnter"')
]
assert 'if self.reportPending then return end' in turtle_click
assert turtle_click.index("Report(message)") < turtle_click.index(
    "self:AnimatePressTo(0, TURTLE_MENU_STYLE.upSeconds, function()"
)
release_callback = turtle_click[
    turtle_click.index("self:AnimatePressTo(0, TURTLE_MENU_STYLE.upSeconds, function()"):
]
assert "Report(message)" not in release_callback
assert 'visible with the EFC"' in turtle_click
toc = (root / "ZurkMaps.toc").read_text(encoding="utf-8-sig")
assert toc.index("ZurkMaps_WSGIncoming.lua") < toc.index("ZurkMaps_WSG.lua")
print("Lua 5.1 compilation, antialiased area assets, masks, and TOC order passed.")
print(f"All {alias_count} accepted aliases resolve to packaged regions for both factions.")
