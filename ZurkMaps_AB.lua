local addonName = ...

local MAP_WIDTH = 400
local MAP_HEIGHT = 400
local MOVE_HANDLE_HEIGHT = 22
local MOVE_HANDLE_FONT_SIZE = 11
local TITLE_PLAQUE_WIDTH = 184
local MAP_ALPHA = 0.72
local PANE_TEXT_R, PANE_TEXT_G, PANE_TEXT_B = 0.72, 0.66, 0.50
local BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B = 0.84, 0.56, 0.31

ZurksABCalloutMapDB = ZurksABCalloutMapDB or {}
if ZurksABCalloutMapDB.showHonorBar == nil then ZurksABCalloutMapDB.showHonorBar = true end

local hoveredZone = nil
local isMoving = false
local resizing = false
local hoverAccumulator = 0
local manualVisibility = nil
local pendingVisibilityUpdate = false
local ConfigureFriendlyPlayerDots = nil
local ConfigureContestTimerScale = nil
local ConfigureBattlecryPanel = nil
local RefreshBaseNodes = nil
local hoveredBaseNode = nil
local hoveredContestTimerFrame = nil
local contestedBaseStates = {}
local contestedBaseVisuals = {}
local contestedTestMode = false
local abTestMode = false
local abTestBaseNodeStates = {}
local UpdateABTestBlips = nil
local ShowABTestBlips = nil
local HideABTestBlips = nil
local RandomizeABTestPlayers = nil
local function ShowContestTimerTooltip(baseNode)
    if not baseNode then
        return
    end

    GameTooltip:Hide()
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:SetText(baseNode.name)
    GameTooltip:AddLine("Click to report TIME remaining", 0.72, 0.66, 0.50)
    GameTooltip:Show()
end

local UpdateContestedBaseState = nil
local AB_CONTEST_FALLBACK_SECONDS = 64

-- Mirrors HotspotGeometry_v28.json. Road highlights 5-8 were rebuilt from scratch
-- by isolating the actual road pixels underneath the user's markup. Their visible
-- highlights stay road-width while separate path-based hit areas remain generous.
-- Overlay colors now use the approved mockup-inspired palette, with all roads
-- sharing one unified spring-green highlight color.
local ZONES = {
    {
        id = "STABLES",
        isBase = true,
        name = "Stables",
        calloutLocation = "ST",
        calloutStyle = "incoming",
        points = {
            {35.20, 16.30}, {32.90, 14.90}, {29.90, 14.80}, {22.20, 18.10},
            {11.90, 25.30}, {11.10, 30.10}, {13.30, 33.40}, {15.90, 34.60},
            {29.40, 37.20}, {33.40, 36.80}, {36.80, 33.70}, {38.10, 29.80},
        },
    },
    {
        id = "GOLD_MINE",
        isBase = true,
        name = "Gold Mine",
        calloutLocation = "GM",
        calloutStyle = "incoming",
        points = {
            {52.30, 21.10}, {51.40, 25.90}, {64.30, 37.30}, {71.40, 49.50},
            {75.80, 50.10}, {81.70, 46.70}, {82.10, 29.60}, {84.00, 20.60},
            {74.00, 18.50}, {68.30, 21.90},
        },
    },
    {
        id = "LUMBER_MILL",
        isBase = true,
        name = "Lumber Mill",
        calloutLocation = "LM",
        calloutStyle = "incoming",
        points = {
            {22.30, 57.50}, {20.40, 60.40}, {20.00, 65.90}, {22.30, 70.00},
            {22.80, 76.00}, {24.60, 79.50}, {30.90, 82.90}, {35.30, 83.90},
            {47.80, 80.70}, {48.80, 74.40}, {47.10, 71.90}, {42.10, 71.90},
            {34.90, 68.30}, {29.70, 61.40}, {28.90, 55.70}, {24.60, 56.00},
        },
    },
    {
        id = "BLACKSMITH",
        isBase = true,
        name = "Blacksmith",
        calloutLocation = "BS",
        calloutStyle = "incoming",
        points = {
            {45.90, 39.50}, {43.90, 40.70}, {42.20, 43.30}, {40.70, 51.10},
            {44.70, 57.60}, {48.00, 59.40}, {52.70, 60.50}, {55.00, 59.50},
            {57.30, 56.50}, {57.70, 49.40}, {51.80, 39.00},
        },
    },
    {
        id = "FARM",
        isBase = true,
        name = "Farm",
        calloutLocation = "Farm",
        calloutStyle = "incoming",
        points = {
            {86.80, 66.70}, {82.30, 61.60}, {74.60, 61.80}, {70.70, 63.90},
            {65.00, 64.90}, {59.50, 69.00}, {57.10, 77.70}, {58.70, 79.70},
            {67.50, 82.30}, {71.40, 86.00}, {73.80, 86.10}, {80.10, 82.50},
            {85.20, 76.70}, {87.20, 73.00},
        },
    },
    {
        id = "BS_BRIDGE_ST",
        name = "North Bridge",
        calloutLocation = "North Bridge",
        calloutStyle = "at",
        points = {
            {47.30, 28.40}, {45.70, 31.20}, {45.80, 38.60}, {51.30, 38.60},
            {54.10, 35.40}, {54.00, 31.40}, {51.70, 28.00},
        },
    },
    {
        id = "BS_GY_WATER",
        name = "BS GY Water",
        calloutLocation = "BS GY Water",
        calloutStyle = "at",
        points = {
            {57.10, 43.00}, {56.30, 45.50}, {57.10, 58.30}, {61.80, 58.90},
            {65.20, 55.80}, {65.00, 49.60}, {62.60, 42.80},
        },
    },
    {
        id = "BS_LM_FARM_INTERSECTION",
        name = "BS/LM/Farm Intersection",
        calloutLocation = "BS/LM/Farm Intersection",
        calloutStyle = "at",
        points = {
            {48.80, 59.80}, {47.00, 61.60}, {47.50, 72.80}, {50.60, 75.40},
            {54.60, 75.10}, {57.50, 71.80}, {59.90, 66.70}, {57.40, 64.30},
            {54.70, 61.60},
        },
    },
    {
        id = "BS_LM_WATER",
        name = "BS LM Water",
        calloutLocation = "BS LM Water",
        calloutStyle = "at",
        points = {
            {32.40, 42.00}, {31.20, 44.20}, {31.70, 52.60}, {34.20, 55.40},
            {39.80, 55.50}, {40.30, 44.30}, {38.00, 41.80},
        },
    },
    {
        id = "ROAD_ST_TO_LM",
        name = "Road from ST to LM",
        calloutLocation = "road from ST to LM",
        calloutStyle = "road_spotted",
        hitRadius = 2.60,
        hitPaths = {
            {
                {24.20, 36.00}, {24.10, 39.00}, {24.70, 42.00}, {25.80, 44.50},
                {27.00, 46.80}, {27.20, 48.80}, {26.50, 50.80}, {25.30, 53.00},
                {24.10, 55.20}, {23.40, 56.50},
            },
        },
    },
    {
        id = "ROAD_ST_TO_GM",
        name = "Road from ST to GM",
        calloutLocation = "road from ST to GM",
        calloutStyle = "road_spotted",
        hitRadius = 2.60,
        hitPaths = {
            {
                {51.00, 24.00}, {48.50, 23.80}, {46.00, 23.90}, {43.50, 24.00},
                {41.00, 24.40}, {39.20, 25.00}, {38.00, 26.00}, {37.80, 26.80},
                {38.70, 27.70}, {40.50, 28.40}, {42.60, 28.90}, {44.80, 29.10},
                {47.10, 29.20},
            },
        },
    },
    {
        id = "ROAD_ABOVE_GM",
        name = "Road Above GM",
        calloutLocation = "road above GM",
        calloutStyle = "road_spotted",
        hitRadius = 2.60,
        hitPaths = {
            {
                {55.50, 32.00}, {57.00, 33.20}, {58.50, 35.00}, {60.00, 37.20},
                {61.50, 39.80}, {63.00, 42.50}, {64.50, 45.30}, {66.00, 48.20},
                {67.50, 50.70}, {69.00, 52.90}, {70.80, 54.30},
            },
        },
    },
    {
        id = "ROAD_GM_TO_FARM",
        name = "Road from GM to Farm",
        calloutLocation = "road from GM to Farm",
        calloutStyle = "road_spotted",
        hitRadius = 2.60,
        hitPaths = {
            {
                {72.10, 49.50}, {72.70, 51.70}, {73.40, 54.00}, {74.10, 56.20},
                {74.80, 58.50}, {75.50, 60.50}, {76.30, 62.00},
            },
            {
                {70.50, 53.40}, {71.60, 54.00}, {72.70, 54.70}, {73.60, 55.40},
            },
        },
    },
    {
        id = "ROAD_BELOW_LM",
        name = "Road Below LM",
        calloutLocation = "road below LM",
        calloutStyle = "road_spotted",
        hitRadius = 2.60,
        hitPaths = {
            {
                {27.91, 50.16}, {29.74, 52.23}, {31.90, 55.26}, {33.65, 57.02},
                {37.24, 59.97}, {38.76, 60.85}, {40.03, 62.04}, {44.74, 65.47},
                {45.93, 66.03}, {46.17, 66.43},
            },
        },
    },
}

-- Base-node positions are fixed overlays on Zurk's custom AB artwork. Their
-- icon texture/state is supplied by Blizzard's live battleground landmark data.
local BASE_NODES = {
    {
        id = "STABLES",
        name = "Stables",
        callout = "ST",
        x = 29.09,
        y = 28.38,
        neutralTextureIndex = 36,
    },
    {
        id = "GOLD_MINE",
        name = "Gold Mine",
        callout = "GM",
        x = 71.55,
        y = 28.46,
        neutralTextureIndex = 16,
    },
    {
        id = "BLACKSMITH",
        name = "Blacksmith",
        callout = "BS",
        x = 49.43,
        y = 50.87,
        neutralTextureIndex = 26,
    },
    {
        id = "LUMBER_MILL",
        name = "Lumber Mill",
        callout = "LM",
        x = 29.54,
        y = 71.62,
        neutralTextureIndex = 21,
    },
    {
        id = "FARM",
        name = "Farm",
        callout = "Farm",
        x = 71.31,
        y = 70.24,
        neutralTextureIndex = 31,
    },
}

local BASE_NODE_BY_ID = {}
for _, baseNode in ipairs(BASE_NODES) do
    BASE_NODE_BY_ID[baseNode.id] = baseNode
end

local function Report(message)
    if ZurkMapsOptions and ZurkMapsOptions.SendCallout then
        ZurkMapsOptions.SendCallout("AB", message)
        return
    end

    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "pvp" then
        SendChatMessage(message, "INSTANCE_CHAT")
    else
        SendChatMessage(message, "SAY")
    end
end

local AB_UI_MAP_ID_FALLBACK = 1366

-- Blizzard's normalized AB player coordinates are based on the full native
-- battleground map, while Zurk Maps uses a tighter crop of that artwork.
-- Start with the previous hand-calibrated transform, then replace it in live AB
-- with a transform fitted against Blizzard's own five objective POI positions.
-- That keeps teammate blips tied to the same coordinate space as our fixed
-- Stables/GM/BS/LM/Farm overlays instead of relying on screenshot guesswork.
local abFriendlyPositionGeometry = {
    xScale = 2.00,
    xOffset = -0.48,
    yScale = 1.35,
    yOffset = -0.09,
    calibrated = false,
}
local abFriendlyCalibrationSamples = {}

local function IsInArathiBasin()
    local instanceName = nil
    if GetInstanceInfo then
        instanceName = GetInstanceInfo()
    end

    local realZone = GetRealZoneText and GetRealZoneText() or nil
    local zone = GetZoneText and GetZoneText() or nil

    return instanceName == "Arathi Basin"
        or realZone == "Arathi Basin"
        or zone == "Arathi Basin"
end

local function GetABUiMapID()
    if IsInArathiBasin() then
        if MapUtil and type(MapUtil.GetDisplayableMapForPlayer) == "function" then
            local ok, mapID = pcall(MapUtil.GetDisplayableMapForPlayer)
            if ok and type(mapID) == "number" then
                return mapID
            end
        end

        if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
            local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
            if ok and type(mapID) == "number" then
                return mapID
            end
        end
    end

    return AB_UI_MAP_ID_FALLBACK
end

local function GetVectorPositionXY(position)
    if not position then
        return nil, nil
    end

    local getXY = nil
    local okMethod, method = pcall(function() return position.GetXY end)
    if okMethod then
        getXY = method
    end
    if type(getXY) == "function" then
        local ok, x, y = pcall(getXY, position)
        if ok and type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    local okX, x = pcall(function() return position.x end)
    local okY, y = pcall(function() return position.y end)
    if okX and okY and type(x) == "number" and type(y) == "number" then
        return x, y
    end

    return nil, nil
end

local function FitABFriendlyPositionAxis(samples, rawKey, targetKey)
    local count = 0
    local sumRaw, sumTarget = 0, 0
    local sumRawSquared, sumRawTarget = 0, 0

    for _, sample in pairs(samples) do
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

    if count < 2 then
        return nil, nil
    end

    local denominator = (count * sumRawSquared) - (sumRaw * sumRaw)
    if math.abs(denominator) < 0.000001 then
        return nil, nil
    end

    local scale = ((count * sumRawTarget) - (sumRaw * sumTarget)) / denominator
    local offset = (sumTarget - (scale * sumRaw)) / count
    return scale, offset
end

local function UpdateABFriendlyPositionCalibration(poiData)
    if type(poiData) ~= "table" then
        return false
    end

    local samples = {}
    for _, baseNode in ipairs(BASE_NODES) do
        local data = poiData[baseNode.id]
        local mapX = data and tonumber(data.mapX) or nil
        local mapY = data and tonumber(data.mapY) or nil
        if mapX and mapY then
            samples[baseNode.id] = {
                rawX = mapX,
                rawY = mapY,
                targetX = baseNode.x / 100,
                targetY = baseNode.y / 100,
            }
        end
    end

    local xScale, xOffset = FitABFriendlyPositionAxis(samples, "rawX", "targetX")
    local yScale, yOffset = FitABFriendlyPositionAxis(samples, "rawY", "targetY")
    if not xScale or not xOffset or not yScale or not yOffset then
        return false
    end

    -- Ignore bad API data rather than snapping the entire overlay off-map.
    if xScale < 0.50 or xScale > 3.00
        or yScale < 0.50 or yScale > 3.00
        or xOffset < -1.00 or xOffset > 1.00
        or yOffset < -1.00 or yOffset > 1.00 then
        return false
    end

    local geometry = abFriendlyPositionGeometry
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
    abFriendlyCalibrationSamples = samples

    if changed and ConfigureFriendlyPlayerDots then
        ConfigureFriendlyPlayerDots()
    end

    return true
end

local function GetEnemyFactionToken()
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil

    if faction == "Alliance" then
        return "horde"
    elseif faction == "Horde" then
        return "ally"
    end

    return "enemy"
end

local function IsBaseHeldOrAssaultedByPlayerFaction(zone)
    if not zone or not zone.isBase then
        return false
    end

    local baseNode = BASE_NODE_BY_ID[zone.id]
    if not baseNode then
        return false
    end

    local playerFaction = UnitFactionGroup and UnitFactionGroup("player") or nil
    if playerFaction ~= "Alliance" and playerFaction ~= "Horde" then
        return false
    end

    -- While a contest timer is active, the faction doing the assault owns the
    -- callout context: enemies there are "incoming" for that faction because
    -- it is actively trying to hold the capture. This also makes /ab test use
    -- the same rule as live AB.
    local contestState = contestedBaseStates[zone.id]
    if contestState and contestState.active and contestState.faction then
        return contestState.faction == playerFaction
    end

    -- Test mode owns its own base-state table. Read it directly instead of relying
    -- on currentTextureIndex, which can briefly reflect a previously rendered/live
    -- node. Live mode continues to use Blizzard's current node state.
    local textureIndex = nil
    if abTestMode then
        textureIndex = tonumber(abTestBaseNodeStates[zone.id])
    end
    textureIndex = textureIndex or tonumber(baseNode.currentTextureIndex) or baseNode.neutralTextureIndex

    local offset = textureIndex - baseNode.neutralTextureIndex

    -- Blizzard AB node texture offsets:
    --   0 = neutral, 1 = Alliance assaulting, 2 = Alliance controlled,
    --   3 = Horde assaulting, 4 = Horde controlled.
    if playerFaction == "Alliance" then
        return offset == 1 or offset == 2
    end

    return offset == 3 or offset == 4
end

local function FormatZoneCallout(zone, dropdownSelection)
    if not zone or not dropdownSelection then
        return nil
    end

    if dropdownSelection == "Safe" and zone.isBase then
        return zone.name .. " safe."
    elseif dropdownSelection == "Get OUT" and not zone.isBase then
        return "Stop fighting at " .. zone.name .. "! You're needed elsewhere"
    end

    local enemyFaction = GetEnemyFactionToken()
    local location = zone.calloutLocation or zone.name

    if zone.calloutStyle == "at" then
        return dropdownSelection .. " " .. enemyFaction .. " at " .. location .. "!"
    elseif zone.calloutStyle == "road_spotted" then
        return dropdownSelection .. " " .. enemyFaction .. " spotted on the " .. location .. "!"
    elseif zone.isBase and not IsBaseHeldOrAssaultedByPlayerFaction(zone) then
        return dropdownSelection .. " " .. enemyFaction .. " visible at " .. location .. "!"
    end

    return dropdownSelection .. " " .. enemyFaction .. " incoming " .. location .. "!"
end

local frame = CreateFrame("Frame", "ZurksABCalloutMapFrame", UIParent)
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
-- Slightly overscan the bordered map texture so it fully seats under the frame.
mapTexture:SetPoint("TOPLEFT", map, "TOPLEFT", -3, 3)
mapTexture:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 3, -3)
mapTexture:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\ABMap")
mapTexture:SetAlpha(MAP_ALPHA)

