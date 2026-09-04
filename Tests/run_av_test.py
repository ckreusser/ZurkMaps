"""Run real AV simulation, renderer integration, objective timers and lifecycle."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "ZurkMaps_AV.lua").read_text(encoding="utf-8-sig")
simulation = (root / "ZurkMaps_AVTest.lua").read_text(encoding="utf-8-sig")
npc_source = (root / "ZurkMaps_AVLieutenants.lua").read_text(encoding="utf-8-sig")
npcs = npc_source[npc_source.index("local LIEUTENANTS = {"):npc_source.index("local BY_ID, BY_NAME")]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval("function(s,n) local f,e=loadstring(s,n); return f~=nil,e end")
for name in ("ZurkMaps_AV.lua", "ZurkMaps_AVTest.lua", "ZurkMaps_AVLieutenants.lua"):
    ok, error = compile_lua((root / name).read_text(encoding="utf-8-sig"), name)
    assert ok, error
definitions = source[source.index("local OBJECTIVES = {"):source.index("local function IsInAlteracValley()")]
lua.execute(definitions + "\nTEST_OBJECTIVES=OBJECTIVES")
lua.execute(npcs + "\nTEST_NPCS=LIEUTENANTS")
lua.execute(simulation)
lua.execute((root / "Tests/av_test_spec.lua").read_text(encoding="utf-8-sig"))

toc = (root / "ZurkMaps.toc").read_text(encoding="utf-8-sig")
assert toc.index("ZurkMaps_AVTest.lua") < toc.index("ZurkMaps_AV.lua")

# Keep functions in their real shared lexical scope while replacing unrelated
# map artwork, live roster APIs and chat/UI entry points with small mocks.
ui = LuaRuntime(unpack_returned_tuples=True)
ui.execute((root / "Tests/av_test_ui_mock.lua").read_text(encoding="utf-8-sig"))
ui.execute(npc_source)
ui.execute(simulation)
ui.execute((root / "ZurkMaps_PlayerBlips.lua").read_text(encoding="utf-8-sig"))
ui.execute((root / "ZurkMaps_AVTimers.lua").read_text(encoding="utf-8-sig"))

def section(start, end):
    i = source.index(start)
    return source[i:source.index(end, i)]

program = definitions + "\n" + (root / "Tests/av_test_ui_setup.lua").read_text(encoding="utf-8-sig")
program += section("local AV_TEST_NAMES = {", "local function GetMapMousePercent()")
program += section("local function SetTestMode(flag)", 'map:SetScript("OnMouseUp"')
program += section("if ZurkMapsAVTimers and ZurkMapsAVTimers.Create then", 'local refreshFrame=CreateFrame')
program += section("local wasInAVForObjectives=false", "\nif ZurkMapsOptions then")
program += (root / "Tests/av_test_ui_spec.lua").read_text(encoding="utf-8-sig")
ui.execute(program)
