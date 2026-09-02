-- Zurk Maps local PvP breakpoint celebrations.
-- Kept separate from the Honor Bar renderer so crossing a breakpoint can be
-- celebrated even when the bar itself is hidden or attached to another map.
ZurkMapsCelebrations = ZurkMapsCelebrations or {}

local Celebration = ZurkMapsCelebrations
local SOUND_FILE = "Interface\\AddOns\\ZurkMaps\\Media\\BreakpointAchieved_FullImmediate.ogg"

local function FormatNumber(value)
    local n = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
    local text = tostring(n)
    while true do
        local changed, count = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
        text = changed
        if count == 0 then break end
    end
    return text
end

local function GetWeekKey()
    if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset) == "function" and type(GetServerTime) == "function" then
        local ok, seconds = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if ok and tonumber(seconds) and tonumber(seconds) > 0 then
            local nextReset = GetServerTime() + tonumber(seconds)
            -- Round to the nearest hour so minor countdown jitter cannot create a new key.
            return tostring(math.floor((nextReset + 1800) / 3600))
        end
    end
    return nil
end

local function EnsureState()
    ZurkMapsHonorDB = ZurkMapsHonorDB or {}
    ZurkMapsHonorDB.breakpointCelebration = ZurkMapsHonorDB.breakpointCelebration or {}
    local state = ZurkMapsHonorDB.breakpointCelebration
    state.seen = type(state.seen) == "table" and state.seen or {}
    return state
end

local function GetRankUpForMilestone(snapshot, milestone)
    if type(snapshot) ~= "table" or type(milestone) ~= "table" then return nil end

    -- A breakpoint only earns the congratulations clause when reaching THIS
    -- milestone increases the projected PvP rank compared with the state
    -- immediately before it. Ordinary within-rank breakpoints return nil.
    local rankBeforeMilestone = tonumber(snapshot.rank) or 0
    for _, candidate in ipairs(snapshot.milestones or {}) do
        local candidateRank = tonumber(candidate and candidate.rank) or rankBeforeMilestone
        local isTarget = candidate == milestone
            or ((candidate and candidate.honor or -1) == (milestone.honor or -2))

        if isTarget then
            if candidateRank > rankBeforeMilestone then
                return candidateRank
            end
            return nil
        end

        if candidateRank > rankBeforeMilestone then
            rankBeforeMilestone = candidateRank
        end
    end
    return nil
end

local ALLIANCE_RANK_NAMES = {
    [1] = "Private", [2] = "Corporal", [3] = "Sergeant", [4] = "Master Sergeant",
    [5] = "Sergeant Major", [6] = "Knight", [7] = "Knight-Lieutenant", [8] = "Knight-Captain",
    [9] = "Knight-Champion", [10] = "Lieutenant Commander", [11] = "Commander", [12] = "Marshal",
    [13] = "Field Marshal", [14] = "Grand Marshal",
}

local HORDE_RANK_NAMES = {
    [1] = "Scout", [2] = "Grunt", [3] = "Sergeant", [4] = "Senior Sergeant",
    [5] = "First Sergeant", [6] = "Stone Guard", [7] = "Blood Guard", [8] = "Legionnaire",
    [9] = "Centurion", [10] = "Champion", [11] = "Lieutenant General", [12] = "General",
    [13] = "Warlord", [14] = "High Warlord",
}

local function GetFactionRankName(rankNumber)
    rankNumber = tonumber(rankNumber)
    if not rankNumber or rankNumber < 1 or rankNumber > 14 then return nil end

    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local factionID = faction == "Alliance" and 1 or 0
    if type(GetPVPRankInfo) == "function" then
        -- PvP rank IDs are rank number + 4. Passing the faction explicitly
        -- gives the correct localized Alliance/Horde title for that rank.
        local ok, rankName = pcall(GetPVPRankInfo, rankNumber + 4, factionID)
        if ok and type(rankName) == "string" and rankName ~= "" then
            return rankName
        end
    end

    if faction == "Alliance" then
        return ALLIANCE_RANK_NAMES[rankNumber]
    end
    return HORDE_RANK_NAMES[rankNumber]
end

local function AddChatMessage(requiredHonor)
    local message = string.format(
        "|cff33ff99Zurk Maps|r: Breakpoint reached — you have over |cffffd100%s|r honor this week.",
        FormatNumber(requiredHonor))

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    else
        print(message)
    end
end