local mapBorder = CreateFrame(
    "Frame",
    nil,
    map,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
mapBorder:SetPoint("TOPLEFT", map, "TOPLEFT", -5, 5)
mapBorder:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 5, -5)

if mapBorder.SetBackdrop then
    mapBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
    })
    mapBorder:SetBackdropBorderColor(BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B, 0.98)
end

mapBorder:EnableMouse(false)
mapBorder:SetFrameLevel(map:GetFrameLevel() + 10)

if ZurkMapsABHonor and ZurkMapsABHonor.Create then
    local abHonorBar = ZurkMapsABHonor.Create(mapBorder, frame, MAP_HEIGHT, {
        battlegroundName = "Arathi Basin",
        db = ZurksABCalloutMapDB,
        mapKey = "AB",
        runLabelSingular = "AB",
        runLabelPlural = "ABs",
        getAverageHonor = function(limit)
            if ZurkMapsBGHistory and ZurkMapsBGHistory.GetAverageHonor then
                return ZurkMapsBGHistory.GetAverageHonor("Arathi Basin", limit)
            end
            return nil, 0
        end,
        sendBGCallout = function(message) Report(message) end,
    })
    if abHonorBar and ZurkMapsHonorWidget and ZurkMapsHonorWidget.Attach then
        ZurkMapsHonorWidget.Attach(abHonorBar, ZurkMapsABHonor, { mapKey = "AB", mapFrame = frame })
    end
end

frame.GetABHonorBarMode = function()
    return ZurkMapsHonorWidget and ZurkMapsHonorWidget.GetMode and ZurkMapsHonorWidget.GetMode() or "ATTACHED"
end

frame.IsABHonorBarVisible = function()
    return frame.GetABHonorBarMode() ~= "OFF"
end

frame.ApplyABHonorBarVisibility = function()
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMapShown then
        ZurkMapsHonorWidget.SetMapShown("AB", frame:IsShown())
    elseif ZurkMapsABHonor and ZurkMapsABHonor.SetVisible then
        ZurkMapsABHonor.SetVisible(frame.IsABHonorBarVisible())
    end
end

frame.SetABHonorBarVisible = function(flag)
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMode then
        if flag then
            if ZurkMapsHonorWidget.GetMode() == "OFF" then ZurkMapsHonorWidget.SetMode("ATTACHED", "AB") end
        else
            ZurkMapsHonorWidget.SetMode("OFF", "AB")
        end
    end
end

frame.IsABHonorBarUnlocked = function()
    return ZurkMapsHonorWidget and ZurkMapsHonorWidget.IsUnlocked and ZurkMapsHonorWidget.IsUnlocked() or false
end

frame.SetABHonorBarUnlocked = function(flag)
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetGlobalUnlocked then ZurkMapsHonorWidget.SetGlobalUnlocked(flag) end
end

-- Same one-texture-at-a-time hotspot highlighting approach as the WSG map.
local highlightTexture = map:CreateTexture(nil, "ARTWORK")
highlightTexture:SetAllPoints()
highlightTexture:Hide()

local moveHandle = CreateFrame(
    "Frame",
    nil,
    frame,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
moveHandle:SetSize(TITLE_PLAQUE_WIDTH, MOVE_HANDLE_HEIGHT)
moveHandle:SetPoint("BOTTOM", map, "TOP", 0, 0)
moveHandle:SetFrameLevel(mapBorder:GetFrameLevel() + 5)
moveHandle:EnableMouse(true)
moveHandle:RegisterForDrag("LeftButton")

-- Same bronze filigree title plaque used by Zurk's WSG Callout Map.
moveHandle.bg = moveHandle:CreateTexture(nil, "BACKGROUND")
moveHandle.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
moveHandle.bg:SetVertexColor(0.018, 0.012, 0.008, 0.97)

moveHandle.border = CreateFrame("Frame", nil, moveHandle)
moveHandle.border:SetAllPoints(moveHandle)
moveHandle.border:SetFrameLevel(moveHandle:GetFrameLevel() + 1)
moveHandle.border:EnableMouse(false)

moveHandle.borderR = BOX_BORDER_R
moveHandle.borderG = BOX_BORDER_G
moveHandle.borderB = BOX_BORDER_B
moveHandle.filigreeExtraHeight = 2
moveHandle.filigreeOverlap = 4
moveHandle.trimHeight = 8

moveHandle.ApplyBorderAtlas = function(self, texture, atlasName, useAtlasSize)
    texture:SetVertexColor(self.borderR, self.borderG, self.borderB, 0.97)
    if texture.SetAtlas then
        texture:SetAtlas(atlasName, useAtlasSize and true or false)
    end
end

moveHandle.topTrim = moveHandle.border:CreateTexture(nil, "BORDER")
moveHandle:ApplyBorderAtlas(moveHandle.topTrim, "battlefieldminimap-border-top")

moveHandle.bottomTrim = moveHandle.border:CreateTexture(nil, "BORDER")
moveHandle:ApplyBorderAtlas(moveHandle.bottomTrim, "battlefieldminimap-border-bottom")

moveHandle.leftTrim = moveHandle.border:CreateTexture(nil, "OVERLAY")
moveHandle:ApplyBorderAtlas(moveHandle.leftTrim, "PetJournal-BattleSlotTitle-Left", true)

moveHandle.rightTrim = moveHandle.border:CreateTexture(nil, "OVERLAY")
moveHandle:ApplyBorderAtlas(moveHandle.rightTrim, "PetJournal-BattleSlotTitle-Right", true)

moveHandle.filigreeAspect = 1
if moveHandle.leftTrim:GetHeight() and moveHandle.leftTrim:GetHeight() > 0 then
    moveHandle.filigreeAspect = moveHandle.leftTrim:GetWidth() / moveHandle.leftTrim:GetHeight()
end

if not moveHandle.topTrim.SetAtlas then
    moveHandle.fallbackTop = moveHandle.border:CreateTexture(nil, "OVERLAY")
    moveHandle.fallbackTop:SetColorTexture(moveHandle.borderR, moveHandle.borderG, moveHandle.borderB, 1)

    moveHandle.fallbackBottom = moveHandle.border:CreateTexture(nil, "OVERLAY")
    moveHandle.fallbackBottom:SetColorTexture(moveHandle.borderR, moveHandle.borderG, moveHandle.borderB, 1)
end

moveHandle.text = moveHandle:CreateFontString(nil, "OVERLAY")
moveHandle.text:SetPoint("CENTER", moveHandle, "CENTER", 0, 0)
moveHandle.text:SetFont("Fonts\\FRIZQT__.TTF", MOVE_HANDLE_FONT_SIZE, "")
moveHandle.text:SetTextColor(PANE_TEXT_R, PANE_TEXT_G, PANE_TEXT_B, 1)
moveHandle.text:SetText("Zurk Maps")

moveHandle.UpdateGeometry = function(self, compensationScale)
    local inv = 1 / compensationScale
    local filigreeHeight = (MOVE_HANDLE_HEIGHT + self.filigreeExtraHeight) * inv
    local filigreeWidth = filigreeHeight * self.filigreeAspect
    local filigreeOverlap = self.filigreeOverlap * inv
    local trimHeight = self.trimHeight * inv
    local topOffset = 2 * inv
    local bottomOffset = -2 * inv

    self.leftTrim:ClearAllPoints()
    self.leftTrim:SetPoint("RIGHT", self.border, "LEFT", filigreeOverlap, 0)
    self.leftTrim:SetSize(filigreeWidth, filigreeHeight)

    self.rightTrim:ClearAllPoints()
    self.rightTrim:SetPoint("LEFT", self.border, "RIGHT", -filigreeOverlap, 0)
    self.rightTrim:SetSize(filigreeWidth, filigreeHeight)

    local trimInset = math.max(0, filigreeOverlap - (1 * inv))

    self.bg:ClearAllPoints()
    self.bg:SetPoint("TOPLEFT", self.border, "TOPLEFT", 0, -1 * inv)
    self.bg:SetPoint("BOTTOMRIGHT", self.border, "BOTTOMRIGHT", 0, 1 * inv)

    self.topTrim:ClearAllPoints()
    self.topTrim:SetPoint("TOPLEFT", self.border, "TOPLEFT", trimInset, topOffset)
    self.topTrim:SetPoint("TOPRIGHT", self.border, "TOPRIGHT", -trimInset, topOffset)
    self.topTrim:SetHeight(trimHeight)

    self.bottomTrim:ClearAllPoints()
    self.bottomTrim:SetPoint("BOTTOMLEFT", self.border, "BOTTOMLEFT", trimInset, bottomOffset)
    self.bottomTrim:SetPoint("BOTTOMRIGHT", self.border, "BOTTOMRIGHT", -trimInset, bottomOffset)
    self.bottomTrim:SetHeight(trimHeight)

    if self.fallbackTop and self.fallbackBottom then
        self.fallbackTop:ClearAllPoints()
        self.fallbackTop:SetPoint("TOPLEFT", self.border, "TOPLEFT", 3 * inv, 0)
        self.fallbackTop:SetPoint("TOPRIGHT", self.border, "TOPRIGHT", -3 * inv, 0)
        self.fallbackTop:SetHeight(1 * inv)

        self.fallbackBottom:ClearAllPoints()
        self.fallbackBottom:SetPoint("BOTTOMLEFT", self.border, "BOTTOMLEFT", 3 * inv, 0)
        self.fallbackBottom:SetPoint("BOTTOMRIGHT", self.border, "BOTTOMRIGHT", -3 * inv, 0)
        self.fallbackBottom:SetHeight(1 * inv)
    end
end

local MIN_SCALE = 0.55
local MAX_SCALE = 2.00
local resizeStartX = 0
local resizeStartY = 0
local resizeStartScale = 1

local function UpdateMoveHandleScale(addonScale)
    -- Match the WSG plaque behavior: below 100% addon scale, keep the title
    -- and filigree readable instead of letting the ornament collapse.
    local compensationScale = math.min(addonScale, 1)

    moveHandle:SetWidth(TITLE_PLAQUE_WIDTH / compensationScale)
    moveHandle:SetHeight(MOVE_HANDLE_HEIGHT / compensationScale)
    moveHandle.text:SetFont(
        "Fonts\\FRIZQT__.TTF",
        MOVE_HANDLE_FONT_SIZE / compensationScale,
        ""
    )
    moveHandle:UpdateGeometry(compensationScale)

    if ConfigureFriendlyPlayerDots then
        ConfigureFriendlyPlayerDots()
    end
    if ConfigureContestTimerScale then
        ConfigureContestTimerScale(addonScale)
    end
    if ConfigureBattlecryPanel then
        ConfigureBattlecryPanel(addonScale)
    end
end

moveHandle:UpdateGeometry(1)

local function SaveLayout()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then
        ZurksABCalloutMapDB.point = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
    ZurksABCalloutMapDB.scale = frame:GetScale()
end

local function RestoreLayout()
    local savedScale = tonumber(ZurksABCalloutMapDB.scale) or 1
    savedScale = math.max(MIN_SCALE, math.min(MAX_SCALE, savedScale))
    frame:SetScale(savedScale)
    UpdateMoveHandleScale(savedScale)

    local p = ZurksABCalloutMapDB.point
    if p and p.point and p.relativePoint and p.x and p.y then
        frame:ClearAllPoints()
        frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    end
end

local function GetCursorUIPosition()
    local x, y = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    return x / uiScale, y / uiScale
end

local function StartMove()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    isMoving = true
    hoveredZone = nil
    highlightTexture:Hide()
    GameTooltip:Hide()
    frame:StartMoving()
end

local function StopMove()
    if not isMoving then
        return
    end

    frame:StopMovingOrSizing()
    isMoving = false
    SaveLayout()
end

moveHandle:SetScript("OnMouseDown", function()
    moveHandle.didDrag = false
end)
moveHandle:SetScript("OnDragStart", function()
    moveHandle.didDrag = true
    StartMove()
end)
moveHandle:SetScript("OnDragStop", StopMove)
moveHandle:SetScript("OnMouseUp", function(self, button)
    local didDrag = moveHandle.didDrag
    StopMove()
    if button == "RightButton" and not didDrag and ZurkMapsOptions then
        ZurkMapsOptions.OpenMapMenu("AB", self)
        return
    end
    if button == "LeftButton" and IsControlKeyDown() and not didDrag then
        if IsShiftKeyDown() and ZurkMapsPromos then
            ZurkMapsPromos.SendRandomPromo("AB")
        elseif ZurkMapsPromos then
            local promo = ZurkMapsPromos.GetHeaderPromo("AB")
            if ZurkMapsOptions and ZurkMapsOptions.SendHeaderShare then
                ZurkMapsOptions.SendHeaderShare(promo)
            else
                Report(promo)
            end
        end
    end
end)
moveHandle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:SetText("Drag here to move map")
    GameTooltip:AddLine("Right-click for options.", 0.95, 0.82, 0.28, true)
    GameTooltip:AddLine("CTRL+Click to share the addon in chat.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
moveHandle:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Keep the WSG behavior where Alt-dragging the map itself moves the addon.
local mapDragStarted = false
map:SetScript("OnDragStart", function()
    if IsAltKeyDown() then
        mapDragStarted = true
        StartMove()
    end
end)
map:SetScript("OnDragStop", function()
    StopMove()
end)

local function BeginResize()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    resizing = true
    resizeStartX, resizeStartY = GetCursorUIPosition()
    resizeStartScale = frame:GetScale()
    hoveredZone = nil
    highlightTexture:Hide()
    GameTooltip:Hide()
end

local function EndResize()
    if not resizing then
        return
    end

    resizing = false
    SaveLayout()
end

local resizeHandle = CreateFrame("Button", nil, map)
resizeHandle:SetSize(22, 22)
resizeHandle:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -1, 1)
resizeHandle:SetFrameLevel(mapBorder:GetFrameLevel() + 2)
resizeHandle:RegisterForDrag("LeftButton")
resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeHandle:GetNormalTexture():SetAlpha(0)
resizeHandle:GetHighlightTexture():SetAlpha(0)
resizeHandle:GetPushedTexture():SetAlpha(0)
resizeHandle._gripAlpha = 0
resizeHandle:SetScript("OnDragStart", BeginResize)
resizeHandle:SetScript("OnDragStop", EndResize)
resizeHandle:SetScript("OnMouseUp", EndResize)
resizeHandle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:SetText("Resize Zurk Maps")
    GameTooltip:Show()
end)
resizeHandle:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
resizeHandle:SetScript("OnUpdate", function(self, elapsed)
    local gripTarget = (frame:IsShown() and frame:IsMouseOver()) and 1 or 0
    if gripTarget > self._gripAlpha then
        self._gripAlpha = math.min(1, self._gripAlpha + ((elapsed or 0) / 0.2))
    elseif gripTarget < self._gripAlpha then
        self._gripAlpha = math.max(0, self._gripAlpha - ((elapsed or 0) / 0.1))
    end
    self:GetNormalTexture():SetAlpha(self._gripAlpha)
    self:GetHighlightTexture():SetAlpha(self._gripAlpha)
    self:GetPushedTexture():SetAlpha(self._gripAlpha)
    if not resizing then
        return
    end

    local x, y = GetCursorUIPosition()
    local dx = x - resizeStartX
    local dy = resizeStartY - y
    local scaleFromX = resizeStartScale + (dx / MAP_WIDTH)
    local scaleFromY = resizeStartScale + (dy / MAP_HEIGHT)
    local newScale = (scaleFromX + scaleFromY) / 2

    newScale = math.max(MIN_SCALE, math.min(MAX_SCALE, newScale))
    frame:SetScale(newScale)
    UpdateMoveHandleScale(newScale)
end)


-- WSG-style class Focus Callout, placed in the upper-right corner of the AB map.
local focusCallout = {
    BUTTON_SIZE = 45,
    MENU_WIDTH = 142,
    OPTION_HEIGHT = 23,
    MENU_PADDING = 5,
    classOptions = {
        PALADIN = { token = "PALADIN", name = "Paladin" },
        SHAMAN = { token = "SHAMAN", name = "Shaman" },
        PRIEST = { token = "PRIEST", name = "Priest" },
        DRUID = { token = "DRUID", name = "Druid" },
        MAGE = { token = "MAGE", name = "Mage" },
        WARLOCK = { token = "WARLOCK", name = "Warlock" },
        HUNTER = { token = "HUNTER", name = "Hunter" },
        ROGUE = { token = "ROGUE", name = "Rogue" },
        WARRIOR = { token = "WARRIOR", name = "Warrior" },
    },
    standardOrder = { "PRIEST", "DRUID", "MAGE", "WARLOCK", "HUNTER", "ROGUE", "WARRIOR" },
    classColorFallback = {
        WARRIOR = { 0.78, 0.61, 0.43 },
        PALADIN = { 0.96, 0.55, 0.73 },
        HUNTER = { 0.67, 0.83, 0.45 },
        ROGUE = { 1.00, 0.96, 0.41 },
        PRIEST = { 1.00, 1.00, 1.00 },
        SHAMAN = { 0.00, 0.44, 0.87 },
        MAGE = { 0.25, 0.78, 0.92 },
        WARLOCK = { 0.53, 0.53, 0.93 },
        DRUID = { 1.00, 0.49, 0.04 },
    },
    classIconFallback = {
        WARRIOR = { 0.00, 0.25, 0.00, 0.25 },
        MAGE = { 0.25, 0.50, 0.00, 0.25 },
        ROGUE = { 0.50, 0.75, 0.00, 0.25 },
        DRUID = { 0.75, 1.00, 0.00, 0.25 },
        HUNTER = { 0.00, 0.25, 0.25, 0.50 },
        SHAMAN = { 0.25, 0.50, 0.25, 0.50 },
        PRIEST = { 0.50, 0.75, 0.25, 0.50 },
        WARLOCK = { 0.75, 1.00, 0.25, 0.50 },
        PALADIN = { 0.00, 0.25, 0.50, 0.75 },
    },
}

