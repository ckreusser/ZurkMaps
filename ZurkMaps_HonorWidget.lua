-- Shared honor-bar controller for WSG, AB, and AV.
-- Credit: the action-button glow treatment is recreated from the WeakAuras /
-- LibCustomGlow visual approach; Zurk Maps does not require either addon.
-- One global state drives all three map-specific renderers so the Honor Bar
-- behaves like one Zurk Maps feature instead of three independent widgets.
ZurkMapsHonorWidget = ZurkMapsHonorWidget or {}

local Widget = ZurkMapsHonorWidget
Widget.bars = Widget.bars or {}
Widget.byMap = Widget.byMap or {}
Widget.mapShown = Widget.mapShown or {}

ZurkMapsHonorDB = ZurkMapsHonorDB or {}

local MAP_ORDER = { "WSG", "AB", "AV" }
local VALID_MODES = { OFF = true, ATTACHED = true, PERSISTENT = true }

local function Clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function GetCursorUIPosition()
    if not GetCursorPosition then return nil, nil end
    local x, y = GetCursorPosition()
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not scale or scale == 0 then scale = 1 end
    return x / scale, y / scale
end

local function CopyLegacyState(state, legacy)
    if type(legacy) ~= "table" then return end
    if legacy.unlocked ~= nil and state.unlocked == nil then state.unlocked = legacy.unlocked and true or false end
    if legacy.orientation == "HORIZONTAL" or legacy.orientation == "VERTICAL" then
        if not state.persistentOrientation then state.persistentOrientation = legacy.orientation end
    end
    if legacy.point and state.point == nil then
        state.point = legacy.point
        state.relativePoint = legacy.relativePoint
        state.x = legacy.x
        state.y = legacy.y
        state.width = legacy.width
        state.height = legacy.height
    end
end

local function EnsureState()
    ZurkMapsHonorDB = ZurkMapsHonorDB or {}
    ZurkMapsHonorDB.widget = ZurkMapsHonorDB.widget or {}
    local state = ZurkMapsHonorDB.widget

    if tonumber(state.schemaVersion) ~= 3 then
        local legacyDBs = {
            WSG = _G.ZurksWSGCalloutMapDB,
            AB = _G.ZurksABCalloutMapDB,
            AV = _G.ZurksAVCalloutMapDB,
        }
        local anyShown = false
        local detachedKey = nil
        for _, key in ipairs(MAP_ORDER) do
            local db = legacyDBs[key]
            if type(db) == "table" then
                if db.showHonorBar ~= false then anyShown = true end
                if type(db.honorWidget) == "table" then
                    CopyLegacyState(state, db.honorWidget)
                    if db.honorWidget.detached then detachedKey = detachedKey or key end
                end
            end
        end

        if not VALID_MODES[state.mode] then
            if detachedKey then
                state.mode = "PERSISTENT"
                state.hostMapKey = detachedKey
            elseif anyShown then
                state.mode = "ATTACHED"
            else
                state.mode = "OFF"
            end
        end
        state.schemaVersion = 3
    end

    if not VALID_MODES[state.mode] then state.mode = "ATTACHED" end
    state.unlocked = state.unlocked and true or false
    if state.persistentOrientation ~= "HORIZONTAL" then state.persistentOrientation = "VERTICAL" end
    if state.mode == "PERSISTENT" then
        state.orientation = state.persistentOrientation
        state.detached = true
    else
        state.orientation = "VERTICAL"
        state.detached = false
    end
    return state
end

function Widget.GetState()
    return EnsureState()
end

function Widget.GetMode()
    return EnsureState().mode
end

