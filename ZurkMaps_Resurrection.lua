-- Shared spirit-healer clock. Live timing starts with a server observation; never
-- assume the wave phase from zone entry, death, or the start of test mode.
ZurkMapsResurrection = {}

function ZurkMapsResurrection.Create(map, border, config)
    local clock = CreateFrame("Frame", nil, map)
    clock:SetSize(36, 36)
    clock:SetFrameLevel(border:GetFrameLevel() + 4)
    clock:EnableMouse(true)
    clock:Hide()

    clock.icon = clock:CreateTexture(nil, "ARTWORK")
    clock.icon:SetAllPoints()
    -- The blue winged spirit healer, rather than the Resurrection spell icon.
    -- Preserve the artwork's transparency and full silhouette.
    clock.icon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
    clock.icon:SetDesaturated(true)
    clock.icon:SetAlpha(0.50)

    -- Keep the sprite fixed and move a feathered alpha mask instead of a hard
    -- scissor edge, which advances in visibly discrete pixels on a small icon.
    clock.fillClip = CreateFrame("Frame", nil, clock)
    clock.fillClip:SetFrameLevel(clock:GetFrameLevel() + 1)
    clock.fillClip:SetPoint("BOTTOMLEFT", clock, "BOTTOMLEFT", 0, 0)
    clock.fillClip:SetSize(36, 36)
    clock.fillClip:EnableMouse(false)
    clock.fill = clock.fillClip:CreateTexture(nil, "ARTWORK")
    clock.fill:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
    clock.fill:SetSize(36, 36)
    clock.fill:SetPoint("BOTTOMLEFT", clock.fillClip, "BOTTOMLEFT", 0, 0)
    clock.fill:SetAlpha(0.60)
    clock.fillMask = clock.fillClip:CreateMaskTexture()
    clock.fillMask:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\ResurrectionFillMask.tga")
    clock.fillMask:SetSize(36, 96)
    clock.fillMask:SetPoint("CENTER", clock, "BOTTOM", 0, -2)
    clock.fill:AddMaskTexture(clock.fillMask)
    for _, texture in ipairs({ clock.fill, clock.fillMask }) do
        if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
        if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
    end
    clock.shine = clock:CreateTexture(nil, "BACKGROUND")
    clock.shine:SetTexture("Interface\\Cooldown\\star4")
    clock.shine:SetBlendMode("ADD")
    clock.shine:SetVertexColor(1, 0.85, 0.35)
    clock.shine:SetPoint("CENTER", clock, "CENTER", 0, 0)
    clock.shine:SetSize(64, 64)
    clock.shine:SetAlpha(0)

    function clock:UpdateScale(addonScale)
        -- Let the artwork shrink with the map. Only give the digits a small
        -- readability floor; their fixed centers still fit inside the icon.
        addonScale = math.max(0.01, addonScale or 1)
        local fontSize = math.max(16, 11 / addonScale)
        local offsetX, rowCenter
        if config.getPosition then
            offsetX, rowCenter = config.getPosition()
        else
            offsetX, rowCenter = 0, 7 + config.shoutButton:GetHeight() / 2
        end
        if self.fontSize == fontSize and self.rowCenter == rowCenter and self.offsetX == offsetX then return end
        self.fontSize, self.rowCenter, self.offsetX = fontSize, rowCenter, offsetX
        self:SetScale(1)
        self:ClearAllPoints()
        self:SetPoint("CENTER", map, "BOTTOM", offsetX, rowCenter)
        self.timerText:SetFont("Fonts\\ARIALN.TTF", fontSize, "OUTLINE")
        -- Use an icon-wide centered text area instead of an auto-sized run.
        -- Give the line ample height as the readability floor increases its
        -- font size on small maps; narrow digit boxes previously clipped it.
        self.timerText:SetSize(36, fontSize * 2)
    end

    -- Center the complete number as one run. Arial Narrow's tabular numerals
    -- keep a steady advance while WoW handles spacing and centering at every
    -- scale, including the transition from two digits to one.
    clock.textLayer = CreateFrame("Frame", nil, clock)
    clock.textLayer:SetAllPoints(clock)
    clock.textLayer:SetFrameLevel(clock:GetFrameLevel() + 2)
    clock.textLayer:EnableMouse(false)
    clock.textLayer:SetAlpha(0)
    clock.textAlpha, clock.textTarget = 0, 0
    -- A full-size completion layer holds the finished artwork independently
    -- of the next wave's rising fill, then dissolves into that new fill.
    clock.completed = clock:CreateTexture(nil, "ARTWORK", nil, 1)
    clock.completed:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
    clock.completed:SetAllPoints(clock)
    clock.completed:SetAlpha(0)
    clock.timerText = clock.textLayer:CreateFontString(nil, "OVERLAY")
    clock.timerText:SetFont("Fonts\\ARIALN.TTF", 16, "OUTLINE")
    clock.timerText:SetWordWrap(false)
    clock.timerText:SetPoint("CENTER", clock, "CENTER", 0, 0)
    clock.timerText:SetJustifyH("CENTER")
    clock.timerText:SetJustifyV("MIDDLE")
    clock.timerText:SetTextColor(1, 1, 0, 1)
    clock.timerText:SetShadowColor(0, 0, 0, 1)
    clock.timerText:SetShadowOffset(1, -1)

    function clock:UpdateTextFade()
        if not self.textFadeStarted then return end
        local t = math.min(1, math.max(0, (GetTime() - self.textFadeStarted) / 0.12))
        local eased = t * t * (3 - 2 * t)
        self.textAlpha = self.textFrom + (self.textTarget - self.textFrom) * eased
        self.textLayer:SetAlpha(self.textAlpha)
        if t >= 1 then self.textFadeStarted = nil end
    end

    function clock:SetTextHovered(hovered)
        self:UpdateTextFade()
        self.textFrom, self.textTarget = self.textAlpha, hovered and 1 or 0
        self.textFadeStarted = GetTime()
    end

    function clock:UpdateEffects()
        if not self:IsShown() then
            self.effectMode, self.effectCycle, self.shineStarted = nil, nil, nil
            self.shine:SetAlpha(0)
            self.completed:SetAlpha(0)
            return
        end
        self:UpdateTextFade()
        local now = GetTime()
        local testing = config.isTestMode()
        local mode = testing and "test" or "live"
        local origin = testing and self.testStarted or self.liveDeadline
        local remaining, cycle
        if origin then
            if testing then
                cycle = math.floor((now - origin) / 30)
                remaining = 30 - ((now - origin) % 30)
            else
                local delta = origin - now
                cycle = delta > 0 and 0 or math.floor(-delta / 30) + 1
                remaining = delta > 0 and delta or (30 - ((-delta) % 30))
            end
        end
        if self.effectMode == mode and cycle and self.effectCycle and cycle > self.effectCycle then
            self.shineStarted = now
        end
        if self.effectMode ~= mode or not origin then self.shineStarted = nil end
        self.effectMode, self.effectCycle = mode, cycle
        local progress = remaining and math.max(0, math.min(1, 1 - remaining / 30)) or 0
        local shineAge = self.shineStarted and now - self.shineStarted
        if shineAge and shineAge < 1.6 then
            self.shine:SetAlpha(math.sin(math.min(1, shineAge / 0.15) * math.pi / 2) * (1 - shineAge / 1.6))
            self.shine:SetRotation(shineAge * 0.45)
        else
            self.shine:SetAlpha(0)
        end
        -- Keep the completed silhouette through the entire shine. Cross-fade
        -- it away over 0.30 seconds while the next wave fills underneath.
        local completion = shineAge and math.max(0, math.min(1, (1.9 - shineAge) / 0.30)) or 0
        self.completionStrength = completion
        self.completed:SetAlpha(completion * (self.hovered and 1 or 0.60))
        self.fillProgress = progress
        -- The four-unit feather starts below the icon and finishes above it,
        -- giving genuinely empty/full endpoints without resizing the artwork.
        self.fillMask:ClearAllPoints()
        self.fillMask:SetPoint("CENTER", self, "BOTTOM", 0, -2 + 40 * progress)
        self.fillClip:SetShown(progress > 0)
    end
    clock:SetScript("OnUpdate", clock.UpdateEffects)

    function clock:IsEnabled()
        return config.getDB().showResurrectionTimer ~= false
    end

    function clock:SetEnabled(enabled)
        config.getDB().showResurrectionTimer = enabled == true
        self:Refresh()
    end

    function clock:Observe()
        if not config.isInBattleground() or not GetAreaSpiritHealerTime then return end
        local seconds = GetAreaSpiritHealerTime()
        -- Some clients expose a snapshot instead of a continuously decreasing
        -- value. Do not keep moving the deadline forward for an unchanged sample.
        if type(seconds) == "number" and seconds > 0 and seconds <= 30
            and seconds ~= self.lastObservedSeconds then
            if self.liveDeadline and self.liveDeadline - GetTime() <= 2
                and seconds >= 25 and not config.isTestMode() and self:IsShown() then
                self.shineStarted = GetTime()
            end
            self.lastObservedSeconds = seconds
            self.liveDeadline = GetTime() + seconds
        end
    end

    function clock:Refresh()
        self:UpdateScale(config.getMapScale())
        local inBG, testing = config.isInBattleground(), config.isTestMode()
        if not inBG then
            self.liveDeadline, self.lastObservedSeconds, self.nearHealer = nil, nil, nil
        end
        if testing and not self.testStarted then self.testStarted = GetTime() end
        if not testing then self.testStarted = nil end
        local remaining
        self.estimated = false
        if testing then
            remaining = 30 - ((GetTime() - self.testStarted) % 30)
        elseif self.liveDeadline then
            local delta = self.liveDeadline - GetTime()
            self.estimated = delta <= 0
            remaining = delta > 0 and delta or (30 - ((-delta) % 30))
        end
        self.remaining = remaining and math.max(1, math.min(30, math.ceil(remaining))) or nil
        local text = self.remaining and tostring(self.remaining) or "--"
        if text ~= self.lastText then
            self.timerText:SetText(text)
            self.lastText = text
        end
        self:SetShown(self:IsEnabled() and (inBG or testing))
        self:UpdateEffects()
    end

    clock:SetScript("OnEnter", function(self)
        self.hovered = true
        self:SetTextHovered(true)
        self.icon:SetAlpha(0.75)
        self.fill:SetAlpha(1)
        if config.onEnter then config.onEnter() end
        GameTooltip:Hide()
    end)
    local function EndHover(self)
        self.hovered = false
        self:SetTextHovered(false)
        self.icon:SetAlpha(0.50)
        self.fill:SetAlpha(0.60)
    end
    clock:SetScript("OnLeave", EndHover)
    clock:SetScript("OnHide", function(self)
        EndHover(self)
        self.effectMode, self.effectCycle, self.shineStarted = nil, nil, nil
        self.shine:SetAlpha(0)
        self.completed:SetAlpha(0)
        self.textAlpha, self.textTarget, self.textFadeStarted = 0, 0, nil
        self.textLayer:SetAlpha(0)
    end)

    -- A separate driver continues observing events even when the map is hidden
    -- or the option is off, so re-enabling does not lose a known live wave.
    local driver = CreateFrame("Frame")
    clock.driver = driver
    for _, event in ipairs({ "AREA_SPIRIT_HEALER_IN_RANGE", "AREA_SPIRIT_HEALER_OUT_OF_RANGE",
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
        driver:RegisterEvent(event)
    end
    driver:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            clock.liveDeadline, clock.lastObservedSeconds = nil, nil
            clock.nearHealer = UnitIsGhost("player") and StaticPopup_Visible
                and not not StaticPopup_Visible("AREA_SPIRIT_HEAL")
        elseif event == "AREA_SPIRIT_HEALER_IN_RANGE" then
            -- Let Blizzard accept the spirit heal before reading on the next tick.
            clock.nearHealer, clock.lastObservedSeconds = true, nil
        elseif event == "AREA_SPIRIT_HEALER_OUT_OF_RANGE" or event == "PLAYER_UNGHOST" then
            clock.nearHealer, clock.lastObservedSeconds = false, nil
        end
        clock:Refresh()
    end)
    local elapsedTime = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime < 0.1 then return end
        elapsedTime = 0
        if clock.nearHealer and UnitIsGhost("player") then clock:Observe() end
        clock:Refresh()
    end)
    clock:Refresh()
    return clock
end