function focusCallout:GetEnemyFactionSpecialClassToken()
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then
        return "SHAMAN"
    elseif faction == "Horde" then
        return "PALADIN"
    end
    return nil
end

function focusCallout:GetOrderedClassOptions()
    local options = {}
    local specialToken = self:GetEnemyFactionSpecialClassToken()
    if specialToken and self.classOptions[specialToken] then
        table.insert(options, self.classOptions[specialToken])
    end

    for _, token in ipairs(self.standardOrder) do
        if self.classOptions[token] then
            table.insert(options, self.classOptions[token])
        end
    end

    return options
end

function focusCallout:GetClassDisplayName(classInfo)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classInfo.token]) or classInfo.name
end

function focusCallout:CreateCrispIconBorder(button)
    local border = CreateFrame("Frame", nil, button)
    border:SetAllPoints()
    border:SetFrameLevel(button:GetFrameLevel() + 2)
    border:EnableMouse(false)

    local function Edge(point1, relativePoint1, x1, y1, point2, relativePoint2, x2, y2, width, height, r, g, b, a)
        local texture = border:CreateTexture(nil, "OVERLAY")
        texture:SetPoint(point1, border, relativePoint1, x1, y1)
        if point2 then
            texture:SetPoint(point2, border, relativePoint2, x2, y2)
        end
        if width then texture:SetWidth(width) end
        if height then texture:SetHeight(height) end
        texture:SetColorTexture(r, g, b, a)
        return texture
    end

    Edge("TOPLEFT", "TOPLEFT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, 0, nil, 2, 0.055, 0.035, 0.018, 0.68)
    Edge("BOTTOMLEFT", "BOTTOMLEFT", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, nil, 2, 0.055, 0.035, 0.018, 0.68)
    Edge("TOPLEFT", "TOPLEFT", 0, 0, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, 2, nil, 0.055, 0.035, 0.018, 0.68)
    Edge("TOPRIGHT", "TOPRIGHT", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, 2, nil, 0.055, 0.035, 0.018, 0.68)
    Edge("TOPLEFT", "TOPLEFT", 2, -2, "TOPRIGHT", "TOPRIGHT", -2, -2, nil, 2, 0.70, 0.52, 0.20, 0.92)
    Edge("BOTTOMLEFT", "BOTTOMLEFT", 2, 2, "BOTTOMRIGHT", "BOTTOMRIGHT", -2, 2, nil, 2, 0.70, 0.52, 0.20, 0.92)
    Edge("TOPLEFT", "TOPLEFT", 2, -2, "BOTTOMLEFT", "BOTTOMLEFT", 2, 2, 2, nil, 0.70, 0.52, 0.20, 0.92)
    Edge("TOPRIGHT", "TOPRIGHT", -2, -2, "BOTTOMRIGHT", "BOTTOMRIGHT", -2, 2, 2, nil, 0.70, 0.52, 0.20, 0.92)
    return border
end

function focusCallout:CloseMenu()
    if self.menu then self.menu:Hide() end
    if self.dismiss then self.dismiss:Hide() end
    if self.openHighlight then self.openHighlight:Hide() end

    if self.button and self.button:IsMouseOver() then
        self.icon:SetAlpha(1)
        self.border:SetAlpha(1)
    elseif self.icon and self.border then
        self.icon:SetAlpha(0.82)
        self.border:SetAlpha(0.96)
    end
end

function focusCallout:AnchorMenu()
    self.menu:SetScale(frame:GetScale())
    self.menu:ClearAllPoints()
    self.menu:SetPoint("TOPRIGHT", self.button, "BOTTOMRIGHT", 0, -2)
end

function focusCallout:RefreshOptions()
    local options = self:GetOrderedClassOptions()
    self.menu:SetHeight((self.OPTION_HEIGHT * #options) + (self.MENU_PADDING * 2))

    for i, option in ipairs(self.optionButtons) do
        local classInfo = options[i]
        if classInfo then
            local coords = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classInfo.token]) or self.classIconFallback[classInfo.token]
            if coords then
                option.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            end

            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classInfo.token]
            local fallback = self.classColorFallback[classInfo.token]
            if color then
                option.optionLabel:SetTextColor(color.r, color.g, color.b, 1)
            elseif fallback then
                option.optionLabel:SetTextColor(fallback[1], fallback[2], fallback[3], 1)
            else
                option.optionLabel:SetTextColor(1, 1, 1, 1)
            end

            local displayName = self:GetClassDisplayName(classInfo)
            option.optionLabel:SetText(displayName)
            option.classNameUpper = string.upper(displayName)
            option:Show()
        else
            option.classNameUpper = nil
            option:Hide()
        end
    end
end

focusCallout.button = CreateFrame("Button", nil, map)
focusCallout.button:SetSize(focusCallout.BUTTON_SIZE, focusCallout.BUTTON_SIZE)
focusCallout.button:SetPoint("TOPRIGHT", map, "TOPRIGHT", -7, -7)
focusCallout.button:SetFrameLevel(mapBorder:GetFrameLevel() + 4)
focusCallout.button:RegisterForClicks("LeftButtonUp")

focusCallout.background = focusCallout.button:CreateTexture(nil, "BACKGROUND")
focusCallout.background:SetAllPoints()
focusCallout.background:SetColorTexture(0.08, 0.055, 0.025, 0.72)

focusCallout.icon = focusCallout.button:CreateTexture(nil, "ARTWORK")
focusCallout.icon:SetPoint("TOPLEFT", focusCallout.button, "TOPLEFT", 2, -2)
focusCallout.icon:SetPoint("BOTTOMRIGHT", focusCallout.button, "BOTTOMRIGHT", -2, 2)
focusCallout.icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
focusCallout.icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
focusCallout.icon:SetAlpha(0.82)

focusCallout.border = focusCallout:CreateCrispIconBorder(focusCallout.button)
focusCallout.border:SetAlpha(0.96)
focusCallout.button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
focusCallout.button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

focusCallout.openHighlight = focusCallout.button:CreateTexture(nil, "OVERLAY")
focusCallout.openHighlight:SetAllPoints()
focusCallout.openHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
focusCallout.openHighlight:SetBlendMode("ADD")
focusCallout.openHighlight:Hide()

focusCallout.dismiss = CreateFrame("Button", nil, UIParent)
focusCallout.dismiss:SetAllPoints(UIParent)
focusCallout.dismiss:SetFrameStrata("DIALOG")
focusCallout.dismiss:SetFrameLevel(90)
focusCallout.dismiss:EnableMouse(true)
focusCallout.dismiss:RegisterForClicks("AnyUp")
focusCallout.dismiss:SetScript("OnClick", function() focusCallout:CloseMenu() end)
focusCallout.dismiss:Hide()

