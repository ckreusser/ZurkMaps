-- Zurk Maps weekly honor milestone bar.
-- Ranking calculations are adapted from the Ranker addon supplied during AVMap development.
ZurkMapsABHonor = ZurkMapsABHonor or {}

local Honor = ZurkMapsABHonor

local CONTRIBUTION_FLOOR = { 0, 2000, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000, 50000, 55000, 60000 }
local CONTRIBUTION_CEILING = { 2000, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000, 50000, 55000, 60000, 65000 }
local RANK_CHANGE_FACTOR = { 1, 1, 1, 0.8, 0.8, 0.8, 0.7, 0.7, 0.6, 0.5, 0.5, 0.4, 0.4, 0.34, 0.34 }
local HONOR_INCREMENTS = { 0, 4500, 11250, 22500, 33750, 45000, 77500, 110000, 142500, 175000, 256250, 337500, 418750, 500000 }
local MAX_RANK = 14
local HEADER_BG_R, HEADER_BG_G, HEADER_BG_B, HEADER_BG_A = 0.018, 0.012, 0.008, 0.97
local MAP_BORDER_R, MAP_BORDER_G, MAP_BORDER_B, MAP_BORDER_A = 0.84, 0.56, 0.31, 0.98

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function IsHorizontalWidgetBar(bar)
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.IsBarHorizontal then
        return ZurkMapsHonorWidget.IsBarHorizontal(bar)
    end
    return bar and bar._honorWidgetState and bar._honorWidgetState.orientation == "HORIZONTAL"
end

local UNREALIZED_STRIPE_TEXTURE_VERTICAL = "Interface\\AddOns\\ZurkMaps\\Media\\HonorUnrealizedStripes_Vertical"
local UNREALIZED_STRIPE_TEXTURE_HORIZONTAL = "Interface\\AddOns\\ZurkMaps\\Media\\HonorUnrealizedStripes_Horizontal"
local UNREALIZED_STRIPE_TILE = 16
local UNREALIZED_STRIPE_LONG = 1024
local UNREALIZED_STRIPE_SHORT = 128
local UNREALIZED_STRIPE_SWEEP_DURATION = 1.05

local function ApplyUnrealizedStripeTexCoord(bar, horizontal, width, height, offset)
    local stripe = bar and bar.unrealizedStripes
    if not stripe then return end

    -- R6g's 16x16 stripe art is pre-repeated into long source textures. Crop
    -- those sources with UVs that always stay inside 0..1 instead of asking the
    -- Classic client to tile beyond the source texture. One source pixel maps
    -- to one bar unit, so the original stripe width, spacing, and ~45-degree
    -- geometry remain stable when the bar is short, long, narrow, or resized.
    width = math.max(1, tonumber(width) or 1)
    height = math.max(1, tonumber(height) or 1)
    offset = Clamp(tonumber(offset) or 0, 0, 1)

    if horizontal then
        local phase = UNREALIZED_STRIPE_TILE * offset
        stripe:SetTexture(UNREALIZED_STRIPE_TEXTURE_HORIZONTAL)
        stripe:SetTexCoord(
            phase / UNREALIZED_STRIPE_LONG,
            (phase + width) / UNREALIZED_STRIPE_LONG,
            0,
            height / UNREALIZED_STRIPE_SHORT
        )
    else
        -- R6g swept the vertical phase in the negative-V direction. Starting
        -- one full tile into the pre-rendered texture gives the identical static
        -- phase while keeping the entire animated crop inside valid UV bounds.
        local phase = UNREALIZED_STRIPE_TILE * (1 - offset)
        stripe:SetTexture(UNREALIZED_STRIPE_TEXTURE_VERTICAL)
        stripe:SetTexCoord(
            0,
            width / UNREALIZED_STRIPE_SHORT,
            phase / UNREALIZED_STRIPE_LONG,
            (phase + height) / UNREALIZED_STRIPE_LONG
        )
    end
end

local function StartUnrealizedStripeSweep(bar)
    if not bar or not bar.unrealizedStripes or not bar._unrealizedStripeAnimator then return end
    if not bar.unrealizedStripes:IsShown() then return end
    bar._unrealizedStripeSweepStart = (GetTime and GetTime()) or 0
    bar._unrealizedStripeAnimator:Show()
end