local function CaptureDock(bar)
    if not bar or bar._honorDockCaptured then return end
    bar._honorDockCaptured = true
    bar._honorDockParent = bar:GetParent()
    bar._honorDockPoints = {}
    for i = 1, bar:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = bar:GetPoint(i)
        bar._honorDockPoints[#bar._honorDockPoints + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
    bar._honorDockWidth = bar:GetWidth()
    bar._honorDockHeight = bar:GetHeight()
end

local function RestoreDockPoints(bar)
    if not bar then return end
    CaptureDock(bar)
    if bar._honorDockParent and bar.SetParent then bar:SetParent(bar._honorDockParent) end
    bar:SetAlpha(1)
    if bar.SetScale then bar:SetScale(1) end
    bar:ClearAllPoints()
    for _, data in ipairs(bar._honorDockPoints or {}) do
        bar:SetPoint(data.point, data.relativeTo, data.relativePoint, data.x, data.y)
    end
    if bar._honorDockWidth then bar:SetWidth(bar._honorDockWidth) end
    if bar._honorDockHeight and #((bar._honorDockPoints) or {}) < 2 then bar:SetHeight(bar._honorDockHeight) end
end

local function SavePersistentPoint(bar)
    local state = EnsureState()
    if not bar then return end
    local point, _, relativePoint, x, y = bar:GetPoint(1)
    state.point = point or "CENTER"
    state.relativePoint = relativePoint or state.point
    state.x = tonumber(x) or 0
    state.y = tonumber(y) or 0
    state.width = bar:GetWidth()
    state.height = bar:GetHeight()
end

local function GetInfo(bar)
    return bar and Widget.bars[bar] or nil
end

local function GetCurrentBattlegroundMapKey()
    local instanceName = GetInstanceInfo and GetInstanceInfo() or nil
    local realZone = GetRealZoneText and GetRealZoneText() or nil
    local zone = GetZoneText and GetZoneText() or nil
    local name = instanceName or realZone or zone
    if name == "Warsong Gulch" then return "WSG" end
    if name == "Arathi Basin" then return "AB" end
    if name == "Alterac Valley" then return "AV" end
    if realZone == "Warsong Gulch" or zone == "Warsong Gulch" then return "WSG" end
    if realZone == "Arathi Basin" or zone == "Arathi Basin" then return "AB" end
    if realZone == "Alterac Valley" or zone == "Alterac Valley" then return "AV" end
    return nil
end

local function IsMapShown(key)
    local bar = Widget.byMap[key]
    local info = bar and GetInfo(bar) or nil
    if info and info.mapFrame and info.mapFrame.IsShown then
        return info.mapFrame:IsShown() and true or false
    end
    return Widget.mapShown[key] and true or false
end

local function ChooseAttachedMap(preferred)
    local state = EnsureState()
    if preferred and Widget.byMap[preferred] and IsMapShown(preferred) then return preferred end
    local current = GetCurrentBattlegroundMapKey()
    if current and Widget.byMap[current] and IsMapShown(current) then return current end
    if state.activeMapKey and Widget.byMap[state.activeMapKey] and IsMapShown(state.activeMapKey) then
        return state.activeMapKey
    end
    for _, key in ipairs(MAP_ORDER) do
        if Widget.byMap[key] and IsMapShown(key) then return key end
    end
    return nil
end

local function ChoosePersistentHost(preferred)
    local state = EnsureState()
    if preferred and Widget.byMap[preferred] then return preferred end
    if state.hostMapKey and Widget.byMap[state.hostMapKey] then return state.hostMapKey end
    if state.activeMapKey and Widget.byMap[state.activeMapKey] then return state.activeMapKey end
    local current = GetCurrentBattlegroundMapKey()
    if current and Widget.byMap[current] then return current end
    for _, key in ipairs(MAP_ORDER) do
        if Widget.byMap[key] then return key end
    end
    return nil
end

local function ApplyPersistentSizeLimits(bar, width, height)
    local state = EnsureState()
    local horizontal = state.orientation == "HORIZONTAL"
    if horizontal then
        width = Clamp(width, 90, 1000)
        height = Clamp(height, 8, 120)
    else
        width = Clamp(width, 8, 120)
        height = Clamp(height, 90, 1000)
    end
    bar:SetSize(width, height)
end

local function PlacePersistentFromSaved(bar)
    if not bar then return end
    local state = EnsureState()
    if bar.SetParent then bar:SetParent(UIParent) end
    bar:SetAlpha(ZurkMapsOptions and ZurkMapsOptions.GetFrameOpacity() or 1)
    if bar.SetScale then bar:SetScale(1) end
    bar:ClearAllPoints()
    bar:SetPoint(state.point or "CENTER", UIParent, state.relativePoint or state.point or "CENTER", tonumber(state.x) or 0, tonumber(state.y) or 0)
    local width = tonumber(state.width)
    local height = tonumber(state.height)
    if not width or not height then
        local info = GetInfo(bar)
        width = (info and info.persistentDefaultWidth) or math.max(18, bar._honorDockWidth or bar:GetWidth())
        height = (info and info.persistentDefaultHeight) or math.max(260, bar._honorDockHeight or bar:GetHeight())
        if state.orientation == "HORIZONTAL" then width, height = height, width end
    end
    ApplyPersistentSizeLimits(bar, width, height)
end

local function DetachPreservingPosition(bar)
    if not bar then return end
    local state = EnsureState()
    CaptureDock(bar)

    local oldScale = (bar.GetEffectiveScale and bar:GetEffectiveScale()) or 1
    local uiScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if not oldScale or oldScale == 0 then oldScale = 1 end
    if not uiScale or uiScale == 0 then uiScale = 1 end
    local left, bottom = bar:GetLeft(), bar:GetBottom()
    local width, height = bar:GetWidth(), bar:GetHeight()
    local screenLeft = left and ((left * oldScale) / uiScale) or nil
    local screenBottom = bottom and ((bottom * oldScale) / uiScale) or nil
    local screenWidth = math.max(1, (width * oldScale) / uiScale)
    local screenHeight = math.max(1, (height * oldScale) / uiScale)

    if bar.SetParent then bar:SetParent(UIParent) end
    bar:SetAlpha(ZurkMapsOptions and ZurkMapsOptions.GetFrameOpacity() or 1)
    if bar.SetScale then bar:SetScale(1) end
    bar:ClearAllPoints()
    if screenLeft and screenBottom then
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", screenLeft, screenBottom)
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    bar:SetSize(screenWidth, screenHeight)

    local info = GetInfo(bar)
    state.mode = "PERSISTENT"
    state.detached = true
    state.hostMapKey = info and info.mapKey or state.hostMapKey
    state.orientation = state.persistentOrientation or "VERTICAL"
    SavePersistentPoint(bar)
end

local function RefreshBar(bar)
    local info = GetInfo(bar)
    local honorModule = info and info.honorModule or nil
    if honorModule and honorModule.Refresh then honorModule.Refresh(true) end
end

local function FindBreakpointBounds(bar, requiredHonor)
    requiredHonor = tonumber(requiredHonor)
    if not bar or not requiredHonor then return nil end
    for _, bounds in ipairs(bar.segmentBounds or {}) do
        local milestoneHonor = tonumber(bounds.milestone and bounds.milestone.honor)
        if milestoneHonor and math.abs(milestoneHonor - requiredHonor) < 0.5 then
            return bounds
        end
    end
    return nil
end

local AnimateGlowTexCoords = (TextureUtil and TextureUtil.AnimateTexCoords) or _G.AnimateTexCoords

-- WeakAuras' "Action Button Glow" is LibCustomGlow's ButtonGlow treatment:
-- one SpellActivationOverlay rectangle stretched to the target frame, with the
-- animated "ants" texture running around its edge. Keep a small local version
-- here instead of depending on WeakAuras/LibCustomGlow being installed.
local function CreateGlowScaleAnim(group, target, order, duration, x, y, delay)
    local anim = group:CreateAnimation("Scale")
    anim:SetChildKey(target)
    anim:SetOrder(order)
    anim:SetDuration(duration)
    anim:SetScale(x, y)
    if delay then anim:SetStartDelay(delay) end
    return anim
end

local function CreateGlowAlphaAnim(group, target, order, duration, fromAlpha, toAlpha, delay)
    local anim = group:CreateAnimation("Alpha")
    anim:SetChildKey(target)
    anim:SetOrder(order)
    anim:SetDuration(duration)
    anim:SetFromAlpha(fromAlpha)
    anim:SetToAlpha(toAlpha)
    if delay then anim:SetStartDelay(delay) end
    return anim
end

local function ConfigureBreakpointActionGlow(frame)
    if frame._configured then return end
    frame._configured = true

    frame.spark = frame:CreateTexture(nil, "BACKGROUND")
    frame.spark:SetPoint("CENTER")
    frame.spark:SetAlpha(0)
    frame.spark:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    frame.spark:SetTexCoord(0.00781250, 0.61718750, 0.00390625, 0.26953125)

    frame.innerGlow = frame:CreateTexture(nil, "ARTWORK")
    frame.innerGlow:SetPoint("CENTER")
    frame.innerGlow:SetAlpha(0)
    frame.innerGlow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    frame.innerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

    frame.innerGlowOver = frame:CreateTexture(nil, "ARTWORK")
    frame.innerGlowOver:SetPoint("TOPLEFT", frame.innerGlow, "TOPLEFT")
    frame.innerGlowOver:SetPoint("BOTTOMRIGHT", frame.innerGlow, "BOTTOMRIGHT")
    frame.innerGlowOver:SetAlpha(0)
    frame.innerGlowOver:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    frame.innerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

    frame.outerGlow = frame:CreateTexture(nil, "ARTWORK")
    frame.outerGlow:SetPoint("CENTER")
    frame.outerGlow:SetAlpha(0)
    frame.outerGlow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    frame.outerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

    frame.outerGlowOver = frame:CreateTexture(nil, "ARTWORK")
    frame.outerGlowOver:SetPoint("TOPLEFT", frame.outerGlow, "TOPLEFT")
    frame.outerGlowOver:SetPoint("BOTTOMRIGHT", frame.outerGlow, "BOTTOMRIGHT")
    frame.outerGlowOver:SetAlpha(0)
    frame.outerGlowOver:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    frame.outerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

    frame.ants = frame:CreateTexture(nil, "OVERLAY")
    frame.ants:SetPoint("CENTER")
    frame.ants:SetAlpha(0)
    frame.ants:SetTexture("Interface\\SpellActivationOverlay\\IconAlertAnts")

    local gold = {1.0, 0.86, 0.18, 1.0}
    for _, tex in ipairs({frame.spark, frame.innerGlow, frame.innerGlowOver, frame.outerGlow, frame.outerGlowOver, frame.ants}) do
        tex:SetDesaturated(true)
        tex:SetVertexColor(gold[1], gold[2], gold[3], gold[4])
    end

    frame.animIn = frame:CreateAnimationGroup()
    CreateGlowScaleAnim(frame.animIn, "spark",         1, 0.20, 1.5, 1.5)
    CreateGlowAlphaAnim(frame.animIn, "spark",         1, 0.20, 0, 1)
    CreateGlowScaleAnim(frame.animIn, "innerGlow",     1, 0.30, 2, 2)
    CreateGlowScaleAnim(frame.animIn, "innerGlowOver", 1, 0.30, 2, 2)
    CreateGlowAlphaAnim(frame.animIn, "innerGlowOver", 1, 0.30, 1, 0)
    CreateGlowScaleAnim(frame.animIn, "outerGlow",     1, 0.30, 0.5, 0.5)
    CreateGlowScaleAnim(frame.animIn, "outerGlowOver", 1, 0.30, 0.5, 0.5)
    CreateGlowAlphaAnim(frame.animIn, "outerGlowOver", 1, 0.30, 1, 0)
    CreateGlowScaleAnim(frame.animIn, "spark",         1, 0.20, 2/3, 2/3, 0.20)
    CreateGlowAlphaAnim(frame.animIn, "spark",         1, 0.20, 1, 0, 0.20)
    CreateGlowAlphaAnim(frame.animIn, "innerGlow",     1, 0.20, 1, 0, 0.30)
    CreateGlowAlphaAnim(frame.animIn, "ants",          1, 0.20, 0, 1, 0.30)

    frame.animIn:SetScript("OnPlay", function(group)
        local f = group:GetParent()
        local w, h = f:GetSize()
        f.spark:SetSize(w, h)
        f.spark:SetAlpha(1)
        f.innerGlow:SetSize(w / 2, h / 2)
        f.innerGlow:SetAlpha(1)
        f.innerGlowOver:SetAlpha(1)
        f.outerGlow:SetSize(w * 2, h * 2)
        f.outerGlow:SetAlpha(1)
        f.outerGlowOver:SetAlpha(1)
        f.ants:SetSize(w * 0.85, h * 0.85)
        f.ants:SetAlpha(0)
    end)
    frame.animIn:SetScript("OnFinished", function(group)
        local f = group:GetParent()
        local w, h = f:GetSize()
        f.spark:SetAlpha(0)
        f.innerGlow:SetAlpha(0)
        f.innerGlow:SetSize(w, h)
        f.innerGlowOver:SetAlpha(0)
        f.outerGlow:SetSize(w, h)
        f.outerGlowOver:SetAlpha(0)
        f.outerGlowOver:SetSize(w, h)
        f.ants:SetSize(w * 0.85, h * 0.85)
        f.ants:SetAlpha(1)
    end)

    frame.animOut = frame:CreateAnimationGroup()
    CreateGlowAlphaAnim(frame.animOut, "outerGlowOver", 1, 0.20, 0, 1)
    CreateGlowAlphaAnim(frame.animOut, "ants",          1, 0.20, 1, 0)
    CreateGlowAlphaAnim(frame.animOut, "outerGlowOver", 2, 0.20, 1, 0)
    CreateGlowAlphaAnim(frame.animOut, "outerGlow",     2, 0.20, 1, 0)
    frame.animOut:SetScript("OnFinished", function(group)
        group:GetParent():Hide()
    end)

    frame:SetScript("OnUpdate", function(self, elapsed)
        if AnimateGlowTexCoords and self.ants and self.ants:IsShown() then
            AnimateGlowTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed or 0, 0.01)
        end
    end)