focusCallout.menu = CreateFrame(
    "Frame",
    "ZurksABFocusMenu",
    UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
focusCallout.menu:SetSize(
    focusCallout.MENU_WIDTH,
    (focusCallout.OPTION_HEIGHT * 8) + (focusCallout.MENU_PADDING * 2)
)
focusCallout.menu:SetFrameStrata("DIALOG")
focusCallout.menu:SetFrameLevel(91)
focusCallout.menu:SetClampedToScreen(true)

if focusCallout.menu.SetBackdrop then
    focusCallout.menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    focusCallout.menu:SetBackdropColor(0.03, 0.03, 0.03, 0.96)
    focusCallout.menu:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
end
focusCallout.menu:Hide()

focusCallout.optionButtons = {}
for i = 1, 8 do
    local option = CreateFrame("Button", nil, focusCallout.menu)
    option:SetHeight(focusCallout.OPTION_HEIGHT)
    option:SetPoint(
        "TOPLEFT",
        focusCallout.menu,
        "TOPLEFT",
        focusCallout.MENU_PADDING,
        -focusCallout.MENU_PADDING - ((i - 1) * focusCallout.OPTION_HEIGHT)
    )
    option:SetPoint(
        "TOPRIGHT",
        focusCallout.menu,
        "TOPRIGHT",
        -focusCallout.MENU_PADDING,
        -focusCallout.MENU_PADDING - ((i - 1) * focusCallout.OPTION_HEIGHT)
    )

    option.bg = option:CreateTexture(nil, "BACKGROUND")
    option.bg:SetAllPoints()
    option.bg:SetColorTexture(0.02, 0.02, 0.02, 0.72)

    option.highlight = option:CreateTexture(nil, "HIGHLIGHT")
    option.highlight:SetAllPoints()
    option.highlight:SetColorTexture(0.85, 0.62, 0.08, 0.55)

    option.classIcon = option:CreateTexture(nil, "ARTWORK")
    option.classIcon:SetSize(17, 17)
    option.classIcon:SetPoint("LEFT", option, "LEFT", 4, 0)
    option.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")

    option.optionLabel = option:CreateFontString(nil, "OVERLAY")
    option.optionLabel:SetPoint("LEFT", option.classIcon, "RIGHT", 6, 0)
    option.optionLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

    option:RegisterForClicks("LeftButtonUp")
    option:SetScript("OnClick", function(self)
        if not self.classNameUpper then
            return
        end
        focusCallout:CloseMenu()
        Report("FOCUS the " .. self.classNameUpper .. "!")
    end)
    focusCallout.optionButtons[i] = option
end

focusCallout.button:SetScript("OnEnter", function(self)
    focusCallout.icon:SetAlpha(1)
    focusCallout.border:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Focus Callout")
    GameTooltip:AddLine("Choose the enemy class your team should focus.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)

focusCallout.button:SetScript("OnLeave", function()
    if focusCallout.menu:IsShown() then
        focusCallout.icon:SetAlpha(1)
        focusCallout.border:SetAlpha(1)
    else
        focusCallout.icon:SetAlpha(0.82)
        focusCallout.border:SetAlpha(0.96)
    end
    GameTooltip:Hide()
end)

focusCallout.button:SetScript("OnClick", function()
    if focusCallout.menu:IsShown() then
        focusCallout:CloseMenu()
        return
    end

    hoveredZone = nil
    highlightTexture:Hide()
    GameTooltip:Hide()
    focusCallout:RefreshOptions()
    focusCallout:AnchorMenu()
    focusCallout.dismiss:Show()
    focusCallout.menu:Show()
    focusCallout.openHighlight:Show()
    focusCallout.icon:SetAlpha(1)
    focusCallout.border:SetAlpha(1)
end)

frame:HookScript("OnHide", function() focusCallout:CloseMenu() end)

-- Battlecry callout button. Mirrors the Focus button size/border but lives in the
-- lower-left corner. Its custom message is stored in the addon's SavedVariables.
local battlecry = {
    BUTTON_SIZE = focusCallout.BUTTON_SIZE,
    PANEL_WIDTH = 260,
    PANEL_HEIGHT = 72,
    HOVER_GRACE_SECONDS = 0.55,
    closeAt = nil,
}

function battlecry:GetFriendlyFaction()
    if UnitFactionGroup then
        return UnitFactionGroup("player")
    end
    return nil
end

function battlecry:GetDefaultMessage()
    local faction = self:GetFriendlyFaction()
    if faction == "Alliance" then
        return "FOR THE ALLIANCE!"
    elseif faction == "Horde" then
        return "FOR THE HORDE!"
    end
    return "FOR THE TEAM!"
end

function battlecry:GetMessage()
    local saved = ZurksABCalloutMapDB and ZurksABCalloutMapDB.battlecryMessage
    if type(saved) == "string" and string.find(saved, "%S") then
        return saved
    end
    return self:GetDefaultMessage()
end

function battlecry:TrimMessage(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

function battlecry:SaveEditedMessage()
    if not self.editBox then
        return
    end

    self.savingEdit = true

    local text = self:TrimMessage(self.editBox:GetText())
    if text == "" then
        text = self:GetDefaultMessage()
    end

    ZurksABCalloutMapDB.battlecryMessage = text
    self.currentMessage = text
    self.editBox:SetText(text)
    self.editBox:ClearFocus()
    self.editing = false
    self.closeAt = nil
    if self.instruction then
        self.instruction:SetText("Click message to edit")
    end
    if self.panel and self.panel:IsShown() then
        self.panel:Hide()
    end
    self.savingEdit = false
end

function battlecry:ExecuteMessage()
    local message = self:TrimMessage(self:GetMessage())
    if message == "" then
        return
    end

    -- Saved slash-emotes should behave like actual WoW emotes instead of being
    -- printed literally into battleground chat. This supports commands such as
    -- /spit, /wave, /cheer, /dance, etc. Custom /e text is handled separately.
    local slashCommand, slashArgs = string.match(message, "^/(%S+)%s*(.-)%s*$")
    if slashCommand then
        local command = string.lower(slashCommand)
        if command == "e" or command == "em" or command == "me" then
            if slashArgs and slashArgs ~= "" then
                SendChatMessage(slashArgs, "EMOTE")
            end
            return
        end

        if DoEmote then
            DoEmote(string.upper(slashCommand))
            return
        end
    end

    -- Battlecry text is intentionally shouted in /y rather than routed through
    -- the normal hotspot reporter. Slash-emotes above still execute as emotes.
    SendChatMessage(message, "YELL")
end

function battlecry:CancelEditing()
    if not self.editBox then
        return
    end
    self.cancelingEdit = true
    self.editBox:SetText(self:GetMessage())
    self.editBox:ClearFocus()
    self.editing = false
    self.closeAt = nil
    if self.instruction then
        self.instruction:SetText("Click message to edit")
    end
    if self.panel and self.panel:IsShown() then
        self.panel:Hide()
    end
    self.cancelingEdit = false
end

function battlecry:ShowPanel()
    if not self.panel then
        return
    end
    if ConfigureBattlecryPanel then
        ConfigureBattlecryPanel(frame:GetScale())
    end
    self.currentMessage = self:GetMessage()
    self.savingEdit = false
    self.cancelingEdit = false
    self.editBox:SetText(self.currentMessage)
    if not self.editBox:HasFocus() then
        self.instruction:SetText("Click message to edit")
    end
    self.panel:Show()
end

function battlecry:GetIconTexture()
    local faction = self:GetFriendlyFaction()
    if faction == "Alliance" then
        -- Commanding Shout
        return "Interface\\Icons\\Ability_Warrior_RallyingCry"
    elseif faction == "Horde" then
        -- Demoralizing Shout
        return "Interface\\Icons\\Ability_Warrior_WarCry"
    end
    return "Interface\\Icons\\Ability_Warrior_BattleShout"
end

battlecry.button = CreateFrame("Button", nil, map)
battlecry.button:SetSize(battlecry.BUTTON_SIZE, battlecry.BUTTON_SIZE)
battlecry.button:SetPoint("BOTTOMLEFT", map, "BOTTOMLEFT", 7, 7)
battlecry.button:SetFrameLevel(mapBorder:GetFrameLevel() + 4)
battlecry.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

battlecry.background = battlecry.button:CreateTexture(nil, "BACKGROUND")
battlecry.background:SetAllPoints()
battlecry.background:SetColorTexture(0.08, 0.055, 0.025, 0.72)

battlecry.icon = battlecry.button:CreateTexture(nil, "ARTWORK")
battlecry.icon:SetPoint("TOPLEFT", battlecry.button, "TOPLEFT", 2, -2)
battlecry.icon:SetPoint("BOTTOMRIGHT", battlecry.button, "BOTTOMRIGHT", -2, 2)
battlecry.icon:SetTexture(battlecry:GetIconTexture())
battlecry.icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
battlecry.icon:SetAlpha(0.82)

battlecry.border = focusCallout:CreateCrispIconBorder(battlecry.button)
battlecry.border:SetAlpha(0.96)
battlecry.button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
battlecry.button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

battlecry.panel = CreateFrame(
    "Frame",
    "ZurksABBattlecryTooltip",
    frame,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
battlecry.panel:SetSize(MAP_WIDTH + 10, battlecry.PANEL_HEIGHT)
battlecry.panel:SetFrameStrata("DIALOG")
battlecry.panel:SetFrameLevel(95)
battlecry.panel:SetClampedToScreen(false)
battlecry.panel:EnableMouse(true)

ConfigureBattlecryPanel = function(addonScale)
    if not battlecry.panel or not mapBorder then
        return
    end

    -- The panel is a child of the addon frame, so it inherits the map's scale.
    -- Anchor both horizontal edges to the visible map border and place its top edge
    -- directly against the map's bottom edge at every resize setting.
    battlecry.panel:SetScale(1)
    battlecry.panel:ClearAllPoints()
    -- UI-Tooltip-Border has transparent padding around its artwork. Pull the panel
    -- upward by 5px so the *visible* bottom border of the map and the visible top
    -- border of the panel meet cleanly, without covering the map artwork itself.
    battlecry.panel:SetPoint("TOPLEFT", mapBorder, "BOTTOMLEFT", 0, 5)
    battlecry.panel:SetPoint("TOPRIGHT", mapBorder, "BOTTOMRIGHT", 0, 5)
    battlecry.panel:SetHeight(battlecry.PANEL_HEIGHT)
end

if battlecry.panel.SetBackdrop then
    battlecry.panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    battlecry.panel:SetBackdropColor(0.03, 0.03, 0.03, 0.97)
    battlecry.panel:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
end

battlecry.title = battlecry.panel:CreateFontString(nil, "OVERLAY")
battlecry.title:SetPoint("TOPLEFT", battlecry.panel, "TOPLEFT", 12, -7)
battlecry.title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
battlecry.title:SetTextColor(1, 0.82, 0.20, 1)
battlecry.title:SetText("Battlecry")

battlecry.instruction = battlecry.panel:CreateFontString(nil, "OVERLAY")
battlecry.instruction:SetPoint("TOPLEFT", battlecry.title, "BOTTOMLEFT", 0, -1)
battlecry.instruction:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
battlecry.instruction:SetTextColor(0.76, 0.70, 0.54, 1)
battlecry.instruction:SetText("Click message to edit")

battlecry.editBox = CreateFrame("EditBox", nil, battlecry.panel, "InputBoxTemplate")
battlecry.editBox:SetPoint("TOPLEFT", battlecry.panel, "TOPLEFT", 12, -39)
battlecry.editBox:SetPoint("TOPRIGHT", battlecry.panel, "TOPRIGHT", -84, -39)
battlecry.editBox:SetHeight(22)
battlecry.editBox:SetAutoFocus(false)
battlecry.editBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
battlecry.editBox:SetMaxLetters(220)
battlecry.editBox:SetTextInsets(4, 4, 0, 0)
battlecry.editBox:SetText(battlecry:GetMessage())

battlecry.editBox:SetScript("OnEditFocusGained", function(self)
    battlecry.editing = true
    battlecry.instruction:SetText("Press Enter or Okay to save")
    self:HighlightText()
end)

battlecry.editBox:SetScript("OnEnterPressed", function()
    battlecry:SaveEditedMessage()
end)

battlecry.editBox:SetScript("OnEscapePressed", function()
    battlecry:CancelEditing()
end)

battlecry.editBox:SetScript("OnEditFocusLost", function()
    if battlecry.savingEdit or battlecry.cancelingEdit then
        return
    end

    if battlecry.panel and battlecry.panel:IsShown() then
        battlecry:CancelEditing()
    end
end)

battlecry.okayButton = CreateFrame("Button", nil, battlecry.panel, "UIPanelButtonTemplate")
battlecry.okayButton:SetSize(64, 22)
battlecry.okayButton:SetPoint("TOPRIGHT", battlecry.panel, "TOPRIGHT", -10, -39)
battlecry.okayButton:SetText("Okay")
battlecry.okayButton:SetScript("OnMouseDown", function()
    battlecry.savingEdit = true
end)

battlecry.okayButton:SetScript("OnClick", function()
    battlecry:SaveEditedMessage()
end)

battlecry.button:SetScript("OnEnter", function(self)
    battlecry.closeAt = nil
    battlecry.icon:SetAlpha(1)
    battlecry.border:SetAlpha(1)
    hoveredZone = nil
    highlightTexture:Hide()
    GameTooltip:Hide()
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:SetText("Battlecry")
    GameTooltip:AddLine(battlecry:GetMessage(), 0.72, 0.66, 0.50, true)
    GameTooltip:AddLine("Right-click to edit message", 0.72, 0.66, 0.50)
    GameTooltip:Show()
end)

battlecry.button:SetScript("OnLeave", function()
    battlecry.icon:SetAlpha(0.82)
    battlecry.border:SetAlpha(0.96)
    GameTooltip:Hide()
end)

battlecry.button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
        GameTooltip:Hide()
        battlecry:ShowPanel()
        battlecry.editBox:SetFocus()
    elseif mouseButton == "LeftButton" then
        battlecry:ExecuteMessage()
    end
end)

battlecry.panel:SetScript("OnEnter", function()
    battlecry.closeAt = nil
end)

battlecry.panel:SetScript("OnLeave", function()
    if not battlecry.editBox:HasFocus() then
        battlecry.closeAt = GetTime() + battlecry.HOVER_GRACE_SECONDS
    end
end)

battlecry.panel:SetScript("OnUpdate", function(self)
    if not self:IsShown() then
        return
    end

    if battlecry.editBox:HasFocus() then
        battlecry.closeAt = nil
        return
    end

    if battlecry.button:IsMouseOver() or self:IsMouseOver() then
        battlecry.closeAt = nil
        return
    end

    if not battlecry.closeAt then
        battlecry.closeAt = GetTime() + battlecry.HOVER_GRACE_SECONDS
        return
    end

    if GetTime() >= battlecry.closeAt then
        battlecry.closeAt = nil
        self:Hide()
    end
end)

battlecry.panel:SetScript("OnHide", function()
    battlecry.closeAt = nil
    battlecry.savingEdit = false
    battlecry.cancelingEdit = false
    if battlecry.editBox:HasFocus() then
        battlecry:SaveEditedMessage()
    end
end)

ConfigureBattlecryPanel(frame:GetScale())
battlecry.panel:Hide()
frame:HookScript("OnHide", function()
    battlecry.panel:Hide()
end)

local function PointInPolygon(x, y, points)
    local inside = false
    local j = #points

    for i = 1, #points do
        local xi, yi = points[i][1], points[i][2]
        local xj, yj = points[j][1], points[j][2]

        if ((yi > y) ~= (yj > y)) then
            local intersectX = ((xj - xi) * (y - yi) / (yj - yi)) + xi
            if x < intersectX then
                inside = not inside
            end
        end

        j = i
    end

    return inside
end

local function DistanceSquaredToSegment(px, py, ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    local lengthSquared = (dx * dx) + (dy * dy)

    if lengthSquared <= 0 then
        local ox = px - ax
        local oy = py - ay
        return (ox * ox) + (oy * oy)
    end

    local t = (((px - ax) * dx) + ((py - ay) * dy)) / lengthSquared
    t = math.max(0, math.min(1, t))

    local nearestX = ax + (t * dx)
    local nearestY = ay + (t * dy)
    local ox = px - nearestX
    local oy = py - nearestY

    return (ox * ox) + (oy * oy)
end

local function PointNearPaths(x, y, paths, radius)
    if not paths or not radius then
        return false
    end

    local radiusSquared = radius * radius

    for _, path in ipairs(paths) do
        for i = 1, #path - 1 do
            local a = path[i]
            local b = path[i + 1]
            if DistanceSquaredToSegment(x, y, a[1], a[2], b[1], b[2]) <= radiusSquared then
                return true
            end
        end
    end

    return false
end

local function GetMousePercent()
    local left = map:GetLeft()
    local bottom = map:GetBottom()

    if not left or not bottom then
        return nil, nil
    end

    local effectiveScale = map:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local leftPx = left * effectiveScale
    local bottomPx = bottom * effectiveScale
    local widthPx = map:GetWidth() * effectiveScale
    local heightPx = map:GetHeight() * effectiveScale

    local x = ((cursorX - leftPx) / widthPx) * 100
    local yFromBottom = ((cursorY - bottomPx) / heightPx) * 100
    local y = 100 - yFromBottom

    if x < 0 or x > 100 or y < 0 or y > 100 then
        return nil, nil
    end

    return x, y
end

local function FindZone(x, y)
    if not x or not y then
        return nil
    end

    -- Exact polygon hotspots get first priority so a generous road hit area never
    -- steals a click from a base or bridge/water/intersection hotspot.
    for _, zone in ipairs(ZONES) do
        if zone.points and PointInPolygon(x, y, zone.points) then
            return zone
        end
    end

    -- Roads 5-9 use larger invisible path-based hit areas while their visible
    -- highlight textures remain tightly mapped to the road artwork.
    for _, zone in ipairs(ZONES) do
        if zone.hitPaths and PointNearPaths(x, y, zone.hitPaths, zone.hitRadius) then
            return zone
        end
    end

        return nil
end

local function ShowZone(zone)
    if hoveredZone == zone then
        return
    end

    hoveredZone = zone
    GameTooltip:Hide()

    if not zone then
        highlightTexture:Hide()
        return
    end

    local contestedState = zone.isBase and contestedBaseStates[zone.id] or nil
    if contestedState and contestedState.active then
        highlightTexture:Hide()
    else
        highlightTexture:SetTexture(
            "Interface\\AddOns\\ZurkMaps\\Media\\Highlights\\" .. zone.id
        )
        highlightTexture:Show()
    end

    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:SetText(zone.name)
    if zone.isBase then
        GameTooltip:AddLine("Right-click for HELP", 0.72, 0.66, 0.50)
        GameTooltip:AddLine("Shift-click to report WEAK", 0.72, 0.66, 0.50)
    else
        GameTooltip:AddLine("Right-click for Get OUT", 0.72, 0.66, 0.50)
    end
    GameTooltip:Show()
end

-- Live AB base nodes. Blizzard's own POI icon sheet and live objective
-- textureIndex are used so neutral/assaulted/controlled states match the game.
local BASE_NODE_SIZE = 22
local baseNodeButtons = {}
local baseNodeRefreshElapsed = 0

local BASE_NODE_HIGHLIGHT_COLORS = {
    -- Saturated versions of the base hotspot colors so the small node glow reads
    -- with the same punch as the faction-contested blue/red highlights.
    STABLES = { 0.12, 0.78, 0.86 },
    GOLD_MINE = { 1.00, 0.70, 0.10 },
    BLACKSMITH = { 0.68, 0.38, 0.92 },
    LUMBER_MILL = { 1.00, 0.48, 0.10 },
    FARM = { 0.96, 0.28, 0.24 },
}

local function GetBaseNodeHighlightColor(baseNode, textureIndex)
    local contestState = baseNode and contestedBaseStates[baseNode.id] or nil
    if contestState and contestState.active then
        if contestState.faction == "Alliance" then
            return 0.12, 0.36, 1.00
        elseif contestState.faction == "Horde" then
            return 1.00, 0.20, 0.16
        end
    end

    textureIndex = tonumber(textureIndex) or (baseNode and baseNode.neutralTextureIndex)
    if baseNode and textureIndex then
        local offset = textureIndex - baseNode.neutralTextureIndex
        if offset == 1 then
            return 0.12, 0.36, 1.00
        elseif offset == 3 then
            return 1.00, 0.20, 0.16
        end
    end

    local color = baseNode and BASE_NODE_HIGHLIGHT_COLORS[baseNode.id] or nil
    if color then
        return color[1], color[2], color[3]
    end
    return 1, 1, 1
end

local function UpdateBaseNodeHighlightColor(baseNode)
    if not baseNode then
        return
    end
    local button = baseNodeButtons[baseNode.id]
    if not button then
        return
    end
    local highlight = button:GetHighlightTexture()
    if not highlight then
        return
    end
    local r, g, b = GetBaseNodeHighlightColor(baseNode, baseNode.currentTextureIndex)
    highlight:SetVertexColor(r, g, b, 1)
    highlight:SetAlpha(1.00)
end

local function GetBaseNodeIDFromName(name)
    local normalized = string.lower(name or "")

    if string.find(normalized, "stable", 1, true) then
        return "STABLES"
    elseif string.find(normalized, "gold", 1, true) and string.find(normalized, "mine", 1, true) then
        return "GOLD_MINE"
    elseif string.find(normalized, "blacksmith", 1, true) then
        return "BLACKSMITH"
    elseif string.find(normalized, "lumber", 1, true) and string.find(normalized, "mill", 1, true) then
        return "LUMBER_MILL"
    elseif string.find(normalized, "farm", 1, true) then
        return "FARM"
    end

    return nil
end

local function GetBaseNodeIDFromTextureIndex(textureIndex)
    textureIndex = tonumber(textureIndex)
    if not textureIndex then
        return nil
    end

    if textureIndex >= 16 and textureIndex <= 20 then
        return "GOLD_MINE"
    elseif textureIndex >= 21 and textureIndex <= 25 then
        return "LUMBER_MILL"
    elseif textureIndex >= 26 and textureIndex <= 30 then
        return "BLACKSMITH"
    elseif textureIndex >= 31 and textureIndex <= 35 then
        return "FARM"
    elseif textureIndex >= 36 and textureIndex <= 40 then
        return "STABLES"
    end

    return nil
end

local function GetBaseNodeStatusLabel(baseNode, textureIndex)
    textureIndex = tonumber(textureIndex) or baseNode.neutralTextureIndex
    local offset = textureIndex - baseNode.neutralTextureIndex

    if offset == 1 then
        return "Alliance Assaulting"
    elseif offset == 2 then
        return "Alliance Controlled"
    elseif offset == 3 then
        return "Horde Assaulting"
    elseif offset == 4 then
        return "Horde Controlled"
    end

    return "Unclaimed"
end

local function ApplyBaseNodePOITexture(texture, textureIndex)
    textureIndex = tonumber(textureIndex)
    if not textureIndex then
        return false
    end

    local coordsOK = false
    local x1, x2, y1, y2

    if C_Minimap and type(C_Minimap.GetPOITextureCoords) == "function" then
        local ok, a, b, c, d = pcall(C_Minimap.GetPOITextureCoords, textureIndex)
        if ok and a then
            coordsOK = true
            x1, x2, y1, y2 = a, b, c, d
        end
    elseif type(GetPOITextureCoords) == "function" then
        local ok, a, b, c, d = pcall(GetPOITextureCoords, textureIndex)
        if ok and a then
            coordsOK = true
            x1, x2, y1, y2 = a, b, c, d
        end
    end

    if not coordsOK then
        return false
    end

    texture:SetTexture("Interface\\Minimap\\POIIcons")
    texture:SetTexCoord(x1, x2, y1, y2)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:Show()
    return true
end

local function SetBaseNodeFallback(button, baseNode, textureIndex)
    button.icon:Hide()
    button.fallbackLeft:Show()
    button.fallbackRight:Show()

    local offset = (tonumber(textureIndex) or baseNode.neutralTextureIndex) - baseNode.neutralTextureIndex
    local grey = { 0.45, 0.45, 0.45 }
    local blue = { 0.12, 0.42, 0.95 }
    local red = { 0.90, 0.12, 0.10 }
    local left = grey
    local right = grey

    if offset == 1 then
        left = blue
    elseif offset == 2 then
        left = blue
        right = blue
    elseif offset == 3 then
        left = red
    elseif offset == 4 then
        left = red
        right = red
    end

    button.fallbackLeft:SetColorTexture(left[1], left[2], left[3], 0.95)
    button.fallbackRight:SetColorTexture(right[1], right[2], right[3], 0.95)
end

local function UpdateBaseNodeButton(baseNode, textureIndex)
    local button = baseNodeButtons[baseNode.id]
    if not button then
        return
    end

    textureIndex = tonumber(textureIndex) or baseNode.neutralTextureIndex
    baseNode.currentTextureIndex = textureIndex
    baseNode.currentStatus = GetBaseNodeStatusLabel(baseNode, textureIndex)

    if ApplyBaseNodePOITexture(button.icon, textureIndex) then
        button.fallbackLeft:Hide()
        button.fallbackRight:Hide()
    else
        SetBaseNodeFallback(button, baseNode, textureIndex)
    end

    UpdateBaseNodeHighlightColor(baseNode)
end

local function ReadLegacyBaseNodeStates(states, poiData)
    if type(GetNumMapLandmarks) ~= "function" or type(GetMapLandmarkInfo) ~= "function" then
        return false
    end

    local okCount, count = pcall(GetNumMapLandmarks)
    if not okCount or type(count) ~= "number" then
        return false
    end

    local found = false
    for i = 1, count do
        local values = { pcall(GetMapLandmarkInfo, i) }
        if values[1] then
            local name = values[2]
            local textureIndex = values[4]
            local mapX = tonumber(values[5])
            local mapY = tonumber(values[6])
            local nodeID = GetBaseNodeIDFromName(name) or GetBaseNodeIDFromTextureIndex(textureIndex)
            if nodeID and tonumber(textureIndex) then
                states[nodeID] = tonumber(textureIndex)
                if poiData then
                    local data = poiData[nodeID] or {}
                    data.textureIndex = tonumber(textureIndex)
                    data.name = name
                    if mapX and mapY then
                        data.mapX = mapX
                        data.mapY = mapY
                    end
                    poiData[nodeID] = data
                end
                found = true
            end
        end
    end

    return found
end

local function ReadAreaPOIBaseNodeStates(states, poiData)
    if not C_AreaPoiInfo
        or type(C_AreaPoiInfo.GetAreaPOIForMap) ~= "function"
        or type(C_AreaPoiInfo.GetAreaPOIInfo) ~= "function" then
        return false
    end

    local mapID = GetABUiMapID()
    local okIDs, poiIDs = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
    if not okIDs or type(poiIDs) ~= "table" then
        return false
    end

    local found = false
    for _, poiID in ipairs(poiIDs) do
        local okInfo, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
        if okInfo and type(info) == "table" then
            local textureIndex = tonumber(info.textureIndex)
            local nodeID = GetBaseNodeIDFromName(info.name) or GetBaseNodeIDFromTextureIndex(textureIndex)
            if nodeID and textureIndex then
                states[nodeID] = textureIndex
                if poiData then
                    local data = poiData[nodeID] or {}
                    local mapX, mapY = GetVectorPositionXY(info.position)
                    data.poiID = poiID
                    data.textureIndex = textureIndex
                    data.name = info.name
                    if mapX and mapY then
                        data.mapX = mapX
                        data.mapY = mapY
                    end
                    poiData[nodeID] = data
                end
                found = true
            end
        end
    end

    return found
end

RefreshBaseNodes = function()
    local states = {}
    local poiData = {}

    if abTestMode then
        for _, baseNode in ipairs(BASE_NODES) do
            local textureIndex = abTestBaseNodeStates[baseNode.id] or baseNode.neutralTextureIndex
            UpdateBaseNodeButton(baseNode, textureIndex)
        end
        return
    end

    if IsInArathiBasin() then
        ReadLegacyBaseNodeStates(states, poiData)
        ReadAreaPOIBaseNodeStates(states, poiData)
        UpdateABFriendlyPositionCalibration(poiData)
    end

    for _, baseNode in ipairs(BASE_NODES) do
        local textureIndex = states[baseNode.id] or baseNode.neutralTextureIndex
        UpdateBaseNodeButton(baseNode, textureIndex)
        if UpdateContestedBaseState and not contestedTestMode then
            local data = poiData[baseNode.id]
            UpdateContestedBaseState(baseNode, textureIndex, data and data.poiID or nil)
        end
    end
end

for _, baseNode in ipairs(BASE_NODES) do
    local button = CreateFrame("Button", nil, map)
    button:SetSize(BASE_NODE_SIZE, BASE_NODE_SIZE)
    button:SetPoint(
        "CENTER",
        map,
        "TOPLEFT",
        (baseNode.x / 100) * MAP_WIDTH,
        -(baseNode.y / 100) * MAP_HEIGHT
    )
    button:SetFrameLevel(mapBorder:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(16, 16)
    button.icon:SetPoint("CENTER")

    button.fallbackLeft = button:CreateTexture(nil, "ARTWORK")
    button.fallbackLeft:SetSize(8, 16)
    button.fallbackLeft:SetPoint("RIGHT", button, "CENTER", 0, 0)

    button.fallbackRight = button:CreateTexture(nil, "ARTWORK")
    button.fallbackRight:SetSize(8, 16)
    button.fallbackRight:SetPoint("LEFT", button, "CENTER", 0, 0)

    -- Restore the softer Blizzard minimap-node highlight shape from the earlier
    -- builds. Desaturating it first removes the texture's built-in blue cast so
    -- vertex coloring works correctly for teal/gold/violet/orange/red as well.
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    local nodeHighlight = button:GetHighlightTexture()
    if nodeHighlight then
        nodeHighlight:ClearAllPoints()
        nodeHighlight:SetPoint("CENTER", button, "CENTER", 0, 0)
        nodeHighlight:SetSize(BASE_NODE_SIZE + 10, BASE_NODE_SIZE + 10)
        nodeHighlight:SetBlendMode("ADD")
        if nodeHighlight.SetDesaturated then
            nodeHighlight:SetDesaturated(true)
        end
    end

    button:SetScript("OnEnter", function(self)
        hoveredBaseNode = baseNode
        hoveredZone = nil
        highlightTexture:Hide()
        GameTooltip:Hide()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(baseNode.name)
        GameTooltip:AddLine(baseNode.currentStatus or "Unclaimed", 0.82, 0.82, 0.82)
        GameTooltip:AddLine("Click: SPIN", 0.72, 0.66, 0.50)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        hoveredBaseNode = nil
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if IsShiftKeyDown() then
            Report(baseNode.name .. " looking weak.")
        elseif mouseButton == "RightButton" then
            Report("Need HELP at " .. baseNode.name .. "!!")
        elseif mouseButton == "LeftButton" then
            Report("SPIN " .. baseNode.callout .. " FLAG!!")
        end
    end)

    baseNodeButtons[baseNode.id] = button
    UpdateBaseNodeHighlightColor(baseNode)
end

-- Experimental contested-base visualization. It uses the five base hotspot shapes
-- as persistent illumination masks while a base is contested, independent of hover.
-- The hotspot colors are intended to track the same faction color family as the
-- countdown frame borders so the two read as one connected alert.
local ALLIANCE_CONTEST_R, ALLIANCE_CONTEST_G, ALLIANCE_CONTEST_B = 0.12, 0.36, 1.00 -- vivid royal Alliance blue
local HORDE_CONTEST_R, HORDE_CONTEST_G, HORDE_CONTEST_B = 1.00, 0.20, 0.16
local CONTEST_TIMER_FONT_SIZE = 13
local CONTEST_TIMER_FRAME_SIZE = 29
local CONTEST_TIMER_NORMAL_R, CONTEST_TIMER_NORMAL_G, CONTEST_TIMER_NORMAL_B = 0.96, 0.93, 0.84
local CONTEST_TIMER_WARNING_R, CONTEST_TIMER_WARNING_G, CONTEST_TIMER_WARNING_B = 1.00, 0.82, 0.12
local CONTEST_FINISH_FLOURISH_SECONDS = 1.0
local CONTEST_TIMER_FRAME_EDGE_ALPHA = 0.98
local CONTEST_TIMER_FRAME_BG_ALPHA = 0.00
local CONTEST_TIMER_TEXT_BG_ALPHA = 0.68
local CONTEST_TIMER_TEXT_OFFSET_X = 0
local CONTEST_TIMER_TEXT_OFFSET_Y = 0

-- Fixed square timer-frame positions inside each base hotspot. Keeping the timer
-- centered in a fixed-size Blizzard-art frame stops digit jitter, and each location
-- stays clear of both the node icon and hotspot edge.
local CONTEST_TIMER_POSITIONS = {
    STABLES = { x = 21.50, y = 27.80 },
    GOLD_MINE = { x = 73.00, y = 35.00 },
    BLACKSMITH = { x = 48.00, y = 44.70 },
    LUMBER_MILL = { x = 36.50, y = 76.50 },
    FARM = { x = 79.00, y = 74.00 },
}

local contestAnimationFrame = CreateFrame("Frame", nil, frame)

local function GetPOIRemainingSeconds(poiID)
    if not poiID or not C_AreaPoiInfo then
        return nil, nil
    end

    if type(C_AreaPoiInfo.GetAreaPOISecondsLeft) == "function" then
        local ok, seconds = pcall(C_AreaPoiInfo.GetAreaPOISecondsLeft, poiID)
        seconds = ok and tonumber(seconds) or nil
        if seconds and seconds > 0 then
            return seconds, "GetAreaPOISecondsLeft"
        end
    end

    if type(C_AreaPoiInfo.GetAreaPOITimeLeft) == "function" then
        local ok, minutes = pcall(C_AreaPoiInfo.GetAreaPOITimeLeft, poiID)
        minutes = ok and tonumber(minutes) or nil
        if minutes and minutes > 0 then
            return minutes * 60, "GetAreaPOITimeLeft"
        end
    end

    return nil, nil
end

local function GetContestingFaction(baseNode, textureIndex)
    textureIndex = tonumber(textureIndex) or baseNode.neutralTextureIndex
    local offset = textureIndex - baseNode.neutralTextureIndex
    if offset == 1 then
        return "Alliance"
    elseif offset == 3 then
        return "Horde"
    end
    return nil
end

local function SetContestTimerFrameColor(visual, faction)
    if not visual or not visual.timerFrame then
        return
    end

    local r, g, b
    if faction == "Alliance" then
        r, g, b = ALLIANCE_CONTEST_R, ALLIANCE_CONTEST_G, ALLIANCE_CONTEST_B
    else
        r, g, b = HORDE_CONTEST_R, HORDE_CONTEST_G, HORDE_CONTEST_B
    end

    -- Keep the outer square transparent except for its faction-colored Blizzard
    -- border. The dedicated inner plate directly behind the number is darker than
    -- the hotspot itself, but not so dark that it feels visually heavy.
    if visual.timerFrame.SetBackdropBorderColor then
        visual.timerFrame:SetBackdropBorderColor(r, g, b, CONTEST_TIMER_FRAME_EDGE_ALPHA)
    end
    if visual.timerFrame.SetBackdropColor then
        visual.timerFrame:SetBackdropColor(0, 0, 0, CONTEST_TIMER_FRAME_BG_ALPHA)
    end
    if visual.timerTextBG then
        visual.timerTextBG:SetVertexColor(0.06, 0.06, 0.06, CONTEST_TIMER_TEXT_BG_ALPHA)
    end
end

local function HideContestedBase(baseID)
    local state = contestedBaseStates[baseID]
    local visual = contestedBaseVisuals[baseID]
    if state then
        state.active = false
        state.faction = nil
        state.endTime = nil
        state.timerSource = nil
        state.poiID = nil
        state.timerExpired = false
        state.expiredFaction = nil
    end
    if visual then
        visual.texture:Hide()
        visual.timerFrame:Hide()
        visual.timerText:Hide()
    end
    UpdateBaseNodeHighlightColor(BASE_NODE_BY_ID[baseID])
end

local function FinishContestedBase(baseID)
    local state = contestedBaseStates[baseID]
    local visual = contestedBaseVisuals[baseID]
    if state then
        state.active = false
        state.timerExpired = true
        state.expiredFaction = state.faction
        state.endTime = nil
    end
    if visual then
        visual.texture:Hide()
        visual.texture:SetAlpha(1)
        visual.timerFrame:Hide()
        visual.timerFrame:SetAlpha(1)
        visual.timerText:Hide()
        visual.timerText:SetAlpha(1)
    end

    -- In /ab test, a completed assault resolves into full ownership by the same
    -- faction so the node-icon transition can be verified without live AB data.
    if abTestMode and state and state.expiredFaction then
        local baseNode = BASE_NODE_BY_ID[baseID]
        if baseNode then
            local controlledOffset = state.expiredFaction == "Alliance" and 2 or 4
            local controlledTextureIndex = baseNode.neutralTextureIndex + controlledOffset
            abTestBaseNodeStates[baseID] = controlledTextureIndex
            UpdateBaseNodeButton(baseNode, controlledTextureIndex)
        end
    end
    UpdateBaseNodeHighlightColor(BASE_NODE_BY_ID[baseID])
end

local function StartContestedBase(baseNode, faction, durationSeconds, source, poiID)
    local state = contestedBaseStates[baseNode.id]
    local visual = contestedBaseVisuals[baseNode.id]
    if not state or not visual then
        return
    end

    durationSeconds = tonumber(durationSeconds)
    state.active = true
    state.faction = faction
    state.poiID = poiID
    state.timerSource = source or "local"
    state.timerExpired = false
    state.expiredFaction = nil
    state.endTime = durationSeconds and (GetTime() + math.max(0, durationSeconds)) or nil
    UpdateBaseNodeHighlightColor(baseNode)

    if faction == "Alliance" then
        visual.texture:SetVertexColor(ALLIANCE_CONTEST_R, ALLIANCE_CONTEST_G, ALLIANCE_CONTEST_B, 1)
    else
        visual.texture:SetVertexColor(HORDE_CONTEST_R, HORDE_CONTEST_G, HORDE_CONTEST_B, 1)
    end
    SetContestTimerFrameColor(visual, faction)
    visual.timerText:SetTextColor(CONTEST_TIMER_NORMAL_R, CONTEST_TIMER_NORMAL_G, CONTEST_TIMER_NORMAL_B, 1)

    visual.texture:SetAlpha(1)
    visual.timerFrame:SetAlpha(1)
    visual.timerText:SetAlpha(1)
    visual.texture:Show()
    visual.timerFrame:Show()
    visual.timerText:Show()
end

UpdateContestedBaseState = function(baseNode, textureIndex, poiID)
    local faction = GetContestingFaction(baseNode, textureIndex)
    local state = contestedBaseStates[baseNode.id]

    if not faction then
        HideContestedBase(baseNode.id)
        return
    end

    if state and state.active and state.faction == faction then
        return
    end

    if state and state.timerExpired and state.expiredFaction == faction then
        return
    end

    local secondsLeft, source = GetPOIRemainingSeconds(poiID)
    if not secondsLeft then
        secondsLeft = AB_CONTEST_FALLBACK_SECONDS
        source = "Classic fallback"
    end

    StartContestedBase(baseNode, faction, secondsLeft, source, poiID)
end

for _, baseNode in ipairs(BASE_NODES) do
    contestedBaseStates[baseNode.id] = {
        active = false,
        faction = nil,
        endTime = nil,
        timerSource = nil,
        poiID = nil,
        timerExpired = false,
        expiredFaction = nil,
    }

    local visual = {}
    visual.texture = map:CreateTexture(nil, "ARTWORK", nil, 1)
    visual.texture:SetAllPoints(map)
    visual.texture:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\Contested\\" .. baseNode.id)
    visual.texture:SetBlendMode("BLEND")
    visual.texture:Hide()

    local timerPosition = CONTEST_TIMER_POSITIONS[baseNode.id] or { x = baseNode.x, y = baseNode.y + 7 }
    visual.timerFrame = CreateFrame(
        "Button",
        nil,
        map,
        BackdropTemplateMixin and "BackdropTemplate" or nil
    )
    visual.timerFrame:SetSize(CONTEST_TIMER_FRAME_SIZE, CONTEST_TIMER_FRAME_SIZE)
    visual.timerFrame:SetPoint(
        "CENTER",
        map,
        "TOPLEFT",
        (timerPosition.x / 100) * MAP_WIDTH,
        -(timerPosition.y / 100) * MAP_HEIGHT
    )
    visual.timerFrame:SetFrameLevel(mapBorder:GetFrameLevel() + 6)
    visual.timerFrame.baseNode = baseNode
    visual.timerFrame:EnableMouse(true)
    visual.timerFrame:RegisterForClicks("LeftButtonUp")
    visual.timerFrame:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local timerHighlight = visual.timerFrame:GetHighlightTexture()
    if timerHighlight then
        timerHighlight:SetAlpha(0.38)
        timerHighlight:SetAllPoints(visual.timerFrame)
    end

    -- Square timer frame made entirely from existing Blizzard UI art. The border
    -- remains faction-colored, while a dedicated dark inner plate sits directly
    -- behind the digits so the number itself reads as the highest-contrast element.
    if visual.timerFrame.SetBackdrop then
        visual.timerFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 9,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end

    visual.timerTextBG = visual.timerFrame:CreateTexture(nil, "ARTWORK")
    visual.timerTextBG:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")

    -- Lumber Mill's inner dark timer plate was visually too narrow on the left
    -- and right. Widen only its horizontal coverage while keeping the same top
    -- and bottom inset as every other base.
    local timerTextBGInsetX = (baseNode.id == "LUMBER_MILL") and 1 or 3
    local timerTextBGInsetY = 3
    visual.timerTextBG:SetPoint("TOPLEFT", visual.timerFrame, "TOPLEFT", timerTextBGInsetX, -timerTextBGInsetY)
    visual.timerTextBG:SetPoint("BOTTOMRIGHT", visual.timerFrame, "BOTTOMRIGHT", -timerTextBGInsetX, timerTextBGInsetY)

    visual.timerText = visual.timerFrame:CreateFontString(nil, "OVERLAY")
    visual.timerText:SetFont("Fonts\\FRIZQT__.TTF", CONTEST_TIMER_FONT_SIZE, "OUTLINE")
    visual.timerText:SetShadowColor(0, 0, 0, 1)
    visual.timerText:SetShadowOffset(1, -1)
    visual.timerText:SetPoint("CENTER", visual.timerFrame, "CENTER", CONTEST_TIMER_TEXT_OFFSET_X, CONTEST_TIMER_TEXT_OFFSET_Y)
    visual.timerText:SetSize(CONTEST_TIMER_FRAME_SIZE - 4, CONTEST_TIMER_FRAME_SIZE - 8)
    if visual.timerText.SetWordWrap then
        visual.timerText:SetWordWrap(false)
    end
    if visual.timerText.SetNonSpaceWrap then
        visual.timerText:SetNonSpaceWrap(false)
    end
    if visual.timerText.SetMaxLines then
        visual.timerText:SetMaxLines(1)
    end
    visual.timerText:SetJustifyH("CENTER")
    visual.timerText:SetJustifyV("MIDDLE")
    visual.timerText:Hide()
    visual.timerFrame:Hide()

    visual.timerFrame:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" then
            return
        end

        local state = contestedBaseStates[baseNode.id]
        if not state or not state.active or not state.endTime then
            return
        end

        local secondsRemaining = math.max(0, math.ceil(state.endTime - GetTime()))
        local factionToken = "enemy"
        if state.faction == "Alliance" then
            factionToken = "ally"
        elseif state.faction == "Horde" then
            factionToken = "horde"
        end

        Report(secondsRemaining .. " seconds left until " .. factionToken .. " claim the " .. baseNode.name .. "!")
    end)

    visual.timerFrame:SetScript("OnEnter", function(self)
        hoveredContestTimerFrame = self
        hoveredZone = nil
        highlightTexture:Hide()
        -- ShowContestTimerTooltip() already clears/replaces GameTooltip. Do not call
        -- ClearFriendlyPlayerTooltip here because that local function is declared later
        -- in this file and is not in lexical scope at timer-frame construction time.
        ShowContestTimerTooltip(self.baseNode)
    end)

    visual.timerFrame:SetScript("OnLeave", function(self)
        if hoveredContestTimerFrame == self then
            hoveredContestTimerFrame = nil
        end
        GameTooltip:Hide()
    end)

    visual.timerFrame:SetScript("OnHide", function(self)
        if hoveredContestTimerFrame == self then
            hoveredContestTimerFrame = nil
        end
        GameTooltip:Hide()
    end)

    contestedBaseVisuals[baseNode.id] = visual
end

ConfigureContestTimerScale = function(addonScale)
    addonScale = tonumber(addonScale) or (frame and frame:GetScale()) or 1

    local fontSize = CONTEST_TIMER_FONT_SIZE
    local fontFlags = "OUTLINE"
    local shadowOffsetX, shadowOffsetY = 1, -1
    local shadowAlpha = 1

    if addonScale < 0.90 then
        fontSize = CONTEST_TIMER_FONT_SIZE - 1
    end
    if addonScale < 0.75 then
        fontSize = CONTEST_TIMER_FONT_SIZE - 2
        fontFlags = "OUTLINE,MONOCHROME"
        shadowOffsetX, shadowOffsetY = 0, 0
        shadowAlpha = 0.85
    end

    for _, visual in pairs(contestedBaseVisuals) do
        if visual.timerText then
            visual.timerText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, fontFlags)
            visual.timerText:SetShadowColor(0, 0, 0, shadowAlpha)
            visual.timerText:SetShadowOffset(shadowOffsetX, shadowOffsetY)
            visual.timerText:SetSize(CONTEST_TIMER_FRAME_SIZE - 4, CONTEST_TIMER_FRAME_SIZE - 8)
            if visual.timerText.SetWordWrap then
                visual.timerText:SetWordWrap(false)
            end
            if visual.timerText.SetNonSpaceWrap then
                visual.timerText:SetNonSpaceWrap(false)
            end
            if visual.timerText.SetMaxLines then
                visual.timerText:SetMaxLines(1)
            end
        end
    end
end

ConfigureContestTimerScale(frame and frame:GetScale() or 1)

contestAnimationFrame.elapsed = 0
contestAnimationFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + (elapsed or 0)
    if self.elapsed < 0.05 then return end
    self.elapsed = 0
    local now = GetTime()
    for _, baseNode in ipairs(BASE_NODES) do
        local state = contestedBaseStates[baseNode.id]
        local visual = contestedBaseVisuals[baseNode.id]
        if state and visual and state.active then
            if state.endTime then
                local rawRemaining = state.endTime - now

                if rawRemaining > 0 then
                    local speed = rawRemaining <= 5 and 9.0 or 4.5
                    local wave = 0.5 + (0.5 * math.sin(now * speed))
                    if state.faction == "Alliance" then
                        visual.texture:SetAlpha(0.50 + (0.28 * wave))
                    else
                        visual.texture:SetAlpha(0.46 + (0.26 * wave))
                    end
                    visual.timerFrame:SetAlpha(1)
                    visual.timerText:SetAlpha(1)
                    local shownRemaining = math.max(0, math.ceil(rawRemaining))
                    visual.timerText:SetText(tostring(shownRemaining))
                    if shownRemaining < 10 then
                        local textBreath = 0.5 + (0.5 * math.sin(now * speed))
                        local warningR = CONTEST_TIMER_WARNING_R + ((1.00 - CONTEST_TIMER_WARNING_R) * textBreath)
                        local warningG = CONTEST_TIMER_WARNING_G + ((0.98 - CONTEST_TIMER_WARNING_G) * textBreath)
                        local warningB = CONTEST_TIMER_WARNING_B + ((0.58 - CONTEST_TIMER_WARNING_B) * textBreath)
                        visual.timerText:SetTextColor(warningR, warningG, warningB, 1)
                    elseif shownRemaining == 10 then
                        visual.timerText:SetTextColor(CONTEST_TIMER_WARNING_R, CONTEST_TIMER_WARNING_G, CONTEST_TIMER_WARNING_B, 1)
                    else
                        visual.timerText:SetTextColor(CONTEST_TIMER_NORMAL_R, CONTEST_TIMER_NORMAL_G, CONTEST_TIMER_NORMAL_B, 1)
                    end
                else
                    -- Hold 0 for one final second of a single breath flourish,
                    -- then switch the contested visual off cleanly with no fade-out tail.
                    local flourishAge = now - state.endTime
                    if flourishAge < CONTEST_FINISH_FLOURISH_SECONDS then
                        local progress = flourishAge / CONTEST_FINISH_FLOURISH_SECONDS
                        local breath = math.sin(progress * math.pi)
                        if state.faction == "Alliance" then
                            visual.texture:SetAlpha(0.52 + (0.34 * breath))
                        else
                            visual.texture:SetAlpha(0.48 + (0.32 * breath))
                        end
                        visual.timerFrame:SetAlpha(1)
                        visual.timerText:SetAlpha(1)
                        local zeroR = CONTEST_TIMER_WARNING_R + ((1.00 - CONTEST_TIMER_WARNING_R) * breath)
                        local zeroG = CONTEST_TIMER_WARNING_G + ((0.98 - CONTEST_TIMER_WARNING_G) * breath)
                        local zeroB = CONTEST_TIMER_WARNING_B + ((0.58 - CONTEST_TIMER_WARNING_B) * breath)
                        visual.timerText:SetTextColor(zeroR, zeroG, zeroB, 1)
                        visual.timerText:SetText("0")
                    else
                        FinishContestedBase(baseNode.id)
                    end
                end
            else
                local wave = 0.5 + (0.5 * math.sin(now * 4.5))
                if state.faction == "Alliance" then
                    visual.texture:SetAlpha(0.50 + (0.28 * wave))
                else
                    visual.texture:SetAlpha(0.46 + (0.26 * wave))
                end
                visual.timerFrame:SetAlpha(1)
                visual.timerText:SetAlpha(1)
                visual.timerText:SetTextColor(CONTEST_TIMER_NORMAL_R, CONTEST_TIMER_NORMAL_G, CONTEST_TIMER_NORMAL_B, 1)
                visual.timerText:SetText("??")
            end
        end
    end
end)

local TEST_BASE_ALIASES = {
    st = "STABLES",
    stables = "STABLES",
    gm = "GOLD_MINE",
    mine = "GOLD_MINE",
    goldmine = "GOLD_MINE",
    bs = "BLACKSMITH",
    blacksmith = "BLACKSMITH",
    lm = "LUMBER_MILL",
    lumbermill = "LUMBER_MILL",
    farm = "FARM",
}

local function ClearContestTestMode()
    contestedTestMode = false
    abTestMode = false
    abTestBaseNodeStates = {}
    if HideABTestBlips then
        HideABTestBlips()
    end
    for _, baseNode in ipairs(BASE_NODES) do
        HideContestedBase(baseNode.id)
    end
    RefreshBaseNodes()
end

local function StartContestTest(baseToken, factionToken, secondsToken)
    local baseID = TEST_BASE_ALIASES[string.lower(baseToken or "")]
    local baseNode = baseID and BASE_NODE_BY_ID[baseID] or nil
    local factionLower = string.lower(factionToken or "")
    local faction = nil
    if factionLower == "ally" or factionLower == "alliance" or factionLower == "blue" then
        faction = "Alliance"
    elseif factionLower == "horde" or factionLower == "red" then
        faction = "Horde"
    end

    if not baseNode or not faction then
        print("|cff33ff99Zurk Maps|r test usage: /ab testcontest <ST|GM|BS|LM|Farm> <ally|horde> [seconds]")
        return
    end

    local seconds = tonumber(secondsToken) or 60
    seconds = math.max(1, math.min(300, seconds))
    contestedTestMode = true
    for _, node in ipairs(BASE_NODES) do
        HideContestedBase(node.id)
    end
    StartContestedBase(baseNode, faction, seconds, "test", nil)
    print(string.format("|cff33ff99Zurk Maps|r testing %s contested by %s for %d seconds.", baseNode.name, faction, seconds))
end

local function StartAllContestTests()
    contestedTestMode = true
    abTestMode = true
    RandomizeABTestPlayers()
    abTestBaseNodeStates = {}
    for _, baseNode in ipairs(BASE_NODES) do
        HideContestedBase(baseNode.id)
    end

    print("|cff33ff99Zurk Maps|r AB test mode: 15 moving gold friendly blips with generated Horde names + randomized assaults that resolve to full control:")
    for _, baseNode in ipairs(BASE_NODES) do
        local faction = math.random(1, 2) == 1 and "Alliance" or "Horde"
        local seconds = math.random(12, 35)
        local stateOffset = faction == "Alliance" and 1 or 3
        local textureIndex = baseNode.neutralTextureIndex + stateOffset
        abTestBaseNodeStates[baseNode.id] = textureIndex
        UpdateBaseNodeButton(baseNode, textureIndex)
        StartContestedBase(baseNode, faction, seconds, "random all-base test", nil)
        print(string.format("  %s: %s assaulting, %ds", baseNode.name, faction, seconds))
    end
    if ShowABTestBlips then
        ShowABTestBlips()
    end
end

local function PrintABDotPositionDebug()
    if not IsInArathiBasin() then
        print("|cff33ff99Zurk Maps|r dotdebug: enter Arathi Basin first.")
        return
    end

    RefreshBaseNodes()

    local geometry = abFriendlyPositionGeometry
    print(string.format(
        "|cff33ff99Zurk Maps|r AB blip transform: calibrated=%s x=(%.5f * raw %+.5f) y=(%.5f * raw %+.5f)",
        tostring(geometry.calibrated),
        geometry.xScale, geometry.xOffset,
        geometry.yScale, geometry.yOffset
    ))

    for _, baseNode in ipairs(BASE_NODES) do
        local sample = abFriendlyCalibrationSamples[baseNode.id]
        if sample then
            local projectedX = (sample.rawX * geometry.xScale) + geometry.xOffset
            local projectedY = (sample.rawY * geometry.yScale) + geometry.yOffset
            print(string.format(
                "  %s raw=(%.4f, %.4f) projected=(%.2f, %.2f) target=(%.2f, %.2f)",
                baseNode.callout,
                sample.rawX, sample.rawY,
                projectedX * 100, projectedY * 100,
                sample.targetX * 100, sample.targetY * 100
            ))
        end
    end
end

local function PrintAreaPOITimerDebug()
    if not IsInArathiBasin() then
        print("|cff33ff99Zurk Maps|r timerdebug: enter Arathi Basin first.")
        return
    end
    if not C_AreaPoiInfo or type(C_AreaPoiInfo.GetAreaPOIForMap) ~= "function" or type(C_AreaPoiInfo.GetAreaPOIInfo) ~= "function" then
        print("|cff33ff99Zurk Maps|r timerdebug: C_AreaPoiInfo APIs unavailable.")
        return
    end

    local mapID = GetABUiMapID()
    local okIDs, poiIDs = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
    if not okIDs or type(poiIDs) ~= "table" then
        print("|cff33ff99Zurk Maps|r timerdebug: unable to read AreaPOIs for map " .. tostring(mapID) .. ".")
        return
    end

    print("|cff33ff99Zurk Maps|r AreaPOI timer snapshot:")
    for _, poiID in ipairs(poiIDs) do
        local okInfo, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
        if okInfo and type(info) == "table" then
            local nodeID = GetBaseNodeIDFromName(info.name) or GetBaseNodeIDFromTextureIndex(info.textureIndex)
            if nodeID then
                local seconds, source = GetPOIRemainingSeconds(poiID)
                print(string.format("  %s | poi=%s | texture=%s | timer=%s | source=%s",
                    tostring(info.name), tostring(poiID), tostring(info.textureIndex),
                    seconds and string.format("%.2f", seconds) or "nil", tostring(source)))
            end
        end
    end
end

RefreshBaseNodes()

local baseNodeUpdateFrame = CreateFrame("Frame", nil, frame)
baseNodeUpdateFrame:SetScript("OnUpdate", function(_, elapsed)
    if not frame:IsShown() or not IsInArathiBasin() then
        return
    end

    baseNodeRefreshElapsed = baseNodeRefreshElapsed + elapsed
    if baseNodeRefreshElapsed < 0.20 then
        return
    end
    baseNodeRefreshElapsed = 0
    RefreshBaseNodes()
end)

-- Friendly-player position overlay. This intentionally mirrors the WSG addon:
-- Blizzard's native UnitPositionFrame/GroupMembersPinTemplate renders the blips,
-- while Zurk's map provides the artwork beneath it.
local AB_FRIENDLY_PLAYER_DOT_SIZE = 10
local CLASS_COLOR_FALLBACK = {
    WARRIOR = { 0.78, 0.61, 0.43 },
    PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1.00, 0.96, 0.41 },
    PRIEST = { 1.00, 1.00, 1.00 },
    SHAMAN = { 0.00, 0.44, 0.87 },
    MAGE = { 0.25, 0.78, 0.92 },
    WARLOCK = { 0.53, 0.53, 0.93 },
    DRUID = { 1.00, 0.49, 0.04 },
}

local friendlyPlayersClipFrame = CreateFrame("Frame", nil, map)
friendlyPlayersClipFrame:SetAllPoints(map)
friendlyPlayersClipFrame:SetFrameLevel(mapBorder:GetFrameLevel() + 3)
if friendlyPlayersClipFrame.SetClipsChildren then
    friendlyPlayersClipFrame:SetClipsChildren(true)
end
friendlyPlayersClipFrame:EnableMouse(false)

local friendlyPlayersFrame = nil
local friendlyPlayersFrameAvailable = false
local friendlyPlayersElapsed = 0
local hoveredFriendlyPlayersSignature = nil

ZurkMapsABRank = ZurkMapsPlayerBlips.CreateRankController({
    min = 12,
    max = 14,
    iconScale = 0.924,
    baseDotSize = AB_FRIENDLY_PLAYER_DOT_SIZE,
    getFriendlyFrame = function() return friendlyPlayersFrame end,
    isAvailable = function() return friendlyPlayersFrameAvailable end,
    getMapFrame = function() return map end,
    getUiMapID = GetABUiMapID,
    getDotSize = function() return ZurkMapsPlayerBlips.GetDotSize(AB_FRIENDLY_PLAYER_DOT_SIZE, frame) end,
    getClassColor = function(unit) return ZurkMapsPlayerBlips.GetClassColor(unit, CLASS_COLOR_FALLBACK) end,
    mapWidth = MAP_WIDTH,
    mapHeight = MAP_HEIGHT,
})

local function ApplyFriendlyPositionGeometry()
    if not friendlyPlayersFrame then
        return
    end

    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT
    local geometry = abFriendlyPositionGeometry

    friendlyPlayersFrame:ClearAllPoints()
    friendlyPlayersFrame:SetPoint(
        "TOPLEFT",
        map,
        "TOPLEFT",
        geometry.xOffset * mapWidth,
        -(geometry.yOffset * mapHeight)
    )
    friendlyPlayersFrame:SetSize(
        geometry.xScale * mapWidth,
        geometry.yScale * mapHeight
    )
end

ConfigureFriendlyPlayerDots = function()
    if not friendlyPlayersFrameAvailable then
        return
    end

    ApplyFriendlyPositionGeometry()
    pcall(friendlyPlayersFrame.SetUiMapID, friendlyPlayersFrame, GetABUiMapID())
    pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "player", true)
    pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "party", true)
    pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "raid", true)

    local dotSize = ZurkMapsPlayerBlips.GetDotSize(AB_FRIENDLY_PLAYER_DOT_SIZE, frame)
    pcall(friendlyPlayersFrame.SetPinSize, friendlyPlayersFrame, "player", dotSize)
    pcall(friendlyPlayersFrame.SetPinSize, friendlyPlayersFrame, "party", dotSize)
    pcall(friendlyPlayersFrame.SetPinSize, friendlyPlayersFrame, "raid", dotSize)

    ZurkMapsABRank.ColorFriendlyUnit("player")
    for i = 1, 4 do
        ZurkMapsABRank.ColorFriendlyUnit("party" .. i)
    end
    for i = 1, 40 do
        ZurkMapsABRank.ColorFriendlyUnit("raid" .. i)
    end

    pcall(friendlyPlayersFrame.UpdatePlayerPins, friendlyPlayersFrame)
    ZurkMapsABRank.UpdateBlips()
    if abTestMode and UpdateABTestBlips then
        UpdateABTestBlips()
    end
