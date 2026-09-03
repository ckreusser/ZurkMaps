-- Regression checks for rotating player arrows, carrier suppression after
-- Blizzard pin rebuilds, and rank data that disappears/reorders in the roster.
local Blips = ZurkMapsPlayerBlips
local checks, now, classColors, nativeSupported = 0, 100, true, true
local players, assigned, carrierGUID = {}, {}, nil
local function Equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
function UnitExists(unit) return players[unit] ~= nil end
function UnitGUID(unit) return players[unit] and players[unit].guid end
function UnitIsUnit(a, b) return UnitGUID(a) ~= nil and UnitGUID(a) == UnitGUID(b) end
function UnitClass(unit) return "Class", players[unit] and players[unit].class end
function UnitPVPRank(unit) return players[unit] and players[unit].rank end
function UnitPVPName(unit) return players[unit] and players[unit].title or "Teammate" end
function IsInRaid() return true end
function GetTime() return now end
C_Timer = {NewTicker = function() return {} end}
C_Map = {GetPlayerMapPosition = function() return {x = 0.5, y = 0.5} end}
ZurkMapsOptions = {UseClassBlips = function() return classColors end}
ZurkMapsPlayerIcons = {
    RAID_BOSS_ICON_ID = 98,
    GetAssignedIconForUnit = function(unit) return assigned[UnitGUID(unit)] end,
    IsOverlayOnlyIcon = function(icon) return icon == 99 end,
    GetIconTexture = function() return "AssignedIcon" end,
    GetEliteAtlas = function() return "EliteDragon" end,
}

local Frame = {}
Frame.__index = Frame
function Frame:SetAllPoints(parent) self.allPoints = parent or self.parent end
function Frame:SetPoint(...) self.point = {...} end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:GetWidth() return self.width or 330 end
function Frame:GetHeight() return self.height or 440 end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:EnableMouse(enabled) self.mouse = enabled end
function Frame:Hide() self.shown = false end
function Frame:Show() self.shown = true end
function Frame:SetShown(shown) self.shown = shown end
function Frame:IsShown() return self.shown end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:SetTexture(path) self.texturePath = path end
function Frame:SetTexCoord(...) self.texCoord = {...} end
function Frame:SetVertexColor(...) self.color = {...} end
function Frame:SetBlendMode(blend) self.blend = blend end
function Frame:SetUiMapID(id) self.mapID = id end
function Frame:ClearUnits() self.units = {} end
function Frame:AddUnit(unit, texture, w, h, r, g, b, alpha, sublevel, rotation)
    if UnitGUID(unit) then
        self.units[UnitGUID(unit)] = {unit = unit, texture = texture, r = r, g = g, b = b, alpha = alpha, rotation = rotation}
    end
end
function Frame:FinalizeUnits() end
function Frame:SetUnitColor(unit, r, g, b, alpha)
    local pin = self.units[UnitGUID(unit)]
    if pin then pin.r, pin.g, pin.b, pin.alpha = r, g, b, alpha end
end
function Frame:UpdatePlayerPins(periodic)
    -- Reproduce Blizzard's UpdateFull/UpdatePeriodic resetting per-unit alpha
    -- to 1 (UnitPositionFrameTemplates.lua). Do not preserve addon overrides.
    if periodic then
        for _, pin in pairs(self.units) do self:SetUnitColor(pin.unit, 1, 1, 1, 1) end
    else
        self:ClearUnits()
        self:AddUnit("player", "WorldMapArrow", 10, 10, 1, 1, 1, 1, 1, true)
        for index = 1, 40 do
            local unit = "raid" .. index
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                self:AddUnit(unit, "WorldMapPartyIcon", 10, 10, 1, 1, 1, 1, 1, false)
            end
        end
    end
end
function CreateFrame(kind, _, parent)
    if kind == "UnitPositionFrame" and not nativeSupported then error("native special frames unavailable") end
    return setmetatable({shown = true, parent = parent, scripts = {}, events = {}, units = {}}, Frame)
end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end