local function EnsureRankUpPopup()
    if Celebration.rankUpPopup then return Celebration.rankUpPopup end

    local frame = CreateFrame("Frame", "ZurkMapsRankUpPopup", UIParent)
    frame:SetSize(600, 230)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(110)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self._userPositioned = true
        if self.SnapToPixels then self:SnapToPixels() end
    end)
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetVertexColor(0.025, 0.035, 0.055, 0.97)
    background:SetAllPoints(frame)

    local inner = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    inner:SetTexture("Interface\\Buttons\\WHITE8X8")
    inner:SetVertexColor(0.14, 0.08, 0.015, 0.42)
    inner:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    inner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)

    -- A clean double-gold frame avoids the black halo baked into Blizzard's
    -- dialog-border texture while retaining a more ceremonial profile.
    local function GetPhysicalPixelScale(widget)
        local unitFactor
        if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then
            unitFactor = PixelUtil.GetPixelToUIUnitFactor()
        elseif GetPhysicalScreenSize then
            local _, physicalHeight = GetPhysicalScreenSize()
            if physicalHeight and physicalHeight > 0 then unitFactor = 768 / physicalHeight end
        end
        return math.max(0.01, (widget:GetEffectiveScale() or 1) / math.max(0.01, unitFactor or 1))
    end
    local borderLayouts = {}
    local function AddBorder(left, right, top, bottom, thickness, r, g, b, alpha)
        local lines = {}
        for index = 1, 4 do
            local line = frame:CreateTexture(nil, "BORDER")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(r, g, b, alpha)
            -- Coordinates below are already physical-pixel aligned. Prevent a
            -- second, independent texture-rounding pass on opposite edges.
            if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
            if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
            lines[index] = line
        end
        borderLayouts[#borderLayouts + 1] = function(scale, widthPixels, heightPixels)
            local function Pixels(value) return math.floor(value * scale + 0.5) end
            local l, rInset, t, bInset = Pixels(left), Pixels(right), Pixels(top), Pixels(bottom)
            local stroke = math.max(1, Pixels(thickness))
            local width, height = widthPixels - l - rInset, heightPixels - t - bInset
            local function Place(line, x, y, w, h)
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", frame, "TOPLEFT", x / scale, -y / scale)
                line:SetSize(w / scale, h / scale)
            end
            Place(lines[1], l, t, width, stroke)
            Place(lines[2], l, heightPixels - bInset - stroke, width, stroke)
            -- Exclude the corners already painted by the horizontal strokes.
            Place(lines[3], l, t + stroke, stroke, height - (2 * stroke))
            Place(lines[4], widthPixels - rInset - stroke, t + stroke, stroke, height - (2 * stroke))
        end
    end
    AddBorder(1, 1, 1, 1, 2, 0.98, 0.67, 0.10, 1)
    AddBorder(5, 5, 5, 5, 1, 0.76, 0.42, 0.05, 0.85)

    function frame:SnapToPixels()
        local scale = GetPhysicalPixelScale(self)
        local parentScale = GetPhysicalPixelScale(UIParent)
        local widthPixels = math.floor(600 * scale + 0.5)
        local heightPixels = math.floor((self.layoutHeight or 230) * scale + 0.5)
        self:SetSize(widthPixels / scale, heightPixels / scale)
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            local x = (math.floor(left * scale + 0.5) - (UIParent:GetLeft() or 0) * parentScale) / parentScale
            local y = (math.floor(top * scale + 0.5) - (UIParent:GetBottom() or 0) * parentScale) / parentScale
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        end
        for _, layout in ipairs(borderLayouts) do layout(scale, widthPixels, heightPixels) end
    end

    -- Reuse the friendly WSG flag-carrier glow treatment: two counter-rotating
    -- gold stars pulse behind the artwork without covering the badge itself.
    local iconGlow = CreateFrame("Frame", nil, frame)
    iconGlow:SetSize(130, 130)
    iconGlow:SetPoint("LEFT", frame, "LEFT", 9, -1)
    iconGlow:SetFrameLevel(frame:GetFrameLevel() + 1)
    iconGlow:EnableMouse(false)
    iconGlow.elapsed = 0

    iconGlow.rearStar = iconGlow:CreateTexture(nil, "ARTWORK", nil, -2)
    iconGlow.rearStar:SetPoint("CENTER")
    iconGlow.rearStar:SetTexture("Interface\\Cooldown\\star4")
    iconGlow.rearStar:SetBlendMode("ADD")
    iconGlow.rearStar:SetVertexColor(1.00, 0.78, 0.08, 1)

    iconGlow.innerStar = iconGlow:CreateTexture(nil, "ARTWORK", nil, -1)
    iconGlow.innerStar:SetPoint("CENTER")
    iconGlow.innerStar:SetTexture("Interface\\Cooldown\\star4")
    iconGlow.innerStar:SetBlendMode("ADD")
    iconGlow.innerStar:SetVertexColor(1.00, 1.00, 0.68, 1)

    iconGlow:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        local rearPulse = 0.5 + (0.5 * math.sin(self.elapsed * 4.2))
        local innerPulse = 0.5 + (0.5 * math.sin((self.elapsed * 4.2) + (math.pi * 0.72)))
        self.rearStar:SetSize(119 + (13 * rearPulse), 119 + (13 * rearPulse))
        self.rearStar:SetAlpha(0.53 + (0.30 * rearPulse))
        self.innerStar:SetSize(101 + (11 * innerPulse), 101 + (11 * innerPulse))
        self.innerStar:SetAlpha(0.44 + (0.26 * innerPulse))
        if self.rearStar.SetRotation then self.rearStar:SetRotation(self.elapsed * 0.75) end
        if self.innerStar.SetRotation then self.innerStar:SetRotation(self.elapsed * -1.05) end
    end)

    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetSize(64, 64)
    iconFrame:SetPoint("CENTER", iconGlow, "CENTER", 0, 0)
    iconFrame:SetFrameLevel(frame:GetFrameLevel() + 2)
    iconFrame:EnableMouse(false)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(64, 64)
    icon:SetAllPoints(iconFrame)

    local eyebrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    eyebrow:SetPoint("TOP", frame, "TOP", 0, -12)
    eyebrow:SetJustifyH("CENTER")
    eyebrow:SetText("HONOR BREAKPOINT ACHIEVED")
    eyebrow:SetTextColor(1, 0.74, 0.18, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 34, -39)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -39)
    title:SetJustifyH("CENTER")
    if title.SetWordWrap then title:SetWordWrap(false) end
    if title.SetNonSpaceWrap then title:SetNonSpaceWrap(false) end
    if title.SetMaxLines then title:SetMaxLines(1) end
    title:SetTextColor(1, 1, 1, 1)

    local rankText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rankText:SetPoint("TOPLEFT", frame, "TOPLEFT", 126, -88)
    rankText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -88)
    rankText:SetJustifyH("LEFT")
    rankText:SetTextColor(1, 0.82, 0.30, 1)

    local honorBar = CreateFrame("Frame", nil, frame)
    honorBar:SetSize(520, 20)
    honorBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 51)
    honorBar:SetFrameLevel(frame:GetFrameLevel() + 2)
    honorBar:EnableMouse(false)

    local function SnapBarPixel(bar, value)
        local scale = bar:GetEffectiveScale() or 1
        if scale <= 0 then scale = 1 end
        return math.floor(value * scale + 0.5) / scale
    end

    honorBar.background = honorBar:CreateTexture(nil, "BACKGROUND")
    honorBar.background:SetTexture("Interface\\Buttons\\WHITE8X8")
    honorBar.background:SetVertexColor(0.025, 0.025, 0.030, 1)
    honorBar.background:SetAllPoints(honorBar)

    honorBar.fill = honorBar:CreateTexture(nil, "ARTWORK", nil, 1)
    honorBar.fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    honorBar.fill:SetTexCoord(0, 1, 0, 1)
    honorBar.fill:SetPoint("TOPLEFT", honorBar, "TOPLEFT", 2, -2)
    honorBar.fill:SetPoint("BOTTOMLEFT", honorBar, "BOTTOMLEFT", 2, 2)

    honorBar.incompleteOverlay = honorBar:CreateTexture(nil, "ARTWORK", nil, 2)
    honorBar.incompleteOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")

    honorBar.stripes = honorBar:CreateTexture(nil, "ARTWORK", nil, 3)
    honorBar.stripes:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\HonorUnrealizedStripes_Horizontal")
    honorBar.stripes:SetBlendMode("BLEND")
    honorBar.stripes:SetPoint("TOPLEFT", honorBar, "TOPLEFT", 2, -2)
    honorBar.stripes:SetPoint("BOTTOMLEFT", honorBar, "BOTTOMLEFT", 2, 2)

    honorBar.marker = honorBar:CreateTexture(nil, "OVERLAY", nil, 5)
    honorBar.marker:SetTexture("Interface\\Buttons\\WHITE8X8")
    honorBar.marker:SetVertexColor(1, 0.96, 0.68, 1)
    honorBar.marker:SetSize(2, 14)

    honorBar.markerSpark = honorBar:CreateTexture(nil, "OVERLAY", nil, 6)
    honorBar.markerSpark:SetTexture("Interface\\Cooldown\\star4")
    honorBar.markerSpark:SetBlendMode("ADD")
    honorBar.markerSpark:SetVertexColor(1, 0.90, 0.28, 1)
    honorBar.markerSpark:SetSize(24, 24)

    honorBar.targetGlow = honorBar:CreateTexture(nil, "ARTWORK", nil, 3)
    honorBar.targetGlow:SetTexture("Interface\\Cooldown\\star4")
    honorBar.targetGlow:SetBlendMode("ADD")
    honorBar.targetGlow:SetVertexColor(1, 0.78, 0.08, 1)
    honorBar.targetGlow:SetPoint("CENTER", honorBar, "CENTER", 0, 0)

    honorBar.targetRank = honorBar:CreateTexture(nil, "OVERLAY", nil, 4)
    honorBar.targetRank:SetSize(30, 30)
    honorBar.targetRank:SetPoint("CENTER", honorBar.targetGlow, "CENTER")

    honorBar.breakpoints = {}
    for index = 1, 4 do
        local marker = CreateFrame("Frame", nil, honorBar)
        marker:SetSize(20, 20)
        marker:SetFrameLevel(honorBar:GetFrameLevel() + 4)
        marker.tick = marker:CreateTexture(nil, "OVERLAY")
        marker.tick:SetTexture("Interface\\Buttons\\WHITE8X8")
        marker.tick:SetVertexColor(0.82, 0.73, 0.56, 0.72)
        marker.tick:SetSize(1, 14)
        marker.tick:SetPoint("CENTER")
        marker.rankIcon = marker:CreateTexture(nil, "OVERLAY", nil, 2)
        marker.rankIcon:SetSize(18, 18)
        marker.rankIcon:SetPoint("CENTER")
        marker:Hide()
        honorBar.breakpoints[index] = marker
    end

    -- Match the real honor bar's complete tooltip-style frame, including both
    -- end caps. A separate layer keeps the border above the fill/stripe artwork.
    local barBorder = CreateFrame("Frame", nil, honorBar, BackdropTemplateMixin and "BackdropTemplate" or nil)
    barBorder:SetAllPoints(honorBar)
    barBorder:SetFrameLevel(honorBar:GetFrameLevel() + 1)
    barBorder:EnableMouse(false)
    if barBorder.SetBackdrop then
        barBorder:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        barBorder:SetBackdropColor(0, 0, 0, 0)
        barBorder:SetBackdropBorderColor(0.84, 0.56, 0.31, 0.98)
    end

    -- Lift the shaded top bevel all the way to the inner corner shoulders so
    -- the highlight joins the end caps without a dark gap at either end.
    -- Keep the highlight one physical pixel thick.
    local topHighlight = barBorder:CreateTexture(nil, "OVERLAY", nil, 7)
    topHighlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    topHighlight:SetVertexColor(0.84, 0.56, 0.31, 0.65)
    topHighlight:SetPoint("TOPLEFT", barBorder, "TOPLEFT", 2, -1)
    topHighlight:SetPoint("TOPRIGHT", barBorder, "TOPRIGHT", -2, -1)
    local function SizeTopHighlight()
        topHighlight:SetHeight(1 / math.max(0.01, honorBar:GetEffectiveScale() or 1))
    end
    barBorder:SetScript("OnShow", SizeTopHighlight)
    barBorder:SetScript("OnSizeChanged", SizeTopHighlight)
    SizeTopHighlight()

    honorBar:SetScript("OnUpdate", nil)
    honorBar.Start = function(self, rank, faction, barData, requiredHonor)
        rank = math.max(1, math.min(14, tonumber(rank) or 1))
        self.targetRank:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", rank))
        local r, g, b = faction == "Alliance" and 0.10 or 0.86, faction == "Alliance" and 0.38 or 0.035, faction == "Alliance" and 0.95 or 0.025
        self.fill:SetVertexColor(r, g, b, 0.95)
        self.incompleteOverlay:SetVertexColor(r * 0.42, g * 0.42, b * 0.42, 0.96)
        self.stripes:SetVertexColor(math.min(1, r * 1.45 + 0.10), math.min(1, g * 1.45 + 0.10), math.min(1, b * 1.45 + 0.10), 0.48)
        local milestones = type(barData) == "table" and barData.milestones or nil
        if type(milestones) ~= "table" or #milestones == 0 then
            milestones = { { honor = 1, rank = rank } }
        end
        local maxHonor = tonumber(milestones[#milestones] and milestones[#milestones].honor) or 1
        requiredHonor = tonumber(requiredHonor) or maxHonor
        maxHonor = math.max(1, maxHonor, requiredHonor)
        local startHonor = 0
        for _, milestone in ipairs(milestones) do
            local honor = tonumber(milestone and milestone.honor) or 0
            if honor < requiredHonor then startHonor = math.max(startHonor, honor) end
        end

        local previousRank = tonumber(barData and barData.rank) or math.max(0, rank - 1)
        for index, marker in ipairs(self.breakpoints) do
            local milestone = milestones[index]
            if milestone then
                local ratio = math.max(0, math.min(1, (tonumber(milestone.honor) or 0) / maxHonor))
                local axis = SnapBarPixel(self, 2 + (516 * ratio))
                marker:ClearAllPoints()
                marker:SetPoint("CENTER", self, "LEFT", math.max(10, math.min(510, axis)), 0)
                -- Dividers stay inside the track with a one-unit clearance from
                -- its border; rank icons retain their independent positioning.
                marker.tick:ClearAllPoints()
                marker.tick:SetWidth(1 / math.max(0.01, self:GetEffectiveScale() or 1))
                marker.tick:SetPoint("TOPLEFT", self, "TOPLEFT", math.max(3, math.min(516, axis)), -3)
                marker.tick:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", math.max(3, math.min(516, axis)), 3)
                local resultingRank = tonumber(milestone.rank) or previousRank
                if resultingRank > previousRank then
                    marker.rankIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", resultingRank))
                    marker.rankIcon:Show()
                    marker.tick:Hide()
                    previousRank = resultingRank
                else
                    marker.rankIcon:Hide()
                    marker.tick:Show()
                end
                marker:Show()
            else
                marker:Hide()
            end
        end

        local targetRatio = math.max(0, math.min(1, requiredHonor / maxHonor))
        self.targetGlow:ClearAllPoints()
        self.targetGlow:SetPoint("CENTER", self, "LEFT", math.max(10, math.min(510, 2 + (516 * targetRatio))), 0)
        self.targetRank:Hide() -- the normal breakpoint marker owns the rank icon
        self.elapsed = 0
        self.marker:SetAlpha(1)
        self.markerSpark:SetAlpha(0.55)
        self:SetScript("OnUpdate", function(bar, elapsed)
            bar.elapsed = bar.elapsed + (elapsed or 0)
            local travel = math.min(1, bar.elapsed / 2.25)
            local eased = 1 - ((1 - travel) * (1 - travel) * (1 - travel))
            local animatedHonor = startHonor + ((requiredHonor - startHonor) * eased)
            local realizedHonor = 0
            for _, milestone in ipairs(milestones) do
                local honor = tonumber(milestone and milestone.honor) or 0
                if animatedHonor >= honor then realizedHonor = math.max(realizedHonor, honor) end
            end
            local animatedRatio = math.max(0, math.min(1, animatedHonor / maxHonor))
            local realizedRatio = math.max(0, math.min(animatedRatio, realizedHonor / maxHonor))
            -- Shared snapped boundaries prevent fractional-pixel seams between
            -- the completed fill, striped interval, and moving honor indicator.
            local solidWidth = SnapBarPixel(bar, 516 * realizedRatio)
            local animatedWidth = SnapBarPixel(bar, 516 * animatedRatio)
            local stripeWidth = math.max(0, animatedWidth - solidWidth)
            bar.fill:SetWidth(math.max(1, solidWidth))
            bar.fill:SetShown(realizedRatio > 0)
            bar.stripes:ClearAllPoints()
            bar.stripes:SetPoint("TOPLEFT", bar, "TOPLEFT", 2 + solidWidth, -2)
            bar.stripes:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2 + solidWidth, 2)
            bar.stripes:SetWidth(math.max(1, stripeWidth))
            bar.stripes:SetShown(stripeWidth > 0.5)
            bar.incompleteOverlay:ClearAllPoints()
            bar.incompleteOverlay:SetAllPoints(bar.stripes)
            bar.incompleteOverlay:SetShown(stripeWidth > 0.5)
            local phase = (bar.elapsed * 72) % 16
            bar.stripes:SetTexCoord(phase / 1024, (phase + math.max(1, stripeWidth)) / 1024, 0, 16 / 128)
            bar.marker:ClearAllPoints()
            local markerWidth = 2 / math.max(0.01, bar:GetEffectiveScale() or 1)
            local markerX = math.max(3, math.min(517 - markerWidth, 2 + animatedWidth))
            bar.marker:SetWidth(markerWidth)
            bar.marker:SetPoint("TOPLEFT", bar, "TOPLEFT", markerX, -3)
            bar.marker:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", markerX, 3)
            bar.markerSpark:ClearAllPoints()
            bar.markerSpark:SetPoint("CENTER", bar.marker, "CENTER")
            -- Once the fill arrives, retire the moving indicator over half a
            -- second. Its attached spark fades too; the rank glow is separate.
            local markerAlpha = 1 - math.min(1, math.max(0, (bar.elapsed - 2.25) / 0.5))
            bar.marker:SetAlpha(markerAlpha)
            bar.markerSpark:SetAlpha((0.55 + (0.35 * math.sin(math.min(bar.elapsed, 2.25) * 10))) * markerAlpha)

            if travel < 1 then
                bar.targetGlow:SetSize(34, 34)
                bar.targetGlow:SetAlpha(0.22)
            elseif bar.elapsed < 5.25 then
                local pulse = 0.5 + (0.5 * math.sin((bar.elapsed - 2.25) * 7))
                bar.targetGlow:SetSize(46 + (12 * pulse), 46 + (12 * pulse))
                bar.targetGlow:SetAlpha(0.52 + (0.42 * pulse))
            else
                bar.targetGlow:SetSize(48, 48)
                bar.targetGlow:SetAlpha(0.52)
                bar.marker:SetAlpha(0)
                bar.markerSpark:SetAlpha(0)
                bar.stripes:Hide()
                bar.incompleteOverlay:Hide()
                bar:SetScript("OnUpdate", nil)
            end
        end)
    end

    local noteRule = frame:CreateTexture(nil, "ARTWORK")
    noteRule:SetTexture("Interface\\Buttons\\WHITE8X8")
    noteRule:SetVertexColor(0.95, 0.66, 0.12, 0.32)
    noteRule:SetHeight(1)
    noteRule:SetPoint("LEFT", frame, "LEFT", 22, 0)
    noteRule:SetPoint("RIGHT", frame, "RIGHT", -22, 0)
    noteRule:SetPoint("BOTTOM", frame, "BOTTOM", 0, 36)

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    note:SetText("Your new rank is awarded after the Tuesday weekly reset.")
    note:SetTextColor(0.72, 0.75, 0.82, 1)

    -- Blizzard's native red panel close button includes matching normal,
    -- highlight, and pushed-down artwork.
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame.icon = icon
    frame.title = title
    frame.rankText = rankText
    frame.honorBar = honorBar
    frame.titleFont = ({ title:GetFont() })[1] or "Fonts\\FRIZQT__.TTF"
    -- An unconstrained measuring string reports the full text width, including
    -- on clients where the visible title's width is already ellipsis-clamped.
    frame.titleMeasure = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.titleMeasure:Hide()
    Celebration.rankUpPopup = frame
    return frame
end

local function PositionRankUpPopup(frame)
    if not frame then return end
    local screenHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
    if not frame._userPositioned then
        frame:ClearAllPoints()
        -- Keep the default below the upper-screen banner and closer to the visual
        -- center; the player can drag it elsewhere after it opens.
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, screenHeight / 12)
    end
    frame:SnapToPixels()