end

local function SetActionGlowEdgeFrame(tex, frameIndex, edge)
    if not tex then return end

    -- IconAlertAnts is a 5x5 sheet of 48x48 cells (22 live frames).
    -- Instead of stretching the full square alert across a long honor segment,
    -- crop the animated border out of each frame and stretch only that edge.
    local sheet = 256
    local cell = 48
    local col = frameIndex % 5
    local row = math.floor(frameIndex / 5)
    local cellLeft = col * cell
    local cellTop = row * cell

    local x1, x2, y1, y2
    if edge == "TOP" then
        x1, x2, y1, y2 = 8, 40, 2, 13
    elseif edge == "BOTTOM" then
        x1, x2, y1, y2 = 8, 40, 35, 46
    elseif edge == "LEFT" then
        x1, x2, y1, y2 = 2, 13, 8, 40
    else -- RIGHT
        x1, x2, y1, y2 = 35, 46, 8, 40
    end

    tex:SetTexCoord(
        (cellLeft + x1) / sheet,
        (cellLeft + x2) / sheet,
        (cellTop + y1) / sheet,
        (cellTop + y2) / sheet
    )
end

local function EnsureBreakpointGlow(bar)
    if bar._honorBreakpointGlow then return bar._honorBreakpointGlow end

    local holder = CreateFrame("Frame", nil, bar)
    holder:EnableMouse(false)
    holder:SetFrameStrata(bar:GetFrameStrata())
    holder:SetFrameLevel(bar:GetFrameLevel() + 60)
    if holder.SetClipsChildren then holder:SetClipsChildren(true) end
    holder:Hide()

    -- Two phase-offset Action Button Glow passes make the completed segment
    -- feel denser and more celebratory without increasing animation speed.
    holder._edgePasses = {}
    local passColors = {
        {1.00, 0.78, 0.04, 1.00}, -- hot gold
        {1.00, 0.98, 0.52, 0.78}, -- pale-gold highlight
    }
    for pass = 1, 2 do
        local edges = {}
        for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local tex = holder:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetTexture("Interface\\SpellActivationOverlay\\IconAlertAnts")
            tex:SetBlendMode("ADD")
            tex:SetDesaturated(true)
            local c = passColors[pass]
            tex:SetVertexColor(c[1], c[2], c[3], c[4])
            edges[edge] = tex
        end
        holder._edgePasses[pass] = edges
    end

    -- Stronger static inner-gold silhouette underneath the moving ants.
    holder._underlay = {}
    for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local tex = holder:CreateTexture(nil, "ARTWORK", nil, 6)
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetBlendMode("ADD")
        tex:SetVertexColor(1.0, 0.56, 0.02, 0.46)
        holder._underlay[edge] = tex
    end

    holder:SetScript("OnUpdate", function(self, elapsed)
        self._elapsed = (self._elapsed or 0) + (elapsed or 0)
        local duration = tonumber(self._duration) or 4.0
        -- Preserve the same frame cadence as R5a; the second pass only changes
        -- phase/density, not how fast the Action Button Glow moves.
        local baseFrame = math.floor((self._elapsed / 0.03)) % 22
        local phaseOffsets = {0, 11}

        for pass, edges in ipairs(self._edgePasses or {}) do
            local frameIndex = (baseFrame + (phaseOffsets[pass] or 0)) % 22
            for edge, tex in pairs(edges) do
                SetActionGlowEdgeFrame(tex, frameIndex, edge)
            end
        end

        -- Punchier pulse while retaining the existing movement speed.
        local pulse = 0.84 + (0.16 * math.sin(self._elapsed * 7.5))
        local alpha = pulse
        if self._elapsed < 0.10 then
            alpha = alpha * math.max(0, math.min(1, self._elapsed / 0.10))
        elseif self._elapsed > duration - 0.45 then
            alpha = alpha * math.max(0, (duration - self._elapsed) / 0.45)
        end
        self:SetAlpha(alpha)

        if self._elapsed >= duration then
            self:Hide()
            self:SetAlpha(1)
            self._elapsed = 0
        end
    end)

    bar._honorBreakpointGlow = holder
    return holder
