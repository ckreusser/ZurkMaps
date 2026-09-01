-- Alterac Valley tracked-NPC status (lieutenants + commanders + captains + enemy general), distinct faction blips, patrol overlays, health sharing, reporting, and lightweight addon sync.
-- Death detection uses COMBAT_LOG_EVENT_UNFILTERED / UNIT_DIED for the known AV honor-NPC IDs.
ZurkMapsAVLieutenants = ZurkMapsAVLieutenants or {}

local LT = ZurkMapsAVLieutenants

local PREFIX = "ZurkMapsAVLT"
local CAPPING_PREFIX = "Capping" -- passive health interoperability; Zurk Maps never sends on this prefix
local ALLIANCE_R, ALLIANCE_G, ALLIANCE_B = 0.18, 0.46, 0.95
local HORDE_R, HORDE_G, HORDE_B = 0.78, 0.12, 0.10
local PATH_ALPHA = 0.96
local MAP_CROP_LEFT, MAP_CROP_RIGHT = 0.028, 0.972
local MAP_CROP_TOP, MAP_CROP_BOTTOM = 0.010, 0.990

-- x/y are Zurk Map custom-map percentages, after the same artwork crop used by AVMap.tga.
-- Patrol routes are intentionally approximate route corridors. NPC blips remain at their
-- designed/static locations; combat is communicated through live health bars + blip pulsing.
local LIEUTENANTS = {
    -- Alliance
    { id=13138, key="SPENCER", name="Lieutenant Spencer", faction="Alliance", kind="lieutenant", x=59.76, y=35.21,
      location="Guards Stonehearth Graveyard", calloutLocation="Stonehearth GY" },
    { id=13296, key="LARGENT", name="Lieutenant Largent", faction="Alliance", kind="lieutenant", x=53.05, y=37.50,
      location="Stationed just outside Stonehearth Outpost with Greywand", calloutLocation="Stonehearth Outpost" },
    { id=13297, key="STOUTHANDLE", name="Lieutenant Stouthandle", faction="Alliance", kind="lieutenant", x=57.20, y=41.25,
      location="Patrols the roads south of Stonehearth Graveyard toward Stonehearth Bunker", calloutLocation="south of Stonehearth GY",
      routeLabel="Stonehearth Outpost <-> Stonehearth Bunker",
      route={{52.3,39.6},{54.7,40.3},{57.2,41.2},{59.4,42.1},{61.6,43.0}} },
    { id=13298, key="GREYWAND", name="Lieutenant Greywand", faction="Alliance", kind="lieutenant", x=50.35, y=37.50,
      location="Stationed just outside Stonehearth Outpost with Largent", calloutLocation="Stonehearth Outpost" },
    { id=13299, key="LONADIN", name="Lieutenant Lonadin", faction="Alliance", kind="lieutenant", x=52.58, y=34.85,
      location="Patrols the broad road above Stonehearth Outpost toward Stonehearth Graveyard", calloutLocation="road above Stonehearth Outpost",
      routeLabel="Stonehearth Outpost -> Stonehearth Graveyard road",
      route={{50.88,35.35},{51.68,35.10},{52.58,34.85},{53.63,34.55},{54.68,34.25},{55.68,34.00},{56.53,33.80}} },
    { id=13300, key="MANCUSO", name="Lieutenant Mancuso", faction="Alliance", kind="lieutenant", x=60.20, y=39.10,
      location="Patrols north of Stonehearth Bunker on the Stonehearth roads", calloutLocation="north of Stonehearth Bunker",
      routeLabel="South Stonehearth Graveyard roads",
      route={{59.3,35.7},{59.4,37.0},{59.8,38.4},{60.4,39.7},{61.1,41.0},{61.9,42.4}} },

    -- Horde
    { id=13143, key="STRONGHOOF", name="Lieutenant Stronghoof", faction="Horde", kind="lieutenant", x=61.10, y=56.95,
      location="Guards the east side of Iceblood Graveyard", calloutLocation="east of Iceblood GY" },
    { id=13144, key="VOLTALAR", name="Lieutenant Vol'talar", faction="Horde", kind="lieutenant", x=40.95, y=55.45,
      location="Stationed above and left of Iceblood Garrison with Lewis", calloutLocation="upper-left of Iceblood Garrison" },
    { id=13145, key="GRUMMUS", name="Lieutenant Grummus", faction="Horde", kind="lieutenant", x=52.20, y=56.85,
      location="Patrols between Iceblood Garrison and Iceblood Graveyard", calloutLocation="Garrison to Iceblood GY",
      routeLabel="Iceblood Garrison <-> Iceblood Graveyard",
      route={{46.8,55.9},{49.2,56.1},{51.4,56.6},{53.8,56.8},{56.2,57.0},{58.7,57.1}} },
    { id=13146, key="MURP", name="Lieutenant Murp", faction="Horde", kind="lieutenant", x=60.35, y=66.20,
      location="Patrols the main road southeast of Tower Point", calloutLocation="road southeast of Tower Point",
      routeLabel="Tower Point lower road patrol",
      route={{59.15,64.15},{59.65,64.95},{60.05,65.75},{60.45,66.45},{61.05,67.05},{60.15,67.70},{59.25,68.00}} },
    { id=13147, key="LEWIS", name="Lieutenant Lewis", faction="Horde", kind="lieutenant", x=44.60, y=55.45,
      location="Stationed above and right of Iceblood Garrison with Vol'talar", calloutLocation="upper-right of Iceblood Garrison" },
    { id=13137, key="RUGBA", name="Lieutenant Rugba", faction="Horde", kind="lieutenant", x=56.60, y=57.55,
      location="Guards the west side of Iceblood Graveyard", calloutLocation="west of Iceblood GY",
      routeLabel="Iceblood Graveyard west approach",
      route={{55.7,57.0},{56.3,57.5},{57.0,58.0},{57.6,57.7},{57.1,57.1},{56.4,56.8}} },

    -- Commanders also award bonus honor. These are the tower/bunker/graveyard honor NPCs
    -- that can easily be mistaken for lieutenants when looking at old AV maps.
    -- Alliance
    { id=13319, key="DUFFY", name="Commander Duffy", faction="Alliance", kind="commander", x=52.64, y=13.53,
      location="Guards the Stormpike Graveyard flag", calloutLocation="Stormpike GY" },
    { id=13320, key="KARL_PHILIPS", name="Commander Karl Philips", faction="Alliance", kind="commander", x=56.14, y=29.72,
      location="Posted inside Icewing Bunker", calloutLocation="Icewing Bunker" },
    { id=13139, key="RANDOLPH", name="Commander Randolph", faction="Alliance", kind="commander", x=62.30, y=43.36,
      location="Posted inside Stonehearth Bunker", calloutLocation="Stonehearth Bunker" },
    { id=13318, key="MORTIMER", name="Commander Mortimer", faction="Alliance", kind="commander", x=38.80, y=14.65,
      location="Patrols Dun Baldar between the bunkers and Aid Station", calloutLocation="Dun Baldar",
      routeLabel="Dun Baldar bunker / Aid Station patrol",
      route={{34.3,14.4},{36.8,14.0},{39.5,13.7},{41.3,14.3},{40.0,16.0},{37.6,16.7},{35.3,15.6},{34.3,14.4}} },

    -- Horde
    { id=13140, key="DARDOSH", name="Commander Dardosh", faction="Horde", kind="commander", x=50.56, y=58.22,
      location="Posted inside Iceblood Tower", calloutLocation="Iceblood Tower" },
    { id=13154, key="LOUIS_PHILIPS", name="Commander Louis Philips", faction="Horde", kind="commander", x=55.37, y=65.28,
      location="Posted at the top of Tower Point", calloutLocation="Tower Point" },
    { id=13152, key="MALGOR", name="Commander Malgor", faction="Horde", kind="commander", x=52.99, y=77.20,
      location="Guards Frostwolf Graveyard", calloutLocation="Frostwolf GY" },
    { id=13153, key="MULFORT", name="Commander Mulfort", faction="Horde", kind="commander", x=52.65, y=89.25,
      location="Stationed at the Frostwolf Relief Hut", calloutLocation="Frostwolf Relief Hut" },

    -- Captains: centered on the baked captain emblems in AVMap.tga.
    { id=11949, key="BALINDA", name="Captain Balinda Stonehearth", faction="Alliance", kind="captain", x=51.86, y=38.68,
      location="Inside Stonehearth Outpost", calloutLocation="Stonehearth Outpost" },
    { id=11947, key="GALVANGAR", name="Captain Galvangar", faction="Horde", kind="captain", x=42.79, y=57.00,
      location="Inside Iceblood Garrison", calloutLocation="Iceblood Garrison" },

    -- Final generals: only the opposing faction's boss is shown. Generals share
    -- health/death observations but do not use the +honor death popup.
    { id=11948, key="VANNDAR", name="Vanndar Stormpike", faction="Alliance", kind="boss", honorYield=false, x=32.64, y=11.53,
      location="Inside Dun Baldar Keep", calloutLocation="Dun Baldar Keep" },
    { id=11946, key="DREKTHAR", name="Drek'Thar", faction="Horde", kind="boss", honorYield=false, x=46.5677, y=87.43,
      location="Inside Frostwolf Keep", calloutLocation="Frostwolf Keep" },
}

local BY_ID, BY_NAME = {}, {}
for _, info in ipairs(LIEUTENANTS) do
    BY_ID[info.id] = info
    BY_NAME[string.lower(info.name)] = info
end

LT.data = LIEUTENANTS
LT.byID = BY_ID
LT.states = LT.states or {}
LT.map = nil
LT.mapBorder = nil
LT.addonFrame = nil
LT.config = nil
LT.wasInAV = false
LT.syncRequested = false
LT.lastPositionBroadcast = LT.lastPositionBroadcast or {}
LT.lastAliveBroadcast = LT.lastAliveBroadcast or {}
LT.friendlyAuraSeen = LT.friendlyAuraSeen or { lieutenant=false, commander=false }
LT.popup = nil
LT.devButton = nil
LT.pendingHonorDeaths = LT.pendingHonorDeaths or {}
LT.recentHonorGains = LT.recentHonorGains or {}
LT.absenceEvidence = LT.absenceEvidence or {}
LT.syncElapsed = LT.syncElapsed or 0
LT.scanElapsed = LT.scanElapsed or 0
LT.healthScanElapsed = LT.healthScanElapsed or 0
LT.healthScanBlocked = LT.healthScanBlocked or {}
LT.lastHealthBroadcast = LT.lastHealthBroadcast or {}
LT.positionSensors = LT.positionSensors or {}
LT.livePositionUnits = LT.livePositionUnits or {}
LT.nativeLiveActive = LT.nativeLiveActive or {}
LT.nativePositionResolved = LT.nativePositionResolved or {}
LT.livePositionElapsed = LT.livePositionElapsed or 0

local DEFAULT_DEATH_HONOR = 198
local DEATH_SKULL_FADE_SECONDS = 10.0
local HEALTH_STALE_SECONDS = 20.0
local HEALTH_BAR_BASE_WIDTH = 24.0
local HEALTH_BAR_BASE_HEIGHT = 4.0

-- Keep tracked honor-NPC visuals above every AV map-content layer, including
-- objective buttons and special player markers. HIGH is intentional here: it
-- wins within the map without covering Blizzard/Zurks tooltip/menu strata.
local NPC_TOP_FRAME_OFFSET = 110
local NPC_HEALTH_FRAME_OFFSET = 118
local NPC_DEATH_FLOAT_FRAME_OFFSET = 126
local COMBAT_YELLOW_R, COMBAT_YELLOW_G, COMBAT_YELLOW_B = 1.00, 0.86, 0.06
LT.lastSyncRequest = LT.lastSyncRequest or 0

local MarkDead
local FindNearbyAliveEnemyHonorNPC
local ClearPositionSensor
local UpdateSecureTargetButton

local function GetFactionColor(info)
    if info and info.faction == "Alliance" then return ALLIANCE_R, ALLIANCE_G, ALLIANCE_B end
    return HORDE_R, HORDE_G, HORDE_B
end

local function GetEliteWrapperColor(info)
    if info and info.faction == "Alliance" then return 0.48, 0.74, 1.00 end
    return 1.00, 0.34, 0.28
end

local function GetDisplayCompensation()
    local scale = (LT.addonFrame and LT.addonFrame.GetScale and LT.addonFrame:GetScale()) or 1
    scale = math.min(scale, 1)
    local fullInverse = 1 / math.max(scale, 0.01)
    -- Only partially compensate at small map sizes. Honor-NPC markers remain readable,
    -- but now shrink with the map instead of staying almost full physical size.
    return 1 + ((fullInverse - 1) * 0.55)
end

local function ApplyRaidMarkerSkull(texture)
    if not texture then return end
    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    texture:SetTexCoord(0, 1, 0, 1)
end

local function GetDeadSkullSize(info)
    local inv = GetDisplayCompensation()
    -- Death skull is intentionally more prominent than the old tiny marker.
    -- 6.54 is exactly 20% larger than the previous 5.45 base size.
    return 6.54 * inv
end

local function GetBlipSizes(info)
    local inv = GetDisplayCompensation()
    if info and (info.kind == "captain" or info.kind == "boss") then
        -- Captains and final generals use the same compact Raid Boss treatment.
        -- Keeping the dimensions identical prevents the boss marker from visually
        -- overpowering the baked keep icon it is centered on.
        return 9.5 * inv, 0
    elseif info and info.kind == "commander" then
        return 13.0 * inv, 0
    end
    return 12.0 * inv, 0
end

