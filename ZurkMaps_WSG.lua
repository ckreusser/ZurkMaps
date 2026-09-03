local addonName = ...
-- Credit: the friendly flag-carrier silhouette glow adapts the WeakAuras /
-- LibCustomGlow visual approach without requiring either addon.

local MAP_WIDTH = 330
local MAP_HEIGHT = 440
local ACTION_HEIGHT = 34
local MOVE_HANDLE_HEIGHT = 18
local MOVE_HANDLE_FONT_SIZE = 10
local TITLE_PLAQUE_WIDTH = 184
local MAP_ALPHA = 0.72
local PANE_TEXT_R, PANE_TEXT_G, PANE_TEXT_B = 0.72, 0.66, 0.50

ZurksWSGCalloutMapDB = ZurksWSGCalloutMapDB or {}
if ZurksWSGCalloutMapDB.showHonorBar == nil then ZurksWSGCalloutMapDB.showHonorBar = true end

local hoveredZone = nil
local isMoving = false
local hoverAccumulator = 0
local moveHandleDragged = false
local wsgTestMode = false
local UpdateWSGTestBlips = nil
local ShowWSGTestBlips = nil
local HideWSGTestBlips = nil
_G.ZurkMapsWSGTestSim = _G.ZurkMapsWSGTestSim or {
    friendlyFCName = "Zugmash",
    friendlyFCClass = "DRUID",
    enemyFCName = "Lightshield",
    enemyFCClass = "WARRIOR",
    fcMapX = 0.515,
    fcMapY = 0.465,
}

local ZONES = {
    { id="ALLY_FLAG_ROOM", name="Alliance Flag Room", message="EFC is at ALLY FLAG ROOM!", points={ {40.800, 10.200}, {48.800, 10.200}, {48.800, 14.200}, {40.800, 14.200} } },
    { id="ALLY_SECOND_FLOOR", name="Alliance Second Floor", message="EFC is at ALLY SECOND FLOOR!", points={ {48.800, 19.000}, {53.400, 19.000}, {53.400, 10.200}, {48.800, 10.200}, {48.800, 14.200}, {40.800, 14.200}, {40.800, 17.200}, {48.800, 17.200} } },
    { id="ALLY_ROOF", name="Alliance Roof", message="EFC is at ALLY ROOF!", points={ {53.400, 10.200}, {56.800, 9.300}, {62.800, 10.000}, {67.800, 12.000}, {69.600, 14.800}, {66.800, 17.400}, {60.200, 17.200}, {53.400, 17.200} } },
    { id="ALLY_TOPSIDE", name="Alliance Topside", message="EFC is at ALLY TOPSIDE!", points={ {27.800, 15.000}, {40.800, 15.000}, {40.800, 17.200}, {48.800, 17.200}, {48.800, 19.000}, {48.800, 21.900}, {27.800, 21.900}, {27.800, 18.200} } },
    { id="ALLY_BANANA", name="Alliance Banana", message="EFC is at ALLY BANANA!", points={ {53.400, 17.200}, {60.200, 17.200}, {66.800, 17.400}, {69.600, 14.800}, {71.200, 21.800}, {67.200, 22.000}, {53.400, 21.900} } },
    { id="ALLY_GRAVEYARD", name="Alliance Graveyard", message="EFC is at ALLY GRAVEYARD!", points={ {27.800, 21.900}, {48.800, 21.900}, {48.800, 29.800}, {45.300, 31.600}, {40.500, 31.900}, {26.400, 31.000}, {25.400, 29.600} } },
    { id="ALLY_RAMP", name="Alliance Ramp", message="EFC is at ALLY RAMP!", points={ {53.400, 21.900}, {67.200, 22.000}, {71.200, 21.800}, {74.000, 22.000}, {74.000, 27.600}, {71.000, 29.600}, {61.200, 29.800}, {57.000, 31.600}, {53.400, 29.800} } },
    { id="ALLY_TUNNEL", name="Alliance Tunnel", message="EFC is at ALLY TUNNEL!", points={ {48.800, 19.000}, {53.400, 19.000}, {53.400, 29.800}, {57.000, 31.600}, {59.000, 33.900}, {59.000, 39.900}, {43.500, 39.900}, {43.500, 33.900}, {45.300, 31.600}, {48.800, 29.800} } },
    { id="ALLY_LEAF_HUT", name="Alliance Leaf Hut", message="EFC is at ALLY LEAF HUT!", points={ {26.400, 31.000}, {40.500, 31.900}, {45.300, 31.600}, {43.500, 33.900}, {43.500, 39.900}, {30.000, 39.900}, {30.000, 36.000} } },
    { id="ALLY_ZERK_HUT", name="Alliance Zerk Hut", message="EFC is at ALLY ZERK HUT!", points={ {57.000, 31.600}, {61.200, 29.800}, {71.000, 29.600}, {73.000, 34.000}, {74.000, 38.800}, {72.000, 40.000}, {59.000, 39.900}, {59.000, 33.900} } },
    { id="MID_WEST", name="Middle West", message="EFC is at MID WEST!", points={ {30.000, 39.900}, {43.500, 39.900}, {43.200, 42.700}, {41.400, 46.700}, {42.000, 49.300}, {43.500, 51.000}, {30.000, 51.000} } },
    { id="MID", name="Middle", message="EFC is at MID!", points={ {43.500, 39.900}, {59.000, 39.900}, {61.000, 42.100}, {62.100, 45.800}, {61.400, 49.300}, {60.000, 52.800}, {45.000, 52.800}, {43.500, 51.000}, {42.000, 49.300}, {41.400, 46.700}, {43.200, 42.700} } },
    { id="MID_EAST", name="Middle East", message="EFC is at MID EAST!", points={ {59.000, 39.900}, {72.000, 40.000}, {74.000, 40.200}, {75.000, 52.800}, {60.000, 52.800}, {61.400, 49.300}, {62.100, 45.800}, {61.000, 42.100} } },
    { id="TREE", name="Tree", message="EFC is at TREE!", points={ {21.600, 49.000}, {30.000, 49.000}, {30.000, 51.000}, {28.000, 52.300}, {28.000, 62.500}, {19.000, 61.000}, {18.000, 55.000} } },
    { id="HORDE_ZERK_HUT", name="Horde Zerk Hut", message="EFC is at HORDE ZERK HUT!", points={ {30.000, 51.000}, {43.500, 51.000}, {45.000, 52.800}, {44.200, 56.200}, {43.700, 61.800}, {28.000, 62.500}, {28.000, 52.300} } },
    { id="HORDE_LEAF_HUT", name="Horde Leaf Hut", message="EFC is at HORDE LEAF HUT!", points={ {60.000, 52.800}, {75.000, 52.800}, {79.500, 56.400}, {79.000, 63.000}, {63.000, 61.800}, {61.700, 56.200} } },
    { id="HORDE_TUNNEL", name="Horde Tunnel", message="EFC is at HORDE TUNNEL!", points={ {45.000, 52.800}, {60.000, 52.800}, {61.700, 56.200}, {63.000, 61.800}, {53.400, 63.200}, {53.400, 73.400}, {48.800, 73.400}, {48.800, 63.200}, {43.700, 61.800}, {44.200, 56.200} } },
    -- The red highlight follows the ramp; the blue-reference hover envelope
    -- adds a forgiving margin, especially around the western ramp approach.
    { id="HORDE_RAMP", name="Horde Ramp", message="EFC is at HORDE RAMP!", drawPolygon=true,
      points={ {22.000, 63.500}, {28.000, 62.500}, {43.700, 61.800}, {48.800, 63.200}, {48.800, 69.000}, {33.000, 69.500}, {30.000, 67.500}, {26.000, 65.500} },
      hoverPoints={ {19.500, 62.800}, {31.000, 61.900}, {44.300, 61.500}, {46.200, 62.300}, {49.200, 62.600}, {49.400, 68.800}, {47.500, 69.400}, {36.700, 69.500}, {33.000, 70.000}, {30.000, 69.700}, {20.400, 66.900}, {18.500, 65.100}, {18.900, 63.600} } },
    { id="HORDE_GRAVEYARD", name="Horde Graveyard", message="EFC is at HORDE GRAVEYARD!", points={ {53.400, 63.200}, {63.000, 61.800}, {79.000, 63.000}, {79.000, 69.000}, {61.000, 69.000}, {53.400, 69.000} } },
    { id="HORDE_BANANA", name="Horde Banana", message="EFC is at HORDE BANANA!", points={ {37.000, 69.000}, {48.800, 69.000}, {48.800, 73.400}, {46.600, 74.800}, {39.200, 75.400}, {37.000, 73.600} } },
    { id="HORDE_SECOND_FLOOR", name="Horde Second Floor", message="EFC is at HORDE SECOND FLOOR!", points={ {48.800, 73.400}, {53.400, 73.400}, {53.400, 75.200}, {61.000, 75.200}, {61.000, 78.200}, {53.400, 78.200}, {53.400, 82.200}, {48.800, 82.200} } },
    { id="HORDE_TOPSIDE", name="Horde Topside", message="EFC is at HORDE TOPSIDE!", points={ {53.400, 69.000}, {79.000, 69.000}, {79.000, 77.800}, {69.200, 78.500}, {61.000, 82.200}, {61.000, 78.200}, {61.000, 75.200}, {53.400, 75.200}, {53.400, 73.400} } },
    { id="HORDE_ROOF", name="Horde Roof", message="EFC is at HORDE ROOF!", points={ {39.200, 75.400}, {46.600, 74.800}, {48.800, 73.400}, {48.800, 82.200}, {45.800, 81.000}, {39.400, 79.800} } },
    { id="HORDE_FLAG_ROOM", name="Horde Flag Room", message="EFC is at HORDE FLAG ROOM!", points={ {53.400, 78.200}, {61.000, 78.200}, {61.000, 82.200}, {53.400, 82.200} } },
}

-- Checked before the parent polygons so Top of Tunnel wins over Tunnel.
local NESTED_ZONES = {
    { id="ALLY_TOP_OF_TUNNEL", name="Alliance Top of Tunnel", message="EFC is at ALLY TOP OF TUNNEL!", cx=51.920, cy=31.550, rx=2.450, ry=1.450 },
    { id="HORDE_TOP_OF_TUNNEL", name="Horde Top of Tunnel", message="EFC is at HORDE TOP OF TUNNEL!", cx=51.910, cy=60.210, rx=2.450, ry=1.450 },
}

local function Report(message)
    if ZurkMapsOptions and ZurkMapsOptions.SendCallout then
        ZurkMapsOptions.SendCallout("WSG", message)
        return
    end

    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "pvp" then
        SendChatMessage(message, "INSTANCE_CHAT")
    else
        SendChatMessage(message, "SAY")
    end
end

local BOX_BORDER_R = 0.84
local BOX_BORDER_G = 0.56
local BOX_BORDER_B = 0.31

local frame = CreateFrame("Frame", "ZurksWSGCalloutMapFrame", UIParent)
-- Start hidden before secure carrier buttons are parented beneath this frame.
-- Once those secure children exist, showing/hiding the parent is protected in combat.
frame:Hide()
frame:SetSize(MAP_WIDTH + 10, MAP_HEIGHT + (ACTION_HEIGHT * 2) + MOVE_HANDLE_HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetClampedToScreen(true)
frame:SetMovable(true)

local map = CreateFrame("Frame", nil, frame)
-- Fill to the visible rim (3 units inside the tooltip-border frame). Expand
-- the coordinate surface with the artwork so hotspots and blips stay aligned.
map:SetSize(MAP_WIDTH + 4, MAP_HEIGHT + 4)
map:SetPoint("BOTTOM", frame, "BOTTOM", 0, ACTION_HEIGHT - 2)
map:EnableMouse(true)
map:RegisterForDrag("LeftButton")

local mapTexture = map:CreateTexture(nil, "BACKGROUND")
mapTexture:SetAllPoints()
mapTexture:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\WSGMap")
mapTexture:SetAlpha(MAP_ALPHA)


-- Border around the MAP ONLY. CAP/PICK remain outside the border.
local mapBorder = CreateFrame(
    "Frame",
    nil,
    map,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
mapBorder:SetPoint("TOPLEFT", map, "TOPLEFT", -3, 3)
mapBorder:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 3, -3)

if mapBorder.SetBackdrop then
    mapBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
    })
    mapBorder:SetBackdropBorderColor(BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B, 1)
end

mapBorder:EnableMouse(false)
mapBorder:SetFrameLevel(map:GetFrameLevel() + 10)

-- Hard clipping keeps the artwork opaque up to the rim at 100% opacity.
-- The shared opacity setting still controls transparency for the whole map.
map.interiorMask = ZurkMapsInteriorMask.Create(map, mapBorder, 3, 4, true)
ZurkMapsInteriorMask.Apply(map.interiorMask, mapTexture)

if ZurkMapsWSGHonor and ZurkMapsWSGHonor.Create then
    local wsgHonorBar = ZurkMapsWSGHonor.Create(frame, frame, frame:GetHeight(), {
        battlegroundName = "Warsong Gulch",
        db = ZurksWSGCalloutMapDB,
        mapKey = "WSG",
        runLabelSingular = "WSG",
        runLabelPlural = "WSGs",
        getAverageHonor = function(limit)
            if ZurkMapsBGHistory and ZurkMapsBGHistory.GetAverageHonor then
                return ZurkMapsBGHistory.GetAverageHonor("Warsong Gulch", limit)
            end
            return nil, 0
        end,
        sendBGCallout = function(message) Report(message) end,
    })

    if wsgHonorBar then
        -- Top: stop at the top edge of the FC pane; do not climb into the
        -- Zurk Maps title plaque. Bottom: finish exactly with the CAP/PICK row
        -- so the Honor Bar and map assembly share one continuous baseline.
        wsgHonorBar:ClearAllPoints()
        wsgHonorBar:SetPoint("TOPRIGHT", frame, "TOPLEFT", 1, -MOVE_HANDLE_HEIGHT)
        wsgHonorBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 1, 0)
        if ZurkMapsHonorWidget and ZurkMapsHonorWidget.Attach then
            ZurkMapsHonorWidget.Attach(wsgHonorBar, ZurkMapsWSGHonor, { mapKey = "WSG", mapFrame = frame })
        end
    end
end

frame.GetWSGHonorBarMode = function()
    return ZurkMapsHonorWidget and ZurkMapsHonorWidget.GetMode and ZurkMapsHonorWidget.GetMode() or "ATTACHED"
end

frame.IsWSGHonorBarVisible = function()
    return frame.GetWSGHonorBarMode() ~= "OFF"
end

frame.ApplyWSGHonorBarVisibility = function()
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMapShown then
        ZurkMapsHonorWidget.SetMapShown("WSG", frame:IsShown())
    elseif ZurkMapsWSGHonor and ZurkMapsWSGHonor.SetVisible then
        ZurkMapsWSGHonor.SetVisible(frame.IsWSGHonorBarVisible())
    end
end

frame.SetWSGHonorBarVisible = function(flag)
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMode then
        if flag then
            if ZurkMapsHonorWidget.GetMode() == "OFF" then ZurkMapsHonorWidget.SetMode("ATTACHED", "WSG") end
        else
            ZurkMapsHonorWidget.SetMode("OFF", "WSG")
        end
    end
end

frame.IsWSGHonorBarUnlocked = function()
    return ZurkMapsHonorWidget and ZurkMapsHonorWidget.IsUnlocked and ZurkMapsHonorWidget.IsUnlocked() or false
end

frame.SetWSGHonorBarUnlocked = function(flag)
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetGlobalUnlocked then ZurkMapsHonorWidget.SetGlobalUnlocked(flag) end
end

-- Scale-resize state. Resizing the parent frame scales the map, hotspot geometry,
-- border, CAP/PICK buttons, and their text together while preserving proportions.
local resizing = false
local resizeState

local MIN_SCALE = 0.55
local MAX_SCALE = 2.00

-- Forward declaration: the resize OnUpdate callback is created before
-- the move-handle block where this function is assigned.
local UpdateMoveHandleScale
local ConfigureFriendlyPlayerDots

local function SaveLayout()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then
        ZurksWSGCalloutMapDB.point = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
    ZurksWSGCalloutMapDB.scale = frame:GetScale()
end

local function RestoreLayout()
    local savedScale = tonumber(ZurksWSGCalloutMapDB.scale) or 1
    savedScale = math.max(MIN_SCALE, math.min(MAX_SCALE, savedScale))
    frame:SetScale(savedScale)

    local p = ZurksWSGCalloutMapDB.point
    if p and p.point and p.relativePoint and p.x and p.y then
        frame:ClearAllPoints()
        frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    end

    if UpdateMoveHandleScale then
        UpdateMoveHandleScale(savedScale)
    end
    if ConfigureFriendlyPlayerDots then
        ConfigureFriendlyPlayerDots()
    end
end

local function BeginResize()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    resizing = true
    resizeState = ZurkMapsMapResize.Begin(frame, mapBorder)
    GameTooltip:Hide()
end

local function EndResize()
    if resizing then
        resizing = false
        resizeState = nil
        SaveLayout()
        if ConfigureFriendlyPlayerDots then
            ConfigureFriendlyPlayerDots()
        end
    end
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