end

local function LayoutBreakpointGlow(holder)
    if not holder then return end
    local w, h = holder:GetSize()
    if not w or not h or w <= 0 or h <= 0 then return end

    -- The holder is already inset into the Honor Bar's inner rectangle. Keep
    -- every glow texture entirely inside that holder so no soft edge escapes
    -- beyond the bar frame.
    local edgeThickness = math.max(1, math.min(2, math.floor(math.min(w, h) * 0.16 + 0.5)))
    local animatedThickness = math.min(3, edgeThickness + 1)

    local function AnchorEdge(tex, edge, thickness, inset)
        tex:ClearAllPoints()
        inset = inset or 0
        if edge == "TOP" then
            tex:SetPoint("TOPLEFT", holder, "TOPLEFT", inset, -inset)
            tex:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -inset, -inset)
            tex:SetHeight(thickness)
        elseif edge == "BOTTOM" then
            tex:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", inset, inset)
            tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inset, inset)
            tex:SetHeight(thickness)
        elseif edge == "LEFT" then
            tex:SetPoint("TOPLEFT", holder, "TOPLEFT", inset, -inset)
            tex:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", inset, inset)
            tex:SetWidth(thickness)
        else
            tex:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -inset, -inset)
            tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inset, inset)
            tex:SetWidth(thickness)
        end
    end

    for edge, tex in pairs(holder._underlay or {}) do
        AnchorEdge(tex, edge, edgeThickness, 0)
    end
    for pass, edges in ipairs(holder._edgePasses or {}) do
        local inset = pass == 1 and 0 or 1
        for edge, tex in pairs(edges) do
            AnchorEdge(tex, edge, animatedThickness, inset)
            tex:SetAlpha(1)
        end
    end