end

local function ShowRankUpPopup(rankUpRank, barData, requiredHonor)
    rankUpRank = tonumber(rankUpRank)
    if not rankUpRank or rankUpRank < 1 then return end
    local frame = EnsureRankUpPopup()
    local playerName = UnitName and UnitName("player") or "Player"
    local rankName = GetFactionRankName(rankUpRank) or ("Rank " .. tostring(rankUpRank))
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local rally = faction == "Alliance" and "For the Alliance!" or "Lok'tar ogar!"
    frame.icon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", rankUpRank))
    frame.title:SetText(string.format("Congratulations, %s %s!", rankName, playerName or "Player"))
    frame.titleMeasure:SetText(frame.title:GetText())
    local targetWidth = frame:GetWidth() - 75
    local selectedFontSize = 10
    -- Grow short greetings as well as shrinking long ones. Quarter-point steps
    -- use nearly all the title row without encroaching on the subtext below.
    for fontSize = 34, 10, -0.25 do
        frame.titleMeasure:SetFont(frame.titleFont, fontSize, "")
        if frame.titleMeasure:GetStringWidth() <= targetWidth or fontSize == 10 then
            frame.title:SetFont(frame.titleFont, fontSize, "")
            selectedFontSize = fontSize
            break
        end
    end
    -- A larger greeting also needs vertical room: expand the content row rather
    -- than letting the title crowd the badge. Long greetings retain the compact
    -- layout, and reopening with different text recomputes this from the base.
    local extraHeight = math.max(0, selectedFontSize - 22) * 1.5
    frame.layoutHeight = 230 + extraHeight
    frame:SetHeight(frame.layoutHeight)
    frame.rankText:ClearAllPoints()
    frame.rankText:SetPoint("TOPLEFT", frame, "TOPLEFT", 126, -88 - (extraHeight / 2))
    frame.rankText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -88 - (extraHeight / 2))
    frame.rankText:SetText(string.format(
        "You have earned enough honor to be granted the rank of |cffffffff%s|r and all the Quartermaster purchasing privileges therein. %s",
        rankName, rally))
    PositionRankUpPopup(frame)
    frame:SetAlpha(0)
    frame:Show()
    frame.honorBar:Start(rankUpRank, faction, barData, requiredHonor)
    frame._fadeElapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        -- Hidden-frame layout can settle only once shown; align once more before
        -- the opening fade makes the border visible.
        if self._fadeElapsed == 0 then self:SnapToPixels() end
        self._fadeElapsed = (self._fadeElapsed or 0) + (elapsed or 0)
        self:SetAlpha(math.min(1, self._fadeElapsed / 0.22))
        if self._fadeElapsed >= 0.22 then self:SetScript("OnUpdate", nil) end
    end)
