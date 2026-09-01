local addonName = ...

local MAP_WIDTH = 276
local MAP_HEIGHT = 512
local MOVE_HANDLE_HEIGHT = 22
local MOVE_HANDLE_FONT_SIZE = 11
local TITLE_PLAQUE_WIDTH = 184
local MAP_ALPHA = 0.72
local PANE_TEXT_R, PANE_TEXT_G, PANE_TEXT_B = 0.72, 0.66, 0.50
local BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B = 0.84, 0.56, 0.31
local MIN_SCALE, MAX_SCALE = 0.65, 2.00
local DEFAULT_SCALE = 0.65

ZurksAVCalloutMapDB = ZurksAVCalloutMapDB or {}
if ZurksAVCalloutMapDB.showHonorBar == nil then ZurksAVCalloutMapDB.showHonorBar = true end

local manualVisibility = nil
local isMoving = false
local resizing = false
local resizeStartX, resizeStartY, resizeStartScale = 0, 0, 1

-- Positions are fitted from Blizzard's AV objective-map artwork onto AVMap.tga.
-- x/y are percentages of the custom portrait texture after the current AV map crop.
local OBJECTIVES = {
    -- Vanilla AV POI IDs used by this client: 7 neutral GY, 9 Horde tower, 10 Alliance tower,
    -- 12 Horde GY, 13 Alliance GY assaulted by Horde, 14 Alliance GY, 15 non-objective/invisible.
    { id="STORMPIKE_AID", name="Stormpike Aid Station", aliases={"stormpike aid station","aid station"}, x=33.81, y=14.34, kind="gy", defaultTexture=14, initialStatus="Alliance controlled" },
    { id="DB_NORTH", name="Dun Baldar North Bunker", aliases={"dun baldar north bunker","north bunker"}, x=41.12, y=13.46, kind="tower", defaultTexture=10, initialStatus="Alliance controlled" },
    { id="STORMPIKE_GY", name="Stormpike Graveyard", aliases={"stormpike graveyard"}, x=52.64, y=13.53, kind="gy", defaultTexture=14, initialStatus="Alliance controlled" },
    { id="DB_SOUTH", name="Dun Baldar South Bunker", aliases={"dun baldar south bunker","south bunker"}, x=37.97, y=17.03, kind="tower", defaultTexture=10, initialStatus="Alliance controlled" },
    { id="IRONDEEP", name="Irondeep Mine", aliases={"irondeep mine"}, x=54.16, y=8.54, kind="mine", defaultTexturePath="Interface\\AddOns\\ZurkMaps\\Media\\AV_NeutralMine", initialStatus="Neutral mine" },
    { id="ICEWING", name="Icewing Bunker", aliases={"icewing bunker"}, x=56.14, y=29.72, kind="tower", defaultTexture=10, initialStatus="Alliance controlled" },
    { id="STONEHEARTH_GY", name="Stonehearth Graveyard", aliases={"stonehearth graveyard"}, x=59.76, y=35.21, kind="gy", defaultTexture=14, initialStatus="Alliance controlled" },
    { id="SNOWFALL", name="Snowfall Graveyard", aliases={"snowfall graveyard"}, x=40.71, y=44.92, kind="gy", defaultTexture=7, initialStatus="Neutral / Unclaimed" },
    { id="STONEHEARTH", name="Stonehearth Bunker", aliases={"stonehearth bunker"}, x=62.30, y=43.36, kind="tower", defaultTexture=10, initialStatus="Alliance controlled" },
    { id="ICEBLOOD_TOWER", name="Iceblood Tower", aliases={"iceblood tower"}, x=50.56, y=58.22, kind="tower", defaultTexture=9, initialStatus="Horde controlled" },
    { id="ICEBLOOD_GY", name="Iceblood Graveyard", aliases={"iceblood graveyard"}, x=59.02, y=57.08, kind="gy", defaultTexture=12, initialStatus="Horde controlled" },
    { id="TOWER_POINT", name="Tower Point", aliases={"tower point"}, x=55.37, y=65.28, kind="tower", defaultTexture=9, initialStatus="Horde controlled" },
    { id="COLDTOOTH", name="Coldtooth Mine", aliases={"coldtooth mine"}, x=45.61, y=72.27, kind="mine", defaultTexturePath="Interface\\AddOns\\ZurkMaps\\Media\\AV_NeutralMine", initialStatus="Neutral mine" },
    { id="FROSTWOLF_GY", name="Frostwolf Graveyard", aliases={"frostwolf graveyard"}, x=52.99, y=77.20, kind="gy", defaultTexture=12, initialStatus="Horde controlled" },
    { id="WEST_FW", name="West Frostwolf Tower", aliases={"west frostwolf tower"}, x=49.89, y=85.13, kind="tower", defaultTexture=9, initialStatus="Horde controlled" },
    { id="EAST_FW", name="East Frostwolf Tower", aliases={"east frostwolf tower"}, x=53.01, y=85.13, kind="tower", defaultTexture=9, initialStatus="Horde controlled" },
    { id="RELIEF_HUT", name="Frostwolf Relief Hut", aliases={"frostwolf relief hut","relief hut"}, x=52.65, y=89.30, kind="gy", defaultTexture=12, initialStatus="Horde controlled" },
}

local function NormalizeName(value)
    value = string.lower(value or "")
    value = value:gsub("[^%w]+", " ")
    return value:match("^%s*(.-)%s*$")
end

local function FindObjective(name)
    local clean = NormalizeName(name)
    if clean == "" then return nil end
    for _, objective in ipairs(OBJECTIVES) do
        for _, alias in ipairs(objective.aliases) do
            if clean == alias or clean:find(alias, 1, true) then
                return objective
            end
        end
    end
    return nil
end

local function IsInAlteracValley()
    local instanceName = GetInstanceInfo and GetInstanceInfo() or nil
    local realZone = GetRealZoneText and GetRealZoneText() or nil
    local zone = GetZoneText and GetZoneText() or nil
    return instanceName == "Alterac Valley" or realZone == "Alterac Valley" or zone == "Alterac Valley"
end

local frame = CreateFrame("Frame", "ZurkMapsAVMapFrame", UIParent)
frame:Hide()
frame:SetSize(MAP_WIDTH + 10, MAP_HEIGHT + MOVE_HANDLE_HEIGHT + 5)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetClampedToScreen(true)
frame:SetMovable(true)

local map = CreateFrame("Frame", nil, frame)
map:SetSize(MAP_WIDTH, MAP_HEIGHT)
map:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
map:EnableMouse(true)
map:RegisterForDrag("LeftButton")

local mapTexture = map:CreateTexture(nil, "BACKGROUND")
mapTexture:SetPoint("TOPLEFT", map, "TOPLEFT", -3, 3)
mapTexture:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 3, -3)
mapTexture:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\AVMap")
mapTexture:SetTexCoord(0.028, 0.972, 0.010, 0.990)
mapTexture:SetAlpha(MAP_ALPHA)

local mapBorder = CreateFrame("Frame", nil, map, BackdropTemplateMixin and "BackdropTemplate" or nil)
mapBorder:SetPoint("TOPLEFT", map, "TOPLEFT", -5, 5)
mapBorder:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 5, -5)
if mapBorder.SetBackdrop then
    mapBorder:SetBackdrop({ edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=16 })
    mapBorder:SetBackdropBorderColor(BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B, 0.98)
end
mapBorder:EnableMouse(false)
mapBorder:SetFrameLevel(map:GetFrameLevel() + 10)

local function IsInBattlegroundInstance()
    if type(IsInInstance) ~= "function" then return false end
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "pvp"
end