local function GetBossVisualYOffset(info)
    if not info or info.kind ~= "boss" then return 0 end
    -- UI-TargetingFrame-Skull's visible skull sits high inside its square texture.
    -- Keep the boss frame/hitbox centered on the baked keep marker, but lower the
    -- actual artwork so the visible skull is centered the way Captain markers read.
    return -4.5 * GetDisplayCompensation()
end

local function GetBlipHitSize(info)
    local inv = GetDisplayCompensation()
    if info and (info.kind == "captain" or info.kind == "boss") then return 13.0 * inv end
    if info and info.kind == "commander" then return 15.0 * inv end
    return 13.5 * inv
end


local function GetBlipFrameLevel(info)
    local base = (LT.mapBorder and LT.mapBorder:GetFrameLevel() or (LT.map and LT.map:GetFrameLevel()) or 1)
    return base + NPC_TOP_FRAME_OFFSET
end

local function GetLiveNPCFrameLevel()
    -- Player pins/special markers in AV live around mapBorder + 20..30. A genuinely
    -- observed/moving honor NPC should win visually when a player pile overlaps it.
    local base = (LT.mapBorder and LT.mapBorder:GetFrameLevel() or (LT.map and LT.map:GetFrameLevel()) or 1)
    return base + 60
end

local function IsRecentLivePosition(info, state)
    return false
end

local function NormalizeName(value)
    value = string.lower(value or "")
    value = value:gsub("<old>", "")
    value = value:gsub("%s+", " ")
    return value:match("^%s*(.-)%s*$")
end

local function IsInAlteracValley()
    local instanceName = GetInstanceInfo and GetInstanceInfo() or nil
    local realZone = GetRealZoneText and GetRealZoneText() or nil
    local zone = GetZoneText and GetZoneText() or nil
    return instanceName == "Alterac Valley" or realZone == "Alterac Valley" or zone == "Alterac Valley"
end

local function GetNPCIDFromGUID(guid)
    if type(guid) ~= "string" then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil end
    return tonumber(npcID)
end

local function GetInfoFromUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    local id = GetNPCIDFromGUID(UnitGUID and UnitGUID(unit) or nil)
    if id and BY_ID[id] then return BY_ID[id] end
    local name = UnitName and UnitName(unit) or nil
    if name then return BY_NAME[NormalizeName(name)] end
    return nil
end

local function RawMapToAVMap(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then return nil, nil end
    local customX = (x - MAP_CROP_LEFT) / (MAP_CROP_RIGHT - MAP_CROP_LEFT)
    local customY = (y - MAP_CROP_TOP) / (MAP_CROP_BOTTOM - MAP_CROP_TOP)
    if customX < 0 or customX > 1 or customY < 0 or customY > 1 then return nil, nil end
    return customX * 100, customY * 100
end

local function EnsureState(info)
    local state = LT.states[info.id]
    if not state then
        state = {
            dead=false,
            x=info.x,
            y=info.y,
            lastSeen=nil,
            source="initial",
            healthPct=100,
            healthUpdatedAt=nil,
            healthSource=nil,
        }
        LT.states[info.id] = state
    end
    if state.healthPct == nil then state.healthPct = 100 end
    return state
end

local function AddonSendSucceeded(ok, firstResult, secondResult)
    if not ok then return false end
    local result = secondResult ~= nil and secondResult or firstResult
    -- Older Classic wrappers returned nil/true on a successful enqueue. Current
    -- C_ChatInfo returns Enum.SendAddonMessageResult.Success (0).
    if result == nil or result == true then return true end
    if result == false then return false end
    if type(result) == "number" then return result == 0 end
    return true
end

local function SendAddonCompat(message, channel)
    if not message or message == "" or not channel then return false end
    if C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function" then
        local ok, firstResult, secondResult = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, channel)
        return AddonSendSucceeded(ok, firstResult, secondResult)
    end
    if type(_G.SendAddonMessage) == "function" then
        local ok, firstResult, secondResult = pcall(_G.SendAddonMessage, PREFIX, message, channel)
        if AddonSendSucceeded(ok, firstResult, secondResult) then return true end
    end
    return false
end

local function Broadcast(message)
    if not IsInAlteracValley() or not message or message == "" then return false end
    local inInstance, instanceType = false, nil
    if type(IsInInstance) == "function" then
        local ok, inside, kind = pcall(IsInInstance)
        if ok then inInstance, instanceType = inside, kind end
    end
    if not inInstance or instanceType ~= "pvp" then return false end
    -- AV synchronization always uses the instance-group addon channel. Never
    -- send synchronization over RAID; Classic can display "not in a raid group"
    -- for that path even while the player is correctly inside a battleground.
    return SendAddonCompat(message, "INSTANCE_CHAT")
end

local function RegisterPrefix()
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        -- Capping broadcasts AV boss/captain health as "npcID:percent". Listen to
        -- that existing INSTANCE_CHAT feed as an extra observation source so a
        -- Zurk Maps user can see remote boss health even when no Zurk Maps client
        -- near the NPC currently has a usable unit token. We never transmit with
        -- Capping's prefix.
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, CAPPING_PREFIX)
    elseif type(RegisterAddonMessagePrefix) == "function" then
        pcall(RegisterAddonMessagePrefix, PREFIX)
        pcall(RegisterAddonMessagePrefix, CAPPING_PREFIX)
    end
end

local function HidePath(info)
    if not info or not info.pathWidgets then return end
    info.routePinned = false
    for _, widget in ipairs(info.pathWidgets) do
        if widget.outline then widget.outline:SetAlpha(0) end
        if widget.core then widget.core:SetAlpha(0) end
    end
end

local function EnsureDeathProc(blip)
    if not blip or blip.deathProcStarA then return end

    local starA = blip:CreateTexture(nil, "ARTWORK", nil, -2)
    starA:SetPoint("CENTER", blip, "CENTER", 0, 0)
    starA:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    starA:SetBlendMode("ADD")
    starA:SetVertexColor(1.0, 0.76, 0.16, 1)
    starA:Hide()

    local starB = blip:CreateTexture(nil, "ARTWORK", nil, -1)
    starB:SetPoint("CENTER", blip, "CENTER", 0, 0)
    starB:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    starB:SetBlendMode("ADD")
    starB:SetVertexColor(1.0, 0.92, 0.48, 0.92)
    if starB.SetRotation then starB:SetRotation(math.pi / 4) end
    starB:Hide()

    blip.deathProcStarA = starA
    blip.deathProcStarB = starB
end

local function FinishDeathTransition(blip)
    if not blip then return end
    blip:SetScript("OnUpdate", nil)
    if blip.deathProcStarA then blip.deathProcStarA:Hide() end
    if blip.deathProcStarB then blip.deathProcStarB:Hide() end
    local callback = blip.deathProcCallback
    blip.deathProcCallback = nil
    blip.deathProcElapsed = nil
    if callback then callback() end
end

local function PlayDeathTransition(info, callback)
    if not info or not info.blip then
        if callback then callback() end
        return
    end

    local blip = info.blip
    EnsureDeathProc(blip)
    local coreSize = select(1, GetBlipSizes(info))

    -- Previous proc was ~core+18. This is intentionally about 60% smaller in footprint,
    -- while the doubled/rotated border keeps the transition readable.
    local procSize = math.max(coreSize + 3, (coreSize + 18) * 0.42)
    for _, star in ipairs({blip.deathProcStarA, blip.deathProcStarB}) do
        if star then
            star:ClearAllPoints()
            star:SetPoint("CENTER", blip, "CENTER", 0, 0)
            star:SetSize(procSize, procSize)
            star:SetAlpha(1)
            star:Show()
        end
    end

    blip.deathProcCallback = callback
    blip.deathProcElapsed = 0
    local duration = 0.82

    blip:SetScript("OnUpdate", function(self, elapsed)
        self.deathProcElapsed = (self.deathProcElapsed or 0) + (elapsed or 0)
        local t = math.min(1, self.deathProcElapsed / duration)
        local angle = (math.pi * 3.0) * t
        local fade = 1 - (t * 0.72)
        local pulse = 1 + (math.sin(t * math.pi) * 0.16)
        local size = procSize * pulse

        if self.deathProcStarA then
            self.deathProcStarA:SetSize(size, size)
            self.deathProcStarA:SetAlpha(fade)
            if self.deathProcStarA.SetRotation then self.deathProcStarA:SetRotation(angle) end
        end
        if self.deathProcStarB then
            self.deathProcStarB:SetSize(size, size)
            self.deathProcStarB:SetAlpha(fade * 0.9)
            if self.deathProcStarB.SetRotation then self.deathProcStarB:SetRotation(angle + (math.pi / 4)) end
        end

        if t >= 1 then
            FinishDeathTransition(self)
        end
    end)
end

local function FormatHonorAmount(value)
    local n = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
    local text = tostring(n)
    while true do
        local changed, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        text = changed
        if count == 0 then break end
    end
    return text
end

local function GetCurrentWeekHonor()
    if type(GetPVPThisWeekStats) ~= "function" then return nil end
    local ok, _, honor = pcall(GetPVPThisWeekStats)
    if not ok then return nil end
    return tonumber(honor)
end

local function IsEnemyHonorNPC(info)
    if not info then return false end
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player") or nil
    return playerFaction and info.faction and playerFaction ~= info.faction
end

local function ShowHonorGainFloat(info, amount)
    amount = tonumber(amount)
    if not info or not info.blip or not LT.map or not amount or amount <= 0 then return end

    local float = CreateFrame("Frame", nil, LT.map)
    float:SetSize(72, 18)
    if float.SetFrameStrata then float:SetFrameStrata("HIGH") end
    float:SetFrameLevel((LT.mapBorder and LT.mapBorder:GetFrameLevel() or 1) + NPC_DEATH_FLOAT_FRAME_OFFSET)
    float.elapsed = 0
    float.duration = 1.20
    float.rise = 18

    local label = float:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER", float, "CENTER", 0, 0)
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    label:SetTextColor(1.00, 0.82, 0.12, 1)
    label:SetShadowColor(0, 0, 0, 0.90)
    label:SetShadowOffset(1, -1)
    label:SetText("+" .. FormatHonorAmount(amount))
    float.label = label

    local function Reanchor(offsetY)
        float:ClearAllPoints()
        -- Keep the text close to the NPC: the popup's CENTER is only a few
        -- pixels above/right of the blip, then the combat-text rise carries it up.
        float:SetPoint("CENTER", info.blip, "CENTER", 7, 7 + (offsetY or 0))
    end
    Reanchor(0)

    float:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        local t = math.min(1, self.elapsed / self.duration)
        -- Fast initial lift, then a smoother upward coast like floating combat text.
        local riseT = 1 - ((1 - t) * (1 - t))
        local rise = self.rise * riseT
        Reanchor(rise)

        local alpha
        if t < 0.08 then
            alpha = t / 0.08
        elseif t < 0.48 then
            alpha = 1
        else
            alpha = math.max(0, 1 - ((t - 0.48) / 0.52))
        end
        self:SetAlpha(alpha)

        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            if self.SetParent then self:SetParent(nil) end
        end
    end)
end

local function PruneHonorQueues()
    local now = GetTime and GetTime() or 0
    for i = #LT.pendingHonorDeaths, 1, -1 do
        local entry = LT.pendingHonorDeaths[i]
        if not entry or entry.matched or (now - (entry.time or 0)) > 4.0 then
            table.remove(LT.pendingHonorDeaths, i)
        end
    end
    for i = #LT.recentHonorGains, 1, -1 do
        local entry = LT.recentHonorGains[i]
        if not entry or entry.used or (now - (entry.time or 0)) > 1.0 then
            table.remove(LT.recentHonorGains, i)
        end
    end
end

local function MatchRecentHonorGain(pending)
    if not pending or pending.matched then return false end
    PruneHonorQueues()
    local now = GetTime and GetTime() or 0
    local best, bestDelta
    for _, gain in ipairs(LT.recentHonorGains) do
        if gain and not gain.used and gain.amount and gain.amount > 0 then
            local delta = math.abs((gain.time or now) - (pending.time or now))
            if delta <= 0.75 and (not bestDelta or delta < bestDelta) then
                best, bestDelta = gain, delta
            end
        end
    end
    if best then
        best.used = true
        pending.matched = true
        ShowHonorGainFloat(pending.info, best.amount)
        return true
    end
    return false
end

local function CheckPendingHonorDelta(pending)
    if not pending or pending.matched then return end
    local now = GetTime and GetTime() or 0
    if (now - (pending.time or 0)) > 3.0 then return end

    -- Use the weekly-honor delta only as a fallback when this is the sole recent
    -- unmatched honor-NPC death. CHAT_MSG_COMBAT_HONOR_GAIN remains the primary source.
    local recentUnmatched = 0
    for _, entry in ipairs(LT.pendingHonorDeaths) do
        if entry and not entry.matched and (now - (entry.time or 0)) <= 3.0 then
            recentUnmatched = recentUnmatched + 1
        end
    end
    if recentUnmatched ~= 1 or not pending.baselineHonor then return end

    local currentHonor = GetCurrentWeekHonor()
    if currentHonor and currentHonor > pending.baselineHonor then
        local delta = currentHonor - pending.baselineHonor
        if delta > 0 then
            pending.matched = true
            ShowHonorGainFloat(pending.info, delta)
        end
    end
end

