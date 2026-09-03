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
Equal(controller.expiresAt, 112, "expiry")
Equal(controller.overlays.ALLY_TUNNEL.texture.texturePath, "Interface\\AddOns\\ZurkMaps\\Media\\Highlights\\ALLY_TUNNEL", "reuse real highlight artwork")
Equal(controller.overlays.ALLY_TUNNEL.mouse, false, "click through")
local firstOverlay = controller.overlays.ALLY_TUNNEL
clock = 100.6
controller.driver.scripts.OnUpdate()
assert(controller.overlays.ALLY_TUNNEL.alpha < 0.25, "pulse trough")
checks = checks + 1
Say("efc our ramp")
Equal(IDs(controller.activeIDs), "HORDE_RAMP", "replace previous report")
Equal(firstOverlay.shown, false, "old region hidden")
Equal(controller.overlays.HORDE_RAMP.texture.shown, false, "ramp uses edited geometry")
assert(#controller.overlays.HORDE_RAMP.fills > 0, "ramp polygon drawn")
Equal(#controller.overlays.HORDE_RAMP.edges, 8, "ramp outline")
checks = checks + 1
Say("where efc?")
Equal(IDs(controller.activeIDs), "HORDE_RAMP", "question does not replace valid report")
Say("efc roof", "Creature-1-enemy")
Equal(IDs(controller.activeIDs), "HORDE_RAMP", "reject NPC event")
Say("efc tun")
Equal(controller.overlays.ALLY_TUNNEL, firstOverlay, "reuse frame pool")
clock = controller.expiresAt - 1
controller.driver.scripts.OnUpdate()
assert(firstOverlay.alpha <= 0.5, "final two-second fade")
checks = checks + 1
clock = controller.expiresAt
controller.driver.scripts.OnUpdate()
Equal(#controller.activeIDs, 0, "expired regions cleared")
Equal(controller.driver.shown, false, "idle updater stopped")
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
Equal(controller.expiresAt, clock + 12, "BG report refreshes expiry")
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