local function SendChatCompat(message, chatType)
    if not message or message == "" then return false end
    chatType = chatType or "SAY"

    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        -- Classic branches have temporarily shipped both signatures. Try the
        -- struct form first (the user's current client reports `params`), then
        -- the documented positional form used by other branches.
        local ok = pcall(C_ChatInfo.SendChatMessage, { message = message, chatType = chatType })
        if ok then return true end
        ok = pcall(C_ChatInfo.SendChatMessage, message, chatType)
        if ok then return true end
    end

    if type(SendChatMessage) == "function" then
        local ok = pcall(SendChatMessage, message, chatType)
        if ok then return true end
    end
    return false
end

if ZurkMapsAVHonor and ZurkMapsAVHonor.Create then
    local avHonorBar = ZurkMapsAVHonor.Create(mapBorder, frame, MAP_HEIGHT, {
        battlegroundName = "Alterac Valley",
        db = ZurksAVCalloutMapDB,
        mapKey = "AV",
        runLabelSingular = "AV",
        runLabelPlural = "AVs",
        getAverageHonor = function(limit)
            if ZurkMapsBGHistory and ZurkMapsBGHistory.GetAverageHonor then
                return ZurkMapsBGHistory.GetAverageHonor("Alterac Valley", limit)
            end
            return nil, 0
        end,
        sendBGCallout = function(message)
            if ZurkMapsOptions and ZurkMapsOptions.SendCallout then
                ZurkMapsOptions.SendCallout("AV", message)
            else
                local chatType = IsInBattlegroundInstance() and "INSTANCE_CHAT" or "SAY"
                if not SendChatCompat(message, chatType) then
                    print("|cff33ff99Zurk Maps|r Could not send honor-bar callout.")
                end
            end
        end,
    })
    if avHonorBar and ZurkMapsHonorWidget and ZurkMapsHonorWidget.Attach then
        ZurkMapsHonorWidget.Attach(avHonorBar, ZurkMapsAVHonor, { mapKey = "AV", mapFrame = frame })
    end
end

local function GetHonorBarMode()
    return ZurkMapsHonorWidget and ZurkMapsHonorWidget.GetMode and ZurkMapsHonorWidget.GetMode() or "ATTACHED"
end

local function IsHonorBarVisible()
    return GetHonorBarMode() ~= "OFF"
end

local function ApplyHonorBarVisibility()
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMapShown then
        ZurkMapsHonorWidget.SetMapShown("AV", frame:IsShown())
    elseif ZurkMapsAVHonor and ZurkMapsAVHonor.SetVisible then
        ZurkMapsAVHonor.SetVisible(IsHonorBarVisible())
    end
end

local function SetHonorBarVisible(flag)
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMode then
        if flag then
            if ZurkMapsHonorWidget.GetMode() == "OFF" then ZurkMapsHonorWidget.SetMode("ATTACHED", "AV") end
        else
            ZurkMapsHonorWidget.SetMode("OFF", "AV")
        end
    end
end

local function IsHonorBarUnlocked()
    return ZurkMapsHonorWidget and ZurkMapsHonorWidget.IsUnlocked and ZurkMapsHonorWidget.IsUnlocked() or false
end

local function SetHonorBarUnlocked(flag)
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetGlobalUnlocked then ZurkMapsHonorWidget.SetGlobalUnlocked(flag) end
end

local function CreateCompactIconBorder(button)
    -- Exact Zurk Maps crisp icon border: dark brown outer frame + bronze inner frame.
    local border = CreateFrame("Frame", nil, button)
    border:SetAllPoints()
    border:SetFrameLevel(button:GetFrameLevel() + 2)
    border:EnableMouse(false)

    local function Edge(point1, relativePoint1, x1, y1, point2, relativePoint2, x2, y2, width, height, r, g, b, a)
        local texture = border:CreateTexture(nil, "OVERLAY")
        texture:SetPoint(point1, border, relativePoint1, x1, y1)
        if point2 then texture:SetPoint(point2, border, relativePoint2, x2, y2) end
        if width then texture:SetWidth(width) end
        if height then texture:SetHeight(height) end
        texture:SetColorTexture(r, g, b, a)
        return texture
    end

    Edge("TOPLEFT", "TOPLEFT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, 0, nil, 1, 0.055, 0.035, 0.018, 1.00)
    Edge("BOTTOMLEFT", "BOTTOMLEFT", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, nil, 1, 0.055, 0.035, 0.018, 1.00)
    Edge("TOPLEFT", "TOPLEFT", 0, 0, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, 1, nil, 0.055, 0.035, 0.018, 1.00)
    Edge("TOPRIGHT", "TOPRIGHT", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, 1, nil, 0.055, 0.035, 0.018, 1.00)

    Edge("TOPLEFT", "TOPLEFT", 1, -1, "TOPRIGHT", "TOPRIGHT", -1, -1, nil, 1, 0.70, 0.52, 0.20, 1.00)
    Edge("BOTTOMLEFT", "BOTTOMLEFT", 1, 1, "BOTTOMRIGHT", "BOTTOMRIGHT", -1, 1, nil, 1, 0.70, 0.52, 0.20, 1.00)
    Edge("TOPLEFT", "TOPLEFT", 1, -1, "BOTTOMLEFT", "BOTTOMLEFT", 1, 1, 1, nil, 0.70, 0.52, 0.20, 1.00)
    Edge("TOPRIGHT", "TOPRIGHT", -1, -1, "BOTTOMRIGHT", "BOTTOMRIGHT", -1, 1, 1, nil, 0.70, 0.52, 0.20, 1.00)

    return border
end

local avBattlecry
if ZurkMapsBattlecry and ZurkMapsBattlecry.Create then
    avBattlecry = ZurkMapsBattlecry.Create({
        frame = frame,
        map = map,
        mapBorder = mapBorder,
        db = ZurksAVCalloutMapDB,
        dbKey = "battlecryMessage",
        buttonSize = 33,
        xOffset = 7,
        yOffset = 7,
        frameLevelOffset = 4,
        backgroundAlpha = 1.00,
        iconAlpha = 1.00,
        borderAlpha = 1.00,
        hoverAlpha = 1.00,
        createBorder = CreateCompactIconBorder,
        sendMessage = function(message, chatType)
            if not SendChatCompat(message, chatType or "YELL") then
                print("|cff33ff99Zurk Maps|r Could not send Battlecry.")
            end
        end,
    })
end

local avQuickMessages
if ZurkMapsAVQuickMessages and ZurkMapsAVQuickMessages.Create then
    avQuickMessages = ZurkMapsAVQuickMessages.Create({
        frame = frame,
        map = map,
        mapBorder = mapBorder,
        db = ZurksAVCalloutMapDB,
        width = 20,
        cellHeight = 21,
        isInBattleground = IsInBattlegroundInstance,
        getCurrentChannelLabel = function()
            if ZurkMapsOptions and ZurkMapsOptions.GetCalloutChannel then
                return ZurkMapsOptions.GetCalloutChannel("AV")
            end
            return "BG"
        end,
        sendBGMessage = function(message)
            if ZurkMapsOptions and ZurkMapsOptions.SendCallout then
                ZurkMapsOptions.SendCallout("AV", message)
            else
                local chatType = IsInBattlegroundInstance() and "INSTANCE_CHAT" or "SAY"
                if not SendChatCompat(message, chatType) then
                    print("|cff33ff99Zurk Maps|r Could not send saved AV message.")
                end
            end
        end,
    })
end

local moveHandle = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
moveHandle:SetSize(TITLE_PLAQUE_WIDTH, MOVE_HANDLE_HEIGHT)
moveHandle:SetPoint("BOTTOM", map, "TOP", 0, 0)
moveHandle:SetFrameLevel(mapBorder:GetFrameLevel() + 5)
moveHandle:EnableMouse(true)
moveHandle:RegisterForDrag("LeftButton")
moveHandle.bg = moveHandle:CreateTexture(nil, "BACKGROUND")
moveHandle.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
moveHandle.bg:SetVertexColor(0.018, 0.012, 0.008, 0.97)
moveHandle.border = CreateFrame("Frame", nil, moveHandle)
moveHandle.border:SetAllPoints(moveHandle)
moveHandle.border:SetFrameLevel(moveHandle:GetFrameLevel() + 1)
moveHandle.border:EnableMouse(false)
moveHandle.borderR, moveHandle.borderG, moveHandle.borderB = BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B
moveHandle.filigreeExtraHeight, moveHandle.filigreeOverlap, moveHandle.trimHeight = 2, 4, 8
local function ApplyAtlas(texture, atlasName, useAtlasSize)
    texture:SetVertexColor(BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B, 0.97)
    if texture.SetAtlas then texture:SetAtlas(atlasName, useAtlasSize and true or false) end
end
moveHandle.topTrim = moveHandle.border:CreateTexture(nil, "BORDER"); ApplyAtlas(moveHandle.topTrim, "battlefieldminimap-border-top")
moveHandle.bottomTrim = moveHandle.border:CreateTexture(nil, "BORDER"); ApplyAtlas(moveHandle.bottomTrim, "battlefieldminimap-border-bottom")
moveHandle.leftTrim = moveHandle.border:CreateTexture(nil, "OVERLAY"); ApplyAtlas(moveHandle.leftTrim, "PetJournal-BattleSlotTitle-Left", true)
moveHandle.rightTrim = moveHandle.border:CreateTexture(nil, "OVERLAY"); ApplyAtlas(moveHandle.rightTrim, "PetJournal-BattleSlotTitle-Right", true)
moveHandle.filigreeAspect = 1
if moveHandle.leftTrim:GetHeight() and moveHandle.leftTrim:GetHeight() > 0 then moveHandle.filigreeAspect = moveHandle.leftTrim:GetWidth() / moveHandle.leftTrim:GetHeight() end
moveHandle.text = moveHandle:CreateFontString(nil, "OVERLAY")
moveHandle.text:SetPoint("CENTER")
moveHandle.text:SetFont("Fonts\\FRIZQT__.TTF", MOVE_HANDLE_FONT_SIZE, "")
moveHandle.text:SetTextColor(PANE_TEXT_R, PANE_TEXT_G, PANE_TEXT_B, 1)
moveHandle.text:SetText("Zurk Maps")

local objectiveButtons = {}


local TOWER_FIRE_DURATION = 4.0
local TOWER_FIRE_FRAME_TIME = 0.075
local TOWER_FIRE_FRAMES = 8
local TOWER_FIRE_SCALE = 1.475 -- 25% larger than the R5j fire treatment
local TOWER_FIRE_Y_OFFSET = 0.42 -- fraction of the tower icon size; keeps the flame rooted in its upper half
local TOWER_DESTROY_HONOR = 198

local function FormatAVHonorAmount(value)
    local n = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
    local valueText = tostring(n)
    while true do
        local changed, count = valueText:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        valueText = changed
        if count == 0 then break end
    end
    return valueText
end

local function IsDestroyedTowerState(objective, textureIndex, description)
    if not objective or objective.kind ~= "tower" then return false end
    local texture = tonumber(textureIndex)
    -- Vanilla AV uses POI 5 for a destroyed tower. Later/shared POI sheets use
    -- several faction-specific destroyed-tower entries; accept them as well.
    if texture == 5 or texture == 51 or texture == 53 or texture == 55
        or texture == 124 or texture == 127 or texture == 130 or texture == 133 then
        return true
    end
    local detail = string.lower(tostring(description or ""))
    return detail:find("destroyed", 1, true) ~= nil or detail:find("burned", 1, true) ~= nil
end

local function IsEnemyAVTower(objective)
    if not objective or objective.kind ~= "tower" then return false end
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    if not faction then return false end
    local owner = tonumber(objective.defaultTexture) == 10 and "Alliance"
        or (tonumber(objective.defaultTexture) == 9 and "Horde" or nil)
    return owner and owner ~= faction or false
end

local function ShowTowerHonorFloat(button, amount)
    amount = tonumber(amount)
    if not button or not amount or amount <= 0 then return end
    local float = CreateFrame("Frame", nil, map)
    float:SetSize(72, 18)
    if float.SetFrameStrata then float:SetFrameStrata("HIGH") end
    float:SetFrameLevel((mapBorder:GetFrameLevel() or 1) + 135)
    float.elapsed = 0
    float.duration = 1.20
    float.rise = 18

    local label = float:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    label:SetTextColor(1.00, 0.82, 0.12, 1)
    label:SetShadowColor(0, 0, 0, 0.90)
    label:SetShadowOffset(1, -1)
    label:SetText("+" .. FormatAVHonorAmount(amount))

    local function Reanchor(offsetY)
        float:ClearAllPoints()
        float:SetPoint("CENTER", button, "CENTER", 7, 7 + (offsetY or 0))
    end
    Reanchor(0)

    float:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        local t = math.min(1, self.elapsed / self.duration)
        local riseT = 1 - ((1 - t) * (1 - t))
        Reanchor(self.rise * riseT)
        local alpha
        if t < 0.08 then alpha = t / 0.08
        elseif t < 0.48 then alpha = 1
        else alpha = math.max(0, 1 - ((t - 0.48) / 0.52)) end
        self:SetAlpha(alpha)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            if self.SetParent then self:SetParent(nil) end
        end
    end)
end

local function EnsureTowerFireEffect(button)
    if not button then return nil end
    if button._zurkTowerFire then return button._zurkTowerFire end
    local effect = CreateFrame("Frame", nil, map)
    if effect.SetFrameStrata then effect:SetFrameStrata("HIGH") end
    effect:SetFrameLevel((mapBorder:GetFrameLevel() or 1) + 130)
    effect:EnableMouse(false)
    effect:SetPoint("CENTER", button, "CENTER", 0, 0)
    local texture = effect:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(effect)
    texture:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\AV_TowerFire")
    texture:SetTexCoord(0, 1 / TOWER_FIRE_FRAMES, 0, 1)
    effect.texture = texture
    effect:Hide()
    button._zurkTowerFire = effect
    return effect
end

local function SizeTowerFireEffect(button)
    if not button or not button._zurkTowerFire then return end
    local iconSize = button.icon and button.icon:GetWidth() or button.baseIconSize or 12
    local size = math.max(12, iconSize * TOWER_FIRE_SCALE)
    local effect = button._zurkTowerFire
    effect:SetSize(size, size)
    effect:ClearAllPoints()
    effect:SetPoint("CENTER", button, "CENTER", 0, (iconSize * TOWER_FIRE_Y_OFFSET) + 3)
end

local function PlayTowerDestroyedEffect(objective)
    if not objective then return end
    local button = objectiveButtons[objective.id]
    if not button then return end
    local effect = EnsureTowerFireEffect(button)
    if not effect then return end
    SizeTowerFireEffect(button)
    effect.elapsed = 0
    effect.frameElapsed = 0
    effect.frameIndex = 0
    effect:SetAlpha(1)
    effect.texture:SetTexCoord(0, 1 / TOWER_FIRE_FRAMES, 0, 1)
    effect:Show()
    effect:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        self.frameElapsed = (self.frameElapsed or 0) + (elapsed or 0)
        while self.frameElapsed >= TOWER_FIRE_FRAME_TIME do
            self.frameElapsed = self.frameElapsed - TOWER_FIRE_FRAME_TIME
            self.frameIndex = ((self.frameIndex or 0) + 1) % TOWER_FIRE_FRAMES
        end
        local left = self.frameIndex / TOWER_FIRE_FRAMES
        self.texture:SetTexCoord(left, left + (1 / TOWER_FIRE_FRAMES), 0, 1)
        if self.elapsed > (TOWER_FIRE_DURATION - 0.45) then
            self:SetAlpha(math.max(0, (TOWER_FIRE_DURATION - self.elapsed) / 0.45))
        end
        if self.elapsed >= TOWER_FIRE_DURATION then
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)

    if IsEnemyAVTower(objective) then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.18, function() ShowTowerHonorFloat(button, TOWER_DESTROY_HONOR) end)
        else
            ShowTowerHonorFloat(button, TOWER_DESTROY_HONOR)
        end
    end