local function FormatNumber(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    local sign = value < 0 and "-" or ""
    value = math.abs(value)
    local text = tostring(value)
    while true do
        local updated, count = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
        text = updated
        if count == 0 then break end
    end
    return sign .. text
end

local function FormatShort(value)
    value = tonumber(value) or 0
    if value >= 100000 then
        local rounded = math.floor((value / 1000) + 0.5)
        return tostring(rounded) .. "k"
    elseif value >= 1000 then
        local rounded = math.floor((value / 100) + 0.5) / 10
        if rounded == math.floor(rounded) then
            return tostring(math.floor(rounded)) .. "k"
        end
        return string.format("%.1fk", rounded)
    end
    return tostring(math.floor(value + 0.5))
end

local function GetCurrentRankAndProgress()
    local rank = 0
    local progress = 0
    if type(UnitPVPRank) == "function" and type(GetPVPRankInfo) == "function" then
        local rankID = UnitPVPRank("player")
        if rankID then
            local _, rankNumber = GetPVPRankInfo(rankID)
            rank = tonumber(rankNumber) or 0
        end
    end
    if type(GetPVPRankProgress) == "function" then
        progress = tonumber(GetPVPRankProgress()) or 0
    end
    progress = Clamp(progress, 0, 1)
    return rank, progress
end

local function GetCurrentWeekStats()
    local hk, honor = 0, 0
    if type(GetPVPThisWeekStats) == "function" then
        hk, honor = GetPVPThisWeekStats()
    end
    return tonumber(hk) or 0, (tonumber(honor) or 0) + (tonumber(Honor.simulatedHonor) or 0)
end

local function CalculateContributionPoints(rank, progress)
    if not rank or rank <= 1 then return 0 end
    local floorValue = CONTRIBUTION_FLOOR[rank]
    local ceilingValue = CONTRIBUTION_CEILING[rank]
    if not floorValue or not ceilingValue then return 0 end
    return ((ceilingValue - floorValue) * (progress or 1)) + floorValue
end

local function CalculatePredictedRank(inputRank, inputCP)
    if inputRank == nil then return nil, nil end
    local rank, progress
    for key = 1, #CONTRIBUTION_CEILING do
        if inputCP >= CONTRIBUTION_FLOOR[key] and key <= inputRank then
            rank = key
            progress = (inputCP - CONTRIBUTION_FLOOR[key]) / (CONTRIBUTION_CEILING[key] - CONTRIBUTION_FLOOR[key])
            if key >= MAX_RANK then
                rank = MAX_RANK
                progress = 0
            end
        else
            return rank, progress
        end
    end
    return rank, progress
end

local function CalculateCPGain(rank, objectiveRank, predictedCP, currentCP)
    if objectiveRank == nil then return 0, currentCP, 0 end
    if rank == 0 then rank = 1 end

    local objectiveCP, newCP, gainedCP, bonusCP = 0, 0, 0, 0
    local buckets = objectiveRank - rank

    for key = rank + 1, objectiveRank do
        if key ~= 1 then
            gainedCP = (CONTRIBUTION_FLOOR[key] - CONTRIBUTION_FLOOR[key - 1]) * RANK_CHANGE_FACTOR[key]
        end

        if key == rank + 1 then
            if rank == 9 then
                gainedCP = 3000
            elseif rank == 11 then
                gainedCP = 2500
            end

            local gainedCPwithCeiling = (CONTRIBUTION_FLOOR[key] - CONTRIBUTION_FLOOR[key - 1]) *
                (1 - ((currentCP - CONTRIBUTION_FLOOR[key - 1]) /
                (CONTRIBUTION_FLOOR[key] - CONTRIBUTION_FLOOR[key - 1])))
            if gainedCPwithCeiling < gainedCP then gainedCP = gainedCPwithCeiling end

            if (rank == 6 and buckets == 4) or
                (rank == 7 and buckets >= 3) or
                (rank == 8 and (buckets == 2 or buckets == 3)) or
                (rank == 9 and buckets >= 3) or
                (rank == 10 and buckets >= 2) then
                bonusCP = 500
            elseif rank == 8 and buckets == 4 then
                bonusCP = 1000
            end
        end

        objectiveCP = objectiveCP + gainedCP
    end

    if objectiveCP == 0 then
        objectiveCP = predictedCP or 0
        newCP = predictedCP or currentCP
    else
        newCP = currentCP + objectiveCP
    end

    return objectiveCP, newCP, bonusCP
end

-- Ranker's visible weekly milestones skip the otherwise redundant +1 qualification bucket.
local function BuildMilestones(rank, progress)
    if rank <= 0 then rank = 1 end
    if rank >= MAX_RANK then return {} end

    local milestoneRanks = {}
    if rank == 1 then
        milestoneRanks = { 3, 4, 5 }
    else
        milestoneRanks[#milestoneRanks + 1] = rank
        if rank + 2 <= MAX_RANK then milestoneRanks[#milestoneRanks + 1] = rank + 2 end
        if rank + 3 <= MAX_RANK then milestoneRanks[#milestoneRanks + 1] = rank + 3 end
        if rank + 4 <= MAX_RANK then milestoneRanks[#milestoneRanks + 1] = rank + 4 end
    end

    local currentCP = CalculateContributionPoints(rank, math.ceil(progress * 1000) / 1000)
    local milestones = {}

    for index, milestoneRank in ipairs(milestoneRanks) do
        local honorNeed = HONOR_INCREMENTS[milestoneRank] or 0
        local objectiveRank = milestoneRank

        -- Ranker's first visible milestone is the decay-prevention hop: qualifying for
        -- the current rank awards the next bucket. R1 is a separate 15-HK case.
        if rank > 1 and index == 1 then
            objectiveRank = math.min(rank + 1, MAX_RANK)
        end

        local predictedCP = CONTRIBUTION_FLOOR[objectiveRank] or 0
        local _, newCP, bonusCP = CalculateCPGain(rank, objectiveRank, predictedCP, currentCP)
        local predictedRank, predictedProgress = CalculatePredictedRank(rank + 4, newCP + (bonusCP or 0))

        milestones[#milestones + 1] = {
            honor = honorNeed,
            objectiveRank = objectiveRank,
            rank = predictedRank or rank,
            progress = predictedProgress or progress,
        }
    end

    return milestones
end

local function GetFactionHonorColor()
    -- Prefer the live Blizzard honor-pane status-bar color when it exists.
    if HonorFrameProgressBar and HonorFrameProgressBar.GetStatusBarColor then
        local r, g, b = HonorFrameProgressBar:GetStatusBarColor()
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            -- Some skins leave the bar white; in that case use the faction fallback below.
            if not (r > 0.88 and g > 0.88 and b > 0.88) then
                return r, g, b
            end
        end
    end

    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    if faction == "Horde" then
        return 0.56, 0.07, 0.11 -- maroon/crimson Honor-pane feel
    end
    return 0.10, 0.32, 0.66 -- Alliance Honor-pane blue
end

local function RankIconTag(rank, size)
    rank = tonumber(rank) or 0
    size = tonumber(size) or 12
    if rank <= 0 then return "" end
    return string.format("|TInterface\\PvPRankBadges\\PvPRank%02d:%d|t", rank, size)
end

local function RankLabel(rank, progress)
    return string.format("%s Rank %d — %.2f%%", RankIconTag(rank, 12), tonumber(rank) or 0, (tonumber(progress) or 0) * 100)
end

local function AddTooltipLineForMilestone(milestone, reached)
    if not milestone then return end
    local left = FormatNumber(milestone.honor) .. " honor"
    local right = string.format("R%d %.1f%%", milestone.rank or 0, (milestone.progress or 0) * 100)
    if reached then
        GameTooltip:AddDoubleLine(left, right, 0.65, 0.65, 0.65, 0.65, 0.65, 0.65)
    else
        GameTooltip:AddDoubleLine(left, right, 1.0, 0.86, 0.28, 1.0, 0.86, 0.28)
    end
end

local function DescribeMilestoneDelta(currentHonor, milestoneHonor)
    local delta = (tonumber(milestoneHonor) or 0) - (tonumber(currentHonor) or 0)
    if delta > 0 then
        return FormatNumber(delta) .. " more honor needed"
    elseif delta < 0 then
        return FormatNumber(math.abs(delta)) .. " honor over this breakpoint"
    end
    return "Exactly at this breakpoint"
end

local function GetEstimateBattleground()
    if ZurkMapsBGHistory and ZurkMapsBGHistory.GetMostRecentBattleground then
        local bgName = ZurkMapsBGHistory.GetMostRecentBattleground()
        if bgName then return bgName end
    end
    return (Honor.config and Honor.config.battlegroundName) or "Alterac Valley"
end

local function GetConfiguredAverageHonor(limit)
    local bgName = GetEstimateBattleground()
    if ZurkMapsBGHistory and ZurkMapsBGHistory.GetAverageHonor then
        return ZurkMapsBGHistory.GetAverageHonor(bgName, limit or 10)
    end
    if Honor.config and type(Honor.config.getAverageHonor) == "function" then
        return Honor.config.getAverageHonor(limit or 10)
    end
    return nil, 0
end

local function GetRunLabelSingular()
    local bgName = GetEstimateBattleground()
    if ZurkMapsBGHistory and ZurkMapsBGHistory.GetBattlegroundAcronym then
        return ZurkMapsBGHistory.GetBattlegroundAcronym(bgName)
    end
    if bgName == "Warsong Gulch" then return "WSG" end
    if bgName == "Arathi Basin" then return "AB" end
    return "AV"
end

local function GetRunLabelPlural()
    return GetRunLabelSingular() .. "s"
end

local function GetBattlegroundDisplayName()
    return GetEstimateBattleground()
end

local function GetEstimateLineLabel()
    return "Estimated " .. GetRunLabelPlural() .. " Until Next Breakpoint"
end

local function GetAverageLineLabel()
    return "Recent " .. GetRunLabelSingular() .. " Average"
end

local function GetMilestoneRunEstimate(state, milestone)
    local remaining = math.max(0, (tonumber(milestone.honor) or 0) - (tonumber(state.currentHonor) or 0))
    local average, sampleCount = GetConfiguredAverageHonor(10)
    local runs = nil
    if average and average > 0 and sampleCount and sampleCount > 0 and remaining > 0 then
        runs = math.ceil(remaining / average)
    elseif remaining <= 0 then
        runs = 0
    end
    return {
        remaining = remaining,
        average = average,
        sampleCount = sampleCount or 0,
        runs = runs,
    }
end

local function AddBGEstimateToTooltip(state, milestone)
    local estimate = GetMilestoneRunEstimate(state, milestone)
    if estimate.remaining <= 0 then
        GameTooltip:AddDoubleLine(GetEstimateLineLabel(), "0", 0.72, 0.72, 0.72, 0.72, 0.72, 0.72)
        return
    end

    if estimate.average and estimate.average > 0 and estimate.sampleCount > 0 then
        local sampleLabel = estimate.sampleCount == 1 and ("last " .. GetRunLabelSingular()) or ("last " .. estimate.sampleCount .. " " .. GetRunLabelPlural())
        GameTooltip:AddDoubleLine(GetEstimateLineLabel(), tostring(estimate.runs), 0.82, 0.82, 0.82, 1.0, 0.86, 0.28)
        GameTooltip:AddDoubleLine(GetAverageLineLabel(), FormatNumber(estimate.average) .. " honor/game (" .. sampleLabel .. ")", 0.65, 0.65, 0.65, 0.65, 0.65, 0.65)
    else
        GameTooltip:AddDoubleLine(GetEstimateLineLabel(), "Unknown", 0.82, 0.82, 0.82, 0.72, 0.72, 0.72)
        GameTooltip:AddLine("Complete a few " .. GetBattlegroundDisplayName() .. " games to build your honor/game average.", 0.65, 0.65, 0.65, true)
    end
end

local function SendBattlegroundCallout(message)
    if not message or message == "" then return end

    -- The detached honor bar follows the most recently played battleground,
    -- so its callout channel must follow that battleground too rather than the
    -- map file that originally created this particular bar instance.
    local bgName = GetEstimateBattleground()
    local mapKey = bgName == "Warsong Gulch" and "WSG"
        or bgName == "Arathi Basin" and "AB"
        or bgName == "Alterac Valley" and "AV"
        or nil
    if mapKey and ZurkMapsOptions and type(ZurkMapsOptions.SendCallout) == "function" then
        ZurkMapsOptions.SendCallout(mapKey, message)
        return
    end

    if Honor.config and type(Honor.config.sendBGCallout) == "function" then
        Honor.config.sendBGCallout(message)
        return
    end
    if SendChatMessage then
        SendChatMessage(message, "BATTLEGROUND")
    end
end

local function GetMilestoneOrdinal(state, milestone)
    for index, candidate in ipairs((state and state.milestones) or {}) do
        if candidate == milestone or ((candidate.honor or -1) == (milestone and milestone.honor or -2)) then
            if index <= 1 then return "next" end
            if index == 2 then return "2nd" end
            if index == 3 then return "3rd" end
            local lastTwo = index % 100
            local suffix = "th"
            if lastTwo < 11 or lastTwo > 13 then
                local last = index % 10
                if last == 1 then suffix = "st"
                elseif last == 2 then suffix = "nd"
                elseif last == 3 then suffix = "rd" end
            end
            return tostring(index) .. suffix
        end
    end
    return "next"
end

local function GetMilestoneRankUp(state, milestone)
    if not state or not milestone then return nil end
    local previousRank = tonumber(state.rank) or 0
    for _, candidate in ipairs(state.milestones or {}) do
        local resultingRank = tonumber(candidate.rank) or previousRank
        local isRankUp = resultingRank > previousRank
        if candidate == milestone or ((candidate.honor or -1) == (milestone.honor or -2)) then
            return isRankUp and resultingRank or nil
        end
        if isRankUp then
            previousRank = resultingRank
        end
    end
    return nil
end

local function ShiftCalloutMilestone(state, milestone)
    if not state or not milestone then return end
    local estimate = GetMilestoneRunEstimate(state, milestone)
    local runCount = estimate.runs
    local acronym = GetRunLabelSingular()
    local ordinal = GetMilestoneOrdinal(state, milestone)
    local rankUpRank = GetMilestoneRankUp(state, milestone)

    local message
    if runCount == nil then
        if rankUpRank then
            message = string.format("I don't have enough %s history yet to estimate R%d", acronym, rankUpRank)
        else
            message = string.format("I don't have enough %s history yet to estimate my %s breakpoint", acronym, ordinal)
        end
    else
        local runLabel = runCount == 1 and acronym or (acronym .. "s")
        local remainingHonor = FormatNumber(estimate.remaining or 0)
        if rankUpRank then
            message = string.format("I need about %d more %s (%s honor) to get to R%d", runCount, runLabel, remainingHonor, rankUpRank)
        else
            message = string.format("I need about %d more %s (%s honor) to get to my %s breakpoint", runCount, runLabel, remainingHonor, ordinal)
        end
    end
    SendBattlegroundCallout(message)
end

local function ShowMilestoneTooltip(owner, state, milestone)
    if not owner or not state or not milestone then return end

    GameTooltip:SetOwner(Honor.frame or owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local tooltipBar = Honor.frame or owner
    if IsHorizontalWidgetBar(tooltipBar) then
        GameTooltip:SetPoint("BOTTOMLEFT", tooltipBar, "TOPLEFT", 0, 2)
    else
        GameTooltip:SetPoint("TOPRIGHT", tooltipBar, "TOPLEFT", -2, 0)
    end

    local resultRank = tonumber(milestone.rank) or state.rank or 0
    local resultProgress = tonumber(milestone.progress) or 0
    local currentRank = tonumber(state.rank) or 0
    local currentProgress = tonumber(state.progress) or 0
    local reached = (state.currentHonor or 0) >= (milestone.honor or 0)
    local leftR, leftG, leftB = reached and 0.72 or 1.0, reached and 0.72 or 0.86, reached and 0.72 or 0.28

    GameTooltip:SetText(string.format("%s %s Honor Breakpoint", RankIconTag(resultRank, 14), FormatNumber(milestone.honor)))
    if GameTooltipTextLeft1 then
        GameTooltipTextLeft1:SetJustifyH("CENTER")
    end

    GameTooltip:AddDoubleLine("Status", DescribeMilestoneDelta(state.currentHonor, milestone.honor), leftR, leftG, leftB, leftR, leftG, leftB)
    GameTooltip:AddDoubleLine("Current Standing", RankLabel(currentRank, currentProgress), 0.82, 0.82, 0.82, 1, 1, 1)
    GameTooltip:AddDoubleLine("At This Breakpoint", RankLabel(resultRank, resultProgress), 0.82, 0.82, 0.82, 1, 1, 1)

    GameTooltip:AddLine(" ")
    AddBGEstimateToTooltip(state, milestone)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Shift-click to call out this milestone.", 0.78, 0.70, 0.48, true)
    GameTooltip:Show()
end

local function HandleShiftClick(owner, milestone)
    if not owner then return end

    -- CTRL+SHIFT-click belongs to the Honor Bar promo set. Keep plain
    -- SHIFT-click reserved for the existing milestone callout behavior.
    if IsControlKeyDown and IsControlKeyDown() and ZurkMapsPromos and ZurkMapsPromos.SendRandomPromo then
        ZurkMapsPromos.SendRandomPromo("HONOR")
        return
    end

    local bar = Honor.frame or owner
    local state = (bar and bar.state) or nil
    if not state then return end
    milestone = milestone or GetHoveredMilestone(bar) or state.nextMilestone or state.lastMilestone or (state.milestones and state.milestones[1])
    if not milestone then return end
    ShiftCalloutMilestone(state, milestone)
end

local function GetHoveredMilestone(bar)
    if not bar or not bar.segmentBounds or not GetCursorPosition then return nil end
    local cursorX, cursorY = GetCursorPosition()
    local effectiveScale = (bar.GetEffectiveScale and bar:GetEffectiveScale()) or 1
    if not effectiveScale or effectiveScale == 0 then effectiveScale = 1 end
    local horizontal = IsHorizontalWidgetBar(bar)
    local axis
    if horizontal then
        local left = bar:GetLeft()
        if not left then return nil end
        axis = (cursorX - (left * effectiveScale)) / effectiveScale
    else
        local bottom = bar:GetBottom()
        if not bottom then return nil end
        axis = (cursorY - (bottom * effectiveScale)) / effectiveScale
    end
    for _, bounds in ipairs(bar.segmentBounds) do
        if axis >= bounds.lower and axis <= bounds.upper then
            return bounds.milestone
        end
    end
    if bar.state and bar.state.nextMilestone then return bar.state.nextMilestone end
    return nil
end

function Honor.Create(parentFrame, addonFrame, mapHeight, config)
    if Honor.frame then return Honor.frame end
    if not parentFrame then return nil end
    Honor.config = config or Honor.config or {}

    local bar = CreateFrame("Frame", "ZurkMapsABHonorBar", parentFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bar:SetWidth(20)
    bar:SetPoint("TOPRIGHT", parentFrame, "TOPLEFT", 2, -1)
    bar:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMLEFT", 2, 1)
    bar:SetFrameLevel(parentFrame:GetFrameLevel() + 25)
    bar:EnableMouse(true)

    if bar.SetBackdrop then
        bar:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        bar:SetBackdropColor(0, 0, 0, 0)
        bar:SetBackdropBorderColor(MAP_BORDER_R, MAP_BORDER_G, MAP_BORDER_B, MAP_BORDER_A)
    end

    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -2)
    bar.track:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
    bar.track:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.track:SetVertexColor(HEADER_BG_R, HEADER_BG_G, HEADER_BG_B, 0.82)

    bar.fill = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    bar.fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    -- Rotate Blizzard's horizontal status-bar grain 90 degrees for this vertical bar.
    bar.fill:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
    bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2, 2)
    bar.fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)

    bar.incompleteOverlay = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bar.incompleteOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.incompleteOverlay:SetVertexColor(0.015, 0.010, 0.008, 0.34)
    bar.incompleteOverlay:Hide()

    -- Ranker-inspired unrealized-honor stripes. The pattern stays static during
    -- normal play and briefly sweeps only when weekly honor actually increases.
    bar.unrealizedStripes = bar:CreateTexture(nil, "ARTWORK", nil, 4)
    bar.unrealizedStripes:SetTexture(UNREALIZED_STRIPE_TEXTURE_VERTICAL)
    bar.unrealizedStripes:SetBlendMode("BLEND")
    bar.unrealizedStripes:Hide()

    local stripeAnimator = CreateFrame("Frame", nil, bar)
    stripeAnimator:Hide()
    stripeAnimator:SetScript("OnUpdate", function(self)
        local started = tonumber(bar._unrealizedStripeSweepStart) or 0
        local now = (GetTime and GetTime()) or started
        local elapsed = math.max(0, now - started)
        local progress = Clamp(elapsed / UNREALIZED_STRIPE_SWEEP_DURATION, 0, 1)
        -- One complete tile of travel: lively on honor gain, motionless otherwise.
        ApplyUnrealizedStripeTexCoord(bar, bar._unrealizedStripeHorizontal, bar._unrealizedStripeWidth, bar._unrealizedStripeHeight, progress)
        if progress >= 1 then
            ApplyUnrealizedStripeTexCoord(bar, bar._unrealizedStripeHorizontal, bar._unrealizedStripeWidth, bar._unrealizedStripeHeight, 0)
            self:Hide()
        end
    end)
    bar._unrealizedStripeAnimator = stripeAnimator

    bar.currentLine = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    bar.currentLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.currentLine:SetHeight(1)
    bar.currentLine:SetWidth(12)
    bar.currentLine:SetVertexColor(1.0, 0.92, 0.55, 1)


    bar.segments = {}
    for i = 1, 4 do
        local segment = CreateFrame("Button", nil, bar)
        segment:EnableMouse(true)
        segment:SetFrameStrata(bar:GetFrameStrata())
        segment:SetFrameLevel(bar:GetFrameLevel() + 1)
        segment:SetWidth(20)
        segment.milestone = nil
        segment:SetScript("OnEnter", function(self)
            if self.milestone and bar.state then
                ShowMilestoneTooltip(self, bar.state, self.milestone)
            end
        end)
        segment:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        segment:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        segment:SetScript("OnClick", function(self, button)
            if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
                HandleShiftClick(self, self.milestone)
            end
        end)
        segment:Hide()
        bar.segments[i] = segment
    end

    bar.markers = {}
    for i = 1, 4 do
        local marker = CreateFrame("Button", nil, bar)
        marker:SetSize(14, 16)
        marker:EnableMouse(true)
        marker:SetFrameStrata(bar:GetFrameStrata())
        marker:SetFrameLevel(bar:GetFrameLevel() + 12)

        marker.tick = marker:CreateTexture(nil, "OVERLAY", nil, 6)
        marker.tick:SetTexture("Interface\\Buttons\\WHITE8X8")
        marker.tick:SetHeight(1)
        marker.tick:SetWidth(10)
        marker.tick:SetPoint("CENTER", marker, "CENTER", 0.5, 0)

        marker.rankIcon = marker:CreateTexture(nil, "OVERLAY", nil, 7)
        marker.rankIcon:SetSize(14, 14)
        marker.rankIcon:SetPoint("CENTER", marker, "CENTER", 0, 0)
        marker.rankIcon:Hide()

        marker:SetScript("OnEnter", function(self)
            if self.milestone and bar.state then
                ShowMilestoneTooltip(self, bar.state, self.milestone)
            end
        end)
        marker:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        marker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        marker:SetScript("OnClick", function(self, button)
            if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
                HandleShiftClick(self, self.milestone)
            end
        end)

        marker:Hide()
        bar.markers[i] = marker
    end

    bar:SetScript("OnEnter", function(self)
        local state = self.state
        if not state then return end
        local milestone = GetHoveredMilestone(self) or state.nextMilestone or state.lastMilestone or state.milestones[1]
        if milestone then
            ShowMilestoneTooltip(self, state, milestone)
        end
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
            HandleShiftClick(self, GetHoveredMilestone(self))
        end
    end)

    Honor.frame = bar
    Honor.addonFrame = addonFrame
    if Honor.visible == nil then Honor.visible = true end
    Honor.Refresh(true)
    if Honor.visible == false then
        bar:Hide()
    end
    return bar
end

function Honor.Refresh(force)
    local bar = Honor.frame
    if not bar then return end

    local rank, progress = GetCurrentRankAndProgress()
    local hk, currentHonor = GetCurrentWeekStats()
    local previousStripeHonor = bar._unrealizedStripeLastHonor
    local gainedHonor = previousStripeHonor ~= nil and currentHonor > previousStripeHonor
    bar._unrealizedStripeLastHonor = currentHonor
    local milestones = BuildMilestones(rank, progress)

    local maxHonor = 0
    if #milestones > 0 then
        maxHonor = milestones[#milestones].honor or 0
    end
    if maxHonor <= 0 then
        maxHonor = HONOR_INCREMENTS[14]
    end

    local signature = table.concat({ GetBattlegroundDisplayName(), rank, string.format("%.5f", progress), hk, currentHonor, maxHonor, math.floor((bar:GetWidth() or 0) * 10), math.floor((bar:GetHeight() or 0) * 10), (bar._honorWidgetState and bar._honorWidgetState.orientation) or "VERTICAL" }, ":")
    if not force and bar.signature == signature then return end
    bar.signature = signature

    local r, g, b = GetFactionHonorColor()
    bar.fill:SetVertexColor(r, g, b, 0.95)

    local horizontal = IsHorizontalWidgetBar(bar)
    local barWidth = bar:GetWidth() or 18
    local barHeight = bar:GetHeight() or 512
    local innerLength = math.max(1, (horizontal and barWidth or barHeight) - 4)
    local thickness = math.max(8, horizontal and barHeight or barWidth)
    local fillRatio = maxHonor > 0 and Clamp(currentHonor / maxHonor, 0, 1) or 0

    -- Only honor that has reached a breakpoint is shown at full faction color.
    -- Progress beyond the most recently completed breakpoint is deliberately
    -- darker: it is real weekly honor, but it has not yet realized another
    -- ranking gain. This restores the bright-completed / dark-in-progress read.
    local realizedHonor = 0
    for _, milestone in ipairs(milestones or {}) do
        local required = tonumber(milestone and milestone.honor) or 0
        if currentHonor >= required then
            realizedHonor = math.max(realizedHonor, required)
        end
    end
    local realizedRatio = maxHonor > 0 and Clamp(realizedHonor / maxHonor, 0, fillRatio) or 0

    bar.fill:ClearAllPoints()
    if realizedRatio > 0 then
        if horizontal then
            bar.fill:SetTexCoord(0, 1, 0, 1)
            bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -2)
            bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2, 2)
            bar.fill:SetWidth(math.max(1, innerLength * realizedRatio))
        else
            bar.fill:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
            bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2, 2)
            bar.fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
            bar.fill:SetHeight(math.max(1, innerLength * realizedRatio))
        end
        bar.fill:Show()
    else
        bar.fill:Hide()
    end

    bar.incompleteOverlay:ClearAllPoints()
    bar.unrealizedStripes:ClearAllPoints()
    local unrealizedRatio = math.max(0, fillRatio - realizedRatio)
    if unrealizedRatio > 0 then
        local unrealizedLength = math.max(1, innerLength * unrealizedRatio)
        local stripeWidth, stripeHeight
        bar.incompleteOverlay:SetVertexColor(r * 0.42, g * 0.42, b * 0.42, 0.96)
        -- The stripes use a brighter version of the same faction hue, not white,
        -- so Alliance stays blue and Horde stays red.
        bar.unrealizedStripes:SetVertexColor(Clamp((r * 1.45) + 0.10, 0, 1), Clamp((g * 1.45) + 0.10, 0, 1), Clamp((b * 1.45) + 0.10, 0, 1), 0.48)
        if horizontal then
            local x = 2 + (innerLength * realizedRatio)
            stripeWidth, stripeHeight = unrealizedLength, math.max(1, barHeight - 4)
            bar.incompleteOverlay:SetTexCoord(0, 1, 0, 1)
            bar.incompleteOverlay:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -2)
            bar.incompleteOverlay:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 2)
            bar.incompleteOverlay:SetWidth(unrealizedLength)
            bar.unrealizedStripes:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -2)
            bar.unrealizedStripes:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 2)
            bar.unrealizedStripes:SetWidth(unrealizedLength)
        else
            local y = 2 + (innerLength * realizedRatio)
            stripeWidth, stripeHeight = math.max(1, barWidth - 4), unrealizedLength
            bar.incompleteOverlay:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
            bar.incompleteOverlay:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2, y)
            bar.incompleteOverlay:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, y)
            bar.incompleteOverlay:SetHeight(unrealizedLength)
            bar.unrealizedStripes:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2, y)
            bar.unrealizedStripes:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, y)
            bar.unrealizedStripes:SetHeight(unrealizedLength)
        end
        bar.incompleteOverlay:Show()
        bar.unrealizedStripes:Show()
        bar._unrealizedStripeHorizontal = horizontal
        bar._unrealizedStripeWidth = stripeWidth
        bar._unrealizedStripeHeight = stripeHeight
        if not bar._unrealizedStripeAnimator:IsShown() then
            ApplyUnrealizedStripeTexCoord(bar, horizontal, stripeWidth, stripeHeight, 0)
        end
        if gainedHonor then StartUnrealizedStripeSweep(bar) end
    else
        bar.incompleteOverlay:Hide()
        bar.unrealizedStripes:Hide()
        if bar._unrealizedStripeAnimator then bar._unrealizedStripeAnimator:Hide() end
    end

    bar.currentLine:ClearAllPoints()
    if currentHonor > 0 then
        if horizontal then
            bar.currentLine:SetSize(1, math.max(4, barHeight - 4))
            bar.currentLine:SetPoint("CENTER", bar, "LEFT", 2 + (innerLength * fillRatio), 0)
        else
            bar.currentLine:SetSize(math.max(4, barWidth - 4), 1)
            bar.currentLine:SetPoint("CENTER", bar, "BOTTOM", 0, 2 + (innerLength * fillRatio))
        end
        bar.currentLine:Show()
    else
        bar.currentLine:Hide()
    end

    local lastMilestone, nextMilestone
    local previousMilestoneRank = rank
    local iconSize = Clamp(thickness * 0.78, 6, 64)
    local markerSize = iconSize + 2
    local tickLength = math.max(4, thickness - 4)
    for i = 1, 4 do
        local marker = bar.markers[i]
        local milestone = milestones[i]
        if marker and milestone and maxHonor > 0 then
            local ratio = Clamp(milestone.honor / maxHonor, 0, 1)
            local markerAxis = Clamp(2 + (innerLength * ratio), markerSize * 0.5, (horizontal and barWidth or barHeight) - (markerSize * 0.5))
            marker:SetSize(markerSize, markerSize)
            marker.rankIcon:SetSize(iconSize, iconSize)
            marker:ClearAllPoints()
            if horizontal then
                marker:SetPoint("CENTER", bar, "LEFT", markerAxis, 0)
                marker.tick:SetSize(1, tickLength)
                marker.tick:ClearAllPoints()
                marker.tick:SetPoint("CENTER", marker, "CENTER", 0, 0.5)
            else
                marker:SetPoint("CENTER", bar, "BOTTOM", 0, markerAxis)
                marker.tick:SetSize(tickLength, 1)
                marker.tick:ClearAllPoints()
                marker.tick:SetPoint("CENTER", marker, "CENTER", 0.5, 0)
            end
            marker.milestone = milestone
            marker.tick:SetVertexColor(0.82, 0.73, 0.56, 0.72)

            if currentHonor >= milestone.honor then
                lastMilestone = milestone
            elseif not nextMilestone then
                nextMilestone = milestone
            end

            local resultingRank = tonumber(milestone.rank) or rank
            if resultingRank > previousMilestoneRank then
                marker.rankIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", resultingRank))
                marker.rankIcon:SetVertexColor(1, 1, 1, 1)
                marker.rankIcon:Show()
                -- A rank icon already marks this breakpoint; a tick beneath it
                -- is redundant. Non-rank-up breakpoints keep their scaled tick.
                marker.tick:Hide()
                previousMilestoneRank = resultingRank
            else
                marker.rankIcon:Hide()
                marker.tick:Show()
            end
            marker:Show()
        elseif marker then
            marker.milestone = nil
            marker.rankIcon:Hide()
            marker.tick:Hide()
            marker:Hide()
        end
    end

    -- incompleteOverlay is positioned above as the darker, not-yet-realized
    -- portion of the current week's honor progress.

    bar.segmentBounds = {}
    if bar.segments then
        local previousAxis = 2
        for i = 1, 4 do
            local segment = bar.segments[i]
            local milestone = milestones[i]
            if segment and milestone then
                local upperAxis
                if i <= #milestones - 1 and bar.markers[i] then
                    local _, _, _, xOffset, yOffset = bar.markers[i]:GetPoint(1)
                    upperAxis = horizontal and xOffset or yOffset
                else
                    upperAxis = (horizontal and barWidth or barHeight) - 2
                end
                upperAxis = tonumber(upperAxis) or previousAxis
                local lowerAxis = previousAxis
                local span = math.max(1, upperAxis - lowerAxis)
                segment:ClearAllPoints()
                if horizontal then
                    segment:SetSize(span, barHeight)
                    segment:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", lowerAxis, 0)
                else
                    segment:SetSize(barWidth, span)
                    segment:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, lowerAxis)
                end
                segment.milestone = milestone
                segment:Show()
                bar.segmentBounds[i] = { lower = lowerAxis, upper = lowerAxis + span, milestone = milestone }
                if bar.markers[i] then
                    local _, _, _, xOffset, yOffset = bar.markers[i]:GetPoint(1)
                    previousAxis = tonumber(horizontal and xOffset or yOffset) or upperAxis
                else
                    previousAxis = upperAxis
                end
            elseif segment then
                segment.milestone = nil
                segment:Hide()
            end
        end
    end

    bar.state = {
        rank = rank,
        progress = progress,
        hk = hk,
        currentHonor = currentHonor,
        maxHonor = maxHonor,
        milestones = milestones,
        lastMilestone = lastMilestone,
        nextMilestone = nextMilestone,
    }