local function Setup(native)
    nativeSupported, classColors, now, assigned = native, true, 100, {}
    local self = {guid = "Player-self", class = "MAGE", rank = 18}
    players = {
        player = self, raid1 = self,
        raid2 = {guid = "Player-rank13", class = "DRUID", rank = 17},
        raid3 = {guid = "Player-carrier", class = "WARRIOR", rank = 0},
        raid4 = {guid = "Player-ordinary", class = "HUNTER", rank = 0},
    }
    carrierGUID = players.raid3.guid
    local friendly = CreateFrame("Frame")
    local controller = Blips.CreateRankController({
        getFriendlyFrame = function() return friendly end,
        getMapFrame = function() return friendly end,
        isAvailable = function() return true end,
        getUiMapID = function() return 1460 end,
        getDotSize = function() return 10 end,
        shouldIncludeUnit = function(unit) return UnitGUID(unit) ~= carrierGUID end,
    })
    local function Refresh(periodic)
        friendly:UpdatePlayerPins(periodic)
        controller.UpdateBlips()
    end
    local function Overlay(unit)
        if native then
            local pin = controller.nativeSpecialFrame.units[UnitGUID(unit)]
            return pin and pin.texture
        end
        local blip = controller.blips[unit]
        return blip and blip:IsShown() and blip.texture.texturePath or nil
    end
    local function NoExtraSelf()
        if native then
            for _, frame in ipairs({controller.nativeSpecialFrame, controller.nativeShadowFrame,
                controller.nativeEliteBaseFrame, controller.nativeEliteFrame}) do
                Equal(frame.units[UnitGUID("player")], nil, "self absent from every special frame")
            end
        else
            for _, unit in ipairs({"player", "raid1"}) do
                Equal(controller.blips[unit] and controller.blips[unit]:IsShown() or false, false, "self absent from fallback blips")
                Equal(controller.eliteOverlays[unit] and controller.eliteOverlays[unit]:IsShown() or false, false, "self absent from fallback dragons")
            end
        end
        Equal(friendly.units[UnitGUID("player")].texture, "WorldMapArrow", "player keeps arrow")
        Equal(friendly.units[UnitGUID("player")].alpha, 1, "player arrow visible")
        Equal(friendly.units[UnitGUID("player")].rotation, true, "player arrow rotates")
        Equal(friendly.units[UnitGUID("player")].r, 1, "player arrow retains native tint")
    end
    Refresh()
    NoExtraSelf()
    Equal(Overlay("raid2"), "Interface\\AddOns\\ZurkMaps\\Media\\RankBadges\\Rank13_DRUID", "orange R13 helmet")
    Equal(Overlay("raid3"), nil, "carrier has no replacement blip")
    Equal(friendly.units[carrierGUID].alpha, 0, "native carrier dot hidden")
    Equal(friendly.units[UnitGUID("raid2")].alpha, 0, "native dot hidden under helmet")
    Equal(friendly.units[UnitGUID("raid4")].alpha, 0, "native dot hidden under class blip")
    Refresh(true)
    Equal(friendly.units[carrierGUID].alpha, 0, "carrier still hidden after periodic refresh")
    Equal(friendly.units[UnitGUID("raid4")].alpha, 0, "class dot has no native overlap after refresh")
    Refresh()
    Equal(friendly.units[carrierGUID].alpha, 0, "carrier still hidden after full rebuild")

    players.raid2.rank = 0
    now = now + 2
    Refresh(true)
    Equal(Overlay("raid2"), "Interface\\AddOns\\ZurkMaps\\Media\\RankBadges\\Rank13_DRUID", "known helmet survives missing rank/title")
    players.raid2.rank = nil
    now = now + 2
    Refresh(true)
    Equal(controller.GetRankNumber("raid2"), 13, "nil rank does not erase confirmed rank")

    -- Slot churn must carry the known rank with the GUID, never the slot.
    players.raid5 = players.raid2
    players.raid2 = {guid = "Player-new", class = "ROGUE", rank = 0}
    Refresh()
    Equal(controller.GetRankNumber("raid2"), nil, "new player cannot inherit a raid slot's helmet")
    Equal(Overlay("raid5"), "Interface\\AddOns\\ZurkMaps\\Media\\RankBadges\\Rank13_DRUID", "helmet follows GUID to new slot")
    players.raid5.rank = 18
    now = now + 2
    Refresh(true)
    Equal(controller.GetRankNumber("raid5"), 14, "fresh confirmed rank can update")

    classColors = false
    Refresh()
    NoExtraSelf()
    Equal(Overlay("raid5"), "Interface\\PvPRankBadges\\PvPRank14", "gold mode retains featured badge")
    Equal(friendly.units[carrierGUID].alpha, 0, "carrier hidden in gold mode")
    Equal(friendly.units[UnitGUID("raid4")].alpha, 0.95, "ordinary gold dot restored")
    classColors = true
    Refresh(true)
    Equal(friendly.units[UnitGUID("raid4")].alpha, 0, "toggle back removes underlying gold dot")
    for _, icon in ipairs({98, 99}) do
        assigned[UnitGUID("player")] = icon
        assigned[carrierGUID] = icon
        Refresh()
        NoExtraSelf()
        Equal(Overlay("raid3"), nil, "carrier assignments cannot cover flag")
    end
    assigned = {}

    carrierGUID = UnitGUID("raid5")
    Refresh(true)
    Equal(Overlay("raid5"), nil, "new carrier's helmet hidden")
    Equal(friendly.units[carrierGUID].alpha, 0, "new carrier's native dot hidden")
    Equal(Overlay("raid3"), "Interface\\AddOns\\ZurkMaps\\Media\\ClassPlayerWarcraft", "previous carrier's class blip restored")
    carrierGUID = UnitGUID("player")
    Refresh(true)
    NoExtraSelf()
    Equal(Overlay("raid5"), "Interface\\AddOns\\ZurkMaps\\Media\\RankBadges\\Rank14_DRUID", "rank restored after carrier handoff")

    local isUnit = UnitIsUnit
    UnitIsUnit = nil
    controller.UpdateBlips()
    NoExtraSelf()
    UnitIsUnit = isUnit

    controller.inspectRanks[UnitGUID("raid5")] = 14
    controller.inspectEventFrame.scripts.OnEvent(controller.inspectEventFrame, "PLAYER_ENTERING_WORLD")
    Equal(next(controller.knownRanks), nil, "world change clears confirmed ranks")
    Equal(next(controller.inspectRanks), nil, "world change clears inspected ranks")
    players.raid5.rank = 0
    Equal(controller.GetRankNumber("raid5"), nil, "rank memory limited to current world")
    players.raid5.title = "Warlord Teammate"
    now = now + 2
    Equal(controller.GetRankNumber("raid5"), 13, "title can confirm a rank")
    players.raid5.title = nil
    now = now + 2
    Equal(controller.GetRankNumber("raid5"), 13, "title-only rank survives missing data")
end
Setup(true)
Setup(false)
print("Player blips: " .. checks .. " regression checks passed (native and fallback rendering)")