local function QueueHonorDeath(info)
    if not IsEnemyHonorNPC(info) or info.honorYield == false then return end
    PruneHonorQueues()
    local pending = {
        info = info,
        time = GetTime and GetTime() or 0,
        baselineHonor = GetCurrentWeekHonor(),
        matched = false,
    }
    LT.pendingHonorDeaths[#LT.pendingHonorDeaths + 1] = pending

    -- Handle the rare ordering where the honor chat event arrives just before UNIT_DIED/sync.
    if MatchRecentHonorGain(pending) then return end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.85, function() CheckPendingHonorDelta(pending) end)
        C_Timer.After(1.70, function() CheckPendingHonorDelta(pending) end)
        C_Timer.After(2.05, function()
            if pending and not pending.matched and pending.info and EnsureState(pending.info).dead then
                pending.matched = true
                ShowHonorGainFloat(pending.info, DEFAULT_DEATH_HONOR)
            end
        end)
    elseif not pending.matched then
        pending.matched = true
        ShowHonorGainFloat(info, DEFAULT_DEATH_HONOR)
    end
end

local function ParseHonorGainAmount(...)
    local args = {...}
    for _, value in ipairs(args) do
        if type(value) == "number" and value > 0 then
            return value
        elseif type(value) == "string" then
            local lower = string.lower(value)
            if string.find(lower, "honor", 1, true) then
                local cleaned = string.gsub(value, ",", "")
                local best = nil
                for numberText in string.gmatch(cleaned, "(%d+)") do
                    local n = tonumber(numberText)
                    if n and (not best or n > best) then best = n end
                end
                if best and best > 0 then return best end
            end
        end
    end
    return nil
end

local function HandleHonorGainEvent(...)
    local amount = ParseHonorGainAmount(...)
    if not amount or amount <= 0 then return end
    PruneHonorQueues()
    local now = GetTime and GetTime() or 0

    -- Honor rewards fire essentially with the death. Pair the award to the oldest
    -- unmatched enemy honor-NPC death in the short association window.
    local pending = nil
    for _, entry in ipairs(LT.pendingHonorDeaths) do
        if entry and not entry.matched and (now - (entry.time or 0)) >= -0.25 and (now - (entry.time or 0)) <= 3.0 then
            if not pending or (entry.time or 0) < (pending.time or 0) then
                pending = entry
            end
        end
    end

    if pending then
        pending.matched = true
        ShowHonorGainFloat(pending.info, amount)
    else
        -- If the client awards honor but the nearby UNIT_DIED event was missed,
        -- use the player's calibrated AV position to resolve the nearest still-live
        -- enemy honor NPC. This is direct, current honor evidence, so it is the one
        -- non-combat-log fallback that may legitimately show +Honor.
        local nearby, bestDistance, secondDistance = nil, nil, nil
        if FindNearbyAliveEnemyHonorNPC then
            nearby, bestDistance, secondDistance = FindNearbyAliveEnemyHonorNPC(6.0)
        end
        local clearlyNearest = nearby and bestDistance and (
            bestDistance <= 2.25
            or not secondDistance
            or (secondDistance - bestDistance) >= 0.55
        )
        if clearlyNearest then
            if MarkDead and MarkDead(nearby, "honor-nearby", true) then
                ShowHonorGainFloat(nearby, amount)
            end
        else
            LT.recentHonorGains[#LT.recentHonorGains + 1] = { amount = amount, time = now, used = false }
        end
    end
end

local function ShowPath(info)
    if not info or not info.route or not info.pathWidgets then return end
    -- The AV honor layer is intentionally enemy-only. Friendly honor NPC
    -- status cannot be verified reliably from battleground state, so hiding
    -- their blips/patrols avoids presenting stale information as authoritative.
    if not IsEnemyHonorNPC(info) then
        HidePath(info)
        return
    end
    local state = EnsureState(info)
    local inv = GetDisplayCompensation()
    local r, g, b = GetFactionColor(info)
    if state.dead then r, g, b = 0.82, 0.82, 0.82 end
    for _, widget in ipairs(info.pathWidgets) do
        if widget.button then widget.button:SetSize(11 * inv, 11 * inv) end
        if widget.outline then
            widget.outline:SetSize(5.5 * inv, 5.5 * inv)
            widget.outline:SetAlpha(state.dead and 0.62 or 0.86)
            widget.outline:SetVertexColor(0.98,0.98,1.00,state.dead and 0.78 or 1)
        end
        if widget.core then
            widget.core:SetSize(2.5 * inv, 2.5 * inv)
            widget.core:SetVertexColor(r, g, b, 1)
            widget.core:SetAlpha(state.dead and (PATH_ALPHA * 0.78) or PATH_ALPHA)
        end
    end
end

local function ScheduleHidePath(info)
    if not info then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.08, function()
            if not info.routeHover then HidePath(info) end
        end)
    elseif not info.routeHover then
        HidePath(info)
    end
end

local function ShowLieutenantTooltip(owner, info, fromPath)
    if not owner or not info then return end
    local state = EnsureState(info)
    local r,g,b = GetFactionColor(info)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local ox, oy = owner:GetCenter()
    local mx, my = LT.map and LT.map:GetCenter() or nil, LT.map and select(2, LT.map:GetCenter()) or nil
    if ox and mx and ox > mx then
        GameTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -4, 0)
    else
        GameTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0)
    end
    GameTooltip:SetText(info.name, r, g, b)
    GameTooltip:AddDoubleLine("Status", state.dead and "Dead" or "Alive", 0.72,0.72,0.72,
        state.dead and 0.55 or 0.25, state.dead and 0.55 or 0.95, state.dead and 0.55 or 0.35)
    local healthPct = tonumber(state.healthPct)
    local healthAt = tonumber(state.healthUpdatedAt)
    local healthFresh = healthAt and (GetTime and ((GetTime() - healthAt) <= HEALTH_STALE_SECONDS) or true)
    if not state.dead and healthFresh and healthPct and healthPct < 99.95 then
        GameTooltip:AddDoubleLine("Health", string.format("%.1f%%", healthPct), 0.72,0.72,0.72, 0.35,1.00,0.40)
    end
    if info.location then
        GameTooltip:AddLine(info.location, 0.78,0.78,0.78, true)
    end
    if info.route then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Patrol", info.routeLabel or "Approximate patrol route", 0.72,0.72,0.72, r,g,b)
    end
    GameTooltip:AddLine(" ")
    if fromPath then
        GameTooltip:AddLine("Left-click: Call out status", 0.72,0.66,0.50, true)
        GameTooltip:AddLine("Right-click: Open Zurk Maps menu", 0.72,0.66,0.50, true)
    else
        if IsEnemyHonorNPC(info) then
            GameTooltip:AddLine("Left-click: Target " .. info.name, 0.72,0.66,0.50, true)
        end
        GameTooltip:AddLine("Right-click: Call out status", 0.72,0.66,0.50, true)
    end
    GameTooltip:Show()
    if info.route then ShowPath(info) end
end

local function EnsureNPCHealthBar(info)
    if not info or not info.blip then return nil end
    if info.healthBar then return info.healthBar end

    local bar = CreateFrame("StatusBar", nil, info.blip)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetFrameLevel((LT.mapBorder and LT.mapBorder:GetFrameLevel() or 1) + NPC_HEALTH_FRAME_OFFSET)
    bar:EnableMouse(false)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.025, 0.018, 0.012, 0.96)
    bar.bg = bg

    local function MakeEdge(pointA, pointB, height, width)
        local edge = bar:CreateTexture(nil, "OVERLAY")
        edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        edge:SetVertexColor(0.50, 0.34, 0.17, 0.98)
        edge:SetPoint(pointA, bar, pointA, 0, 0)
        edge:SetPoint(pointB, bar, pointB, 0, 0)
        if height then edge:SetHeight(height) end
        if width then edge:SetWidth(width) end
        return edge
    end
    bar.topEdge = MakeEdge("TOPLEFT", "TOPRIGHT", 1, nil)
    bar.bottomEdge = MakeEdge("BOTTOMLEFT", "BOTTOMRIGHT", 1, nil)
    bar.leftEdge = MakeEdge("TOPLEFT", "BOTTOMLEFT", nil, 1)
    bar.rightEdge = MakeEdge("TOPRIGHT", "BOTTOMRIGHT", nil, 1)

    local gloss = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    gloss:SetTexture("Interface\\Buttons\\WHITE8X8")
    gloss:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    gloss:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)
    gloss:SetHeight(1)
    gloss:SetVertexColor(1, 1, 1, 0.14)
    bar.gloss = gloss

    bar:Hide()
    info.healthBar = bar
    return bar
end

local function UpdateNPCHealthBar(info)
    if not info or not info.blip then return end
    local bar = EnsureNPCHealthBar(info)
    if not bar then return end
    local state = EnsureState(info)
    local pct = tonumber(state.healthPct) or 100
    local updatedAt = tonumber(state.healthUpdatedAt)
    local now = GetTime and GetTime() or 0
    local fresh = updatedAt and updatedAt > 0 and (now - updatedAt) <= HEALTH_STALE_SECONDS

    if state.dead or pct <= 0 or pct >= 99.95 or not fresh or not IsEnemyHonorNPC(info) then
        bar:Hide()
        return
    end

    local inv = GetDisplayCompensation()
    local width = HEALTH_BAR_BASE_WIDTH * inv
    local height = HEALTH_BAR_BASE_HEIGHT * inv
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", info.blip.texture or info.blip, "TOP", 0, 0.10 * inv)
    bar:SetSize(width, height)
    bar:SetFrameLevel((LT.mapBorder and LT.mapBorder:GetFrameLevel() or 1) + NPC_HEALTH_FRAME_OFFSET)
    bar:SetValue(math.max(0, math.min(100, pct)))

    if bar.SetFrameStrata then bar:SetFrameStrata("HIGH") end

    if pct <= 25 then
        bar:SetStatusBarColor(0.90, 0.10, 0.08, 1)
    elseif pct <= 50 then
        bar:SetStatusBarColor(0.96, 0.62, 0.06, 1)
    else
        bar:SetStatusBarColor(0.16, 0.78, 0.22, 1)
    end
    bar:Show()
end

local function IsNPCInObservedCombat(info)
    if not info then return false end
    local state = EnsureState(info)
    if state.dead then return false end
    local pct = tonumber(state.healthPct) or 100
    local updatedAt = tonumber(state.healthUpdatedAt)
    local now = GetTime and GetTime() or 0
    return IsEnemyHonorNPC(info) and updatedAt and updatedAt > 0
        and (now - updatedAt) <= HEALTH_STALE_SECONDS and pct > 0 and pct < 99.95
end

local function RestoreAliveBlipColor(info)
    if not info or not info.blip or not info.blip.texture then return end
    if info.kind == "captain" or info.kind == "boss" then
        info.blip.texture:SetVertexColor(1, 1, 1, 1)
    else
        local r, g, b = GetFactionColor(info)
        info.blip.texture:SetVertexColor(r, g, b, 1)
    end
end

local function UpdateNPCCombatPulse()
    if not LT.map or not LT.addonFrame or not LT.addonFrame:IsShown() or not IsInAlteracValley() then return end
    local now = GetTime and GetTime() or 0
    -- Same calm pulse speed as before, but use attention-grabbing yellow instead
    -- of the opposite faction color. The NPC therefore never looks like it
    -- changed factions merely because it entered combat.
    local t = (math.sin((now * math.pi * 2) / 1.8) + 1) * 0.5
    for _, info in ipairs(LIEUTENANTS) do
        if info.blip and info.blip.texture and IsNPCInObservedCombat(info) then
            local baseR, baseG, baseB
            if info.kind == "captain" or info.kind == "boss" then
                baseR, baseG, baseB = 1, 1, 1
            else
                baseR, baseG, baseB = GetFactionColor(info)
            end
            local r = baseR + ((COMBAT_YELLOW_R - baseR) * t)
            local g = baseG + ((COMBAT_YELLOW_G - baseG) * t)
            local b = baseB + ((COMBAT_YELLOW_B - baseB) * t)
            info.blip.texture:SetVertexColor(r, g, b, 1)
        elseif info.blip and info.blip.texture and not EnsureState(info).dead then
            RestoreAliveBlipColor(info)
        end
    end
end

local function RefreshNPCHealthBars()
    for _, info in ipairs(LIEUTENANTS) do
        if info.healthBar then UpdateNPCHealthBar(info) end
    end
end