end

local function UpdateFriendlyPlayerPositions()
    if friendlyPlayersFrameAvailable and friendlyPlayersFrame:IsShown() then
        pcall(friendlyPlayersFrame.UpdatePlayerPins, friendlyPlayersFrame)
        ZurkMapsABRank.UpdateBlips()
    end
end

do
    local ok, created = pcall(
        CreateFrame,
        "UnitPositionFrame",
        nil,
        friendlyPlayersClipFrame,
        "GroupMembersPinTemplate"
    )
    if ok and created then
        friendlyPlayersFrame = created
        friendlyPlayersFrame.dataProvider = ZurkMapsABRank.dataProvider
        friendlyPlayersFrame:SetScript("OnUpdate", nil)
        friendlyPlayersFrame:SetFrameLevel(friendlyPlayersClipFrame:GetFrameLevel() + 1)

        if friendlyPlayersFrame.SetMouseMotionEnabled then
            friendlyPlayersFrame:SetMouseMotionEnabled(true)
        else
            friendlyPlayersFrame:EnableMouse(true)
        end
        if friendlyPlayersFrame.SetMouseClickEnabled then
            friendlyPlayersFrame:SetMouseClickEnabled(false)
        end

        local mapOK = pcall(friendlyPlayersFrame.SetUiMapID, friendlyPlayersFrame, GetABUiMapID())
        local unitsOK = pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "raid", true)
        friendlyPlayersFrameAvailable = mapOK and unitsOK and type(friendlyPlayersFrame.UpdatePlayerPins) == "function"
        friendlyPlayersFrame:SetShown(false)

        if friendlyPlayersFrameAvailable then
            ConfigureFriendlyPlayerDots()
        end
    end