end

local function EnsureBreakpointBanner()
    if Celebration.banner then return Celebration.banner end

    local frame = CreateFrame("Frame", "ZurkMapsBreakpointBanner", UIParent)
    frame:SetSize(640, 72)
    -- Keep the celebration well above Blizzard's zone/location text, which can
    -- appear at the same time when zoning back into a city after a battleground.
    frame:SetPoint("TOP", UIParent, "TOP", 0, -105)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:Hide()

    local leftSkull = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    leftSkull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    leftSkull:SetSize(30, 30)
    leftSkull:SetPoint("RIGHT", frame, "CENTER", -190, 0)

    local rightSkull = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    rightSkull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    rightSkull:SetSize(30, 30)
    rightSkull:SetPoint("LEFT", frame, "CENTER", 190, 0)

    -- Start from a Blizzard font template so the FontString always has a valid
    -- font before SetText() is called. Classic Era can return false from SetFont
    -- without throwing, so pcall success alone is not enough to prove the font
    -- was actually applied.
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER", frame, "CENTER", 0, 1)
    local callOK, fontOK = pcall(text.SetFont, text, "Fonts\\FRIZQT__.TTF", 30, "THICKOUTLINE")
    if not callOK or fontOK == false then
        if GameFontNormalHuge then text:SetFontObject(GameFontNormalHuge) end
    end
    text:SetText("BREAKPOINT REACHED")
    text:SetTextColor(1.0, 0.06, 0.06, 1)
    text:SetShadowColor(0.12, 0, 0, 1)
    text:SetShadowOffset(2, -2)

    -- Thin red rules make the message feel like its own celebration banner
    -- without introducing another opaque UI box over the game world.
    local topRule = frame:CreateTexture(nil, "ARTWORK")
    topRule:SetTexture("Interface\\Buttons\\WHITE8X8")
    topRule:SetVertexColor(0.75, 0.03, 0.03, 0.85)
    topRule:SetSize(410, 1)
    topRule:SetPoint("BOTTOM", text, "TOP", 0, 7)

    local bottomRule = frame:CreateTexture(nil, "ARTWORK")
    bottomRule:SetTexture("Interface\\Buttons\\WHITE8X8")
    bottomRule:SetVertexColor(0.75, 0.03, 0.03, 0.85)
    bottomRule:SetSize(410, 1)
    bottomRule:SetPoint("TOP", text, "BOTTOM", 0, -7)

    frame.text = text
    frame.leftSkull = leftSkull
    frame.rightSkull = rightSkull
    frame:SetScript("OnUpdate", function(self, elapsed)
        self._elapsed = (self._elapsed or 0) + (elapsed or 0)
        local t = self._elapsed
        local alpha = 1
        if t < 0.15 then
            alpha = t / 0.15
        elseif t > 4.0 then
            alpha = math.max(0, 1 - ((t - 4.0) / 1.0))
        end
        self:SetAlpha(alpha)

        -- A restrained opening punch gives the warning more character while
        -- settling back to normal size quickly enough to remain readable.
        if t < 0.30 then
            self:SetScale(1.10 - (0.10 * (t / 0.30)))
        else
            self:SetScale(1)
        end

        if t >= 5.0 then
            self:Hide()
            self:SetAlpha(1)
            self:SetScale(1)
            self._elapsed = 0
        end
    end)

    Celebration.banner = frame
    return frame