local function UpdateBlip(info)
    if not info or not info.blip or not LT.map then return end
    local state = EnsureState(info)

    -- Display only enemy-faction honor NPCs. We still retain all tracked NPC
    -- state internally so reset/sync parsing remains compatible, but friendly
    -- Lieutenants, Commanders, Captains, and patrol widgets stay hidden.
    if not IsEnemyHonorNPC(info) then
        HidePath(info)
        info.blip:Hide()
        if info.healthBar then info.healthBar:Hide() end
        if info.pathWidgets then
            for _, widget in ipairs(info.pathWidgets) do
                if widget.button then widget.button:Hide() end
            end
        end
        return
    end

    local width = LT.map:GetWidth() or 276
    local height = LT.map:GetHeight() or 512
    local coreSize, overlaySize = GetBlipSizes(info)
    local hitSize = GetBlipHitSize(info)
    info.blip:SetSize(hitSize, hitSize)
    local visualYOffset = GetBossVisualYOffset(info)
    if info.blip.texture then
        info.blip.texture:ClearAllPoints()
        info.blip.texture:SetPoint("CENTER", info.blip, "CENTER", 0, visualYOffset)
        info.blip.texture:SetSize(coreSize, coreSize)
    end
    if info.blip.shadow then
        info.blip.shadow:ClearAllPoints()
        info.blip.shadow:SetPoint("CENTER", info.blip, "CENTER", 1, visualYOffset)
        info.blip.shadow:SetSize(coreSize, coreSize)
    end
    if info.blip.shadowLeft then
        info.blip.shadowLeft:ClearAllPoints()
        info.blip.shadowLeft:SetPoint("CENTER", info.blip, "CENTER", -1, visualYOffset)
        info.blip.shadowLeft:SetSize(coreSize, coreSize)
    end
    if info.blip.shadowUp then
        info.blip.shadowUp:ClearAllPoints()
        info.blip.shadowUp:SetPoint("CENTER", info.blip, "CENTER", 0, visualYOffset + 1)
        info.blip.shadowUp:SetSize(coreSize, coreSize)
    end
    if info.blip.shadowDown then
        info.blip.shadowDown:ClearAllPoints()
        info.blip.shadowDown:SetPoint("CENTER", info.blip, "CENTER", 0, visualYOffset - 1)
        info.blip.shadowDown:SetSize(coreSize, coreSize)
    end
    if info.blip.deathProcStarA then
        info.blip.deathProcStarA:ClearAllPoints()
        info.blip.deathProcStarA:SetPoint("CENTER", info.blip, "CENTER", 0, 0)
    end
    if info.blip.deathProcStarB then
        info.blip.deathProcStarB:ClearAllPoints()
        info.blip.deathProcStarB:SetPoint("CENTER", info.blip, "CENTER", 0, 0)
    end

    if state.dead and not state.transitioning then
        -- Death skull/transition owns the same top AV-content stack as the live NPC.
        -- This keeps the death cue visible even inside a pile of player/objective icons.
        info.blip:SetFrameStrata("HIGH")
        info.blip:SetFrameLevel(GetBlipFrameLevel(info))
        if state.deathSkullExpired and info.kind ~= "captain" and info.kind ~= "boss" then
            info.blip:Hide()
            if info.healthBar then info.healthBar:Hide() end
            return
        end
        if info.blip.texture then
            ApplyRaidMarkerSkull(info.blip.texture)
            local deadSize = GetDeadSkullSize(info)
            info.blip.texture:SetSize(deadSize, deadSize)
            info.blip.texture:SetVertexColor(1.00, 1.00, 1.00, 0.98)
            info.blip.texture:SetBlendMode("BLEND")
        end
        if info.blip.shadow then info.blip.shadow:SetVertexColor(0, 0, 0, 0.04) end
        if info.blip.shadowLeft then info.blip.shadowLeft:SetVertexColor(0, 0, 0, 0.04) end
        if info.blip.shadowUp then info.blip.shadowUp:SetVertexColor(0, 0, 0, 0.04) end
        if info.blip.shadowDown then info.blip.shadowDown:SetVertexColor(0, 0, 0, 0.04) end
        if info.pathWidgets then
            for _, widget in ipairs(info.pathWidgets) do
                if widget.outline then widget.outline:SetAlpha(0) end
                if widget.core then widget.core:SetAlpha(0) end
            end
        end
    else
        -- Stable map placement: combat is represented by the health bar and faction/yellow pulse.
        info.blip:SetAlpha(1)
        info.blip:SetFrameLevel(GetBlipFrameLevel(info))
        info.blip:SetFrameStrata("HIGH")
        local r, g, b = GetFactionColor(info)
        if info.kind == "captain" or info.kind == "boss" then
            if info.blip.texture then
                info.blip.texture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
                info.blip.texture:SetTexCoord(0,1,0,1)
                info.blip.texture:SetVertexColor(1, 1, 1, 1)
                info.blip.texture:SetBlendMode("BLEND")
            end
            if info.blip.shadow then info.blip.shadow:SetVertexColor(0, 0, 0, 0.48) end
            if info.blip.shadowLeft then info.blip.shadowLeft:SetVertexColor(0, 0, 0, 0.48) end
            if info.blip.shadowUp then info.blip.shadowUp:SetVertexColor(0, 0, 0, 0.48) end
            if info.blip.shadowDown then info.blip.shadowDown:SetVertexColor(0, 0, 0, 0.48) end
        else
            if info.blip.texture then
                info.blip.texture:SetTexture("Interface\\MINIMAP\\MiniMap-VignetteArrow")
                info.blip.texture:SetTexCoord(0,1,0,1)
                info.blip.texture:SetVertexColor(r, g, b, 1)
                info.blip.texture:SetBlendMode("BLEND")
            end
        end
    end
    state.x, state.y = info.x, info.y
    info.blip:ClearAllPoints()
    info.blip:SetPoint("CENTER", LT.map, "TOPLEFT", (state.x/100)*width, -((state.y/100)*height))
    info.blip:Show()
    UpdateSecureTargetButton(info, width, height, hitSize)
    UpdateNPCHealthBar(info)
    if info.pathWidgets then
        for _, widget in ipairs(info.pathWidgets) do widget.button:Show() end
    end
end

local function UpdateDevButton()
    if not LT.devButton then return end
    local alive, total = 0, #LIEUTENANTS
    for _, info in ipairs(LIEUTENANTS) do
        if not EnsureState(info).dead then alive = alive + 1 end
    end
    LT.devButton.text:SetText(string.format("HONOR %d/%d", alive, total))
end

local function StartDeathSkullFade(info)
    if not info or not info.blip then return end
    local state = EnsureState(info)
    if info.kind == "captain" or info.kind == "boss" then
        -- Captain/final-boss death skull is persistent by design.
        state.deathSkullExpired = false
        state.deathSkullFadeElapsed = nil
        info.blip:SetAlpha(1)
        return
    end

    state.deathSkullExpired = false
    state.deathSkullFadeElapsed = 0
    info.blip:SetAlpha(1)
    info.blip:SetScript("OnUpdate", function(self, elapsed)
        if not state.dead or state.transitioning then return end
        state.deathSkullFadeElapsed = (state.deathSkullFadeElapsed or 0) + (elapsed or 0)
        local t = math.min(1, state.deathSkullFadeElapsed / DEATH_SKULL_FADE_SECONDS)
        self:SetAlpha(math.max(0, 1 - t))
        if t >= 1 then
            state.deathSkullExpired = true
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)
end

local function UpdateAllVisuals()
    for _, info in ipairs(LIEUTENANTS) do UpdateBlip(info) end
    UpdateDevButton()
end

local function ClosePopup()
    if LT.popup then LT.popup:Hide() end
end

local function PrintDeathNotice(info, source)
    if not info or source == "snapshot" or source == "new-match" or source == "reset" then return end
    if not IsEnemyHonorNPC(info) then return end
    local color = info.faction == "Alliance" and "|cff5f9dff" or "|cffff6258"
    local sourceText = source == "sync" and " (reported by another Zurk Maps user)" or ""
    print(string.format("|cff33ff99Zurk Maps|r %s%s|r is |cffff5555DEAD|r.%s", color, info.name, sourceText))
end

MarkDead = function(info, source, shouldBroadcast)
    if not info then return false end
    local state = EnsureState(info)
    if state.dead then return false end
    state.dead = true
    state.healthPct = 0
    state.healthUpdatedAt = GetTime and GetTime() or 0
    state.healthSource = source or "death"
    state.source = source or "unknown"
    state.deathSkullExpired = false
    state.deathSkullFadeElapsed = nil

    -- A newly learned death is a visual event whether we saw it locally or learned
    -- it from another Zurk Maps user/snapshot. Only match-start/reset restoration is silent.
    local animate = source ~= "new-match" and source ~= "reset"
    state.transitioning = animate and true or false
    HidePath(info)
    UpdateBlip(info)

    if animate then
        if IsEnemyHonorNPC(info) and info.honorYield ~= false then
            if source == "combat" then
                -- Prefer the client's actual awarded honor when available. If no
                -- matching honor event arrives, QueueHonorDeath falls back to the
                -- standard AV honor-NPC value so the death presentation is complete.
                QueueHonorDeath(info)
            else
                -- Remote/snapshot/inferred deaths have no local combat-log honor
                -- event to pair with, but the player still needs the same death cue.
                ShowHonorGainFloat(info, DEFAULT_DEATH_HONOR)
            end
        end
        PlayDeathTransition(info, function()
            state.transitioning = false
            UpdateBlip(info)
            StartDeathSkullFade(info)
        end)
    else
        UpdateBlip(info)
        if info.kind ~= "captain" and info.kind ~= "boss" then
            state.deathSkullExpired = true
            info.blip:Hide()
        end
    end

    UpdateDevButton()
    PrintDeathNotice(info, source)
    if shouldBroadcast then Broadcast("D:"..info.id) end
    return true
end

local function RestoreAlive(info, source, shouldBroadcast)
    if not info then return false end
    local state = EnsureState(info)
    if not state.dead then return false end
    state.dead = false
    state.healthPct = 100
    state.healthUpdatedAt = nil
    state.healthSource = nil
    state.transitioning = false
    state.deathSkullExpired = false
    state.deathSkullFadeElapsed = nil
    state.source = source or "manual"
    if info.blip then
        info.blip:SetScript("OnUpdate", nil)
        info.blip:SetAlpha(1)
    end
    state.x, state.y = info.x, info.y
    state.lastSeen = nil
    state.livePositionAt = nil
    UpdateBlip(info)
    UpdateDevButton()
    if shouldBroadcast then Broadcast("R:"..info.id) end
    return true
end

local function ResetAll(source)
    LT.pendingHonorDeaths = {}
    LT.recentHonorGains = {}
    LT.absenceEvidence = {}
    LT.lastAliveBroadcast = {}
    LT.friendlyAuraSeen = { lieutenant=false, commander=false }
    LT.syncElapsed = 0
    LT.scanElapsed = 0
    LT.healthScanElapsed = 0
    LT.healthScanBlocked = {}
    LT.lastHealthBroadcast = {}
    LT.lastSyncRequest = 0
    for _, info in ipairs(LIEUTENANTS) do ClearPositionSensor(info) end
    for _, info in ipairs(LIEUTENANTS) do
        local state = EnsureState(info)
        state.dead = false
        state.healthPct = 100
        state.healthUpdatedAt = nil
        state.healthSource = nil
        state.transitioning = false
        state.x, state.y = info.x, info.y
        state.lastSeen = nil
        state.livePositionAt = nil
        state.source = source or "reset"
        HidePath(info)
    end
    UpdateAllVisuals()
end

