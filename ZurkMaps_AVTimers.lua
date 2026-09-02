-- Compact Alterac Valley tower and graveyard capture timers.
-- Credit: Capping inspired the AV POI timer model and its timer packet format.
-- Zurk Maps passively reads that public compatibility feed and never sends on it.
ZurkMapsAVTimers = ZurkMapsAVTimers or {}

local Timers = ZurkMapsAVTimers

local CAPTURE_SECONDS = 300
local UPDATE_INTERVAL = 0.10
local BORDER_PULSE_SECONDS = 0.24
local FADE_SECONDS = 0.30
local ZM_TIMER_COMPAT_PREFIX = "Capping"
local BORDER_GOLD = { 1.00, 0.78, 0.06 }
local FACTION_BORDER = {
    Alliance = { 0.18, 0.52, 1.00 },
    Horde = { 1.00, 0.16, 0.08 },
}
local CONTESTED_TEXTURE_KIND = {
    [3] = "gy",
    [13] = "gy",
    [8] = "tower",
    [11] = "tower",
}

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function GetClockParts(value)
    local seconds = math.max(0, math.ceil(tonumber(value) or 0))
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    return tostring(minutes), tostring(math.floor(seconds / 10)), tostring(seconds % 10)
end

local function FormatRemaining(value)
    local minute, tens, ones = GetClockParts(value)
    return minute .. ":" .. tens .. ones
end

local function IsContested(objective, textureIndex)
    return objective and CONTESTED_TEXTURE_KIND[tonumber(textureIndex)] == objective.kind
end

local function AttackingFactionFromTexture(textureIndex)
    textureIndex = tonumber(textureIndex)
    if textureIndex == 3 or textureIndex == 8 then return "Alliance" end
    if textureIndex == 13 or textureIndex == 11 then return "Horde" end
    return nil
end

local function OwnerFactionFromTexture(textureIndex)
    textureIndex = tonumber(textureIndex)
    if textureIndex == 10 or textureIndex == 14 then return "Alliance" end
    if textureIndex == 9 or textureIndex == 12 then return "Horde" end
    return nil
end

local function OppositeFaction(faction)
    if faction == "Alliance" then return "Horde" end
    if faction == "Horde" then return "Alliance" end
    return nil
end

local function RegisterZMTimerCompatPrefix()
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, ZM_TIMER_COMPAT_PREFIX)
    elseif type(RegisterAddonMessagePrefix) == "function" then
        pcall(RegisterAddonMessagePrefix, ZM_TIMER_COMPAT_PREFIX)
    end
end