end

local function ShowRaidWarning()
    local frame = EnsureBreakpointBanner()
    frame._elapsed = 0
    frame:SetAlpha(0)
    frame:SetScale(1.10)
    frame:Show()
end

local function PlayVictorySound()
    if type(PlaySoundFile) == "function" then
        pcall(PlaySoundFile, SOUND_FILE, "Master")
    end
end

local function PlayBreakpointRaidWarningSound()
    if type(PlaySound) ~= "function" then return end
    local soundKit = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959
    pcall(PlaySound, soundKit, "Master")
end

local function Celebrate(requiredHonor, currentHonor, rankUpRank, barData)
    -- All three celebration cues are issued in the same UI frame. The native
    -- Raid Warning sound provides an immediate attack while the fanfare starts
    -- alongside the banner.
    PlayBreakpointRaidWarningSound()
    ShowRaidWarning()
    PlayVictorySound()
    if tonumber(rankUpRank) and tonumber(rankUpRank) > 0 then
        ShowRankUpPopup(rankUpRank, barData, requiredHonor)
    else
        AddChatMessage(requiredHonor)
    end
    if ZurkMapsHonorWidget and type(ZurkMapsHonorWidget.FlashBreakpoint) == "function" then
        ZurkMapsHonorWidget.FlashBreakpoint(requiredHonor)
    end