end



local function UpdateHeaderGeometry(addonScale)
    -- Let the title plaque scale with the map. The previous inverse compensation
    -- kept the plaque physically full-size and made it overhang the map at small scales.
    local inv = 1
    moveHandle:SetWidth(TITLE_PLAQUE_WIDTH * inv)
    moveHandle:SetHeight(MOVE_HANDLE_HEIGHT * inv)
    moveHandle.text:SetFont("Fonts\\FRIZQT__.TTF", MOVE_HANDLE_FONT_SIZE * inv, "")
    local filigreeHeight = (MOVE_HANDLE_HEIGHT + 2) * inv
    local filigreeWidth = filigreeHeight * moveHandle.filigreeAspect
    local overlap = 4 * inv
    moveHandle.leftTrim:ClearAllPoints(); moveHandle.leftTrim:SetPoint("RIGHT", moveHandle.border, "LEFT", overlap, 0); moveHandle.leftTrim:SetSize(filigreeWidth, filigreeHeight)
    moveHandle.rightTrim:ClearAllPoints(); moveHandle.rightTrim:SetPoint("LEFT", moveHandle.border, "RIGHT", -overlap, 0); moveHandle.rightTrim:SetSize(filigreeWidth, filigreeHeight)
    moveHandle.bg:ClearAllPoints(); moveHandle.bg:SetPoint("TOPLEFT", moveHandle.border, "TOPLEFT", 0, -1*inv); moveHandle.bg:SetPoint("BOTTOMRIGHT", moveHandle.border, "BOTTOMRIGHT", 0, 1*inv)
    local inset = math.max(0, overlap - inv)
    moveHandle.topTrim:ClearAllPoints(); moveHandle.topTrim:SetPoint("TOPLEFT", moveHandle.border, "TOPLEFT", inset, 2*inv); moveHandle.topTrim:SetPoint("TOPRIGHT", moveHandle.border, "TOPRIGHT", -inset, 2*inv); moveHandle.topTrim:SetHeight(8*inv)
    moveHandle.bottomTrim:ClearAllPoints(); moveHandle.bottomTrim:SetPoint("BOTTOMLEFT", moveHandle.border, "BOTTOMLEFT", inset, -2*inv); moveHandle.bottomTrim:SetPoint("BOTTOMRIGHT", moveHandle.border, "BOTTOMRIGHT", -inset, -2*inv); moveHandle.bottomTrim:SetHeight(8*inv)
end

local function GetObjectiveScaleCompensation()
    local scale = frame:GetScale() or 1
    if scale >= 1 then return 1 end
    local fullInverse = 1 / math.max(scale, 0.01)
    -- A mild compensation keeps towers/graveyards legible at the minimum map size
    -- without making them look detached from the underlying AV artwork.
    return 1 + ((fullInverse - 1) * 0.30)
end

local function UpdateObjectiveScale()
    local comp = GetObjectiveScaleCompensation()
    for _, button in pairs(objectiveButtons) do
        if button and button.icon and button.baseIconSize then
            local iconComp = (button.objectiveKind == "tower" or button.objectiveKind == "gy") and comp or 1
            local iconSize = button.baseIconSize * iconComp
            local buttonSize = math.max(button.baseButtonSize or 16, iconSize + 4)
            button:SetSize(buttonSize, buttonSize)
            button.icon:SetSize(iconSize, iconSize)
            SizeTowerFireEffect(button)
            local h = button:GetHighlightTexture()
            if h then h:SetSize(buttonSize + 3, buttonSize + 3) end
        end
    end
end

UpdateHeaderGeometry(1)
ApplyHonorBarVisibility()

local function SaveLayout()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then ZurksAVCalloutMapDB.point = { point=point, relativePoint=relativePoint, x=x, y=y } end
    ZurksAVCalloutMapDB.scale = frame:GetScale()
end
local function RestoreLayout()
    local scale = math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(ZurksAVCalloutMapDB.scale) or DEFAULT_SCALE))
    frame:SetScale(scale); UpdateHeaderGeometry(scale); UpdateObjectiveScale(); if ZurkMapsAVLieutenants and ZurkMapsAVLieutenants.RefreshScale then ZurkMapsAVLieutenants.RefreshScale() end
    local p = ZurksAVCalloutMapDB.point
    if p and p.point and p.relativePoint and p.x and p.y then frame:ClearAllPoints(); frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y) end
end
local function GetCursorUIPosition()
    local x, y = GetCursorPosition(); local scale = UIParent:GetEffectiveScale(); return x/scale, y/scale
end
local function StartMove()
    if InCombatLockdown and InCombatLockdown() then return end
    isMoving = true; GameTooltip:Hide(); frame:StartMoving()
end
local function StopMove()
    if not isMoving then return end
    frame:StopMovingOrSizing(); isMoving = false; SaveLayout()
end
moveHandle:SetScript("OnMouseDown", function() moveHandle.didDrag=false end)
moveHandle:SetScript("OnDragStart", function() moveHandle.didDrag=true; StartMove() end)
moveHandle:SetScript("OnDragStop", StopMove)
moveHandle:SetScript("OnMouseUp", function(self, button)
    local didDrag=moveHandle.didDrag; StopMove()
    if button=="RightButton" and not didDrag and ZurkMapsOptions then ZurkMapsOptions.OpenMapMenu("AV", self); return end
    if button=="LeftButton" and IsControlKeyDown() and not didDrag and ZurkMapsPromos then
        if IsShiftKeyDown() then
            ZurkMapsPromos.SendRandomPromo("AV")
        else
            local promo=ZurkMapsPromos.GetHeaderPromo("AV")
            if ZurkMapsOptions and ZurkMapsOptions.SendHeaderShare then
                ZurkMapsOptions.SendHeaderShare(promo)
            elseif SendChatCompat then
                SendChatCompat(promo, IsInBattlegroundInstance() and "INSTANCE_CHAT" or "SAY")
            end
        end
    end
end)
moveHandle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Drag here to move map"); GameTooltip:AddLine("Right-click for options.", 0.95,0.82,0.28,true); GameTooltip:AddLine("CTRL+Click to share the addon in chat.",0.8,0.8,0.8,true); GameTooltip:Show()
end)
moveHandle:SetScript("OnLeave", function() GameTooltip:Hide() end)

map:SetScript("OnDragStart", function() if IsAltKeyDown() then StartMove() end end)
map:SetScript("OnDragStop", StopMove)

local function BeginResize()
    if InCombatLockdown and InCombatLockdown() then return end
    resizing=true; resizeStartX,resizeStartY=GetCursorUIPosition(); resizeStartScale=frame:GetScale(); GameTooltip:Hide()
end
local function EndResize() if resizing then resizing=false; SaveLayout() end end
local resizeHandle=CreateFrame("Button", nil, map)
resizeHandle:SetSize(22,22); resizeHandle:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -1,1); resizeHandle:SetFrameLevel(mapBorder:GetFrameLevel()+2); resizeHandle:RegisterForDrag("LeftButton")
resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"); resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeHandle:SetScript("OnDragStart", BeginResize); resizeHandle:SetScript("OnDragStop", EndResize); resizeHandle:SetScript("OnMouseUp", EndResize)
resizeHandle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:SetText("Resize Zurk Map")
    GameTooltip:Show()
end)
resizeHandle:SetScript("OnLeave", function() GameTooltip:Hide() end)
resizeHandle:SetScript("OnUpdate", function()
    if not resizing then return end
    local x,y=GetCursorUIPosition(); local dx=x-resizeStartX; local dy=resizeStartY-y
    local sx=resizeStartScale+(dx/MAP_WIDTH); local sy=resizeStartScale+(dy/MAP_HEIGHT); local newScale=(sx+sy)/2
    newScale=math.max(MIN_SCALE, math.min(MAX_SCALE,newScale)); frame:SetScale(newScale); UpdateHeaderGeometry(newScale); UpdateObjectiveScale(); if ZurkMapsAVLieutenants and ZurkMapsAVLieutenants.RefreshScale then ZurkMapsAVLieutenants.RefreshScale() end
end)


-- Friendly-player blips: shared Zurk Maps behavior, adapted to the AV artwork crop.
local AV_FRIENDLY_PLAYER_DOT_SIZE = 10
local AV_TEST_GOLD_R, AV_TEST_GOLD_G, AV_TEST_GOLD_B = 1.00, 0.82, 0.18
local CLASS_COLOR_FALLBACK = {
    WARRIOR={0.78,0.61,0.43}, PALADIN={0.96,0.55,0.73}, HUNTER={0.67,0.83,0.45},
    ROGUE={1.00,0.96,0.41}, PRIEST={1.00,1.00,1.00}, SHAMAN={0.00,0.44,0.87},
    MAGE={0.25,0.78,0.92}, WARLOCK={0.53,0.53,0.93}, DRUID={1.00,0.49,0.04},
}

-- AV's custom portrait bitmap is not the same aspect/crop as Blizzard's native
-- battlefield coordinate surface. Start with inverse texture-crop compensation,
-- then, once Blizzard exposes AV landmark positions in the live battleground,
-- fit an independent X/Y scale + offset against our already-calibrated objective
-- icons. This is the same general strategy used by AB and keeps live teammate
-- blips attached to the terrain rather than merely to the bitmap bounds.
local AV_POSITION_GEOMETRY = {
    xOffset = -0.028 / (0.972 - 0.028),
    yOffset = -0.010 / (0.990 - 0.010),
    xScale = 1 / (0.972 - 0.028),
    yScale = 1 / (0.990 - 0.010),
    calibrated = false,
}

