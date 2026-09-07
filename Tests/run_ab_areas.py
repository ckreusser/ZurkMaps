"""Exercise the AB hotspot shadow and press/release renderer with Lua 5.1."""

from pathlib import Path
import runpy

from lupa.lua51 import LuaRuntime
from PIL import Image


root = Path(__file__).resolve().parents[1]
source = (root / "ZurkMaps_AB.lua").read_text(encoding="utf-8-sig")
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval("function(s,n) local f,e=loadstring(s,n); return f~=nil,e end")
ok, error = compile_lua(source, "ZurkMaps_AB.lua")
if not ok:
    raise AssertionError(error)

renderer = source[
    source.index("local AB_AREA_VISUAL = {") : source.index("local highlightTexture = CreateABHighlight()")
]
renderer = renderer.replace("local AB_AREA_VISUAL = {", "AB_AREA_VISUAL = {", 1)
renderer = renderer.replace("local function CreateABHighlight()", "function CreateABHighlight()", 1)

lua.execute(
    r'''
local Frame = {}
Frame.__index = Frame
function Frame:SetAllPoints(parent) self.allPoints = parent or self.parent end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:EnableMouse(enabled) self.mouseEnabled = enabled end
function Frame:CreateTexture()
    local texture = setmetatable({ parent = self, shown = true }, Frame)
    return texture
end
function Frame:CreateMaskTexture() return self:CreateTexture() end
function Frame:CreateLine() return self:CreateTexture() end
function Frame:SetVertexColor(...) self.vertexColor = {...} end
function Frame:SetColorTexture(...) self.color = {...} end
function Frame:Hide() self.shown = false end
function Frame:Show() self.shown = true end
function Frame:SetTexture(path) self.texturePath = path end
function Frame:AddMaskTexture(mask) self.mask = mask end
function Frame:SetBlendMode(mode) self.blendMode = mode end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:SetTexCoord(...) self.texCoord = {...} end
function Frame:SetThickness(thickness) self.thickness = thickness end
function Frame:SetStartPoint(...) self.startPoint = {...} end
function Frame:SetEndPoint(...) self.endPoint = {...} end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...} end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:GetWidth() return self.width or (self.parent and self.parent:GetWidth()) or 512 end
function Frame:GetHeight() return self.height or (self.parent and self.parent:GetHeight()) or 512 end
function Frame:SetScript(event, handler) self.scripts = self.scripts or {}; self.scripts[event] = handler end
function CreateFrame(_, _, parent)
    return setmetatable({ parent = parent, shown = true, points = {}, scripts = {} }, Frame)
end
map = setmetatable({ width = 512, height = 512, shown = true }, Frame)
BASE_NODE_BY_ID = { FARM = { id = "FARM", neutralTextureIndex = 31, currentTextureIndex = 31 } }
abTestMode = true
abTestBaseNodeStates = { FARM = 35 }
'''
)
lua.execute(renderer)
lua.execute(
    r'''
local overlay = CreateABHighlight()
overlay:SetZone({ id = "BLACKSMITH" })
assert(overlay.texture.texturePath:match("BLACKSMITH$"), "area texture selected")
assert(overlay.shadowTexture.texturePath == overlay.texture.texturePath, "shadow uses exact area geometry")

overlay:SetHoverInteraction(true)
overlay:Show()
assert(overlay.shadowTexture.shown, "hover shadow shown")
assert(math.abs(overlay.contentOffset) < 0.001, "hover remains level")

overlay:SetInteractionPressed(true)
assert(overlay.contentOffset > 1, "mouse-down presses area")
local anchoredShadow = overlay.contentOffset + overlay.shadowTexture.points[1][4]
assert(math.abs(anchoredShadow - AB_AREA_VISUAL.shadowOffset) < 0.001, "shadow remains map-anchored")

overlay:SetInteractionPressed(false)
overlay:UpdateInteractionAnimation(AB_AREA_VISUAL.releaseDuration)
assert(math.abs(overlay.contentOffset) < 0.001, "mouse-up returns quickly")
assert(overlay.shadowTexture.shown, "hover shadow remains after release")

overlay:SetInteractionPressed(true)
overlay:SetHoverInteraction(false)
assert(overlay.shadowTexture.shown, "fast pointer exit preserves release shadow")
overlay:UpdateInteractionAnimation(AB_AREA_VISUAL.releaseDuration / 2)
assert(overlay.shadowTexture.shown, "shadow remains during unfinished return")
overlay:UpdateInteractionAnimation(AB_AREA_VISUAL.releaseDuration / 2)
assert(not overlay.shadowTexture.shown, "shadow clears on the return completion frame")
assert(not overlay.shown, "released area clears with its shadow")

overlay:SetZone({
    id = "ROAD_ST_TO_LM",
    hitPaths = {{{24.2, 36.0}, {27.0, 46.8}, {23.4, 56.5}}},
})
overlay:SetHoverInteraction(true)
overlay:Show()
overlay:SetInteractionPressed(true)
overlay:SetInteractionPressed(false)
overlay:SetInteractionPressed(true)
assert(overlay.interactionPressed and not overlay.releaseActive, "rapid second press cancels prior release")
overlay:SetInteractionPressed(false)
overlay:UpdateInteractionAnimation(AB_AREA_VISUAL.releaseDuration)
assert(math.abs(overlay.contentOffset) < 0.001, "rapid click sequence settles level")

local stripeU = overlay.animatedStripeTexture.texCoord and overlay.animatedStripeTexture.texCoord[1]
overlay:SetAnimatedColor(0.12, 0.36, 1.00)
overlay:SetAnimatedActive(true)
assert(not overlay.texture.shown, "animated state replaces continuous hover artwork")
assert(overlay.animatedFillTexture.shown and overlay.animatedStripeTexture.shown, "animated fill and stripes shown")
assert(overlay.animatedMask.texturePath:match("ROAD_ST_TO_LM$"), "matching antialiased mask selected")
assert(overlay.animatedBorderCount >= 10, "segmented border built")
assert(overlay.shadowTexture.shown, "animated state has persistent shadow")
stripeU = overlay.animatedStripeTexture.texCoord[1]
local borderX = overlay.animatedBorderSegments[1].startPoint[3]
overlay:UpdateAnimatedAnimation(0.8)
assert(overlay.animatedStripeTexture.texCoord[1] ~= stripeU, "stripes advance")
assert(overlay.animatedBorderSegments[1].startPoint[3] ~= borderX, "segmented border rotates")
overlay:SetHoverInteraction(true)
overlay:SetInteractionPressed(true)
assert(overlay.contentOffset > 1, "contested area accepts button press")
overlay:SetInteractionPressed(false)
overlay:SetHoverInteraction(false)
overlay:UpdateInteractionAnimation(AB_AREA_VISUAL.releaseDuration)
assert(overlay.shadowTexture.shown, "contested shadow persists after release")
overlay:SetAnimatedActive(false)
assert(not overlay.shadowTexture.shown and not overlay.animatedStripeTexture.shown, "ending contest clears animation")

overlay:SetZone({ id = "FARM", isBase = true })
assert(overlay.texture.texturePath:match("Media\\Contested\\FARM$"), "controlled base uses tintable hover artwork")
assert(math.abs(overlay.texture.vertexColor[1] - AB_AREA_VISUAL.hordeColor[1]) < 0.001, "Horde-controlled hover is faction red")
abTestBaseNodeStates.FARM = 33
overlay:SetZone({ id = "FARM", isBase = true })
assert(math.abs(overlay.texture.vertexColor[3] - AB_AREA_VISUAL.allianceColor[3]) < 0.001, "Alliance-controlled hover is faction blue")

print("AB area interactions: shadow, press, menu-release, rapid-click, stripe, and segmented-border checks passed.")
'''
)