end

local function IsInBattleground()
    if type(IsInInstance) ~= "function" then return false end
    local ok, inInstance, instanceType = pcall(IsInInstance)
    return ok and inInstance and (instanceType == "pvp" or instanceType == "arena")
end

local function QueueOrCelebrate(state, requiredHonor, currentHonor, rankUpRank, weekKey, barData)
    if IsInBattleground() then
        -- SavedVariables preserve the earned celebration through the battleground
        -- loading screen (and even a logout before the player leaves the match).
        state.pending = {
            requiredHonor = requiredHonor,
            currentHonor = currentHonor,
            rankUpRank = rankUpRank,
            weekKey = weekKey,
            barData = barData,
        }
        return
    end
    Celebrate(requiredHonor, currentHonor, rankUpRank, barData)
end

local function FlushPendingCelebration(state, weekKey)
    local pending = state and state.pending
    if type(pending) ~= "table" or IsInBattleground() then return false end
    state.pending = nil
    if pending.weekKey and weekKey and pending.weekKey ~= weekKey then return false end
    local requiredHonor = tonumber(pending.requiredHonor)
    if not requiredHonor then return false end
    Celebrate(requiredHonor, tonumber(pending.currentHonor) or requiredHonor, tonumber(pending.rankUpRank), pending.barData)
    return true
