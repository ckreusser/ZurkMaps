-- Run through run_wsg_incoming.py (Lua 5.1 via lupa), or load the module and
-- CreateWSGHighlight factory before this file in a standalone Lua 5.1 runner.
local Incoming = ZurkMapsWSGIncoming
local checks = 0
local function Equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function IDs(ids)
    local copy = {}
    for _, id in ipairs(ids) do copy[#copy + 1] = id end
    table.sort(copy)
    return table.concat(copy, ",")
end
local function Parse(message, expected, faction)
    Equal(IDs(Incoming.Parse(message, faction or "Horde")), IDs(expected), message .. " [" .. (faction or "Horde") .. "]")
end
local function Both(area) return {"ALLY_" .. area, "HORDE_" .. area} end

Parse("EFC TUN", Both("TUNNEL"))
Parse("tun", Both("TUNNEL"))
Parse("EFC is at ALLY FLAG ROOM!", {"ALLY_FLAG_ROOM"})
Parse("enemy flag carrier is in the horde flagroom", {"HORDE_FLAG_ROOM"})
Parse("EFC our ramp", {"HORDE_RAMP"})
Parse("EFC our ramp", {"ALLY_RAMP"}, "Alliance")
Parse("EFC their ramp", {"ALLY_RAMP"})
Parse("EFC their ramp", {"HORDE_RAMP"}, "Alliance")
Parse("EFC ally roof", {"ALLY_ROOF"})
Parse("EFC north roof", {"ALLY_ROOF"})
Parse("EFC south roof", {"HORDE_ROOF"})
Parse("EFC roof horde", {"HORDE_ROOF"})
Parse("efc at enemy's tunnel", {"ALLY_TUNNEL"})
Parse("efr", {"ALLY_FLAG_ROOM"})
Parse("efr", {"HORDE_FLAG_ROOM"}, "Alliance")
Parse("EFC eTun", {"ALLY_TUNNEL"})
Parse("EFC EGY", {"ALLY_GRAVEYARD"})
Parse("EFC eRoOf", {"ALLY_ROOF"})
Parse("E roof", {"ALLY_ROOF"})
Parse("roof e", {"ALLY_ROOF"})
Parse("roof or gy e", {"ALLY_ROOF", "ALLY_GRAVEYARD"})
Parse("e roof", {"HORDE_ROOF"}, "Alliance")
Parse("e banana", {"ALLY_BANANA"})
Parse("ebanana", {"ALLY_BANANA"})
Parse("etop of tunnel", {"ALLY_TOP_OF_TUNNEL"})
Parse("efc their fc", {})
Parse("their fc roof", Both("ROOF")) -- the subject does not imply its current base
Parse("EFC roof or gy", {"ALLY_ROOF", "HORDE_ROOF", "ALLY_GRAVEYARD", "HORDE_GRAVEYARD"})
Parse("EFC our tunnel or their ramp", {"HORDE_TUNNEL", "ALLY_RAMP"})
Parse("EFC our tunnel or roof", {"HORDE_TUNNEL", "HORDE_ROOF"})
Parse("EFC our roof; their gy", {"HORDE_ROOF", "ALLY_GRAVEYARD"})
Parse("EFC roof horde ramp", {"ALLY_ROOF", "HORDE_ROOF", "HORDE_RAMP"})
Parse("EFC our roof or ally roof", Both("ROOF"))
Parse("efc ally or horde roof", Both("ROOF"))
Parse("efc our tunnel", Both("TUNNEL"), "Neutral")
Parse("efc etun", Both("TUNNEL"), "Neutral")
Parse("EFC top of tunnel", Both("TOP_OF_TUNNEL"))
Parse("EFC on top of the tunnel", Both("TOP_OF_TUNNEL"))
Parse("EFC tunnel top", Both("TOP_OF_TUNNEL"))
Parse("EFC ToT", Both("TOP_OF_TUNNEL"))
Parse("EFC roof ramp", Both("BANANA"))
Parse("EFC banana", Both("BANANA"))
Parse("EFC boots", Both("TUNNEL"))
Parse("EFC speed buff", Both("TUNNEL"))
Parse("EFC has speed", {})
Parse("EFC used the boots at roof", Both("ROOF"))
Parse("EFC has leaf in tunnel", Both("TUNNEL"))
Parse("EFC leaf", Both("LEAF_HUT"))
Parse("EFC resto hut", Both("LEAF_HUT"))
Parse("EFC berserker hut", Both("ZERK_HUT"))
Parse("EFC on 2", Both("SECOND_FLOOR"))
Parse("EFC 2nd floor", Both("SECOND_FLOOR"))
Parse("EFC 2", Both("SECOND_FLOOR"))
Parse("EFC 2 healers roof", Both("ROOF"))
Parse("EFC 3 escorts tunnel", Both("TUNNEL"))
Parse("2", {})
Parse("EFC balcony", Both("SECOND_FLOOR"))
Parse("EFC connector", Both("SECOND_FLOOR"))
Parse("EFC window room", Both("FLAG_ROOM"))
Parse("EFC horde lobby", {"HORDE_FLAG_ROOM", "HORDE_SECOND_FLOOR"})
Parse("EFC mid", {"MID_WEST", "MID", "MID_EAST"})
Parse("EFC mid west", {"MID_WEST"})
Parse("EFC middle east", {"MID_EAST"})
Parse("EFC center mid", {"MID"})
Parse("EFC left mid", {"MID_WEST", "MID_EAST"})
Parse("EFC hut", {"ALLY_LEAF_HUT", "ALLY_ZERK_HUT", "HORDE_LEAF_HUT", "HORDE_ZERK_HUT"})
Parse("EFC our hut", {"HORDE_LEAF_HUT", "HORDE_ZERK_HUT"})
Parse("EFC construction", {"MID_EAST", "HORDE_LEAF_HUT", "HORDE_TOPSIDE"})
Parse("EFC east crane", {"MID_EAST"})
Parse("EFC leaf hut construction", {"HORDE_LEAF_HUT"})
Parse("EFC sawmill", {"HORDE_TOPSIDE"})
Parse("EFC shrine", {"ALLY_ROOF", "ALLY_BANANA"})
Parse("EFC our gy side", {"HORDE_GRAVEYARD", "HORDE_LEAF_HUT", "MID_EAST"})
Parse("EFC our gy side", {"ALLY_GRAVEYARD", "ALLY_LEAF_HUT", "MID_WEST"}, "Alliance")
Parse("EFC our ramp side", {"HORDE_RAMP", "HORDE_ZERK_HUT", "MID_WEST"})
Parse("EFC our ramp side", {"ALLY_RAMP", "ALLY_ZERK_HUT", "MID_EAST"}, "Alliance")
Parse("EFC at |cffff0000HORDE ROOF|r!", {"HORDE_ROOF"})
Parse("EFC tunnel tunnel tunnel", Both("TUNNEL"))
Parse("I love banana bread", {})
Parse("these boots look great", {})
Parse("leaf me alone", {})
Parse("tunnelvision", {})
Parse("roofing", {})
Parse("Where is EFC?", {})
Parse("where efc roof", {})
Parse("is efc roof", {})
Parse("can anyone see efc tunnel", {})
Parse("efc roof?", {})
Parse("fc roof", {})
Parse("our fc tunnel", {})
Parse("friendly flag carrier roof", {})
Parse("fc roof, efc tunnel", Both("TUNNEL"))
Parse("EFC roof, our fc tunnel", Both("ROOF"))
Parse("EFC not tunnel", {})
Parse("EFC isn't at roof", {})
Parse("EFC not roof or tunnel", {})
Parse("EFC not roof but tunnel", Both("TUNNEL"))
Parse("EFC roof, not tunnel", Both("ROOF"))
Parse("EFC dead at roof", {})
Parse("EFC roof dead", {})
Parse("EFC returned from tunnel", {})
Parse("Selling |Hitem:123|h[Boots]|h", {})
Parse("efc |Hitem:123|h[Boots]|h", {})
Parse("", {})
Parse(string.rep("efc roof ", 200), {})
Equal(#Incoming.Parse(nil, "Horde"), 0, "nil input")

-- Strict UI doubles: unsupported calls fail instead of vanishing into a stub.
local clock, faction, targetGUID, targetFriend, cachedRace = 100, "Horde", nil, false, nil
local instanceType, instanceID = "none", 0
function GetInstanceInfo() return "Localized instance name", instanceType, 0, "", 0, 0, false, instanceID end
function GetTime() return clock end
function UnitFactionGroup() return faction end
function UnitGUID(unit) if unit == "player" then return "Player-1-self" elseif unit == "target" then return targetGUID end end
function UnitIsFriend() return targetFriend end
function IsInRaid() return false end
function GetPlayerInfoByGUID() return nil, nil, nil, cachedRace end
local Frame = {}
Frame.__index = Frame
function Frame:SetAllPoints(parent) self.allPoints = parent or self.parent end
function Frame:SetPoint(...) self.point = {...} end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth() return self.width or (self.allPoints and self.allPoints:GetWidth()) or 334 end
function Frame:GetHeight() return self.height or (self.allPoints and self.allPoints:GetHeight()) or 444 end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:EnableMouse(enabled) self.mouse = enabled end
function Frame:Hide()
    local shown = self.shown
    self.shown = false
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:Show() self.shown = true end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetScript(event, handler) self.scripts[event] = handler end
function Frame:HookScript(event, handler)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; handler(...) end
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:SetColorTexture(...) self.color = {...} end
function Frame:SetTexture(texture) self.texturePath = texture end
function Frame:AddMaskTexture(mask)
    self.masks = self.masks or {}
    self.masks[#self.masks + 1] = mask
end
function Frame:SetBlendMode(mode) self.blendMode = mode end
function Frame:SetVertexColor(...) self.vertexColor = {...} end
function Frame:SetTexCoord(...) self.texCoord = {...} end
function Frame:SetTextColor(...) self.textColor = {...} end
function Frame:SetFont(...) self.font = {...} end
function Frame:SetJustifyH(justify) self.justifyH = justify end
function Frame:SetBackdrop(backdrop) self.backdrop = backdrop end
function Frame:GetBackdrop() return self.backdrop end
function Frame:SetBackdropColor(...) self.backdropColor = {...} end
function Frame:GetBackdropColor() return unpack(self.backdropColor or {0.035, 0.022, 0.014, 0.94}) end
function Frame:SetBackdropBorderColor(...) self.backdropBorderColor = {...} end
function Frame:GetBackdropBorderColor() return unpack(self.backdropBorderColor or {0.84, 0.56, 0.31, 0.98}) end
function Frame:SetText(text) self.text = text end
function Frame:SetWordWrap(wrap) self.wrap = wrap end
function Frame:SetThickness(thickness) self.thickness = thickness end
function Frame:SetStartPoint(...) self.startPoint = {...} end
function Frame:SetEndPoint(...) self.endPoint = {...} end
function CreateFrame(_, _, parent)
    return setmetatable({shown = true, parent = parent, scripts = {}, events = {}}, Frame)
end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:CreateMaskTexture() return CreateFrame("MaskTexture", nil, self) end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
function Frame:CreateLine() return CreateFrame("Line", nil, self) end

Equal(Incoming.IsFriendlySender("Player-1-self"), true, "self test")
Equal(Incoming.IsFriendlySender("Creature-1-self"), false, "NPC")
Equal(Incoming.IsFriendlySender(nil), false, "no GUID")
cachedRace = "Orc"
Equal(Incoming.IsFriendlySender("Player-1-friend"), true, "ungrouped Horde sender")
cachedRace = "Human"
Equal(Incoming.IsFriendlySender("Player-1-enemy"), false, "opposing sender")
faction = "Alliance"
Equal(Incoming.IsFriendlySender("Player-1-friend"), true, "ungrouped Alliance sender")
cachedRace = nil
Equal(Incoming.IsFriendlySender("Player-1-unknown"), false, "unresolved sender")
targetGUID, targetFriend = "Player-1-target", true
Equal(Incoming.IsFriendlySender(targetGUID), true, "friendly unit without cached race")
targetFriend, cachedRace = false, "Human"
Equal(Incoming.IsFriendlySender(targetGUID), false, "hostile unit beats race fallback")
faction, cachedRace = "Horde", "Orc"
ZurksWSGCalloutMapDB = {}
map = CreateFrame("Frame")
local allyTunnelZone, allyTopTunnelZone
for _, zone in ipairs(TEST_ZONES) do
    if zone.id == "ALLY_TUNNEL" then allyTunnelZone = zone end
end
for _, zone in ipairs(TEST_NESTED_ZONES) do
    if zone.id == "ALLY_TOP_OF_TUNNEL" then allyTopTunnelZone = zone end
end
local allyTunnelVisualPoints = Incoming.GetVisualZonePoints(allyTunnelZone)
local allyTopTunnelVisualPoints = Incoming.GetVisualZonePoints(allyTopTunnelZone)
assert(math.abs((allyTunnelVisualPoints[1][1] - allyTunnelZone.points[1][1]) - Incoming.Visual.allianceNudgePercent) < 0.001, "Alliance areas move five map pixels right")
assert(math.abs(allyTopTunnelVisualPoints[1][1] - (allyTopTunnelZone.cx + allyTopTunnelZone.rx)) < 0.001, "Alliance Top of Tunnel stays in place")
checks = checks + 2
local actionRow = CreateFrame("Frame")
local controller = Incoming.Create(map, TEST_ZONES, TEST_NESTED_ZONES, CreateWSGHighlight, actionRow)
Equal(controller.listener.events.CHAT_MSG_SAY, true, "say registered")
Equal(controller.listener.events.CHAT_MSG_PARTY, nil, "no party listener")
Equal(controller.listener.events.CHAT_MSG_INSTANCE_CHAT, true, "BG chat registered")
Equal(controller.listener.events.CHAT_MSG_INSTANCE_CHAT_LEADER, true, "BG leader chat registered")
local function Say(message, guid)
    controller.listener.scripts.OnEvent(controller.listener, "CHAT_MSG_SAY", message, "Tester-Realm", "Orcish", "", "", "", 0, 0, "", 0, 42, guid or "Player-1-self", 0, false, false)
end
Say("efc tun")
Equal(IDs(controller.activeIDs), IDs(Both("TUNNEL")), "real event arg12")
Equal(controller.expiresAt, 108, "eight-second expiry")
Equal(controller.overlays.ALLY_TUNNEL.texture.texturePath, "Interface\\AddOns\\ZurkMaps\\Media\\Highlights\\ALLY_TUNNEL", "reuse real highlight artwork")
Equal(controller.overlays.ALLY_TUNNEL.mouse, false, "click through")
local firstOverlay = controller.overlays.ALLY_TUNNEL
Equal(firstOverlay.calloutActive, true, "callout animation enabled")
assert((firstOverlay.calloutFillCount or 0) > 0, "callout interior drawn without solid outline")
assert((firstOverlay.calloutStripeCount or 0) > 0, "callout stripes drawn")
assert((firstOverlay.calloutBorderCount or 0) >= 16, "segmented border drawn")
Equal(firstOverlay.texture.shown, false, "continuous callout border hidden")
Equal(firstOverlay.calloutMask.texturePath, "Interface\\AddOns\\ZurkMaps\\Media\\CalloutMasks\\ALLY_TUNNEL", "antialiased callout mask selected")
Equal(firstOverlay.calloutFillTexture.masks[1], firstOverlay.calloutMask, "callout fill is masked")
Equal(firstOverlay.calloutStripeTexture.masks[1], firstOverlay.calloutMask, "callout stripes are masked")
local firstStripeU = firstOverlay.calloutStripeTexture.texCoord[1]
local firstBorderX = firstOverlay.calloutBorderSegments[1].startPoint[3]
Equal(firstOverlay.calloutBorderSegments[1].alpha, firstOverlay.calloutBorderSegments[2].alpha, "uniform segmented border")
Equal(firstOverlay.shadowMode, "CALLOUT", "callout drop shadow enabled")
Equal(controller:SetAreaInteraction("ALLY_TUNNEL", true, false), true, "active callout accepts hover interaction")
firstOverlay:UpdateInteractionAnimation(1)
local calloutRaisedOffset = firstOverlay.contentOffset
assert(math.abs(calloutRaisedOffset) < 0.01, "active callout stays level on hover")
controller:SetAreaInteraction("ALLY_TUNNEL", true, true)
firstOverlay:UpdateInteractionAnimation(1)
assert(firstOverlay.contentOffset > 1, "active callout area presses toward shadow")
controller:SetAreaInteraction("ALLY_TUNNEL", true, false)
firstOverlay:UpdateInteractionAnimation(1)
assert(math.abs(firstOverlay.contentOffset) < 0.01, "active callout snaps level on release")
controller:SetAreaInteraction(nil, false, false)
firstOverlay:UpdateInteractionAnimation(1)
assert(math.abs(firstOverlay.contentOffset) < 0.01, "active callout settles after hover")
controller:SetAreaInteraction("ALLY_TUNNEL", true, true)
firstOverlay:UpdateInteractionAnimation(0.05)
controller:SetAreaInteraction(nil, false, false)
firstOverlay:UpdateInteractionAnimation(0.05)
Equal(firstOverlay.shadowMode, "CALLOUT", "leaving directly from mouse-down preserves callout shadow mode")
Equal(firstOverlay.shadowTexture.shown, true, "leaving directly from mouse-down preserves callout shadow")
checks = checks + 9
clock = 100.6
controller.driver.scripts.OnUpdate()
assert(controller.overlays.ALLY_TUNNEL.calloutPulseAlpha < 0.25, "callout artwork reaches pulse trough")
Equal(controller.overlays.ALLY_TUNNEL.alpha, 1, "callout frame stays opaque for persistent shadow")
Equal(controller.overlays.ALLY_TUNNEL.shadowTexture.shown, true, "fast hover exit keeps callout shadow visible")
Equal(controller.overlays.ALLY_TUNNEL.shadowTexture.vertexColor[4], Incoming.Visual.shadowAlpha, "callout shadow ignores pulse trough")
assert(firstOverlay.calloutStripeTexture.texCoord[1] ~= firstStripeU, "callout stripes advance")
assert(firstOverlay.calloutBorderSegments[1].startPoint[3] ~= firstBorderX, "segmented border rotates")
Equal(firstOverlay.calloutBorderSegments[1].alpha, firstOverlay.calloutBorderSegments[2].alpha, "rotating dashes stay uniform")
checks = checks + 3
Say("efc our ramp")
Equal(IDs(controller.activeIDs), "HORDE_RAMP", "replace previous report")
Equal(firstOverlay.shown, false, "old region hidden")
Equal(firstOverlay.calloutActive, false, "old region animation stopped")
Equal(controller.overlays.HORDE_RAMP.texture.shown, false, "continuous ramp border hidden during callout")
Equal(controller.overlays.HORDE_RAMP.texture.texturePath, "Interface\\AddOns\\ZurkMaps\\Media\\Highlights\\HORDE_RAMP", "ramp uses regenerated artwork")
Equal(controller.overlays.HORDE_RAMP.calloutMask.texturePath, "Interface\\AddOns\\ZurkMaps\\Media\\CalloutMasks\\HORDE_RAMP", "ramp uses matching callout mask")
Equal(controller.overlays.HORDE_RAMP.shadowTexture.texturePath, controller.overlays.HORDE_RAMP.texture.texturePath, "ramp shadow shares hover geometry")
Equal(controller.overlays.HORDE_RAMP.shadowTexture.shown, true, "ramp drop shadow shown")
checks = checks + 1
Say("where efc?")
Equal(IDs(controller.activeIDs), "HORDE_RAMP", "question does not replace valid report")
Say("efc roof", "Creature-1-enemy")
Equal(IDs(controller.activeIDs), "HORDE_RAMP", "reject NPC event")
Say("efc tun")
Equal(controller.overlays.ALLY_TUNNEL, firstOverlay, "reuse frame pool")
clock = controller.expiresAt - Incoming.FADE_DURATION - 0.01
controller.driver.scripts.OnUpdate()
Equal(firstOverlay.calloutExpiryAlpha, 1, "terminal fade does not begin early")
clock = controller.expiresAt - (Incoming.FADE_DURATION / 2)
controller.driver.scripts.OnUpdate()
assert(firstOverlay.calloutPulseAlpha <= 0.5, "short terminal fade")
assert(math.abs(firstOverlay.calloutExpiryAlpha - 0.5) < 0.001, "expiry fade is separate from pulse")
assert(math.abs(firstOverlay.shadowTexture.vertexColor[4] - (Incoming.Visual.shadowAlpha * 0.5)) < 0.001, "shadow follows expiry fade")
clock = controller.expiresAt - 0.01
controller.driver.scripts.OnUpdate()
assert(firstOverlay.shadowTexture.vertexColor[4] < 0.01, "shadow is effectively gone before expiry completes")
checks = checks + 5
clock = controller.expiresAt
controller.driver.scripts.OnUpdate()
Equal(#controller.activeIDs, 0, "expired regions cleared")
Equal(controller.driver.shown, false, "idle updater stopped")
Equal(firstOverlay.calloutActive, false, "expired animation stopped")
Equal(firstOverlay.shadowTexture.shown, false, "expired animation clears shadow immediately")
Say("efc tot")
Equal(IDs(controller.activeIDs), IDs(Both("TOP_OF_TUNNEL")), "nested region render")
map:Hide()
Equal(#controller.activeIDs, 0, "hide clears reports")
Say("efc roof")
Equal(#controller.activeIDs, 0, "hidden map ignores reports")
map:Show()
Equal(#controller.activeIDs, 0, "reopen has no stale report")
Say("efc roof")
controller.listener.scripts.OnEvent(controller.listener, "PLAYER_ENTERING_WORLD")
Equal(#controller.activeIDs, 0, "world transition clears reports")
ZurksWSGCalloutMapDB.incomingCallouts = false
Say("efc roof")
Equal(#controller.activeIDs, 0, "saved off setting")
ZurksWSGCalloutMapDB.incomingCallouts = true
Say("efc roof")
Equal(#controller.activeIDs, 2, "re-enabled")
controller:Clear()

local hoverOverlay = CreateWSGHighlight()
hoverOverlay:SetZone(TEST_ZONES[1])
hoverOverlay:SetHoverInteraction(true)
hoverOverlay:UpdateInteractionAnimation(1)
local raisedOffset = hoverOverlay.contentOffset
local anchoredShadow = raisedOffset + hoverOverlay.shadowTexture.point[4]
assert(hoverOverlay.shadowTexture.shown and math.abs(raisedOffset) < 0.01, "hover keeps area level")
assert(anchoredShadow < 2.2, "hover shadow tightened")
hoverOverlay:SetInteractionPressed(true)
assert(hoverOverlay.contentOffset > 1, "fast mouse-down applies before the next animation frame")
hoverOverlay:UpdateInteractionAnimation(1)
local pressedOffset = hoverOverlay.contentOffset
assert(pressedOffset > 1, "mouse down moves area toward shadow")
assert(math.abs((pressedOffset + hoverOverlay.shadowTexture.point[4]) - anchoredShadow) < 0.01, "shadow remains anchored while area moves")
hoverOverlay:SetInteractionPressed(false)
hoverOverlay:UpdateInteractionAnimation(0.01)
assert(hoverOverlay.contentOffset > 0.02, "mouse-up return remains in progress")
hoverOverlay:SetHoverInteraction(false)
Equal(hoverOverlay:IsFinishingHoverRelease(), true, "fast pointer exit preserves release animation")
Equal(hoverOverlay.shadowTexture.shown, true, "fast pointer exit preserves release shadow")
hoverOverlay:UpdateInteractionAnimation(0.01)
Equal(hoverOverlay.shadowTexture.shown, true, "release shadow stays through unfinished return")
hoverOverlay:UpdateInteractionAnimation(1)
assert(math.abs(hoverOverlay.contentOffset) < 0.01, "mouse-up snaps area level")
Equal(hoverOverlay.shadowTexture.shown, false, "release completion clears hover shadow immediately")
Equal(hoverOverlay.shown, false, "release completion clears hover artwork immediately")
hoverOverlay:Show()
hoverOverlay:SetHoverInteraction(true)
hoverOverlay:SetInteractionPressed(true)
hoverOverlay:SetInteractionPressed(false)
hoverOverlay:UpdateInteractionAnimation(0.02)
hoverOverlay:SetInteractionPressed(true)
assert(hoverOverlay.contentOffset > 1 and not hoverOverlay.releaseActive, "second fast press replaces unfinished release")
hoverOverlay:SetInteractionPressed(false)
hoverOverlay:UpdateInteractionAnimation(Incoming.Visual.releaseDuration)
assert(math.abs(hoverOverlay.contentOffset) < 0.001 and not hoverOverlay.releaseActive, "fast repeated click finishes on exact release duration")
checks = checks + 12

-- /bg uses instance chat for ordinary teammates and the battleground leader.
local function Battleground(message, leader, guid)
    local event = leader and "CHAT_MSG_INSTANCE_CHAT_LEADER" or "CHAT_MSG_INSTANCE_CHAT"
    controller.listener.scripts.OnEvent(controller.listener, event, message, "Teammate-Realm", "Orcish", "", "", "", 0, 0, "", 0, 43, guid or "Player-1-teammate", 0, false, false)
end
Battleground("efc roof")
Equal(#controller.activeIDs, 0, "BG chat outside WSG ignored")
instanceType, instanceID = "pvp", 529
Battleground("efc roof", true)
Equal(#controller.activeIDs, 0, "AB leader chat ignored with WSG map visible")
instanceID = 30
Battleground("efc roof")
Equal(#controller.activeIDs, 0, "AV chat ignored")
instanceType, instanceID = "party", 489
Battleground("efc roof")
Equal(#controller.activeIDs, 0, "requires an actual battleground")
instanceType, instanceID, cachedRace = "pvp", 489, nil
Battleground("efc our ramp")
Equal(IDs(controller.activeIDs), "HORDE_RAMP", "uncached distant teammate in WSG accepted")
Equal(controller.lastAuthor, "Teammate-Realm", "BG caller retained")
clock = clock + 2
Battleground("efc their roof", true)
Equal(IDs(controller.activeIDs), "ALLY_ROOF", "leader report replaces ordinary report")
Equal(controller.expiresAt, clock + 8, "BG report refreshes eight-second expiry")
Battleground("where efc?")
Equal(IDs(controller.activeIDs), "ALLY_ROOF", "BG question does not replace report")
Battleground("efc tunnel", false, "Creature-1-test")
Equal(IDs(controller.activeIDs), "ALLY_ROOF", "BG non-player GUID rejected")
ZurksWSGCalloutMapDB.incomingCallouts = false
Battleground("efc tun")
Equal(IDs(controller.activeIDs), "ALLY_ROOF", "off setting also gates BG chat")
ZurksWSGCalloutMapDB.incomingCallouts = true
map:Hide()
Battleground("efc tun")
Equal(#controller.activeIDs, 0, "hidden map ignores BG reports")
map:Show()
Battleground("efc tot")
Equal(IDs(controller.activeIDs), IDs(Both("TOP_OF_TUNNEL")), "BG ambiguous callout")
instanceType, instanceID = "none", 0
controller.listener.scripts.OnEvent(controller.listener, "PLAYER_ENTERING_WORLD")
Battleground("efc roof", true)
Equal(#controller.activeIDs, 0, "leaving WSG clears and gates BG reports")
Say("efc tun")
Equal(IDs(controller.activeIDs), IDs(Both("TUNNEL")), "self say testing still works outside WSG")
controller:Clear()

-- Every existing clickable callout must round-trip to its exact map region.
for _, list in ipairs({TEST_ZONES, TEST_NESTED_ZONES}) do
    for _, zone in ipairs(list) do
        local expected = {zone.id}
        if zone.id == "MID" then expected = {"MID_WEST", "MID", "MID_EAST"} end
        Parse(zone.message, expected)
    end
end
print("WSG incoming callouts: " .. checks .. " checks passed (Lua " .. _VERSION .. ")")