end

function Widget.FlashBreakpoint(requiredHonor)
    for bar in pairs(Widget.bars) do
        if bar:IsShown() then
            RefreshBar(bar)
            local bounds = FindBreakpointBounds(bar, requiredHonor)
            if bounds then
                local glow = EnsureBreakpointGlow(bar)
                glow:ClearAllPoints()
                local horizontal = Widget.IsBarHorizontal(bar)
                local lower = tonumber(bounds.lower) or 0
                local upper = tonumber(bounds.upper) or lower
                local span = math.max(3, upper - lower)
                local thickness
                local barInset = 2
                local axisInset = 1
                if horizontal then
                    thickness = math.max(6, bar:GetHeight() or 6)
                    local innerThickness = math.max(3, thickness - (barInset * 2))
                    local innerSpan = math.max(3, span - (axisInset * 2))
                    glow:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", lower + axisInset, barInset)
                    glow:SetSize(innerSpan, innerThickness)
                else
                    thickness = math.max(6, bar:GetWidth() or 6)
                    local innerThickness = math.max(3, thickness - (barInset * 2))
                    local innerSpan = math.max(3, span - (axisInset * 2))
                    glow:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", barInset, lower + axisInset)
                    glow:SetSize(innerThickness, innerSpan)
                end

                LayoutBreakpointGlow(glow)
                glow._elapsed = 0
                glow._duration = 4.0
                glow:SetAlpha(1)
                glow:Show()
                return true
            end
        end
    end
    return false
end

function Widget.RefreshAllVisibility()
    local state = EnsureState()

    if state.mode == "OFF" then
        for bar in pairs(Widget.bars) do
            GameTooltip:Hide()
            bar:Hide()
        end
        return
    end

    if state.mode == "PERSISTENT" then
        local hostKey = ChoosePersistentHost(state.hostMapKey)
        if not hostKey then return end
        state.hostMapKey = hostKey
        state.detached = true
        state.orientation = state.persistentOrientation or "VERTICAL"
        for bar, info in pairs(Widget.bars) do
            if info.mapKey == hostKey then
                if bar:GetParent() ~= UIParent then
                    if state.point and state.width and state.height then
                        PlacePersistentFromSaved(bar)
                    else
                        DetachPreservingPosition(bar)
                    end
                else
                    PlacePersistentFromSaved(bar)
                end
                bar:Show()
                RefreshBar(bar)
                Widget.UpdateControls(bar)
            else
                bar:Hide()
            end
        end
        return
    end

    -- ATTACHED mode: the same global feature follows whichever Zurk Map is active.
    state.detached = false
    state.orientation = "VERTICAL"
    local activeKey = ChooseAttachedMap(state.activeMapKey)
    if activeKey then state.activeMapKey = activeKey end
    for bar, info in pairs(Widget.bars) do
        if activeKey and info.mapKey == activeKey and IsMapShown(activeKey) then
            RestoreDockPoints(bar)
            bar:Show()
            RefreshBar(bar)
            Widget.UpdateControls(bar)
        else
            bar:Hide()
        end
    end
end

function Widget.SetMapShown(mapKey, shown)
    if not mapKey then return end
    Widget.mapShown[mapKey] = shown and true or false
    local state = EnsureState()
    if shown then state.activeMapKey = mapKey end
    Widget.RefreshAllVisibility()
end

function Widget.SetActiveMap(mapKey)
    local state = EnsureState()
    if mapKey and Widget.byMap[mapKey] then state.activeMapKey = mapKey end
    if state.mode == "ATTACHED" then Widget.RefreshAllVisibility() end
end