end

local friendlyPlayersUpdateFrame = CreateFrame("Frame", nil, frame)
friendlyPlayersUpdateFrame:SetScript("OnUpdate", function(_, elapsed)
    if not friendlyPlayersFrameAvailable or not friendlyPlayersFrame:IsShown() then
        return
    end

    friendlyPlayersElapsed = friendlyPlayersElapsed + elapsed
    if friendlyPlayersElapsed < 0.05 then
        return
    end
    friendlyPlayersElapsed = 0
    UpdateFriendlyPlayerPositions()
end)

-- Synthetic AB friendly-player overlay used by /ab test. Test players use
-- Blizzard's native world-map party blip artwork and travel through a waypoint graph
-- traced along the visible AB roads. Multiple players may share the same route,
-- but each moves and pauses independently so groups remain loose and may overlap.
local AB_HORDE_TEST_NAMES = {
    "Zugmash", "Mokthar", "Grimtotem", "Ragetusk", "Drekka", "Skullbash",
    "Hexhoof", "Gromsnack", "Bonetusk", "Frostfang", "Mudsnout", "Razortusk",
    "Axehoof", "Wolfsnout", "Doomtotem", "Shadowtusk", "Mokgor", "Thrakka",
    "Zugzug", "Grimfang", "Bloodtotem", "Rotgut", "Hexgrin", "Rokzug",
    "Voodooman", "Totemsmash", "Ironhoof", "Darkspear", "Ashfang", "Warhoof",
}
local AB_HORDE_TEST_CLASSES = { "WARRIOR", "SHAMAN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID" }
local AB_TEST_GOLD_R, AB_TEST_GOLD_G, AB_TEST_GOLD_B = 1.00, 0.82, 0.18
local AB_TEST_BASE_SPEED_SCALE = 0.70
local AB_TEST_MOUNT_SPEED_MULTIPLIER = 2.00
local AB_TEST_MOUNT_CHANCE = 0.055
local AB_TEST_BLIP_TEX_COORDS = {
    WARRIOR = {0.000, 0.125, 0.000, 0.250},
    PALADIN = {0.125, 0.250, 0.000, 0.250},
    HUNTER  = {0.250, 0.375, 0.000, 0.250},
    ROGUE   = {0.375, 0.500, 0.000, 0.250},
    PRIEST  = {0.500, 0.625, 0.000, 0.250},
    SHAMAN  = {0.750, 0.875, 0.000, 0.250},
    MAGE    = {0.875, 1.000, 0.000, 0.250},
    WARLOCK = {0.000, 0.125, 0.250, 0.500},
    DRUID   = {0.250, 0.375, 0.250, 0.500},
}

