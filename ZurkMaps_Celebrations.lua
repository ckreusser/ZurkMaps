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

local function AddChatMessage(requiredHonor, rankUpRank)
    local message = string.format(
        "|cff33ff99Zurk Maps|r: Breakpoint reached — you have over |cffffd100%s|r honor this week.",
        FormatNumber(requiredHonor))

    rankUpRank = tonumber(rankUpRank)
    if rankUpRank and rankUpRank > 0 then
        local playerName = UnitName and UnitName("player") or nil
        playerName = playerName or "Player"
        local rankName = GetFactionRankName(rankUpRank) or ("Rank " .. tostring(rankUpRank))
        -- Use the same PvP rank texture path Blizzard uses, with chat-safe
        -- escaped backslashes so the inline texture renders in Classic Era.
        local rankIcon = string.format("|TInterface\\PvPRankBadges\\PvPRank%02d:16:16:0:0|t", rankUpRank)
        message = message .. string.format(" Congratulations, %s %s %s!", rankIcon, rankName, playerName)
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    else
        print(message)
    end
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

local function Celebrate(requiredHonor, currentHonor, rankUpRank)
    -- All three celebration cues are issued in the same UI frame. The native
    -- Raid Warning sound provides an immediate attack while the fanfare starts
    -- alongside the banner.
    PlayBreakpointRaidWarningSound()
    ShowRaidWarning()
    PlayVictorySound()
    AddChatMessage(requiredHonor, rankUpRank)
    if ZurkMapsHonorWidget and type(ZurkMapsHonorWidget.FlashBreakpoint) == "function" then
        ZurkMapsHonorWidget.FlashBreakpoint(requiredHonor)
    end
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
        if required then Celebrate(required, currentHonor, rankUpRank) end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
eventFrame:SetScript("OnEvent", function(_, event)
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