area_ids = {
    "STABLES", "GOLD_MINE", "LUMBER_MILL", "BLACKSMITH", "FARM",
    "BS_BRIDGE_ST", "BS_GY_WATER", "BS_LM_FARM_INTERSECTION", "BS_LM_WATER",
    "ROAD_ST_TO_LM", "ROAD_ST_TO_GM", "ROAD_ABOVE_GM", "ROAD_GM_TO_FARM", "ROAD_BELOW_LM",
}
for area_id in area_ids:
    artwork_path = root / "Media" / "Highlights" / f"{area_id}.tga"
    mask_path = root / "Media" / "CalloutMasks" / f"{area_id}.tga"
    assert artwork_path.is_file() and mask_path.is_file(), area_id
    with Image.open(artwork_path).convert("RGBA") as artwork:
        assert artwork.size == (512, 512), area_id
        assert sum(1 for count in artwork.getchannel("A").histogram() if count) > 32, f"{area_id} lacks antialiasing"
    with Image.open(mask_path).convert("RGBA") as mask:
        assert mask.size == (512, 512), area_id
        assert sum(1 for count in mask.getchannel("A").histogram() if count) > 32, f"{area_id} mask lacks antialiasing"

with Image.open(root / "Media" / "CalloutMasks" / "ROAD_GM_TO_FARM.tga").convert("RGBA") as fork_mask:
    fork_alpha = fork_mask.getchannel("A")
    fork_y = round(46.5 / 100 * 512)
    scanline = [fork_alpha.getpixel((x, fork_y)) for x in range(512)]
    opaque_runs = 0
    inside = False
    for alpha in scanline:
        if alpha >= 128 and not inside:
            opaque_runs += 1
            inside = True
        elif alpha < 128:
            inside = False
    assert opaque_runs == 2, "GM-to-Farm artwork must preserve both visible fork branches"