end

local function MarkCurrentMilestonesSeen(state, milestones, currentHonor)
    for _, milestone in ipairs(milestones or {}) do
        local required = tonumber(milestone and milestone.honor)
        if required and currentHonor >= required then
            state.seen[tostring(math.floor(required + 0.5))] = true
        end
    end
end

function Celebration.Check()
    if not ZurkMapsAVHonor or type(ZurkMapsAVHonor.GetBreakpointCelebrationSnapshot) ~= "function" then return end
    local ok, snapshot = pcall(ZurkMapsAVHonor.GetBreakpointCelebrationSnapshot)
    if not ok or type(snapshot) ~= "table" then return end

    local currentHonor = tonumber(snapshot.currentHonor) or 0
    local milestones = snapshot.milestones or {}
    local state = EnsureState()
    local weekKey = GetWeekKey()

    -- A breakpoint earned in a battleground is held until IsInInstance reports
    -- that the player has arrived back in the world outside that battleground.
    FlushPendingCelebration(state, weekKey)

    -- A weekly reset can be identified either by the reset timestamp or by honor
    -- dropping. Both paths clear the prior week's completed breakpoints.
    if weekKey and state.weekKey and state.weekKey ~= weekKey then
        state.seen = {}
        state.lastHonor = nil
    elseif tonumber(state.lastHonor) and currentHonor < tonumber(state.lastHonor) then
        state.seen = {}
        state.lastHonor = nil
    end
    if weekKey then state.weekKey = weekKey end

    -- Never fire retroactively on login/reload. Establish the session baseline and
    -- consider everything already below the player completed for celebration purposes.
    if not Celebration.sessionInitialized then
        Celebration.sessionInitialized = true
        state.lastHonor = currentHonor
        MarkCurrentMilestonesSeen(state, milestones, currentHonor)
        return
    end

    local previousHonor = tonumber(state.lastHonor) or currentHonor
    if currentHonor <= previousHonor then
        state.lastHonor = currentHonor
        return
    end

    local crossed = nil
    for _, milestone in ipairs(milestones) do
        local required = tonumber(milestone and milestone.honor)
        local key = required and tostring(math.floor(required + 0.5)) or nil
        if required and key and previousHonor < required and currentHonor >= required and not state.seen[key] then
            if not crossed or required > (tonumber(crossed.honor) or 0) then crossed = milestone end
        end
        if required and currentHonor >= required then
            state.seen[key] = true
        end
    end

    state.lastHonor = currentHonor
    if crossed then
        local required = tonumber(crossed.honor)
        local rankUpRank = GetRankUpForMilestone(snapshot, crossed)
        local barData = { rank = snapshot.rank, milestones = snapshot.milestones }
        if required then QueueOrCelebrate(state, required, currentHonor, rankUpRank, weekKey, barData) end
    end
