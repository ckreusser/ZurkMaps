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
local hoveredAreaOverlay = nil
local isMoving = false
local resizing = false
local hoverAccumulator = 0
local manualVisibility = nil
local pendingVisibilityUpdate = false
local ConfigureFriendlyPlayerDots = nil
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
                {24.40, 37.55}, {24.45, 39.45}, {25.20, 41.55}, {26.45, 43.75},
                {27.55, 45.95}, {28.05, 47.75}, {27.55, 49.20}, {26.40, 50.75},
                {25.20, 52.35}, {24.25, 54.05}, {24.10, 56.35}, {24.60, 57.85},
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
                {53.20, 31.55}, {55.30, 32.75}, {57.45, 34.55}, {59.45, 37.10},
                {61.55, 39.90}, {63.90, 42.35}, {65.75, 45.05}, {66.45, 47.55},
                {66.80, 49.55}, {68.45, 52.15},
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
                {66.80, 46.35}, {67.10, 47.90}, {67.75, 49.65}, {68.70, 51.75},
                {70.25, 53.55}, {72.55, 55.35}, {73.30, 55.85},
            },
            {
                {71.55, 44.55}, {71.55, 46.65}, {71.70, 48.80}, {72.10, 50.85},
                {72.70, 53.10}, {73.30, 55.85},
            },
            {
                {73.25, 55.70}, {74.55, 57.45}, {75.85, 59.35}, {76.55, 60.65},
                {76.55, 61.30},
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
                {27.80, 50.05}, {29.60, 52.15}, {31.75, 55.10}, {33.55, 56.95},
                {37.10, 59.85}, {38.70, 60.75}, {40.10, 62.00}, {44.55, 65.30},
                {46.05, 66.25},
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

local ZONE_BY_ID = {}
for _, zone in ipairs(ZONES) do
    ZONE_BY_ID[zone.id] = zone
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

local function GetEnemyFactionDisplayName()
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    if faction == "Alliance" then
        return "Horde"
    elseif faction == "Horde" then
        return "Alliance"
    end
    return "Enemy"
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

local function GetBaseReportDescriptor(zone)
    local reportType = IsBaseHeldOrAssaultedByPlayerFaction(zone) and "incoming" or "visible"
    return GetEnemyFactionDisplayName() .. " " .. reportType
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
        return dropdownSelection .. " " .. enemyFaction .. " at " .. location
    elseif zone.calloutStyle == "road_spotted" then
        return dropdownSelection .. " " .. enemyFaction .. " spotted on the " .. location
    elseif zone.isBase and not IsBaseHeldOrAssaultedByPlayerFaction(zone) then
        return dropdownSelection .. " " .. enemyFaction .. " visible at " .. location
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
    mapBorder:SetBackdropBorderColor(BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B, 1)
end

mapBorder:EnableMouse(false)
mapBorder:SetFrameLevel(map:GetFrameLevel() + 10)

-- Keep the artwork opaque up to the rim at 100%, with the shared opacity
-- setting controlling transparency and hard clipping containing the overscan.
map.interiorMask = ZurkMapsInteriorMask.Create(map, mapBorder, 3, 4, true)
ZurkMapsInteriorMask.Apply(map.interiorMask, mapTexture)


do
-- Arathi Basin game-pace timer. The resource-rate table and score-widget parsing
-- are adapted from Capping's Classic AB estimator, but all state is owned by
-- Zurk Maps and named for this map. The widget does not appear until a base is
-- fully controlled, then slides down from a clipped position beneath the header.
local AB_WIN_TIMER_MAX_SCORE = 2000
local AB_WIN_TIMER_ALLIANCE_WIDGET_ID = 1893
local AB_WIN_TIMER_HORDE_WIDGET_ID = 1894
local AB_WIN_TIMER_SCORE_PER_SECOND = {
    [1] = 0.8333,
    [2] = 1.1111,
    [3] = 1.6667,
    [4] = 3.3333,
    [5] = 30,
}
local AB_WIN_TIMER_WIDTH = 202
local AB_WIN_TIMER_HEIGHT = 30
local AB_WIN_TIMER_FILL_HEIGHT = 10
local AB_WIN_TIMER_ICON_GUTTER = 54
local AB_WIN_TIMER_MASK_HEIGHT = 34
local AB_WIN_TIMER_START_Y = 30
local AB_WIN_TIMER_TARGET_Y = -1
local AB_WIN_TIMER_SLIDE_SECONDS = 0.38
local AB_WIN_TIMER_GLOW_SECONDS = 0.82
local AB_WIN_TIMER_ICON_GLOW_FADE_SECONDS = 0.42
local AB_WIN_TIMER_LIVE_POLL_SECONDS = 0.15
local AB_WIN_TIMER_TIE_EPSILON = 0.10
local AB_WIN_TIMER_INFINITY = 1000000

-- The 5-base crawl uses one synchronized IconAlertAnts animation split across
-- three geometry regions: a wide top/bottom band and two square end-cap fields.
-- A single extremely wide, shallow action-button sprite left permanent dead
-- areas on the side centers and forced the side rays to share the same allowance
-- as the top/bottom rays. Keep r65's accepted vertical reach, but make the side
-- allowance independently much tighter.
local AB_WIN_TIMER_CRAWL_INNER_WIDTH_PAD = 2.0
local AB_WIN_TIMER_CRAWL_INNER_HEIGHT_TRIM = 2.0
local AB_WIN_TIMER_CRAWL_VERTICAL_OUTSET = 6.0
local AB_WIN_TIMER_CRAWL_SIDE_OUTSET = 1.25
local AB_WIN_TIMER_CRAWL_BAND_OVERLAP = 0.50
local AB_WIN_TIMER_FACTION_COLOR = {
    Alliance = { 0.12, 0.46, 1.00 },
    Horde = { 0.96, 0.16, 0.10 },
}

-- Horde's 4-base pace glow should read as clearly red, not orange or gray.
-- Keep the same geometry, but use stacked red-only tints with a mild overall
-- alpha boost so the Horde pace glow stays visible.
local AB_WIN_TIMER_HORDE_PACE_GLOW_COLOR = { 1.00, 0.00, 0.00 }
local AB_WIN_TIMER_HORDE_PACE_GLOW_ALPHA_MULT = 1.25
local AB_WIN_TIMER_HORDE_PACE_GLOW_HOT_COLOR = { 1.00, 0.15, 0.12 }
local AB_WIN_TIMER_HORDE_PACE_GLOW_LEFT_INSET = 6
local AB_WIN_TIMER_HORDE_PACE_GLOW_RIGHT_INSET = 6
local AB_WIN_TIMER_HORDE_PACE_GLOW_TOP_INSET = 1
local AB_WIN_TIMER_HORDE_PACE_GLOW_BOTTOM_INSET = 1
local AB_WIN_TIMER_HORDE_PACE_GLOW_X_OFFSET = 2

local function ABWinTimerNow()
    return type(GetTime) == "function" and GetTime() or 0
end

local function ApplyABWinTimerAtlas(texture, atlasChoices)
    if not texture or type(texture.SetAtlas) ~= "function" then return nil end
    for _, atlasName in ipairs(atlasChoices or {}) do
        local atlasExists = true
        if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
            local infoOK, atlasInfo = pcall(C_Texture.GetAtlasInfo, atlasName)
            atlasExists = infoOK and atlasInfo ~= nil
        end
        if atlasExists then
            local ok = pcall(texture.SetAtlas, texture, atlasName, false)
            if ok then return atlasName end
        end
    end
    return nil
end

local abWinTimerMask = CreateFrame("Frame", nil, map)
abWinTimerMask:SetSize(AB_WIN_TIMER_WIDTH + 12, AB_WIN_TIMER_MASK_HEIGHT)
abWinTimerMask:SetPoint("TOP", map, "TOP", 0, 0)
abWinTimerMask:SetFrameLevel(mapBorder:GetFrameLevel() + 8)
abWinTimerMask:EnableMouse(false)
if abWinTimerMask.SetClipsChildren then
    abWinTimerMask:SetClipsChildren(true)
end

local abWinTimerWidget = CreateFrame("Frame", nil, abWinTimerMask)
abWinTimerWidget:SetSize(AB_WIN_TIMER_WIDTH, AB_WIN_TIMER_HEIGHT)
abWinTimerWidget:SetPoint("TOP", abWinTimerMask, "TOP", 0, AB_WIN_TIMER_START_Y)
abWinTimerWidget:SetFrameLevel(abWinTimerMask:GetFrameLevel() + 1)
abWinTimerWidget:EnableMouse(false)
abWinTimerWidget:Hide()

abWinTimerWidget.frameTexture = abWinTimerWidget:CreateTexture(nil, "ARTWORK")
abWinTimerWidget.frameTexture:SetAllPoints()
ApplyABWinTimerAtlas(abWinTimerWidget.frameTexture, {
    "worldstate-capturebar-frame-factions",
    "worldstate-capturebar-frame",
})

local abWinTimerTrackWidth = math.max(1, (AB_WIN_TIMER_WIDTH - AB_WIN_TIMER_ICON_GUTTER) + 12)
local abWinTimerIconCenterOffset = math.floor((AB_WIN_TIMER_WIDTH * 0.5) - ((AB_WIN_TIMER_ICON_GUTTER * 0.5) * 0.5))

abWinTimerWidget.trackFrame = CreateFrame("Frame", nil, abWinTimerWidget)
abWinTimerWidget.trackFrame:SetSize(abWinTimerTrackWidth, AB_WIN_TIMER_FILL_HEIGHT)
abWinTimerWidget.trackFrame:SetPoint("CENTER", abWinTimerWidget, "CENTER", 0, 0)
abWinTimerWidget.trackFrame:SetFrameLevel(math.max(1, abWinTimerWidget:GetFrameLevel() - 1))
abWinTimerWidget.trackFrame:EnableMouse(false)

abWinTimerWidget.backgroundFill = abWinTimerWidget.trackFrame:CreateTexture(nil, "BACKGROUND")
abWinTimerWidget.backgroundFill:SetAllPoints()
local abBackgroundAtlas = ApplyABWinTimerAtlas(abWinTimerWidget.backgroundFill, {
    "worldstate-capturebar-gray",
})
if abBackgroundAtlas ~= "worldstate-capturebar-gray" then
    abWinTimerWidget.backgroundFill:SetColorTexture(0.12, 0.12, 0.12, 0.95)
else
    abWinTimerWidget.backgroundFill:SetVertexColor(1, 1, 1, 0.96)
end

abWinTimerWidget.allianceFill = abWinTimerWidget.trackFrame:CreateTexture(nil, "ARTWORK")
abWinTimerWidget.allianceFill:SetHeight(AB_WIN_TIMER_FILL_HEIGHT)
abWinTimerWidget.allianceFill:SetPoint("RIGHT", abWinTimerWidget.trackFrame, "RIGHT", 0, 0)
local abAllianceFillAtlas = ApplyABWinTimerAtlas(abWinTimerWidget.allianceFill, {
    "worldstate-capturebar-leftfill-factions",
    "worldstate-capturebar-blue",
})
if abAllianceFillAtlas ~= "worldstate-capturebar-leftfill-factions" then
    local color = AB_WIN_TIMER_FACTION_COLOR.Alliance
    abWinTimerWidget.allianceFill:SetVertexColor(color[1], color[2], color[3], 1)
end
abWinTimerWidget.allianceFill:Hide()

abWinTimerWidget.hordeFill = abWinTimerWidget.trackFrame:CreateTexture(nil, "ARTWORK")
abWinTimerWidget.hordeFill:SetHeight(AB_WIN_TIMER_FILL_HEIGHT)
abWinTimerWidget.hordeFill:SetPoint("LEFT", abWinTimerWidget.trackFrame, "LEFT", 0, 0)
local abHordeFillAtlas = ApplyABWinTimerAtlas(abWinTimerWidget.hordeFill, {
    "worldstate-capturebar-rightfill-factions",
    "worldstate-capturebar-red",
})
if abHordeFillAtlas ~= "worldstate-capturebar-rightfill-factions" then
    local color = AB_WIN_TIMER_FACTION_COLOR.Horde
    abWinTimerWidget.hordeFill:SetVertexColor(color[1], color[2], color[3], 1)
end
abWinTimerWidget.hordeFill:Hide()

abWinTimerWidget.glowFrame = CreateFrame("Frame", nil, abWinTimerWidget)
abWinTimerWidget.glowFrame:SetFrameLevel(abWinTimerWidget:GetFrameLevel() + 2)
abWinTimerWidget.glowFrame:SetSize(abWinTimerTrackWidth + 2, AB_WIN_TIMER_FILL_HEIGHT + 12)
abWinTimerWidget.glowFrame:SetPoint("CENTER", abWinTimerWidget.trackFrame, "CENTER", 0, 0)
abWinTimerWidget.glowFrame:EnableMouse(false)
abWinTimerWidget.glowFrame:Hide()

-- Pace glows: Alliance uses the fitted neutral glow texture. Horde uses the
-- boss capturebar glow asset requested by the user, stacked in the same fitted
-- geometry so it reads strongly and clearly red.
local function CreateABWinTimerPaceGlowTexture(faction, vertexColor, baseAlpha, atlasChoices)
    local texture = abWinTimerWidget.glowFrame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetBlendMode("ADD")

    local used = ApplyABWinTimerAtlas(texture, atlasChoices or {
        "worldstate-capturebar-neutralglow-bastionarmor",
        "worldstate-capturebar-glow",
    })
    if not used then
        texture:SetTexture("Interface\Buttons\WHITE8X8")
    end

    if texture.SetDesaturated then pcall(texture.SetDesaturated, texture, false) end
    if vertexColor then
        texture:SetVertexColor(vertexColor[1], vertexColor[2], vertexColor[3], 1)
    else
        texture:SetVertexColor(1, 1, 1, 1)
    end
    texture:SetAlpha(baseAlpha or 1)
    texture:Hide()
    return texture
end

abWinTimerWidget.allianceGlow = CreateABWinTimerPaceGlowTexture("Alliance", nil, 1, {
    "worldstate-capturebar-neutralglow-bastionarmor",
    "worldstate-capturebar-glow",
})
abWinTimerWidget.hordeGlow = CreateABWinTimerPaceGlowTexture("Horde", AB_WIN_TIMER_HORDE_PACE_GLOW_COLOR, 1, {
    "worldstate-capturebar-leftglow-boss",
    "worldstate-capturebar-glow",
    "worldstate-capturebar-neutralglow-bastionarmor",
})
abWinTimerWidget.hordeGlowHot = CreateABWinTimerPaceGlowTexture("Horde", AB_WIN_TIMER_HORDE_PACE_GLOW_HOT_COLOR, 0.72, {
    "worldstate-capturebar-leftglow-boss",
    "worldstate-capturebar-glow",
    "worldstate-capturebar-neutralglow-bastionarmor",
})

-- The boss glow atlas reads well for Horde, but it does not naturally fit
-- the capturebar geometry when stretched like Alliance's neutral glow. Give
-- it its own fitted bounds so the red pace glow hugs the pill more closely,
-- especially at the right end.
local function InsetABWinTimerHordePaceGlow(texture)
    if not texture then return end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", abWinTimerWidget.glowFrame, "TOPLEFT", AB_WIN_TIMER_HORDE_PACE_GLOW_LEFT_INSET + AB_WIN_TIMER_HORDE_PACE_GLOW_X_OFFSET, -AB_WIN_TIMER_HORDE_PACE_GLOW_TOP_INSET)
    texture:SetPoint("BOTTOMRIGHT", abWinTimerWidget.glowFrame, "BOTTOMRIGHT", -AB_WIN_TIMER_HORDE_PACE_GLOW_RIGHT_INSET + AB_WIN_TIMER_HORDE_PACE_GLOW_X_OFFSET, AB_WIN_TIMER_HORDE_PACE_GLOW_BOTTOM_INSET)
end

InsetABWinTimerHordePaceGlow(abWinTimerWidget.hordeGlow)
InsetABWinTimerHordePaceGlow(abWinTimerWidget.hordeGlowHot)

-- Compatibility alias for any out-of-scope code that still expects .glow.
abWinTimerWidget.glow = abWinTimerWidget.allianceGlow

-- Icon glow clip deliberately clips only at the top map boundary.  Give the
-- clip lots of room on the left/right/bottom so rays are never boxed in there.
abWinTimerWidget.iconGlowClip = CreateFrame("Frame", nil, abWinTimerMask)
abWinTimerWidget.iconGlowClip:ClearAllPoints()
abWinTimerWidget.iconGlowClip:SetPoint("TOPLEFT", abWinTimerMask, "TOPLEFT", -90, 0)
abWinTimerWidget.iconGlowClip:SetPoint("BOTTOMRIGHT", abWinTimerMask, "BOTTOMRIGHT", 90, -70)
abWinTimerWidget.iconGlowClip:SetFrameLevel(math.max(1, abWinTimerWidget:GetFrameLevel() - 1))
abWinTimerWidget.iconGlowClip:EnableMouse(false)
if abWinTimerWidget.iconGlowClip.SetClipsChildren then
    abWinTimerWidget.iconGlowClip:SetClipsChildren(true)
end

local function CreateABWinTimerIconGlow(parent, xOffset)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(66, 66)
    holder:SetPoint("CENTER", abWinTimerWidget, "CENTER", xOffset, 0)
    holder:SetFrameLevel(parent:GetFrameLevel())
    holder:EnableMouse(false)
    holder:Hide()
    holder.elapsed = 0
    holder.progress = 0
    holder.fadeAlpha = 0
    holder.fadeTarget = 0
    holder:SetAlpha(0)

    holder.rearStar = holder:CreateTexture(nil, "ARTWORK", nil, -2)
    holder.rearStar:SetPoint("CENTER")
    holder.rearStar:SetTexture("Interface\\Cooldown\\star4")
    holder.rearStar:SetBlendMode("ADD")
    holder.rearStar:SetVertexColor(1.00, 0.72, 0.04, 1)

    holder.innerStar = holder:CreateTexture(nil, "ARTWORK", nil, -1)
    holder.innerStar:SetPoint("CENTER")
    holder.innerStar:SetTexture("Interface\\Cooldown\\star4")
    holder.innerStar:SetBlendMode("ADD")
    holder.innerStar:SetVertexColor(1.00, 0.96, 0.56, 1)

    holder.rays01 = holder:CreateTexture(nil, "ARTWORK", nil, 0)
    holder.rays01:SetPoint("CENTER")
    holder.rays01:SetBlendMode("ADD")
    ApplyABWinTimerAtlas(holder.rays01, { "shop-toast-token-rays01" })
    holder.rays01:SetVertexColor(1.00, 0.84, 0.18, 1)
    holder.rays01:Hide()

    holder.rays02 = holder:CreateTexture(nil, "ARTWORK", nil, 1)
    holder.rays02:SetPoint("CENTER")
    holder.rays02:SetBlendMode("ADD")
    ApplyABWinTimerAtlas(holder.rays02, { "shop-toast-token-rays02" })
    holder.rays02:SetVertexColor(1.00, 0.94, 0.46, 1)
    holder.rays02:Hide()

    return holder
end

abWinTimerWidget.allianceIconGlow = CreateABWinTimerIconGlow(abWinTimerWidget.iconGlowClip, -abWinTimerIconCenterOffset)
abWinTimerWidget.hordeIconGlow = CreateABWinTimerIconGlow(abWinTimerWidget.iconGlowClip, abWinTimerIconCenterOffset)

local function SetABWinTimerIconGlowActive(glow, active, progress)
    if not glow then return end
    if active then
        glow.progress = math.max(0, math.min(1, tonumber(progress) or 0))
        glow.fadeTarget = 1
        if not glow:IsShown() then
            glow.fadeAlpha = 0
            glow:SetAlpha(0)
            glow:Show()
        end
    else
        glow.progress = 0
        glow.fadeTarget = 0
        if glow.fadeAlpha == nil then
            glow.fadeAlpha = glow:IsShown() and 1 or 0
        end
    end
end

-- 5-base intensity effect: use the WeakAuras Beams picker textures as the
-- fill itself. WeakAuras stores these entries as numeric-string Blizzard
-- texture IDs, so load them the same way WeakAuras does. The texture remains
-- full-scale; progress reveals more of it from the faction-specific side.
local AB_WIN_TIMER_5BASE_HORDE_BEAM = "186201" -- Red Lightning
local AB_WIN_TIMER_5BASE_ALLIANCE_BEAM = "186211" -- Shock Lightning
local AB_WIN_TIMER_5BASE_BEAM_HEIGHT = AB_WIN_TIMER_FILL_HEIGHT + 8
local AB_WIN_TIMER_5BASE_BEAM_EDGE_INSET = 0
local AB_WIN_TIMER_5BASE_BEAM_TEXCOORD_TRIM = 0.085
local AB_WIN_TIMER_5BASE_BORDER_TEXCOORD_TRIM = 0.12
local AB_WIN_TIMER_5BASE_BORDER_SHIFT = 0.04
local AB_WIN_TIMER_PROGRESS_SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"
local AB_WIN_TIMER_PROGRESS_SPARK_WIDTH = 10
local AB_WIN_TIMER_PROGRESS_SPARK_HEIGHT = AB_WIN_TIMER_FILL_HEIGHT + 16
local AB_WIN_TIMER_PROGRESS_SPARK_FADE_SECONDS = 0.55
local AB_WIN_TIMER_PROGRESS_SPARK_HORDE_X_OFFSET = 0
local AB_WIN_TIMER_PROGRESS_SPARK_ALLIANCE_X_OFFSET = 0

local function SetABWinTimerBeamTexture(texture, textureRef)
    if not texture then return false end
    local ok = texture:SetTexture(textureRef, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not ok then
        local numericRef = tonumber(textureRef)
        if numericRef then
            ok = texture:SetTexture(numericRef, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
    end
    return ok
end

local function CreateABWinTimerFiveBaseBeam(textureRef, subLevel)
    -- Put the beam directly on trackFrame: above the normal fill textures, but
    -- below the timer text because trackFrame is one frame level below widget.
    local texture = abWinTimerWidget.trackFrame:CreateTexture(nil, "ARTWORK", nil, subLevel or 2)
    texture:SetHeight(AB_WIN_TIMER_5BASE_BEAM_HEIGHT)
    texture:SetBlendMode("BLEND")
    SetABWinTimerBeamTexture(texture, textureRef)

    local mask = nil
    if abWinTimerWidget.trackFrame.CreateMaskTexture and texture.AddMaskTexture then
        mask = abWinTimerWidget.trackFrame:CreateMaskTexture(nil, "ARTWORK")
        mask:SetAllPoints(abWinTimerWidget.trackFrame)
        mask:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\ABFiveBaseBeamMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if mask.SetSnapToPixelGrid then mask:SetSnapToPixelGrid(false) end
        if mask.SetTexelSnappingBias then mask:SetTexelSnappingBias(0) end
        texture:AddMaskTexture(mask)
    end

    texture:Hide()
    return texture, mask
end

abWinTimerWidget.hordeFiveBaseBeam, abWinTimerWidget.hordeFiveBaseMask =
    CreateABWinTimerFiveBaseBeam(AB_WIN_TIMER_5BASE_HORDE_BEAM, 2)
abWinTimerWidget.hordeFiveBaseBeamHot = abWinTimerWidget.trackFrame:CreateTexture(nil, "ARTWORK", nil, 3)
abWinTimerWidget.hordeFiveBaseBeamHot:SetHeight(AB_WIN_TIMER_5BASE_BEAM_HEIGHT)
abWinTimerWidget.hordeFiveBaseBeamHot:SetBlendMode("ADD")
SetABWinTimerBeamTexture(abWinTimerWidget.hordeFiveBaseBeamHot, AB_WIN_TIMER_5BASE_HORDE_BEAM)
if abWinTimerWidget.hordeFiveBaseMask and abWinTimerWidget.hordeFiveBaseBeamHot.AddMaskTexture then
    abWinTimerWidget.hordeFiveBaseBeamHot:AddMaskTexture(abWinTimerWidget.hordeFiveBaseMask)
end
abWinTimerWidget.hordeFiveBaseBeamHot:Hide()

abWinTimerWidget.allianceFiveBaseBeam, abWinTimerWidget.allianceFiveBaseMask =
    CreateABWinTimerFiveBaseBeam(AB_WIN_TIMER_5BASE_ALLIANCE_BEAM, 2)
abWinTimerWidget.allianceFiveBaseBeamHot = abWinTimerWidget.trackFrame:CreateTexture(nil, "ARTWORK", nil, 3)
abWinTimerWidget.allianceFiveBaseBeamHot:SetHeight(AB_WIN_TIMER_5BASE_BEAM_HEIGHT)
abWinTimerWidget.allianceFiveBaseBeamHot:SetBlendMode("ADD")
SetABWinTimerBeamTexture(abWinTimerWidget.allianceFiveBaseBeamHot, AB_WIN_TIMER_5BASE_ALLIANCE_BEAM)
if abWinTimerWidget.allianceFiveBaseMask and abWinTimerWidget.allianceFiveBaseBeamHot.AddMaskTexture then
    abWinTimerWidget.allianceFiveBaseBeamHot:AddMaskTexture(abWinTimerWidget.allianceFiveBaseMask)
end
abWinTimerWidget.allianceFiveBaseBeamHot:Hide()

local function HideABWinTimerFiveBaseBeams()
    abWinTimerWidget.hordeFiveBaseBeam:Hide()
    abWinTimerWidget.hordeFiveBaseBeamHot:Hide()
    abWinTimerWidget.allianceFiveBaseBeam:Hide()
    abWinTimerWidget.allianceFiveBaseBeamHot:Hide()
end

-- 5-base crackling electricity arc effect.
-- Source credit: Jordan Irwin (AntumDeluge), "Electricity Overlay Effect",
-- OpenGameArt.org. Licensed under CC BY 4.0 / OGA BY. The original red and
-- blue 48x64 frame strips are repacked into local 512x512 TGA atlases for WoW.
local AB_WIN_TIMER_CRACKLE_FRAME_COUNT = 15
local AB_WIN_TIMER_CRACKLE_COLUMNS = 4
local AB_WIN_TIMER_CRACKLE_ROWS = 4
local AB_WIN_TIMER_CRACKLE_FRAME_SECONDS = 0.060
local AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_HEIGHT = 14
local AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_HEIGHT = 10
local AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_Y = 1.5
local AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_Y = -1.5
local AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_ORIGIN_INSET = 8
local AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_MAX_WIDTH = 108
local AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_MAX_WIDTH = 84
local AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_INSET = 6
local AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_DELAY = 26
local AB_WIN_TIMER_5BASE_POWERDOWN_SECONDS = 0.55
local AB_WIN_TIMER_5BASE_CRACKLE_POWERDOWN_SECONDS = 0.30

abWinTimerWidget.fiveBaseBorderFrame = CreateFrame("Frame", nil, abWinTimerWidget)
abWinTimerWidget.fiveBaseBorderFrame:SetFrameLevel(abWinTimerWidget:GetFrameLevel() + 2)
abWinTimerWidget.fiveBaseBorderFrame:SetSize(abWinTimerTrackWidth + 2, AB_WIN_TIMER_FILL_HEIGHT + 12)
abWinTimerWidget.fiveBaseBorderFrame:SetPoint("CENTER", abWinTimerWidget.trackFrame, "CENTER", 0, 0)
abWinTimerWidget.fiveBaseBorderFrame:EnableMouse(false)
abWinTimerWidget.fiveBaseBorderFrame:Hide()

local function CreateABWinTimerCrackleArcTexture(texturePath, subLevel, mask)
    local texture = abWinTimerWidget.trackFrame:CreateTexture(nil, "ARTWORK", nil, subLevel or 4)
    texture:SetTexture(texturePath)
    texture:SetBlendMode("ADD")
    if mask and texture.AddMaskTexture then
        texture:AddMaskTexture(mask)
    end
    texture:Hide()
    return texture
end

local function CreateABWinTimerCrackleArcSet(texturePath, mask)
    return {
        primary = CreateABWinTimerCrackleArcTexture(texturePath, 4, mask),
        secondary = CreateABWinTimerCrackleArcTexture(texturePath, 5, mask),
    }
end

abWinTimerWidget.hordeBorderLightning = CreateABWinTimerCrackleArcSet(
    "Interface\\AddOns\\ZurkMaps\\Media\\AB_CracklingElectricity_Horde",
    abWinTimerWidget.hordeFiveBaseMask
)
abWinTimerWidget.allianceBorderLightning = CreateABWinTimerCrackleArcSet(
    "Interface\\AddOns\\ZurkMaps\\Media\\AB_CracklingElectricity_Alliance",
    abWinTimerWidget.allianceFiveBaseMask
)

local function HideABWinTimerCrackleSet(set)
    if not set then return end
    if set.primary then set.primary:Hide() end
    if set.secondary then set.secondary:Hide() end
end

local function HideABWinTimerFiveBaseBorderLightning()
    HideABWinTimerCrackleSet(abWinTimerWidget.hordeBorderLightning)
    HideABWinTimerCrackleSet(abWinTimerWidget.allianceBorderLightning)
    abWinTimerWidget.fiveBaseBorderFrame:Hide()
end

local function SetABWinTimerCrackleFrame(texture, frameIndex)
    frameIndex = frameIndex % AB_WIN_TIMER_CRACKLE_FRAME_COUNT
    local col = frameIndex % AB_WIN_TIMER_CRACKLE_COLUMNS
    local row = math.floor(frameIndex / AB_WIN_TIMER_CRACKLE_COLUMNS)
    local u0 = col / AB_WIN_TIMER_CRACKLE_COLUMNS
    local u1 = (col + 1) / AB_WIN_TIMER_CRACKLE_COLUMNS
    local v0 = row / AB_WIN_TIMER_CRACKLE_ROWS
    local v1 = (row + 1) / AB_WIN_TIMER_CRACKLE_ROWS
    texture:SetTexCoord(u0, u1, v0, v1)
end

local function SetABWinTimerCrackleArcFromOrigin(texture, faction, yOffset, height, width)
    if not texture or not width or width < 2 then
        if texture then texture:Hide() end
        return
    end

    texture:ClearAllPoints()
    texture:SetSize(width, height)
    if faction == "Alliance" then
        texture:SetPoint("RIGHT", abWinTimerWidget.trackFrame, "RIGHT", -AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_ORIGIN_INSET, yOffset)
    else
        texture:SetPoint("LEFT", abWinTimerWidget.trackFrame, "LEFT", AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_ORIGIN_INSET, yOffset)
    end
    texture:Show()
end

local function SetABWinTimerCrackleArcAtSpark(texture, faction, yOffset, height, progressWidth, width, inset)
    if not texture or not width or width < 2 or not progressWidth or progressWidth < 2 then
        if texture then texture:Hide() end
        return
    end

    local sparkInset = inset or 0
    texture:ClearAllPoints()
    texture:SetSize(width, height)
    if faction == "Alliance" then
        texture:SetPoint("LEFT", abWinTimerWidget.trackFrame, "RIGHT", -(progressWidth - sparkInset), yOffset)
    else
        texture:SetPoint("RIGHT", abWinTimerWidget.trackFrame, "LEFT", progressWidth - sparkInset, yOffset)
    end
    texture:Show()
end

local function UpdateABWinTimerCrackleSet(set, faction, progress, elapsedTime, powerDownAlpha)
    if not set then return end

    local primary = set.primary
    local secondary = set.secondary
    local baseTime = elapsedTime or 0
    local fadeAlpha = math.max(0, math.min(1, tonumber(powerDownAlpha) or 1))
    local collapseScale = 0.72 + (0.28 * fadeAlpha)
    local progressWidth = abWinTimerTrackWidth * math.max(0, math.min(1, tonumber(progress) or 0))

    local primaryFrame = math.floor(baseTime / AB_WIN_TIMER_CRACKLE_FRAME_SECONDS) % AB_WIN_TIMER_CRACKLE_FRAME_COUNT
    local secondaryFrame = math.floor((baseTime + 0.19) / AB_WIN_TIMER_CRACKLE_FRAME_SECONDS) % AB_WIN_TIMER_CRACKLE_FRAME_COUNT
    SetABWinTimerCrackleFrame(primary, primaryFrame)
    SetABWinTimerCrackleFrame(secondary, secondaryFrame)

    local primaryWidth = math.min(AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_MAX_WIDTH, math.max(0, progressWidth - AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_ORIGIN_INSET)) * collapseScale
    local secondaryAvailable = progressWidth - AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_DELAY
    local secondaryWidth = math.min(AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_MAX_WIDTH, math.max(0, secondaryAvailable)) * collapseScale

    local heightBoost = math.min(3, progressWidth / 50)
    local heightScale = 0.82 + (0.18 * fadeAlpha)
    SetABWinTimerCrackleArcFromOrigin(primary, faction, AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_Y, (AB_WIN_TIMER_CRACKLE_ARC_PRIMARY_HEIGHT + heightBoost) * heightScale, primaryWidth)
    SetABWinTimerCrackleArcAtSpark(secondary, faction, AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_Y, (AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_HEIGHT + (heightBoost * 0.75)) * heightScale, progressWidth, secondaryWidth, AB_WIN_TIMER_CRACKLE_ARC_SECONDARY_INSET)

    local intensity = math.max(0, math.min(1, progressWidth / abWinTimerTrackWidth))
    if primary:IsShown() then
        local flickerA = 0.5 + (0.5 * math.sin((baseTime * 18.0) + 0.2))
        local flickerB = 0.5 + (0.5 * math.sin((baseTime * 10.7) + 1.3))
        primary:SetAlpha(((0.54 + (0.18 * intensity)) + ((0.26 + (0.10 * intensity)) * flickerA * flickerB)) * fadeAlpha)
    end
    if secondary:IsShown() then
        local flickerA = 0.5 + (0.5 * math.sin((baseTime * 16.0) + 1.2))
        local flickerB = 0.5 + (0.5 * math.sin((baseTime * 8.3) + 0.7))
        secondary:SetAlpha(((0.18 + (0.16 * intensity)) + ((0.28 + (0.16 * intensity)) * flickerA * flickerB)) * fadeAlpha)
    end
end

abWinTimerWidget.progressSpark = abWinTimerWidget.trackFrame:CreateTexture(nil, "ARTWORK", nil, 4)
abWinTimerWidget.progressSpark:SetTexture(AB_WIN_TIMER_PROGRESS_SPARK_TEXTURE)
abWinTimerWidget.progressSpark:SetBlendMode("ADD")
abWinTimerWidget.progressSpark:SetSize(AB_WIN_TIMER_PROGRESS_SPARK_WIDTH, AB_WIN_TIMER_PROGRESS_SPARK_HEIGHT)
if abWinTimerWidget.hordeFiveBaseMask and abWinTimerWidget.progressSpark.AddMaskTexture then
    abWinTimerWidget.progressSpark:AddMaskTexture(abWinTimerWidget.hordeFiveBaseMask)
end
abWinTimerWidget.progressSpark:Hide()

local function HideABWinTimerProgressSpark()
    abWinTimerWidget.progressSpark:Hide()
end

local function PositionABWinTimerProgressSpark(faction, progress)
    if not faction then
        HideABWinTimerProgressSpark()
        HideABWinTimerFiveBaseBorderLightning()
        return
    end

    progress = math.max(0, math.min(1, tonumber(progress) or 0))
    local width = abWinTimerTrackWidth * progress
    if width < 1 then
        HideABWinTimerProgressSpark()
        return
    end

    local edgeInset = 5
    local edgeOffset
    if faction == "Alliance" then
        edgeOffset = -math.min(abWinTimerTrackWidth - edgeInset, math.max(edgeInset, width)) + AB_WIN_TIMER_PROGRESS_SPARK_ALLIANCE_X_OFFSET
        abWinTimerWidget.progressSpark:ClearAllPoints()
        abWinTimerWidget.progressSpark:SetPoint("CENTER", abWinTimerWidget.trackFrame, "RIGHT", edgeOffset, 0)
        abWinTimerWidget.progressSpark:SetVertexColor(0.96, 1.00, 1.00, 1)
    else
        edgeOffset = math.min(abWinTimerTrackWidth - edgeInset, math.max(edgeInset, width)) + AB_WIN_TIMER_PROGRESS_SPARK_HORDE_X_OFFSET
        abWinTimerWidget.progressSpark:ClearAllPoints()
        abWinTimerWidget.progressSpark:SetPoint("CENTER", abWinTimerWidget.trackFrame, "LEFT", edgeOffset, 0)
        abWinTimerWidget.progressSpark:SetVertexColor(1.00, 0.97, 0.92, 1)
    end
end

local function SetABWinTimerFiveBaseProgress(faction, progress)
    HideABWinTimerFiveBaseBeams()
    HideABWinTimerProgressSpark()
    if faction ~= "Alliance" and faction ~= "Horde" then return end

    progress = math.max(0, math.min(1, tonumber(progress) or 0))
    local width = abWinTimerTrackWidth * progress
    if width < 1 then return end

    local beamInset = AB_WIN_TIMER_5BASE_BEAM_EDGE_INSET
    local visibleWidth = width
    local trim = AB_WIN_TIMER_5BASE_BEAM_TEXCOORD_TRIM
    local usable = 1 - (trim * 2)

    if faction == "Horde" then
        local left, right = trim, trim + (usable * progress)
        for _, texture in ipairs({abWinTimerWidget.hordeFiveBaseBeam, abWinTimerWidget.hordeFiveBaseBeamHot}) do
            texture:ClearAllPoints()
            texture:SetPoint("LEFT", abWinTimerWidget.trackFrame, "LEFT", beamInset, 0)
            texture:SetSize(visibleWidth, AB_WIN_TIMER_5BASE_BEAM_HEIGHT)
            texture:SetTexCoord(left, right, 0, 1)
            texture:Show()
        end
    else
        local left, right = (1 - trim) - (usable * progress), 1 - trim
        for _, texture in ipairs({abWinTimerWidget.allianceFiveBaseBeam, abWinTimerWidget.allianceFiveBaseBeamHot}) do
            texture:ClearAllPoints()
            texture:SetPoint("RIGHT", abWinTimerWidget.trackFrame, "RIGHT", -beamInset, 0)
            texture:SetSize(visibleWidth, AB_WIN_TIMER_5BASE_BEAM_HEIGHT)
            texture:SetTexCoord(left, right, 0, 1)
            texture:Show()
        end
    end
end

local ABWinTimerAnimateTexCoords = (TextureUtil and TextureUtil.AnimateTexCoords) or _G.AnimateTexCoords

local function CreateABWinTimerText(parent, fontSize)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\ARIALN.TTF", fontSize or 10, "OUTLINE")
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    return text
end

-- Match the existing AB/AV capture-clock spacing, but slightly tighten the
-- 1-digit-minute case so it does not leave a weird moat before the colon.
abWinTimerWidget.minute = CreateABWinTimerText(abWinTimerWidget, 10)
abWinTimerWidget.minute:SetSize(16, 12)
abWinTimerWidget.minute:SetJustifyH("CENTER")
abWinTimerWidget.colon = CreateABWinTimerText(abWinTimerWidget, 10)
abWinTimerWidget.colon:SetText(":")
abWinTimerWidget.secondTens = CreateABWinTimerText(abWinTimerWidget, 10)
abWinTimerWidget.secondOnes = CreateABWinTimerText(abWinTimerWidget, 10)

abWinTimerWidget.clockText = CreateABWinTimerText(abWinTimerWidget, 10)
abWinTimerWidget.clockText:SetPoint("CENTER", abWinTimerWidget, "CENTER", 0, 0)
abWinTimerWidget.clockText:SetJustifyH("CENTER")
abWinTimerWidget.clockText:SetSize(54, 12)
abWinTimerWidget.minute:Hide()
abWinTimerWidget.colon:Hide()
abWinTimerWidget.secondTens:Hide()
abWinTimerWidget.secondOnes:Hide()

abWinTimerWidget.winFrame = CreateFrame("Frame", nil, abWinTimerWidget)
abWinTimerWidget.winFrame:SetSize(120, 16)
abWinTimerWidget.winFrame:SetPoint("CENTER", abWinTimerWidget, "CENTER", 0, 0)
abWinTimerWidget.winFrame:SetFrameLevel(abWinTimerWidget:GetFrameLevel() + 2)
abWinTimerWidget.winFrame:EnableMouse(false)
abWinTimerWidget.winFrame:Hide()

abWinTimerWidget.winLeftIcon = abWinTimerWidget.winFrame:CreateTexture(nil, "OVERLAY")
abWinTimerWidget.winLeftIcon:SetSize(10, 10)
abWinTimerWidget.winLeftIcon:SetPoint("LEFT", abWinTimerWidget.winFrame, "LEFT", 2, 0)

abWinTimerWidget.winRightIcon = abWinTimerWidget.winFrame:CreateTexture(nil, "OVERLAY")
abWinTimerWidget.winRightIcon:SetSize(10, 10)
abWinTimerWidget.winRightIcon:SetPoint("RIGHT", abWinTimerWidget.winFrame, "RIGHT", -2, 0)

abWinTimerWidget.winTextBackdrop = abWinTimerWidget.winFrame:CreateTexture(nil, "OVERLAY", nil, -1)
abWinTimerWidget.winTextBackdrop:SetTexture("Interface\\Buttons\\WHITE8x8")
abWinTimerWidget.winTextBackdrop:SetPoint("CENTER", abWinTimerWidget.winFrame, "CENTER", 0, 0)
abWinTimerWidget.winTextBackdrop:SetSize(74, 12)
abWinTimerWidget.winTextBackdrop:SetVertexColor(0, 0, 0, 0)
abWinTimerWidget.winTextBackdrop:Hide()

abWinTimerWidget.winText = CreateABWinTimerText(abWinTimerWidget.winFrame, 10)
abWinTimerWidget.winText:SetPoint("CENTER", abWinTimerWidget.winFrame, "CENTER", 0, 0)
abWinTimerWidget.winText:SetTextColor(1.00, 0.95, 0.62, 1)
abWinTimerWidget.winText:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
abWinTimerWidget.winText:SetShadowOffset(1, -1)
abWinTimerWidget.winText:SetShadowColor(0, 0, 0, 1)
abWinTimerWidget.winText:SetWidth(90)
abWinTimerWidget.winText:SetJustifyH("CENTER")

local function SetABWinWinnerIcons(faction)
    local atlasChoices = faction == "Horde"
        and { "ShipMissionIcon-SiegeH-MapBadge" }
        or { "ShipMissionIcon-SiegeA-MapBadge" }
    ApplyABWinTimerAtlas(abWinTimerWidget.winLeftIcon, atlasChoices)
    ApplyABWinTimerAtlas(abWinTimerWidget.winRightIcon, atlasChoices)
end

local function UpdateABWinTimerScale(addonScale)
    addonScale = tonumber(addonScale) or 1
    local compensationScale = addonScale < 1 and math.min(1.38, 1 / math.max(addonScale, 0.72)) or 1

    abWinTimerMask:SetSize((AB_WIN_TIMER_WIDTH + 12) * compensationScale, AB_WIN_TIMER_MASK_HEIGHT * compensationScale)
    abWinTimerWidget:SetScale(compensationScale)
    abWinTimerWidget.clockText:SetFont("Fonts\\ARIALN.TTF", 10 * compensationScale, "OUTLINE")
    abWinTimerWidget.winText:SetFont("Fonts\\ARIALN.TTF", 10 * compensationScale, "OUTLINE")
end

local function PositionABWinTimerClock(minuteValue)
    local hasTwoDigitMinutes = (tonumber(minuteValue) or 0) >= 10

    abWinTimerWidget.minute:ClearAllPoints()
    abWinTimerWidget.colon:ClearAllPoints()
    abWinTimerWidget.secondTens:ClearAllPoints()
    abWinTimerWidget.secondOnes:ClearAllPoints()

    if hasTwoDigitMinutes then
        abWinTimerWidget.minute:SetPoint("CENTER", abWinTimerWidget, "CENTER", -6.5, 0)
        abWinTimerWidget.colon:SetPoint("CENTER", abWinTimerWidget, "CENTER", -2.2, 0)
        abWinTimerWidget.secondTens:SetPoint("CENTER", abWinTimerWidget, "CENTER", 1.9, 0)
        abWinTimerWidget.secondOnes:SetPoint("CENTER", abWinTimerWidget, "CENTER", 6.0, 0)
    else
        abWinTimerWidget.minute:SetPoint("CENTER", abWinTimerWidget, "CENTER", -4.6, 0)
        abWinTimerWidget.colon:SetPoint("CENTER", abWinTimerWidget, "CENTER", -0.8, 0)
        abWinTimerWidget.secondTens:SetPoint("CENTER", abWinTimerWidget, "CENTER", 3.3, 0)
        abWinTimerWidget.secondOnes:SetPoint("CENTER", abWinTimerWidget, "CENTER", 7.4, 0)
    end
end

PositionABWinTimerClock(0)
UpdateABWinTimerScale(1)

local abWinTimer = {
    widget = abWinTimerWidget,
    activated = false,
    revealElapsed = nil,
    glowElapsed = nil,
    glowFaction = nil,
    pendingGlowFaction = nil,
    paceFaction = nil,
    paceBases = 0,
    burnElapsed = 0,
    fiveBaseFadeElapsed = nil,
    fiveBaseFadeFaction = nil,
    fiveBaseFadeProgress = nil,
    fiveBaseFadeBurnElapsed = nil,
    winnerFaction = nil,
    winnerAnimElapsed = nil,
    livePollElapsed = 0,
    liveAllianceScore = nil,
    liveHordeScore = nil,
    liveAllianceBases = nil,
    liveHordeBases = nil,
    liveAllianceScoreTime = nil,
    liveHordeScoreTime = nil,
    testAllianceScore = 0,
    testHordeScore = 0,
    testRunning = false,
    broadcastFaction = nil,
    broadcastRemaining = nil,
    broadcastUpdatedAt = nil,
    broadcastDidWin = false,
}

abWinTimerWidget.clickButton = CreateFrame("Button", nil, abWinTimerWidget)
abWinTimerWidget.clickButton:SetAllPoints(abWinTimerWidget)
abWinTimerWidget.clickButton:SetFrameLevel(abWinTimerWidget:GetFrameLevel() + 6)
abWinTimerWidget.clickButton:RegisterForClicks("LeftButtonUp")
abWinTimerWidget.clickButton:EnableMouse(true)
abWinTimerWidget.clickButton:SetScript("OnClick", function()
    abWinTimer:BroadcastPace()
end)
abWinTimerWidget.clickButton:SetScript("OnEnter", function(self)
    local message = abWinTimer:GetBroadcastMessage()
    if not message then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Report Game Time")
    GameTooltip:AddLine(message, 1, 1, 1, true)
    GameTooltip:Show()
end)
abWinTimerWidget.clickButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function SetABWinTimerClock(seconds)
    local value = tonumber(seconds)
    if not value then
        abWinTimerWidget.clockText:SetText("?:??")
        return
    end

    value = math.max(0, math.ceil(value))
    local minutes = math.floor(value / 60)
    local secs = value % 60
    abWinTimerWidget.clockText:SetFormattedText("%d:%02d", minutes, secs)
end

local function FormatABWinTimerBroadcastTime(seconds)
    local value = tonumber(seconds)
    if not value or value >= AB_WIN_TIMER_INFINITY then return nil end
    value = math.max(0, math.ceil(value))
    return string.format("%d:%02d", math.floor(value / 60), value % 60)
end

function abWinTimer:GetBroadcastMessage()
    local faction = self.broadcastFaction
    if faction ~= "Alliance" and faction ~= "Horde" then return nil end
    if self.broadcastDidWin then return nil end

    local remaining = tonumber(self.broadcastRemaining)
    if not remaining or remaining >= AB_WIN_TIMER_INFINITY then return nil end
    if self.broadcastUpdatedAt then
        remaining = math.max(0, remaining - math.max(0, ABWinTimerNow() - self.broadcastUpdatedAt))
    end
    if remaining <= 0 then return nil end

    local timeText = FormatABWinTimerBroadcastTime(remaining)
    if not timeText then return nil end
    return string.format("%s win in ~%s if bases hold", faction, timeText)
end

function abWinTimer:BroadcastPace()
    local message = self:GetBroadcastMessage()
    if not message then return end

    -- Always use the same shared callout router as every other AB map callout,
    -- including while AB Test Mode is active. This keeps timer clicks on /say
    -- outside battlegrounds and /bg or /rw inside battlegrounds according to
    -- the user's Zurk Maps callout-channel setting.
    Report(message)
end

local function CountABWinTimerControlledBases()
    local allianceBases, hordeBases = 0, 0
    for _, baseNode in ipairs(BASE_NODES) do
        local textureIndex = abTestMode and tonumber(abTestBaseNodeStates[baseNode.id]) or nil
        textureIndex = textureIndex or tonumber(baseNode.currentTextureIndex) or baseNode.neutralTextureIndex
        local offset = textureIndex - baseNode.neutralTextureIndex
        if offset == 2 then
            allianceBases = allianceBases + 1
        elseif offset == 4 then
            hordeBases = hordeBases + 1
        end
    end
    return allianceBases, hordeBases
end

local function GetABWinTimerRate(baseCount)
    return AB_WIN_TIMER_SCORE_PER_SECOND[tonumber(baseCount) or 0] or 0
end

local function GetABWinTimerLiveRemaining(score, bases, scoreTime, now)
    score = math.max(0, math.min(AB_WIN_TIMER_MAX_SCORE, tonumber(score) or 0))
    local rate = GetABWinTimerRate(bases)
    if score >= AB_WIN_TIMER_MAX_SCORE then return 0, rate, AB_WIN_TIMER_MAX_SCORE end
    if rate <= 0 then return AB_WIN_TIMER_INFINITY, rate, score end

    local elapsedSinceScore = scoreTime and math.max(0, now - scoreTime) or 0
    local remaining = ((AB_WIN_TIMER_MAX_SCORE - score) / rate) - elapsedSinceScore
    return math.max(0, remaining), rate
end

local function ChooseABWinTimerPace(allianceRemaining, hordeRemaining)
    local aFinite = allianceRemaining < AB_WIN_TIMER_INFINITY
    local hFinite = hordeRemaining < AB_WIN_TIMER_INFINITY
    if not aFinite and not hFinite then return nil, nil end
    if aFinite and not hFinite then return "Alliance", allianceRemaining end
    if hFinite and not aFinite then return "Horde", hordeRemaining end

    if allianceRemaining + AB_WIN_TIMER_TIE_EPSILON < hordeRemaining then
        return "Alliance", allianceRemaining
    elseif hordeRemaining + AB_WIN_TIMER_TIE_EPSILON < allianceRemaining then
        return "Horde", hordeRemaining
    end
    return nil, math.min(allianceRemaining, hordeRemaining)
end

local function GetABWinTimerGlowAlpha(baseCount)
    baseCount = tonumber(baseCount) or 0
    if baseCount >= 5 then return 0.90 end
    if baseCount >= 4 then return 0.72 end
    if baseCount >= 3 then return 0.32 end
    return 0
end

function abWinTimer:PositionWidget(yOffset)
    self.widget:ClearAllPoints()
    self.widget:SetPoint("TOP", abWinTimerMask, "TOP", 0, yOffset)
end

function abWinTimer:Activate()
    if self.activated then return end
    self.activated = true
    self.revealElapsed = 0
    self.pendingGlowFaction = self.paceFaction
    self:PositionWidget(AB_WIN_TIMER_START_Y)
    self.widget:SetAlpha(0)
    self.widget:Show()
end

function abWinTimer:StartGlow(faction)
    if faction ~= "Alliance" and faction ~= "Horde" then return end
    self.glowFaction = faction
    self.glowElapsed = 0
    self.pendingGlowFaction = nil

    local glowFrame = self.widget.glowFrame
    glowFrame:SetScale(0.96)
    glowFrame:SetAlpha(0)
    self.widget.allianceGlow:SetShown(faction == "Alliance")
    self.widget.hordeGlow:SetShown(faction == "Horde")
    glowFrame:Show()
end

function abWinTimer:ShowWinner(faction)
    if faction ~= "Alliance" and faction ~= "Horde" then return end
    if self.winnerFaction ~= faction then
        self.winnerFaction = faction
        self.winnerAnimElapsed = 0
        SetABWinWinnerIcons(faction)
        abWinTimerWidget.winText:SetText((faction == "Horde" and "HORDE   WIN") or "ALLIANCE   WIN")
        self.widget.winFrame:SetScale(0.88)
        self.widget.winFrame:SetAlpha(0)
    end
    self.widget.clockText:Hide()
    self.widget.winFrame:Show()
end

function abWinTimer:HideWinner()
    self.winnerFaction = nil
    self.winnerAnimElapsed = nil
    self.widget.winFrame:Hide()
    self.widget.clockText:Show()
end

function abWinTimer:SetPace(faction, remaining, winningProgress, winningBases, didWin)
    local previousFaction = self.paceFaction
    local previousBases = tonumber(self.paceBases) or 0
    local nextBases = tonumber(winningBases) or 0
    local factionChanged = faction ~= previousFaction
    local wasFiveBase = previousFaction and previousBases >= 5
    local isFiveBase = faction and nextBases >= 5
    local beginFiveBasePowerDown = wasFiveBase and not isFiveBase

    if beginFiveBasePowerDown then
        self.fiveBaseFadeElapsed = 0
        self.fiveBaseFadeFaction = previousFaction
        self.fiveBaseFadeProgress = self.lastWinningProgress or math.max(0, math.min(1, tonumber(winningProgress) or 0))
        self.fiveBaseFadeBurnElapsed = self.burnElapsed or 0
        if self.progressSparkFaction == previousFaction and self.progressSparkPersistent then
            self.progressSparkPersistent = false
            self.progressSparkElapsed = 0
        end
    elseif isFiveBase then
        self.fiveBaseFadeElapsed = nil
        self.fiveBaseFadeFaction = nil
        self.fiveBaseFadeProgress = nil
        self.fiveBaseFadeBurnElapsed = nil
    end

    self.paceFaction = faction
    self.paceBases = nextBases
    self.broadcastFaction = faction
    self.broadcastRemaining = tonumber(remaining)
    self.broadcastUpdatedAt = ABWinTimerNow()
    self.broadcastDidWin = didWin and true or false
    if factionChanged then
        self.pendingGlowFaction = nil
        self.glowElapsed = nil
        if not beginFiveBasePowerDown then
            self.burnElapsed = 0
        end
        self.widget.allianceGlow:Hide()
        self.widget.hordeGlow:Hide()
        if self.widget.hordeGlowHot then self.widget.hordeGlowHot:Hide() end
        self.widget.glowFrame:SetAlpha(0)
        self.widget.glowFrame:Hide()
        if not beginFiveBasePowerDown then
            HideABWinTimerFiveBaseBeams()
            HideABWinTimerFiveBaseBorderLightning()
        end
        if faction == "Alliance" then
            self.widget.allianceIconGlow.elapsed = 0
            self.widget.allianceIconGlow.fadeAlpha = 0
        elseif faction == "Horde" then
            self.widget.hordeIconGlow.elapsed = 0
            self.widget.hordeIconGlow.fadeAlpha = 0
        end
    end

    if didWin and faction then
        self:ShowWinner(faction)
    else
        self:HideWinner()
        if remaining then
            SetABWinTimerClock(remaining)
        else
            SetABWinTimerClock(nil)
        end
    end

    self.widget.allianceFill:Hide()
    self.widget.hordeFill:Hide()
    SetABWinTimerIconGlowActive(self.widget.allianceIconGlow, false, 0)
    SetABWinTimerIconGlowActive(self.widget.hordeIconGlow, false, 0)
    if not self.fiveBaseFadeElapsed then
        HideABWinTimerFiveBaseBeams()
    end
    if not faction then
        self.progressSparkFaction = nil
        self.progressSparkProgress = nil
        self.progressSparkPersistent = nil
        self.progressSparkElapsed = nil
        self.lastWinningProgress = nil
        self.lastWinningFaction = nil
        HideABWinTimerProgressSpark()
        return
    end

    local progress = math.max(0, math.min(1, tonumber(winningProgress) or 0))
    local width = abWinTimerTrackWidth * progress
    local useFiveBaseBeam = (self.paceFaction == faction) and ((tonumber(self.paceBases) or 0) >= 5)
    if width >= 1 then
        if useFiveBaseBeam then
            if faction == "Alliance" then
                self.widget.allianceFill:SetWidth(width)
                self.widget.allianceFill:Show()
                SetABWinTimerIconGlowActive(self.widget.allianceIconGlow, true, progress)
            else
                self.widget.hordeFill:SetWidth(width)
                self.widget.hordeFill:Show()
                SetABWinTimerIconGlowActive(self.widget.hordeIconGlow, true, progress)
            end
            SetABWinTimerFiveBaseProgress(faction, progress)
        elseif faction == "Alliance" then
            self.widget.allianceFill:SetWidth(width)
            self.widget.allianceFill:Show()
            SetABWinTimerIconGlowActive(self.widget.allianceIconGlow, true, progress)
        else
            self.widget.hordeFill:SetWidth(width)
            self.widget.hordeFill:Show()
            SetABWinTimerIconGlowActive(self.widget.hordeIconGlow, true, progress)
        end
    end

    local moved = (self.lastWinningFaction ~= faction) or (self.lastWinningProgress == nil) or (math.abs(progress - self.lastWinningProgress) > 0.0005)
    self.lastWinningFaction = faction
    self.lastWinningProgress = progress

    if progress >= 1 then
        self.progressSparkFaction = nil
        self.progressSparkProgress = nil
        self.progressSparkPersistent = nil
        self.progressSparkElapsed = nil
        HideABWinTimerProgressSpark()
    elseif useFiveBaseBeam then
        self.progressSparkFaction = faction
        self.progressSparkProgress = progress
        self.progressSparkPersistent = true
        self.progressSparkElapsed = 0
        PositionABWinTimerProgressSpark(faction, progress)
        self.widget.progressSpark:SetAlpha(1)
        self.widget.progressSpark:Show()
    elseif moved and width >= 1 then
        self.progressSparkFaction = faction
        self.progressSparkProgress = progress
        self.progressSparkPersistent = false
        self.progressSparkElapsed = 0
        PositionABWinTimerProgressSpark(faction, progress)
        self.widget.progressSpark:SetAlpha(1)
        self.widget.progressSpark:Show()
    end
end

function abWinTimer:Reset()
    self.activated = false
    self.revealElapsed = nil
    self.glowElapsed = nil
    self.glowFaction = nil
    self.pendingGlowFaction = nil
    self.paceFaction = nil
    self.paceBases = 0
    self.broadcastFaction = nil
    self.broadcastRemaining = nil
    self.broadcastUpdatedAt = nil
    self.broadcastDidWin = false
    self.burnElapsed = 0
    self.fiveBaseFadeElapsed = nil
    self.fiveBaseFadeFaction = nil
    self.fiveBaseFadeProgress = nil
    self.fiveBaseFadeBurnElapsed = nil
    self.progressSparkFaction = nil
    self.progressSparkProgress = nil
    self.progressSparkPersistent = nil
    self.progressSparkElapsed = nil
    self.lastWinningProgress = nil
    self.lastWinningFaction = nil
    self.winnerFaction = nil
    self.winnerAnimElapsed = nil
    self.livePollElapsed = 0
    self.liveAllianceScore = nil
    self.liveHordeScore = nil
    self.liveAllianceBases = nil
    self.liveHordeBases = nil
    self.liveAllianceScoreTime = nil
    self.liveHordeScoreTime = nil
    self.widget.allianceFill:Hide()
    self.widget.hordeFill:Hide()
    self.widget.allianceIconGlow.fadeAlpha = 0
    self.widget.allianceIconGlow.fadeTarget = 0
    self.widget.allianceIconGlow:SetAlpha(0)
    self.widget.allianceIconGlow:Hide()
    self.widget.hordeIconGlow.fadeAlpha = 0
    self.widget.hordeIconGlow.fadeTarget = 0
    self.widget.hordeIconGlow:SetAlpha(0)
    self.widget.hordeIconGlow:Hide()
    self.widget.clockText:Show()
    self.widget.winFrame:Hide()
    self.widget.allianceGlow:Hide()
    self.widget.hordeGlow:Hide()
    if self.widget.hordeGlowHot then self.widget.hordeGlowHot:Hide() end
    self.widget.glowFrame:SetAlpha(0)
    self.widget.glowFrame:Hide()
    HideABWinTimerFiveBaseBeams()
    HideABWinTimerFiveBaseBorderLightning()
    self.widget:SetAlpha(1)
    self:PositionWidget(AB_WIN_TIMER_START_Y)
    self.widget:Hide()
    SetABWinTimerClock(0)
end

function abWinTimer:BeginTest()
    self:Reset()
    self.testAllianceScore = 0
    self.testHordeScore = 0
    self.testRunning = true
end

function abWinTimer:EndTest()
    self.testRunning = false
    self.testAllianceScore = 0
    self.testHordeScore = 0
    self:Reset()
end

local function ReadABWinTimerWidget(widgetID)
    if not C_UIWidgetManager or type(C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo) ~= "function" then
        return nil
    end
    local ok, info = pcall(C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo, widgetID)
    if not ok or type(info) ~= "table" or type(info.text) ~= "string" then return nil end

    -- Capping's Classic AB widgets expose text in the form "<bases> ... <score>/2000".
    local basesText, scoreText, maxText = string.match(info.text, "(%d)[^%d]+(%d+)%s*/%s*(%d+)")
    local bases, score, maxScore = tonumber(basesText), tonumber(scoreText), tonumber(maxText)
    if not bases or not score then return nil end
    return bases, score, maxScore
end

function abWinTimer:RefreshLive()
    if abTestMode or not IsInArathiBasin() then return false end

    local allianceBases, allianceScore = ReadABWinTimerWidget(AB_WIN_TIMER_ALLIANCE_WIDGET_ID)
    local hordeBases, hordeScore = ReadABWinTimerWidget(AB_WIN_TIMER_HORDE_WIDGET_ID)
    if allianceBases == nil or hordeBases == nil then return false end

    local now = ABWinTimerNow()
    if self.liveAllianceScore == nil or allianceScore ~= self.liveAllianceScore
        or allianceBases ~= self.liveAllianceBases then
        self.liveAllianceScoreTime = now
    end
    if self.liveHordeScore == nil or hordeScore ~= self.liveHordeScore
        or hordeBases ~= self.liveHordeBases then
        self.liveHordeScoreTime = now
    end

    self.liveAllianceScore = allianceScore
    self.liveHordeScore = hordeScore
    self.liveAllianceBases = allianceBases
    self.liveHordeBases = hordeBases

    local visualAllianceBases, visualHordeBases = CountABWinTimerControlledBases()
    if (allianceBases + hordeBases) > 0 or (visualAllianceBases + visualHordeBases) > 0 then
        self:Activate()
    end
    if not self.activated then return true end

    local allianceRemaining = GetABWinTimerLiveRemaining(
        allianceScore, allianceBases, self.liveAllianceScoreTime, now)
    local hordeRemaining = GetABWinTimerLiveRemaining(
        hordeScore, hordeBases, self.liveHordeScoreTime, now)
    local faction, remaining = ChooseABWinTimerPace(allianceRemaining, hordeRemaining)
    local winningScore = faction == "Alliance" and allianceScore or (faction == "Horde" and hordeScore or 0)
    local winningBases = faction == "Alliance" and allianceBases or (faction == "Horde" and hordeBases or 0)
    local didWin = faction and (winningScore >= AB_WIN_TIMER_MAX_SCORE or ((tonumber(remaining) or 1) <= 0))
    self:SetPace(faction, remaining, winningScore / AB_WIN_TIMER_MAX_SCORE, winningBases, didWin)
    return true
end

function abWinTimer:UpdateTest(elapsed)
    if not abTestMode then return end
    if not self.testRunning then self:BeginTest() end

    local allianceBases, hordeBases = CountABWinTimerControlledBases()
    local allianceRate = GetABWinTimerRate(allianceBases)
    local hordeRate = GetABWinTimerRate(hordeBases)
    self.testAllianceScore = math.min(AB_WIN_TIMER_MAX_SCORE,
        self.testAllianceScore + (allianceRate * elapsed))
    self.testHordeScore = math.min(AB_WIN_TIMER_MAX_SCORE,
        self.testHordeScore + (hordeRate * elapsed))

    if (allianceBases + hordeBases) > 0 then self:Activate() end
    if not self.activated then return end

    local allianceRemaining = allianceRate > 0
        and math.max(0, (AB_WIN_TIMER_MAX_SCORE - self.testAllianceScore) / allianceRate)
        or AB_WIN_TIMER_INFINITY
    local hordeRemaining = hordeRate > 0
        and math.max(0, (AB_WIN_TIMER_MAX_SCORE - self.testHordeScore) / hordeRate)
        or AB_WIN_TIMER_INFINITY
    local faction, remaining = ChooseABWinTimerPace(allianceRemaining, hordeRemaining)
    local score = faction == "Alliance" and self.testAllianceScore or (faction == "Horde" and self.testHordeScore or 0)
    local winningBases = faction == "Alliance" and allianceBases or (faction == "Horde" and hordeBases or 0)
    local didWin = faction and (score >= AB_WIN_TIMER_MAX_SCORE or ((tonumber(remaining) or 1) <= 0))
    self:SetPace(faction, remaining, score / AB_WIN_TIMER_MAX_SCORE, winningBases, didWin)
end

function abWinTimer:UpdateAnimations(elapsed)
    if self.revealElapsed then
        self.revealElapsed = self.revealElapsed + elapsed
        local progress = math.max(0, math.min(1, self.revealElapsed / AB_WIN_TIMER_SLIDE_SECONDS))
        local eased = 1 - ((1 - progress) * (1 - progress) * (1 - progress))
        local y = AB_WIN_TIMER_START_Y + ((AB_WIN_TIMER_TARGET_Y - AB_WIN_TIMER_START_Y) * eased)
        self:PositionWidget(y)
        self.widget:SetAlpha(math.min(1, progress * 2.2))
        if progress >= 1 then
            self.revealElapsed = nil
            self:PositionWidget(AB_WIN_TIMER_TARGET_Y)
            self.widget:SetAlpha(1)
        end
    end

    if self.winnerAnimElapsed then
        self.winnerAnimElapsed = self.winnerAnimElapsed + elapsed
        local progress = math.max(0, math.min(1, self.winnerAnimElapsed / 0.32))
        local eased = 1 - ((1 - progress) * (1 - progress))
        self.widget.winFrame:SetAlpha(progress)
        self.widget.winFrame:SetScale(0.88 + (0.12 * eased))
    end

    local fiveBaseFadeMix = 0
    if self.fiveBaseFadeElapsed and self.fiveBaseFadeFaction == self.paceFaction then
        fiveBaseFadeMix = 1 - math.max(0, math.min(1, self.fiveBaseFadeElapsed / AB_WIN_TIMER_5BASE_POWERDOWN_SECONDS))
    end

    local glowAlpha = GetABWinTimerGlowAlpha(self.paceBases)
    if fiveBaseFadeMix > 0 then
        local fiveBaseGlowAlpha = GetABWinTimerGlowAlpha(5)
        glowAlpha = glowAlpha + ((fiveBaseGlowAlpha - glowAlpha) * fiveBaseFadeMix)
    end
    if self.paceFaction and glowAlpha > 0 then
        -- Both factions keep the same fitted geometry. Horde visibility now comes
        -- from the boss capturebar glow asset stacked in red, rather than from
        -- a weak tinted neutral glow.
        self.widget.glowFrame:SetSize(abWinTimerTrackWidth + 2, AB_WIN_TIMER_FILL_HEIGHT + 12)
        self.widget.allianceGlow:SetShown(self.paceFaction == "Alliance")
        self.widget.hordeGlow:SetShown(self.paceFaction == "Horde")
        self.widget.hordeGlowHot:SetShown(self.paceFaction == "Horde")

        local isFiveBase = (tonumber(self.paceBases) or 0) >= 5
        local fiveBaseIntensity = isFiveBase and 1 or fiveBaseFadeMix
        local alphaMult = self.paceFaction == "Horde" and AB_WIN_TIMER_HORDE_PACE_GLOW_ALPHA_MULT or 1
        local pulseTime = (ABWinTimerNow() or 0)
        local normalPulse = 0.96 + (0.04 * math.sin(pulseTime * 3.4))
        local fivePulse = 0.68 + (0.32 * (0.5 + (0.5 * math.sin(pulseTime * 5.0))))
        local pulse = normalPulse + ((fivePulse - normalPulse) * fiveBaseIntensity)
        local fiveScale = 0.995 + (0.012 * (0.5 + (0.5 * math.sin(pulseTime * 5.0))))
        local scale = 1 + ((fiveScale - 1) * fiveBaseIntensity)
        local allianceFiveAlpha = 0.68 + (0.32 * (0.5 + (0.5 * math.sin((pulseTime * 5.8) + 0.4))))
        local hordeFiveAlpha = allianceFiveAlpha
        local hordeHotFiveAlpha = 0.24 + (0.54 * (0.5 + (0.5 * math.sin((pulseTime * 8.8) + 0.9))))
        self.widget.allianceGlow:SetAlpha(1 + ((allianceFiveAlpha - 1) * fiveBaseIntensity))
        self.widget.hordeGlow:SetAlpha(1 + ((hordeFiveAlpha - 1) * fiveBaseIntensity))
        self.widget.hordeGlowHot:SetAlpha(0.72 + ((hordeHotFiveAlpha - 0.72) * fiveBaseIntensity))
        self.widget.glowFrame:SetScale(scale)
        self.widget.glowFrame:SetAlpha(math.min(1, glowAlpha * alphaMult * pulse))
        self.widget.glowFrame:Show()
    else
        self.widget.allianceGlow:Hide()
        self.widget.hordeGlow:Hide()
        if self.widget.hordeGlowHot then self.widget.hordeGlowHot:Hide() end
        self.widget.glowFrame:SetAlpha(0)
        self.widget.glowFrame:Hide()
    end

    local doCrawl = self.paceFaction and (tonumber(self.paceBases) or 0) >= 5
    if doCrawl then
        self.fiveBaseFadeElapsed = nil
        self.fiveBaseFadeFaction = nil
        self.fiveBaseFadeProgress = nil
        self.fiveBaseFadeBurnElapsed = nil
        self.burnElapsed = (self.burnElapsed or 0) + (elapsed or 0)
        local baseAlpha = 0.36 + (0.24 * (0.5 + (0.5 * math.sin((self.burnElapsed * 2.8) - 0.4))))
        local hotAlpha = 0.14 + (0.34 * (0.5 + (0.5 * math.sin((self.burnElapsed * 5.6) + 0.8))))
        self.widget.fiveBaseBorderFrame:Show()

        if self.paceFaction == "Horde" then
            self.widget.hordeFiveBaseBeam:SetAlpha(baseAlpha)
            self.widget.hordeFiveBaseBeamHot:SetAlpha(hotAlpha)
            UpdateABWinTimerCrackleSet(self.widget.hordeBorderLightning, "Horde", self.progressSparkProgress or self.lastWinningProgress or 0, self.burnElapsed, 1)
            HideABWinTimerCrackleSet(self.widget.allianceBorderLightning)
        else
            self.widget.allianceFiveBaseBeam:SetAlpha(baseAlpha)
            self.widget.allianceFiveBaseBeamHot:SetAlpha(hotAlpha)
            UpdateABWinTimerCrackleSet(self.widget.allianceBorderLightning, "Alliance", self.progressSparkProgress or self.lastWinningProgress or 0, self.burnElapsed, 1)
            HideABWinTimerCrackleSet(self.widget.hordeBorderLightning)
        end
    elseif self.fiveBaseFadeElapsed and self.fiveBaseFadeFaction then
        self.fiveBaseFadeElapsed = self.fiveBaseFadeElapsed + (elapsed or 0)
        self.fiveBaseFadeBurnElapsed = (self.fiveBaseFadeBurnElapsed or self.burnElapsed or 0) + (elapsed or 0)

        local fadeProgress = math.max(0, math.min(1, self.fiveBaseFadeElapsed / AB_WIN_TIMER_5BASE_POWERDOWN_SECONDS))
        local beamFade = 1 - (fadeProgress * fadeProgress)
        local crackleFade = 1 - math.max(0, math.min(1, self.fiveBaseFadeElapsed / AB_WIN_TIMER_5BASE_CRACKLE_POWERDOWN_SECONDS))
        local baseAlpha = (0.36 + (0.24 * (0.5 + (0.5 * math.sin((self.fiveBaseFadeBurnElapsed * 2.8) - 0.4))))) * beamFade
        local hotAlpha = (0.14 + (0.34 * (0.5 + (0.5 * math.sin((self.fiveBaseFadeBurnElapsed * 5.6) + 0.8))))) * beamFade
        local fadeFaction = self.fiveBaseFadeFaction
        local fadeProgressValue = self.fiveBaseFadeProgress or self.lastWinningProgress or 0
        self.widget.fiveBaseBorderFrame:Show()

        if fadeFaction == "Horde" then
            self.widget.hordeFiveBaseBeam:SetAlpha(baseAlpha)
            self.widget.hordeFiveBaseBeamHot:SetAlpha(hotAlpha)
            self.widget.hordeFiveBaseBeam:Show()
            self.widget.hordeFiveBaseBeamHot:Show()
            UpdateABWinTimerCrackleSet(self.widget.hordeBorderLightning, "Horde", fadeProgressValue, self.fiveBaseFadeBurnElapsed, crackleFade)
            HideABWinTimerCrackleSet(self.widget.allianceBorderLightning)
        else
            self.widget.allianceFiveBaseBeam:SetAlpha(baseAlpha)
            self.widget.allianceFiveBaseBeamHot:SetAlpha(hotAlpha)
            self.widget.allianceFiveBaseBeam:Show()
            self.widget.allianceFiveBaseBeamHot:Show()
            UpdateABWinTimerCrackleSet(self.widget.allianceBorderLightning, "Alliance", fadeProgressValue, self.fiveBaseFadeBurnElapsed, crackleFade)
            HideABWinTimerCrackleSet(self.widget.hordeBorderLightning)
        end

        if fadeProgress >= 1 then
            self.fiveBaseFadeElapsed = nil
            self.fiveBaseFadeFaction = nil
            self.fiveBaseFadeProgress = nil
            self.fiveBaseFadeBurnElapsed = nil
            self.burnElapsed = 0
            HideABWinTimerFiveBaseBeams()
            HideABWinTimerFiveBaseBorderLightning()
        end
    else
        self.burnElapsed = 0
        HideABWinTimerFiveBaseBeams()
        HideABWinTimerFiveBaseBorderLightning()
    end

    if self.progressSparkFaction and self.progressSparkProgress and self.progressSparkProgress < 1 then
        PositionABWinTimerProgressSpark(self.progressSparkFaction, self.progressSparkProgress)
        if self.progressSparkPersistent then
            local pulse = 0.88 + (0.12 * (0.5 + (0.5 * math.sin((ABWinTimerNow() or 0) * 6.2))))
            self.widget.progressSpark:SetAlpha(pulse)
            self.widget.progressSpark:Show()
        elseif self.widget.progressSpark:IsShown() then
            self.progressSparkElapsed = (self.progressSparkElapsed or 0) + (elapsed or 0)
            local fadeProgress = math.max(0, math.min(1, self.progressSparkElapsed / AB_WIN_TIMER_PROGRESS_SPARK_FADE_SECONDS))
            self.widget.progressSpark:SetAlpha(1 - fadeProgress)
            if fadeProgress >= 1 then
                self.progressSparkFaction = nil
                self.progressSparkProgress = nil
                self.progressSparkElapsed = nil
                HideABWinTimerProgressSpark()
            end
        end
    else
        HideABWinTimerProgressSpark()
    end

    local iconGlows = { self.widget.allianceIconGlow, self.widget.hordeIconGlow }
    for _, glow in ipairs(iconGlows) do
        if glow then
            local target = tonumber(glow.fadeTarget) or 0
            local current = tonumber(glow.fadeAlpha) or 0
            local fadeStep = math.min(1, (elapsed or 0) / AB_WIN_TIMER_ICON_GLOW_FADE_SECONDS)
            current = current + ((target - current) * fadeStep)

            if target <= 0 and current < 0.015 then
                current = 0
                glow:SetAlpha(0)
                glow:Hide()
                if glow.rays01 then glow.rays01:Hide() end
                if glow.rays02 then glow.rays02:Hide() end
            else
                if not glow:IsShown() then glow:Show() end
                glow:SetAlpha(current)
                glow.elapsed = (glow.elapsed or 0) + (elapsed or 0)

                local progress = math.max(0, math.min(1, tonumber(glow.progress) or 0))
                local rearPulse = 0.5 + (0.5 * math.sin(glow.elapsed * 3.6))
                local innerPulse = 0.5 + (0.5 * math.sin((glow.elapsed * 4.2) + (math.pi * 0.72)))
                local threshold75 = math.max(0, math.min(1, (progress - 0.75) / 0.20))
                local threshold95 = math.max(0, math.min(1, (progress - 0.95) / 0.05))
                local endBoost = 1 + (0.24 * threshold95)

                glow.rearStar:SetSize((40 + (8 * rearPulse)) + (6 * threshold95), (40 + (8 * rearPulse)) + (6 * threshold95))
                glow.rearStar:SetAlpha((0.66 + (0.16 * rearPulse)) + (0.12 * threshold95))
                glow.innerStar:SetSize((30 + (7 * innerPulse)) + (5 * threshold95), (30 + (7 * innerPulse)) + (5 * threshold95))
                glow.innerStar:SetAlpha((0.58 + (0.20 * innerPulse)) + (0.12 * threshold95))
                if glow.rearStar.SetRotation then glow.rearStar:SetRotation(glow.elapsed * (0.72 * endBoost)) end
                if glow.innerStar.SetRotation then glow.innerStar:SetRotation(glow.elapsed * (-0.98 * endBoost)) end

                if threshold75 > 0 then
                    local speedMult = 1.0 + (0.80 * threshold95)
                    local rays01Pulse = 0.5 + (0.5 * math.sin((glow.elapsed * (3.4 * speedMult)) + 0.35))
                    local rays02Pulse = 0.5 + (0.5 * math.sin((glow.elapsed * (4.4 * speedMult)) + 1.15))
                    local rays01Size = 26 + (8 * threshold75) + (14 * threshold95) + (6 * rays01Pulse)
                    local rays02Size = 22 + (7 * threshold75) + (16 * threshold95) + (7 * rays02Pulse)
                    glow.rays01:SetSize(rays01Size, rays01Size)
                    glow.rays02:SetSize(rays02Size, rays02Size)
                    glow.rays01:SetAlpha((0.08 + (0.12 * threshold75) + (0.24 * threshold95)) * (0.72 + (0.22 * rays01Pulse)))
                    glow.rays02:SetAlpha((0.06 + (0.10 * threshold75) + (0.28 * threshold95)) * (0.70 + (0.24 * rays02Pulse)))
                    if glow.rays01.SetRotation then glow.rays01:SetRotation(glow.elapsed * (0.22 * speedMult)) end
                    if glow.rays02.SetRotation then glow.rays02:SetRotation(glow.elapsed * (-0.32 * speedMult)) end
                    glow.rays01:Show()
                    glow.rays02:Show()
                else
                    glow.rays01:Hide()
                    glow.rays02:Hide()
                end
            end

            glow.fadeAlpha = current
        end
    end
end

abWinTimer.updateFrame = CreateFrame("Frame", nil, frame)
abWinTimer.updateFrame:SetScript("OnUpdate", function(_, elapsed)
    elapsed = tonumber(elapsed) or 0
    abWinTimer:UpdateAnimations(elapsed)

    if abTestMode then
        abWinTimer:UpdateTest(elapsed)
        return
    end

    if not IsInArathiBasin() then
        if abWinTimer.activated or abWinTimer.testRunning then abWinTimer:EndTest() end
        return
    end

    abWinTimer.testRunning = false
    abWinTimer.livePollElapsed = abWinTimer.livePollElapsed + elapsed
    if abWinTimer.livePollElapsed >= AB_WIN_TIMER_LIVE_POLL_SECONDS then
        abWinTimer.livePollElapsed = abWinTimer.livePollElapsed % AB_WIN_TIMER_LIVE_POLL_SECONDS
        abWinTimer:RefreshLive()
    end
end)

abWinTimer.eventFrame = CreateFrame("Frame", nil, frame)
abWinTimer.eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
abWinTimer.eventFrame:SetScript("OnEvent", function(_, _, widgetInfo)
    if abTestMode or not IsInArathiBasin() then return end
    local widgetID = type(widgetInfo) == "table" and widgetInfo.widgetID or tonumber(widgetInfo)
    if widgetID == AB_WIN_TIMER_ALLIANCE_WIDGET_ID or widgetID == AB_WIN_TIMER_HORDE_WIDGET_ID then
        abWinTimer:RefreshLive()
    end
end)

frame.abWinTimer = abWinTimer
end -- AB game-pace timer scope

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

-- AB hover and contested areas use the same renderer as the finished WSG
-- callout regions: antialiased masks, one shared stripe direction, uniformly
-- rotating border dashes, and a map-anchored button shadow.
local AB_AREA_VISUAL = {
    stripeTexture = "Interface\\AddOns\\ZurkMaps\\Media\\CalloutStripes",
    stripeLong = 1024,
    stripeShort = 512,
    stripeTile = 16,
    stripeCycle = 3.2,
    stripeAlpha = 0.34,
    borderDashCycle = 1.8,
    borderAlpha = 0.86,
    shadowOffset = 2.15,
    shadowAlpha = 0.48,
    hoverOffset = 0,
    pressedOffset = 1.35,
    releaseDuration = 0.09,
    roadHalfWidth = 1.20,
    allianceColor = { 0.12, 0.36, 1.00 },
    hordeColor = { 1.00, 0.20, 0.16 },
}

local function SmoothABContour(points, iterations)
    local result = {}
    for _, point in ipairs(points or {}) do
        result[#result + 1] = { point[1], point[2] }
    end
    for _ = 1, (iterations or 0) do
        local smoothed = {}
        for index, point in ipairs(result) do
            local nextPoint = result[(index % #result) + 1]
            smoothed[#smoothed + 1] = {
                (point[1] * 0.75) + (nextPoint[1] * 0.25),
                (point[2] * 0.75) + (nextPoint[2] * 0.25),
            }
            smoothed[#smoothed + 1] = {
                (point[1] * 0.25) + (nextPoint[1] * 0.75),
                (point[2] * 0.25) + (nextPoint[2] * 0.75),
            }
        end
        result = smoothed
    end
    return result
end

local function SmoothABOpenPath(points, iterations)
    local result = {}
    for _, point in ipairs(points or {}) do result[#result + 1] = { point[1], point[2] } end
    for _ = 1, (iterations or 0) do
        local smoothed = { { result[1][1], result[1][2] } }
        for index = 1, #result - 1 do
            local point, nextPoint = result[index], result[index + 1]
            smoothed[#smoothed + 1] = {
                (point[1] * 0.75) + (nextPoint[1] * 0.25),
                (point[2] * 0.75) + (nextPoint[2] * 0.25),
            }
            smoothed[#smoothed + 1] = {
                (point[1] * 0.25) + (nextPoint[1] * 0.75),
                (point[2] * 0.25) + (nextPoint[2] * 0.75),
            }
        end
        smoothed[#smoothed + 1] = { result[#result][1], result[#result][2] }
        result = smoothed
    end
    return result
end

local function BuildABRoadContour(path)
    if not path or #path < 2 then return {} end
    local centers = SmoothABOpenPath(path, 2)
    local left, right, tangents, normals = {}, {}, {}, {}
    for index, point in ipairs(centers) do
        local before = centers[math.max(1, index - 1)]
        local after = centers[math.min(#centers, index + 1)]
        local dx, dy = after[1] - before[1], after[2] - before[2]
        local length = math.sqrt((dx * dx) + (dy * dy))
        local nx, ny = 0, 0
        if length > 0 then
            nx = (-dy / length) * AB_AREA_VISUAL.roadHalfWidth
            ny = (dx / length) * AB_AREA_VISUAL.roadHalfWidth
        end
        tangents[index] = { length > 0 and (dx / length) or 0, length > 0 and (dy / length) or 0 }
        normals[index] = { nx, ny }
        left[#left + 1] = { point[1] + nx, point[2] + ny }
        right[#right + 1] = { point[1] - nx, point[2] - ny }
    end

    local contour = {}
    for _, point in ipairs(left) do contour[#contour + 1] = point end
    local finish, finishTangent, finishNormal = centers[#centers], tangents[#centers], normals[#centers]
    for step = 1, 6 do
        local angle = math.pi * step / 6
        contour[#contour + 1] = {
            finish[1] + (finishNormal[1] * math.cos(angle)) + (finishTangent[1] * AB_AREA_VISUAL.roadHalfWidth * math.sin(angle)),
            finish[2] + (finishNormal[2] * math.cos(angle)) + (finishTangent[2] * AB_AREA_VISUAL.roadHalfWidth * math.sin(angle)),
        }
    end
    for index = #right - 1, 1, -1 do contour[#contour + 1] = right[index] end
    local start, startTangent, startNormal = centers[1], tangents[1], normals[1]
    for step = 1, 5 do
        local angle = math.pi * step / 6
        contour[#contour + 1] = {
            start[1] - (startNormal[1] * math.cos(angle)) - (startTangent[1] * AB_AREA_VISUAL.roadHalfWidth * math.sin(angle)),
            start[2] - (startNormal[2] * math.cos(angle)) - (startTangent[2] * AB_AREA_VISUAL.roadHalfWidth * math.sin(angle)),
        }
    end
    return contour
end

local function GetABVisualContours(zone)
    if not zone then return {} end
    if zone.points then return { SmoothABContour(zone.points, 2) } end
    local contours = {}
    for _, path in ipairs(zone.hitPaths or {}) do
        local contour = BuildABRoadContour(path)
        if #contour >= 3 then contours[#contours + 1] = contour end
    end
    return contours
end

local function GetABVisualBounds(zone)
    local minX, minY, maxX, maxY
    for _, contour in ipairs(GetABVisualContours(zone)) do
        for _, point in ipairs(contour) do
            minX = minX and math.min(minX, point[1]) or point[1]
            minY = minY and math.min(minY, point[2]) or point[2]
            maxX = maxX and math.max(maxX, point[1]) or point[1]
            maxY = maxY and math.max(maxY, point[2]) or point[2]
        end
    end
    return minX, minY, maxX, maxY
end

local function GetABControlledFactionColor(zone)
    if not zone or not zone.isBase then return nil end
    local baseNode = BASE_NODE_BY_ID[zone.id]
    if not baseNode then return nil end
    local textureIndex = abTestMode and tonumber(abTestBaseNodeStates[zone.id]) or nil
    textureIndex = textureIndex or tonumber(baseNode.currentTextureIndex) or baseNode.neutralTextureIndex
    local offset = textureIndex - baseNode.neutralTextureIndex
    if offset == 2 then return unpack(AB_AREA_VISUAL.allianceColor) end
    if offset == 4 then return unpack(AB_AREA_VISUAL.hordeColor) end
    return nil
end

local function CreateABHighlight()
    local overlay = CreateFrame("Frame", nil, map)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(map:GetFrameLevel() + 1)
    overlay:EnableMouse(false)

    overlay.shadowTexture = overlay:CreateTexture(nil, "BORDER")
    overlay.shadowTexture:SetAllPoints()
    overlay.shadowTexture:SetVertexColor(0, 0, 0, AB_AREA_VISUAL.shadowAlpha)
    overlay.shadowTexture:Hide()

    overlay.texture = overlay:CreateTexture(nil, "ARTWORK")
    overlay.texture:SetAllPoints()

    overlay.animatedMask = overlay:CreateMaskTexture(nil, "ARTWORK")
    overlay.animatedMask:SetAllPoints()
    overlay.animatedFillTexture = overlay:CreateTexture(nil, "ARTWORK", nil, 1)
    overlay.animatedFillTexture:SetAllPoints()
    overlay.animatedFillTexture:AddMaskTexture(overlay.animatedMask)
    overlay.animatedFillTexture:Hide()
    overlay.animatedStripeTexture = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
    overlay.animatedStripeTexture:SetAllPoints()
    overlay.animatedStripeTexture:SetTexture(AB_AREA_VISUAL.stripeTexture)
    overlay.animatedStripeTexture:SetBlendMode("BLEND")
    overlay.animatedStripeTexture:AddMaskTexture(overlay.animatedMask)
    overlay.animatedStripeTexture:Hide()
    overlay.animatedBorderSegments = {}
    overlay.animatedContourGeometry = {}

    function overlay:SetZone(zone)
        self.zone = zone
        local r, g, b = GetABControlledFactionColor(zone)
        local textureFolder = r and "Contested" or "Highlights"
        local texturePath = "Interface\\AddOns\\ZurkMaps\\Media\\" .. textureFolder .. "\\" .. zone.id
        self.shadowTexture:SetTexture(texturePath)
        self.texture:SetTexture(texturePath)
        self.texture:SetVertexColor(r or 1, g or 1, b or 1, 1)
        self.animatedMask:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\CalloutMasks\\" .. zone.id)
        if self.animatedActive then self:BuildAnimatedGeometry() else self.texture:Show() end
    end

    function overlay:GetAnimatedBorderPoint(geometry, distance)
        local perimeter = geometry and geometry.perimeter or 0
        if perimeter <= 0 then return 0, 0 end
        distance = distance % perimeter
        local traversed = 0
        for index, point in ipairs(geometry.points) do
            local length = geometry.edgeLengths[index]
            if distance <= traversed + length or index == #geometry.points then
                local nextPoint = geometry.points[(index % #geometry.points) + 1]
                local ratio = length > 0 and ((distance - traversed) / length) or 0
                return point[1] + ((nextPoint[1] - point[1]) * ratio),
                    point[2] + ((nextPoint[2] - point[2]) * ratio)
            end
            traversed = traversed + length
        end
        return geometry.points[1][1], geometry.points[1][2]
    end

    function overlay:BuildAnimatedGeometry()
        self.texture:Hide()
        self.animatedFillTexture:Hide()
        self.animatedStripeTexture:Hide()
        for _, segment in ipairs(self.animatedBorderSegments) do segment:Hide() end
        self.animatedContourGeometry = {}
        self.animatedBorderCount = 0
        if not self.animatedActive or not self.zone then return end

        local width, height = self:GetWidth(), self:GetHeight()
        if not width or not height or width <= 0 or height <= 0 then return end
        local r, g, b = self.animatedR or 1, self.animatedG or 1, self.animatedB or 1
        self.animatedFillTexture:SetColorTexture(r, g, b, 72 / 255)
        self.animatedFillTexture:Show()
        self.animatedStripeTexture:SetVertexColor(r, g, b, AB_AREA_VISUAL.stripeAlpha)
        self.animatedStripeTexture:Show()

        local segmentIndex = 0
        for _, contour in ipairs(GetABVisualContours(self.zone)) do
            local pixelPoints, edgeLengths, perimeter = {}, {}, 0
            for _, point in ipairs(contour) do
                pixelPoints[#pixelPoints + 1] = { point[1] * width / 100, point[2] * height / 100 }
            end
            for index, point in ipairs(pixelPoints) do
                local nextPoint = pixelPoints[(index % #pixelPoints) + 1]
                local dx, dy = nextPoint[1] - point[1], nextPoint[2] - point[2]
                local length = math.sqrt((dx * dx) + (dy * dy))
                edgeLengths[index] = length
                perimeter = perimeter + length
            end
            if perimeter > 0 then
                local segmentCount = math.max(10, math.min(40, math.floor((perimeter / 8) + 0.5)))
                local geometry = {
                    points = pixelPoints,
                    edgeLengths = edgeLengths,
                    perimeter = perimeter,
                    cellLength = perimeter / segmentCount,
                    firstSegment = segmentIndex + 1,
                    segmentCount = segmentCount,
                }
                self.animatedContourGeometry[#self.animatedContourGeometry + 1] = geometry
                for localIndex = 1, segmentCount do
                    segmentIndex = segmentIndex + 1
                    local startDistance = (localIndex - 1) * geometry.cellLength
                    local x1, y1 = self:GetAnimatedBorderPoint(geometry, startDistance)
                    local x2, y2 = self:GetAnimatedBorderPoint(geometry, startDistance + (geometry.cellLength * 0.68))
                    local segment = self.animatedBorderSegments[segmentIndex]
                    if not segment then
                        segment = self:CreateLine(nil, "OVERLAY")
                        self.animatedBorderSegments[segmentIndex] = segment
                    end
                    segment:SetColorTexture(r, g, b, 1)
                    segment:SetThickness(2.35)
                    segment:SetStartPoint("TOPLEFT", self, x1, -y1)
                    segment:SetEndPoint("TOPLEFT", self, x2, -y2)
                    segment:SetAlpha(AB_AREA_VISUAL.borderAlpha * (self.animatedPulseAlpha or 1))
                    segment:Show()
                end
            end
        end
        self.animatedBorderCount = segmentIndex
        self:UpdateAnimatedAnimation(self.animatedAge or 0)
    end

    function overlay:SetAnimatedColor(r, g, b)
        self.animatedR, self.animatedG, self.animatedB = r, g, b
        if self.animatedActive then self:BuildAnimatedGeometry() end
    end

    function overlay:SetAnimatedActive(active)
        self.animatedActive = active and true or false
        if self.animatedActive then
            self.shadowMode = "ANIMATED"
            self.pendingHoverExit = false
            self.contentOffset, self.contentTargetOffset = 0, 0
            self.animatedPulseAlpha = 1
            self:ApplyContentOffset()
            self:ApplyShadow()
            self:BuildAnimatedGeometry()
            self:Show()
        else
            self.shadowMode = nil
            self.pendingHoverExit = false
            self.interactionActive = false
            self.interactionPressed = false
            self.releaseActive = false
            self.releaseElapsed, self.releaseStartOffset = nil, nil
            self.contentOffset, self.contentTargetOffset = 0, 0
            self:ApplyContentOffset()
            self.shadowTexture:Hide()
            self.animatedFillTexture:Hide()
            self.animatedStripeTexture:Hide()
            for _, segment in ipairs(self.animatedBorderSegments) do segment:Hide() end
            self.animatedBorderCount = 0
            self.animatedContourGeometry = {}
            self.animatedPulseAlpha = 1
            if self.zone then self.texture:Show() end
        end
    end

    function overlay:SetAnimatedPulseAlpha(alpha)
        alpha = math.max(0, math.min(1, tonumber(alpha) or 1))
        self.animatedPulseAlpha = alpha
        self.animatedFillTexture:SetAlpha(alpha)
        self.animatedStripeTexture:SetAlpha(alpha)
        for index = 1, (self.animatedBorderCount or 0) do
            self.animatedBorderSegments[index]:SetAlpha(AB_AREA_VISUAL.borderAlpha * alpha)
        end
        if self.animatedActive then self:ApplyShadow() end
    end

    function overlay:UpdateAnimatedAnimation(age)
        if not self.animatedActive then return end
        age = tonumber(age) or 0
        self.animatedAge = age
        local stripePhase = ((age % AB_AREA_VISUAL.stripeCycle) / AB_AREA_VISUAL.stripeCycle) * AB_AREA_VISUAL.stripeTile
        self.animatedStripeTexture:SetTexCoord(
            stripePhase / AB_AREA_VISUAL.stripeLong,
            (stripePhase + self:GetWidth()) / AB_AREA_VISUAL.stripeLong,
            0,
            self:GetHeight() / AB_AREA_VISUAL.stripeShort
        )
        for _, geometry in ipairs(self.animatedContourGeometry or {}) do
            local borderOffset = ((age % AB_AREA_VISUAL.borderDashCycle) / AB_AREA_VISUAL.borderDashCycle) * geometry.cellLength
            for localIndex = 1, geometry.segmentCount do
                local startDistance = ((localIndex - 1) * geometry.cellLength) + borderOffset
                local x1, y1 = self:GetAnimatedBorderPoint(geometry, startDistance)
                local x2, y2 = self:GetAnimatedBorderPoint(geometry, startDistance + (geometry.cellLength * 0.68))
                local segment = self.animatedBorderSegments[geometry.firstSegment + localIndex - 1]
                segment:SetStartPoint("TOPLEFT", self, x1, -y1)
                segment:SetEndPoint("TOPLEFT", self, x2, -y2)
                segment:SetAlpha(AB_AREA_VISUAL.borderAlpha * (self.animatedPulseAlpha or 1))
            end
        end
    end

    function overlay:ApplyContentOffset()
        local offset = tonumber(self.contentOffset) or 0
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", map, "TOPLEFT", offset, -offset)
        self:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", offset, -offset)
    end

    function overlay:ApplyShadow()
        if not self.shadowMode then
            self.shadowTexture:Hide()
            return
        end
        local offset = AB_AREA_VISUAL.shadowOffset - (tonumber(self.contentOffset) or 0)
        self.shadowTexture:ClearAllPoints()
        self.shadowTexture:SetPoint("TOPLEFT", self, "TOPLEFT", offset, -offset)
        self.shadowTexture:SetSize(self:GetWidth(), self:GetHeight())
        self.shadowTexture:SetVertexColor(0, 0, 0, self.interactionPressed and 0.20 or AB_AREA_VISUAL.shadowAlpha)
        self.shadowTexture:Show()
    end

    function overlay:BeginInteractionRelease()
        self.interactionPressed = false
        self.contentTargetOffset = AB_AREA_VISUAL.hoverOffset
        self.releaseStartOffset = math.max(0, tonumber(self.contentOffset) or 0)
        self.releaseElapsed = 0
        self.releaseActive = self.releaseStartOffset > 0.001
    end

    function overlay:SetHoverInteraction(active)
        if active then
            self.pendingHoverExit = false
            self.interactionActive = true
            self.shadowMode = self.animatedActive and "ANIMATED" or "HOVER"
            self.contentOffset = self.contentOffset or AB_AREA_VISUAL.hoverOffset
            self.contentTargetOffset = AB_AREA_VISUAL.hoverOffset
            self:ApplyShadow()
            return
        end

        local wasPressed = self.interactionPressed
        self.interactionActive = false
        if wasPressed then self:BeginInteractionRelease() end
        self.contentTargetOffset = AB_AREA_VISUAL.hoverOffset

        if self.animatedActive then
            self.pendingHoverExit = false
            self.shadowMode = "ANIMATED"
            self:ApplyShadow()
        elseif self.releaseActive or math.abs(tonumber(self.contentOffset) or 0) > 0.02 then
            if not self.releaseActive then self:BeginInteractionRelease() end
            self.pendingHoverExit = true
            self.shadowMode = "HOVER_RELEASE"
            self:ApplyShadow()
        else
            self.pendingHoverExit = false
            self.shadowMode = nil
            self.contentOffset, self.contentTargetOffset = 0, 0
            self:ApplyContentOffset()
            self.shadowTexture:Hide()
        end
    end

    function overlay:SetInteractionPressed(pressed)
        if not self.interactionActive then return end
        if pressed then
            self.interactionPressed = true
            self.releaseActive = false
            self.contentOffset = AB_AREA_VISUAL.pressedOffset
            self.contentTargetOffset = AB_AREA_VISUAL.pressedOffset
        else
            self:BeginInteractionRelease()
        end
        self:ApplyContentOffset()
        self:ApplyShadow()
    end

    function overlay:UpdateInteractionAnimation(elapsed)
        if not self.shadowMode then return end
        elapsed = math.max(0, tonumber(elapsed) or 0)
        if self.interactionPressed then
            self.contentOffset = AB_AREA_VISUAL.pressedOffset
        elseif self.releaseActive then
            self.releaseElapsed = (self.releaseElapsed or 0) + elapsed
            local progress = math.min(1, self.releaseElapsed / AB_AREA_VISUAL.releaseDuration)
            self.contentOffset = (self.releaseStartOffset or 0) * ((1 - progress) ^ 3)
            if progress >= 1 then
                self.contentOffset = AB_AREA_VISUAL.hoverOffset
                self.releaseActive = false
                self.releaseElapsed, self.releaseStartOffset = nil, nil
            end
        else
            self.contentOffset = self.contentTargetOffset or AB_AREA_VISUAL.hoverOffset
        end

        if self.pendingHoverExit and not self.releaseActive then
            self.contentOffset, self.contentTargetOffset = 0, 0
            self.pendingHoverExit = false
            self.shadowMode = nil
            self:ApplyContentOffset()
            self.shadowTexture:Hide()
            self:Hide()
            return
        end
        self:ApplyContentOffset()
        self:ApplyShadow()
    end

    function overlay:IsFinishingHoverRelease()
        return self.pendingHoverExit and true or false
    end

    overlay:SetScript("OnSizeChanged", function(self)
        if self.shadowMode then self:ApplyShadow() end
        if self.animatedActive then self:BuildAnimatedGeometry() end
    end)
    overlay:Hide()
    return overlay
end

local highlightTexture = CreateABHighlight()

local function ClearABAreaInteraction()
    if hoveredAreaOverlay then hoveredAreaOverlay:SetHoverInteraction(false) end
    hoveredAreaOverlay = nil
    if not highlightTexture:IsFinishingHoverRelease() then highlightTexture:Hide() end
end

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
local resizeState

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

    if UpdateABWinTimerScale then
        UpdateABWinTimerScale(addonScale)
    end
    if ConfigureFriendlyPlayerDots then
        ConfigureFriendlyPlayerDots()
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

local function StartMove()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    isMoving = true
    hoveredZone = nil
    ClearABAreaInteraction()
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
    resizeState = ZurkMapsMapResize.Begin(frame, mapBorder)
    hoveredZone = nil
    ClearABAreaInteraction()
    GameTooltip:Hide()
end

local function EndResize()
    if not resizing then
        return
    end

    resizing = false
    resizeState = nil
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

    local newScale = ZurkMapsMapResize.Update(frame, resizeState, MIN_SCALE, MAX_SCALE)
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

focusCallout.raidTargetChatTags = {
    [1] = "{star}",
    [2] = "{circle}",
    [3] = "{diamond}",
    [4] = "{triangle}",
    [5] = "{moon}",
    [6] = "{square}",
    [7] = "{cross}",
    [8] = "{skull}",
}

function focusCallout:ReportCurrentTarget()
    if not UnitExists("target") or not UnitIsPlayer("target") then
        print("|cff33ff99Zurk Maps|r: Select a player target first.")
        return
    end

    local name = UnitName("target")
    if not name or name == "" then
        print("|cff33ff99Zurk Maps|r: Could not identify the current target.")
        return
    end

    if UnitIsFriend("player", "target") then
        local markerIndex = GetRaidTargetIndex and GetRaidTargetIndex("target")
        local markerTag = markerIndex and self.raidTargetChatTags[markerIndex]
        if markerTag then
            Report("Assist " .. name .. " " .. markerTag .. "!")
        else
            Report("Assist " .. name .. "!")
        end
        return
    end

    local race = UnitRace("target")
    local className = UnitClass("target")
    if race and race ~= "" and className and className ~= "" then
        Report("Focus " .. name .. " - " .. race .. " " .. className .. "!")
    else
        Report("Focus " .. name .. "!")
    end
end

function focusCallout:CloseMenu()
    if self.menu then self.menu:Hide() end
    if self.dismiss then self.dismiss:Hide() end
    if self.openHighlight then self.openHighlight:Hide() end

    if self.button and self.button:IsMouseOver() then
        self.icon:SetAlpha(1)
        self.border:SetAlpha(1)
    elseif self.icon and self.border then
        self.icon:SetAlpha(1)
        self.border:SetAlpha(1)
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
focusCallout.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

focusCallout.background = focusCallout.button:CreateTexture(nil, "BACKGROUND")
focusCallout.background:SetAllPoints()
focusCallout.background:SetColorTexture(0.08, 0.055, 0.025, 1)

focusCallout.icon = focusCallout.button:CreateTexture(nil, "ARTWORK")
focusCallout.icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
focusCallout.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
focusCallout.icon:SetAlpha(1)

focusCallout.border = ZurkMapsBattlecry.CreateButtonBorder(focusCallout.button)
focusCallout.border:FitContent(focusCallout.background, focusCallout.icon, 1)
focusCallout.border:SetAlpha(1)
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
        Report("Focus the " .. self.classNameUpper .. "!")
    end)
    focusCallout.optionButtons[i] = option
end

focusCallout.button:SetScript("OnEnter", function(self)
    focusCallout.icon:SetAlpha(1)
    focusCallout.border:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Focus Callout", 1.0, 0.82, 0.0)
    GameTooltip:AddDoubleLine(((type(CreateAtlasMarkup) == "function" and (((C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("NPE_LeftClick")) or (type(GetAtlasInfo) == "function" and GetAtlasInfo("NPE_LeftClick")))) and CreateAtlasMarkup("NPE_LeftClick", 18, 18, 0, 0) or "LMB") .. " |cffff7070Enemy|r"), "|cffffffffFocus target|r", 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    GameTooltip:AddDoubleLine(((type(CreateAtlasMarkup) == "function" and (((C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("NPE_LeftClick")) or (type(GetAtlasInfo) == "function" and GetAtlasInfo("NPE_LeftClick")))) and CreateAtlasMarkup("NPE_LeftClick", 18, 18, 0, 0) or "LMB") .. " |cff70ff70Friendly|r"), "|cffffffffAssist target|r", 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    GameTooltip:AddDoubleLine(((type(CreateAtlasMarkup) == "function" and (((C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("NPE_RightClick")) or (type(GetAtlasInfo) == "function" and GetAtlasInfo("NPE_RightClick")))) and CreateAtlasMarkup("NPE_RightClick", 18, 18, 0, 0) or "RMB") .. " |cffffd36aMenu|r"), "|cffffffffChoose enemy class|r", 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    GameTooltip:Show()
end)

focusCallout.button:SetScript("OnLeave", function()
    if focusCallout.menu:IsShown() then
        focusCallout.icon:SetAlpha(1)
        focusCallout.border:SetAlpha(1)
    else
        focusCallout.icon:SetAlpha(1)
        focusCallout.border:SetAlpha(1)
    end
    GameTooltip:Hide()
end)

focusCallout.button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "LeftButton" then
        focusCallout:CloseMenu()
        GameTooltip:Hide()
        focusCallout:ReportCurrentTarget()
        return
    end

    if mouseButton ~= "RightButton" then
        return
    end

    if focusCallout.menu:IsShown() then
        focusCallout:CloseMenu()
        return
    end

    hoveredZone = nil
    ClearABAreaInteraction()
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
battlecry.background:SetColorTexture(0.08, 0.055, 0.025, 1)

battlecry.icon = battlecry.button:CreateTexture(nil, "ARTWORK")
battlecry.icon:SetTexture(battlecry:GetIconTexture())
battlecry.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
battlecry.icon:SetAlpha(1)

battlecry.border = ZurkMapsBattlecry.CreateButtonBorder(battlecry.button)
battlecry.border:FitContent(battlecry.background, battlecry.icon, 1)
battlecry.border:SetAlpha(1)
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
    ClearABAreaInteraction()
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
    battlecry.icon:SetAlpha(1)
    battlecry.border:SetAlpha(1)
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

local function ShowZoneTooltip(zone)
    if not zone then return end

    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:SetText(zone.name)
    if zone.isBase then
        GameTooltip:AddLine("Left-click: Report " .. GetBaseReportDescriptor(zone), 0.72, 0.66, 0.50)
        GameTooltip:AddLine("Right-click: Call for HELP", 0.72, 0.66, 0.50)
        GameTooltip:AddLine("Shift-click: Report WEAK", 0.72, 0.66, 0.50)
    else
        GameTooltip:AddLine("Right-click for Get OUT", 0.72, 0.66, 0.50)
    end
    GameTooltip:Show()
end

local function ShowZone(zone)
    local contestedState = zone and zone.isBase and contestedBaseStates[zone.id] or nil
    local contestedVisual = contestedState and contestedState.active and contestedBaseVisuals[zone.id] or nil
    local areaOverlay = contestedVisual and contestedVisual.overlay or (zone and highlightTexture or nil)
    if hoveredZone == zone and hoveredAreaOverlay == areaOverlay then
        return
    end

    if hoveredAreaOverlay then hoveredAreaOverlay:SetHoverInteraction(false) end
    if hoveredAreaOverlay == highlightTexture and not highlightTexture:IsFinishingHoverRelease() then
        highlightTexture:Hide()
    end
    hoveredAreaOverlay = nil
    hoveredZone = zone
    GameTooltip:Hide()

    if not zone then
        if not highlightTexture:IsFinishingHoverRelease() then
            highlightTexture:Hide()
        end
        return
    end

    if contestedVisual and contestedVisual.overlay then
        highlightTexture:Hide()
        contestedVisual.overlay:SetHoverInteraction(true)
        contestedVisual.overlay:Show()
        hoveredAreaOverlay = contestedVisual.overlay
    else
        highlightTexture:SetZone(zone)
        highlightTexture:SetHoverInteraction(true)
        highlightTexture:Show()
        hoveredAreaOverlay = highlightTexture
    end

    ShowZoneTooltip(zone)
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
    local highlight = button.nodeHighlight or button:GetHighlightTexture()
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
    if hoveredZone and hoveredZone.id == baseNode.id and hoveredAreaOverlay == highlightTexture then
        highlightTexture:SetZone(hoveredZone)
    end
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

local BASE_NODE_MOUSE_BUFFER = 0.05
local BASE_NODE_VISUAL_LEVEL_OFFSET = 2
local BASE_NODE_HIT_LEVEL_OFFSET = 9

for _, baseNode in ipairs(BASE_NODES) do
    -- Keep the objective artwork under teammate markers so a player standing on a
    -- flag remains visible. Mouse priority is handled by a separate transparent
    -- hit button above the markers, which gives the base callout a 5% buffer on
    -- every side without forcing the base icon itself to render on top.
    local button = CreateFrame("Frame", nil, map)
    button:SetSize(BASE_NODE_SIZE, BASE_NODE_SIZE)
    button:SetPoint(
        "CENTER",
        map,
        "TOPLEFT",
        (baseNode.x / 100) * MAP_WIDTH,
        -(baseNode.y / 100) * MAP_HEIGHT
    )
    button:SetFrameLevel(mapBorder:GetFrameLevel() + BASE_NODE_VISUAL_LEVEL_OFFSET)
    button:EnableMouse(false)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(16, 16)
    button.icon:SetPoint("CENTER")

    button.fallbackLeft = button:CreateTexture(nil, "ARTWORK")
    button.fallbackLeft:SetSize(8, 16)
    button.fallbackLeft:SetPoint("RIGHT", button, "CENTER", 0, 0)

    button.fallbackRight = button:CreateTexture(nil, "ARTWORK")
    button.fallbackRight:SetSize(8, 16)
    button.fallbackRight:SetPoint("LEFT", button, "CENTER", 0, 0)

    -- This is the old Blizzard minimap-node hover artwork, but it now lives on
    -- the low visual layer and is toggled by the invisible priority hit box.
    button.nodeHighlight = button:CreateTexture(nil, "OVERLAY")
    button.nodeHighlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.nodeHighlight:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.nodeHighlight:SetSize(BASE_NODE_SIZE + 10, BASE_NODE_SIZE + 10)
    button.nodeHighlight:SetBlendMode("ADD")
    if button.nodeHighlight.SetDesaturated then
        button.nodeHighlight:SetDesaturated(true)
    end
    button.nodeHighlight:Hide()

    local hitButton = CreateFrame("Button", nil, map)
    local hitSize = BASE_NODE_SIZE * (1 + (BASE_NODE_MOUSE_BUFFER * 2))
    hitButton:SetSize(hitSize, hitSize)
    hitButton:SetPoint("CENTER", button, "CENTER", 0, 0)
    hitButton:SetFrameLevel(mapBorder:GetFrameLevel() + BASE_NODE_HIT_LEVEL_OFFSET)
    hitButton:EnableMouse(true)
    hitButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hitButton.baseNodeVisual = button
    button.hitButton = hitButton

    hitButton:SetScript("OnEnter", function(self)
        hoveredBaseNode = baseNode
        hoveredZone = nil
        ClearABAreaInteraction()
        if button.nodeHighlight then button.nodeHighlight:Show() end
        GameTooltip:Hide()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(baseNode.name)
        GameTooltip:AddLine(baseNode.currentStatus or "Unclaimed", 0.82, 0.82, 0.82)
        GameTooltip:AddLine("Area menu: " .. GetBaseReportDescriptor(ZONE_BY_ID[baseNode.id]), 0.82, 0.82, 0.82)
        GameTooltip:AddLine("Left-click: SPIN", 0.72, 0.66, 0.50)
        GameTooltip:AddLine("Right-click: Call for HELP", 0.72, 0.66, 0.50)
        GameTooltip:AddLine("Shift-click: Report WEAK", 0.72, 0.66, 0.50)
        GameTooltip:Show()
    end)

    hitButton:SetScript("OnLeave", function()
        hoveredBaseNode = nil
        if button.nodeHighlight then button.nodeHighlight:Hide() end
        GameTooltip:Hide()
    end)

    hitButton:SetScript("OnClick", function(_, mouseButton)
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

-- Contested bases reuse the interactive area renderer. Their faction-colored
-- masks keep the WSG-style stripes, rotating segmented border, and anchored
-- shadow active independently of hover; the clocks retain AV's gold countdown
-- border and faction-colored completion pulse.
local ALLIANCE_CONTEST_R, ALLIANCE_CONTEST_G, ALLIANCE_CONTEST_B = 0.12, 0.36, 1.00 -- vivid royal Alliance blue
local HORDE_CONTEST_R, HORDE_CONTEST_G, HORDE_CONTEST_B = 1.00, 0.20, 0.16
-- Keep the five established AB timer centers while sharing AV's compact clock.
local CONTEST_TIMER_SCALE = 1.40
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
        state.animationStart = nil
        state.visualStart = nil
    end
    if visual and visual.overlay then
        if hoveredAreaOverlay == visual.overlay then
            hoveredAreaOverlay = nil
            hoveredZone = nil
        end
        visual.overlay:SetAnimatedActive(false)
        visual.overlay:Hide()
        ZurkMapsCaptureClock.Reset(visual.timerFrame)
        visual.timerFrame:Hide()
    end
    UpdateBaseNodeHighlightColor(BASE_NODE_BY_ID[baseID])
end

local function FinishContestedBase(baseID, completionFaction)
    local state = contestedBaseStates[baseID]
    local visual = contestedBaseVisuals[baseID]
    if state then
        state.active = false
        state.timerExpired = true
        state.expiredFaction = state.faction
        state.endTime = nil
        state.animationStart = GetTime()
        state.visualStart = nil
    end
    if visual and visual.overlay then
        if hoveredAreaOverlay == visual.overlay then
            hoveredAreaOverlay = nil
            hoveredZone = nil
        end
        visual.overlay:SetAnimatedActive(false)
        visual.overlay:Hide()
        ZurkMapsCaptureClock.Complete(visual.timerFrame, completionFaction or (state and state.faction))
        if hoveredContestTimerFrame == visual.timerFrame then
            hoveredContestTimerFrame = nil
            GameTooltip:Hide()
        end
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
    state.animationStart = nil
    state.visualStart = GetTime()
    state.endTime = durationSeconds and (GetTime() + math.max(0, durationSeconds)) or nil
    UpdateBaseNodeHighlightColor(baseNode)

    if faction == "Alliance" then
        visual.overlay:SetAnimatedColor(ALLIANCE_CONTEST_R, ALLIANCE_CONTEST_G, ALLIANCE_CONTEST_B)
    else
        visual.overlay:SetAnimatedColor(HORDE_CONTEST_R, HORDE_CONTEST_G, HORDE_CONTEST_B)
    end
    ZurkMapsCaptureClock.Reset(visual.timerFrame)
    ZurkMapsCaptureClock.SetRemaining(visual.timerFrame, durationSeconds)
    visual.overlay:SetAnimatedActive(true)
    visual.overlay:SetAnimatedPulseAlpha(1)
    visual.overlay:Show()
    visual.timerFrame:Show()
    if hoveredZone and hoveredZone.id == baseNode.id then ShowZone(hoveredZone) end
end

UpdateContestedBaseState = function(baseNode, textureIndex, poiID)
    local faction = GetContestingFaction(baseNode, textureIndex)
    local state = contestedBaseStates[baseNode.id]

    if not faction then
        local offset = (tonumber(textureIndex) or baseNode.neutralTextureIndex) - baseNode.neutralTextureIndex
        local owner = offset == 2 and "Alliance" or (offset == 4 and "Horde" or nil)
        if state and state.active and owner then
            -- A confirmed capture or defense completes the clock immediately.
            FinishContestedBase(baseNode.id, owner)
        elseif state and state.animationStart and owner then
            ZurkMapsCaptureClock.SetBorderColor(contestedBaseVisuals[baseNode.id].timerFrame, owner)
        else
            HideContestedBase(baseNode.id)
        end
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
        animationStart = nil,
        visualStart = nil,
    }

    local visual = {}
    visual.overlay = CreateABHighlight()
    for _, zone in ipairs(ZONES) do
        if zone.id == baseNode.id then
            visual.overlay:SetZone(zone)
            break
        end
    end
    visual.overlay:Hide()

    local timerPosition = CONTEST_TIMER_POSITIONS[baseNode.id] or { x = baseNode.x, y = baseNode.y + 7 }
    visual.timerFrame = ZurkMapsCaptureClock.Create(map, mapBorder:GetFrameLevel() + 6)
    visual.timerFrame:SetScale(CONTEST_TIMER_SCALE)
    -- Anchor offsets use the clock's scale; compensate to keep its map center.
    visual.timerFrame:SetPoint(
        "CENTER",
        map,
        "TOPLEFT",
        (timerPosition.x / 100) * MAP_WIDTH / CONTEST_TIMER_SCALE,
        -(timerPosition.y / 100) * MAP_HEIGHT / CONTEST_TIMER_SCALE
    )
    visual.timerFrame.baseNode = baseNode
    visual.timerFrame:EnableMouse(true)
    visual.timerFrame:RegisterForClicks("LeftButtonUp")

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
        ClearABAreaInteraction()
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

contestAnimationFrame.elapsed = 0
contestAnimationFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + (elapsed or 0)
    local updateClock = self.elapsed >= 0.10
    if updateClock then self.elapsed = self.elapsed % 0.10 end
    local now = GetTime()
    for _, baseNode in ipairs(BASE_NODES) do
        local state = contestedBaseStates[baseNode.id]
        local visual = contestedBaseVisuals[baseNode.id]
        if state and visual then
            visual.overlay:UpdateInteractionAnimation(elapsed)
            if state.animationStart then
                -- Match AV's smooth border pulse and fade at the existing center.
                if ZurkMapsCaptureClock.AnimateCompletion(visual.timerFrame, now - state.animationStart) then
                    state.animationStart = nil
                end
            elseif state.active then
                local rawRemaining = state.endTime and (state.endTime - now) or nil
                if rawRemaining and rawRemaining <= 0 then
                    FinishContestedBase(baseNode.id)
                else
                    -- AB's faction-colored hotspot illumination stays independent
                    -- of the steady white clock digits, just as before.
                    local speed = rawRemaining and rawRemaining <= 5 and 9.0 or 4.5
                    local wave = 0.5 + (0.5 * math.sin(now * speed))
                    if state.faction == "Alliance" then
                        visual.overlay:SetAnimatedPulseAlpha(0.50 + (0.28 * wave))
                    else
                        visual.overlay:SetAnimatedPulseAlpha(0.46 + (0.26 * wave))
                    end
                    visual.overlay:UpdateAnimatedAnimation(now - (state.visualStart or now))
                    if updateClock then
                        ZurkMapsCaptureClock.SetRemaining(visual.timerFrame, rawRemaining)
                    end
                end
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
    if frame.abWinTimer then frame.abWinTimer:EndTest() end
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
    if frame.abWinTimer then frame.abWinTimer:BeginTest() end
    RandomizeABTestPlayers()
    abTestBaseNodeStates = {}
    for _, baseNode in ipairs(BASE_NODES) do
        HideContestedBase(baseNode.id)
    end

    local sweepFaction = nil
    local sweepRoll = math.random()
    if sweepRoll < 0.05 then
        sweepFaction = "Alliance"
    elseif sweepRoll < 0.10 then
        sweepFaction = "Horde"
    end

    for _, baseNode in ipairs(BASE_NODES) do
        local faction = sweepFaction or (math.random(1, 2) == 1 and "Alliance" or "Horde")
        local seconds = math.random(5, 10)
        local stateOffset = faction == "Alliance" and 1 or 3
        local textureIndex = baseNode.neutralTextureIndex + stateOffset
        abTestBaseNodeStates[baseNode.id] = textureIndex
        UpdateBaseNodeButton(baseNode, textureIndex)
        StartContestedBase(baseNode, faction, seconds, "random all-base test", nil)
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
local AB_FRIENDLY_PLAYER_DOT_SIZE = 12.5
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
    getAddonFrame = function() return frame end,
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
            ZurkMapsPlayerBlips.ApplyRankBadge(blip, agent.pvpRankNumber, ZurkMapsABRank.GetRankBadgeSize(), agent.classToken)
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
abTestMovementFrame:SetScript("OnUpdate", function(_, elapsed)
    if not abTestMode then return end
    AdvanceABTestAgents(elapsed)
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

-- Compact two-column command pad. Every numbered callout uses the same 2x4
-- layout: 1+ through 7+, with Safe or Get OUT in the final cell.
local INCOMING_MENU_WIDTH = 82
local INCOMING_OPTION_HEIGHT = 25
local INCOMING_MENU_HEADER_HEIGHT = 14
local INCOMING_MENU_PADDING = 4
local INCOMING_MENU_MAX_OPTIONS = 8
local INCOMING_MENU_POP_SECONDS = 0.09
local INCOMING_BUTTON_STYLE = {
    headerGap = 4,
    columnGap = 1,
    rowGap = 1,
    pressDepth = 2,
    downSeconds = 0.045,
    upSeconds = 0.065,
}
local incomingMenu
local incomingMenuDismiss
local incomingMenuZone = nil
local incomingMenuOptions = {}

local incomingMenuAnchor = CreateFrame("Frame", nil, map)
incomingMenuAnchor:SetSize(1, 1)
incomingMenuAnchor:SetPoint("CENTER", map, "CENTER", 0, 0)

local function CloseIncomingMenu(preserveHoverAtCursor)
    local closingZone = incomingMenuZone
    if incomingMenu then
        incomingMenu.popElapsed = nil
        incomingMenu:SetAlpha(1)
        incomingMenu:Hide()
    end
    if incomingMenuDismiss then
        incomingMenuDismiss:Hide()
    end
    incomingMenuZone = nil

    -- The dismiss frame receives a repeated click on the selected area. Keep
    -- its existing overlay alive instead of hiding it for one update frame and
    -- immediately rebuilding it under the stationary cursor.
    if preserveHoverAtCursor and closingZone then
        local x, y = GetMousePercent()
        if FindZone(x, y) == closingZone then
            if hoveredZone ~= closingZone or not hoveredAreaOverlay then
                ShowZone(closingZone)
            else
                ShowZoneTooltip(closingZone)
            end
            return
        end
    end

    ShowZone(nil)
end

incomingMenuDismiss = CreateFrame("Button", nil, UIParent)
incomingMenuDismiss:SetAllPoints(UIParent)
incomingMenuDismiss:SetFrameStrata("DIALOG")
incomingMenuDismiss:SetFrameLevel(90)
incomingMenuDismiss:EnableMouse(true)
incomingMenuDismiss:RegisterForClicks("AnyUp")
incomingMenuDismiss:SetScript("OnClick", function()
    CloseIncomingMenu(true)
end)
incomingMenuDismiss:Hide()

incomingMenu = CreateFrame(
    "Frame",
    "ZurksABIncomingMenu",
    UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
incomingMenu:SetSize(
    INCOMING_MENU_WIDTH,
    (INCOMING_MENU_PADDING * 2)
        + INCOMING_MENU_HEADER_HEIGHT
        + INCOMING_BUTTON_STYLE.headerGap
        + (INCOMING_OPTION_HEIGHT * 4)
        + (INCOMING_BUTTON_STYLE.rowGap * 3)
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

-- The tooltip background texture has transparency baked into it. Seat an
-- opaque panel beneath it so map details cannot wash out the compact heading.
local incomingMenuOpaqueBackground = incomingMenu:CreateTexture(nil, "BACKGROUND", nil, -1)
incomingMenuOpaqueBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
incomingMenuOpaqueBackground:SetPoint("TOPLEFT", incomingMenu, "TOPLEFT", 4, -4)
incomingMenuOpaqueBackground:SetPoint("BOTTOMRIGHT", incomingMenu, "BOTTOMRIGHT", -4, 4)
incomingMenuOpaqueBackground:SetVertexColor(0.018, 0.014, 0.010, 1)

local incomingMenuHeadingBackground = incomingMenu:CreateTexture(nil, "BACKGROUND", nil, 1)
incomingMenuHeadingBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
incomingMenuHeadingBackground:SetPoint("TOPLEFT", incomingMenu, "TOPLEFT", 5, -5)
incomingMenuHeadingBackground:SetPoint("TOPRIGHT", incomingMenu, "TOPRIGHT", -5, -5)
incomingMenuHeadingBackground:SetHeight(INCOMING_MENU_HEADER_HEIGHT)
incomingMenuHeadingBackground:SetVertexColor(0.07, 0.045, 0.018, 1)

local incomingMenuHeadingDivider = incomingMenu:CreateTexture(nil, "BORDER")
incomingMenuHeadingDivider:SetTexture("Interface\\Buttons\\WHITE8X8")
incomingMenuHeadingDivider:SetPoint("TOPLEFT", incomingMenuHeadingBackground, "BOTTOMLEFT", 0, 0)
incomingMenuHeadingDivider:SetPoint("TOPRIGHT", incomingMenuHeadingBackground, "BOTTOMRIGHT", 0, 0)
incomingMenuHeadingDivider:SetHeight(1)
incomingMenuHeadingDivider:SetVertexColor(0.62, 0.48, 0.24, 0.28)

local incomingMenuHeading = incomingMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
incomingMenuHeading:SetPoint("TOPLEFT", incomingMenu, "TOPLEFT", INCOMING_MENU_PADDING, -INCOMING_MENU_PADDING)
incomingMenuHeading:SetPoint("TOPRIGHT", incomingMenu, "TOPRIGHT", -INCOMING_MENU_PADDING, -INCOMING_MENU_PADDING)
incomingMenuHeading:SetHeight(INCOMING_MENU_HEADER_HEIGHT)
incomingMenuHeading:SetTextColor(1, 0.74, 0.18, 1)
incomingMenuHeading:SetJustifyH("CENTER")
if incomingMenuHeading.SetWordWrap then incomingMenuHeading:SetWordWrap(false) end
if incomingMenuHeading.SetNonSpaceWrap then incomingMenuHeading:SetNonSpaceWrap(false) end
if incomingMenuHeading.SetMaxLines then incomingMenuHeading:SetMaxLines(1) end

local function AnchorIncomingMenu(zone)
    local minX, minY, maxX, maxY = GetABVisualBounds(zone)
    if not minX then return end
    local centerY = (minY + maxY) / 2
    local placeRight = maxX <= 78
    local anchorX = placeRight and maxX or minX

    incomingMenuAnchor:ClearAllPoints()
    incomingMenuAnchor:SetPoint(
        "TOPLEFT",
        map,
        "TOPLEFT",
        (anchorX / 100) * map:GetWidth(),
        -(centerY / 100) * map:GetHeight()
    )

    incomingMenu.baseScale = frame:GetScale()
    incomingMenu:SetScale(incomingMenu.baseScale * 0.94)
    incomingMenu:SetAlpha(1)
    incomingMenu:ClearAllPoints()
    if placeRight then
        incomingMenu:SetPoint("LEFT", incomingMenuAnchor, "RIGHT", 5, 0)
    else
        incomingMenu:SetPoint("RIGHT", incomingMenuAnchor, "LEFT", -5, 0)
    end
end

incomingMenu:SetScript("OnUpdate", function(self, elapsed)
    if not self.popElapsed then return end
    self.popElapsed = self.popElapsed + math.max(0, tonumber(elapsed) or 0)
    local progress = math.min(1, self.popElapsed / INCOMING_MENU_POP_SECONDS)
    local eased = 1 - ((1 - progress) ^ 3)
    self:SetScale((self.baseScale or frame:GetScale()) * (0.94 + (0.06 * eased)))
    if progress >= 1 then
        self.popElapsed = nil
        self:SetScale(self.baseScale or frame:GetScale())
        self:SetAlpha(1)
    end
end)

local function GetIncomingMenuEntries(zone)
    if zone and zone.isBase then
        return { "1+", "2+", "3+", "4+", "5+", "6+", "7+", "Safe" }
    end

    return { "1+", "2+", "3+", "4+", "5+", "6+", "7+", "Get OUT" }
end

local function ConfigureIncomingMenu(zone)
    local entries = GetIncomingMenuEntries(zone)
    local rowCount = 4
    incomingMenu:SetHeight(
        (INCOMING_MENU_PADDING * 2)
        + INCOMING_MENU_HEADER_HEIGHT
        + INCOMING_BUTTON_STYLE.headerGap
        + (INCOMING_OPTION_HEIGHT * rowCount)
        + (INCOMING_BUTTON_STYLE.rowGap * (rowCount - 1))
    )
    if zone and zone.isBase then
        incomingMenuHeading:SetText(IsBaseHeldOrAssaultedByPlayerFaction(zone) and "INCOMING" or "VISIBLE")
    else
        incomingMenuHeading:SetText("VISIBLE")
    end

    for i, option in ipairs(incomingMenuOptions) do
        local optionText = entries[i]
        if optionText then
            option.calloutText = optionText
            option.label:SetText(optionText == "Get OUT" and "OUT" or optionText)
            option.label:SetFontObject(
                (optionText == "Safe" or optionText == "Get OUT") and GameFontNormalSmall or GameFontNormal
            )
            local row = math.floor((i - 1) / 2)
            local column = (i - 1) % 2
            local availableWidth = INCOMING_MENU_WIDTH - (INCOMING_MENU_PADDING * 2)
            local buttonWidth = (availableWidth - INCOMING_BUTTON_STYLE.columnGap) / 2
            local xOffset = INCOMING_MENU_PADDING
                + (column * (buttonWidth + INCOMING_BUTTON_STYLE.columnGap))
            local yOffset = INCOMING_MENU_PADDING
                + INCOMING_MENU_HEADER_HEIGHT
                + INCOMING_BUTTON_STYLE.headerGap
                + (row * (INCOMING_OPTION_HEIGHT + INCOMING_BUTTON_STYLE.rowGap))

            option:ClearAllPoints()
            option:SetPoint("TOPLEFT", incomingMenu, "TOPLEFT", xOffset, -yOffset)
            option:SetSize(buttonWidth, INCOMING_OPTION_HEIGHT)
            option:SetPressDepth(0)
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
    if hoveredZone ~= zone or not hoveredAreaOverlay then ShowZone(zone) end
    GameTooltip:Hide()
    ConfigureIncomingMenu(zone)
    AnchorIncomingMenu(zone)
    incomingMenu.popElapsed = 0
    incomingMenu:Show()
    incomingMenuDismiss:Show()
end

for i = 1, INCOMING_MENU_MAX_OPTIONS do
    local option = CreateFrame("Button", nil, incomingMenu)
    option:SetSize(34, INCOMING_OPTION_HEIGHT)
    option:SetFrameLevel(incomingMenu:GetFrameLevel() + 1)

    option.shadow = option:CreateTexture(nil, "BACKGROUND")
    option.shadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    option.shadow:SetPoint("TOPLEFT", option, "TOPLEFT", 1, -2)
    option.shadow:SetPoint("BOTTOMRIGHT", option, "BOTTOMRIGHT", -1, 0)
    option.shadow:SetVertexColor(0, 0, 0, 0.82)

    option.face = CreateFrame("Button", nil, option, "UIPanelButtonTemplate")
    option.face:SetFrameLevel(option:GetFrameLevel() + 1)
    option.face:EnableMouse(false)
    option.face:SetText("")
    option.label = option.face:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    option.label:SetPoint("CENTER", option.face, "CENTER", 0, 0)
    option.label:SetTextColor(1, 0.84, 0.30, 1)
    local faceHighlight = option.face:GetHighlightTexture()
    if faceHighlight then
        faceHighlight:SetBlendMode("ADD")
        faceHighlight:SetAlpha(0.72)
    end

    function option:SetPressDepth(depth)
        depth = math.max(0, math.min(INCOMING_BUTTON_STYLE.pressDepth, tonumber(depth) or 0))
        self.pressDepth = depth
        self.face:ClearAllPoints()
        self.face:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -depth)
        self.face:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 2 - depth)
        self.face:SetButtonState(depth >= (INCOMING_BUTTON_STYLE.pressDepth * 0.42) and "PUSHED" or "NORMAL")
        self.shadow:SetAlpha(0.82 * (1 - (0.78 * (depth / INCOMING_BUTTON_STYLE.pressDepth))))
    end

    function option:AnimatePressTo(target, duration, onFinished)
        self.pressStart = self.pressDepth or 0
        self.pressTarget = target
        self.pressDuration = math.max(0.001, duration or INCOMING_BUTTON_STYLE.upSeconds)
        self.pressElapsed = 0
        self.pressFinished = onFinished
    end

    option:SetScript("OnUpdate", function(self, elapsed)
        if self.pressElapsed == nil then return end
        self.pressElapsed = self.pressElapsed + math.max(0, tonumber(elapsed) or 0)
        local progress = math.min(1, self.pressElapsed / self.pressDuration)
        local eased = 1 - ((1 - progress) ^ 3)
        self:SetPressDepth(self.pressStart + ((self.pressTarget - self.pressStart) * eased))
        if progress >= 1 then
            self.pressElapsed = nil
            local finished = self.pressFinished
            self.pressFinished = nil
            if finished then finished() end
        end
    end)

    option:SetScript("OnEnter", function(self)
        self.face:LockHighlight()
    end)

    option:SetScript("OnLeave", function(self)
        self.face:UnlockHighlight()
        if self.pressElapsed ~= nil and self.pressTarget == INCOMING_BUTTON_STYLE.pressDepth then
            self:AnimatePressTo(0, INCOMING_BUTTON_STYLE.upSeconds)
        end
    end)

    option:SetScript("OnMouseDown", function(self)
        self:AnimatePressTo(INCOMING_BUTTON_STYLE.pressDepth, INCOMING_BUTTON_STYLE.downSeconds)
    end)

    option:SetScript("OnMouseUp", function(self)
        self:AnimatePressTo(0, INCOMING_BUTTON_STYLE.upSeconds)
    end)

    option:SetScript("OnHide", function(self)
        self.pressElapsed = nil
        self.pressFinished = nil
        self.reportPending = nil
        self:SetPressDepth(0)
        self.face:UnlockHighlight()
    end)

    option:RegisterForClicks("LeftButtonUp")
    option:SetScript("OnClick", function(self)
        if self.reportPending then return end
        local zone = incomingMenuZone
        local selection = self.calloutText
        local message = zone and selection and FormatZoneCallout(zone, selection) or nil
        if not message then
            CloseIncomingMenu()
            return
        end

        -- Chat APIs must run inside the hardware-click handler. The visual
        -- release may finish later, but the protected action cannot.
        self.reportPending = true
        Report(message)
        self:AnimatePressTo(0, INCOMING_BUTTON_STYLE.upSeconds, function()
            CloseIncomingMenu()
        end)
    end)

    incomingMenuOptions[i] = option
end

map:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and hoveredZone and hoveredAreaOverlay and not isMoving and not resizing then
        hoveredAreaOverlay:SetInteractionPressed(true)
    end
end)

map:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and hoveredAreaOverlay then
        hoveredAreaOverlay:SetInteractionPressed(false)
    end

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
    highlightTexture:UpdateInteractionAnimation(elapsed)

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
    if not isMoving and not resizing and not hoveredBaseNode and not hoveredContestTimerFrame
        and not (incomingMenu and incomingMenu:IsShown()) then
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
    if frame.abWinTimer and not abTestMode then
        if inAB then
            frame.abWinTimer:RefreshLive()
        elseif frame.abWinTimer.activated or frame.abWinTimer.testRunning then
            frame.abWinTimer:EndTest()
        end
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
    print("Hotspot menus: 1+ to 7+, plus Safe for bases or Get OUT elsewhere.")
    print("Base nodes: left-click SPIN, right-click HELP, Shift-click weak.")
    print("|cffffff00/ab testcontest ST ally 60|r - Preview one contested hotspot animation/timer.")
    print("|cffffff00/ab test|r - Show moving blips, resolving base captures, and the live AB win-pace timer.")
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
    elseif string.find(msg, "^testcontest") then
        local _, _, arg1, arg2, arg3 = string.find(msg, "^testcontest%s*(%S*)%s*(%S*)%s*(%S*)")
        if arg1 == "off" or arg1 == "clear" then
            ClearContestTestMode()
            UpdateVisibility()
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