local function FitAVFriendlyPositionAxis(samples, rawKey, targetKey)
    local count = 0
    local sumRaw, sumTarget = 0, 0
    local sumRawSquared, sumRawTarget = 0, 0
    for _, sample in ipairs(samples or {}) do
        local raw = tonumber(sample[rawKey])
        local target = tonumber(sample[targetKey])
        if raw and target then
            count = count + 1
            sumRaw = sumRaw + raw
            sumTarget = sumTarget + target
            sumRawSquared = sumRawSquared + (raw * raw)
            sumRawTarget = sumRawTarget + (raw * target)
        end
    end
    if count < 4 then return nil, nil end
    local denominator = (count * sumRawSquared) - (sumRaw * sumRaw)
    if math.abs(denominator) < 0.000001 then return nil, nil end
    local scale = ((count * sumRawTarget) - (sumRaw * sumTarget)) / denominator
    local offset = (sumTarget - (scale * sumRaw)) / count
    return scale, offset
end

local function UpdateAVFriendlyPositionCalibration(samples)
    local xScale, xOffset = FitAVFriendlyPositionAxis(samples, "rawX", "targetX")
    local yScale, yOffset = FitAVFriendlyPositionAxis(samples, "rawY", "targetY")
    if not xScale or not xOffset or not yScale or not yOffset then return false end

    -- Sanity guard against a transient/bad landmark API result.
    if xScale < 0.50 or xScale > 3.00
        or yScale < 0.50 or yScale > 3.00
        or xOffset < -1.00 or xOffset > 1.00
        or yOffset < -1.00 or yOffset > 1.00 then
        return false
    end

    local geometry = AV_POSITION_GEOMETRY
    local changed = not geometry.calibrated
        or math.abs(geometry.xScale - xScale) > 0.0005
        or math.abs(geometry.xOffset - xOffset) > 0.0005
        or math.abs(geometry.yScale - yScale) > 0.0005
        or math.abs(geometry.yOffset - yOffset) > 0.0005

    geometry.xScale = xScale
    geometry.xOffset = xOffset
    geometry.yScale = yScale
    geometry.yOffset = yOffset
    geometry.calibrated = true
    return changed
end

local function TransformAVPlayerPosition(x, y)
    local geometry = AV_POSITION_GEOMETRY
    return (x * geometry.xScale) + geometry.xOffset,
        (y * geometry.yScale) + geometry.yOffset
end


local function GetAVVectorPositionXY(position)
    if not position then return nil, nil end
    local okMethod, method = pcall(function() return position.GetXY end)
    if okMethod and type(method)=="function" then
        local ok,x,y=pcall(method,position)
        if ok and type(x)=="number" and type(y)=="number" then return x,y end
    end
    local okX,x=pcall(function() return position.x end)
    local okY,y=pcall(function() return position.y end)
    if okX and okY and type(x)=="number" and type(y)=="number" then return x,y end
    return nil,nil
end

local friendlyPlayersClipFrame = CreateFrame("Frame", nil, map)
friendlyPlayersClipFrame:SetAllPoints(map)
-- AV objective art is interactive and intentionally sits above the parchment,
-- but player information must win visually when the two overlap. Put the entire
-- player visual stack in HIGH strata rather than trying to out-number objective
-- frame levels inside the same strata (UnitPositionFrame creates its own pins).
if friendlyPlayersClipFrame.SetFrameStrata then friendlyPlayersClipFrame:SetFrameStrata("HIGH") end
friendlyPlayersClipFrame:SetFrameLevel(mapBorder:GetFrameLevel() + 20)
if friendlyPlayersClipFrame.SetClipsChildren then friendlyPlayersClipFrame:SetClipsChildren(true) end
friendlyPlayersClipFrame:EnableMouse(false)

local friendlyPlayersFrame = nil
local friendlyPlayersFrameAvailable = false
local friendlyPlayersElapsed = 0
local hoveredFriendlyPlayersSignature = nil
local avTestMode = false
local testPreviousManualVisibility = nil

local function GetAVUiMapID()
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and mapID then return mapID end
    end
    if type(GetCurrentMapAreaID) == "function" then
        local ok, mapID = pcall(GetCurrentMapAreaID)
        if ok and mapID and mapID > 0 then return mapID end
    end
    return nil
end

if ZurkMapsAVLieutenants and ZurkMapsAVLieutenants.Create then
    ZurkMapsAVLieutenants.Create({
        map=map,
        mapBorder=mapBorder,
        addonFrame=frame,
        positionParent=friendlyPlayersClipFrame,
        configureNativePositionFrame=function(positionFrame)
            if not positionFrame then return end
            local mapWidth = map:GetWidth() or MAP_WIDTH
            local mapHeight = map:GetHeight() or MAP_HEIGHT
            positionFrame:ClearAllPoints()
            positionFrame:SetPoint("TOPLEFT", map, "TOPLEFT",
                AV_POSITION_GEOMETRY.xOffset * mapWidth,
                -(AV_POSITION_GEOMETRY.yOffset * mapHeight))
            positionFrame:SetSize(
                AV_POSITION_GEOMETRY.xScale * mapWidth,
                AV_POSITION_GEOMETRY.yScale * mapHeight)
            local mapID = GetAVUiMapID()
            if mapID and positionFrame.SetUiMapID then
                pcall(positionFrame.SetUiMapID, positionFrame, mapID)
            end
        end,
        getUiMapID=GetAVUiMapID,
        transformMapPosition=function(x,y)
            local tx,ty=TransformAVPlayerPosition(x,y)
            if type(tx)=="number" and type(ty)=="number" then
                return tx*100,ty*100
            end
            return nil,nil
        end,
        openMapMenu=function(owner)
            if ZurkMapsOptions then ZurkMapsOptions.OpenMapMenu("AV", owner) end
        end,
        sendCallout=function(message)
            if ZurkMapsOptions and ZurkMapsOptions.SendCallout then
                ZurkMapsOptions.SendCallout("AV", message)
            elseif SendChatMessage then
                SendChatMessage(message, "SAY")
            end
        end,
    })
end

local AVMapRank = ZurkMapsPlayerBlips and ZurkMapsPlayerBlips.CreateRankController and ZurkMapsPlayerBlips.CreateRankController({
    min=12, max=14, iconScale=0.924, baseDotSize=AV_FRIENDLY_PLAYER_DOT_SIZE,
    getFriendlyFrame=function() return friendlyPlayersFrame end,
    isAvailable=function() return friendlyPlayersFrameAvailable end,
    getMapFrame=function() return map end,
    getUiMapID=GetAVUiMapID,
    getDotSize=function() return ZurkMapsPlayerBlips.GetDotSize(AV_FRIENDLY_PLAYER_DOT_SIZE, frame) end,
    -- Manual/rank player icons must remain visible when crossing AV objective icons.
    -- Objective buttons live at mapBorder + 5; reserve +10 and above for special players.
    getSpecialFrameLevel=function() return mapBorder:GetFrameLevel() + 24 end,
    -- Visible default blips are deliberately gold; tooltip names remain class-colored.
    getClassColor=function() return AV_TEST_GOLD_R, AV_TEST_GOLD_G, AV_TEST_GOLD_B end,
    mapWidth=MAP_WIDTH, mapHeight=MAP_HEIGHT,
}) or nil

local function ApplyFriendlyPositionGeometry()
    if not friendlyPlayersFrame then return end
    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT
    friendlyPlayersFrame:ClearAllPoints()
    friendlyPlayersFrame:SetPoint("TOPLEFT", map, "TOPLEFT",
        AV_POSITION_GEOMETRY.xOffset * mapWidth,
        -(AV_POSITION_GEOMETRY.yOffset * mapHeight))
    friendlyPlayersFrame:SetSize(
        AV_POSITION_GEOMETRY.xScale * mapWidth,
        AV_POSITION_GEOMETRY.yScale * mapHeight)
end

local function ConfigureFriendlyPlayerDots()
    if not friendlyPlayersFrameAvailable or not friendlyPlayersFrame or not AVMapRank then return false end
    local mapID = GetAVUiMapID()
    if not mapID then return false end
    ApplyFriendlyPositionGeometry()
    pcall(friendlyPlayersFrame.SetUiMapID, friendlyPlayersFrame, mapID)
    pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "player", true)
    pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "party", true)
    pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "raid", true)
    local dotSize = ZurkMapsPlayerBlips.GetDotSize(AV_FRIENDLY_PLAYER_DOT_SIZE, frame)
    pcall(friendlyPlayersFrame.SetPinSize, friendlyPlayersFrame, "player", dotSize)
    pcall(friendlyPlayersFrame.SetPinSize, friendlyPlayersFrame, "party", dotSize)
    pcall(friendlyPlayersFrame.SetPinSize, friendlyPlayersFrame, "raid", dotSize)
    AVMapRank.ColorFriendlyUnit("player")
    for i=1,4 do AVMapRank.ColorFriendlyUnit("party"..i) end
    for i=1,40 do AVMapRank.ColorFriendlyUnit("raid"..i) end
    pcall(friendlyPlayersFrame.UpdatePlayerPins, friendlyPlayersFrame)
    AVMapRank.UpdateBlips()
    return true
end

local function UpdateFriendlyPlayerPositions()
    if friendlyPlayersFrameAvailable and friendlyPlayersFrame and friendlyPlayersFrame:IsShown() and AVMapRank then
        pcall(friendlyPlayersFrame.UpdatePlayerPins, friendlyPlayersFrame)
        AVMapRank.UpdateBlips()
    end
end

do
    local ok, created = pcall(CreateFrame, "UnitPositionFrame", nil, friendlyPlayersClipFrame, "GroupMembersPinTemplate")
    if ok and created then
        friendlyPlayersFrame = created
        if AVMapRank then friendlyPlayersFrame.dataProvider = AVMapRank.dataProvider end
        friendlyPlayersFrame:SetScript("OnUpdate", nil)
        if friendlyPlayersFrame.SetFrameStrata then friendlyPlayersFrame:SetFrameStrata("HIGH") end
        friendlyPlayersFrame:SetFrameLevel(friendlyPlayersClipFrame:GetFrameLevel() + 1)
        -- AV uses dedicated transparent hit buttons for player hover/right-click.
        -- Keep the visual UnitPositionFrame completely mouse-transparent so it can
        -- sit above objective artwork without stealing objective interactions.
        if friendlyPlayersFrame.SetMouseMotionEnabled then friendlyPlayersFrame:SetMouseMotionEnabled(false) else friendlyPlayersFrame:EnableMouse(false) end
        if friendlyPlayersFrame.SetMouseClickEnabled then friendlyPlayersFrame:SetMouseClickEnabled(false) end
        friendlyPlayersFrameAvailable = type(friendlyPlayersFrame.UpdatePlayerPins) == "function"
        friendlyPlayersFrame:SetShown(false)
    end