function Widget.SetMode(mode, preferredMapKey)
    local state = EnsureState()
    mode = VALID_MODES[mode] and mode or "ATTACHED"
    if preferredMapKey and Widget.byMap[preferredMapKey] then state.activeMapKey = preferredMapKey end

    if mode == "OFF" then
        state.mode = "OFF"
        state.detached = false
        Widget.RefreshAllVisibility()
        return
    end

    if mode == "ATTACHED" then
        state.mode = "ATTACHED"
        state.detached = false
        state.orientation = "VERTICAL"
        if preferredMapKey then state.activeMapKey = preferredMapKey end
        Widget.RefreshAllVisibility()
        return
    end

    local hostKey = ChoosePersistentHost(preferredMapKey)
    state.mode = "PERSISTENT"
    state.detached = true
    state.hostMapKey = hostKey
    state.orientation = state.persistentOrientation or "VERTICAL"
    local host = hostKey and Widget.byMap[hostKey] or nil
    if host then
        if state.point and state.width and state.height then
            PlacePersistentFromSaved(host)
        else
            DetachPreservingPosition(host)
        end
    end
    Widget.RefreshAllVisibility()
end

function Widget.CycleMode(preferredMapKey)
    local current = Widget.GetMode()
    if current == "OFF" then
        Widget.SetMode("ATTACHED", preferredMapKey)
    elseif current == "ATTACHED" then
        Widget.SetMode("PERSISTENT", preferredMapKey)
    else
        Widget.SetMode("OFF", preferredMapKey)
    end
    return Widget.GetMode()
end

function Widget.ShouldSuppressBar(bar)
    local state = EnsureState()
    if state.mode == "OFF" then return true end
    if state.mode == "PERSISTENT" then
        local info = GetInfo(bar)
        return not (info and info.mapKey == ChoosePersistentHost(state.hostMapKey))
    end
    local info = GetInfo(bar)
    return not (info and info.mapKey == ChooseAttachedMap(state.activeMapKey))
end

function Widget.SnapToMap(bar, preferredMapKey)
    local info = GetInfo(bar)
    Widget.SetMode("ATTACHED", preferredMapKey or (info and info.mapKey) or nil)
end

function Widget.SetOrientation(bar, orientation)
    local state = EnsureState()
    if state.mode ~= "PERSISTENT" then return end
    orientation = orientation == "HORIZONTAL" and "HORIZONTAL" or "VERTICAL"
    if state.orientation == orientation then return end

    -- Rotate the standalone bar around its center instead of around whatever
    -- saved anchor happened to be in use. This prevents the widget from
    -- jumping across the screen when switching vertical <-> horizontal.
    local centerX, centerY = bar:GetCenter()
    local oldWidth, oldHeight = bar:GetWidth(), bar:GetHeight()
    state.orientation = orientation
    state.persistentOrientation = orientation

    if centerX and centerY then
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
    end

    ApplyPersistentSizeLimits(bar, oldHeight, oldWidth)
    SavePersistentPoint(bar)
    RefreshBar(bar)
    Widget.UpdateControls(bar)
end

function Widget.GetOrientation()
    return EnsureState().orientation or "VERTICAL"
end


function Widget.IsBarHorizontal(bar)
    local state = EnsureState()
    if state.mode == "PERSISTENT" then
        if state.persistentOrientation == "HORIZONTAL" or state.orientation == "HORIZONTAL" then
            return true
        end
    end
    local widgetState = bar and bar._honorWidgetState or nil
    if widgetState and widgetState.mode == "PERSISTENT" and widgetState.orientation == "HORIZONTAL" then
        return true
    end
    local width = bar and bar.GetWidth and (bar:GetWidth() or 0) or 0
    local height = bar and bar.GetHeight and (bar:GetHeight() or 0) or 0
    return width > math.max(24, height * 2)
end

function Widget.SetUnlocked(_, flag)
    local state = EnsureState()
    state.unlocked = flag and true or false
    for bar in pairs(Widget.bars) do Widget.UpdateControls(bar) end
end

function Widget.SetGlobalUnlocked(flag)
    Widget.SetUnlocked(nil, flag)
end

function Widget.IsUnlocked()
    return EnsureState().unlocked and true or false
end

function Widget.IsDetached()
    return EnsureState().mode == "PERSISTENT"
end

local function LayoutResizeGrip(resize, side)
    if not resize then return end
    local grip = resize._honorGrip
    if not grip then return end

    grip:ClearAllPoints()
    grip:SetAllPoints(resize)

    if side == "LEFT" then
        -- Mirror the stock bottom-right grabber into a natural bottom-left corner grip.
        grip:SetTexCoord(1, 0, 0, 1)
        if grip.SetRotation then grip:SetRotation(0) end
    else
        grip:SetTexCoord(0, 1, 0, 1)
        if grip.SetRotation then grip:SetRotation(0) end
    end
end

function Widget.UpdateControls(bar)
    if not bar then return end
    local state = EnsureState()
    local unlocked = state.unlocked
    if bar._honorResizeHandle then
        local resize = bar._honorResizeHandle
        resize:SetShown(unlocked and true or false)
        resize:ClearAllPoints()

        if state.mode == "PERSISTENT" and Widget.IsBarHorizontal(bar) then
            -- Horizontal bars resize from the bottom-left corner.
            resize:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1)
            LayoutResizeGrip(resize, "LEFT")
        else
            -- Vertical (including snapped) bars resize from the bottom-right corner.
            resize:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
            LayoutResizeGrip(resize, "RIGHT")
        end
    end
end