end

function Celebration.TestRankUp()
    local snapshot = ZurkMapsAVHonor and ZurkMapsAVHonor.GetBreakpointCelebrationSnapshot
        and ZurkMapsAVHonor.GetBreakpointCelebrationSnapshot() or {}
    local baseRank = tonumber(snapshot.rank) or 0
    local targetMilestone, rank
    for _, milestone in ipairs(snapshot.milestones or {}) do
        if (tonumber(milestone.rank) or baseRank) > baseRank then
            targetMilestone = milestone
            rank = tonumber(milestone.rank)
            break
        end
    end
    rank = rank or math.min(14, math.max(1, baseRank + 1))
    local required = tonumber(targetMilestone and targetMilestone.honor) or tonumber(snapshot.currentHonor) or 1
    Celebrate(required, required, rank, { rank = baseRank, milestones = snapshot.milestones })
end

SLASH_ZURKMAPSCELEBRATION1 = "/zurkcelebrate"
SlashCmdList.ZURKMAPSCELEBRATION = function()
    Celebration.TestRankUp()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        PositionRankUpPopup(Celebration.rankUpPopup)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then Celebration.sessionInitialized = false end

    -- Check immediately first. Some Classic honor events update the weekly
    -- value synchronously; when they do, the celebration should not wait.
    Celebration.Check()

    -- The scoreboard/honor cache can also land a fraction of a second later,
    -- so retry briefly. The seen/lastHonor guards prevent duplicate celebrations.
    if C_Timer and C_Timer.After then
        C_Timer.After(0.10, Celebration.Check)
        C_Timer.After(0.30, Celebration.Check)
    end
end)

if C_Timer and type(C_Timer.NewTicker) == "function" then
    Celebration.ticker = C_Timer.NewTicker(1.0, Celebration.Check)
else
    eventFrame.elapsed = 0
    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + (elapsed or 0)
        if self.elapsed < 1.0 then return end
        self.elapsed = 0
        Celebration.Check()
    end)
end