-- Road corridors traced against the actual AB artwork. The important rule here is
-- that consecutive waypoints stay on the same visible road. Players may leave the
-- road only for the final short approach to a flag/node; they never shortcut the moat.
local AB_PATH_ST_TO_BS = {
    {0.291,0.284}, {0.305,0.265}, {0.335,0.282}, {0.370,0.300},
    {0.405,0.292}, {0.445,0.285}, {0.485,0.292}, {0.520,0.312},
    {0.515,0.345}, {0.507,0.382}, {0.503,0.420}, {0.500,0.460},
    {0.494,0.509},
}
local AB_PATH_ST_TO_GM = {
    {0.291,0.284}, {0.305,0.265}, {0.335,0.282}, {0.370,0.300},
    {0.405,0.292}, {0.445,0.285}, {0.485,0.292}, {0.520,0.312},
    {0.555,0.325}, {0.590,0.330}, {0.625,0.325}, {0.660,0.310},
    {0.690,0.295}, {0.716,0.285},
}
local AB_PATH_ST_TO_LM = {
    {0.291,0.284}, {0.286,0.325}, {0.285,0.365}, {0.284,0.405},
    {0.278,0.450}, {0.260,0.490}, {0.238,0.535}, {0.235,0.575},
    {0.255,0.615}, {0.285,0.650}, {0.320,0.678}, {0.305,0.700},
    {0.295,0.716},
}
local AB_PATH_BS_TO_GM = {
    {0.494,0.509}, {0.500,0.460}, {0.503,0.420}, {0.507,0.382},
    {0.515,0.345}, {0.520,0.312}, {0.555,0.325}, {0.590,0.330},
    {0.625,0.325}, {0.660,0.310}, {0.690,0.295}, {0.716,0.285},
}
local AB_PATH_BS_TO_LM = {
    {0.494,0.509}, {0.470,0.545}, {0.482,0.585}, {0.502,0.625},
    {0.512,0.660}, {0.505,0.695}, {0.480,0.720}, {0.445,0.738},
    {0.405,0.740}, {0.365,0.725}, {0.330,0.695}, {0.305,0.700},
    {0.295,0.716},
}
local AB_PATH_BS_TO_FARM = {
    {0.494,0.509}, {0.470,0.545}, {0.482,0.585}, {0.502,0.625},
    {0.512,0.660}, {0.545,0.685}, {0.585,0.710}, {0.625,0.735},
    {0.665,0.755}, {0.700,0.765}, {0.718,0.740}, {0.716,0.715},
    {0.713,0.702},
}
local AB_PATH_GM_TO_FARM = {
    {0.716,0.285}, {0.690,0.295}, {0.660,0.310}, {0.625,0.325},
    {0.600,0.350}, {0.620,0.385}, {0.642,0.425}, {0.660,0.465},
    {0.675,0.505}, {0.688,0.550}, {0.698,0.595}, {0.705,0.640},
    {0.710,0.675}, {0.713,0.702},
}
local AB_PATH_LM_TO_FARM = {
    {0.295,0.716}, {0.305,0.700}, {0.330,0.695}, {0.365,0.725},
    {0.405,0.740}, {0.445,0.738}, {0.480,0.720}, {0.505,0.695},
    {0.512,0.660}, {0.545,0.685}, {0.585,0.710}, {0.625,0.735},
    {0.665,0.755}, {0.700,0.765}, {0.718,0.740}, {0.716,0.715},
    {0.713,0.702},
}