end

function Honor.SetVisible(flag)
    Honor.visible = (flag ~= false)
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.RefreshAllVisibility then
        ZurkMapsHonorWidget.RefreshAllVisibility()
        return
    end
    if not Honor.frame then return end
    if Honor.visible then
        Honor.frame:Show()
        Honor.Refresh(true)
    else
        GameTooltip:Hide()
        Honor.frame:Hide()
    end
end

function Honor.IsVisible()
    return Honor.visible ~= false
end


function Honor.SetUnlocked(flag)
    if Honor.frame and ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetUnlocked then
        ZurkMapsHonorWidget.SetUnlocked(Honor.frame, flag)
    elseif Honor.config and Honor.config.db then
        Honor.config.db.honorWidget = Honor.config.db.honorWidget or {}
        Honor.config.db.honorWidget.unlocked = flag and true or false
    end
end

function Honor.IsUnlocked()
    if Honor.frame and ZurkMapsHonorWidget and ZurkMapsHonorWidget.IsUnlocked then
        return ZurkMapsHonorWidget.IsUnlocked(Honor.frame)
    end
    local db = Honor.config and Honor.config.db
    return db and db.honorWidget and db.honorWidget.unlocked and true or false
end

function Honor.IsDetached()
    if Honor.frame and ZurkMapsHonorWidget and ZurkMapsHonorWidget.IsDetached then
        return ZurkMapsHonorWidget.IsDetached(Honor.frame)
    end
    local db = Honor.config and Honor.config.db
    return db and db.honorWidget and db.honorWidget.detached and true or false
end

function Honor.AddSimulatedHonor(amount)
    Honor.simulatedHonor = math.max(0, (tonumber(Honor.simulatedHonor) or 0) + (tonumber(amount) or 0))
    Honor.Refresh(true)
    return Honor.simulatedHonor
end

function Honor.GetSimulatedHonor()
    return tonumber(Honor.simulatedHonor) or 0
end