local function DistanceToDockForKey(bar, mapKey)
    local dockBar = Widget.byMap[mapKey]
    local info = dockBar and GetInfo(dockBar) or nil
    local dock = dockBar and dockBar._honorDockParent or nil
    if not dock or not info or not IsMapShown(mapKey) or not dock.GetLeft then return math.huge end

    local right = bar:GetRight()
    local mapLeft = dock:GetLeft()
    local _, cy = bar:GetCenter()
    local _, my = dock:GetCenter()
    if not right or not mapLeft or not cy or not my then return math.huge end

    local barScale = (bar.GetEffectiveScale and bar:GetEffectiveScale()) or 1
    local mapScale = (dock.GetEffectiveScale and dock:GetEffectiveScale()) or 1
    local uiScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if not uiScale or uiScale == 0 then uiScale = 1 end
    local dx = math.abs((right * barScale) - (mapLeft * mapScale)) / uiScale
    local dy = math.abs((cy * barScale) - (my * mapScale)) / uiScale
    return math.sqrt((dx * dx) + ((dy * 0.35) * (dy * 0.35)))
end

local function FindNearestDock(bar)
    local bestKey, bestDistance = nil, math.huge
    for _, key in ipairs(MAP_ORDER) do
        local distance = DistanceToDockForKey(bar, key)
        if distance < bestDistance then
            bestKey, bestDistance = key, distance
        end
    end
    return bestKey, bestDistance
end

local function StartMoving(bar)
    local state = EnsureState()
    if not state.unlocked then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if state.mode ~= "PERSISTENT" then
        -- A snapped honor bar is always vertical. Dragging it free should keep
        -- the orientation the player is actually looking at instead of
        -- unexpectedly restoring an older standalone orientation.
        state.persistentOrientation = state.orientation or "VERTICAL"
        DetachPreservingPosition(bar)
        state.mode = "PERSISTENT"
        state.hostMapKey = (GetInfo(bar) and GetInfo(bar).mapKey) or state.hostMapKey
        Widget.RefreshAllVisibility()
    end
    bar:StartMoving()
end

local function StopMoving(bar)
    local state = EnsureState()
    if not state.unlocked then return end
    bar:StopMovingOrSizing()
    local nearestKey, distance = FindNearestDock(bar)
    if nearestKey and distance <= 48 then
        Widget.SetMode("ATTACHED", nearestKey)
    else
        state.mode = "PERSISTENT"
        state.detached = true
        SavePersistentPoint(bar)
        Widget.RefreshAllVisibility()
    end
end

local function StartResize(bar)
    local state = EnsureState()
    if not state.unlocked then return end
    if state.mode ~= "PERSISTENT" then
        -- Preserve the snapped bar's current vertical orientation when the
        -- resize gesture itself is what detaches it.
        state.persistentOrientation = state.orientation or "VERTICAL"
        DetachPreservingPosition(bar)
        state.mode = "PERSISTENT"
        state.hostMapKey = (GetInfo(bar) and GetInfo(bar).mapKey) or state.hostMapKey
        Widget.RefreshAllVisibility()
    end
    local x, y = GetCursorUIPosition()
    if not x or not y then return end

    bar._honorResizing = true
    bar._honorResizeStartX = x
    bar._honorResizeStartY = y
    bar._honorResizeStartWidth = bar:GetWidth()
    bar._honorResizeStartHeight = bar:GetHeight()
    bar._honorResizeStartLeft = bar:GetLeft()
    bar._honorResizeStartRight = bar:GetRight()
    bar._honorResizeStartTop = bar:GetTop()
    bar._honorResizeStartBottom = bar:GetBottom()
end

local function StopResize(bar)
    if not bar then return end
    bar._honorResizing = false
    SavePersistentPoint(bar)
    RefreshBar(bar)
end

local function UpdateResize(bar)
    if not bar or not bar._honorResizing then return end
    local state = EnsureState()
    local x, y = GetCursorUIPosition()
    if not x or not y then return end

    local startW = math.max(1, tonumber(bar._honorResizeStartWidth) or bar:GetWidth())
    local startH = math.max(1, tonumber(bar._honorResizeStartHeight) or bar:GetHeight())
    local scale

    if state.orientation == "HORIZONTAL" then
        -- Handle is on the left: dragging left makes the bar larger.
        local proposed = startW + ((bar._honorResizeStartX or x) - x)
        scale = proposed / startW
    else
        -- Handle is on the bottom: dragging down makes the bar larger.
        local proposed = startH + ((bar._honorResizeStartY or y) - y)
        scale = proposed / startH
    end

    local minScale, maxScale = 0.30, 4.00
    if state.orientation == "HORIZONTAL" then
        minScale = math.max(minScale, 90 / startW, 8 / startH)
        maxScale = math.min(maxScale, 1000 / startW, 120 / startH)
    else
        minScale = math.max(minScale, 8 / startW, 90 / startH)
        maxScale = math.min(maxScale, 120 / startW, 1000 / startH)
    end
    scale = Clamp(scale, minScale, maxScale)

    -- Anchor the edge opposite the resize handle so the handle stays under the
    -- cursor. The aspect ratio remains fixed while both dimensions scale.
    if state.orientation == "HORIZONTAL" and bar._honorResizeStartRight and bar._honorResizeStartTop then
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", bar._honorResizeStartRight, bar._honorResizeStartTop)
    elseif state.orientation ~= "HORIZONTAL" and bar._honorResizeStartLeft and bar._honorResizeStartTop then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", bar._honorResizeStartLeft, bar._honorResizeStartTop)
    end

    bar:SetSize(startW * scale, startH * scale)
    RefreshBar(bar)
end