function Timers.Create(options)
    if not options or not options.map or type(options.objectives) ~= "table"
        or type(options.buttons) ~= "table" then
        return nil
    end

    local controller = {
        map = options.map,
        mapBorder = options.mapBorder,
        objectives = options.objectives,
        buttons = options.buttons,
        boxes = {},
        states = {},
        objectiveByID = {},
        objectiveByPoiID = {},
        pendingZMCompatTimes = {},
        testMode = false,
        elapsed = 0,
    }

    local function SetBorderExpansion(box, amount)
        if not box or not box.border then return end
        amount = math.max(0, tonumber(amount) or 0)
        box.border:ClearAllPoints()
        box.border:SetPoint("TOPLEFT", box, "TOPLEFT", -amount, amount)
        box.border:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", amount, -amount)
    end

    local function SetBorderColor(box, faction)
        if not box or not box.border or not box.border.SetBackdropBorderColor then return end
        local color = FACTION_BORDER[faction] or BORDER_GOLD
        box.border:SetBackdropBorderColor(color[1], color[2], color[3], 1.00)
    end

    local function SetClockText(box, value)
        if not box then return end
        local minute, tens, ones = GetClockParts(value)
        box.minute:SetText(minute)
        box.secondTens:SetText(tens)
        box.secondOnes:SetText(ones)
    end

    local function CreateClockGlyph(parent, offsetX)
        local glyph = parent:CreateFontString(nil, "OVERLAY")
        glyph:SetPoint("CENTER", parent:GetParent(), "CENTER", offsetX, 0)
        glyph:SetFont("Fonts\\ARIALN.TTF", 8, "")
        glyph:SetTextColor(1, 1, 1, 1)
        glyph:SetShadowColor(0, 0, 0, 1)
        glyph:SetShadowOffset(1, -1)
        return glyph
    end

    local function CreateTimerBox(objective)
        local button = controller.buttons[objective.id]
        if not button or (objective.kind ~= "tower" and objective.kind ~= "gy") then return nil end

        local box = CreateFrame("Button", nil, controller.map)
        box:SetSize(25, 13)
        box:SetFrameLevel(((controller.mapBorder and controller.mapBorder:GetFrameLevel()) or controller.map:GetFrameLevel()) + 8)
        box:ClearAllPoints()

        -- Keep collision-prone clocks beside their icons. The paired Frostwolf
        -- timers point outward, away from each other and away from Frostwolf Keep.
        if objective.id == "DB_NORTH" then
            box:SetPoint("BOTTOM", button, "TOP", 0, 0)
        elseif objective.id == "STORMPIKE_AID" or objective.id == "WEST_FW" then
            box:SetPoint("RIGHT", button, "LEFT", -1, 0)
        elseif objective.id == "ICEBLOOD_GY" or objective.id == "EAST_FW" then
            box:SetPoint("LEFT", button, "RIGHT", 1, 0)
        else
            box:SetPoint("TOP", button, "BOTTOM", 0, 0)
        end

        box.background = box:CreateTexture(nil, "BACKGROUND")
        box.background:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -1)
        box.background:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 1)
        box.background:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        box.background:SetVertexColor(0.018, 0.014, 0.006, 0.96)

        box.border = CreateFrame("Frame", nil, box, BackdropTemplateMixin and "BackdropTemplate" or nil)
        box.border:SetFrameLevel(box:GetFrameLevel() + 1)
        if box.border.SetBackdrop then
            box.border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false,
                edgeSize = 6,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
        end
        SetBorderExpansion(box, 0)
        SetBorderColor(box, nil)

        -- Four fixed glyph positions make the display behave like a clock. The
        -- numerals never recenter or slide as proportional character widths change.
        box.minute = CreateClockGlyph(box.border, -6.5)
        box.colon = CreateClockGlyph(box.border, -2.2)
        box.secondTens = CreateClockGlyph(box.border, 1.9)
        box.secondOnes = CreateClockGlyph(box.border, 6.0)
        box.colon:SetText(":")
        SetClockText(box, CAPTURE_SECONDS)

        box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        box:SetScript("OnClick", function(_, mouseButton)
            controller:HandleClick(objective, mouseButton)
        end)
        box:SetScript("OnEnter", function(self)
            controller:ShowTooltip(objective, self)
        end)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)
        box:Hide()
        return box
    end

    for _, objective in ipairs(controller.objectives) do
        controller.objectiveByID[objective.id] = objective
        local box = CreateTimerBox(objective)
        if box then controller.boxes[objective.id] = box end
    end

    function controller:GetState(objective)
        if not objective then return nil end
        local state = self.states[objective.id]
        if not state then
            state = {
                textureIndex = nil,
                endsAt = nil,
                source = nil,
                poiID = nil,
                ownerFaction = nil,
                captureFaction = nil,
                animationStart = nil,
                animationFaction = nil,
            }
            self.states[objective.id] = state
        end
        return state
    end

    function controller:GetRemaining(objective)
        local state = self:GetState(objective)
        if not state or not state.endsAt then return nil end
        return math.max(0, state.endsAt - Now())
    end

    function controller:GetPlayerFaction()
        if type(options.getPlayerFaction) == "function" then
            local faction = options.getPlayerFaction()
            if faction == "Alliance" or faction == "Horde" then return faction end
        end
        if type(UnitFactionGroup) == "function" then
            local faction = UnitFactionGroup("player")
            if faction == "Alliance" or faction == "Horde" then return faction end
        end
        return nil
    end

    function controller:GetChannelHint()
        if type(options.getCalloutChannel) == "function" then
            local channel = options.getCalloutChannel()
            if channel == "RW" then return "/RW" end
        end
        return "/BG"
    end

    function controller:GetRightClickAction(objective)
        local state = self:GetState(objective)
        local playerFaction = self:GetPlayerFaction()
        local ownerFaction = state and (state.ownerFaction or OppositeFaction(state.captureFaction)) or nil
        return playerFaction and ownerFaction == playerFaction and "reinforce" or "weak"
    end

    function controller:AddTooltipLines(objective, tooltip)
        tooltip = tooltip or GameTooltip
        local remaining = self:GetRemaining(objective)
        if not remaining or remaining <= 0 then return false end

        tooltip:AddLine("Time remaining: " .. FormatRemaining(remaining), 1, 1, 1, true)
        tooltip:AddLine("Left-click timer: Report time to " .. self:GetChannelHint(), 0.92, 0.82, 0.38, true)
        if self:GetRightClickAction(objective) == "reinforce" then
            tooltip:AddLine("Right-click timer: Call for reinforcements", 0.92, 0.82, 0.38, true)
        else
            tooltip:AddLine("Right-click timer: Report objective as weak", 0.92, 0.82, 0.38, true)
        end
        return true
    end

    function controller:ShowTooltip(objective, owner)
        GameTooltip:Hide()
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(objective.name)
        GameTooltip:AddLine(objective.status or "Contested objective", 0.82, 0.82, 0.82, true)
        self:AddTooltipLines(objective, GameTooltip)
        GameTooltip:Show()
    end

    function controller:HandleClick(objective, mouseButton)
        local remaining = self:GetRemaining(objective)
        if not remaining or remaining <= 0 or type(options.sendCallout) ~= "function" then return end
        local clock = FormatRemaining(remaining)
        local message
        if mouseButton == "RightButton" then
            if self:GetRightClickAction(objective) == "reinforce" then
                message = string.format("Reinforcements to %s! %s remaining", objective.name, clock)
            else
                message = string.format("%s is weak! %s remaining", objective.name, clock)
            end
        else
            message = string.format("%s: %s remaining", objective.name, clock)
        end
        options.sendCallout(message)
    end

    function controller:SetRemaining(objective, remaining, source)
        local state = self:GetState(objective)
        local box = objective and self.boxes[objective.id]
        remaining = tonumber(remaining)
        if not state or not box or not remaining or remaining <= 0 then return false end
        remaining = math.min(CAPTURE_SECONDS, remaining)
        state.endsAt = Now() + remaining
        state.source = source or "poi"
        state.animationStart = nil
        state.animationFaction = nil
        box:SetAlpha(1)
        box:EnableMouse(true)
        SetBorderExpansion(box, 0)
        SetBorderColor(box, nil)
        SetClockText(box, remaining)
        box:Show()
        return true
    end

    function controller:CompleteObjective(objective, faction)
        local state = self:GetState(objective)
        local box = objective and self.boxes[objective.id]
        if not state or not box then return end
        local completionSource = state.source
        state.endsAt = nil
        state.source = nil
        state.animationStart = Now()
        state.animationFaction = faction or state.captureFaction or state.ownerFaction
        SetClockText(box, 0)
        SetBorderExpansion(box, 0)
        SetBorderColor(box, state.animationFaction)
        box:SetAlpha(1)
        box:EnableMouse(false)
        box:Show()
        if completionSource == "test" and objective.kind == "tower" and type(options.onTestTowerComplete) == "function" then
            options.onTestTowerComplete(objective)
        end
    end

    function controller:ClearObjective(objective, clearTexture)
        local state = self:GetState(objective)
        if not state then return end
        state.endsAt = nil
        state.source = nil
        state.animationStart = nil
        state.animationFaction = nil
        if clearTexture then
            state.textureIndex = nil
            state.ownerFaction = nil
            state.captureFaction = nil
        end
        local box = objective and self.boxes[objective.id]
        if box then
            box:SetAlpha(1)
            box:EnableMouse(true)
            SetBorderExpansion(box, 0)
            SetBorderColor(box, nil)
            box:Hide()
        end
    end

    function controller:ObserveObjective(objective, textureIndex, areaPoiID)
        if not objective or (objective.kind ~= "tower" and objective.kind ~= "gy") then return end
        textureIndex = tonumber(textureIndex)
        if not textureIndex then return end

        local state = self:GetState(objective)
        local previousTexture = state.textureIndex
        local wasContested = IsContested(objective, previousTexture)
        local nowContested = IsContested(objective, textureIndex)
        local newOwner = OwnerFactionFromTexture(textureIndex)
        state.textureIndex = textureIndex

        areaPoiID = tonumber(areaPoiID)
        if areaPoiID then
            state.poiID = areaPoiID
            self.objectiveByPoiID[areaPoiID] = objective
        end

        if self.testMode then return end

        if nowContested then
            if not wasContested or previousTexture ~= textureIndex then
                state.captureFaction = AttackingFactionFromTexture(textureIndex)
                state.ownerFaction = OwnerFactionFromTexture(previousTexture) or OppositeFaction(state.captureFaction)
            end
            local synced = areaPoiID and self.pendingZMCompatTimes[areaPoiID] or nil
            if synced then
                self.pendingZMCompatTimes[areaPoiID] = nil
                self:SetRemaining(objective, synced, "zm-compat-sync")
            elseif not wasContested or previousTexture ~= textureIndex then
                self:SetRemaining(objective, CAPTURE_SECONDS, "poi")
            end
        else
            if newOwner then state.ownerFaction = newOwner end
            if wasContested then
                local completionFaction = newOwner or state.captureFaction or state.ownerFaction
                if state.animationStart then
                    state.animationFaction = completionFaction
                    SetBorderColor(self.boxes[objective.id], completionFaction)
                else
                    self:CompleteObjective(objective, completionFaction)
                end
            elseif state.endsAt then
                self:ClearObjective(objective, false)
            end
        end
    end

    function controller:ApplyZMCompatTimer(areaPoiID, remaining)
        areaPoiID = tonumber(areaPoiID)
        remaining = tonumber(remaining)
        if not areaPoiID or not remaining or remaining <= 0 or remaining > CAPTURE_SECONDS then return end

        local objective = self.objectiveByPoiID[areaPoiID]
        if not objective then
            self.pendingZMCompatTimes[areaPoiID] = remaining
            return
        end

        local state = self:GetState(objective)
        if self.testMode or not IsContested(objective, state.textureIndex) then return end
        local current = state.endsAt and (state.endsAt - Now()) or nil
        if not current or remaining <= current + 2 then
            self:SetRemaining(objective, remaining, "zm-compat-sync")
        end
    end

    function controller:ApplyZMCompatMessage(message)
        if type(message) ~= "string" or not message:find("~", 1, true) then return end
        for poiText, remainingText in message:gmatch("(%d+)%-(%d+)~") do
            self:ApplyZMCompatTimer(poiText, remainingText)
        end
    end

    function controller:StartTest()
        self.testMode = true
        for index, objective in ipairs(self.objectives) do
            if objective.kind == "tower" or objective.kind == "gy" then
                local state = self:GetState(objective)
                local originalOwner = OwnerFactionFromTexture(objective.defaultTexture)
                state.ownerFaction = originalOwner
                state.captureFaction = OppositeFaction(originalOwner) or (index % 2 == 0 and "Alliance" or "Horde")
                local remaining = objective.kind == "tower" and math.random(1, 15) or math.random(61, 300)
                self:SetRemaining(objective, remaining, "test")
            end
        end
    end

    function controller:StopTest()
        self.testMode = false
        for _, objective in ipairs(self.objectives) do
            if objective.kind == "tower" or objective.kind == "gy" then
                self:ClearObjective(objective, true)
            end
        end
    end

    function controller:Reset()
        self.testMode = false
        self.pendingZMCompatTimes = {}
        self.objectiveByPoiID = {}
        for _, objective in ipairs(self.objectives) do
            if objective.kind == "tower" or objective.kind == "gy" then
                local state = self:GetState(objective)
                state.poiID = nil
                self:ClearObjective(objective, true)
            end
        end
    end

    controller.updateFrame = CreateFrame("Frame", nil, controller.map)
    controller.updateFrame:SetScript("OnUpdate", function(_, elapsed)
        controller.elapsed = controller.elapsed + (elapsed or 0)
        local updateClock = controller.elapsed >= UPDATE_INTERVAL
        if updateClock then controller.elapsed = controller.elapsed % UPDATE_INTERVAL end
        local now = Now()
        for objectiveID, state in pairs(controller.states) do
            local objective = controller.objectiveByID[objectiveID]
            local box = controller.boxes[objectiveID]
            if state.animationStart and box then
                -- Animation runs every rendered frame. It begins at the timer's
                -- normal dimensions, eases outward, and returns before fading.
                local animationTime = now - state.animationStart
                if animationTime < BORDER_PULSE_SECONDS then
                    local progress = math.max(0, math.min(1, animationTime / BORDER_PULSE_SECONDS))
                    local pulse = math.sin(progress * math.pi)
                    SetBorderExpansion(box, pulse * pulse * 2)
                    box:SetAlpha(1)
                else
                    SetBorderExpansion(box, 0)
                    local fadeProgress = (animationTime - BORDER_PULSE_SECONDS) / FADE_SECONDS
                    box:SetAlpha(math.max(0, 1 - fadeProgress))
                    if fadeProgress >= 1 then
                        state.animationStart = nil
                        state.animationFaction = nil
                        box:SetAlpha(1)
                        box:EnableMouse(true)
                        SetBorderColor(box, nil)
                        box:Hide()
                    end
                end
            elseif state.endsAt and updateClock then
                local remaining = state.endsAt - now
                if remaining > 0 then
                    if box then SetClockText(box, remaining); box:Show() end
                else
                    controller:CompleteObjective(objective, state.captureFaction or state.ownerFaction)
                end
            end
        end
    end)

    controller.eventFrame = CreateFrame("Frame")
    controller.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    controller.eventFrame:SetScript("OnEvent", function(_, _, prefix, message, channel)
        if prefix ~= ZM_TIMER_COMPAT_PREFIX or channel ~= "INSTANCE_CHAT" then return end
        if options.isInAlteracValley and not options.isInAlteracValley() then return end
        controller:ApplyZMCompatMessage(message)
    end)
    RegisterZMTimerCompatPrefix()

    return controller
end