assert "visual.overlay:SetAnimatedActive(true)" in source
assert "visual.overlay:UpdateAnimatedAnimation" in source
assert "AnchorIncomingMenu(zone)" in source
assert 'incomingMenu:SetPoint("LEFT", incomingMenuAnchor, "RIGHT", 5, 0)' in source
assert 'GameTooltip:AddLine("Right-click: Call for HELP"' in source
assert 'GameTooltip:AddLine("Left-click: Report " .. GetBaseReportDescriptor(zone)' in source
assert 'GameTooltip:AddLine("Area menu: " .. GetBaseReportDescriptor(ZONE_BY_ID[baseNode.id])' in source
assert 'incomingMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")' in source
assert 'incomingMenuHeading:SetTextColor(1, 0.74, 0.18, 1)' in source
assert 'incomingMenuHeading:SetText(IsBaseHeldOrAssaultedByPlayerFaction(zone) and "INCOMING" or "VISIBLE")' in source
assert 'incomingMenuOpaqueBackground:SetVertexColor(0.018, 0.014, 0.010, 1)' in source
assert 'incomingMenuHeadingBackground:SetVertexColor(0.07, 0.045, 0.018, 1)' in source
assert 'incomingMenuHeading:SetText("VISIBLE")' in source
assert 'incomingMenu:SetAlpha(1)' in source
assert 'self:SetAlpha(0.58 + (0.42 * eased))' not in source
assert 'return { "1+", "2+", "3+", "4+", "5+", "6+", "7+", "Safe" }' in source
assert 'return { "1+", "2+", "3+", "4+", "5+", "6+", "7+", "Get OUT" }' in source
assert 'local rowCount = 4' in source
assert 'local INCOMING_OPTION_HEIGHT = 25' in source
assert 'local INCOMING_MENU_PADDING = 4' in source
assert 'columnGap = 1' in source and 'rowGap = 1' in source
assert 'headerGap = 4' in source
assert '(optionText == "Safe" or optionText == "Get OUT") and GameFontNormalSmall or GameFontNormal' in source
assert 'local function CloseIncomingMenu(preserveHoverAtCursor)' in source
assert 'if FindZone(x, y) == closingZone then' in source
assert 'ShowZoneTooltip(closingZone)' in source
assert 'CloseIncomingMenu(true)' in source
assert 'AdvanceABTestAgents(elapsed)' in source
assert 'abTestMovementElapsed < 0.05' not in source
assert 'ZurkMapsABRank.GetRankBadgeSize()' in source
assert 'getAddonFrame = function() return frame end' in source
assert 'function option:AnimatePressTo(target, duration, onFinished)' in source
assert 'option.face = CreateFrame("Button", nil, option, "UIPanelButtonTemplate")' in source
assert 'option.label = option.face:CreateFontString(nil, "OVERLAY", "GameFontNormal")' in source
assert 'option.label = option.face:GetFontString()' not in source
assert 'self.face:LockHighlight()' in source
assert 'self.face:SetButtonState(depth >= (INCOMING_BUTTON_STYLE.pressDepth * 0.42) and "PUSHED" or "NORMAL")' in source
assert 'self:AnimatePressTo(INCOMING_BUTTON_STYLE.pressDepth, INCOMING_BUTTON_STYLE.downSeconds)' in source
assert 'self:AnimatePressTo(0, INCOMING_BUTTON_STYLE.upSeconds, function()' in source
incoming_click = source[
    source.index('for i = 1, INCOMING_MENU_MAX_OPTIONS do'):
    source.index('    incomingMenuOptions[i] = option')
]
assert 'if self.reportPending then return end' in incoming_click
assert incoming_click.index('Report(message)') < incoming_click.index(
    'self:AnimatePressTo(0, INCOMING_BUTTON_STYLE.upSeconds, function()'
)
release_callback = incoming_click[
    incoming_click.index('self:AnimatePressTo(0, INCOMING_BUTTON_STYLE.upSeconds, function()'):
]
assert 'Report(message)' not in release_callback

build_source = (root / "Media" / "BuildABHighlights.py").read_text(encoding="utf-8")
assert '"BS_BRIDGE_ST": BRIDGE_COLOR' in build_source
assert '"BS_LM_FARM_INTERSECTION": BRIDGE_COLOR' in build_source
assert '"BS_GY_WATER": WATER_COLOR' in build_source
assert '"BS_LM_WATER": WATER_COLOR' in build_source

build_data = runpy.run_path(str(root / "Media" / "BuildABHighlights.py"))

def side(a, b, point):
    return ((b[0] - a[0]) * (point[1] - a[1])) - ((b[1] - a[1]) * (point[0] - a[0]))

for road_name, outline in build_data["ROAD_OUTLINES"].items():
    edges = list(zip(outline, outline[1:] + outline[:1]))
    for first_index, (a, b) in enumerate(edges):
        for second_index, (c, d) in enumerate(edges):
            if second_index <= first_index + 1 or (first_index == 0 and second_index == len(edges) - 1):
                continue
            crosses = side(a, b, c) * side(a, b, d) < 0 and side(c, d, a) * side(c, d, b) < 0
            assert not crosses, f"{road_name} contains overlapping boundary segments"
print("All 14 AB hotspots have rebuilt artwork and animation masks.")