function Widget.OpenMenu(bar)
    if not bar or not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then return false end
    local state = EnsureState()
    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(bar, function(_, root)
        root:CreateTitle("Honor Bar")

        -- Orientation belongs to the standalone/persistent widget. A snapped
        -- bar keeps the map-designed vertical layout.
        if state.mode == "PERSISTENT" then
            root:CreateRadio("Vertical", function() return Widget.GetOrientation() == "VERTICAL" end,
                function() Widget.SetOrientation(bar, "VERTICAL") end)
            root:CreateRadio("Horizontal", function() return Widget.GetOrientation() == "HORIZONTAL" end,
                function() Widget.SetOrientation(bar, "HORIZONTAL") end)
            root:CreateDivider()
        end

        if Widget.IsUnlocked() then
            root:CreateButton("Lock Honor Bar", function() Widget.SetGlobalUnlocked(false) end)
        else
            root:CreateButton("Unlock Honor Bar", function() Widget.SetGlobalUnlocked(true) end)
        end

        if state.mode == "PERSISTENT" then
            local snapKey = ChooseAttachedMap(state.activeMapKey)
            if snapKey then
                root:CreateButton("Snap to Zurk Map", function()
                    Widget.SetMode("ATTACHED", snapKey)
                end)
            end
        end

        root:CreateButton("Reset Bar Size", function()
            if state.mode == "PERSISTENT" then
                local info = GetInfo(bar)
                local w = (info and info.persistentDefaultWidth) or (bar._honorDockWidth or 18)
                local h = (info and info.persistentDefaultHeight) or (bar._honorDockHeight or 300)
                if state.orientation == "HORIZONTAL" then w, h = h, w end
                ApplyPersistentSizeLimits(bar, w, h)
                SavePersistentPoint(bar)
                RefreshBar(bar)
            else
                RestoreDockPoints(bar)
                RefreshBar(bar)
            end
        end)
        root:CreateButton("Hide Honor Bar", function() Widget.SetMode("OFF") end)
    end)
    return true
end

local function HookInteractiveChild(child, bar)
    if not child or child._honorWidgetHooked then return end
    child._honorWidgetHooked = true
    if child.RegisterForDrag then child:RegisterForDrag("LeftButton") end
    if child.HookScript then
        child:HookScript("OnDragStart", function() StartMoving(bar) end)
        child:HookScript("OnDragStop", function() StopMoving(bar) end)
        child:HookScript("OnClick", function(_, button)
            if button == "RightButton" then Widget.OpenMenu(bar) end
        end)
    end
end

function Widget.Attach(bar, honorModule, config)
    if not bar then return nil end
    if bar._honorWidgetAttached then return bar end
    config = config or {}
    local state = EnsureState()

    bar._honorWidgetAttached = true
    bar._honorWidgetState = state
    bar._honorWidgetConfig = config
    bar._honorModule = honorModule
    Widget.bars[bar] = {
        honorModule = honorModule,
        mapKey = config.mapKey,
        mapFrame = config.mapFrame or (honorModule and honorModule.addonFrame) or nil,
        persistentDefaultWidth = config.persistentDefaultWidth,
        persistentDefaultHeight = config.persistentDefaultHeight,
    }
    if config.mapKey then Widget.byMap[config.mapKey] = bar end
    CaptureDock(bar)

    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:HookScript("OnDragStart", function(self) StartMoving(self) end)
    bar:HookScript("OnDragStop", function(self) StopMoving(self) end)
    bar:HookScript("OnMouseUp", function(self, button)
        if button == "RightButton" then Widget.OpenMenu(self) end
    end)

    for _, segment in ipairs(bar.segments or {}) do HookInteractiveChild(segment, bar) end
    for _, marker in ipairs(bar.markers or {}) do HookInteractiveChild(marker, bar) end

    local resize = CreateFrame("Button", nil, bar)
    resize:SetSize(16, 16)
    resize:SetFrameLevel(bar:GetFrameLevel() + 40)
    resize:EnableMouse(true)
    resize:RegisterForDrag("LeftButton")
    local grip = resize:CreateTexture(nil, "OVERLAY")
    grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetAlpha(0.95)
    resize._honorGrip = grip
    resize:SetScript("OnDragStart", function() StartResize(bar) end)
    resize:SetScript("OnDragStop", function() StopResize(bar) end)
    resize:SetScript("OnUpdate", function() UpdateResize(bar) end)
    bar._honorResizeHandle = resize

    Widget.UpdateControls(bar)
    Widget.RefreshAllVisibility()
    return bar
end

-- One shared updater replaces the three map-specific honor refresh loops.
function Widget.RefreshShownHonorBars(force)
    for bar, info in pairs(Widget.bars) do
        local honorModule = info and info.honorModule or nil
        if bar and bar.IsShown and bar:IsShown() and honorModule and honorModule.Refresh then
            honorModule.Refresh(force and true or false)
        end
    end
end

local honorUpdater = CreateFrame("Frame")
honorUpdater.elapsed = 0
honorUpdater:RegisterEvent("PLAYER_ENTERING_WORLD")
honorUpdater:RegisterEvent("PLAYER_PVP_RANK_CHANGED")
honorUpdater:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
honorUpdater:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
honorUpdater:SetScript("OnEvent", function()
    Widget.RefreshShownHonorBars(true)
end)
if C_Timer and type(C_Timer.NewTicker) == "function" then
    Widget.honorRefreshTicker = C_Timer.NewTicker(1.0, function()
        Widget.RefreshShownHonorBars(false)
    end)
else
    honorUpdater:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 1.0 then return end
        self.elapsed = 0
        Widget.RefreshShownHonorBars(false)
    end)
end