end

local friendlyPlayersUpdateFrame = CreateFrame("Frame", nil, frame)
friendlyPlayersUpdateFrame:SetScript("OnUpdate", function(_, elapsed)
    if not friendlyPlayersFrameAvailable or not friendlyPlayersFrame or not friendlyPlayersFrame:IsShown() then return end
    friendlyPlayersElapsed = friendlyPlayersElapsed + elapsed
    if friendlyPlayersElapsed < 0.05 then return end
    friendlyPlayersElapsed = 0
    UpdateFriendlyPlayerPositions()
end)

local AV_TEST_NAMES = {
    "Frostbinder","Ironhowl","Stormbrand","Ashwalker","Grimward","Nightforge","Brightaxe","Wolfheart",
    "Stonecaller","Duskblade","Emberguard","Runesong","Oakshield","Skytalon","Blackriver","Goldfang",
    "Snowreaver","Thornwatch","Steelwind","Moonstrike","Ragebloom","Dawnshield","Hexrunner","Cloudscar",
    "Firemane","Coldhammer","Shadowfen","Wildspark","Gravewind","Redbranch","Stormhoof","Icebrand",
    "Duskrunner","Bloodpine","Mistclaw","Sunforge","Boneward","Frostveil","Warbriar","Ironstar",
}
-- Test-mode rush routes. All 40 simulated players begin stacked at their faction's
-- starting cave, then leave in a staggered stream toward the opposing main keep.
local AV_TEST_ROUTE_ALLIANCE = {
    {0.675,0.050}, -- Alliance starting cave: user-marked cave at the far north-east edge
    {0.650,0.095},{0.600,0.145},{0.545,0.210},{0.555,0.295},{0.595,0.355},
    {0.545,0.415},{0.485,0.475},{0.530,0.535},{0.565,0.590},{0.555,0.650},
    {0.525,0.710},{0.530,0.770},{0.515,0.825},{0.525,0.875},{0.535,0.915},
}
local AV_TEST_ROUTE_HORDE = {
    {0.765,0.710}, -- Horde starting cave: user-marked cave east/southeast of Tower Point
    {0.705,0.680},{0.635,0.645},{0.585,0.610},{0.555,0.575},{0.535,0.535},
    {0.485,0.505},{0.455,0.460},{0.505,0.410},{0.565,0.355},{0.555,0.300},
    {0.540,0.250},{0.500,0.205},{0.450,0.175},{0.400,0.145},{0.365,0.120},{0.350,0.100},
}
local AV_TEST_CLASSES_ALLIANCE = {"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID"}
local AV_TEST_CLASSES_HORDE = {"WARRIOR","SHAMAN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID"}
local avTestAgents, avTestBlips = {}, {}
local ShowTestPlayerTooltip, ShowFriendlyPlayerTooltip
local LockTestHoverPlayers
local testHoverLockPlayers = nil
local testHoverLockSignature = nil
local testHoverLockUntil = 0
local TEST_HOVER_GRACE = 0.55
local TEST_HOVER_RADIUS_MULTIPLIER = 1.80

local function GetTestClasses()
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "Horde"
    return faction == "Alliance" and AV_TEST_CLASSES_ALLIANCE or AV_TEST_CLASSES_HORDE
end

local function GetAVTestRoute()
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "Horde"
    return faction == "Alliance" and AV_TEST_ROUTE_ALLIANCE or AV_TEST_ROUTE_HORDE
end

local function ResetAVTestAgents()
    for i = #avTestAgents, 1, -1 do avTestAgents[i] = nil end
end