local function GetDeadIDs()
    local ids = {}
    for _, info in ipairs(LIEUTENANTS) do
        if EnsureState(info).dead then ids[#ids+1] = tostring(info.id) end
    end
    return ids
end

local function RequestSync(force)
    if not IsInAlteracValley() then return end
    local now = GetTime and GetTime() or 0
    if not force and (now - (LT.lastSyncRequest or 0)) < 2.0 then return end
    LT.lastSyncRequest = now
    Broadcast("Q")
end

local function SendSnapshot(forceEmpty)
    local ids = GetDeadIDs()
    if #ids == 0 and not forceEmpty then return false end
    return Broadcast("S:"..table.concat(ids, ","))
end

local function BroadcastAliveObservation(info)
    if not info or not IsInAlteracValley() then return end
    local now = GetTime and GetTime() or 0
    local last = LT.lastAliveBroadcast[info.id] or 0
    if now - last < 3.0 then return end
    LT.lastAliveBroadcast[info.id] = now
    Broadcast("A:"..info.id)
end

local function SetObservedPosition(info, xPct, yPct, shouldBroadcast)
    if not info or type(xPct)~="number" or type(yPct)~="number" then return end
    local state = EnsureState(info)

    -- Directly seeing a tracked NPC alive is stronger evidence than any prior
    -- synced/inferred death state. Correct it immediately and share the repair.
    local revived = false
    if state.dead then
        state.dead = false
        state.transitioning = false
        state.source = "seen-alive"
        revived = true
    end

    state.x = math.max(0, math.min(100, xPct))
    state.y = math.max(0, math.min(100, yPct))
    local now = GetTime and GetTime() or 0
    state.lastSeen = now
    state.livePositionAt = now
    state.source = "seen"
    LT.absenceEvidence[info.id] = nil
    UpdateBlip(info)

    if revived and shouldBroadcast and IsInAlteracValley() then
        Broadcast("R:"..info.id)
    end

    if shouldBroadcast and IsInAlteracValley() then
        local last = LT.lastPositionBroadcast[info.id] or 0
        if now - last >= 2 then
            LT.lastPositionBroadcast[info.id] = now
            Broadcast(string.format("P:%d:%.2f:%.2f", info.id, state.x, state.y))
        end
    end
end

local function GetCustomUnitPosition(unit)
    local mapID = LT.config and LT.config.getUiMapID and LT.config.getUiMapID() or nil
    if not mapID or not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" then return nil, nil end
    local ok, position = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
    if not ok or not position then return nil, nil end
    local x,y
    if type(position.GetXY) == "function" then
        local okXY, px, py = pcall(position.GetXY, position)
        if okXY then x,y=px,py end
    else
        x,y=position.x,position.y
    end
    if type(x)~="number" or type(y)~="number" or (x==0 and y==0) then return nil, nil end
    if LT.config and type(LT.config.transformMapPosition)=="function" then
        local okTransform, customX, customY = pcall(LT.config.transformMapPosition, x, y)
        if okTransform and type(customX)=="number" and type(customY)=="number" then
            return customX, customY
        end
    end
    return RawMapToAVMap(x,y)
end

local function ObserveUnit(unit, shouldBroadcast, skipMapPosition)
    local info = GetInfoFromUnit(unit)
    if not info then return nil end

    local isDead = false
    if UnitIsDeadOrGhost then
        local ok, value = pcall(UnitIsDeadOrGhost, unit)
        if ok and value then isDead = true end
    elseif UnitIsDead then
        local ok, value = pcall(UnitIsDead, unit)
        if ok and value then isDead = true end
    end

    if isDead then
        -- Seeing the corpse is retrospective evidence. Update/sync the state,
        -- but never queue the +Honor animation.
        MarkDead(info, "seen-dead", shouldBroadcast and true or false)
        return info
    end

    -- A direct unit token is authoritative proof that this NPC is alive, even
    -- when C_Map cannot provide coordinates for NPC nameplate/target tokens.
    local state = EnsureState(info)
    if state.dead then RestoreAlive(info, "seen-alive", shouldBroadcast and true or false) end
    state.lastSeen = GetTime and GetTime() or 0
    LT.absenceEvidence[info.id] = nil
    if shouldBroadcast then BroadcastAliveObservation(info) end

    -- Health/death observations update state, but NPC map placement remains static.
    return info
end

-- Capping-style distributed tracked-NPC health observation. Classic exposes raid member
-- targets as unit tokens even when the Zurk Maps user is nowhere near that NPC.
-- Scanning raid1target..raid40target therefore lets one local client learn about
-- a tracked AV NPC whenever any raid member is actively targeting it. The death
-- is then shared through Zurk Maps' existing INSTANCE_CHAT D:/snapshot protocol.
local HEALTH_SCAN_UNITS_PRIMARY = {
    "target", "targettarget",
    "mouseover", "mouseovertarget",
    "focus", "focustarget",
    "softenemy", "softenemytarget",
}
local HEALTH_SCAN_UNITS_NAMEPLATE_TARGET = {}
local HEALTH_SCAN_UNITS_RAID_TARGET = {}
for index = 1, 40 do
    HEALTH_SCAN_UNITS_PRIMARY[#HEALTH_SCAN_UNITS_PRIMARY + 1] = "nameplate" .. index
    HEALTH_SCAN_UNITS_NAMEPLATE_TARGET[#HEALTH_SCAN_UNITS_NAMEPLATE_TARGET + 1] = "nameplate" .. index .. "target"
    HEALTH_SCAN_UNITS_RAID_TARGET[#HEALTH_SCAN_UNITS_RAID_TARGET + 1] = "raid" .. index .. "target"
end

local function SetObservedHealth(info, pct, source, shouldBroadcast)
    if not info then return end
    pct = tonumber(pct)
    if not pct or pct ~= pct then return end
    pct = math.max(0, math.min(100, pct))

    local state = EnsureState(info)
    state.healthPct = pct
    state.healthUpdatedAt = GetTime and GetTime() or 0
    state.healthSource = source or "observed"
    UpdateNPCHealthBar(info)

    if shouldBroadcast and IsInAlteracValley() then
        local now = GetTime and GetTime() or 0
        local last = LT.lastHealthBroadcast[info.id] or 0
        if (now - last) >= 0.75 then
            LT.lastHealthBroadcast[info.id] = now
            Broadcast(string.format("H:%d:%.1f", info.id, pct))
        end
    end
end

local function ScanHealthUnit(unit, allowRepeat)
    if not unit or not UnitGUID then return end
    local guid = UnitGUID(unit)
    if not guid then return end
    local npcID = GetNPCIDFromGUID(guid)
    local info = npcID and BY_ID[npcID] or nil
    if not info or (LT.healthScanBlocked[npcID] and not allowRepeat) then return end

    local maxHealth = UnitHealthMax and UnitHealthMax(unit) or 0
    if not maxHealth or maxHealth <= 0 then return end

    -- Only process one live token per tracked NPC during the periodic sweep.
    -- Event-driven UNIT_HEALTH / UNIT_TARGET observations bypass this block so
    -- the map can react immediately between one-second sweeps.
    if not allowRepeat then LT.healthScanBlocked[npcID] = true end

    local currentHealth = UnitHealth and UnitHealth(unit) or 0
    local healthPct = (currentHealth / maxHealth) * 100
    local dead = currentHealth <= 0
    if not dead and UnitIsDeadOrGhost then
        local ok, value = pcall(UnitIsDeadOrGhost, unit)
        dead = ok and value and true or false
    elseif not dead and UnitIsDead then
        local ok, value = pcall(UnitIsDead, unit)
        dead = ok and value and true or false
    end

    if dead then
        SetObservedHealth(info, 0, "raid-target-health", false)
        MarkDead(info, "raid-target-health", true)
        return
    end

    -- A valid >0-health raid-target token is useful alive evidence, but don't
    -- let a slightly stale remote target undo a confirmed combat/synced death.
    -- Only repair the low-confidence automatic absence inference here. Direct
    -- local target/nameplate events still use ObserveUnit() and remain capable
    -- of correcting a genuinely false state.
    local state = EnsureState(info)
    state.lastSeen = GetTime and GetTime() or 0
    LT.absenceEvidence[info.id] = nil
    if state.dead then
        if state.source == "inferred" then
            RestoreAlive(info, "raid-target-alive", true)
            SetObservedHealth(info, healthPct, "raid-target-health", true)
        end
    else
        SetObservedHealth(info, healthPct, "raid-target-health", true)
        BroadcastAliveObservation(info)
    end
end

local function ScanHealthUnitList(units)
    for _, unit in ipairs(units) do
        ScanHealthUnit(unit)
    end
end

local function ScanRaidObservedHonorNPCHealth()
    if not IsInAlteracValley() then return end
    wipe(LT.healthScanBlocked)

    -- Mirror Capping's low-hitch scan strategy: local/nameplate tokens first,
    -- then nameplate targets and all 40 raid-member targets on tiny staggered
    -- timers rather than doing the entire token set in one frame.
    ScanHealthUnitList(HEALTH_SCAN_UNITS_PRIMARY)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.01, function()
            if IsInAlteracValley() then ScanHealthUnitList(HEALTH_SCAN_UNITS_NAMEPLATE_TARGET) end
        end)
        C_Timer.After(0.02, function()
            if IsInAlteracValley() then ScanHealthUnitList(HEALTH_SCAN_UNITS_RAID_TARGET) end
        end)
    else
        ScanHealthUnitList(HEALTH_SCAN_UNITS_NAMEPLATE_TARGET)
        ScanHealthUnitList(HEALTH_SCAN_UNITS_RAID_TARGET)
    end
end

local function ConfigurePositionSensor(sensor)
    if not sensor then return false end
    if LT.config and type(LT.config.configureNativePositionFrame) == "function" then
        local ok = pcall(LT.config.configureNativePositionFrame, sensor)
        if not ok then return false end
    elseif LT.map then
        sensor:ClearAllPoints()
        sensor:SetAllPoints(LT.map)
    end
    local mapID = LT.config and LT.config.getUiMapID and LT.config.getUiMapID() or nil
    if mapID and type(sensor.SetUiMapID) == "function" then
        pcall(sensor.SetUiMapID, sensor, mapID)
    end
    return true
end

local function EnsurePositionSensor(info)
    if not info then return nil end
    local existing = LT.positionSensors[info.id]
    if existing then
        ConfigurePositionSensor(existing)
        return existing
    end

    local parent = (LT.config and LT.config.positionParent) or LT.map
    if not parent then return nil end
    local ok, sensor = pcall(CreateFrame, "UnitPositionFrame", nil, parent)
    if not ok or not sensor
        or type(sensor.AddUnit) ~= "function"
        or type(sensor.ClearUnits) ~= "function"
        or type(sensor.FinalizeUnits) ~= "function" then
        if sensor then sensor:Hide() end
        return nil
    end

    if sensor.SetFrameStrata then sensor:SetFrameStrata("HIGH") end
    if sensor.SetFrameLevel then sensor:SetFrameLevel(GetLiveNPCFrameLevel() - 1) end
    if sensor.SetMouseMotionEnabled then sensor:SetMouseMotionEnabled(false) else sensor:EnableMouse(false) end
    if sensor.SetMouseClickEnabled then sensor:SetMouseClickEnabled(false) end
    ConfigurePositionSensor(sensor)
    pcall(sensor.ClearUnits, sensor)
    pcall(sensor.FinalizeUnits, sensor)
    sensor._boundUnit = nil
    sensor._nativePin = nil
    sensor._lastObservedX = nil
    sensor._lastObservedY = nil
    sensor._lastObservedAt = nil
    sensor:SetAlpha(1)
    sensor:Hide()
    LT.positionSensors[info.id] = sensor
    return sensor
end

ClearPositionSensor = function(info)
    local sensor = info and LT.positionSensors[info.id] or nil
    if sensor then
        if sensor._boundUnit ~= nil then
            pcall(sensor.ClearUnits, sensor)
            pcall(sensor.FinalizeUnits, sensor)
            sensor._boundUnit = nil
        end
        sensor._nativePin = nil
        sensor._lastObservedX = nil
        sensor._lastObservedY = nil
        sensor._lastObservedAt = nil
        sensor:SetAlpha(1)
        sensor:Hide()
    end
    if info then
        LT.nativeLiveActive[info.id] = nil
        LT.nativePositionResolved[info.id] = nil
        if info.blip then UpdateBlip(info) end
    end
end

local function AddVisiblePositionUnit(result, unit, prefer)
    if not unit or not UnitExists or not UnitExists(unit) then return end
    local info = ObserveUnit(unit, true, true)
    if not info or not IsEnemyHonorNPC(info) then return end
    local state = EnsureState(info)
    if state.dead then return end
    if prefer or not result[info.id] then result[info.id] = unit end
end

local function CollectVisiblePositionUnits()
    local result = LT.livePositionUnits
    for id in pairs(result) do result[id] = nil end

    if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local unit = plate and (plate.namePlateUnitToken or plate.unitToken)
                if unit then AddVisiblePositionUnit(result, unit, true) end
            end
        end
    end
    AddVisiblePositionUnit(result, "target", false)
    AddVisiblePositionUnit(result, "mouseover", false)
    AddVisiblePositionUnit(result, "focus", false)
    AddVisiblePositionUnit(result, "softenemy", false)
    return result
end

local function GetNativePinCandidate(sensor)
    if not sensor or type(sensor.GetChildren) ~= "function" then return nil end

    local cached = sensor._nativePin
    if cached and cached.GetCenter and (not cached.IsShown or cached:IsShown()) then
        return cached
    end

    local children = { sensor:GetChildren() }
    local best, bestArea
    for _, child in ipairs(children) do
        if child and child.GetCenter and (not child.IsShown or child:IsShown()) then
            local w = child.GetWidth and (child:GetWidth() or 0) or 0
            local h = child.GetHeight and (child:GetHeight() or 0) or 0
            -- UnitPositionFrame pins are small children. Reject container-sized
            -- implementation frames if Blizzard happens to expose them as children.
            if w > 0 and h > 0 and w <= 80 and h <= 80 then
                local area = w * h
                if not bestArea or area < bestArea then
                    best, bestArea = child, area
                end
            end
        end
    end
    sensor._nativePin = best
    return best
end

local function ReadNativeSensorPosition(info, sensor, shouldBroadcast)
    if not info or not sensor or not sensor._boundUnit or not LT.map then return false end
    local pin = GetNativePinCandidate(sensor)
    if not pin then return false end

    local cx, cy = pin:GetCenter()
    local mapLeft, mapTop = LT.map:GetLeft(), LT.map:GetTop()
    local mapWidth, mapHeight = LT.map:GetWidth(), LT.map:GetHeight()
    if not cx or not cy or not mapLeft or not mapTop or not mapWidth or not mapHeight
        or mapWidth <= 0 or mapHeight <= 0 then return false end

    local xPct = ((cx - mapLeft) / mapWidth) * 100
    local yPct = ((mapTop - cy) / mapHeight) * 100
    if xPct < -2 or xPct > 102 or yPct < -2 or yPct > 102 then return false end
    xPct = math.max(0, math.min(100, xPct))
    yPct = math.max(0, math.min(100, yPct))

    local now = GetTime and GetTime() or 0
    local lastX, lastY = sensor._lastObservedX, sensor._lastObservedY
    local moved = not lastX or not lastY or math.abs(xPct - lastX) >= 0.02 or math.abs(yPct - lastY) >= 0.02
    local refresh = not sensor._lastObservedAt or (now - sensor._lastObservedAt) >= 0.50
    if moved or refresh then
        sensor._lastObservedX, sensor._lastObservedY = xPct, yPct
        sensor._lastObservedAt = now
        SetObservedPosition(info, xPct, yPct, shouldBroadcast and true or false)
    end

    LT.nativePositionResolved[info.id] = true
    -- Keep the native position provider alive, but make our established NPC art
    -- the visible moving marker once we have successfully harvested its pin.
    sensor:SetAlpha(0.01)
    if info.blip then info.blip:SetAlpha(1) end
    return true
end

local function GetNativeLiveVisual(info)
    local coreSize = select(1, GetBlipSizes(info)) or 8
    if info.kind == "captain" then
        return "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", coreSize, 1, 1, 1, 1
    end
    local r, g, b = GetFactionColor(info)
    return "Interface\\MINIMAP\\MiniMap-VignetteArrow", coreSize, r, g, b, 1
end

local function BindNativeLiveUnit(info, unit)
    local sensor = EnsurePositionSensor(info)
    if not sensor then return false end
    ConfigurePositionSensor(sensor)

    -- Keep the same token continuously bound. UnitPositionFrame owns the motion;
    -- repeatedly clearing/re-adding it can prevent its internal position provider
    -- from ever reaching a rendered update.
    if sensor._boundUnit ~= unit then
        pcall(sensor.ClearUnits, sensor)
        local texture, size, r, g, b, a = GetNativeLiveVisual(info)
        local okAdd = pcall(sensor.AddUnit, sensor, unit, texture, size, size, r, g, b, a, 1, false)
        pcall(sensor.FinalizeUnits, sensor)
        if not okAdd then
            sensor._boundUnit = nil
            sensor:Hide()
            LT.nativeLiveActive[info.id] = nil
            LT.nativePositionResolved[info.id] = nil
            return false
        end
        sensor._boundUnit = unit
        sensor._nativePin = nil
        sensor._lastObservedX = nil
        sensor._lastObservedY = nil
        sensor._lastObservedAt = nil
        LT.nativePositionResolved[info.id] = nil
        sensor:SetAlpha(1)
    end

    sensor:Show()
    LT.nativeLiveActive[info.id] = true
    -- Until the native pin is readable, keep the established marker visible as a
    -- reference instead of almost erasing it. The native pin itself sits above
    -- player icons, so a successfully moving pin should be easy to distinguish.
    if info.blip and not LT.nativePositionResolved[info.id] then info.blip:SetAlpha(0.55) end
    return true
end

local function UpdateLiveNPCPositions()
    if not LT.map or not LT.addonFrame or not LT.addonFrame:IsShown() or not IsInAlteracValley() then
        for _, info in ipairs(LIEUTENANTS) do ClearPositionSensor(info) end
        return
    end

    local visible = CollectVisiblePositionUnits()
    local now = GetTime and GetTime() or 0
    for _, info in ipairs(LIEUTENANTS) do
        local state = EnsureState(info)
        local unit = visible[info.id]
        if unit and IsEnemyHonorNPC(info) and not state.dead then
            if BindNativeLiveUnit(info, unit) then
                -- Unlike R4n, do not assume the pin exists in the same tick it was
                -- created. Sample it on subsequent 0.10s ticks and, once exposed,
                -- drive the existing Zurk Maps NPC blip from that native position.
                ReadNativeSensorPosition(info, LT.positionSensors[info.id], true)
            else
                ClearPositionSensor(info)
            end
        else
            ClearPositionSensor(info)
            -- A last-known moving position is useful briefly, but it should not be
            -- presented as live forever after every observer loses the NPC.
            if state.livePositionAt and (now - state.livePositionAt) > LIVE_POSITION_STALE_SECONDS then
                state.x, state.y = info.x, info.y
                state.livePositionAt = nil
                state.lastSeen = nil
                state.source = "static"
                UpdateBlip(info)
            end
        end
    end
end

function LT.RefreshNativePositionGeometry()
    for _, sensor in pairs(LT.positionSensors) do ConfigurePositionSensor(sensor) end
end

local function EnemyNameplatesEnabled()
    if type(GetCVarBool) == "function" then
        local ok, value = pcall(GetCVarBool, "nameplateShowEnemies")
        if ok and type(value) == "boolean" then return value end
    end
    if type(GetCVar) == "function" then
        local ok, value = pcall(GetCVar, "nameplateShowEnemies")
        if ok and value ~= nil then return tostring(value) == "1" end
    end
    return false
end

local function FriendlyNameplatesEnabled()
    if type(GetCVarBool) == "function" then
        local ok, value = pcall(GetCVarBool, "nameplateShowFriends")
        if ok and type(value) == "boolean" then return value end
    end
    if type(GetCVar) == "function" then
        local ok, value = pcall(GetCVar, "nameplateShowFriends")
        if ok and value ~= nil then return tostring(value) == "1" end
    end
    return false
end

local function PlayerHasOfficerAura(kind)
    if kind ~= "lieutenant" and kind ~= "commander" then return false, false end
    if type(UnitBuff) ~= "function" then return false, false end

    local wanted = kind == "commander" and "grip of command" or "aura of battle"
    local sawAnyBuff = false
    for index = 1, 40 do
        local ok, name = pcall(UnitBuff, "player", index)
        if not ok or not name then break end
        sawAnyBuff = true
        local lower = string.lower(tostring(name))
        if string.find(lower, wanted, 1, true) then
            LT.friendlyAuraSeen[kind] = true
            return true, true
        end
    end
    return false, sawAnyBuff
end

local function MapDistance(aX, aY, bX, bY)
    if not aX or not aY or not bX or not bY then return math.huge end
    -- AV's bitmap is much taller than it is wide. Weight X by the bitmap aspect
    -- ratio so proximity checks correspond to what the player actually sees.
    local dx = (aX - bX) * (276 / 512)
    local dy = aY - bY
    return math.sqrt((dx * dx) + (dy * dy))
end

local function GetNearestRoutePoint(info, playerX, playerY)
    if not info or not info.route then return nil, math.huge end
    local bestIndex, bestDistance
    for index, point in ipairs(info.route) do
        local distance = MapDistance(playerX, playerY, point[1], point[2])
        if not bestDistance or distance < bestDistance then
            bestIndex, bestDistance = index, distance
        end
    end
    return bestIndex, bestDistance or math.huge
end

FindNearbyAliveEnemyHonorNPC = function(maxDistance)
    local playerX, playerY = GetCustomUnitPosition("player")
    if not playerX or not playerY then return nil, nil, nil end
    maxDistance = tonumber(maxDistance) or 6.0
    local bestInfo, bestDistance, secondDistance
    for _, info in ipairs(LIEUTENANTS) do
        local state = EnsureState(info)
        if IsEnemyHonorNPC(info) and info.honorYield ~= false and not state.dead then
            local distance
            if info.route and #info.route > 0 then
                local _, routeDistance = GetNearestRoutePoint(info, playerX, playerY)
                distance = routeDistance
            else
                local referenceX = state.lastSeen and state.x or info.x
                local referenceY = state.lastSeen and state.y or info.y
                distance = MapDistance(playerX, playerY, referenceX, referenceY)
            end
            if distance and distance <= maxDistance then
                if not bestDistance or distance < bestDistance then
                    secondDistance = bestDistance
                    bestInfo, bestDistance = info, distance
                elseif not secondDistance or distance < secondDistance then
                    secondDistance = distance
                end
            end
        end
    end
    return bestInfo, bestDistance, secondDistance
end

local function GetVisibleTrackedNPCs()
    local visible = {}
    local function AddUnit(unit)
        if not unit or not UnitExists or not UnitExists(unit) then return end
        local info = ObserveUnit(unit, true)
        if info then visible[info.id] = true end
    end

    AddUnit("target")
    AddUnit("mouseover")
    AddUnit("focus")
    AddUnit("softenemy")

    if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local unit = plate and (plate.namePlateUnitToken or plate.unitToken)
                if unit then AddUnit(unit) end
            end
        end
    end
    return visible
end

local function CountRecentRoutePoints(points, now)
    local count = 0
    for index, seenAt in pairs(points or {}) do
        if now - (seenAt or 0) <= 12 then
            count = count + 1
        else
            points[index] = nil
        end
    end
    return count
end

local function ScanForAbsentTrackedNPCs()
    if not IsInAlteracValley() then return end
    local playerX, playerY = GetCustomUnitPosition("player")
    if not playerX or not playerY then return end

    local enemyPlates = EnemyNameplatesEnabled()
    local visible = GetVisibleTrackedNPCs()
    local now = GetTime and GetTime() or 0

    -- Only enemy honor NPCs are displayed. Their fallback status should therefore
    -- be aggressive enough to clear stale alive blips when the player physically
    -- runs through the NPC's expected area, even if the corpse is already gone.
    for _, info in ipairs(LIEUTENANTS) do
        local state = EnsureState(info)
        if IsEnemyHonorNPC(info) and info.kind ~= "boss" and not state.dead then
            if visible[info.id] then
                LT.absenceEvidence[info.id] = nil
            else
                local evidence = LT.absenceEvidence[info.id] or { samples = 0, routePoints = {}, since = now }
                local nearby = false
                local enoughEvidence = false

                if info.kind == "lieutenant" and info.route and #info.route > 0 then
                    local routeIndex, distance = GetNearestRoutePoint(info, playerX, playerY)
                    local radius = enemyPlates and 4.8 or 4.0
                    if routeIndex and distance <= radius then
                        nearby = true
                        evidence.samples = (evidence.samples or 0) + 1
                        evidence.routePoints[routeIndex] = now
                        -- Nameplates are positive live evidence when the lieutenant is
                        -- actually present. If none is found while the player stays in
                        -- the patrol corridor, don't require a full sweep of the route;
                        -- a few sustained samples are enough to remove a stale blip.
                        if enemyPlates then
                            enoughEvidence = evidence.samples >= 3
                        else
                            local routeCoverage = CountRecentRoutePoints(evidence.routePoints, now)
                            enoughEvidence = evidence.samples >= 5 and routeCoverage >= 1
                        end
                    end
                else
                    local referenceX = state.lastSeen and state.x or info.x
                    local referenceY = state.lastSeen and state.y or info.y
                    local distance = MapDistance(playerX, playerY, referenceX, referenceY)
                    local radius
                    local neededSamples
                    if info.kind == "lieutenant" then
                        radius = enemyPlates and 4.6 or 3.8
                        neededSamples = enemyPlates and 3 or 5
                    elseif info.kind == "commander" then
                        radius = enemyPlates and 4.4 or 3.6
                        neededSamples = enemyPlates and 3 or 6
                    else
                        radius = enemyPlates and 3.8 or 3.2
                        neededSamples = enemyPlates and 4 or 7
                    end

                    if distance <= radius then
                        nearby = true
                        evidence.samples = (evidence.samples or 0) + 1
                        enoughEvidence = evidence.samples >= neededSamples
                    end
                end

                if nearby then
                    evidence.lastNearby = now
                    LT.absenceEvidence[info.id] = evidence
                    if enoughEvidence then
                        MarkDead(info, "inferred", true)
                        LT.absenceEvidence[info.id] = nil
                    end
                elseif evidence.lastNearby and (now - evidence.lastNearby) > 4 then
                    LT.absenceEvidence[info.id] = nil
                end
            end
        end
    end
end

local ReportStatus

local function BuildPathWidgets(info)
    if not LT.map or not info.route or #info.route < 2 then return end
    info.pathWidgets = {}
    local mapWidth = LT.map:GetWidth() or 276
    local mapHeight = LT.map:GetHeight() or 512
    local r,g,b = GetFactionColor(info)
    local inv = GetDisplayCompensation()

    for segmentIndex=1,#info.route-1 do
        local a,bp = info.route[segmentIndex], info.route[segmentIndex+1]
        local ax,ay = (a[1]/100)*mapWidth,(a[2]/100)*mapHeight
        local bx,by = (bp[1]/100)*mapWidth,(bp[2]/100)*mapHeight
        local dx,dy = bx-ax,by-ay
        local distance = math.sqrt(dx*dx + dy*dy)
        local steps = math.max(1, math.ceil(distance/3))
        for step=0,steps-1 do
            local t = step/steps
            local px,py = ax+(dx*t), ay+(dy*t)
            local hit = CreateFrame("Button", nil, LT.map)
            hit:SetSize(9*inv,9*inv)
            hit:SetPoint("CENTER", LT.map, "TOPLEFT", px, -py)
            hit:SetFrameLevel((LT.mapBorder and LT.mapBorder:GetFrameLevel() or LT.map:GetFrameLevel()) + 1)
            hit:EnableMouse(true)
            hit:RegisterForClicks("LeftButtonUp","RightButtonUp")

            local outline = hit:CreateTexture(nil,"ARTWORK")
            outline:SetSize(5.0*inv,5.0*inv)
            outline:SetPoint("CENTER")
            outline:SetTexture("Interface\\Buttons\\WHITE8X8")
            outline:SetVertexColor(0.98,0.98,1.00,1)
            outline:SetBlendMode("ADD")
            outline:SetAlpha(0)

            local core = hit:CreateTexture(nil,"OVERLAY")
            core:SetSize(2.3*inv,2.3*inv)
            core:SetPoint("CENTER")
            core:SetTexture("Interface\\Buttons\\WHITE8X8")
            core:SetVertexColor(r,g,b,1)
            core:SetAlpha(0)

            hit:SetScript("OnEnter", function(self)
                info.routeHover = true
                ShowPath(info)
                ShowLieutenantTooltip(self, info, true)
            end)
            hit:SetScript("OnLeave", function()
                info.routeHover = false
                GameTooltip:Hide()
                ScheduleHidePath(info)
            end)
            hit:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    ReportStatus(info)
                elseif button == "RightButton" and LT.config and LT.config.openMapMenu then
                    LT.config.openMapMenu(self)
                end
            end)
            info.pathWidgets[#info.pathWidgets+1] = {button=hit,outline=outline,core=core}
        end
    end
end

local function GetCalloutPronoun(info)
    -- Balinda is the only female honor-yielding NPC in the tracked set.
    if info and info.key == "BALINDA" then return "she" end
    return "he"
end

local function BuildLocationPhrase(pronoun, where, pastTense)
    where = tostring(where or "Alterac Valley")
    local verb = pastTense and "was" or "is"
    local lower = string.lower(where)

    -- Lua patterns do not support regex alternation with `|`, so test each
    -- directional phrase explicitly. These fragments already include their
    -- relationship to the landmark and must never be prefixed with "at".
    if string.match(lower, "^north of ")
        or string.match(lower, "^south of ")
        or string.match(lower, "^east of ")
        or string.match(lower, "^west of ")
        or string.match(lower, "^upper%-left of ")
        or string.match(lower, "^upper%-right of ")
        or string.match(lower, "^lower%-left of ")
        or string.match(lower, "^lower%-right of ") then
        return string.format("%s %s %s", pronoun, verb, where)
    end

    -- Road descriptions read naturally with "on the".
    if string.match(lower, "^road ") then
        return string.format("%s %s on the %s", pronoun, verb, where)
    end

    -- This abbreviated route name represents a corridor between two landmarks.
    if where == "Garrison to Iceblood GY" then
        return string.format("%s %s between Iceblood Garrison and Iceblood GY", pronoun, verb)
    end

    return string.format("%s %s at %s", pronoun, verb, where)
end

ReportStatus = function(info)
    if not info then return end
    local state = EnsureState(info)
    local where = info.calloutLocation or info.location or "Alterac Valley"
    local pronoun = GetCalloutPronoun(info)
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local isFriendly = playerFaction and info.faction == playerFaction
    local message

    if state.dead then
        message = string.format("%s is dead (%s).", info.name, BuildLocationPhrase(pronoun, where, true))
    elseif isFriendly then
        message = string.format("%s is alive (%s).", info.name, BuildLocationPhrase(pronoun, where, false))
    else
        message = string.format("Kill %s if you can (%s).", info.name, BuildLocationPhrase(pronoun, where, false))
    end

    if LT.config and type(LT.config.sendCallout) == "function" then
        LT.config.sendCallout(message)
    elseif SendChatMessage then
        SendChatMessage(message, "SAY")
    end
end


-- TargetUnit() is protected when called directly from addon Lua. Keep the
-- animated NPC marker itself insecure, and use an invisible secure action button
-- for the physical left-click /targetexact action. CRITICAL: the protected button
-- must not be parented or anchored to ZurkMapsAVMapFrame (or any child of it),
-- otherwise Blizzard can propagate protected-frame restrictions back into the AV
-- map and block ordinary frame:Show()/Hide() calls during combat.
local function EnsureSecureTargetButton(info)
    if not info or not LT.map or not IsEnemyHonorNPC(info) then return nil end
    if info.secureTargetButton then return info.secureTargetButton end
    if InCombatLockdown and InCombatLockdown() then
        LT.pendingSecureTargetButtons = true
        return nil
    end

    local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    -- This proxy must win mouse hit-testing over the ordinary AV blip even though
    -- it is no longer in the map's frame hierarchy. TOOLTIP strata is deliberate:
    -- the proxy has no artwork, so this only affects click/hover ownership.
    button:SetFrameStrata("TOOLTIP")
    button:SetFrameLevel(10000)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", "/targetexact " .. info.name)
    button:Hide()

    button:SetScript("OnEnter", function(self)
        info.routeHover = true
        ShowLieutenantTooltip(self, info, false)
    end)
    button:SetScript("OnLeave", function()
        info.routeHover = false
        GameTooltip:Hide()
        ScheduleHidePath(info)
    end)
    -- Do not install a normal OnClick script on a SecureActionButtonTemplate.
    -- PostClick preserves Blizzard's secure left-click action, then handles our
    -- ordinary right-click callout after the secure click machinery has run.
    button:SetScript("PostClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ReportStatus(info)
        end
    end)

    info.secureTargetButton = button
    return button
end

local function GetSecureTargetScreenGeometry(info, width, height, hitSize)
    if not info or not LT.map or not UIParent then return nil end
    hitSize = hitSize or GetBlipHitSize(info)

    -- Use the blip's *resolved screen position* rather than recomputing it from
    -- map percentages. That keeps the detached secure proxy pixel-aligned after
    -- every map resize/scale/position change without anchoring the protected
    -- button to ZurkMapsAVMapFrame.
    if info.blip and info.blip.GetCenter then
        local centerX, centerY = info.blip:GetCenter()
        if type(centerX) == "number" and type(centerY) == "number" then
            local blipScale = info.blip.GetEffectiveScale and info.blip:GetEffectiveScale() or 1
            local uiScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
            if not uiScale or uiScale <= 0 then uiScale = 1 end
            local scaleRatio = (blipScale or 1) / uiScale
            return centerX * scaleRatio, centerY * scaleRatio, math.max(1, hitSize * scaleRatio)
        end
    end

    -- Fallback for the brief creation window before the blip has a resolved
    -- center. This still uses only UIParent coordinates and never creates a
    -- protected anchor relationship back to the map.
    local mapLeft, mapTop = LT.map:GetLeft(), LT.map:GetTop()
    if type(mapLeft) ~= "number" or type(mapTop) ~= "number" then return nil end
    width = width or LT.map:GetWidth() or 276
    height = height or LT.map:GetHeight() or 512
    local mapScale = LT.map.GetEffectiveScale and LT.map:GetEffectiveScale() or 1
    local uiScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not uiScale or uiScale <= 0 then uiScale = 1 end
    local scaleRatio = (mapScale or 1) / uiScale
    local x = (mapLeft + ((info.x / 100) * width)) * scaleRatio
    local y = (mapTop - ((info.y / 100) * height)) * scaleRatio
    return x, y, math.max(1, hitSize * scaleRatio)
end

UpdateSecureTargetButton = function(info, width, height, hitSize)
    local button = info and (info.secureTargetButton or EnsureSecureTargetButton(info)) or nil
    if not button then return end
    if InCombatLockdown and InCombatLockdown() then
        LT.pendingSecureTargetButtons = true
        return
    end

    local x, y, screenHitSize = GetSecureTargetScreenGeometry(info, width, height, hitSize)
    button:ClearAllPoints()
    if x and y and LT.addonFrame and LT.addonFrame:IsShown() and IsInAlteracValley() then
        button:SetSize(screenHitSize, screenHitSize)
        button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        button:SetFrameStrata("TOOLTIP")
        button:SetFrameLevel(10000)
        button:Show()
    else
        button:Hide()
    end
end

local function RefreshSecureTargetButtons()
    if InCombatLockdown and InCombatLockdown() then
        LT.pendingSecureTargetButtons = true
        return
    end
    LT.pendingSecureTargetButtons = false
    local width = LT.map and LT.map:GetWidth() or 276
    local height = LT.map and LT.map:GetHeight() or 512
    for _, info in ipairs(LIEUTENANTS) do
        if IsEnemyHonorNPC(info) then
            EnsureSecureTargetButton(info)
            UpdateSecureTargetButton(info, width, height, GetBlipHitSize(info))
        end
    end
end
LT.RefreshSecureTargetButtons = RefreshSecureTargetButtons

local function CreateBlip(info)
    if not LT.map or info.blip then return end
    local r,g,b = GetFactionColor(info)
    local coreSize, overlaySize = GetBlipSizes(info)
    local hitSize = GetBlipHitSize(info)
    local blip = CreateFrame("Button", nil, LT.map)
    blip:SetSize(hitSize,hitSize)
    blip:SetFrameLevel(GetBlipFrameLevel(info))
    blip:SetFrameStrata("HIGH")
    blip:EnableMouse(true)
    blip:RegisterForClicks("LeftButtonUp","RightButtonUp")

    if info.kind == "captain" or info.kind == "boss" then
        -- Four same-size, one-pixel-offset copies create a darker edge around
        -- the raid-boss skull without making the captain icon itself larger.
        local visualYOffset = GetBossVisualYOffset(info)
        blip.shadow = blip:CreateTexture(nil,"ARTWORK")
        blip.shadow:SetPoint("CENTER", blip, "CENTER", 1, visualYOffset)
        blip.shadow:SetSize(coreSize, coreSize)
        blip.shadow:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        blip.shadow:SetTexCoord(0,1,0,1)
        blip.shadow:SetVertexColor(0,0,0,0.48)

        blip.shadowLeft = blip:CreateTexture(nil,"ARTWORK")
        blip.shadowLeft:SetPoint("CENTER", blip, "CENTER", -1, visualYOffset)
        blip.shadowLeft:SetSize(coreSize, coreSize)
        blip.shadowLeft:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        blip.shadowLeft:SetTexCoord(0,1,0,1)
        blip.shadowLeft:SetVertexColor(0,0,0,0.48)

        blip.shadowUp = blip:CreateTexture(nil,"ARTWORK")
        blip.shadowUp:SetPoint("CENTER", blip, "CENTER", 0, visualYOffset + 1)
        blip.shadowUp:SetSize(coreSize, coreSize)
        blip.shadowUp:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        blip.shadowUp:SetTexCoord(0,1,0,1)
        blip.shadowUp:SetVertexColor(0,0,0,0.48)

        blip.shadowDown = blip:CreateTexture(nil,"ARTWORK")
        blip.shadowDown:SetPoint("CENTER", blip, "CENTER", 0, visualYOffset - 1)
        blip.shadowDown:SetSize(coreSize, coreSize)
        blip.shadowDown:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        blip.shadowDown:SetTexCoord(0,1,0,1)
        blip.shadowDown:SetVertexColor(0,0,0,0.48)

        blip.texture = blip:CreateTexture(nil,"OVERLAY")
        blip.texture:SetPoint("CENTER", blip, "CENTER", 0, visualYOffset)
        blip.texture:SetSize(coreSize, coreSize)
        blip.texture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        blip.texture:SetTexCoord(0,1,0,1)
        blip.texture:SetVertexColor(1,1,1,1)
    else
        -- Honor NPCs use Blizzard's neutral silver/gray minimap vignette arrow.
        -- It is intentionally different from both world-map player assets and
        -- remains legible when scaled down while accepting faction tint cleanly.
        blip.texture = blip:CreateTexture(nil,"ARTWORK")
        blip.texture:SetPoint("CENTER", blip, "CENTER", 0, 0)
        blip.texture:SetSize(coreSize, coreSize)
        blip.texture:SetTexture("Interface\\MINIMAP\\MiniMap-VignetteArrow")
        blip.texture:SetTexCoord(0,1,0,1)
        blip.texture:SetVertexColor(r,g,b,1)
        blip.texture:SetBlendMode("BLEND")
    end
    blip:SetScript("OnEnter", function(self)
        info.routeHover = true
        ShowLieutenantTooltip(self, info, false)
    end)
    blip:SetScript("OnLeave", function()
        info.routeHover = false
        GameTooltip:Hide()
        ScheduleHidePath(info)
    end)
    blip:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ReportStatus(info)
        end
        -- Left-click targeting is owned by the secure overlay created below.
    end)
    info.blip = blip
    EnsureSecureTargetButton(info)
    UpdateBlip(info)
end

local function EnsurePopup()
    if LT.popup then return LT.popup end
    local popup = CreateFrame("Frame", "ZurkMapsAVLieutenantTestMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    popup:SetWidth(190)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(100)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:Hide()
    if popup.SetBackdrop then
        popup:SetBackdrop({
            bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true,tileSize=8,edgeSize=12,
            insets={left=3,right=3,top=3,bottom=3},
        })
        popup:SetBackdropColor(0.018,0.012,0.008,0.98)
        popup:SetBackdropBorderColor(0.84,0.56,0.31,0.98)
    end
    popup.title=popup:CreateFontString(nil,"OVERLAY")
    popup.title:SetFont("Fonts\\FRIZQT__.TTF",11,"")
    popup.title:SetTextColor(1.0,0.84,0.15,1)
    popup.title:SetPoint("TOPLEFT",popup,"TOPLEFT",10,-9)
    popup.rows={}
    for i=1,24 do
        local row=CreateFrame("Button",nil,popup)
        row:SetHeight(16)
        row:SetPoint("LEFT",popup,"LEFT",10,0)
        row:SetPoint("RIGHT",popup,"RIGHT",-10,0)
        row.text=row:CreateFontString(nil,"OVERLAY")
        row.text:SetFont("Fonts\\FRIZQT__.TTF",10,"")
        row.text:SetPoint("LEFT")
        row.text:SetJustifyH("LEFT")
        row:SetScript("OnEnter",function(self) self.text:SetTextColor(1,0.9,0.4,1) end)
        row:SetScript("OnLeave",function(self)
            if self.info then
                local rr,gg,bb=GetFactionColor(self.info)
                self.text:SetTextColor(rr,gg,bb,1)
            end
        end)
        row:Hide()
        popup.rows[i]=row
    end
    popup:SetScript("OnLeave",function(self)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25,function() if not self:IsMouseOver() then self:Hide() end end)
        end
    end)
    LT.popup=popup
    return popup
end

local function OpenTestMenu(owner, mode)
    local popup=EnsurePopup()
    popup:ClearAllPoints()
    popup:SetPoint("BOTTOMLEFT",owner,"TOPLEFT",0,3)
    local killMode = mode == "kill"
    popup.title:SetText(killMode and "Mark Honor NPC Dead" or "Restore Honor NPC")
    local choices={}
    for _,info in ipairs(LIEUTENANTS) do
        local dead=EnsureState(info).dead
        if (killMode and not dead) or ((not killMode) and dead) then choices[#choices+1]=info end
    end
    table.sort(choices,function(a,b)
        if a.faction~=b.faction then return a.faction=="Alliance" end
        return a.name<b.name
    end)
    for i,row in ipairs(popup.rows) do
        local info=choices[i]
        if info then
            row.info=info
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",popup,"TOPLEFT",10,-27-((i-1)*16))
            row:SetPoint("TOPRIGHT",popup,"TOPRIGHT",-10,-27-((i-1)*16))
            row.text:SetText(info.name)
            local r,g,b=GetFactionColor(info)
            row.text:SetTextColor(r,g,b,1)
            row:SetScript("OnClick",function()
                if killMode then
                    local changed = MarkDead(info,"dev",true)
                    if changed and IsEnemyHonorNPC(info) then
                        -- DEV-only visual test: use a representative honor value so the
                        -- floating +Honor animation can be tested without waiting for a real kill.
                        if C_Timer and C_Timer.After then
                            C_Timer.After(0.12,function() ShowHonorGainFloat(info,198) end)
                        else
                            ShowHonorGainFloat(info,198)
                        end
                    end
                else
                    RestoreAlive(info,"dev",true)
                end
                popup:Hide()
            end)
            row:Show()
        else
            row.info=nil
            row:Hide()
        end
    end
    local rows=math.max(1,#choices)
    popup:SetHeight(36+(rows*16))
    if #choices==0 then
        popup.title:SetText(killMode and "No living honor NPCs" or "No dead honor NPCs")
    end
    popup:Show()
end

local function CreateDevButton()
    if not LT.map or LT.devButton then return end
    local button=CreateFrame("Button",nil,LT.map,BackdropTemplateMixin and "BackdropTemplate" or nil)
    button:SetSize(92,18)
    button:SetPoint("TOPLEFT",LT.map,"TOPLEFT",7,-7)
    button:SetFrameLevel((LT.mapBorder and LT.mapBorder:GetFrameLevel() or LT.map:GetFrameLevel())+9)
    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true,tileSize=8,edgeSize=8,
            insets={left=2,right=2,top=2,bottom=2},
        })
        button:SetBackdropColor(0.018,0.012,0.008,0.97)
        button:SetBackdropBorderColor(0.84,0.56,0.31,0.98)
    end
    button.text=button:CreateFontString(nil,"OVERLAY")
    button.text:SetPoint("CENTER")
    button.text:SetFont("Fonts\\FRIZQT__.TTF",9,"")
    button.text:SetTextColor(1.0,0.84,0.15,1)
    button:RegisterForClicks("LeftButtonUp","RightButtonUp")
    button:SetScript("OnClick",function(self,mouseButton)
        if mouseButton=="RightButton" then OpenTestMenu(self,"restore") else OpenTestMenu(self,"kill") end
    end)
    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("DEV: Honor NPC State")
        GameTooltip:AddLine("Left-click: choose a living lieutenant/commander/captain/general to report dead.",0.82,0.82,0.82,true)
        GameTooltip:AddLine("Enemy NPCs also preview the +198 floating honor animation.",1.00,0.82,0.12,true)
        GameTooltip:AddLine("Right-click: choose a dead honor NPC to restore.",0.82,0.82,0.82,true)
        GameTooltip:AddLine("Test changes are synced to other Zurk Maps users in the same AV.",0.58,0.58,0.58,true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    LT.devButton=button
    UpdateDevButton()
end

local function HandlePotentialDeathAnnouncement(message)
    if type(message) ~= "string" or message == "" then return end
    local lower = string.lower(message)
    if not (string.find(lower, "slain", 1, true)
        or string.find(lower, "killed", 1, true)
        or string.find(lower, "defeated", 1, true)
        or string.find(lower, "has fallen", 1, true)) then
        return
    end
    for _, info in ipairs(LIEUTENANTS) do
        if string.find(lower, string.lower(info.name), 1, true) then
            MarkDead(info, "announcement", true)
            return
        end
    end
end

local function HandleAddonMessage(message)
    if type(message)~="string" then return end
    local op,rest=message:match("^([^:]+):?(.*)$")
    if op=="D" then
        local info=BY_ID[tonumber(rest)]
        if info then MarkDead(info,"sync",false) end
    elseif op=="R" or op=="A" then
        local info=BY_ID[tonumber(rest)]
        if info then RestoreAlive(info,"sync-alive",false) end
    elseif op=="Q" then
        SendSnapshot(true)
    elseif op=="S" then
        for idText in string.gmatch(rest or "","(%d+)") do
            local info=BY_ID[tonumber(idText)]
            if info then MarkDead(info,"snapshot",false) end
        end
    elseif op=="H" then
        local idText,hpText=rest:match("^(%d+):([%d%.%-]+)$")
        local info=BY_ID[tonumber(idText)]
        local hp=tonumber(hpText)
        if info and hp and hp == hp and hp >= 0 and hp <= 100 then
            if hp <= 0 then
                MarkDead(info,"sync-health",false)
            else
                local state=EnsureState(info)
                if not state.dead then
                    SetObservedHealth(info,hp,"sync-health",false)
                elseif state.source == "inferred" then
                    RestoreAlive(info,"sync-health-alive",false)
                    SetObservedHealth(info,hp,"sync-health",false)
                end
            end
        end
    elseif op=="P" then
        -- Legacy live-position packets are ignored; R5h+ keeps tracked NPC blips static.
        return
    end
end

function LT.Create(config)
    if LT.map then return LT end
    if type(config)~="table" or not config.map then return nil end
    LT.config=config
    LT.map=config.map
    LT.mapBorder=config.mapBorder
    LT.addonFrame=config.addonFrame

    if LT.addonFrame and LT.addonFrame.HookScript then
        LT.addonFrame:HookScript("OnShow", function() RefreshSecureTargetButtons() end)
        LT.addonFrame:HookScript("OnHide", function() RefreshSecureTargetButtons() end)
    end

    RegisterPrefix()
    for _,info in ipairs(LIEUTENANTS) do
        EnsureState(info)
        CreateBlip(info)
        BuildPathWidgets(info)
        UpdateBlip(info)
    end
    -- Production Zurk Maps build: no honor-NPC developer button.
    return LT
end

function LT.MarkDeadByID(id, source, shouldBroadcast)
    return MarkDead(BY_ID[tonumber(id)],source,shouldBroadcast)
end
function LT.RestoreByID(id, source, shouldBroadcast)
    return RestoreAlive(BY_ID[tonumber(id)],source,shouldBroadcast)
end
function LT.ResetAll()
    ResetAll("manual")
end
function LT.GetState(id)
    local info=BY_ID[tonumber(id)]
    return info and EnsureState(info) or nil
end

function LT.RefreshScale()
    LT.RefreshNativePositionGeometry()
    local inv = GetDisplayCompensation()
    for _, info in ipairs(LIEUTENANTS) do
        UpdateBlip(info)
        if info.pathWidgets then
            for _, widget in ipairs(info.pathWidgets) do
                if widget.button then widget.button:SetSize(11*inv,11*inv) end
                if widget.outline then widget.outline:SetSize(5.0*inv,5.0*inv) end
                if widget.core then widget.core:SetSize(2.3*inv,2.3*inv) end
            end
        end
    end
end

local eventFrame=CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
if eventFrame.RegisterEvent then
    pcall(eventFrame.RegisterEvent, eventFrame, "GROUP_ROSTER_UPDATE")
    pcall(eventFrame.RegisterEvent, eventFrame, "NAME_PLATE_UNIT_ADDED")
    pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_TARGET")
    pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_HEALTH")
    pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_HEALTH_FREQUENT")
    pcall(eventFrame.RegisterEvent, eventFrame, "CHAT_MSG_COMBAT_HONOR_GAIN")
    pcall(eventFrame.RegisterEvent, eventFrame, "CHAT_MSG_BG_SYSTEM_NEUTRAL")
    pcall(eventFrame.RegisterEvent, eventFrame, "CHAT_MSG_BG_SYSTEM_ALLIANCE")
    pcall(eventFrame.RegisterEvent, eventFrame, "CHAT_MSG_BG_SYSTEM_HORDE")
    pcall(eventFrame.RegisterEvent, eventFrame, "CHAT_MSG_MONSTER_YELL")
    pcall(eventFrame.RegisterEvent, eventFrame, "RAID_BOSS_EMOTE")
end

local function RunPeriodicMaintenance(step)
    if not IsInAlteracValley() then return end

    LT.syncElapsed = (LT.syncElapsed or 0) + step
    LT.scanElapsed = (LT.scanElapsed or 0) + step
    LT.healthScanElapsed = (LT.healthScanElapsed or 0) + step
    RefreshNPCHealthBars()

    -- Capping's AV health sharing works because it checks raid-member targets,
    -- not just units visible to the local player. Do the same once per second so
    -- a death seen through any raidXtarget becomes a Zurk Maps D: broadcast.
    if LT.healthScanElapsed >= 1.0 then
        LT.healthScanElapsed = 0
        ScanRaidObservedHonorNPCHealth()
    end

    -- Periodic dead-state snapshots make missed combat-log/addon packets converge
    -- for everyone in the same AV, including same-faction NPC deaths and late joiners.
    if LT.syncElapsed >= 5.0 then
        LT.syncElapsed = 0
        SendSnapshot()
    end

    if LT.scanElapsed >= 0.50 then
        LT.scanElapsed = 0
        ScanForAbsentTrackedNPCs()
    end
end

if C_Timer and type(C_Timer.NewTicker) == "function" then
    LT.maintenanceTicker = C_Timer.NewTicker(0.50, function()
        RunPeriodicMaintenance(0.50)
    end)
else
    eventFrame.updateElapsed = 0
    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        self.updateElapsed = self.updateElapsed + (elapsed or 0)
        if self.updateElapsed < 0.50 then return end
        local step = self.updateElapsed
        self.updateElapsed = 0
        RunPeriodicMaintenance(step)
    end)
end

-- Live NPC map-position probing removed; shared health/death is the live combat signal.

if C_Timer and type(C_Timer.NewTicker) == "function" then
    LT.combatPulseTicker = C_Timer.NewTicker(0.08, UpdateNPCCombatPulse)
end

eventFrame:SetScript("OnEvent",function(_,event,...)
    if event=="PLAYER_REGEN_ENABLED" then
        if LT.pendingSecureTargetButtons then RefreshSecureTargetButtons() end
        return
    end
    if event=="CHAT_MSG_COMBAT_HONOR_GAIN" then
        HandleHonorGainEvent(...)
        return
    end
    if event=="CHAT_MSG_BG_SYSTEM_NEUTRAL" or event=="CHAT_MSG_BG_SYSTEM_ALLIANCE"
        or event=="CHAT_MSG_BG_SYSTEM_HORDE" or event=="CHAT_MSG_MONSTER_YELL"
        or event=="RAID_BOSS_EMOTE" then
        if IsInAlteracValley() then HandlePotentialDeathAnnouncement(...) end
        return
    end

    if event=="COMBAT_LOG_EVENT_UNFILTERED" then
        if not IsInAlteracValley() or type(CombatLogGetCurrentEventInfo)~="function" then return end
        local _,subevent,_,_,_,_,_,destGUID,destName=CombatLogGetCurrentEventInfo()
        if subevent=="UNIT_DIED" or subevent=="PARTY_KILL" or subevent=="UNIT_DESTROYED" then
            local id=GetNPCIDFromGUID(destGUID)
            local info=id and BY_ID[id] or (destName and BY_NAME[NormalizeName(destName)] or nil)
            if info then MarkDead(info,"combat",true) end
        end
        return
    end

    if event=="CHAT_MSG_ADDON" then
        local prefix,message,channel=...
        if not IsInAlteracValley() then return end
        if prefix==PREFIX then
            HandleAddonMessage(message)
        elseif prefix==CAPPING_PREFIX and channel=="INSTANCE_CHAT" and type(message)=="string" then
            -- Passive Capping interoperability. Its AV health feed uses exactly
            -- "npcID:percent"; unrelated Capping timer packets do not match.
            local idText,hpText=message:match("^(%d+):([%d%.%-]+)$")
            local info=BY_ID[tonumber(idText)]
            local hp=tonumber(hpText)
            if info and hp and hp==hp and hp>=0 and hp<=100 then
                if hp<=0 then
                    SetObservedHealth(info,0,"capping-health",false)
                    MarkDead(info,"capping-health",false)
                else
                    local state=EnsureState(info)
                    if not state.dead then
                        SetObservedHealth(info,hp,"capping-health",false)
                    elseif state.source=="inferred" then
                        RestoreAlive(info,"capping-health-alive",false)
                        SetObservedHealth(info,hp,"capping-health",false)
                    end
                end
            end
        end
        return
    end

    if event=="PLAYER_TARGET_CHANGED" then
        if IsInAlteracValley() then
            ObserveUnit("target",true)
            ScanHealthUnit("target",true)
        end
        return
    end
    if event=="UNIT_TARGET" then
        local unit=...
        if IsInAlteracValley() and type(unit)=="string" and unit~="" then
            ScanHealthUnit(unit.."target",true)
        end
        return
    end
    if event=="UNIT_HEALTH" or event=="UNIT_HEALTH_FREQUENT" then
        local unit=...
        if IsInAlteracValley() and unit then ScanHealthUnit(unit,true) end
        return
    end
    if event=="UPDATE_MOUSEOVER_UNIT" then
        if IsInAlteracValley() then
            ObserveUnit("mouseover",true)
            ScanHealthUnit("mouseover",true)
        end
        return
    end
    if event=="NAME_PLATE_UNIT_ADDED" then
        local unit=...
        if IsInAlteracValley() and unit then
            ObserveUnit(unit,true)
            ScanHealthUnit(unit,true)
        end
        return
    end
    if event=="GROUP_ROSTER_UPDATE" then
        if IsInAlteracValley() then RequestSync() end
        return
    end

    local inAV=IsInAlteracValley()
    if inAV and not LT.wasInAV then
        LT.wasInAV=true
        LT.syncRequested=false
        ResetAll("new-match")
        if C_Timer and C_Timer.After then
            C_Timer.After(0.8,function()
                if IsInAlteracValley() then RequestSync(true); LT.syncRequested=true end
            end)
            C_Timer.After(3.0,function()
                if IsInAlteracValley() then RequestSync(true) end
            end)
        else
            RequestSync(true); LT.syncRequested=true
        end
    elseif not inAV and LT.wasInAV then
        -- AV NPC state is match-local. Clear deaths/observed positions immediately
        -- after leaving so the next AV can never inherit stale lieutenant state.
        ResetAll("leave")
        LT.wasInAV=false
        LT.syncRequested=false
    end
end)