-- There is only one visible hotspot texture at a time.
-- With no mouseover, this texture is hidden, so there are no visible
-- boundaries, hotspot fills, or map labels.
local highlightTexture = CreateFrame("Frame", nil, map)
highlightTexture:SetAllPoints()
highlightTexture:SetFrameLevel(map:GetFrameLevel())
highlightTexture:EnableMouse(false)
highlightTexture.texture = highlightTexture:CreateTexture(nil, "ARTWORK")
highlightTexture.texture:SetAllPoints()
highlightTexture.fills = {}
highlightTexture.edges = {}

-- Render the edited ramp directly from its polygon so the visual boundary and
-- source geometry cannot diverge from a stale, pre-rendered highlight mask.
function highlightTexture:SetZone(zone)
    self.zone = zone
    for _, fill in ipairs(self.fills) do fill:Hide() end
    for _, edge in ipairs(self.edges) do edge:Hide() end
    if not zone.drawPolygon then
        self.texture:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\Highlights\\" .. zone.id)
        self.texture:Show()
        return
    end
    self.texture:Hide()
    local width, height = self:GetWidth(), self:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then return end
    local points, minY, maxY = zone.points, 100, 0
    for _, point in ipairs(points) do
        minY, maxY = math.min(minY, point[2]), math.max(maxY, point[2])
    end
    local rowHeight, used = 0.5, 0
    local firstY, lastY = minY * height / 100, maxY * height / 100
    for rowY = firstY, lastY - 0.001, rowHeight do
        local h = math.min(rowHeight, lastY - rowY)
        local sampleY = (rowY + h / 2) * 100 / height
        local crossings = {}
        local previous = points[#points]
        for _, point in ipairs(points) do
            if (point[2] > sampleY) ~= (previous[2] > sampleY) then
                crossings[#crossings + 1] = point[1] + ((sampleY - point[2]) * (previous[1] - point[1]) / (previous[2] - point[2]))
            end
            previous = point
        end
        table.sort(crossings)
        for index = 1, #crossings - 1, 2 do
            used = used + 1
            local fill = self.fills[used]
            if not fill then
                fill = self:CreateTexture(nil, "ARTWORK")
                fill:SetColorTexture(245 / 255, 65 / 255, 65 / 255, 72 / 255)
                if fill.SetSnapToPixelGrid then fill:SetSnapToPixelGrid(false) end
                if fill.SetTexelSnappingBias then fill:SetTexelSnappingBias(0) end
                self.fills[used] = fill
            end
            fill:ClearAllPoints()
            fill:SetPoint("TOPLEFT", self, "TOPLEFT", crossings[index] * width / 100, -rowY)
            fill:SetSize((crossings[index + 1] - crossings[index]) * width / 100, h)
            fill:Show()
        end
    end
    for index, point in ipairs(points) do
        local nextPoint = points[(index % #points) + 1]
        local edge = self.edges[index]
        if not edge then
            edge = self:CreateLine(nil, "OVERLAY")
            edge:SetColorTexture(1, 105 / 255, 105 / 255, 235 / 255)
            self.edges[index] = edge
        end
        -- Other region masks have a four-pixel outline on a 512x512 source,
        -- stretched to this portrait map. Match that weight in each direction
        -- instead of using a thinner, fixed-width runtime line.
        local dx, dy = nextPoint[1] - point[1], nextPoint[2] - point[2]
        local sourceLength = math.sqrt(dx * dx + dy * dy)
        local displayLength = math.sqrt((dx * width) ^ 2 + (dy * height) ^ 2)
        if displayLength > 0 then
            edge:SetThickness(4 * width * height * sourceLength / (512 * displayLength))
        end
        edge:SetStartPoint("TOPLEFT", self, point[1] * width / 100, -point[2] * height / 100)
        edge:SetEndPoint("TOPLEFT", self, nextPoint[1] * width / 100, -nextPoint[2] * height / 100)
        edge:Show()
    end
end
highlightTexture:SetScript("OnSizeChanged", function(self)
    if self.zone and self.zone.drawPolygon then self:SetZone(self.zone) end
end)
highlightTexture:Hide()

local function StartMove()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if IsAltKeyDown() then
        isMoving = true
        GameTooltip:Hide()
        highlightTexture:Hide()
        frame:StartMoving()
    end
end

local function StartHandleMove()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    moveHandleDragged = true
    isMoving = true
    GameTooltip:Hide()
    highlightTexture:Hide()
    frame:StartMoving()
end

local function StopMove()
    if isMoving then
        frame:StopMovingOrSizing()
        isMoving = false
        SaveLayout()
    end
end

map:SetScript("OnDragStart", StartMove)
map:SetScript("OnDragStop", StopMove)

local ROW_WIDTH = MAP_WIDTH + 10
local HALF_ACTION_WIDTH = ROW_WIDTH / 2

-- One shared container joins CAP/PICK to the map border without stacking a
-- second tooltip border around each already-framed GameMenuButton.
frame.actionRow = CreateFrame(
    "Frame",
    nil,
    frame,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
frame.actionRow:SetSize(ROW_WIDTH, ACTION_HEIGHT)
-- The tooltip border frame extends five pixels below the map artwork. Pull the
-- action row through that transparent padding so the two visible edges touch.
frame.actionRow:SetPoint("TOP", mapBorder, "BOTTOM", 0, 5)
frame.actionRow:SetFrameLevel(mapBorder:GetFrameLevel() + 1)
frame.actionRow:EnableMouse(false)
if frame.actionRow.SetBackdrop then
    frame.actionRow:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame.actionRow:SetBackdropColor(0.035, 0.022, 0.014, 0.94)
    frame.actionRow:SetBackdropBorderColor(BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B, 0.98)
end

local allianceFlagCarrier = nil
local hordeFlagCarrier = nil
local pendingTargetAttributeUpdate = false
local friendlyTargetButton
local enemyTargetButton
local UpdateCarrierFrameVisuals
local carrierClassCache = {}
local enemyLastHealthPercent = nil

-- Automatic EFC health callouts are threshold-driven rather than timer-driven.
-- A meaningful heal re-arms lower thresholds with a small hysteresis margin,
-- while a five-second refresh barrier keeps recovery updates from becoming spammy.
local EFC_AUTO_THRESHOLDS = { 40, 20, 10 }
local EFC_AUTO_REARM_MARGIN = 5
local EFC_AUTO_REFRESH_COOLDOWN = 5
local efcLastHealthCalloutTime = 0
local efcAutoHealthState = {
    carrierName = nil,
    previousPct = nil,
    pendingRefresh = false,
    lastCallThreshold = nil,
    armed = {},
}

local function GetEFCHealthBandThreshold(pct)
    if not pct then return nil end
    if pct <= 10 then return 10 end
    if pct <= 20 then return 20 end
    if pct <= 40 then return 40 end
    return nil
end

local function ResetEFCAutoHealthState(carrierName)
    efcAutoHealthState.carrierName = carrierName
    efcAutoHealthState.previousPct = nil
    efcAutoHealthState.pendingRefresh = false
    efcAutoHealthState.lastCallThreshold = nil
    efcAutoHealthState.armed = {}
    efcLastHealthCalloutTime = 0
    for _, threshold in ipairs(EFC_AUTO_THRESHOLDS) do
        efcAutoHealthState.armed[threshold] = true
    end
end

local function RecordEFCHealthCallout(pct, threshold)
    efcLastHealthCalloutTime = GetTime and GetTime() or 0
    efcAutoHealthState.lastCallThreshold = threshold or GetEFCHealthBandThreshold(pct)
    if not pct then return end

    -- A manual or automatic report at the current health also consumes any
    -- threshold the EFC is already below, preventing an immediate duplicate.
    for _, consumedThreshold in ipairs(EFC_AUTO_THRESHOLDS) do
        if pct <= consumedThreshold then
            efcAutoHealthState.armed[consumedThreshold] = false
        end
    end
end

local function SendEFCHealthCallout(pct, threshold)
    if not pct then return end
    Report(">>> EFC " .. pct .. "%! <<<")
    RecordEFCHealthCallout(pct, threshold)
end

local function UpdateEFCAutoHealthCallouts(carrierName, pct)
    -- Only call this with a live, currently resolved EFC unit. Cached health is
    -- intentionally display/manual-report data only and can be stale.
    if not carrierName or not pct or pct <= 0 then return end

    if efcAutoHealthState.carrierName ~= carrierName then
        ResetEFCAutoHealthState(carrierName)
    end

    local previousPct = efcAutoHealthState.previousPct
    local crossedThreshold = nil

    -- Healing at least five points beyond a threshold re-arms it. Re-arming a
    -- 20% or 10% threshold while the EFC is still <=40% also queues one recovery
    -- refresh, but that refresh respects the five-second anti-spam barrier.
    for _, threshold in ipairs(EFC_AUTO_THRESHOLDS) do
        if not efcAutoHealthState.armed[threshold]
            and pct >= threshold + EFC_AUTO_REARM_MARGIN then
            efcAutoHealthState.armed[threshold] = true
            if threshold < 40 and pct <= 40 then
                efcAutoHealthState.pendingRefresh = true
            end
        end
    end

    -- Detect downward crossings. A genuinely lower danger threshold (40 -> 20
    -- -> 10) is urgent and may report inside five seconds. Re-crossing the same
    -- threshold after a heal is held behind the normal anti-spam barrier.
    for _, threshold in ipairs(EFC_AUTO_THRESHOLDS) do
        if efcAutoHealthState.armed[threshold]
            and pct <= threshold
            and (previousPct == nil or previousPct > threshold) then
            crossedThreshold = threshold
        end
    end

    if crossedThreshold then
        local now = GetTime and GetTime() or 0
        local lastThreshold = efcAutoHealthState.lastCallThreshold
        local isMoreUrgent = lastThreshold == nil or crossedThreshold < lastThreshold
        local cooldownReady = now - efcLastHealthCalloutTime >= EFC_AUTO_REFRESH_COOLDOWN

        if isMoreUrgent or cooldownReady then
            SendEFCHealthCallout(pct, crossedThreshold)
            efcAutoHealthState.pendingRefresh = false
        else
            efcAutoHealthState.pendingRefresh = true
        end
    elseif efcAutoHealthState.pendingRefresh and pct <= 40 then
        local now = GetTime and GetTime() or 0
        if now - efcLastHealthCalloutTime >= EFC_AUTO_REFRESH_COOLDOWN then
            SendEFCHealthCallout(pct, GetEFCHealthBandThreshold(pct))
            efcAutoHealthState.pendingRefresh = false
        end
    elseif pct > 40 then
        efcAutoHealthState.pendingRefresh = false
    end

    efcAutoHealthState.previousPct = pct
end

local function GetCarrierAssignments()
    local faction = UnitFactionGroup("player")

    if faction == "Horde" then
        return hordeFlagCarrier, allianceFlagCarrier
    end

    -- Alliance is also the safe default if faction data is temporarily unavailable.
    return allianceFlagCarrier, hordeFlagCarrier
end

local function CarrierNameMatches(unit, carrierName)
    if not unit or not carrierName or not UnitExists(unit) then
        return false
    end

    local unitName = (GetUnitName and GetUnitName(unit, true)) or UnitName(unit)
    local shortUnit = unitName and ((Ambiguate and Ambiguate(unitName, "short")) or unitName:match("^[^-]+"))
    local shortCarrier = (Ambiguate and Ambiguate(carrierName, "short")) or carrierName:match("^[^-]+")

    return unitName == carrierName or (shortUnit and shortCarrier and shortUnit == shortCarrier)
end

local function FindFriendlyCarrierUnit(carrierName)
    if not carrierName then return nil end

    local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        for i = 1, groupSize do
            local unit = "raid" .. i
            if CarrierNameMatches(unit, carrierName) then
                return unit
            end
        end
    else
        if CarrierNameMatches("player", carrierName) then
            return "player"
        end
        for i = 1, math.max(0, groupSize - 1) do
            local unit = "party" .. i
            if CarrierNameMatches(unit, carrierName) then
                return unit
            end
        end
    end

    return nil
end

local function FindEnemyCarrierUnit(carrierName)
    if not carrierName then return nil end

    -- Enemy players do not get a persistent public unit token in battlegrounds.
    -- We can still resolve the EFC while the player, a raid member, or a visible
    -- nameplate currently has that carrier represented by a valid unit token.
    local direct = { "target", "mouseover", "focus" }
    for _, unit in ipairs(direct) do
        if CarrierNameMatches(unit, carrierName) then
            return unit
        end
    end

    local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        for i = 1, groupSize do
            local unit = "raid" .. i .. "target"
            if CarrierNameMatches(unit, carrierName) then
                return unit
            end
        end
    else
        for i = 1, math.max(0, groupSize - 1) do
            local unit = "party" .. i .. "target"
            if CarrierNameMatches(unit, carrierName) then
                return unit
            end
        end
    end

    -- Classic Era supports nameplate unit tokens on current clients. If a
    -- particular client does not, UnitExists() simply returns false here.
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if CarrierNameMatches(unit, carrierName) then
            return unit
        end
    end

    return nil
end

local function GetCarrierClassToken(carrierName, unit)
    if not carrierName then return nil end

    if unit and UnitExists(unit) then
        local _, classToken = UnitClass(unit)
        if classToken then
            carrierClassCache[carrierName] = classToken
            return classToken
        end
    end

    if carrierClassCache[carrierName] then
        return carrierClassCache[carrierName]
    end

    if type(GetNumBattlefieldScores) == "function" and type(GetBattlefieldScore) == "function" then
        local shortCarrier = (Ambiguate and Ambiguate(carrierName, "short")) or carrierName:match("^[^-]+")
        local count = GetNumBattlefieldScores() or 0
        for i = 1, count do
            local scoreName, _, _, _, _, _, _, _, classToken = GetBattlefieldScore(i)
            if scoreName then
                local shortScore = (Ambiguate and Ambiguate(scoreName, "short")) or scoreName:match("^[^-]+")
                if scoreName == carrierName or (shortCarrier and shortScore == shortCarrier) then
                    if classToken then
                        carrierClassCache[carrierName] = classToken
                    end
                    return classToken
                end
            end
        end
    end

    return nil
end

local function GetClassColor(classToken)
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if color then
        return color.r, color.g, color.b
    end
    return 0.95, 0.82, 0.52
end

local function GetUnitHealthPercent(unit)
    if not unit or not UnitExists(unit) then return nil end
    local maxHealth = UnitHealthMax(unit)
    if not maxHealth or maxHealth <= 0 then return nil end
    local health = UnitHealth(unit) or 0
    return math.max(0, math.min(100, math.floor((health / maxHealth) * 100 + 0.5)))
end

local function TruncateCarrierDisplayName(name, maxChars)
    if not name then
        return name
    end

    maxChars = maxChars or 10
    if string.len(name) <= maxChars then
        return name
    end

    return string.sub(name, 1, maxChars)
end

local function SetCarrierHealthBarColor(healthBar, pct)
    if not healthBar or not pct then return end

    -- Smooth red -> yellow -> green health gradient.
    -- 1% is red, ~50% is yellow, and 100% is green.
    local clamped = math.max(1, math.min(100, pct))
    local t = (clamped - 1) / 99
    local r, g
    if t < 0.5 then
        r = 1
        g = t * 2
    else
        r = (1 - t) * 2
        g = 1
    end
    healthBar:SetStatusBarColor(r, g, 0, 0.95)
end

local function GetCarrierFlagToken(isFriendly)
    local faction = UnitFactionGroup("player")
    if isFriendly then
        return faction == "Horde" and "AllianceFlag" or "HordeFlag"
    end
    return faction == "Horde" and "HordeFlag" or "AllianceFlag"
end

local function ApplyTargetAttributes()
    if InCombatLockdown and InCombatLockdown() then
        pendingTargetAttributeUpdate = true
        if friendlyTargetButton then friendlyTargetButton.targetReady = false end
        if enemyTargetButton then enemyTargetButton.targetReady = false end
        return
    end

    local friendlyCarrier, enemyCarrier = GetCarrierAssignments()
    local friendlyUnit = FindFriendlyCarrierUnit(friendlyCarrier)

    if friendlyCarrier and friendlyUnit then
        friendlyTargetButton:SetAttribute("type1", "target")
        friendlyTargetButton:SetAttribute("unit", friendlyUnit)
        friendlyTargetButton:SetAttribute("macrotext1", "")
        friendlyTargetButton.targetReady = true
    elseif friendlyCarrier then
        friendlyTargetButton:SetAttribute("type1", "macro")
        friendlyTargetButton:SetAttribute("unit", nil)
        friendlyTargetButton:SetAttribute("macrotext1", "/targetexact " .. friendlyCarrier)
        friendlyTargetButton.targetReady = true
    else
        friendlyTargetButton:SetAttribute("type1", "macro")
        friendlyTargetButton:SetAttribute("unit", nil)
        friendlyTargetButton:SetAttribute("macrotext1", "")
        friendlyTargetButton.targetReady = false
    end

    enemyTargetButton:SetAttribute("type1", "macro")
    enemyTargetButton:SetAttribute("unit", nil)
    enemyTargetButton:SetAttribute("macrotext1", enemyCarrier and ("/targetexact " .. enemyCarrier) or "")
    enemyTargetButton:SetAttribute(
        "shift-macrotext1",
        enemyCarrier
            and ("/targetexact " .. enemyCarrier .. "\n/run ZurksWSGCalloutMap_ShiftFCReport(\"enemy\")")
            or '/run ZurksWSGCalloutMap_ShiftFCReport("enemy")'
    )
    enemyTargetButton.targetReady = enemyCarrier ~= nil

    pendingTargetAttributeUpdate = false
end

local function UpdateTargetButtons()
    local friendlyCarrier, enemyCarrier = GetCarrierAssignments()
    local previousEnemyCarrier = enemyTargetButton and enemyTargetButton.carrierName or nil
    if previousEnemyCarrier ~= enemyCarrier then
        enemyLastHealthPercent = nil
        ResetEFCAutoHealthState(enemyCarrier)
    end
    friendlyTargetButton.carrierName = friendlyCarrier
    enemyTargetButton.carrierName = enemyCarrier

    if type(RequestBattlefieldScoreData) == "function" and (friendlyCarrier or enemyCarrier) then
        pcall(RequestBattlefieldScoreData)
    end

    ApplyTargetAttributes()
    if UpdateCarrierFrameVisuals then
        UpdateCarrierFrameVisuals(true)
    end
end

local carrierRow
local CARRIER_ROW_INSET = 1
local CARRIER_ROW_SEPARATOR_WIDTH = 2
local CARRIER_FRAME_WIDTH = math.floor((ROW_WIDTH - (CARRIER_ROW_INSET * 2) - CARRIER_ROW_SEPARATOR_WIDTH) / 2)

local function MakeChatButton(text, message, point, relativePoint)
    local button = CreateFrame("Button", nil, frame.actionRow, "GameMenuButtonTemplate")
    button:SetSize(HALF_ACTION_WIDTH - 4, ACTION_HEIGHT - 6)
    if point == "TOPRIGHT" then
        button:SetPoint("LEFT", frame.actionRow, "LEFT", 3, 0)
    else
        button:SetPoint("RIGHT", frame.actionRow, "RIGHT", -3, 0)
    end
    button:SetText(text)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function()
        Report(message)
    end)

    return button
end

local function MakeCarrierFrame(isFriendly, point, relativePoint)
    local button = CreateFrame(
        "Button",
        nil,
        carrierRow or frame,
        "SecureActionButtonTemplate,BackdropTemplate"
    )
    button:SetSize(CARRIER_FRAME_WIDTH, ACTION_HEIGHT - 2)
    if isFriendly then
        button:SetPoint("TOPLEFT", carrierRow, "TOPLEFT", CARRIER_ROW_INSET, -1)
    else
        button:SetPoint("TOPRIGHT", carrierRow, "TOPRIGHT", -CARRIER_ROW_INSET, -1)
    end
    -- Secure carrier actions fire on mouse release only. Registering both press
    -- and release was unnecessary and could leave Shift+Click reporting in a
    -- bad repeated-action state on some clients/input setups.
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", "")
    button:SetAttribute("shift-type1", "macro")
    button:SetAttribute(
        "shift-macrotext1",
        isFriendly
            and '/run ZurksWSGCalloutMap_ShiftFCReport("friendly")'
            or '/run ZurksWSGCalloutMap_ShiftFCReport("enemy")'
    )
    button.isFriendlyCarrierFrame = isFriendly
    button.manualReportClickSerial = 0
    button.lastManualReportClickSerial = 0

    -- Arm one manual report from an actual physical Shift+LeftButton press.
    -- The secure macro consumes this serial exactly once on release, so even if
    -- a client ever re-executes the macro unexpectedly it cannot keep reporting.
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" and IsShiftKeyDown() then
            self.manualReportClickSerial = (self.manualReportClickSerial or 0) + 1
        end
    end)

    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        button:SetBackdropColor(0.035, 0.025, 0.018, 0.02)
        button:SetBackdropBorderColor(0.46, 0.36, 0.20, 0.0)
    end

    local iconFrame = CreateFrame("Frame", nil, button)
    iconFrame:SetSize(29, 29)
    iconFrame:SetPoint(isFriendly and "LEFT" or "RIGHT", button, isFriendly and "LEFT" or "RIGHT", isFriendly and 3 or -3, 0)
    iconFrame:SetFrameLevel(button:GetFrameLevel() + 2)
    if iconFrame.SetClipsChildren then iconFrame:SetClipsChildren(true) end

    local flagToken = GetCarrierFlagToken(isFriendly)
    local glow = CreateFrame("Frame", nil, button)
    glow:SetAllPoints(iconFrame)
    glow:SetFrameLevel(button:GetFrameLevel() + 1)
    glow:EnableMouse(false)
    if glow.SetClipsChildren then glow:SetClipsChildren(true) end
    if isFriendly then
        glow.elapsed = 0
        glow.rearStar = glow:CreateTexture(nil, "ARTWORK", nil, -2)
        glow.rearStar:SetPoint("CENTER")
        glow.rearStar:SetTexture("Interface\\Cooldown\\star4")
        glow.rearStar:SetBlendMode("ADD")
        glow.rearStar:SetVertexColor(1.00, 0.78, 0.08, 1)
        glow.innerStar = glow:CreateTexture(nil, "ARTWORK", nil, -1)
        glow.innerStar:SetPoint("CENTER")
        glow.innerStar:SetTexture("Interface\\Cooldown\\star4")
        glow.innerStar:SetBlendMode("ADD")
        glow.innerStar:SetVertexColor(1.00, 1.00, 0.68, 1)
        glow:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            local rearPulse = 0.5 + (0.5 * math.sin(self.elapsed * 4.2))
            local innerPulse = 0.5 + (0.5 * math.sin((self.elapsed * 4.2) + (math.pi * 0.72)))
            self.rearStar:SetSize(32 + (4 * rearPulse), 32 + (4 * rearPulse))
            self.rearStar:SetAlpha(0.34 + (0.20 * rearPulse))
            self.innerStar:SetSize(28 + (3 * innerPulse), 28 + (3 * innerPulse))
            self.innerStar:SetAlpha(0.28 + (0.16 * innerPulse))
            if self.rearStar.SetRotation then self.rearStar:SetRotation(self.elapsed * 0.75) end
            if self.innerStar.SetRotation then self.innerStar:SetRotation(self.elapsed * -1.05) end
        end)
    else
        glow.fill = glow:CreateTexture(nil, "BACKGROUND")
        glow.fill:SetAllPoints()
        if flagToken == "AllianceFlag" then
            glow.fill:SetColorTexture(0.18, 0.55, 1.0, 0.05)
        else
            glow.fill:SetColorTexture(1.0, 0.16, 0.10, 0.05)
        end
        glow.flameElapsed = 0
        glow.flameFrame = -1
        glow.flame = glow:CreateTexture(nil, "ARTWORK", nil, -1)
        glow.flame:SetPoint("CENTER", glow, "CENTER", -1, -1)
        glow.flame:SetSize(36, 40)
        glow.flame:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\AV_TowerFire")
        glow.flame:SetTexCoord(1 / 1024, (1 / 8) - (1 / 1024), 0, 1)
        glow.flame:SetBlendMode("ADD")
        glow.flame:SetAlpha(0.32)
        if glow.CreateMaskTexture and glow.flame.AddMaskTexture then
            -- A dim, slightly larger copy feathers the silhouette beyond the
            -- primary mask. Layering it behind the flame softens the visible
            -- lower cup without widening the bright core.
            glow.flameSoft = glow:CreateTexture(nil, "ARTWORK", nil, -2)
            glow.flameSoft:SetPoint("CENTER", glow, "CENTER", -1, -1)
            glow.flameSoft:SetSize(40, 44)
            glow.flameSoft:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\AV_TowerFire")
            glow.flameSoft:SetTexCoord(1 / 1024, (1 / 8) - (1 / 1024), 0, 1)
            glow.flameSoft:SetBlendMode("ADD")
            glow.flameSoft:SetAlpha(0.08)
            glow.flameSoftMask = glow:CreateMaskTexture(nil, "ARTWORK", nil, -1)
            glow.flameSoftMask:SetPoint("CENTER", glow, "CENTER", -1, 1)
            glow.flameSoftMask:SetSize(27, 33)
            glow.flameSoftMask:SetTexture(
                "Interface\\CharacterFrame\\TempPortraitAlphaMaskSmall",
                "CLAMPTOBLACKADDITIVE",
                "CLAMPTOBLACKADDITIVE"
            )
            glow.flameSoft:AddMaskTexture(glow.flameSoftMask)

            glow.flameMask = glow:CreateMaskTexture(nil, "ARTWORK", nil, 0)
            -- A tall portrait mask pinches the wide lower flame inward. This
            -- reads as a compact vase silhouette instead of a flat bowl while
            -- preserving the animated tips above the flag artwork.
            glow.flameMask:SetPoint("CENTER", glow, "CENTER", -1, 1)
            glow.flameMask:SetSize(23, 29)
            glow.flameMask:SetTexture(
                "Interface\\CharacterFrame\\TempPortraitAlphaMaskSmall",
                "CLAMPTOBLACKADDITIVE",
                "CLAMPTOBLACKADDITIVE"
            )
            glow.flame:AddMaskTexture(glow.flameMask)
        end
        glow:SetScript("OnUpdate", function(self, elapsed)
            self.flameElapsed = (self.flameElapsed or 0) + elapsed
            local frameIndex = math.floor(self.flameElapsed / 0.12) % 8
            if frameIndex ~= self.flameFrame then
                self.flameFrame = frameIndex
                local left = (frameIndex / 8) + (1 / 1024)
                self.flame:SetTexCoord(left, ((frameIndex + 1) / 8) - (1 / 1024), 0, 1)
                if self.flameSoft then
                    self.flameSoft:SetTexCoord(left, ((frameIndex + 1) / 8) - (1 / 1024), 0, 1)
                end
            end
            local breath = 0.5 + (0.5 * math.sin(self.flameElapsed * 4.0))
            local width = 36 + (3 * breath)
            local height = 40 + (4 * breath)
            self.flame:SetSize(width, height)
            self.flame:SetAlpha(0.24 + (0.12 * breath))
            if self.flameSoft then
                self.flameSoft:SetSize(width + 4, height + 4)
                self.flameSoft:SetAlpha(0.045 + (0.05 * breath))
            end
        end)
    end
    glow:Hide()

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\WorldStateFrame\\" .. flagToken)
    icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    icon:SetAlpha(0.38)

    local innerLeft = isFriendly and 36 or 5
    local innerRight = isFriendly and -5 or -36

    local healthBar = CreateFrame("StatusBar", nil, button)
    healthBar:SetPoint("TOPLEFT", button, "TOPLEFT", innerLeft, -4)
    healthBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", innerRight, 4)
    healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    healthBar:SetStatusBarColor(0.12, 0.78, 0.18, 0.95)
    healthBar:SetMinMaxValues(0, 100)
    healthBar:SetValue(0)

    local healthBG = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBG:SetAllPoints()
    healthBG:SetColorTexture(0.02, 0.02, 0.02, 0.90)

    local healthOverlay = healthBar:CreateTexture(nil, "OVERLAY")
    healthOverlay:SetAllPoints()
    healthOverlay:SetColorTexture(1, 1, 1, 0.03)

    local nameText = healthBar:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    if isFriendly then
        nameText:SetPoint("LEFT", healthBar, "LEFT", 5, 0)
    else
        nameText:SetPoint("RIGHT", healthBar, "RIGHT", -5, 0)
    end
    nameText:SetJustifyH(isFriendly and "LEFT" or "RIGHT")
    if nameText.SetWordWrap then
        nameText:SetWordWrap(false)
    end
    if nameText.SetMaxLines then
        nameText:SetMaxLines(1)
    end
    nameText:SetText(isFriendly and "Friendly FC" or "Enemy FC")
    nameText:SetTextColor(PANE_TEXT_R, PANE_TEXT_G, PANE_TEXT_B, 1)

    local healthText = healthBar:CreateFontString(nil, "OVERLAY")
    if isFriendly then
        healthText:SetPoint("RIGHT", healthBar, "RIGHT", -6, 0)
    else
        healthText:SetPoint("LEFT", healthBar, "LEFT", 6, 0)
    end
    healthText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    healthText:SetTextColor(1, 1, 1, 1)
    healthText:SetJustifyH(isFriendly and "RIGHT" or "LEFT")
    healthText:SetText("--")

    button.flagIcon = icon
    button.flagGlow = glow
    button.nameText = nameText
    button.healthBar = healthBar
    button.healthText = healthText
    button.resolvedUnit = nil
    button.lastHealthPercent = nil

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        if GameTooltip_SetDefaultAnchor then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        else
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
        end

        if self.resolvedUnit and UnitExists(self.resolvedUnit) and CarrierNameMatches(self.resolvedUnit, self.carrierName) then
            GameTooltip:SetUnit(self.resolvedUnit)
        elseif self.carrierName then
            local classToken = GetCarrierClassToken(self.carrierName, self.resolvedUnit)
            local r, g, b = GetClassColor(classToken)
            GameTooltip:SetText(self.carrierName, r, g, b)
            if classToken then
                local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or classToken
                GameTooltip:AddLine(className, r, g, b)
            end
            if self.lastHealthPercent then
                GameTooltip:AddLine("Health: " .. self.lastHealthPercent .. "%", 0.85, 0.85, 0.85)
            end
        else
            GameTooltip:SetText(self.isFriendlyCarrierFrame and "No friendly flag carrier" or "No enemy flag carrier")
        end

        GameTooltip:AddLine("Left-click to target", 0.72, 0.66, 0.50)
        if self.isFriendlyCarrierFrame then
            GameTooltip:AddLine("Shift+Click reports: HELP our FC!!", 0.95, 0.82, 0.28, true)
        else
            GameTooltip:AddLine("Shift+Click reports: >>> EFC " .. tostring(self.lastHealthPercent or "?") .. "%! <<<", 0.95, 0.82, 0.28, true)
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

-- Compact FC unit frames above the map. Unmodified click targets the carrier;
-- Shift+Click sends the carrier-specific battleground callout.
carrierRow = CreateFrame(
    "Frame",
    nil,
    frame,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
carrierRow:SetSize(ROW_WIDTH, ACTION_HEIGHT)
-- Sit directly on the map border so the FC pane and map read as one assembly.
carrierRow:SetPoint("BOTTOM", map, "TOP", 0, 0)
carrierRow:SetFrameLevel(mapBorder:GetFrameLevel() + 1)
carrierRow:EnableMouse(false)
if carrierRow.SetBackdrop then
    carrierRow:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    carrierRow:SetBackdropColor(0.055, 0.035, 0.018, 0.91)
    carrierRow:SetBackdropBorderColor(BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B, 0.98)
end

local carrierRowSeparator = carrierRow:CreateTexture(nil, "BORDER")
carrierRowSeparator:SetWidth(1)
carrierRowSeparator:SetPoint("TOP", carrierRow, "TOP", 0, -3)
carrierRowSeparator:SetPoint("BOTTOM", carrierRow, "BOTTOM", 0, 3)
carrierRowSeparator:SetColorTexture(BOX_BORDER_R, BOX_BORDER_G, BOX_BORDER_B, 0.35)

local carrierRowSeparatorDark = carrierRow:CreateTexture(nil, "BACKGROUND")
carrierRowSeparatorDark:SetWidth(3)
carrierRowSeparatorDark:SetPoint("TOP", carrierRow, "TOP", 0, -2)
carrierRowSeparatorDark:SetPoint("BOTTOM", carrierRow, "BOTTOM", 0, 2)
carrierRowSeparatorDark:SetColorTexture(0.08, 0.05, 0.02, 0.28)

friendlyTargetButton = MakeCarrierFrame(true, "BOTTOMRIGHT", "TOP")
enemyTargetButton = MakeCarrierFrame(false, "BOTTOMLEFT", "TOP")

UpdateCarrierFrameVisuals = function(force)
    if wsgTestMode then
        local function SetTestCarrier(button, name, classToken, pct)
            local r, g, b = GetClassColor(classToken)
            button.carrierName = name
            button.resolvedUnit = nil
            button.nameText:SetText(name)
            button.nameText:SetTextColor(r, g, b, 1)
            button.flagIcon:SetAlpha(1)
            button.flagGlow:Show()
            button.lastHealthPercent = pct
            button.healthBar:SetValue(pct)
            SetCarrierHealthBarColor(button.healthBar, pct)
            button.healthText:SetText(pct .. "%")
        end

        SetTestCarrier(friendlyTargetButton, ZurkMapsWSGTestSim.friendlyFCName, ZurkMapsWSGTestSim.friendlyFCClass, 78)
        SetTestCarrier(enemyTargetButton, ZurkMapsWSGTestSim.enemyFCName, ZurkMapsWSGTestSim.enemyFCClass, 43)
        enemyLastHealthPercent = 43
        return
    end

    local friendlyCarrier, enemyCarrier = GetCarrierAssignments()
    local friendlyUnit = FindFriendlyCarrierUnit(friendlyCarrier)
    local enemyUnit = FindEnemyCarrierUnit(enemyCarrier)

    local function UpdateOne(button, carrierName, unit, isFriendly)
        button.carrierName = carrierName
        button.resolvedUnit = unit

        if carrierName then
            local classToken = GetCarrierClassToken(carrierName, unit)
            local r, g, b = GetClassColor(classToken)
            local shortName = (Ambiguate and Ambiguate(carrierName, "short")) or carrierName:match("^[^-]+") or carrierName
            shortName = TruncateCarrierDisplayName(shortName, 10)
            button.nameText:SetText(shortName)
            button.nameText:SetTextColor(r, g, b, 1)
            button.flagIcon:SetAlpha(1)
            button.flagGlow:Show()

            local pct = GetUnitHealthPercent(unit)
            if not isFriendly and pct then
                enemyLastHealthPercent = pct
                UpdateEFCAutoHealthCallouts(carrierName, pct)
            end
            if not pct and not isFriendly then
                pct = enemyLastHealthPercent
            end

            button.lastHealthPercent = pct
            if pct then
                button.healthBar:SetValue(pct)
                SetCarrierHealthBarColor(button.healthBar, pct)
                button.healthText:SetText(pct .. "%")
            else
                button.healthBar:SetValue(0)
                button.healthText:SetText("?%")
            end
        else
            button.nameText:SetText(isFriendly and "Friendly FC" or "Enemy FC")
            button.nameText:SetTextColor(PANE_TEXT_R, PANE_TEXT_G, PANE_TEXT_B, 1)
            button.healthBar:SetValue(0)
            button.healthText:SetText("--")
            button.flagIcon:SetAlpha(0.38)
            button.flagGlow:Hide()
            button.resolvedUnit = nil
            button.lastHealthPercent = nil
            if not isFriendly then
                enemyLastHealthPercent = nil
                if efcAutoHealthState.carrierName ~= nil then
                    ResetEFCAutoHealthState(nil)
                end
            end
        end
    end

    UpdateOne(friendlyTargetButton, friendlyCarrier, friendlyUnit, true)
    UpdateOne(enemyTargetButton, enemyCarrier, enemyUnit, false)
end

_G.ZurksWSGCalloutMap_ShiftFCReport = function(which)
    local reportButton = which == "friendly" and friendlyTargetButton or enemyTargetButton
    if reportButton then
        local clickSerial = reportButton.manualReportClickSerial or 0
        if clickSerial == 0 or clickSerial == (reportButton.lastManualReportClickSerial or 0) then
            return
        end
        reportButton.lastManualReportClickSerial = clickSerial
    end

    if which == "friendly" then
        Report("HELP our FC!!")
        return
    end

    local _, enemyCarrier = GetCarrierAssignments()
    local enemyUnit = FindEnemyCarrierUnit(enemyCarrier)
    local pct = GetUnitHealthPercent(enemyUnit) or enemyLastHealthPercent
    if pct then
        SendEFCHealthCallout(pct)
    else
        Report(">>> EFC ?%! <<<")
    end
end

local carrierFrameUpdateElapsed = 0
local carrierFrameUpdater = CreateFrame("Frame", nil, frame)
carrierFrameUpdater:SetScript("OnUpdate", function(self, elapsed)
    carrierFrameUpdateElapsed = carrierFrameUpdateElapsed + elapsed
    if carrierFrameUpdateElapsed < 0.15 then
        return
    end
    carrierFrameUpdateElapsed = 0
    if UpdateCarrierFrameVisuals then
        UpdateCarrierFrameVisuals(false)
    end
end)

-- CAP and PICK share the bottom row.
MakeChatButton("CAP", "CAP the flag NOW!!!", "TOPRIGHT", "BOTTOM")
MakeChatButton("PICK", "PICK the flag ASAP!!!", "TOPLEFT", "BOTTOM")

-- Compact centered title plaque / move handle, tucked into the FC pane trim.
local moveHandle = CreateFrame(
    "Frame",
    nil,
    frame,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
moveHandle:SetSize(TITLE_PLAQUE_WIDTH, MOVE_HANDLE_HEIGHT)
moveHandle:SetPoint("BOTTOM", carrierRow, "TOP", 0, -3)
moveHandle:SetFrameLevel(carrierRow:GetFrameLevel() + 5)
moveHandle:EnableMouse(true)
moveHandle:RegisterForDrag("LeftButton")

-- Build the title plaque as one connected assembly. Store the plaque parts
-- on moveHandle instead of creating many top-level locals; Classic Lua caps the
-- number of locals in a single chunk, and the header work had pushed us over it.
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
moveHandle.trimUnderlap = 0
moveHandle.trimHeight = 8
moveHandle.bgInsetX = 0
moveHandle.bgInsetY = 1

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

-- Endcaps stay above the horizontal trim. Use each atlas at its native aspect
-- ratio so the filigree is never stretched; only its overall scale changes.
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

-- The filigree atlases themselves form the left/right ends of the title box.
-- Do not add separate vertical bars here; the reference frame joins the
-- horizontal trims directly underneath the inner portion of each ornament.

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

    -- First place the filigrees at the intended size and position.
    self.leftTrim:ClearAllPoints()
    self.leftTrim:SetPoint("RIGHT", self.border, "LEFT", filigreeOverlap, 0)
    self.leftTrim:SetSize(filigreeWidth, filigreeHeight)

    self.rightTrim:ClearAllPoints()
    self.rightTrim:SetPoint("LEFT", self.border, "RIGHT", -filigreeOverlap, 0)
    self.rightTrim:SetSize(filigreeWidth, filigreeHeight)

    -- Then fit the top/bottom box pieces underneath the already-placed
    -- filigrees, like the reference. The box sits a touch taller, with a small
    -- inset so its ends disappear under the inner stems of the ornaments.
    local trimInset = math.max(0, filigreeOverlap - (1 * inv))
    self.bg:ClearAllPoints()
    -- Fill the entire center box horizontally. The filigrees sit on top of this
    -- area, so extending the fill to the box edges removes the exposed strips
    -- without allowing the background outside the plaque bounds.
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

UpdateMoveHandleScale = function(addonScale)
    -- Preserve title and border readability below 100% addon scale. The title,
    -- filigrees, trim thickness, overlap, and background inset are all adjusted
    -- as one system so resizing cannot pull the border pieces apart.
    local compensationScale = math.min(addonScale, 1)

    moveHandle:SetWidth(math.min(ROW_WIDTH, TITLE_PLAQUE_WIDTH / compensationScale))
    moveHandle:SetHeight(MOVE_HANDLE_HEIGHT / compensationScale)
    moveHandle.text:SetFont(
        "Fonts\\FRIZQT__.TTF",
        MOVE_HANDLE_FONT_SIZE / compensationScale,
        ""
    )
    moveHandle:UpdateGeometry(compensationScale)
end

-- Initialize geometry at the default scale before the first resize event.
moveHandle:UpdateGeometry(1)

moveHandle:SetScript("OnMouseDown", function()
    moveHandleDragged = false
end)
moveHandle:SetScript("OnDragStart", StartHandleMove)
moveHandle:SetScript("OnDragStop", StopMove)
moveHandle:SetScript("OnMouseUp", function(self, button)
    local didDrag = moveHandleDragged
    StopMove()
    if button == "RightButton" and not didDrag and ZurkMapsOptions then
        ZurkMapsOptions.OpenMapMenu("WSG", self)
        return
    end
    if button == "LeftButton" and IsControlKeyDown() and not didDrag then
        if IsShiftKeyDown() and ZurkMapsPromos then
            ZurkMapsPromos.SendRandomPromo("WSG")
        elseif ZurkMapsPromos then
            local promo = ZurkMapsPromos.GetHeaderPromo("WSG")
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

UpdateMoveHandleScale(frame:GetScale())

-- Calibration from Blizzard battlefield coordinates to the custom Zurk WSG map.
-- Blizzard's native battlefield coordinate space is noticeably narrower on X
-- and taller on Y than the portrait map art used here. These values are based
-- on our live WSG pickup/capture samples and the accepted v8 hotspot geometry.
local BATTLEFIELD_X_SCALE = 2.20
local BATTLEFIELD_X_OFFSET = -0.60
local BATTLEFIELD_Y_SCALE = 0.845
local BATTLEFIELD_Y_OFFSET = 0.0225

local function TransformBattlefieldPosition(x, y)
    local transformedX = (x * BATTLEFIELD_X_SCALE) + BATTLEFIELD_X_OFFSET
    local transformedY = (y * BATTLEFIELD_Y_SCALE) + BATTLEFIELD_Y_OFFSET
    return transformedX, transformedY
end

-- Synthetic WSG test coordinates. The friendly carrier is deliberately placed in
-- mid so the flag marker, carrier-dot suppression, and carrier hover can be checked.
local WSG_TEST_FC_MAP_X = 0.515
local WSG_TEST_FC_MAP_Y = 0.465
local WSG_TEST_FC_RAW_X = (WSG_TEST_FC_MAP_X - BATTLEFIELD_X_OFFSET) / BATTLEFIELD_X_SCALE
local WSG_TEST_FC_RAW_Y = (WSG_TEST_FC_MAP_Y - BATTLEFIELD_Y_OFFSET) / BATTLEFIELD_Y_SCALE

-- Live friendly flag-carrier marker.
-- GetBattlefieldFlagPosition returns normalized coordinates with a top-left
-- origin, matching the WSG map art used by this addon. The marker is anchored
-- in the map's own coordinate space, so resizing the addon scales both the map
-- and marker together without any separate effective-scale conversion.
local FRIENDLY_FLAG_MARKER_SIZE = 22
local friendlyFlagMarker = CreateFrame("Frame", nil, map)
friendlyFlagMarker:SetSize(FRIENDLY_FLAG_MARKER_SIZE, FRIENDLY_FLAG_MARKER_SIZE)
-- Teammate pins render above this large flag marker so nearby players remain
-- individually visible around the friendly carrier.
friendlyFlagMarker:SetFrameLevel(mapBorder:GetFrameLevel() + 2)
if friendlyFlagMarker.SetMouseMotionEnabled then
    friendlyFlagMarker:SetMouseMotionEnabled(true)
else
    friendlyFlagMarker:EnableMouse(true)
end
if friendlyFlagMarker.SetMouseClickEnabled then
    friendlyFlagMarker:SetMouseClickEnabled(false)
end

-- Build the highlight from the flag's own alpha geometry. A broad copy creates
-- the light beneath the artwork while eight offset copies form a soft outline;
-- unlike UI-ActionButton-Border, none of these layers introduces a square edge.
local friendlyFlagGlow = { layers = {}, stars = {}, elapsed = 0, xOffset = -1, yOffset = 1 }
do
    local underlay = friendlyFlagMarker:CreateTexture(nil, "ARTWORK", nil, -8)
    underlay:SetPoint("CENTER", friendlyFlagMarker, "CENTER", friendlyFlagGlow.xOffset, friendlyFlagGlow.yOffset)
    underlay:SetSize(FRIENDLY_FLAG_MARKER_SIZE + 10, FRIENDLY_FLAG_MARKER_SIZE + 10)
    underlay:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    underlay:SetBlendMode("ADD")
    underlay:SetVertexColor(1.0, 0.92, 0.38, 1)
    if underlay.SetDesaturated then underlay:SetDesaturated(true) end
    friendlyFlagGlow.layers[#friendlyFlagGlow.layers + 1] = {
        texture = underlay,
        baseAlpha = 0.12,
        baseSize = FRIENDLY_FLAG_MARKER_SIZE + 10,
        sizePulse = 0.6,
        phase = 0,
        underlay = true,
    }

    local innerLight = friendlyFlagMarker:CreateTexture(nil, "ARTWORK", nil, -7)
    innerLight:SetPoint("CENTER", friendlyFlagMarker, "CENTER", friendlyFlagGlow.xOffset, friendlyFlagGlow.yOffset)
    innerLight:SetSize(FRIENDLY_FLAG_MARKER_SIZE + 4, FRIENDLY_FLAG_MARKER_SIZE + 4)
    innerLight:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    innerLight:SetBlendMode("ADD")
    innerLight:SetVertexColor(1.0, 1.00, 0.72, 1)
    if innerLight.SetDesaturated then innerLight:SetDesaturated(true) end
    friendlyFlagGlow.layers[#friendlyFlagGlow.layers + 1] = {
        texture = innerLight,
        baseAlpha = 0.16,
        baseSize = FRIENDLY_FLAG_MARKER_SIZE + 4,
        sizePulse = 0.5,
        phase = math.pi,
        underlay = true,
    }

    local offsets = {
        { 0.00,  1.25 }, { 0.88,  0.88 }, { 1.25,  0.00 }, { 0.88, -0.88 },
        { 0.00, -1.25 }, {-0.88, -0.88 }, {-1.25,  0.00 }, {-0.88,  0.88 },
    }
    for index, offset in ipairs(offsets) do
        local outline = friendlyFlagMarker:CreateTexture(nil, "ARTWORK", nil, -6)
        outline:SetPoint("CENTER", friendlyFlagMarker, "CENTER", friendlyFlagGlow.xOffset + offset[1], friendlyFlagGlow.yOffset + offset[2])
        outline:SetSize(FRIENDLY_FLAG_MARKER_SIZE, FRIENDLY_FLAG_MARKER_SIZE)
        outline:SetTexCoord(0.04, 0.96, 0.04, 0.96)
        outline:SetBlendMode("ADD")
        outline:SetVertexColor(1.0, 0.88, 0.16, 1)
        if outline.SetDesaturated then outline:SetDesaturated(true) end
        friendlyFlagGlow.layers[#friendlyFlagGlow.layers + 1] = {
            texture = outline,
            baseAlpha = 0.22,
            phase = ((index - 1) / #offsets) * math.pi * 2,
            radius = 1.25,
        }
    end

    local rearStar = friendlyFlagMarker:CreateTexture(nil, "ARTWORK", nil, -5)
    rearStar:SetPoint("CENTER", friendlyFlagMarker, "CENTER", friendlyFlagGlow.xOffset, friendlyFlagGlow.yOffset)
    rearStar:SetTexture("Interface\\Cooldown\\star4")
    rearStar:SetBlendMode("ADD")
    rearStar:SetVertexColor(1.00, 0.72, 0.05, 1)
    friendlyFlagGlow.stars[#friendlyFlagGlow.stars + 1] = {
        texture = rearStar,
        baseSize = 36,
        sizePulse = 4,
        baseAlpha = 0.94,
        rotationSpeed = 0.95,
        phase = 0,
    }

    local whiteStar = friendlyFlagMarker:CreateTexture(nil, "ARTWORK", nil, -4)
    whiteStar:SetPoint("CENTER", friendlyFlagMarker, "CENTER", friendlyFlagGlow.xOffset, friendlyFlagGlow.yOffset)
    whiteStar:SetTexture("Interface\\Cooldown\\star4")
    whiteStar:SetBlendMode("ADD")
    whiteStar:SetVertexColor(1.00, 0.96, 0.58, 1)
    friendlyFlagGlow.stars[#friendlyFlagGlow.stars + 1] = {
        texture = whiteStar,
        baseSize = 29,
        sizePulse = 3,
        baseAlpha = 0.78,
        rotationSpeed = -1.45,
        phase = math.pi * 0.72,
    }

end

local friendlyFlagIcon = friendlyFlagMarker:CreateTexture(nil, "ARTWORK")
friendlyFlagIcon:SetAllPoints()
friendlyFlagIcon:SetTexCoord(0.04, 0.96, 0.04, 0.96)

local friendlyFlagLastTexture = nil
local friendlyFlagUpdateElapsed = 0

local function GetVisibleFriendlyFlagPosition()
    if type(GetBattlefieldFlagPosition) ~= "function" then
        return nil
    end

    local count = nil
    if type(GetNumBattlefieldFlagPositions) == "function" then
        local ok, value = pcall(GetNumBattlefieldFlagPositions)
        if ok and type(value) == "number" then
            count = value
        end
    end

    local scanCount = (count and count > 0) and count or 4
    for i = 1, scanCount do
        local ok, x, y, texture = pcall(GetBattlefieldFlagPosition, i)
        if ok
            and type(x) == "number"
            and type(y) == "number"
            and texture ~= nil
            and x > 0
            and y > 0 then
            return x, y, texture
        end
    end

    return nil
end

local function UpdateFriendlyFlagMarker()
    if wsgTestMode then
        local mapWidth = map:GetWidth() or MAP_WIDTH
        local mapHeight = map:GetHeight() or MAP_HEIGHT
        local half = FRIENDLY_FLAG_MARKER_SIZE / 2
        local pixelX = math.max(half, math.min(mapWidth - half, ZurkMapsWSGTestSim.fcMapX * mapWidth))
        local pixelY = math.max(half, math.min(mapHeight - half, ZurkMapsWSGTestSim.fcMapY * mapHeight))

        friendlyFlagMarker:ClearAllPoints()
        friendlyFlagMarker:SetPoint("CENTER", map, "TOPLEFT", pixelX, -pixelY)
        local flagTexture = "Interface\\WorldStateFrame\\" .. GetCarrierFlagToken(true)
        friendlyFlagIcon:SetTexture(flagTexture)
        for _, layer in ipairs(friendlyFlagGlow.layers) do
            layer.texture:SetTexture(flagTexture)
            if layer.texture.SetDesaturated then layer.texture:SetDesaturated(true) end
        end
        friendlyFlagLastTexture = nil
        friendlyFlagMarker:Show()
        return
    end

    local x, y, texture = GetVisibleFriendlyFlagPosition()
    if not x or not y then
        friendlyFlagMarker:Hide()
        return
    end

    -- Use the map's current local dimensions. They remain 330x440 at the
    -- default layout, while frame scaling changes the rendered size. This keeps
    -- placement correct at every saved scale and after /wsg reset.
    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT
    local half = FRIENDLY_FLAG_MARKER_SIZE / 2
    local transformedX, transformedY = TransformBattlefieldPosition(x, y)

    -- Clamp the marker's center so the complete flag icon always remains
    -- inside the visible map, even at extreme API coordinates near a base.
    local pixelX = math.max(half, math.min(mapWidth - half, transformedX * mapWidth))
    local pixelY = math.max(half, math.min(mapHeight - half, transformedY * mapHeight))

    friendlyFlagMarker:ClearAllPoints()
    friendlyFlagMarker:SetPoint("CENTER", map, "TOPLEFT", pixelX, -pixelY)

    if texture ~= friendlyFlagLastTexture then
        friendlyFlagIcon:SetTexture(texture)
        for _, layer in ipairs(friendlyFlagGlow.layers) do
            layer.texture:SetTexture(texture)
            if layer.texture.SetDesaturated then layer.texture:SetDesaturated(true) end
        end
        friendlyFlagLastTexture = texture
    end

    friendlyFlagMarker:Show()
end

local friendlyFlagUpdateFrame = CreateFrame("Frame", nil, frame)
friendlyFlagUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
    friendlyFlagGlow.elapsed = friendlyFlagGlow.elapsed + elapsed
    if friendlyFlagMarker:IsShown() then
        for _, layer in ipairs(friendlyFlagGlow.layers) do
            if layer.underlay then
                local pulse = math.sin((friendlyFlagGlow.elapsed * 4.2) + layer.phase)
                local shimmer = math.sin((friendlyFlagGlow.elapsed * 9.0) - (layer.phase * 1.7))
                local size = layer.baseSize + (layer.sizePulse * (0.5 + (0.5 * pulse)))
                layer.texture:SetSize(size, size)
                layer.texture:SetAlpha(layer.baseAlpha * (0.82 + (0.13 * pulse) + (0.05 * shimmer)))
            else
                local radius = layer.radius + (0.10 * math.sin((friendlyFlagGlow.elapsed * 4.8) + layer.phase))
                layer.texture:ClearAllPoints()
                layer.texture:SetPoint(
                    "CENTER",
                    friendlyFlagMarker,
                    "CENTER",
                    friendlyFlagGlow.xOffset + (math.cos(layer.phase) * radius),
                    friendlyFlagGlow.yOffset + (math.sin(layer.phase) * radius)
                )
                local sweep = 0.5 + (0.5 * math.sin((friendlyFlagGlow.elapsed * 5.4) - layer.phase))
                local shimmer = 0.5 + (0.5 * math.sin((friendlyFlagGlow.elapsed * 10.8) + (layer.phase * 2.3)))
                layer.texture:SetAlpha(layer.baseAlpha * (0.42 + (0.48 * sweep) + (0.16 * shimmer)))
            end
        end
        for _, star in ipairs(friendlyFlagGlow.stars) do
            local wave = 0.5 + (0.5 * math.sin((friendlyFlagGlow.elapsed * 5.6) + star.phase))
            local flash = star.sharp and (wave * wave * wave * wave) or wave
            local size = star.baseSize + (star.sizePulse * flash)
            star.texture:SetSize(size, size)
            star.texture:SetAlpha(star.baseAlpha * ((star.sharp and 0.20 or 0.62) + ((star.sharp and 0.80 or 0.38) * flash)))
            if star.texture.SetRotation then
                star.texture:SetRotation((friendlyFlagGlow.elapsed * star.rotationSpeed) + star.phase)
            end
        end
    end
    friendlyFlagUpdateElapsed = friendlyFlagUpdateElapsed + elapsed
    if friendlyFlagUpdateElapsed < 0.10 then
        return
    end
    friendlyFlagUpdateElapsed = 0
    UpdateFriendlyFlagMarker()
end)

-- Turtle callout button #1.
-- It sits inside the upper-left corner of the map and scales with the addon.
local TURTLE_BUTTON_SIZE = 45
local TURTLE_MENU_WIDTH = 58
local TURTLE_OPTION_HEIGHT = 25
local TURTLE_MENU_PADDING = 5

local turtleMenu
local turtleMenuDismiss
local turtleButton
local turtleIcon
local turtleBorder
local turtleOpenHighlight

local function CloseTurtleMenu()
    if turtleMenu then
        turtleMenu:Hide()
    end
    if turtleMenuDismiss then
        turtleMenuDismiss:Hide()
    end
    if turtleOpenHighlight then
        turtleOpenHighlight:Hide()
    end

    if turtleButton and turtleButton:IsMouseOver() then
        turtleIcon:SetAlpha(1)
        turtleBorder:SetAlpha(1)
    elseif turtleIcon and turtleBorder then
        turtleIcon:SetAlpha(1)
        turtleBorder:SetAlpha(1)
    end
end

turtleButton = CreateFrame("Button", nil, map)
turtleButton:SetSize(TURTLE_BUTTON_SIZE, TURTLE_BUTTON_SIZE)
-- Seven pixels of inset keeps the full 45x45 button inside the map.
turtleButton:SetPoint("TOPLEFT", map, "TOPLEFT", 7, -7)
turtleButton:SetFrameLevel(mapBorder:GetFrameLevel() + 3)
turtleButton:RegisterForClicks("LeftButtonUp")

local turtleBackground = turtleButton:CreateTexture(nil, "BACKGROUND")
turtleBackground:SetAllPoints()
turtleBackground:SetColorTexture(0.08, 0.055, 0.025, 1)

turtleIcon = turtleButton:CreateTexture(nil, "ARTWORK")
turtleIcon:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Turtle")
turtleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
turtleIcon:SetAlpha(1)

turtleBorder = ZurkMapsBattlecry.CreateButtonBorder(turtleButton)
turtleBorder:FitContent(turtleBackground, turtleIcon, 1)
turtleBorder:SetAlpha(1)

turtleButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
turtleButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

-- Keep a separate glow visible after the cursor leaves the icon.
turtleOpenHighlight = turtleButton:CreateTexture(nil, "OVERLAY")
turtleOpenHighlight:SetAllPoints()
turtleOpenHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
turtleOpenHighlight:SetBlendMode("ADD")
turtleOpenHighlight:Hide()

-- A full-screen click catcher closes the menu when the player clicks elsewhere.
turtleMenuDismiss = CreateFrame("Button", nil, UIParent)
turtleMenuDismiss:SetAllPoints(UIParent)
turtleMenuDismiss:SetFrameStrata("DIALOG")
turtleMenuDismiss:SetFrameLevel(90)
turtleMenuDismiss:EnableMouse(true)
turtleMenuDismiss:RegisterForClicks("AnyUp")
turtleMenuDismiss:SetScript("OnClick", CloseTurtleMenu)
turtleMenuDismiss:Hide()

-- Custom menu anchored directly to the turtle icon.
turtleMenu = CreateFrame(
    "Frame",
    "ZurksWSGTurtleMenu",
    UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
turtleMenu:SetSize(
    TURTLE_MENU_WIDTH,
    (TURTLE_OPTION_HEIGHT * 5) + (TURTLE_MENU_PADDING * 2)
)
turtleMenu:SetFrameStrata("DIALOG")
turtleMenu:SetFrameLevel(91)
turtleMenu:SetClampedToScreen(true)

if turtleMenu.SetBackdrop then
    turtleMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    turtleMenu:SetBackdropColor(0.03, 0.03, 0.03, 0.96)
    turtleMenu:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
end

turtleMenu:Hide()

local function AnchorTurtleMenuToIcon()
    turtleMenu:SetScale(frame:GetScale())
    turtleMenu:ClearAllPoints()
    turtleMenu:SetPoint("TOPLEFT", turtleButton, "BOTTOMLEFT", 0, -2)
end

for i = 1, 5 do
    local optionText = tostring(i) .. "+"
    local option = CreateFrame("Button", nil, turtleMenu)
    option:SetHeight(TURTLE_OPTION_HEIGHT)
    option:SetPoint(
        "TOPLEFT",
        turtleMenu,
        "TOPLEFT",
        TURTLE_MENU_PADDING,
        -TURTLE_MENU_PADDING - ((i - 1) * TURTLE_OPTION_HEIGHT)
    )
    option:SetPoint(
        "TOPRIGHT",
        turtleMenu,
        "TOPRIGHT",
        -TURTLE_MENU_PADDING,
        -TURTLE_MENU_PADDING - ((i - 1) * TURTLE_OPTION_HEIGHT)
    )

    local optionBG = option:CreateTexture(nil, "BACKGROUND")
    optionBG:SetAllPoints()
    optionBG:SetColorTexture(0.02, 0.02, 0.02, 0.72)

    local optionHighlight = option:CreateTexture(nil, "HIGHLIGHT")
    optionHighlight:SetAllPoints()
    optionHighlight:SetColorTexture(0.85, 0.62, 0.08, 0.55)

    local optionLabel = option:CreateFontString(nil, "OVERLAY")
    optionLabel:SetPoint("CENTER")
    optionLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    optionLabel:SetTextColor(1, 0.88, 0.48, 1)
    optionLabel:SetText(optionText)

    option.calloutText = optionText
    option:RegisterForClicks("LeftButtonUp")
    option:SetScript("OnClick", function(self)
        CloseTurtleMenu()
        Report("They are turtling. " .. self.calloutText .. " visible in their Flag Room")
    end)
end

turtleButton:SetScript("OnEnter", function(self)
    turtleIcon:SetAlpha(1)
    turtleBorder:SetAlpha(1)

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Turtle Callout")
    GameTooltip:AddLine("Choose how many defenders are visible in their Flag Room.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)

turtleButton:SetScript("OnLeave", function()
    if turtleMenu:IsShown() then
        turtleIcon:SetAlpha(1)
        turtleBorder:SetAlpha(1)
    else
        turtleIcon:SetAlpha(1)
        turtleBorder:SetAlpha(1)
    end
    GameTooltip:Hide()
end)

turtleButton:SetScript("OnClick", function()
    if turtleMenu:IsShown() then
        CloseTurtleMenu()
        return
    end

    hoveredZone = nil
    highlightTexture:Hide()
    GameTooltip:Hide()
    AnchorTurtleMenuToIcon()
    turtleMenuDismiss:Show()
    turtleMenu:Show()
    turtleOpenHighlight:Show()
    turtleIcon:SetAlpha(1)
    turtleBorder:SetAlpha(1)
end)

frame:HookScript("OnHide", CloseTurtleMenu)

-- Class-focus callout button #2.
-- It mirrors the turtle button in the upper-right corner of the map.
local FOCUS_BUTTON_SIZE = TURTLE_BUTTON_SIZE
local FOCUS_MENU_WIDTH = 142
local FOCUS_OPTION_HEIGHT = 23
local FOCUS_MENU_PADDING = 5

local focusMenu
local focusMenuDismiss
local focusButton
local focusIcon
local focusBorder
local focusOpenHighlight

local FOCUS_CLASS_OPTIONS = {
    PALADIN = { token = "PALADIN", name = "Paladin" },
    SHAMAN = { token = "SHAMAN", name = "Shaman" },
    PRIEST = { token = "PRIEST", name = "Priest" },
    DRUID = { token = "DRUID", name = "Druid" },
    MAGE = { token = "MAGE", name = "Mage" },
    WARLOCK = { token = "WARLOCK", name = "Warlock" },
    HUNTER = { token = "HUNTER", name = "Hunter" },
    ROGUE = { token = "ROGUE", name = "Rogue" },
    WARRIOR = { token = "WARRIOR", name = "Warrior" },
}

local FOCUS_STANDARD_ORDER = {
    "PRIEST",
    "DRUID",
    "MAGE",
    "WARLOCK",
    "HUNTER",
    "ROGUE",
    "WARRIOR",
}

local function GetEnemyFactionFocusClassToken()
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then
        return "SHAMAN"
    elseif faction == "Horde" then
        return "PALADIN"
    end
    return nil
end

local function GetOrderedFocusClassOptions()
    local options = {}
    local specialToken = GetEnemyFactionFocusClassToken()
    if specialToken and FOCUS_CLASS_OPTIONS[specialToken] then
        table.insert(options, FOCUS_CLASS_OPTIONS[specialToken])
    end

    for _, token in ipairs(FOCUS_STANDARD_ORDER) do
        if FOCUS_CLASS_OPTIONS[token] then
            table.insert(options, FOCUS_CLASS_OPTIONS[token])
        end
    end

    return options
end

local function GetFocusClassDisplayName(classInfo)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classInfo.token]) or classInfo.name
end

-- Fallbacks are included in case a Classic client does not expose the shared tables.
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

-- Friendly-player position overlay.
-- This uses Blizzard's native UnitPositionFrame renderer, but the renderer is
-- placed inside a clipping frame and geometrically calibrated to Zurk's map.
local WSG_UI_MAP_ID_FALLBACK = 1460
local FRIENDLY_PLAYER_DOT_SIZE = 10

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

local function GetWSGUiMapID()
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

    return WSG_UI_MAP_ID_FALLBACK
end

ZurkMapsWSGRank = ZurkMapsPlayerBlips.CreateRankController({
    min = 12,
    max = 14,
    iconScale = 0.924,
    baseDotSize = FRIENDLY_PLAYER_DOT_SIZE,
    getFriendlyFrame = function() return friendlyPlayersFrame end,
    isAvailable = function() return friendlyPlayersFrameAvailable end,
    getMapFrame = function() return map end,
    getUiMapID = GetWSGUiMapID,
    getDotSize = function() return ZurkMapsPlayerBlips.GetDotSize(FRIENDLY_PLAYER_DOT_SIZE, frame) end,
    getClassColor = function(unit) return ZurkMapsPlayerBlips.GetClassColor(unit, CLASS_COLOR_FALLBACK) end,
    shouldIncludeUnit = function(unit)
        local friendlyCarrier = GetCarrierAssignments()
        return not (friendlyCarrier and CarrierNameMatches(unit, friendlyCarrier))
    end,
    mapWidth = MAP_WIDTH,
    mapHeight = MAP_HEIGHT,
})

local function ApplyFriendlyPositionGeometry()
    if not friendlyPlayersFrame then
        return
    end

    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT

    friendlyPlayersFrame:ClearAllPoints()
    friendlyPlayersFrame:SetPoint(
        "TOPLEFT",
        map,
        "TOPLEFT",
        BATTLEFIELD_X_OFFSET * mapWidth,
        -(BATTLEFIELD_Y_OFFSET * mapHeight)
    )
    friendlyPlayersFrame:SetSize(
        BATTLEFIELD_X_SCALE * mapWidth,
        BATTLEFIELD_Y_SCALE * mapHeight
    )
end

ConfigureFriendlyPlayerDots = function()
    if not friendlyPlayersFrameAvailable then
        return
    end

    ApplyFriendlyPositionGeometry()
    pcall(friendlyPlayersFrame.SetUiMapID, friendlyPlayersFrame, GetWSGUiMapID())
    pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "player", true)
    pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "party", true)
    pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "raid", true)

    local dotSize = ZurkMapsPlayerBlips.GetDotSize(FRIENDLY_PLAYER_DOT_SIZE, frame)
    pcall(friendlyPlayersFrame.SetPinSize, friendlyPlayersFrame, "player", dotSize)
    pcall(friendlyPlayersFrame.SetPinSize, friendlyPlayersFrame, "party", dotSize)
    pcall(friendlyPlayersFrame.SetPinSize, friendlyPlayersFrame, "raid", dotSize)

    ZurkMapsWSGRank.ColorFriendlyUnit("player")
    for i = 1, 4 do
        ZurkMapsWSGRank.ColorFriendlyUnit("party" .. i)
    end
    for i = 1, 40 do
        ZurkMapsWSGRank.ColorFriendlyUnit("raid" .. i)
    end

    -- Update once after configuration; normal movement updates below only move
    -- the pins and do not repeatedly rebuild size/color state. This avoids the
    -- color/overlap flicker seen in the previous build.
    pcall(friendlyPlayersFrame.UpdatePlayerPins, friendlyPlayersFrame)
    ZurkMapsWSGRank.UpdateBlips()
    if wsgTestMode and UpdateWSGTestBlips then
        UpdateWSGTestBlips()
    end
end

local function UpdateFriendlyPlayerPositions()
    if friendlyPlayersFrameAvailable and friendlyPlayersFrame:IsShown() then
        pcall(friendlyPlayersFrame.UpdatePlayerPins, friendlyPlayersFrame)
        ZurkMapsWSGRank.UpdateBlips()
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
        friendlyPlayersFrame.dataProvider = ZurkMapsWSGRank.dataProvider

        -- We control refresh ourselves because this is not attached to a full
        -- Blizzard MapCanvas data provider.
        friendlyPlayersFrame:SetScript("OnUpdate", nil)
        friendlyPlayersFrame:SetFrameLevel(friendlyPlayersClipFrame:GetFrameLevel() + 1)

        -- Native mouse-motion hit testing is required for GetCurrentMouseOverUnits.
        -- Mouse clicks remain disabled so hotspot clicking still passes through.
        if friendlyPlayersFrame.SetMouseMotionEnabled then
            friendlyPlayersFrame:SetMouseMotionEnabled(true)
        else
            friendlyPlayersFrame:EnableMouse(true)
        end
        if friendlyPlayersFrame.SetMouseClickEnabled then
            friendlyPlayersFrame:SetMouseClickEnabled(false)
        end

        local mapOK = pcall(friendlyPlayersFrame.SetUiMapID, friendlyPlayersFrame, GetWSGUiMapID())
        local unitsOK = pcall(friendlyPlayersFrame.SetShouldShowUnits, friendlyPlayersFrame, "raid", true)
        friendlyPlayersFrameAvailable = mapOK and unitsOK and type(friendlyPlayersFrame.UpdatePlayerPins) == "function"
        friendlyPlayersFrame:SetShown(false)

        if friendlyPlayersFrameAvailable then
            ConfigureFriendlyPlayerDots()
        end
    end
end

local friendlyPlayersUpdateFrame = CreateFrame("Frame", nil, frame)
friendlyPlayersUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
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

-- Synthetic friendly-player overlay used by /wsg test. Test players use
-- Blizzard's native world-map party blip artwork rather than the minimap
-- PartyRaidBlips sheet (which renders as colored circles). They share goals
-- and routes but never hold formation: individual speeds and pauses let them
-- bunch up, overlap, split apart, and naturally converge on objectives.
ZurkMapsWSGTestSim.hordeNames = {
    "Zugmash", "Mokthar", "Grimtotem", "Ragetusk", "Drekka", "Skullbash",
    "Hexhoof", "Gromsnack", "Bonetusk", "Frostfang", "Mudsnout", "Razortusk",
    "Axehoof", "Wolfsnout", "Doomtotem", "Shadowtusk", "Mokgor", "Thrakka",
    "Zugzug", "Grimfang", "Bloodtotem", "Rotgut", "Hexgrin", "Rokzug",
    "Voodooman", "Totemsmash", "Ironhoof", "Darkspear", "Ashfang", "Warhoof",
}
ZurkMapsWSGTestSim.allianceNames = {
    "Lightshield", "Stormwarden", "Goldbraid", "Oakensong", "Brightforge",
    "Dawnwatch", "Lionheart", "Silveroak", "Westfall", "Hammerfall",
}
ZurkMapsWSGTestSim.hordeClasses = { "WARRIOR", "SHAMAN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID" }
ZurkMapsWSGTestSim.gold = { 1.00, 0.82, 0.18 }
ZurkMapsWSGTestSim.baseSpeedScale = 0.70
ZurkMapsWSGTestSim.mountSpeedMultiplier = 2.00
ZurkMapsWSGTestSim.mountChance = 0.10
ZurkMapsWSGTestSim.blipTexCoords = {
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

-- Route library: repeated/shared objectives create loose groups, but every
-- agent advances independently. Coordinates stay within the playable valley.
ZurkMapsWSGTestSim.routeLibrary = {
    -- Flag runner: Horde side -> mid -> Alliance side -> back.
    { {0.50,0.77}, {0.51,0.69}, {0.50,0.61}, {0.51,0.53}, {0.50,0.45}, {0.50,0.36}, {0.50,0.27}, {0.50,0.20}, {0.50,0.28}, {0.50,0.38}, {0.50,0.50}, {0.50,0.62} },
    -- West lane push.
    { {0.50,0.73}, {0.44,0.67}, {0.38,0.59}, {0.32,0.50}, {0.31,0.41}, {0.35,0.32}, {0.42,0.24}, {0.48,0.20}, {0.42,0.29}, {0.36,0.38}, {0.33,0.49}, {0.39,0.60} },
    -- East lane push.
    { {0.52,0.73}, {0.58,0.67}, {0.64,0.59}, {0.69,0.50}, {0.68,0.41}, {0.65,0.32}, {0.58,0.24}, {0.52,0.20}, {0.58,0.30}, {0.64,0.40}, {0.67,0.50}, {0.61,0.60} },
    -- Mid skirmish loop.
    { {0.45,0.57}, {0.42,0.51}, {0.45,0.45}, {0.51,0.42}, {0.57,0.46}, {0.59,0.52}, {0.55,0.57}, {0.49,0.59} },
    -- Horde defense / midfield reinforce.
    { {0.48,0.76}, {0.46,0.69}, {0.48,0.62}, {0.53,0.58}, {0.57,0.53}, {0.53,0.48}, {0.48,0.53}, {0.46,0.62} },
}
ZurkMapsWSGTestSim.starts = {
    {0.50,0.73}, {0.49,0.72}, {0.52,0.71}, {0.48,0.68}, {0.36,0.57},
    {0.64,0.58}, {0.48,0.52}, {0.52,0.63}, {0.50,0.65}, {0.54,0.61},
}
ZurkMapsWSGTestSim.routeAssignments = { 1,1,1,5,2,3,4,5,1,4 }
ZurkMapsWSGTestSim.agents = {}
for i = 1, 10 do
    local s = ZurkMapsWSGTestSim.starts[i]
    local route = ZurkMapsWSGTestSim.routeLibrary[ZurkMapsWSGTestSim.routeAssignments[i]]
    ZurkMapsWSGTestSim.agents[i] = {
        name = ZurkMapsWSGTestSim.hordeNames[i],
        classToken = ZurkMapsWSGTestSim.hordeClasses[((i - 1) % #ZurkMapsWSGTestSim.hordeClasses) + 1],
        x = s[1], y = s[2], route = route, routeIndex = 1,
        speed = 6.5 + ((i * 13) % 30) / 10, pause = 0,
        mounting = false, mounted = false, mountedWaypoints = 0,
        pvpRankNumber = ({ [2] = 12, [5] = 13, [8] = 14 })[i],
        iconKey = "TEST:WSG:" .. i,
    }
end
ZurkMapsWSGTestSim.blips = {}
for i = 1, #ZurkMapsWSGTestSim.agents do
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
    blip.texture:SetVertexColor(ZurkMapsWSGTestSim.gold[1], ZurkMapsWSGTestSim.gold[2], ZurkMapsWSGTestSim.gold[3], 1)
    blip.texture:SetTexCoord(0, 1, 0, 1)
    blip:Hide()
    ZurkMapsWSGTestSim.blips[i] = blip
end
ZurkMapsWSGTestSim.MoveToward = function(agent, targetX, targetY, elapsed, speedBoost)
    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT
    local dxPixels = (targetX - agent.x) * mapWidth
    local dyPixels = (targetY - agent.y) * mapHeight
    local distance = math.sqrt((dxPixels * dxPixels) + (dyPixels * dyPixels))
    if distance < 0.01 then return true end
    local movementMultiplier = ZurkMapsWSGTestSim.baseSpeedScale * (agent.mounted and ZurkMapsWSGTestSim.mountSpeedMultiplier or 1)
    local step = (agent.speed * movementMultiplier * (speedBoost or 1)) * elapsed
    if step >= distance then agent.x, agent.y = targetX, targetY return true end
    agent.x = agent.x + ((dxPixels / distance) * step / mapWidth)
    agent.y = agent.y + ((dyPixels / distance) * step / mapHeight)
    return false
end
ZurkMapsWSGTestSim.Advance = function(elapsed)
    for _, agent in ipairs(ZurkMapsWSGTestSim.agents) do
        if agent.route and #agent.route > 0 then
            if agent.pause > 0 then
                agent.pause = math.max(0, agent.pause - elapsed)
                if agent.pause <= 0 and agent.mounting then
                    -- Three stationary seconds represent the mount cast. The
                    -- resulting mounted run is twice this player's normal test
                    -- speed and lasts across several route waypoints.
                    agent.mounting = false
                    agent.mounted = true
                    agent.mountedWaypoints = math.random(3, 6)
                end
            else
                local target = agent.route[agent.routeIndex]
                if ZurkMapsWSGTestSim.MoveToward(agent, target[1], target[2], elapsed, 1) then
                    agent.routeIndex = (agent.routeIndex % #agent.route) + 1

                    if agent.mounted then
                        agent.mountedWaypoints = math.max(0, (agent.mountedWaypoints or 1) - 1)
                        if agent.mountedWaypoints <= 0 then
                            agent.mounted = false
                        end
                    end

                    if not agent.mounted and math.random() < ZurkMapsWSGTestSim.mountChance then
                        agent.mounting = true
                        agent.pause = 3.0
                    elseif not agent.mounted then
                        -- Independent pauses still create loose groups; mounted
                        -- players continue through instead of stopping to fight.
                        if math.random() < 0.35 then
                            agent.pause = math.random(0, 24) / 10
                        else
                            agent.pause = math.random(0, 5) / 10
                        end
                    end
                end
            end
        end
    end
    ZurkMapsWSGTestSim.fcMapX = ZurkMapsWSGTestSim.agents[1].x
    ZurkMapsWSGTestSim.fcMapY = ZurkMapsWSGTestSim.agents[1].y
end
ZurkMapsWSGTestSim.Randomize = function()
    local pool = {}
    for i, name in ipairs(ZurkMapsWSGTestSim.hordeNames) do pool[i] = name end
    for i, agent in ipairs(ZurkMapsWSGTestSim.agents) do
        agent.name = table.remove(pool, math.random(1, #pool))
        agent.classToken = ZurkMapsWSGTestSim.hordeClasses[math.random(1, #ZurkMapsWSGTestSim.hordeClasses)]
        agent.route = ZurkMapsWSGTestSim.routeLibrary[ZurkMapsWSGTestSim.routeAssignments[i]]
        local spawnIndex = math.random(1, #agent.route)
        local startPoint = agent.route[spawnIndex]
        agent.x, agent.y = startPoint[1], startPoint[2]
        agent.routeIndex = (spawnIndex % #agent.route) + 1
        agent.speed = 6.3 + (math.random(0, 34) / 10)
        agent.pause = math.random(0, 18) / 10
        agent.mounting = false
        agent.mounted = false
        agent.mountedWaypoints = 0
    end
    local fcClasses = { "DRUID", "ROGUE", "SHAMAN", "WARRIOR" }
    ZurkMapsWSGTestSim.agents[1].classToken = fcClasses[math.random(1, #fcClasses)]
    ZurkMapsWSGTestSim.friendlyFCName = ZurkMapsWSGTestSim.agents[1].name
    ZurkMapsWSGTestSim.friendlyFCClass = ZurkMapsWSGTestSim.agents[1].classToken
    ZurkMapsWSGTestSim.enemyFCName = ZurkMapsWSGTestSim.allianceNames[math.random(1, #ZurkMapsWSGTestSim.allianceNames)]
    local enemyClasses = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID" }
    ZurkMapsWSGTestSim.enemyFCClass = enemyClasses[math.random(1, #enemyClasses)]
    ZurkMapsWSGTestSim.fcMapX, ZurkMapsWSGTestSim.fcMapY = ZurkMapsWSGTestSim.agents[1].x, ZurkMapsWSGTestSim.agents[1].y
end
UpdateWSGTestBlips = function()
    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT
    local dotSize = ZurkMapsPlayerBlips.GetDotSize(FRIENDLY_PLAYER_DOT_SIZE, frame)
    for i, agent in ipairs(ZurkMapsWSGTestSim.agents) do
        local blip = ZurkMapsWSGTestSim.blips[i]
        local assignedIcon = ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForKey
            and ZurkMapsPlayerIcons.GetAssignedIconForKey(agent.iconKey, true) or nil
        local eliteAssigned = assignedIcon and ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.IsOverlayOnlyIcon
            and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon)
        if eliteAssigned then
            ZurkMapsPlayerBlips.ApplyGoldBlip(blip, dotSize, ZurkMapsWSGTestSim.gold[1], ZurkMapsWSGTestSim.gold[2], ZurkMapsWSGTestSim.gold[3])
            ZurkMapsPlayerIcons.ApplyAssignedIcon(blip, assignedIcon, dotSize)
        elseif assignedIcon and ZurkMapsPlayerIcons.ApplyAssignedIcon then
            ZurkMapsPlayerIcons.ApplyAssignedIcon(blip, assignedIcon, dotSize * (ZurkMapsPlayerIcons.manualIconScale or 0.84))
        elseif agent.pvpRankNumber and agent.pvpRankNumber >= ZurkMapsWSGRank.min and agent.pvpRankNumber <= ZurkMapsWSGRank.max then
            ZurkMapsPlayerBlips.ApplyRankBadge(blip, agent.pvpRankNumber, dotSize * ZurkMapsWSGRank.iconScale, agent.classToken)
        else
            ZurkMapsPlayerBlips.ApplyGoldBlip(blip, dotSize, ZurkMapsWSGTestSim.gold[1], ZurkMapsWSGTestSim.gold[2], ZurkMapsWSGTestSim.gold[3])
        end
        if (not assignedIcon or (ZurkMapsPlayerIcons.IsOverlayOnlyIcon and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon))) and (assignedIcon or not agent.pvpRankNumber or agent.pvpRankNumber < ZurkMapsWSGRank.min or agent.pvpRankNumber > ZurkMapsWSGRank.max) then
            ZurkMapsPlayerBlips.ApplyTeammateColor(blip, agent.classToken, eliteAssigned)
        end
        blip:ClearAllPoints()
        blip:SetPoint("CENTER", map, "TOPLEFT", agent.x * mapWidth, -(agent.y * mapHeight))
        -- Agent 1 is the synthetic friendly carrier. The flag owns that
        -- position and hover affordance, so do not stack a gold dot over it.
        blip:SetShown(wsgTestMode and i ~= 1)
    end
end
ShowWSGTestBlips = function() UpdateWSGTestBlips() end
HideWSGTestBlips = function() for _, blip in ipairs(ZurkMapsWSGTestSim.blips) do blip:Hide() end end
ZurkMapsWSGTestSim.movementElapsed = 0
ZurkMapsWSGTestSim.movementFrame = CreateFrame("Frame", nil, frame)
ZurkMapsWSGTestSim.movementFrame:SetScript("OnUpdate", function(_, elapsed)
    if not wsgTestMode then return end
    ZurkMapsWSGTestSim.movementElapsed = ZurkMapsWSGTestSim.movementElapsed + elapsed
    if ZurkMapsWSGTestSim.movementElapsed < 0.05 then return end
    local step = ZurkMapsWSGTestSim.movementElapsed
    ZurkMapsWSGTestSim.movementElapsed = 0
    ZurkMapsWSGTestSim.Advance(step)
    UpdateWSGTestBlips()
    UpdateFriendlyFlagMarker()
end)

local CLASS_ICON_FALLBACK = {
    WARRIOR = { 0.00, 0.25, 0.00, 0.25 },
    MAGE = { 0.25, 0.50, 0.00, 0.25 },
    ROGUE = { 0.50, 0.75, 0.00, 0.25 },
    DRUID = { 0.75, 1.00, 0.00, 0.25 },
    HUNTER = { 0.00, 0.25, 0.25, 0.50 },
    SHAMAN = { 0.25, 0.50, 0.25, 0.50 },
    PRIEST = { 0.50, 0.75, 0.25, 0.50 },
    WARLOCK = { 0.75, 1.00, 0.25, 0.50 },
    PALADIN = { 0.00, 0.25, 0.50, 0.75 },
}

local function CloseFocusMenu()
    if focusMenu then
        focusMenu:Hide()
    end
    if focusMenuDismiss then
        focusMenuDismiss:Hide()
    end
    if focusOpenHighlight then
        focusOpenHighlight:Hide()
    end

    if focusButton and focusButton:IsMouseOver() then
        focusIcon:SetAlpha(1)
        focusBorder:SetAlpha(1)
    elseif focusIcon and focusBorder then
        focusIcon:SetAlpha(1)
        focusBorder:SetAlpha(1)
    end
end

focusButton = CreateFrame("Button", nil, map)
focusButton:SetSize(FOCUS_BUTTON_SIZE, FOCUS_BUTTON_SIZE)
focusButton:SetPoint("TOPRIGHT", map, "TOPRIGHT", -7, -7)
focusButton:SetFrameLevel(mapBorder:GetFrameLevel() + 3)
focusButton:RegisterForClicks("LeftButtonUp")

local focusBackground = focusButton:CreateTexture(nil, "BACKGROUND")
focusBackground:SetAllPoints()
focusBackground:SetColorTexture(0.08, 0.055, 0.025, 1)

focusIcon = focusButton:CreateTexture(nil, "ARTWORK")
focusIcon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
focusIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
focusIcon:SetAlpha(1)

focusBorder = ZurkMapsBattlecry.CreateButtonBorder(focusButton)
focusBorder:FitContent(focusBackground, focusIcon, 1)
focusBorder:SetAlpha(1)

focusButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
focusButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

focusOpenHighlight = focusButton:CreateTexture(nil, "OVERLAY")
focusOpenHighlight:SetAllPoints()
focusOpenHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
focusOpenHighlight:SetBlendMode("ADD")
focusOpenHighlight:Hide()

focusMenuDismiss = CreateFrame("Button", nil, UIParent)
focusMenuDismiss:SetAllPoints(UIParent)
focusMenuDismiss:SetFrameStrata("DIALOG")
focusMenuDismiss:SetFrameLevel(90)
focusMenuDismiss:EnableMouse(true)
focusMenuDismiss:RegisterForClicks("AnyUp")
focusMenuDismiss:SetScript("OnClick", CloseFocusMenu)
focusMenuDismiss:Hide()

focusMenu = CreateFrame(
    "Frame",
    "ZurksWSGFocusMenu",
    UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
focusMenu:SetSize(
    FOCUS_MENU_WIDTH,
    (FOCUS_OPTION_HEIGHT * 8) + (FOCUS_MENU_PADDING * 2)
)
focusMenu:SetFrameStrata("DIALOG")
focusMenu:SetFrameLevel(91)
focusMenu:SetClampedToScreen(true)

if focusMenu.SetBackdrop then
    focusMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    focusMenu:SetBackdropColor(0.03, 0.03, 0.03, 0.96)
    focusMenu:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
end
focusMenu:Hide()

local function AnchorFocusMenuToIcon()
    focusMenu:SetScale(frame:GetScale())
    focusMenu:ClearAllPoints()
    focusMenu:SetPoint("TOPRIGHT", focusButton, "BOTTOMRIGHT", 0, -2)
end

local focusOptionButtons = {}

local function RefreshFocusMenuOptions()
    local options = GetOrderedFocusClassOptions()
    focusMenu:SetHeight((FOCUS_OPTION_HEIGHT * #options) + (FOCUS_MENU_PADDING * 2))

    for i, option in ipairs(focusOptionButtons) do
        local classInfo = options[i]
        if classInfo then
            local coords = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classInfo.token]) or CLASS_ICON_FALLBACK[classInfo.token]
            if coords then
                option.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            end

            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classInfo.token]
            local fallback = CLASS_COLOR_FALLBACK[classInfo.token]
            if color then
                option.optionLabel:SetTextColor(color.r, color.g, color.b, 1)
            else
                option.optionLabel:SetTextColor(fallback[1], fallback[2], fallback[3], 1)
            end

            local displayName = GetFocusClassDisplayName(classInfo)
            option.optionLabel:SetText(displayName)
            option.className = displayName
            option.classNameUpper = string.upper(displayName)
            option:Show()
        else
            option.className = nil
            option.classNameUpper = nil
            option:Hide()
        end
    end
end

for i = 1, 8 do
    local option = CreateFrame("Button", nil, focusMenu)
    option:SetHeight(FOCUS_OPTION_HEIGHT)
    option:SetPoint(
        "TOPLEFT",
        focusMenu,
        "TOPLEFT",
        FOCUS_MENU_PADDING,
        -FOCUS_MENU_PADDING - ((i - 1) * FOCUS_OPTION_HEIGHT)
    )
    option:SetPoint(
        "TOPRIGHT",
        focusMenu,
        "TOPRIGHT",
        -FOCUS_MENU_PADDING,
        -FOCUS_MENU_PADDING - ((i - 1) * FOCUS_OPTION_HEIGHT)
    )

    local optionBG = option:CreateTexture(nil, "BACKGROUND")
    optionBG:SetAllPoints()
    optionBG:SetColorTexture(0.02, 0.02, 0.02, 0.72)

    local optionHighlight = option:CreateTexture(nil, "HIGHLIGHT")
    optionHighlight:SetAllPoints()
    optionHighlight:SetColorTexture(0.85, 0.62, 0.08, 0.55)

    local classIcon = option:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(17, 17)
    classIcon:SetPoint("LEFT", option, "LEFT", 4, 0)
    classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")

    local optionLabel = option:CreateFontString(nil, "OVERLAY")
    optionLabel:SetPoint("LEFT", classIcon, "RIGHT", 6, 0)
    optionLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

    option.classIcon = classIcon
    option.optionLabel = optionLabel
    option:RegisterForClicks("LeftButtonUp")
    option:SetScript("OnClick", function(self)
        if not self.classNameUpper then
            return
        end
        CloseFocusMenu()
        Report("FOCUS the " .. self.classNameUpper .. "!")
    end)

    focusOptionButtons[i] = option
end

focusButton:SetScript("OnEnter", function(self)
    focusIcon:SetAlpha(1)
    focusBorder:SetAlpha(1)

    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Focus Callout")
    GameTooltip:AddLine("Choose the enemy class your team should focus.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)

focusButton:SetScript("OnLeave", function()
    if focusMenu:IsShown() then
        focusIcon:SetAlpha(1)
        focusBorder:SetAlpha(1)
    else
        focusIcon:SetAlpha(1)
        focusBorder:SetAlpha(1)
    end
    GameTooltip:Hide()
end)

focusButton:SetScript("OnClick", function()
    if focusMenu:IsShown() then
        CloseFocusMenu()
        return
    end

    hoveredZone = nil
    highlightTexture:Hide()
    GameTooltip:Hide()
    RefreshFocusMenuOptions()
    AnchorFocusMenuToIcon()
    focusMenuDismiss:Show()
    focusMenu:Show()
    focusOpenHighlight:Show()
    focusIcon:SetAlpha(1)
    focusBorder:SetAlpha(1)
end)

frame:HookScript("OnHide", CloseFocusMenu)

-- Eyes-on-EFC callout button #3.
-- Uses a built-in Classic eye icon because the client font does not reliably
-- render modern emoji glyphs. It mirrors the top buttons' size and inset.
local EYES_BUTTON_SIZE = 30
local eyesButton = CreateFrame("Button", nil, map)
eyesButton:SetSize(EYES_BUTTON_SIZE, EYES_BUTTON_SIZE)
eyesButton:SetPoint("BOTTOMLEFT", map, "BOTTOMLEFT", 7, 7)
eyesButton:SetFrameLevel(mapBorder:GetFrameLevel() + 3)
eyesButton:RegisterForClicks("LeftButtonUp")

local eyesBackground = eyesButton:CreateTexture(nil, "BACKGROUND")
eyesBackground:SetAllPoints()
eyesBackground:SetColorTexture(0.08, 0.055, 0.025, 1)

local eyesIcon = eyesButton:CreateTexture(nil, "ARTWORK")
eyesIcon:SetTexture("Interface\\Icons\\Spell_Shadow_EvilEye")
eyesIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
eyesIcon:SetAlpha(1)

local eyesBorder = ZurkMapsBattlecry.CreateButtonBorder(eyesButton)
eyesBorder:FitContent(eyesBackground, eyesIcon, 1)
eyesBorder:SetAlpha(1)

eyesButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
eyesButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

eyesButton:SetScript("OnEnter", function(self)
    eyesIcon:SetAlpha(1)
    eyesBorder:SetAlpha(1)

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Eyes on the EFC")
    GameTooltip:AddLine("Ask whether anyone can see the enemy flag carrier.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)

eyesButton:SetScript("OnLeave", function()
    eyesIcon:SetAlpha(1)
    eyesBorder:SetAlpha(1)
    GameTooltip:Hide()
end)

eyesButton:SetScript("OnClick", function()
    hoveredZone = nil
    highlightTexture:Hide()
    GameTooltip:Hide()
    Report("Anyone got eyes on the EFC??")
end)

-- WSG Battlecry: same compact size as EYES, directly above it.
-- The editor logic lives in ZurkMaps_Battlecry.lua to preserve local-variable headroom.
_G.ZurkMapsWSGBattlecry = ZurkMapsBattlecry and ZurkMapsBattlecry.Create({
    frame = frame,
    map = map,
    mapBorder = mapBorder,
    anchorButton = eyesButton,
    buttonGap = 5,
    buttonSize = EYES_BUTTON_SIZE,
    backgroundAlpha = 1,
    iconAlpha = 1,
    borderAlpha = 1,
    hoverAlpha = 1,
    createBorder = ZurkMapsBattlecry.CreateButtonBorder,
    db = ZurksWSGCalloutMapDB,
    dbKey = "battlecryMessage",
    panelName = "ZurkMapsWSGBattlecryTooltip",
    onHoverStart = function()
        hoveredZone = nil
        highlightTexture:Hide()
        GameTooltip:Hide()
    end,
}) or nil

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

local function PointInEllipse(x, y, zone)
    local dx = (x - zone.cx) / zone.rx
    local dy = (y - zone.cy) / zone.ry
    return (dx * dx + dy * dy) <= 1
end

local function GetMousePercent()
    local left = map:GetLeft()
    local bottom = map:GetBottom()

    if not left or not bottom then
        return nil, nil
    end

    -- GetCursorPosition() is in physical screen pixels.
    -- Convert the map's coordinates and dimensions to that SAME coordinate space.
    -- This keeps hotspot hit-testing aligned at every addon scale.
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

    -- Nested Top of Tunnel areas retain first priority.
    for _, zone in ipairs(NESTED_ZONES) do
        if PointInEllipse(x, y, zone) then
            return zone
        end
    end

    -- Explicit hover envelopes take priority over neighboring region edges.
    -- They affect only pointer interaction, not the visible highlight polygon.
    for _, zone in ipairs(ZONES) do
        if zone.hoverPoints and PointInPolygon(x, y, zone.hoverPoints) then
            return zone
        end
    end

    for _, zone in ipairs(ZONES) do
        if PointInPolygon(x, y, zone.points) then
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

    -- Highlight only while the pointer is inside the hotspot.
    highlightTexture:SetZone(zone)
    highlightTexture:Show()

    -- Use Blizzard's normal tooltip placement (bottom-right by default)
    -- and show only the full, unabbreviated location name.
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:SetText(zone.name)
    GameTooltip:Show()
end

local hoveredFriendlyPlayersSignature = nil

ZurkMapsWSGTestSim.GetPlayersUnderMouse = function()
    if not wsgTestMode then return nil end
    local mouseX, mouseY = GetMousePercent()
    if not mouseX or not mouseY then return nil end
    local nx, ny = mouseX / 100, mouseY / 100
    local mapWidth = map:GetWidth() or MAP_WIDTH
    local mapHeight = map:GetHeight() or MAP_HEIGHT
    local radius = math.max(7, ZurkMapsPlayerBlips.GetDotSize(FRIENDLY_PLAYER_DOT_SIZE, frame) * 0.9)
    local matches = {}
    for _, agent in ipairs(ZurkMapsWSGTestSim.agents) do
        local dx = (nx - agent.x) * mapWidth
        local dy = (ny - agent.y) * mapHeight
        if ((dx * dx) + (dy * dy)) <= (radius * radius) then table.insert(matches, agent) end
    end
    return #matches > 0 and matches or nil
end
ZurkMapsWSGTestSim.ShowTooltip = function(players)
    if not players or #players == 0 then return false end
    local names = {}
    for _, player in ipairs(players) do table.insert(names, player.name) end
    table.sort(names)
    local signature = "test:" .. table.concat(names, "|")
    if hoveredFriendlyPlayersSignature == signature and GameTooltip:IsShown() then return true end
    hoveredFriendlyPlayersSignature = signature
    ShowZone(nil)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else GameTooltip:ClearAllPoints() GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95) end
    GameTooltip:ClearLines()
    for _, player in ipairs(players) do
        local r, g, b = GetClassColor(player.classToken)
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

local function GetFriendlyPlayerMouseoverUnits()
    if not friendlyPlayersFrameAvailable
        or not friendlyPlayersFrame
        or not friendlyPlayersFrame:IsShown() then
        return nil
    end

    -- Do not let the transformed off-map position frame create hover results
    -- outside the visible Zurk map.
    local mouseX, mouseY = GetMousePercent()
    if not mouseX or not mouseY or mouseX < 0 or mouseX > 100 or mouseY < 0 or mouseY > 100 then
        return nil
    end

    local units = {}
    local seen = {}

    -- Blizzard's GroupMembersPinMixin itself uses GetCurrentMouseOverUnits().
    -- It returns a stable table keyed by unit token and behaves better with
    -- overlapping pins than the raw GetMouseOverUnits() varargs call.
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

    -- Fallback for clients where only the raw widget method is available.
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

    -- Player-dot tooltip takes priority only while directly over a dot.
    ShowZone(nil)

    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end

    -- Keep the player tooltip minimal: only class-colored player names.
    -- Blizzard always styles tooltip line 1 as a header even when AddLine() is used,
    -- so explicitly force every player-name line to the same font size afterward.
    GameTooltip:ClearLines()
    for _, unit in ipairs(units) do
        local name = (GetUnitName and GetUnitName(unit, true)) or UnitName(unit) or unit
        local r, g, b = ZurkMapsPlayerBlips.GetClassColor(unit, CLASS_COLOR_FALLBACK)
        GameTooltip:AddLine(ZurkMapsPlayerBlips.GetTooltipIconTagForUnit(unit, ZurkMapsWSGRank) .. name, r, g, b)
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

friendlyFlagMarker.ShowCarrierTooltip = function(self)
    if wsgTestMode then
        local carrier = ZurkMapsWSGTestSim.agents and ZurkMapsWSGTestSim.agents[1]
        return carrier and ZurkMapsWSGTestSim.ShowTooltip({ carrier }) or false
    end

    local friendlyCarrier = GetCarrierAssignments()
    local unit = FindFriendlyCarrierUnit(friendlyCarrier)
    if unit then
        return ShowFriendlyPlayerTooltip({ unit })
    end
    if not friendlyCarrier then
        return false
    end

    local classToken = GetCarrierClassToken(friendlyCarrier, nil)
    local r, g, b = GetClassColor(classToken)
    hoveredFriendlyPlayersSignature = "carrier:" .. friendlyCarrier
    ShowZone(nil)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:ClearLines()
    GameTooltip:AddLine(friendlyCarrier, r, g, b)
    GameTooltip:Show()
    return true
end

friendlyFlagMarker:SetScript("OnEnter", function(self)
    self:ShowCarrierTooltip()
end)
friendlyFlagMarker:SetScript("OnLeave", function()
    ClearFriendlyPlayerTooltip()
end)

map:SetScript("OnUpdate", function(self, elapsed)
    if ZurkMapsOptions and ZurkMapsOptions.menu and ZurkMapsOptions.menu:IsShown() then
        return
    end

    if isMoving or resizing then
        return
    end

    if turtleMenu:IsShown() or turtleButton:IsMouseOver() or focusMenu:IsShown() or focusButton:IsMouseOver()
        or (ZurkMapsWSGBattlecry and ZurkMapsWSGBattlecry:IsInteracting()) then
        ShowZone(nil)
        return
    end

    hoverAccumulator = hoverAccumulator + elapsed
    if hoverAccumulator < 0.03 then
        return
    end
    hoverAccumulator = 0

    local testPlayers = ZurkMapsWSGTestSim.GetPlayersUnderMouse()
    if testPlayers then
        ZurkMapsWSGTestSim.ShowTooltip(testPlayers)
        return
    end

    local friendlyUnits = GetFriendlyPlayerMouseoverUnits()
    if friendlyUnits then
        ShowFriendlyPlayerTooltip(friendlyUnits)
        return
    end


    -- The transparent native carrier pin normally supplies this tooltip. The
    -- flag marker is also a fallback hover target if its API position differs
    -- by a pixel or two from Blizzard's roster-position frame.
    if friendlyFlagMarker:IsShown() and friendlyFlagMarker:IsMouseOver() then
        friendlyFlagMarker:ShowCarrierTooltip()
        return
    end

    ClearFriendlyPlayerTooltip()
    local x, y = GetMousePercent()
    ShowZone(FindZone(x, y))
end)

map:SetScript("OnLeave", function()
    ClearFriendlyPlayerTooltip()
    if not isMoving then
        ShowZone(nil)
    end
end)

map:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and not isMoving and not resizing then
        if ZurkMapsPlayerIcons then
            local testPlayers = ZurkMapsWSGTestSim.GetPlayersUnderMouse()
            if testPlayers and ZurkMapsPlayerIcons.OpenAssignmentMenuForTestPlayers(self, testPlayers) then
                return
            end
            local friendlyUnits = GetFriendlyPlayerMouseoverUnits()
            if friendlyUnits and ZurkMapsPlayerIcons.OpenAssignmentMenuForUnits(self, friendlyUnits) then
                return
            end
        end

        local x, y = GetMousePercent()
        if not FindZone(x, y) and ZurkMapsOptions then
            ShowZone(nil)
            ZurkMapsOptions.OpenMapMenu("WSG", self)
            return
        end
    end

    if button == "LeftButton"
        and not hoveredFriendlyPlayersSignature
        and hoveredZone
        and not isMoving
        and not resizing then
        Report(hoveredZone.message)
    end
end)


-- Temporary flag-position diagnostics for the WSG test build.
-- The watcher automatically turns on when entering WSG and only prints when
-- Blizzard's returned flag-position data changes.
local flagWatchEnabled = false
local flagWatchElapsed = 0
local lastFlagSnapshot = ""
local wasInWSG = false
local flagDiagnosticEntries = {}
local flagReportFrame
local flagReportEditBox

local function ResetFlagDiagnosticEntries()
    wipe(flagDiagnosticEntries)
    ZurksWSGCalloutMapDB.flagDiagnosticEntries = flagDiagnosticEntries
end

local function LoadFlagDiagnosticEntries()
    if type(ZurksWSGCalloutMapDB.flagDiagnosticEntries) == "table" then
        flagDiagnosticEntries = ZurksWSGCalloutMapDB.flagDiagnosticEntries
    else
        ZurksWSGCalloutMapDB.flagDiagnosticEntries = flagDiagnosticEntries
    end
end

local function RecordFlagDiagnostic(kind, text)
    local stamp = date and date("%H:%M:%S") or tostring(GetTime and math.floor(GetTime()) or "?")
    table.insert(flagDiagnosticEntries, string.format("[%s] %s: %s", stamp, kind, text))
    while #flagDiagnosticEntries > 250 do
        table.remove(flagDiagnosticEntries, 1)
    end
    ZurksWSGCalloutMapDB.flagDiagnosticEntries = flagDiagnosticEntries
end

local function BuildFlagDiagnosticReport()
    if #flagDiagnosticEntries == 0 then
        return "No flag-position diagnostic data has been recorded."
    end
    return table.concat(flagDiagnosticEntries, "\n")
end

local function ShowFlagDiagnosticReport()
    if not flagReportFrame then
        flagReportFrame = CreateFrame(
            "Frame",
            "ZurksWSGFlagDiagnosticReport",
            UIParent,
            BackdropTemplateMixin and "BackdropTemplate" or nil
        )
        flagReportFrame:SetSize(680, 360)
        flagReportFrame:SetPoint("CENTER")
        flagReportFrame:SetFrameStrata("DIALOG")
        flagReportFrame:SetClampedToScreen(true)
        flagReportFrame:SetMovable(true)
        flagReportFrame:EnableMouse(true)
        flagReportFrame:RegisterForDrag("LeftButton")
        flagReportFrame:SetScript("OnDragStart", flagReportFrame.StartMoving)
        flagReportFrame:SetScript("OnDragStop", flagReportFrame.StopMovingOrSizing)

        if flagReportFrame.SetBackdrop then
            flagReportFrame:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            flagReportFrame:SetBackdropColor(0.03, 0.03, 0.03, 0.98)
            flagReportFrame:SetBackdropBorderColor(0.70, 0.52, 0.20, 1)
        end

        local title = flagReportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", flagReportFrame, "TOPLEFT", 14, -12)
        title:SetText("WSG Flag Position Diagnostic Report")

        local instructions = flagReportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instructions:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
        instructions:SetText("Click the text, press CTRL+A, then CTRL+C and paste it into ChatGPT.")

        local scroll = CreateFrame("ScrollFrame", nil, flagReportFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", flagReportFrame, "TOPLEFT", 14, -58)
        scroll:SetPoint("BOTTOMRIGHT", flagReportFrame, "BOTTOMRIGHT", -34, 45)

        flagReportEditBox = CreateFrame("EditBox", nil, scroll)
        flagReportEditBox:SetMultiLine(true)
        flagReportEditBox:SetAutoFocus(false)
        flagReportEditBox:SetFontObject(ChatFontNormal)
        flagReportEditBox:SetWidth(620)
        flagReportEditBox:SetScript("OnEscapePressed", function() flagReportFrame:Hide() end)
        scroll:SetScrollChild(flagReportEditBox)

        local close = CreateFrame("Button", nil, flagReportFrame, "UIPanelButtonTemplate")
        close:SetSize(90, 24)
        close:SetPoint("BOTTOMRIGHT", flagReportFrame, "BOTTOMRIGHT", -12, 12)
        close:SetText("Close")
        close:SetScript("OnClick", function() flagReportFrame:Hide() end)
    end

    local report = BuildFlagDiagnosticReport()
    flagReportEditBox:SetText(report)
    flagReportEditBox:SetHeight(math.max(250, flagReportEditBox:GetStringHeight() + 20))
    flagReportFrame:Show()
    flagReportEditBox:SetFocus()
    flagReportEditBox:HighlightText()
end

local function Coord(value)
    if type(value) == "number" then
        return string.format("%.4f", value)
    end
    return "nil"
end

local function GetLegacyFlagSnapshot()
    if type(GetBattlefieldFlagPosition) ~= "function" then
        return "legacy=unavailable"
    end

    local count = nil
    if type(GetNumBattlefieldFlagPositions) == "function" then
        local ok, value = pcall(GetNumBattlefieldFlagPositions)
        if ok then count = value end
    end

    local scanCount = (type(count) == "number" and count > 0) and count or 4
    local found = {}

    for i = 1, scanCount do
        local ok, x, y, token = pcall(GetBattlefieldFlagPosition, i)
        if ok and (x ~= nil or y ~= nil or token ~= nil) then
            table.insert(found, string.format(
                "%d=%s(%s,%s)",
                i,
                tostring(token),
                Coord(x),
                Coord(y)
            ))
        end
    end

    local countText = count == nil and "?" or tostring(count)
    if #found == 0 then
        return "legacy count=" .. countText .. " [none]"
    end
    return "legacy count=" .. countText .. " [" .. table.concat(found, "; ") .. "]"
end

local function GetModernFlagSnapshot()
    if not C_PvP or type(C_PvP.GetBattlefieldFlagPosition) ~= "function" then
        return "cpvp=unavailable"
    end
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" then
        return "cpvp map=nil"
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return "cpvp map=nil"
    end

    local found = {}
    for i = 1, 4 do
        local ok, x, y, texture = pcall(C_PvP.GetBattlefieldFlagPosition, i, mapID)
        if ok and (x ~= nil or y ~= nil or texture ~= nil) then
            table.insert(found, string.format(
                "%d=%s(%s,%s)",
                i,
                tostring(texture),
                Coord(x),
                Coord(y)
            ))
        end
    end

    if #found == 0 then
        return "cpvp map=" .. tostring(mapID) .. " [none]"
    end
    return "cpvp map=" .. tostring(mapID) .. " [" .. table.concat(found, "; ") .. "]"
end

local function GetFlagSnapshot()
    return GetLegacyFlagSnapshot() .. " | " .. GetModernFlagSnapshot()
end

local function PrintFlagSnapshot(prefix)
    local snapshot = GetFlagSnapshot()
    RecordFlagDiagnostic(prefix or "flag API", snapshot)
    print("|cff33ff99Zurk Maps|r " .. (prefix or "flag API") .. ": " .. snapshot)
end

local flagWatchFrame = CreateFrame("Frame", nil, frame)
flagWatchFrame:Hide()
flagWatchFrame:SetScript("OnUpdate", function(self, elapsed)
    if not flagWatchEnabled then return end

    flagWatchElapsed = flagWatchElapsed + elapsed
    if flagWatchElapsed < 0.5 then return end
    flagWatchElapsed = 0

    local snapshot = GetFlagSnapshot()
    if snapshot ~= lastFlagSnapshot then
        lastFlagSnapshot = snapshot
        RecordFlagDiagnostic("flag change", snapshot)
    end
end)

local manualVisibility = nil
local pendingVisibilityUpdate = false

local function IsInWarsongGulch()
    local instanceName = nil

    if GetInstanceInfo then
        instanceName = GetInstanceInfo()
    end

    local realZone = GetRealZoneText and GetRealZoneText() or nil
    local zone = GetZoneText and GetZoneText() or nil

    return instanceName == "Warsong Gulch"
        or realZone == "Warsong Gulch"
        or zone == "Warsong Gulch"
end

local function CleanCarrierName(name)
    if not name then return nil end
    name = name:gsub("!+$", "")
    name = name:match("^%s*(.-)%s*$")
    if name == "" then return nil end
    return name
end

local function HandleBGSystemMessage(msg)
    if not IsInWarsongGulch() or not msg then return end

    RecordFlagDiagnostic("BG event", msg)
    local lmsg = msg:lower()

    if lmsg:find("the alliance flag was picked up by ", 1, true) then
        hordeFlagCarrier = CleanCarrierName(msg:match("[Tt]he [Aa]lliance [Ff]lag was picked up by (.+)"))
        UpdateTargetButtons()
        return
    end

    if lmsg:find("the horde flag was picked up by ", 1, true) then
        allianceFlagCarrier = CleanCarrierName(msg:match("[Tt]he [Hh]orde [Ff]lag was picked up by (.+)"))
        UpdateTargetButtons()
        return
    end

    -- Older/alternate English wording used by some Classic clients.
    local olderAlliance = CleanCarrierName(msg:match("^(.+) picked up the [Aa]lliance'?s? [Ff]lag!?$"))
    if olderAlliance then
        hordeFlagCarrier = olderAlliance
        UpdateTargetButtons()
        return
    end

    local olderHorde = CleanCarrierName(msg:match("^(.+) picked up the [Hh]orde'?s? [Ff]lag!?$"))
    if olderHorde then
        allianceFlagCarrier = olderHorde
        UpdateTargetButtons()
        return
    end

    if lmsg:find("the alliance flag was dropped", 1, true)
        or lmsg:find("the alliance flag was returned", 1, true)
        or lmsg:find("captured the alliance flag", 1, true)
        or lmsg:find("alliance flag was captured by", 1, true) then
        hordeFlagCarrier = nil
        UpdateTargetButtons()
        return
    end

    if lmsg:find("the horde flag was dropped", 1, true)
        or lmsg:find("the horde flag was returned", 1, true)
        or lmsg:find("captured the horde flag", 1, true)
        or lmsg:find("horde flag was captured by", 1, true) then
        allianceFlagCarrier = nil
        UpdateTargetButtons()
        return
    end
end

local function ClearFlagCarriers()
    allianceFlagCarrier = nil
    hordeFlagCarrier = nil
    UpdateTargetButtons()
end

local function UpdateVisibility()
    local inWSG = IsInWarsongGulch()

    -- The carrier targeting buttons use SecureActionButtonTemplate, which makes
    -- their parent hierarchy protected. Defer visibility changes until combat ends
    -- instead of calling Show()/Hide() on the protected addon frame in combat.
    if InCombatLockdown and InCombatLockdown() then
        pendingVisibilityUpdate = true
        return false
    end

    pendingVisibilityUpdate = false

    if wsgTestMode then
        frame:Show()
    elseif manualVisibility == "show" then
        frame:Show()
    elseif manualVisibility == "hide" then
        frame:Hide()
    elseif inWSG then
        frame:Show()
    else
        frame:Hide()
    end

    frame.ApplyWSGHonorBarVisibility()

    if wsgTestMode then
        if friendlyPlayersFrame then
            friendlyPlayersFrame:Hide()
        end
        if ShowWSGTestBlips then
            ShowWSGTestBlips()
        end
    elseif inWSG then
        if HideWSGTestBlips then
            HideWSGTestBlips()
        end
        if friendlyPlayersFrameAvailable then
            ConfigureFriendlyPlayerDots()
            friendlyPlayersFrame:Show()
        end
    else
        if friendlyPlayersFrame then
            friendlyPlayersFrame:Hide()
        end
        if HideWSGTestBlips then
            HideWSGTestBlips()
        end
    end

    if inWSG and not wasInWSG then
        -- Live flag-marker tracking runs silently. The diagnostic watcher is
        -- now manual through /wsg flagwatch if troubleshooting is needed.
        flagWatchEnabled = false
        flagWatchFrame:Hide()
        flagWatchElapsed = 0
        lastFlagSnapshot = ""
    elseif not inWSG and wasInWSG then
        flagWatchEnabled = false
        flagWatchFrame:Hide()
        lastFlagSnapshot = ""
        friendlyFlagMarker:Hide()
        ClearFlagCarriers()
    end

    wasInWSG = inWSG
    return true
end

local function StartWSGTestMode()
    wsgTestMode = true
    ZurkMapsWSGTestSim.Randomize()
    if not (InCombatLockdown and InCombatLockdown()) then
        friendlyTargetButton:SetAttribute("type1", "macro")
        friendlyTargetButton:SetAttribute("unit", nil)
        friendlyTargetButton:SetAttribute("macrotext1", "")
        enemyTargetButton:SetAttribute("type1", "macro")
        enemyTargetButton:SetAttribute("unit", nil)
        enemyTargetButton:SetAttribute("macrotext1", "")
        friendlyTargetButton.targetReady = false
        enemyTargetButton.targetReady = false
    end
    if friendlyPlayersFrame then
        friendlyPlayersFrame:Hide()
    end
    if ShowWSGTestBlips then
        ShowWSGTestBlips()
    end
    UpdateFriendlyFlagMarker()
    if UpdateCarrierFrameVisuals then
        UpdateCarrierFrameVisuals(true)
    end
    UpdateVisibility()
    print("|cff33ff99Zurk Maps|r WSG test mode: 10 moving gold friendly blips with generated Horde names, simulated friendly FC, and simulated EFC enabled.")
end

local function ClearWSGTestMode(silent, deferVisibility)
    wsgTestMode = false
    if HideWSGTestBlips then
        HideWSGTestBlips()
    end
    friendlyFlagMarker:Hide()
    UpdateTargetButtons()
    if not deferVisibility then
        UpdateVisibility()
    end
    if not silent then
        print("|cff33ff99Zurk Maps|r WSG test mode stopped; live data restored.")
    end
end

local function ResetLayout()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetScale(1)
    UpdateMoveHandleScale(1)
    SaveLayout()
end

local function PrintWSGOptions()
    print("|cff33ff99Zurk Maps|r commands:")
    print("|cffffff00/wsg hide|r - Hide Zurk Maps.")
    print("|cffffff00/wsg show|r - Show Zurk Maps.")
    print("|cffffff00/wsg reset|r - Reset saved position and size.")
    print("|cffffff00/wsg test|r - Show 10 moving gold friendly blips plus friendly/enemy FC test data.")
    print("|cffffff00/wsg test off|r - Stop WSG simulation and restore live data.")
    print("|cffffff00/wsg clear|r - Clear detected flag carriers.")
    print("|cffffff00/wsg flagreport|r - Open the saved flag-position test report.")
end

SLASH_WSGCALLOUTS1 = "/wsg"

SlashCmdList["WSGCALLOUTS"] = function(msg)
    msg = string.lower((msg or ""):match("^%s*(.-)%s*$"))

    if msg == "test" then
        StartWSGTestMode()
    elseif msg == "test off" or msg == "test clear" then
        ClearWSGTestMode()
    elseif msg == "hide" then
        if wsgTestMode then
            ClearWSGTestMode(true, true)
        end
        manualVisibility = "hide"
        local applied = UpdateVisibility()
        print("|cff33ff99Zurk Maps|r " .. (applied and "hidden." or "will hide after combat."))
    elseif msg == "show" then
        manualVisibility = "show"
        local applied = UpdateVisibility()
        print("|cff33ff99Zurk Maps|r " .. (applied and "shown." or "will show after combat."))
    elseif msg == "reset" then
        ResetLayout()
        print("|cff33ff99Zurk Maps|r position and size reset.")
    elseif msg == "clear" then
        ClearFlagCarriers()
        print("|cff33ff99Zurk Maps|r flag carriers cleared.")
    elseif msg == "flagreport" then
        ShowFlagDiagnosticReport()
    elseif msg == "flagtest" then
        local snapshot = PrintFlagSnapshot("manual snapshot")
        print("|cff33ff99Zurk Maps|r current flag snapshot saved. Use /wsg flagreport to review.")
    elseif msg == "flagwatch" then
        flagWatchEnabled = not flagWatchEnabled
        flagWatchFrame:SetShown(flagWatchEnabled)
        lastFlagSnapshot = ""
        flagWatchElapsed = 0
        print("|cff33ff99Zurk Maps|r flag watch " .. (flagWatchEnabled and "ON." or "OFF."))
        if flagWatchEnabled then
            PrintFlagSnapshot()
        end
    else
        PrintWSGOptions()
    end
end

if ZurkMapsOptions then
    ZurkMapsOptions.RegisterMap("WSG", {
        frame = frame,
        mapTexture = mapTexture,
        refreshBlips = function() ConfigureFriendlyPlayerDots(); if UpdateWSGTestBlips then UpdateWSGTestBlips() end end,
        title = "Warsong Gulch",
        db = ZurksWSGCalloutMapDB,
        closeCommand = "hide",
        runCommand = function(command) SlashCmdList["WSGCALLOUTS"](command or "") end,
        isTestModeActive = function() return wsgTestMode end,
        isHonorBarVisible = function() return frame.IsWSGHonorBarVisible() end,
        setHonorBarVisible = function(value) frame.SetWSGHonorBarVisible(value) end,
        getHonorBarMode = function() return frame.GetWSGHonorBarMode() end,
        setHonorBarMode = function(mode) if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMode then ZurkMapsHonorWidget.SetMode(mode, "WSG") end end,
        isHonorBarUnlocked = function() return frame.IsWSGHonorBarUnlocked() end,
        setHonorBarUnlocked = function(value) frame.SetWSGHonorBarUnlocked(value) end,
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
frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            LoadFlagDiagnosticEntries()
            RestoreLayout()
            UpdateTargetButtons()
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

    if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"
        or event == "CHAT_MSG_BG_SYSTEM_HORDE"
        or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        HandleBGSystemMessage(...)
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        if IsInWarsongGulch() and friendlyPlayersFrameAvailable then
            ConfigureFriendlyPlayerDots()
            friendlyPlayersFrame:Show()
        end
        if UpdateCarrierFrameVisuals then
            UpdateCarrierFrameVisuals(true)
        end
        return
    end

    if event == "UPDATE_BATTLEFIELD_SCORE" then
        if UpdateCarrierFrameVisuals then
            UpdateCarrierFrameVisuals(true)
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if pendingTargetAttributeUpdate then
            ApplyTargetAttributes()
        end
        if pendingVisibilityUpdate then
            UpdateVisibility()
        end
        return
    end

    if event == "PLAYER_LOGOUT" then
        SaveLayout()
    end
end)

-- The frame starts hidden near creation time, before secure child buttons are added.
-- Zone events will show it automatically in WSG.