-- Match Zurk Maps' stacked-player behavior: treat nearby/overlapping test blips
-- as one hover group so the tooltip lists every player under that stack.
local function GetAVTestPlayersNearAgent(centerAgent)
    if not centerAgent then return nil end
    local mapWidth=map:GetWidth() or MAP_WIDTH
    local mapHeight=map:GetHeight() or MAP_HEIGHT
    local radius=math.max(7,ZurkMapsPlayerBlips.GetDotSize(AV_FRIENDLY_PLAYER_DOT_SIZE,frame)*0.95)
    local matches={}
    for _,agent in ipairs(avTestAgents) do
        local dx=(centerAgent.x-agent.x)*mapWidth
        local dy=(centerAgent.y-agent.y)*mapHeight
        if dx*dx+dy*dy<=radius*radius then matches[#matches+1]=agent end
    end
    return #matches>0 and matches or nil
end

local function InitializeAVTestAgents()
    if #avTestAgents > 0 then return end
    local classes = GetTestClasses()
    local route = GetAVTestRoute()
    local spawn = route[1]
    for i=1,40 do
        avTestAgents[i] = {
            name=AV_TEST_NAMES[i] or ("AVTester"..i),
            classToken=classes[((i - 1) % #classes) + 1],
            iconKey="TEST:AV:"..i,
            routeIndex=1,
            direction=1,
            lane=0,
            x=spawn[1],
            y=spawn[2],
            speed=4.0 + ((i * 13) % 18) / 10,
            pause=(i - 1) * 0.18,
            finished=false,
        }
        local blip = CreateFrame("Button", nil, friendlyPlayersClipFrame)
        if blip.SetFrameStrata then blip:SetFrameStrata("HIGH") end
        blip:SetFrameLevel(mapBorder:GetFrameLevel() + 26)
        blip:EnableMouse(true)
        blip:RegisterForClicks("RightButtonUp")
        blip.agentIndex = i
        blip.shadow=blip:CreateTexture(nil,"ARTWORK")
        blip.shadow:SetPoint("TOPLEFT",blip,"TOPLEFT",-1,1)
        blip.shadow:SetPoint("BOTTOMRIGHT",blip,"BOTTOMRIGHT",1,-1)
        blip.shadow:SetTexCoord(0,1,0,1)
        blip.shadow:SetVertexColor(0,0,0,0.72)
        blip.shadow:Hide()
        blip.texture=blip:CreateTexture(nil,"OVERLAY")
        blip.texture:SetAllPoints()
        blip.texture:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
        blip.texture:SetTexCoord(0,1,0,1)
        blip.texture:SetVertexColor(AV_TEST_GOLD_R,AV_TEST_GOLD_G,AV_TEST_GOLD_B,1)
        blip:SetScript("OnEnter", function(self)
            local agent = avTestAgents[self.agentIndex]
            local players = GetAVTestPlayersNearAgent(agent)
            if players then LockTestHoverPlayers(players) end
        end)
        -- Do not hide immediately when crossing between overlapping child buttons;
        -- the shared hover updater below owns tooltip lifetime, just like Zurk Maps.
        blip:SetScript("OnLeave", function() end)
        blip:SetScript("OnClick", function(self, button)
            if button ~= "RightButton" or not ZurkMapsPlayerIcons then return end
            local agent = avTestAgents[self.agentIndex]
            local players = GetAVTestPlayersNearAgent(agent)
            if players then ZurkMapsPlayerIcons.OpenAssignmentMenuForTestPlayers(self, players) end
        end)
        blip:Hide()
        avTestBlips[i]=blip
    end
end

local function AdvanceAVTestAgents(elapsed)
    InitializeAVTestAgents()
    local route=GetAVTestRoute()
    local mapWidth=map:GetWidth() or MAP_WIDTH
    local mapHeight=map:GetHeight() or MAP_HEIGHT
    for _,agent in ipairs(avTestAgents) do
        if agent.pause and agent.pause>0 then
            agent.pause=math.max(0,agent.pause-elapsed)
        elseif not agent.finished then
            local nextIndex=agent.routeIndex+1
            if nextIndex>#route then
                agent.finished=true
            else
                local target=route[nextIndex]
                local tx=math.max(0.03,math.min(0.97,target[1]))
                local ty=target[2]
                local dxPixels=(tx-agent.x)*mapWidth
                local dyPixels=(ty-agent.y)*mapHeight
                local distance=math.sqrt(dxPixels*dxPixels+dyPixels*dyPixels)
                local step=agent.speed*elapsed
                if distance<0.01 or step>=distance then
                    agent.x,agent.y=tx,ty
                    agent.routeIndex=nextIndex
                    if agent.routeIndex==#route then
                        agent.finished=true
                    elseif (agent.routeIndex % 5)==0 then
                        agent.pause=0.20
                    end
                else
                    agent.x=agent.x+(dxPixels/distance)*step/mapWidth
                    agent.y=agent.y+(dyPixels/distance)*step/mapHeight
                end
            end
        end
    end
end

local function UpdateAVTestBlips()
    InitializeAVTestAgents()
    local dotSize=ZurkMapsPlayerBlips.GetDotSize(AV_FRIENDLY_PLAYER_DOT_SIZE,frame)
    local mapWidth=map:GetWidth() or MAP_WIDTH
    local mapHeight=map:GetHeight() or MAP_HEIGHT
    for i,agent in ipairs(avTestAgents) do
        local blip=avTestBlips[i]
        local assigned=ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForKey and ZurkMapsPlayerIcons.GetAssignedIconForKey(agent.iconKey,true) or nil
        if assigned and ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.ApplyAssignedIcon then
            if ZurkMapsPlayerIcons.IsOverlayOnlyIcon and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assigned) then
                ZurkMapsPlayerBlips.ApplyGoldBlip(blip,dotSize,AV_TEST_GOLD_R,AV_TEST_GOLD_G,AV_TEST_GOLD_B)
                ZurkMapsPlayerIcons.ApplyAssignedIcon(blip,assigned,dotSize)
            else
                ZurkMapsPlayerIcons.ApplyAssignedIcon(blip,assigned,dotSize*(ZurkMapsPlayerIcons.manualIconScale or 0.84))
            end
        else
            ZurkMapsPlayerBlips.ApplyGoldBlip(blip,dotSize,AV_TEST_GOLD_R,AV_TEST_GOLD_G,AV_TEST_GOLD_B)
        end
        blip:ClearAllPoints()
        blip:SetPoint("CENTER",map,"TOPLEFT",agent.x*mapWidth,-(agent.y*mapHeight))
        blip:SetShown(avTestMode)
    end
end

local function HideAVTestBlips()
    for _,blip in ipairs(avTestBlips) do blip:Hide() end
end

local testMovementElapsed=0
local testMovementFrame=CreateFrame("Frame", nil, frame)
testMovementFrame:SetScript("OnUpdate",function(_,elapsed)
    if not avTestMode then return end
    testMovementElapsed=testMovementElapsed+elapsed
    if testMovementElapsed<0.05 then return end
    local step=testMovementElapsed
    testMovementElapsed=0
    AdvanceAVTestAgents(step)
    UpdateAVTestBlips()
end)

local function GetMapMousePercent()
    local left = map:GetLeft()
    local bottom = map:GetBottom()
    local width = map:GetWidth()
    local height = map:GetHeight()
    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then
        return nil, nil
    end

    -- Match the WSG/AB hit-testing path exactly. GetCursorPosition() is in
    -- physical screen pixels, while GetLeft()/GetWidth() are frame-space values.
    -- Converting the map bounds with the map's effective scale keeps AV player
    -- hover aligned after the user resizes the Zurk map.
    local effectiveScale = map:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    local leftPx = left * effectiveScale
    local bottomPx = bottom * effectiveScale
    local widthPx = width * effectiveScale
    local heightPx = height * effectiveScale

    local x = ((cursorX - leftPx) / widthPx) * 100
    local yFromBottom = ((cursorY - bottomPx) / heightPx) * 100
    local y = 100 - yFromBottom
    if x < 0 or x > 100 or y < 0 or y > 100 then
        return nil, nil
    end
    return x, y
end

local function GetAVTestPlayersUnderMouse()
    if not avTestMode then return nil end
    local mx,my=GetMapMousePercent()
    if not mx or mx<0 or mx>100 or my<0 or my>100 then return nil end
    local nx,ny=mx/100,my/100
    local mapWidth=map:GetWidth() or MAP_WIDTH
    local mapHeight=map:GetHeight() or MAP_HEIGHT
    local radius=math.max(7,ZurkMapsPlayerBlips.GetDotSize(AV_FRIENDLY_PLAYER_DOT_SIZE,frame)*0.95)
    local matches={}
    for _,agent in ipairs(avTestAgents) do
        local dx=(nx-agent.x)*mapWidth
        local dy=(ny-agent.y)*mapHeight
        if dx*dx+dy*dy<=radius*radius then matches[#matches+1]=agent end
    end
    return #matches>0 and matches or nil
end

local function GetTestPlayersSignature(players)
    if not players or #players == 0 then return nil end
    local names = {}
    for _, player in ipairs(players) do names[#names + 1] = player.name end
    table.sort(names)
    return "test:" .. table.concat(names, "|")
end

local function IsTestMouseNearPlayers(players, radiusMultiplier)
    if not players or #players == 0 then return false end
    local mx,my=GetMapMousePercent()
    if not mx or mx<0 or mx>100 or my<0 or my>100 then return false end
    local nx,ny=mx/100,my/100
    local mapWidth=map:GetWidth() or MAP_WIDTH
    local mapHeight=map:GetHeight() or MAP_HEIGHT
    local radius=math.max(7,ZurkMapsPlayerBlips.GetDotSize(AV_FRIENDLY_PLAYER_DOT_SIZE,frame)*0.95) * (radiusMultiplier or 1)
    local radiusSq=radius*radius
    for _,agent in ipairs(players) do
        local dx=(nx-agent.x)*mapWidth
        local dy=(ny-agent.y)*mapHeight
        if dx*dx+dy*dy<=radiusSq then return true end
    end
    return false
end

LockTestHoverPlayers = function(players)
    if not players or #players == 0 then return false end
    local now = GetTime and GetTime() or 0

    -- Crossing from one moving child hitbox to another inside the same huddle
    -- must not replace the tooltip snapshot. Keep the group the cursor originally
    -- entered until the mouse actually leaves that cluster.
    if testHoverLockPlayers and IsTestMouseNearPlayers(testHoverLockPlayers, TEST_HOVER_RADIUS_MULTIPLIER) then
        testHoverLockUntil = now + TEST_HOVER_GRACE
        if ShowTestPlayerTooltip then ShowTestPlayerTooltip(testHoverLockPlayers) end
        return true
    end

    testHoverLockPlayers = {}
    for i, player in ipairs(players) do testHoverLockPlayers[i] = player end
    testHoverLockSignature = GetTestPlayersSignature(players)
    testHoverLockUntil = now + TEST_HOVER_GRACE
    if ShowTestPlayerTooltip then ShowTestPlayerTooltip(testHoverLockPlayers) end
    return true
end

local function ClearTestHoverLock()
    testHoverLockPlayers = nil
    testHoverLockSignature = nil
    testHoverLockUntil = 0
end

local function UpdateStickyTestHover()
    local now = GetTime and GetTime() or 0
    local current = GetAVTestPlayersUnderMouse()

    if testHoverLockPlayers then
        -- As long as the cursor remains near any member of the originally-entered
        -- stack, keep that snapshot open. This prevents moving blips from repeatedly
        -- replacing/hiding the tooltip as their individual hitboxes separate.
        if IsTestMouseNearPlayers(testHoverLockPlayers, TEST_HOVER_RADIUS_MULTIPLIER) then
            testHoverLockUntil = now + TEST_HOVER_GRACE
            if ShowTestPlayerTooltip then ShowTestPlayerTooltip(testHoverLockPlayers) end
            return true
        end

        -- If the cursor has clearly moved onto a different stack, switch cleanly.
        if current and #current > 0 then
            local currentSignature = GetTestPlayersSignature(current)
            if currentSignature ~= testHoverLockSignature then
                return LockTestHoverPlayers(current)
            end
        end

        -- Small grace period absorbs the gaps created by moving/staggering blips.
        if now <= testHoverLockUntil then
            if ShowTestPlayerTooltip then ShowTestPlayerTooltip(testHoverLockPlayers) end
            return true
        end

        ClearTestHoverLock()
        return false
    end

    if current and #current > 0 then
        return LockTestHoverPlayers(current)
    end
    return false
end

local LIVE_UNIT_TOKENS = {"player"}
for i=1,4 do LIVE_UNIT_TOKENS[#LIVE_UNIT_TOKENS+1] = "party"..i end
for i=1,40 do LIVE_UNIT_TOKENS[#LIVE_UNIT_TOKENS+1] = "raid"..i end

local function GetFriendlyPlayerMouseoverUnits()
    if not friendlyPlayersFrameAvailable or not friendlyPlayersFrame or not friendlyPlayersFrame:IsShown() then return nil end
    local mx,my=GetMapMousePercent()
    if not mx or mx<0 or mx>100 or my<0 or my>100 then return nil end
    local units,seen={},{}
    if type(friendlyPlayersFrame.GetCurrentMouseOverUnits)=="function" then
        local ok,current=pcall(friendlyPlayersFrame.GetCurrentMouseOverUnits,friendlyPlayersFrame)
        if ok and type(current)=="table" then
            for unit in pairs(current) do
                if type(unit)=="string" and UnitExists(unit) and not seen[unit] then seen[unit]=true; units[#units+1]=unit end
            end
        end
    end
    if #units==0 and type(friendlyPlayersFrame.GetMouseOverUnits)=="function" then
        local results={pcall(friendlyPlayersFrame.GetMouseOverUnits,friendlyPlayersFrame)}
        if results[1] then
            for i=2,#results do
                local unit=results[i]
                if type(unit)=="string" and UnitExists(unit) and not seen[unit] then seen[unit]=true; units[#units+1]=unit end
            end
        end
    end
    return #units>0 and units or nil
end

-- AV uses a stretched/offset UnitPositionFrame to align Blizzard's coordinates with
-- the custom portrait bitmap. Some Classic clients do not return mouseover units
-- from that stretched native frame, so derive the hover stack from the same
-- transformed coordinates that place the visible blips and their hitboxes.
local function GetAVLivePlayersUnderMouse()
    if avTestMode or not frame:IsShown() then return nil end
    local mx,my=GetMapMousePercent()
    if not mx or mx<0 or mx>100 or my<0 or my>100 then return nil end
    local mapID=GetAVUiMapID()
    if not mapID or not C_Map or type(C_Map.GetPlayerMapPosition)~="function" then return nil end

    local nx,ny=mx/100,my/100
    local mapWidth=map:GetWidth() or MAP_WIDTH
    local mapHeight=map:GetHeight() or MAP_HEIGHT
    local dotSize=ZurkMapsPlayerBlips.GetDotSize(AV_FRIENDLY_PLAYER_DOT_SIZE,frame)
    local radius=math.max(9,dotSize*1.20)
    local radiusSq=radius*radius
    local matches,seen={},{}

    for _,unit in ipairs(LIVE_UNIT_TOKENS or {}) do
        if UnitExists(unit) and UnitIsPlayer(unit) and UnitIsFriend("player",unit) then
            local guid=UnitGUID(unit)
            if guid and not seen[guid] then
                local ok,pos=pcall(C_Map.GetPlayerMapPosition,mapID,unit)
                if ok and pos then
                    local x,y
                    if type(pos.GetXY)=="function" then
                        local okXY,px,py=pcall(pos.GetXY,pos)
                        if okXY then x,y=px,py end
                    else
                        x,y=pos.x,pos.y
                    end
                    if type(x)=="number" and type(y)=="number" and x>0 and y>0 then
                        local customX,customY=TransformAVPlayerPosition(x,y)
                        if customX>=0 and customX<=1 and customY>=0 and customY<=1 then
                            local dx=(nx-customX)*mapWidth
                            local dy=(ny-customY)*mapHeight
                            if dx*dx+dy*dy<=radiusSq then
                                matches[#matches+1]=unit
                                seen[guid]=true
                            end
                        end
                    end
                end
            end
        end
    end

    return #matches>0 and matches or nil
end

local function GetAVFriendlyPlayersUnderMouse()
    local transformed=GetAVLivePlayersUnderMouse()
    if transformed and #transformed>0 then return transformed end
    return GetFriendlyPlayerMouseoverUnits()
end

local function GetClassColorForToken(classToken)
    local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if color then return color.r,color.g,color.b end
    local fallback=CLASS_COLOR_FALLBACK[classToken]
    if fallback then return fallback[1],fallback[2],fallback[3] end
    return 1,1,1
end

ShowTestPlayerTooltip = function(players)
    if not players or #players==0 then return false end
    local signature=GetTestPlayersSignature(players)
    if hoveredFriendlyPlayersSignature==signature and GameTooltip:IsShown() then return true end
    hoveredFriendlyPlayersSignature=signature
    GameTooltip:SetOwner(UIParent,"ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
    else GameTooltip:ClearAllPoints(); GameTooltip:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-95,95) end
    GameTooltip:ClearLines()
    for _,player in ipairs(players) do
        local r,g,b=GetClassColorForToken(player.classToken)
        GameTooltip:AddLine(ZurkMapsPlayerBlips.GetTooltipIconTagForTestPlayer(player)..player.name,r,g,b)
    end
    local tooltipName=GameTooltip:GetName()
    if tooltipName then
        for i=1,#players do local line=_G[tooltipName.."TextLeft"..i]; if line then line:SetFont("Fonts\\FRIZQT__.TTF",12,"") end end
    end
    GameTooltip:Show()
    if ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays then ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays(players,true) end
    return true
end

local function GetFriendlyPlayersSignature(units)
    local parts={}
    for _,unit in ipairs(units) do parts[#parts+1]=UnitGUID(unit) or unit end
    table.sort(parts)
    return table.concat(parts,"|")
end

ShowFriendlyPlayerTooltip = function(units)
    if not units or #units==0 then return false end
    local signature=GetFriendlyPlayersSignature(units)
    if hoveredFriendlyPlayersSignature==signature and GameTooltip:IsShown() then return true end
    hoveredFriendlyPlayersSignature=signature
    GameTooltip:SetOwner(UIParent,"ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
    else GameTooltip:ClearAllPoints(); GameTooltip:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-95,95) end
    GameTooltip:ClearLines()
    for _,unit in ipairs(units) do
        local name=(GetUnitName and GetUnitName(unit,true)) or UnitName(unit) or unit
        local r,g,b=ZurkMapsPlayerBlips.GetClassColor(unit,CLASS_COLOR_FALLBACK)
        GameTooltip:AddLine(ZurkMapsPlayerBlips.GetTooltipIconTagForUnit(unit,AVMapRank)..name,r,g,b)
    end
    local tooltipName=GameTooltip:GetName()
    if tooltipName then
        for i=1,#units do local line=_G[tooltipName.."TextLeft"..i]; if line then line:SetFont("Fonts\\FRIZQT__.TTF",12,"") end end
    end
    GameTooltip:Show()
    if ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays then ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays(units,false) end
    return true
end

local livePlayerHitButtons = {}

local function GetOrCreateLivePlayerHitButton(unit)
    local button = livePlayerHitButtons[unit]
    if button then return button end
    button = CreateFrame("Button", nil, map)
    button:SetFrameLevel(mapBorder:GetFrameLevel() + 30)
    button:EnableMouse(true)
    button:RegisterForClicks("RightButtonUp")
    button.unitToken = unit
    button:SetScript("OnEnter", function(self)
        local units = GetAVFriendlyPlayersUnderMouse()
        if units and ShowFriendlyPlayerTooltip then
            ShowFriendlyPlayerTooltip(units)
            return
        end
        local u = self.unitToken
        if u and UnitExists(u) and ShowFriendlyPlayerTooltip then ShowFriendlyPlayerTooltip({u}) end
    end)
    button:SetScript("OnLeave", function() end)
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton ~= "RightButton" or not ZurkMapsPlayerIcons then return end
        local units = GetAVFriendlyPlayersUnderMouse()
        if units and ZurkMapsPlayerIcons.OpenAssignmentMenuForUnits(self, units) then return end
        local u = self.unitToken
        if u and UnitExists(u) then ZurkMapsPlayerIcons.OpenAssignmentMenuForUnits(self, {u}) end
    end)
    button:Hide()
    livePlayerHitButtons[unit] = button
    return button
end

local function UpdateLivePlayerHitButtons()
    local mapID = GetAVUiMapID()
    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT
    local hitSize = math.max(13, ZurkMapsPlayerBlips.GetDotSize(AV_FRIENDLY_PLAYER_DOT_SIZE, frame) * 1.45)
    local showLive = frame:IsShown() and not avTestMode and mapID and C_Map and type(C_Map.GetPlayerMapPosition)=="function"
    for _, unit in ipairs(LIVE_UNIT_TOKENS) do
        local button = GetOrCreateLivePlayerHitButton(unit)
        local shown = false
        if showLive and UnitExists(unit) and UnitIsPlayer(unit) and UnitIsFriend("player", unit) then
            local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
            if ok and pos then
                local x,y
                if type(pos.GetXY)=="function" then
                    local okXY,px,py=pcall(pos.GetXY,pos)
                    if okXY then x,y=px,py end
                else
                    x,y=pos.x,pos.y
                end
                if type(x)=="number" and type(y)=="number" and x>0 and y>0 then
                    local customX,customY=TransformAVPlayerPosition(x,y)
                    if customX>=0 and customX<=1 and customY>=0 and customY<=1 then
                        button:SetSize(hitSize,hitSize)
                        button:ClearAllPoints()
                        button:SetPoint("CENTER",map,"TOPLEFT",customX*mapWidth,-(customY*mapHeight))
                        button:Show()
                        shown=true
                    end
                end
            end
        end
        if not shown then button:Hide() end
    end
end

local function ClearFriendlyPlayerTooltip()
    if hoveredFriendlyPlayersSignature then
        hoveredFriendlyPlayersSignature=nil
        GameTooltip:Hide()
    end
end

local playerHoverElapsed=0
local playerHoverFrame=CreateFrame("Frame", nil, frame)
playerHoverFrame:SetScript("OnUpdate",function(_,elapsed)
    if not frame:IsShown() or isMoving or resizing or (ZurkMapsOptions and ZurkMapsOptions.menu and ZurkMapsOptions.menu:IsShown()) then return end

    -- The player-blip hover manager shares GameTooltip with the map controls.
    -- Do not let a stale player-hover signature clear/replace the header or
    -- resize-handle tooltip while the cursor is actually over those controls.
    if (resizeHandle and resizeHandle.IsMouseOver and resizeHandle:IsMouseOver())
        or (moveHandle and moveHandle.IsMouseOver and moveHandle:IsMouseOver()) then
        hoveredFriendlyPlayersSignature=nil
        return
    end

    playerHoverElapsed=playerHoverElapsed+elapsed
    if playerHoverElapsed<0.03 then return end
    playerHoverElapsed=0
    UpdateLivePlayerHitButtons()

    if avTestMode then
        if UpdateStickyTestHover() then return end
        ClearFriendlyPlayerTooltip()
        return
    end

    local friendlyUnits=GetAVFriendlyPlayersUnderMouse()
    if friendlyUnits then
        ShowFriendlyPlayerTooltip(friendlyUnits)
        return
    end
    ClearFriendlyPlayerTooltip()
end)

local function SetTestMode(flag)
    flag=flag and true or false
    if flag==avTestMode then return end
    if flag then
        testPreviousManualVisibility=manualVisibility
        manualVisibility="show"
        avTestMode=true
        if friendlyPlayersFrame then friendlyPlayersFrame:Hide() end
        ClearTestHoverLock()
        ResetAVTestAgents()
        InitializeAVTestAgents()
        UpdateAVTestBlips()
        frame:Show()
        UpdateLivePlayerHitButtons()
    else
        avTestMode=false
        ClearTestHoverLock()
        HideAVTestBlips()
        manualVisibility=testPreviousManualVisibility
        testPreviousManualVisibility=nil
        UpdateLivePlayerHitButtons()
    end
end

local function IsTestModeActive() return avTestMode end

map:SetScript("OnMouseUp",function(self,button)
    if button~="RightButton" then return end
    if ZurkMapsPlayerIcons then
        local testPlayers=GetAVTestPlayersUnderMouse()
        if testPlayers and ZurkMapsPlayerIcons.OpenAssignmentMenuForTestPlayers(self,testPlayers) then return end
        local friendlyUnits=GetAVFriendlyPlayersUnderMouse()
        if friendlyUnits and ZurkMapsPlayerIcons.OpenAssignmentMenuForUnits(self,friendlyUnits) then return end
    end
    if ZurkMapsOptions then ZurkMapsOptions.OpenMapMenu("AV",self) end
end)

map:SetScript("OnLeave",function()
    -- Do not hide here. Entering a child player/unit frame can generate a map
    -- OnLeave even though the cursor is still visually inside the AV map.
    -- playerHoverFrame performs scale-correct hit testing every 30ms and clears
    -- the tooltip once the cursor actually leaves the player stack/map.
end)

local function ApplyPOITexture(texture, textureIndex)
    textureIndex=tonumber(textureIndex); if textureIndex == nil then return false end
    if textureIndex == 0 then texture:Hide(); return true end
    local ok,a,b,c,d
    if C_Minimap and type(C_Minimap.GetPOITextureCoords)=="function" then ok,a,b,c,d=pcall(C_Minimap.GetPOITextureCoords,textureIndex)
    elseif type(GetPOITextureCoords)=="function" then ok,a,b,c,d=pcall(GetPOITextureCoords,textureIndex) end
    if not ok or not a then return false end
    texture:SetTexture("Interface\\Minimap\\POIIcons"); texture:SetTexCoord(a,b,c,d); texture:SetVertexColor(1,1,1,1); texture:Show(); return true
end

local function ApplyStaticTexture(texture, texturePath)
    if not texturePath then return false end
    texture:SetTexture(texturePath)
    texture:SetTexCoord(0,1,0,1)
    texture:SetVertexColor(1,1,1,1)
    texture:Show()
    return true
end

local function ApplyObjectiveTexture(texture, objective, textureIndex)
    if objective and objective.kind == "mine" and tonumber(textureIndex) == 0 and objective.defaultTexturePath then
        return ApplyStaticTexture(texture, objective.defaultTexturePath)
    end
    if textureIndex and ApplyPOITexture(texture, textureIndex) then return true end
    if objective and objective.defaultTexturePath then return ApplyStaticTexture(texture, objective.defaultTexturePath) end
    if objective and objective.defaultTexture then return ApplyPOITexture(texture, objective.defaultTexture) end
    texture:Hide()
    return false
end


for _, objective in ipairs(OBJECTIVES) do
    local button=CreateFrame("Button", nil, map)
    local iconSize = math.max(8, math.floor(((objective.iconSize or 14) * 0.80) + 0.5))
    local buttonSize = math.max(16, iconSize + 4)
    button.baseIconSize = iconSize
    button.baseButtonSize = buttonSize
    button.objectiveKind = objective.kind
    button:SetSize(buttonSize,buttonSize)
    button:SetPoint("CENTER", map, "TOPLEFT", (objective.x/100)*MAP_WIDTH, -(objective.y/100)*MAP_HEIGHT)
    button:SetFrameLevel(mapBorder:GetFrameLevel()+5)
    button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetSize(iconSize, iconSize); button.icon:SetPoint("CENTER")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight","ADD")
    local h=button:GetHighlightTexture(); if h then h:SetSize(buttonSize + 3, buttonSize + 3); h:SetPoint("CENTER") end
    objective.currentTexture=objective.defaultTexture; objective.status=objective.initialStatus or "Initial control"
    ApplyObjectiveTexture(button.icon, objective, objective.defaultTexture)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(objective.name); GameTooltip:AddLine(objective.status or "Objective",0.82,0.82,0.82,true); GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:RegisterForClicks("RightButtonUp")
    button:SetScript("OnClick", function(self, clickButton)
        if clickButton ~= "RightButton" then return end
        if ZurkMapsPlayerIcons then
            local testPlayers=GetAVTestPlayersUnderMouse()
            if testPlayers and ZurkMapsPlayerIcons.OpenAssignmentMenuForTestPlayers(self,testPlayers) then return end
            local friendlyUnits=GetFriendlyPlayerMouseoverUnits()
            if friendlyUnits and ZurkMapsPlayerIcons.OpenAssignmentMenuForUnits(self,friendlyUnits) then return end
        end
        if ZurkMapsOptions then ZurkMapsOptions.OpenMapMenu("AV",self) end
    end)
    objectiveButtons[objective.id]=button
end
UpdateObjectiveScale()

local function ResetObjectivesToInitial()
    for _, objective in ipairs(OBJECTIVES) do
        objective.currentTexture=objective.defaultTexture
        objective.status=objective.initialStatus or "Initial control"
        objective._zurkDestroyedKnown=nil
        local resetButton=objectiveButtons[objective.id]
        if resetButton and resetButton._zurkTowerFire then
            resetButton._zurkTowerFire:SetScript("OnUpdate", nil)
            resetButton._zurkTowerFire:Hide()
        end
        ApplyObjectiveTexture(objectiveButtons[objective.id].icon, objective, objective.defaultTexture)
    end
end

local function GetAVObjectiveStatusLabel(objective, textureIndex, description)
    if type(description)=="string" and description~="" then return description end
    textureIndex=tonumber(textureIndex)
    if objective and objective.kind=="tower" and IsDestroyedTowerState(objective, textureIndex, description) then return "Destroyed" end
    if textureIndex==7 then return "Neutral / Unclaimed" end
    if textureIndex==9 then return "Horde controlled" end
    if textureIndex==10 then return "Alliance controlled" end
    if textureIndex==12 then return "Horde controlled" end
    if textureIndex==14 then return "Alliance controlled" end
    -- Contested/assaulted POI textures vary a little between Classic branches.
    -- The native icon is authoritative even when a branch supplies no text label.
    if textureIndex then return "Contested / live objective" end
    return objective and objective.status or "Objective"
end

local function ApplyLiveObjectiveState(objective, textureIndex, description)
    if not objective then return false end
    textureIndex=tonumber(textureIndex)
    if not textureIndex then return false end
    local destroyedNow=IsDestroyedTowerState(objective, textureIndex, description)
    if objective.kind=="tower" then
        if objective._zurkDestroyedKnown == nil then
            objective._zurkDestroyedKnown = destroyedNow
        elseif destroyedNow and not objective._zurkDestroyedKnown then
            objective._zurkDestroyedKnown = true
            PlayTowerDestroyedEffect(objective)
        else
            objective._zurkDestroyedKnown = destroyedNow
        end
    end
    objective.currentTexture=textureIndex
    objective.status=GetAVObjectiveStatusLabel(objective, textureIndex, description)
    local button=objectiveButtons[objective.id]
    if button and button.icon then
        ApplyObjectiveTexture(button.icon, objective, textureIndex)
    end
    return true
end

local function RefreshObjectives()
    if not IsInAlteracValley() then return end

    local calibrationByID={}
    local function AddCalibrationSample(objective,mapX,mapY)
        mapX,mapY=tonumber(mapX),tonumber(mapY)
        if not objective or not mapX or not mapY or mapX<0 or mapX>1 or mapY<0 or mapY>1 then return end
        calibrationByID[objective.id]={
            rawX=mapX,rawY=mapY,
            targetX=objective.x/100,targetY=objective.y/100,
        }
    end

    -- Legacy battlefield landmarks provide both objective state and, on Classic
    -- clients that expose it, the native map coordinates used by player blips.
    if type(GetNumMapLandmarks)=="function" and type(GetMapLandmarkInfo)=="function" then
        if type(SetMapToCurrentZone)=="function" then pcall(SetMapToCurrentZone) end
        local okCount,count=pcall(GetNumMapLandmarks)
        if okCount and type(count)=="number" then
            for i=1,count do
                local values={pcall(GetMapLandmarkInfo,i)}
                if values[1] then
                    local name,description,textureIndex,mapX,mapY
                    -- Most Classic clients: name, description, textureIndex, x, y...
                    -- Some branches insert a numeric landmark type before name.
                    if type(values[2])=="number" then
                        name,description,textureIndex=values[3],values[4],values[5]
                        mapX,mapY=values[6],values[7]
                    else
                        name,description,textureIndex=values[2],values[3],values[4]
                        mapX,mapY=values[5],values[6]
                    end
                    local objective=FindObjective(name)
                    if objective then
                        ApplyLiveObjectiveState(objective, textureIndex, description)
                        AddCalibrationSample(objective,mapX,mapY)
                    end
                end
            end
        end
    end

    -- Area POIs are a second source of native positions. Prefer them when the
    -- branch supplies them because their Vector2D positions are the same map
    -- coordinate system consumed by C_Map.GetPlayerMapPosition.
    local mapID=GetAVUiMapID()
    if mapID and C_AreaPoiInfo
        and type(C_AreaPoiInfo.GetAreaPOIForMap)=="function"
        and type(C_AreaPoiInfo.GetAreaPOIInfo)=="function" then
        local okIDs,poiIDs=pcall(C_AreaPoiInfo.GetAreaPOIForMap,mapID)
        if okIDs and type(poiIDs)=="table" then
            for _,poiID in ipairs(poiIDs) do
                local okInfo,info=pcall(C_AreaPoiInfo.GetAreaPOIInfo,mapID,poiID)
                if okInfo and type(info)=="table" then
                    local objective=FindObjective(info.name)
                    if objective then
                        ApplyLiveObjectiveState(objective, info.textureIndex, info.description)
                        local mapX,mapY=GetAVVectorPositionXY(info.position)
                        AddCalibrationSample(objective,mapX,mapY)
                    end
                end
            end
        end
    end

    local calibrationSamples={}
    for _,sample in pairs(calibrationByID) do calibrationSamples[#calibrationSamples+1]=sample end
    if UpdateAVFriendlyPositionCalibration(calibrationSamples) then
        ApplyFriendlyPositionGeometry()
        if ZurkMapsAVLieutenants and ZurkMapsAVLieutenants.RefreshNativePositionGeometry then
            ZurkMapsAVLieutenants.RefreshNativePositionGeometry()
        end
        if friendlyPlayersFrame and friendlyPlayersFrame:IsShown() then
            pcall(friendlyPlayersFrame.UpdatePlayerPins,friendlyPlayersFrame)
            if AVMapRank then AVMapRank.UpdateBlips() end
        end
        UpdateLivePlayerHitButtons()
    end
end

local refreshFrame=CreateFrame("Frame", nil, frame)
refreshFrame.elapsed=0
refreshFrame:SetScript("OnUpdate", function(self,elapsed)
    self.elapsed=self.elapsed+elapsed
    if self.elapsed<0.5 then return end
    self.elapsed=0
    if frame:IsShown() then RefreshObjectives() end
end)

local wasInAVForObjectives=false
local function UpdateVisibility()
    local inAV=IsInAlteracValley()
    if wasInAVForObjectives and not inAV then
        ResetObjectivesToInitial()
        ClearFriendlyPlayerTooltip()
    end
    wasInAVForObjectives=inAV
    if avTestMode then
        frame:Show()
    elseif manualVisibility=="show" then
        frame:Show()
    elseif manualVisibility=="hide" then
        frame:Hide()
    elseif inAV then
        frame:Show()
    else
        frame:Hide()
    end

    ApplyHonorBarVisibility()

    if avTestMode then
        if friendlyPlayersFrame then friendlyPlayersFrame:Hide() end
        UpdateAVTestBlips()
    elseif inAV and frame:IsShown() and friendlyPlayersFrameAvailable then
        HideAVTestBlips()
        if ConfigureFriendlyPlayerDots() then friendlyPlayersFrame:Show() end
    else
        if friendlyPlayersFrame then friendlyPlayersFrame:Hide() end
        HideAVTestBlips()
    end

    if frame:IsShown() then RefreshObjectives() end
end
local function ResetLayout()
    frame:ClearAllPoints(); frame:SetPoint("CENTER",UIParent,"CENTER",0,0); frame:SetScale(DEFAULT_SCALE); UpdateHeaderGeometry(DEFAULT_SCALE); UpdateObjectiveScale(); if ZurkMapsAVLieutenants and ZurkMapsAVLieutenants.RefreshScale then ZurkMapsAVLieutenants.RefreshScale() end; SaveLayout()
end

SLASH_AVCALLOUTS1="/av"
SlashCmdList["AVCALLOUTS"]=function(msg)
    msg=string.lower((msg or ""):match("^%s*(.-)%s*$"))
    if msg=="show" then manualVisibility="show"; UpdateVisibility(); print("|cff33ff99Zurk Maps|r AV map shown.")
    elseif msg=="hide" then manualVisibility="hide"; UpdateVisibility(); print("|cff33ff99Zurk Maps|r AV map hidden.")
    elseif msg=="reset" then ResetLayout(); print("|cff33ff99Zurk Maps|r AV position and size reset.")
    elseif msg=="refresh" then RefreshObjectives(); print("|cff33ff99Zurk Maps|r AV objectives refreshed.")
    elseif msg=="test" then SetTestMode(true); UpdateVisibility(); print("|cff33ff99Zurk Maps|r AV test mode enabled.")
    elseif msg=="test off" or msg=="test clear" then SetTestMode(false); UpdateVisibility(); print("|cff33ff99Zurk Maps|r AV test mode disabled.")
    else print("|cff33ff99Zurk Maps|r AV commands: |cffffff00/av show|r, |cffffff00/av hide|r, |cffffff00/av reset|r, |cffffff00/av refresh|r, |cffffff00/av test|r, |cffffff00/av test off|r") end
end

if ZurkMapsOptions then
    ZurkMapsOptions.RegisterMap("AV", {
        title="Alterac Valley",
        db=ZurksAVCalloutMapDB,
        closeCommand="hide",
        runCommand=function(command) SlashCmdList["AVCALLOUTS"](command or "") end,
        isTestModeActive=function() return IsTestModeActive() end,
        isHonorBarVisible=function() return IsHonorBarVisible() end,
        setHonorBarVisible=function(value) SetHonorBarVisible(value) end,
        getHonorBarMode=function() return GetHonorBarMode() end,
        setHonorBarMode=function(mode) if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMode then ZurkMapsHonorWidget.SetMode(mode, "AV") end end,
        isHonorBarUnlocked=function() return IsHonorBarUnlocked() end,
        setHonorBarUnlocked=function(value) SetHonorBarUnlocked(value) end,
        commands={
            {label="Hide Map",command="hide"},
            {label="Reset Position & Size",command="reset"},
            {label="Start Test",command="test"},
            {label="Stop Test",command="test off"},
        }
    })
end

frame:RegisterEvent("ADDON_LOADED"); frame:RegisterEvent("PLAYER_ENTERING_WORLD"); frame:RegisterEvent("ZONE_CHANGED_NEW_AREA"); frame:RegisterEvent("ZONE_CHANGED"); frame:RegisterEvent("ZONE_CHANGED_INDOORS"); frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE"); frame:RegisterEvent("AREA_POIS_UPDATED")
frame:SetScript("OnEvent", function(self,event,...)
    if event=="ADDON_LOADED" then local loaded=...; if loaded==addonName then RestoreLayout(); ApplyHonorBarVisibility(); UpdateVisibility() end; return end
    if event=="UPDATE_BATTLEFIELD_SCORE" or event=="AREA_POIS_UPDATED" then
        if IsInAlteracValley() then RefreshObjectives() end
        return
    end
    UpdateVisibility()
end)