local function AppendABRoad(route, road, skipFirst, reverse)
    if reverse then
        for i = #road, 1, -1 do
            if not (skipFirst and i == #road) then route[#route + 1] = road[i] end
        end
    else
        for i = 1, #road do
            if not (skipFirst and i == 1) then route[#route + 1] = road[i] end
        end
    end
end

local function MakeABRoute(segments)
    local route = {}
    local first = true
    for _, segment in ipairs(segments) do
        AppendABRoad(route, segment.road, not first, segment.reverse)
        first = false
    end
    return route
end

local AB_TEST_ROUTE_LIBRARY = {
    -- ST -> BS -> GM -> ST
    MakeABRoute({
        {road=AB_PATH_ST_TO_BS}, {road=AB_PATH_BS_TO_GM}, {road=AB_PATH_ST_TO_GM, reverse=true},
    }),
    -- Farm -> BS -> LM -> Farm
    MakeABRoute({
        {road=AB_PATH_BS_TO_FARM, reverse=true}, {road=AB_PATH_BS_TO_LM}, {road=AB_PATH_LM_TO_FARM},
    }),
    -- ST -> LM -> BS -> ST
    MakeABRoute({
        {road=AB_PATH_ST_TO_LM}, {road=AB_PATH_BS_TO_LM, reverse=true}, {road=AB_PATH_ST_TO_BS, reverse=true},
    }),
    -- GM -> Farm -> BS -> GM
    MakeABRoute({
        {road=AB_PATH_GM_TO_FARM}, {road=AB_PATH_BS_TO_FARM, reverse=true}, {road=AB_PATH_BS_TO_GM},
    }),
    -- LM -> Farm -> GM -> BS -> LM
    MakeABRoute({
        {road=AB_PATH_LM_TO_FARM}, {road=AB_PATH_GM_TO_FARM, reverse=true},
        {road=AB_PATH_BS_TO_GM, reverse=true}, {road=AB_PATH_BS_TO_LM},
    }),
    -- ST -> GM -> BS -> Farm -> LM -> ST
    MakeABRoute({
        {road=AB_PATH_ST_TO_GM}, {road=AB_PATH_BS_TO_GM, reverse=true},
        {road=AB_PATH_BS_TO_FARM}, {road=AB_PATH_LM_TO_FARM, reverse=true},
        {road=AB_PATH_ST_TO_LM, reverse=true},
    }),
}

local AB_TEST_ROUTE_ASSIGNMENTS = { 1,1,1,3,4,2,2,2,4,3,5,5,6,1,6 }
local AB_TEST_STARTS = {
    {0.285,0.285}, {0.330,0.310}, {0.365,0.335}, {0.270,0.500},
    {0.715,0.300}, {0.720,0.700}, {0.665,0.650}, {0.600,0.590},
    {0.750,0.525}, {0.300,0.705}, {0.495,0.515}, {0.430,0.575},
    {0.515,0.760}, {0.590,0.420}, {0.445,0.240},
}

local abTestAgents = {}
for i = 1, 15 do
    local startPoint = AB_TEST_STARTS[i]
    abTestAgents[i] = {
        name = AB_HORDE_TEST_NAMES[i],
        classToken = AB_HORDE_TEST_CLASSES[((i - 1) % #AB_HORDE_TEST_CLASSES) + 1],
        x = startPoint[1], y = startPoint[2],
        route = AB_TEST_ROUTE_LIBRARY[AB_TEST_ROUTE_ASSIGNMENTS[i]], routeIndex = 1,
        speed = 4.4 + ((i * 17) % 24) / 10, pause = 0,
        mounting = false, mounted = false, mountedWaypoints = 0,
        pvpRankNumber = ({ [3] = 12, [9] = 13, [14] = 14 })[i],
        iconKey = "TEST:AB:" .. i,
    }
end
local abTestBlips = {}
for i = 1, #abTestAgents do
    local blip = CreateFrame("Frame", nil, friendlyPlayersClipFrame)
    blip:SetFrameLevel(friendlyPlayersClipFrame:GetFrameLevel() + 1)
    blip:EnableMouse(false)
    blip.shadow = blip:CreateTexture(nil, "ARTWORK")
    blip.shadow:SetPoint("TOPLEFT", blip, "TOPLEFT", -1, 1)
    blip.shadow:SetPoint("BOTTOMRIGHT", blip, "BOTTOMRIGHT", 1, -1)
    blip.shadow:SetTexCoord(0, 1, 0, 1)
    blip.shadow:SetVertexColor(0, 0, 0, 0.72)
    blip.shadow:Hide()
    blip.texture = blip:CreateTexture(nil, "OVERLAY")
    blip.texture:SetAllPoints()
    blip.texture:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
    blip.texture:SetVertexColor(AB_TEST_GOLD_R, AB_TEST_GOLD_G, AB_TEST_GOLD_B, 1)
    blip.texture:SetTexCoord(0, 1, 0, 1)
    blip:Hide()
    abTestBlips[i] = blip
end

local function GetABTestClassColor(classToken)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if color then return color.r, color.g, color.b end
    local fallback = CLASS_COLOR_FALLBACK[classToken]
    if fallback then return fallback[1], fallback[2], fallback[3] end
    return 1, 1, 1
end

local function MoveABTestAgentToward(agent, targetX, targetY, elapsed, speedBoost)
    local dx = targetX - agent.x
    local dy = targetY - agent.y
    local dxPixels = dx * (map:GetWidth() or MAP_WIDTH)
    local dyPixels = dy * (map:GetHeight() or MAP_HEIGHT)
    local distance = math.sqrt((dxPixels * dxPixels) + (dyPixels * dyPixels))
    if distance < 0.01 then return true end
    local movementMultiplier = AB_TEST_BASE_SPEED_SCALE * (agent.mounted and AB_TEST_MOUNT_SPEED_MULTIPLIER or 1)
    local step = (agent.speed * movementMultiplier * (speedBoost or 1)) * elapsed
    if step >= distance then
        agent.x, agent.y = targetX, targetY
        return true
    end
    agent.x = agent.x + ((dxPixels / distance) * step / (map:GetWidth() or MAP_WIDTH))
    agent.y = agent.y + ((dyPixels / distance) * step / (map:GetHeight() or MAP_HEIGHT))
    return false
end

local function AdvanceABTestAgents(elapsed)
    for _, agent in ipairs(abTestAgents) do
        if agent.route and #agent.route > 0 then
            if agent.pause and agent.pause > 0 then
                agent.pause = math.max(0, agent.pause - elapsed)
                if agent.pause <= 0 and agent.mounting then
                    -- A three-second stationary cast simulates mounting. Once the
                    -- cast finishes, this player travels at double their normal
                    -- (already 30%-slower) test speed for several road waypoints.
                    agent.mounting = false
                    agent.mounted = true
                    agent.mountedWaypoints = math.random(6, 12)
                end
            else
                local target = agent.route[agent.routeIndex]
                if MoveABTestAgentToward(agent, target[1], target[2], elapsed, 1) then
                    agent.routeIndex = (agent.routeIndex % #agent.route) + 1

                    if agent.mounted then
                        agent.mountedWaypoints = math.max(0, (agent.mountedWaypoints or 1) - 1)
                        if agent.mountedWaypoints <= 0 then
                            agent.mounted = false
                        end
                    end

                    if not agent.mounted and math.random() < AB_TEST_MOUNT_CHANCE then
                        agent.mounting = true
                        agent.pause = 3.0
                    elseif not agent.mounted then
                        -- Ordinary traffic/objective pauses remain loose and
                        -- independent; mounted players keep riding through them.
                        if math.random() < 0.28 then
                            agent.pause = math.random(4, 28) / 10
                        else
                            agent.pause = math.random(0, 4) / 10
                        end
                    end
                end
            end
        end
    end
end

RandomizeABTestPlayers = function()
    local pool = {}
    for i, name in ipairs(AB_HORDE_TEST_NAMES) do pool[i] = name end
    for i, agent in ipairs(abTestAgents) do
        local pick = math.random(1, #pool)
        agent.name = table.remove(pool, pick)
        agent.classToken = AB_HORDE_TEST_CLASSES[math.random(1, #AB_HORDE_TEST_CLASSES)]
        agent.route = AB_TEST_ROUTE_LIBRARY[AB_TEST_ROUTE_ASSIGNMENTS[i]]
        local spawnIndex = math.random(1, #agent.route)
        local startPoint = agent.route[spawnIndex]
        agent.x, agent.y = startPoint[1], startPoint[2]
        agent.routeIndex = (spawnIndex % #agent.route) + 1
        agent.speed = 4.2 + (math.random(0, 28) / 10)
        agent.pause = math.random(0, 20) / 10
        agent.mounting = false
        agent.mounted = false
        agent.mountedWaypoints = 0
    end
end

UpdateABTestBlips = function()
    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT
    local dotSize = ZurkMapsPlayerBlips.GetDotSize(AB_FRIENDLY_PLAYER_DOT_SIZE, frame)

    for i, agent in ipairs(abTestAgents) do
        local blip = abTestBlips[i]
        local assignedIcon = ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForKey
            and ZurkMapsPlayerIcons.GetAssignedIconForKey(agent.iconKey, true) or nil
        local eliteAssigned = assignedIcon and ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.IsOverlayOnlyIcon
            and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon)
        if eliteAssigned then
            ZurkMapsPlayerBlips.ApplyGoldBlip(blip, dotSize, AB_TEST_GOLD_R, AB_TEST_GOLD_G, AB_TEST_GOLD_B)
            ZurkMapsPlayerIcons.ApplyAssignedIcon(blip, assignedIcon, dotSize)
        elseif assignedIcon and ZurkMapsPlayerIcons.ApplyAssignedIcon then
            ZurkMapsPlayerIcons.ApplyAssignedIcon(blip, assignedIcon, dotSize * (ZurkMapsPlayerIcons.manualIconScale or 0.84))
        elseif agent.pvpRankNumber and agent.pvpRankNumber >= ZurkMapsABRank.min and agent.pvpRankNumber <= ZurkMapsABRank.max then
            ZurkMapsPlayerBlips.ApplyRankBadge(blip, agent.pvpRankNumber, dotSize * ZurkMapsABRank.iconScale, agent.classToken)
        else
            ZurkMapsPlayerBlips.ApplyGoldBlip(blip, dotSize, AB_TEST_GOLD_R, AB_TEST_GOLD_G, AB_TEST_GOLD_B)
        end
        if (not assignedIcon or (ZurkMapsPlayerIcons.IsOverlayOnlyIcon and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon))) and (assignedIcon or not agent.pvpRankNumber or agent.pvpRankNumber < ZurkMapsABRank.min or agent.pvpRankNumber > ZurkMapsABRank.max) then
            ZurkMapsPlayerBlips.ApplyTeammateColor(blip, agent.classToken, eliteAssigned)
        end
        blip:ClearAllPoints()
        blip:SetPoint("CENTER", map, "TOPLEFT", agent.x * mapWidth, -(agent.y * mapHeight))
        blip:SetShown(abTestMode)
    end
end

ShowABTestBlips = function()
    if UpdateABTestBlips then UpdateABTestBlips() end
end

HideABTestBlips = function()
    for _, blip in ipairs(abTestBlips) do blip:Hide() end
end

local function GetABTestPlayersUnderMouse()
    if not abTestMode then return nil end
    local mouseX, mouseY = GetMousePercent()
    if not mouseX or not mouseY then return nil end
    local nx, ny = mouseX / 100, mouseY / 100
    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT
    local radius = math.max(7, ZurkMapsPlayerBlips.GetDotSize(AB_FRIENDLY_PLAYER_DOT_SIZE, frame) * 0.9)
    local matches = {}
    for _, agent in ipairs(abTestAgents) do
        local dx = (nx - agent.x) * mapWidth
        local dy = (ny - agent.y) * mapHeight
        if ((dx * dx) + (dy * dy)) <= (radius * radius) then table.insert(matches, agent) end
    end
    return #matches > 0 and matches or nil
end

local function ShowABTestPlayerTooltip(players)
    if not players or #players == 0 then return false end
    local names = {}
    for _, player in ipairs(players) do table.insert(names, player.name) end
    table.sort(names)
    local signature = "test:" .. table.concat(names, "|")
    if hoveredFriendlyPlayersSignature == signature and GameTooltip:IsShown() then return true end
    hoveredFriendlyPlayersSignature = signature
    ShowZone(nil)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:ClearLines()
    for _, player in ipairs(players) do
        local r, g, b = GetABTestClassColor(player.classToken)
        GameTooltip:AddLine(ZurkMapsPlayerBlips.GetTooltipIconTagForTestPlayer(player) .. player.name, r, g, b)
    end
    local tooltipName = GameTooltip:GetName()
    if tooltipName then
        for i = 1, #players do
            local line = _G[tooltipName .. "TextLeft" .. i]
            if line then line:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
        end
    end
    GameTooltip:Show()
    if ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays then
        ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays(players, true)
    end
    return true
end

local abTestMovementFrame = CreateFrame("Frame", nil, frame)
local abTestMovementElapsed = 0
abTestMovementFrame:SetScript("OnUpdate", function(_, elapsed)
    if not abTestMode then return end
    abTestMovementElapsed = abTestMovementElapsed + elapsed
    if abTestMovementElapsed < 0.05 then return end
    local step = abTestMovementElapsed
    abTestMovementElapsed = 0
    AdvanceABTestAgents(step)
    UpdateABTestBlips()
end)

local function GetFriendlyPlayerMouseoverUnits()
    if not friendlyPlayersFrameAvailable
        or not friendlyPlayersFrame
        or not friendlyPlayersFrame:IsShown() then
        return nil
    end

    local mouseX, mouseY = GetMousePercent()
    if not mouseX or not mouseY or mouseX < 0 or mouseX > 100 or mouseY < 0 or mouseY > 100 then
        return nil
    end

    local units = {}
    local seen = {}

    if type(friendlyPlayersFrame.GetCurrentMouseOverUnits) == "function" then
        local ok, current = pcall(friendlyPlayersFrame.GetCurrentMouseOverUnits, friendlyPlayersFrame)
        if ok and type(current) == "table" then
            for unit in pairs(current) do
                if type(unit) == "string" and UnitExists(unit) and not seen[unit] then
                    seen[unit] = true
                    table.insert(units, unit)
                end
            end
        end
    end

    if #units == 0 and type(friendlyPlayersFrame.GetMouseOverUnits) == "function" then
        local results = { pcall(friendlyPlayersFrame.GetMouseOverUnits, friendlyPlayersFrame) }
        if results[1] then
            for i = 2, #results do
                local unit = results[i]
                if type(unit) == "string" and UnitExists(unit) and not seen[unit] then
                    seen[unit] = true
                    table.insert(units, unit)
                end
            end
        end
    end

    return #units > 0 and units or nil
end

local function GetFriendlyPlayersSignature(units)
    local parts = {}
    for _, unit in ipairs(units) do
        table.insert(parts, UnitGUID(unit) or unit)
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function ShowFriendlyPlayerTooltip(units)
    if not units or #units == 0 then
        return false
    end

    local signature = GetFriendlyPlayersSignature(units)
    if hoveredFriendlyPlayersSignature == signature and GameTooltip:IsShown() then
        return true
    end
    hoveredFriendlyPlayersSignature = signature

    ShowZone(nil)

    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end

    GameTooltip:ClearLines()
    for _, unit in ipairs(units) do
        local name = (GetUnitName and GetUnitName(unit, true)) or UnitName(unit) or unit
        local r, g, b = ZurkMapsPlayerBlips.GetClassColor(unit, CLASS_COLOR_FALLBACK)
        GameTooltip:AddLine(ZurkMapsPlayerBlips.GetTooltipIconTagForUnit(unit, ZurkMapsABRank) .. name, r, g, b)
    end

    local tooltipName = GameTooltip:GetName()
    if tooltipName then
        for i = 1, #units do
            local line = _G[tooltipName .. "TextLeft" .. i]
            if line then
                line:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
            end
        end
    end

    GameTooltip:Show()
    if ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays then
        ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays(units, false)
    end
    return true
end

local function ClearFriendlyPlayerTooltip()
    if hoveredFriendlyPlayersSignature then
        hoveredFriendlyPlayersSignature = nil
        GameTooltip:Hide()
    end
end

-- Hotspot dropdowns are configured by hotspot type.
-- Bases: Safe, then 1+ through 7+.
-- Other hotspots: 1+ through 4+, then Get OUT.
local INCOMING_MENU_WIDTH = 82
local INCOMING_OPTION_HEIGHT = 25
local INCOMING_MENU_PADDING = 5
local INCOMING_MENU_MAX_OPTIONS = 8
local incomingMenu
local incomingMenuDismiss
local incomingMenuZone = nil
local incomingMenuOptions = {}

local incomingMenuAnchor = CreateFrame("Frame", nil, map)
incomingMenuAnchor:SetSize(1, 1)
incomingMenuAnchor:SetPoint("CENTER", map, "CENTER", 0, 0)

local function CloseIncomingMenu()
    if incomingMenu then
        incomingMenu:Hide()
    end
    if incomingMenuDismiss then
        incomingMenuDismiss:Hide()
    end
    incomingMenuZone = nil
    ShowZone(nil)
end

incomingMenuDismiss = CreateFrame("Button", nil, UIParent)
incomingMenuDismiss:SetAllPoints(UIParent)
incomingMenuDismiss:SetFrameStrata("DIALOG")
incomingMenuDismiss:SetFrameLevel(90)
incomingMenuDismiss:EnableMouse(true)
incomingMenuDismiss:RegisterForClicks("AnyUp")
incomingMenuDismiss:SetScript("OnClick", CloseIncomingMenu)
incomingMenuDismiss:Hide()

incomingMenu = CreateFrame(
    "Frame",
    "ZurksABIncomingMenu",
    UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
incomingMenu:SetSize(
    INCOMING_MENU_WIDTH,
    (INCOMING_OPTION_HEIGHT * INCOMING_MENU_MAX_OPTIONS) + (INCOMING_MENU_PADDING * 2)
)
incomingMenu:SetFrameStrata("DIALOG")
incomingMenu:SetFrameLevel(91)
incomingMenu:SetClampedToScreen(true)

if incomingMenu.SetBackdrop then
    incomingMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    incomingMenu:SetBackdropColor(0.03, 0.03, 0.03, 0.96)
    incomingMenu:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
end

incomingMenu:Hide()

local function AnchorIncomingMenu(x, y)
    incomingMenuAnchor:ClearAllPoints()
    incomingMenuAnchor:SetPoint(
        "TOPLEFT",
        map,
        "TOPLEFT",
        (x / 100) * map:GetWidth(),
        -(y / 100) * map:GetHeight()
    )

    incomingMenu:SetScale(frame:GetScale())
    incomingMenu:ClearAllPoints()
    incomingMenu:SetPoint("TOPLEFT", incomingMenuAnchor, "BOTTOMLEFT", 0, -2)
end

local function GetIncomingMenuEntries(zone)
    if zone and zone.isBase then
        return { "Safe", "1+", "2+", "3+", "4+", "5+", "6+", "7+" }
    end

    return { "1+", "2+", "3+", "4+", "Get OUT" }
end

local function ConfigureIncomingMenu(zone)
    local entries = GetIncomingMenuEntries(zone)
    incomingMenu:SetHeight((INCOMING_OPTION_HEIGHT * #entries) + (INCOMING_MENU_PADDING * 2))

    for i, option in ipairs(incomingMenuOptions) do
        local optionText = entries[i]
        if optionText then
            option.calloutText = optionText
            option.label:SetText(optionText)
            option:Show()
        else
            option.calloutText = nil
            option:Hide()
        end
    end
end

local function OpenIncomingMenu(zone, x, y)
    if not zone or not x or not y then
        return
    end

    incomingMenuZone = zone
    hoveredZone = nil
    ShowZone(zone)
    GameTooltip:Hide()
    ConfigureIncomingMenu(zone)
    AnchorIncomingMenu(x, y)
    incomingMenuDismiss:Show()
    incomingMenu:Show()
end

for i = 1, INCOMING_MENU_MAX_OPTIONS do
    local option = CreateFrame("Button", nil, incomingMenu)
    option:SetHeight(INCOMING_OPTION_HEIGHT)
    option:SetPoint(
        "TOPLEFT",
        incomingMenu,
        "TOPLEFT",
        INCOMING_MENU_PADDING,
        -INCOMING_MENU_PADDING - ((i - 1) * INCOMING_OPTION_HEIGHT)
    )
    option:SetPoint(
        "TOPRIGHT",
        incomingMenu,
        "TOPRIGHT",
        -INCOMING_MENU_PADDING,
        -INCOMING_MENU_PADDING - ((i - 1) * INCOMING_OPTION_HEIGHT)
    )

    local optionBG = option:CreateTexture(nil, "BACKGROUND")
    optionBG:SetAllPoints()
    optionBG:SetColorTexture(0.02, 0.02, 0.02, 0.72)

    local optionHighlight = option:CreateTexture(nil, "HIGHLIGHT")
    optionHighlight:SetAllPoints()
    optionHighlight:SetColorTexture(0.85, 0.62, 0.08, 0.55)

    option.label = option:CreateFontString(nil, "OVERLAY")
    option.label:SetPoint("CENTER")
    option.label:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    option.label:SetTextColor(1, 0.88, 0.48, 1)

    option:RegisterForClicks("LeftButtonUp")
    option:SetScript("OnClick", function(self)
        local zone = incomingMenuZone
        local selection = self.calloutText
        CloseIncomingMenu()
        if zone and selection then
            local message = FormatZoneCallout(zone, selection)
            if message then
                Report(message)
            end
        end
    end)

    incomingMenuOptions[i] = option
end

map:SetScript("OnMouseUp", function(self, button)
    if mapDragStarted then
        mapDragStarted = false
        return
    end

    if IsAltKeyDown() or resizing then
        return
    end

    if button == "RightButton" and ZurkMapsPlayerIcons then
        local testPlayers = GetABTestPlayersUnderMouse()
        if testPlayers and ZurkMapsPlayerIcons.OpenAssignmentMenuForTestPlayers(self, testPlayers) then
            CloseIncomingMenu()
            return
        end
        local friendlyUnits = GetFriendlyPlayerMouseoverUnits()
        if friendlyUnits and ZurkMapsPlayerIcons.OpenAssignmentMenuForUnits(self, friendlyUnits) then
            CloseIncomingMenu()
            return
        end
    end

    local x, y = GetMousePercent()
    local zone = FindZone(x, y)

    if button == "RightButton" and not zone and ZurkMapsOptions then
        CloseIncomingMenu()
        ShowZone(nil)
        ZurkMapsOptions.OpenMapMenu("AB", self)
        return
    end

    if zone and zone.isBase then
        if IsShiftKeyDown() then
            CloseIncomingMenu()
            Report(zone.name .. " looking weak.")
            return
        elseif button == "RightButton" then
            CloseIncomingMenu()
            Report("Need HELP at " .. zone.name .. "!!")
            return
        end
    elseif zone and button == "RightButton" then
        CloseIncomingMenu()
        local message = FormatZoneCallout(zone, "Get OUT")
        if message then
            Report(message)
        end
        return
    end

    if button ~= "LeftButton" then
        return
    end

    if zone then
        OpenIncomingMenu(zone, x, y)
    elseif incomingMenu:IsShown() then
        CloseIncomingMenu()
    end
end)

frame:HookScript("OnHide", CloseIncomingMenu)

map:SetScript("OnUpdate", function(self, elapsed)
    if ZurkMapsOptions and ZurkMapsOptions.menu and ZurkMapsOptions.menu:IsShown() then
        return
    end

    if isMoving or resizing
        or (incomingMenu and incomingMenu:IsShown())
        or (focusCallout and focusCallout.menu and focusCallout.menu:IsShown())
        or (focusCallout and focusCallout.button and focusCallout.button:IsMouseOver())
        or (battlecry and battlecry.button and battlecry.button:IsMouseOver())
        or (battlecry and battlecry.panel and battlecry.panel:IsShown()
            and (battlecry.panel:IsMouseOver() or battlecry.editBox:HasFocus())) then
        return
    end

    hoverAccumulator = hoverAccumulator + elapsed
    if hoverAccumulator < 0.03 then
        return
    end
    hoverAccumulator = 0

    if hoveredBaseNode then
        ShowZone(nil)
        return
    end

    if hoveredContestTimerFrame then
        ShowZone(nil)
        if hoveredContestTimerFrame:IsShown() and hoveredContestTimerFrame:IsMouseOver() then
            ShowContestTimerTooltip(hoveredContestTimerFrame.baseNode)
        else
            hoveredContestTimerFrame = nil
            GameTooltip:Hide()
        end
        return
    end

    local testPlayers = GetABTestPlayersUnderMouse()
    if testPlayers then
        ShowABTestPlayerTooltip(testPlayers)
        return
    end

    local friendlyUnits = GetFriendlyPlayerMouseoverUnits()
    if friendlyUnits then
        ShowFriendlyPlayerTooltip(friendlyUnits)
        return
    end

    ClearFriendlyPlayerTooltip()
    local x, y = GetMousePercent()
    ShowZone(FindZone(x, y))
end)

map:SetScript("OnLeave", function()
    ClearFriendlyPlayerTooltip()
    if not isMoving and not resizing and not hoveredBaseNode and not hoveredContestTimerFrame then
        ShowZone(nil)
    end
end)

local function UpdateVisibility()
    local inAB = IsInArathiBasin()

    if InCombatLockdown and InCombatLockdown() then
        pendingVisibilityUpdate = true
        return false
    end

    pendingVisibilityUpdate = false

    if abTestMode then
        frame:Show()
    elseif manualVisibility == "show" then
        frame:Show()
    elseif manualVisibility == "hide" then
        frame:Hide()
    elseif inAB then
        frame:Show()
    else
        frame:Hide()
    end

    frame.ApplyABHonorBarVisibility()

    if abTestMode then
        if friendlyPlayersFrame then
            friendlyPlayersFrame:Hide()
        end
        if ShowABTestBlips then
            ShowABTestBlips()
        end
    elseif inAB and frame:IsShown() and friendlyPlayersFrameAvailable then
        if HideABTestBlips then
            HideABTestBlips()
        end
        ConfigureFriendlyPlayerDots()
        friendlyPlayersFrame:Show()
    else
        if friendlyPlayersFrame then
            friendlyPlayersFrame:Hide()
        end
        if HideABTestBlips then
            HideABTestBlips()
        end
    end

    if RefreshBaseNodes then
        RefreshBaseNodes()
    end

    return true
end

local function ResetLayout()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetScale(1)
    UpdateMoveHandleScale(1)
    SaveLayout()
end

local function PrintABOptions()
    print("|cff33ff99Zurk Maps|r commands:")
    print("|cffffff00/ab show|r - Show Zurk Maps.")
    print("|cffffff00/ab hide|r - Hide Zurk Maps.")
    print("|cffffff00/ab reset|r - Reset saved position and size.")
    print("Base hotspots: Safe + 1+ to 7+. Other hotspots: 1+ to 4+ + Get OUT.")
    print("Base nodes: left-click SPIN, right-click HELP, Shift-click weak.")
    print("|cffffff00/ab testcontest ST ally 60|r - Preview one contested hotspot animation/timer.")
    print("|cffffff00/ab test|r - Show 15 moving gold friendly blips plus assaults that resolve into full control.")
    print("|cffffff00/ab test off|r - Stop AB simulation and restore live data.")
    print("|cffffff00/ab testcontest off|r - Stop contested visual test mode.")
    print("|cffffff00/ab timerdebug|r - Print live AB AreaPOI timer data for verification.")
    print("|cffffff00/ab dotdebug|r - Print live teammate-blip coordinate calibration.")
end

SLASH_ABCALLOUTS1 = "/ab"

SlashCmdList["ABCALLOUTS"] = function(msg)
    msg = string.lower((msg or ""):match("^%s*(.-)%s*$"))

    if msg == "show" then
        manualVisibility = "show"
        local applied = UpdateVisibility()
        print("|cff33ff99Zurk Maps|r " .. (applied and "shown." or "will show after combat."))
    elseif msg == "hide" then
        if abTestMode or contestedTestMode then
            -- End simulation first so fake blips/timers are cleared and every base
            -- node is restored to live (or neutral outside AB) before the map hides.
            ClearContestTestMode()
        end
        manualVisibility = "hide"
        local applied = UpdateVisibility()
        print("|cff33ff99Zurk Maps|r " .. (applied and "hidden." or "will hide after combat."))
    elseif msg == "reset" then
        ResetLayout()
        print("|cff33ff99Zurk Maps|r position and size reset.")
    elseif msg == "timerdebug" then
        PrintAreaPOITimerDebug()
    elseif msg == "dotdebug" then
        PrintABDotPositionDebug()
    elseif msg == "test" or msg == "test all" or msg == "test random" then
        StartAllContestTests()
        UpdateVisibility()
    elseif msg == "test off" or msg == "test clear" then
        ClearContestTestMode()
        UpdateVisibility()
        print("|cff33ff99Zurk Maps|r AB test mode stopped; live data restored.")
    elseif string.find(msg, "^testcontest") then
        local _, _, arg1, arg2, arg3 = string.find(msg, "^testcontest%s*(%S*)%s*(%S*)%s*(%S*)")
        if arg1 == "off" or arg1 == "clear" then
            ClearContestTestMode()
            UpdateVisibility()
            print("|cff33ff99Zurk Maps|r contested visual test mode stopped.")
        elseif arg1 == "all" or arg1 == "random" then
            StartAllContestTests()
        else
            StartContestTest(arg1, arg2, arg3)
        end
    else
        PrintABOptions()
    end
end

if ZurkMapsOptions then
    ZurkMapsOptions.RegisterMap("AB", {
        frame = frame,
        mapTexture = mapTexture,
        refreshBlips = function() ConfigureFriendlyPlayerDots(); if UpdateABTestBlips then UpdateABTestBlips() end end,
        title = "Arathi Basin",
        db = ZurksABCalloutMapDB,
        closeCommand = "hide",
        runCommand = function(command) SlashCmdList["ABCALLOUTS"](command or "") end,
        isTestModeActive = function() return contestedTestMode or abTestMode end,
        isHonorBarVisible = function() return frame.IsABHonorBarVisible() end,
        setHonorBarVisible = function(value) frame.SetABHonorBarVisible(value) end,
        getHonorBarMode = function() return frame.GetABHonorBarMode() end,
        setHonorBarMode = function(mode) if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMode then ZurkMapsHonorWidget.SetMode(mode, "AB") end end,
        isHonorBarUnlocked = function() return frame.IsABHonorBarUnlocked() end,
        setHonorBarUnlocked = function(value) frame.SetABHonorBarUnlocked(value) end,
        commands = {
            { label = "Hide Map", command = "hide" },
            { label = "Reset Position & Size", command = "reset" },
            { divider = true },
            { label = "Start Test", command = "test" },
            { label = "Stop Test", command = "test off" },
        },
    })
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("AREA_POIS_UPDATED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            RestoreLayout()
            UpdateVisibility()
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS" then
        UpdateVisibility()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if pendingVisibilityUpdate then
            UpdateVisibility()
        end
        return
    end

    if event == "AREA_POIS_UPDATED" then
        if RefreshBaseNodes and not contestedTestMode then
            RefreshBaseNodes()
        end
        return
    end

    if event == "PLAYER_LOGOUT" then
        SaveLayout()
    end
end)
