-- Shared friendly-player blip and featured PvP-rank support for Zurk Maps.
-- Battleground modules provide only their map/frame geometry and map ID.
ZurkMapsPlayerBlips = ZurkMapsPlayerBlips or {}

local PlayerBlips = ZurkMapsPlayerBlips

local DEFAULT_CLASS_COLORS = {
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

local FEATURED_TITLE_PREFIXES = {
    { "Grand Marshal ", 14 },
    { "High Warlord ", 14 },
    { "Field Marshal ", 13 },
    { "Warlord ", 13 },
    { "Marshal ", 12 },
    { "General ", 12 },
}

function PlayerBlips.GetClassColor(unit, fallbackColors)
    local _, classToken = UnitClass(unit)
    if not classToken then
        return 1, 1, 1
    end

    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if color then
        return color.r, color.g, color.b
    end

    local fallback = (fallbackColors and fallbackColors[classToken]) or DEFAULT_CLASS_COLORS[classToken]
    if fallback then
        return fallback[1], fallback[2], fallback[3]
    end

    return 1, 1, 1
end

function PlayerBlips.GetDotSize(baseSize, addonFrame)
    local addonScale = (addonFrame and addonFrame.GetScale and addonFrame:GetScale()) or 1
    local compensationScale = math.min(addonScale, 1)
    return baseSize / compensationScale
end

function PlayerBlips.ApplyRankBadge(blip, rankNumber, size)
    if not blip or not rankNumber then
        return
    end

    blip:SetSize(size, size)
    local rankTexture = string.format("Interface\\PvPRankBadges\\PvPRank%02d", rankNumber)
    if ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.HideEliteOverlay then
        ZurkMapsPlayerIcons.HideEliteOverlay(blip)
    end
    if blip.shadow then
        blip.shadow:SetTexture(rankTexture)
        blip.shadow:Show()
    end
    if blip.texture then
        blip.texture:SetTexture(rankTexture)
        blip.texture:SetTexCoord(0, 1, 0, 1)
        blip.texture:SetVertexColor(1, 1, 1, 1)
    end
end

function PlayerBlips.ApplyGoldBlip(blip, size, r, g, b)
    if not blip then
        return
    end

    if ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.HideEliteOverlay then
        ZurkMapsPlayerIcons.HideEliteOverlay(blip)
    end
    if blip.shadow then
        blip.shadow:Hide()
    end
    blip:SetSize(size, size)
    if blip.texture then
        blip.texture:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
        blip.texture:SetTexCoord(0, 1, 0, 1)
        blip.texture:SetVertexColor(r or 1, g or 0.82, b or 0.16, 1)
    end
end

function PlayerBlips.CreateRankController(config)
    local controller = {
        min = config.min or 12,
        max = config.max or 14,
        iconScale = config.iconScale or 0.924,
        cache = {},
        blips = {},
        appliedState = {},
        nativeSpecialAvailable = nil,
        nativeSpecialFrame = nil,
        nativeEliteBaseFrame = nil,
        nativeEliteFrame = nil,
        nativeShadowFrame = nil,
        eliteOverlays = {},
        inspectRanks = {},
        inspectAttempts = {},
        inspectRosterSeen = {},
        pendingInspect = nil,
        preGateScanStartedAt = nil,
        inspectPulseElapsed = 0,
        rosterUnits = {},
        inspectRosterUnits = {},
        seenGUIDs = {},
        eliteSeenGUIDs = {},
    }

    local pinSizes = {
        player = config.baseDotSize or 10,
        party = config.baseDotSize or 10,
        raid = config.baseDotSize or 10,
    }

    local dataProvider = {}
    function dataProvider:ShouldShowUnit(unit)
        return (pinSizes[unit] or 0) > 0
    end
    function dataProvider:EnumerateUnitPinSizes()
        return next, pinSizes
    end
    function dataProvider:GetUnitPinSizesTable()
        return pinSizes
    end
    controller.dataProvider = dataProvider

    function controller.GetRankNumber(unit)
        if not unit or not UnitExists(unit) then
            return nil
        end

        local guid = UnitGUID(unit)
        local now = (GetTime and GetTime()) or 0

        local inspectedRank = guid and controller.inspectRanks[guid] or nil
        if type(inspectedRank) == "number" and inspectedRank >= controller.min and inspectedRank <= controller.max then
            controller.cache[unit] = { guid = guid, checkedAt = now, rankNumber = inspectedRank }
            return inspectedRank
        end

        local cached = controller.cache[unit]
        if cached and cached.guid == guid and (now - cached.checkedAt) < 1.0 then
            return cached.rankNumber
        end

        local rankNumber = nil
        if type(UnitPVPRank) == "function" then
            local okRank, rankID = pcall(UnitPVPRank, unit)
            if okRank and type(rankID) == "number" and rankID > 0 then
                -- Classic's UnitPVPRank index starts at 5 for PvP Rank 1, so the
                -- conventional 1-14 rank number is rankID - 4. Use this directly
                -- first; it avoids relying on GetPVPRankInfo behavior for raid units.
                local classicRank = rankID - 4
                if classicRank >= controller.min and classicRank <= controller.max then
                    rankNumber = classicRank
                elseif type(GetPVPRankInfo) == "function" then
                    local okInfo, _, number = pcall(GetPVPRankInfo, rankID, unit)
                    if not okInfo then
                        okInfo, _, number = pcall(GetPVPRankInfo, rankID)
                    end
                    if okInfo and type(number) == "number" and number >= controller.min and number <= controller.max then
                        rankNumber = number
                    end
                end
            end
        end

        -- Last-resort Classic fallback. UnitPVPName includes the displayed PvP title
        -- and works for visible party/raid units even on clients where rank detail
        -- lookup is inconsistent for non-target unit tokens.
        if not rankNumber and type(UnitPVPName) == "function" then
            local okName, pvpName = pcall(UnitPVPName, unit)
            if okName and type(pvpName) == "string" then
                for _, entry in ipairs(FEATURED_TITLE_PREFIXES) do
                    if string.sub(pvpName, 1, #entry[1]) == entry[1] then
                        rankNumber = entry[2]
                        break
                    end
                end
            end
        end

        controller.cache[unit] = { guid = guid, checkedAt = now, rankNumber = rankNumber }
        return rankNumber
    end

    local function ClearTable(tbl)
        for key in pairs(tbl) do
            tbl[key] = nil
        end
        return tbl
    end

    local function FillRosterUnits(units, includePlayer)
        ClearTable(units)
        if includePlayer then
            units[#units + 1] = "player"
        end
        if IsInRaid and IsInRaid() then
            for i = 1, 40 do
                local unit = "raid" .. i
                if UnitExists(unit) then
                    units[#units + 1] = unit
                end
            end
        else
            for i = 1, 4 do
                local unit = "party" .. i
                if UnitExists(unit) then
                    units[#units + 1] = unit
                end
            end
        end
        return units
    end

    local function InspectFrameIsOpen()
        return InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()
    end

    local function CanProbeUnit(unit)
        if not unit or not UnitExists(unit) or (UnitIsUnit and UnitIsUnit(unit, "player")) then
            return false
        end
        if UnitIsConnected and not UnitIsConnected(unit) then
            return false
        end
        if UnitIsVisible and not UnitIsVisible(unit) then
            return false
        end
        if type(CanInspect) == "function" then
            local ok, canInspect = pcall(CanInspect, unit, false)
            if not ok or not canInspect then
                return false
            end
        end
        return true
    end

    function controller.IsPreGateRankScanActive()
        local friendlyFrame = config.getFriendlyFrame and config.getFriendlyFrame() or nil
        if not (config.isAvailable and config.isAvailable()) or not friendlyFrame or not friendlyFrame:IsShown() then
            controller.preGateScanStartedAt = nil
            return false
        end

        -- Never run the inspect queue merely because the map was manually shown
        -- outside a battleground.
        if type(IsInInstance) == "function" then
            local okInstance, inInstance, instanceType = pcall(IsInInstance)
            if okInstance and (not inInstance or instanceType ~= "pvp") then
                controller.preGateScanStartedAt = nil
                return false
            end
        end

        local now = (GetTime and GetTime()) or 0
        if not controller.preGateScanStartedAt then
            controller.preGateScanStartedAt = now
        end

        -- Scan for at most the normal two-minute staging window. If Classic exposes
        -- the live BG runtime, stop immediately when the gates open; this also means
        -- a player who joins late only scans for the remaining pre-gate time.
        if (now - controller.preGateScanStartedAt) > 125 then
            return false
        end
        if type(GetBattlefieldInstanceRunTime) == "function" then
            local ok, runtime = pcall(GetBattlefieldInstanceRunTime)
            if ok and type(runtime) == "number" and runtime > 0 then
                return false
            end
        end

        return true
    end

    function controller.HandleInspectHonorUpdate()
        local pending = controller.pendingInspect
        if not pending then return end
        if InspectFrameIsOpen() then
            -- Do not let a manual inspect steal/corrupt the background probe result.
            controller.pendingInspect = nil
            return
        end

        local unit = pending.unit
        local guid = pending.guid
        if not unit or not guid or not UnitExists(unit) or UnitGUID(unit) ~= guid then
            controller.pendingInspect = nil
            return
        end

        local lifetimeRank = nil
        if type(GetInspectHonorData) == "function" then
            local ok, _, _, _, _, _, _, _, _, _, _, _, rank = pcall(GetInspectHonorData)
            if ok and type(rank) == "number" then
                lifetimeRank = rank
            end
        end

        if lifetimeRank ~= nil then
            controller.inspectRanks[guid] = lifetimeRank
            controller.cache[unit] = nil
            controller.appliedState[unit] = nil
        end

        controller.pendingInspect = nil
        if type(ClearInspectPlayer) == "function" and not InspectFrameIsOpen() then
            pcall(ClearInspectPlayer)
        end

        if lifetimeRank ~= nil then
            controller.UpdateBlips()
        end
    end

    function controller.PulseRankInspection()
        if not controller.IsPreGateRankScanActive() then
            return
        end
        if InspectFrameIsOpen() then
            return
        end
        if type(NotifyInspect) ~= "function" or type(RequestInspectHonorData) ~= "function" then
            return
        end

        local now = (GetTime and GetTime()) or 0
        if controller.pendingInspect then
            if (now - (controller.pendingInspect.requestedAt or now)) < 2.5 then
                return
            end
            controller.pendingInspect = nil
            if type(ClearInspectPlayer) == "function" then
                pcall(ClearInspectPlayer)
            end
        end

        local units = FillRosterUnits(controller.inspectRosterUnits, false)
        local newest = nil
        local fallback = nil

        for _, unit in ipairs(units) do
            local guid = UnitGUID(unit)
            if guid then
                local firstSeen = not controller.inspectRosterSeen[guid]
                controller.inspectRosterSeen[guid] = true
                local alreadyKnown = controller.inspectRanks[guid] ~= nil
                local lastAttempt = controller.inspectAttempts[guid] or -999
                local retryReady = (now - lastAttempt) >= 9.0

                if not alreadyKnown and retryReady and CanProbeUnit(unit) then
                    if firstSeen then
                        newest = unit
                        break
                    elseif not fallback then
                        fallback = unit
                    end
                end
            end
        end

        local unit = newest or fallback
        if not unit then return end

        local guid = UnitGUID(unit)
        if not guid then return end

        controller.inspectAttempts[guid] = now
        controller.pendingInspect = { unit = unit, guid = guid, requestedAt = now }

        local okNotify = pcall(NotifyInspect, unit)
        if not okNotify then
            controller.pendingInspect = nil
            return
        end
        pcall(RequestInspectHonorData)
    end

    controller.inspectEventFrame = CreateFrame("Frame")
    controller.inspectEventFrame:RegisterEvent("INSPECT_HONOR_UPDATE")
    controller.inspectEventFrame:SetScript("OnEvent", function()
        controller.HandleInspectHonorUpdate()
    end)

    if C_Timer and type(C_Timer.NewTicker) == "function" then
        controller.inspectTicker = C_Timer.NewTicker(3.0, function()
            controller.PulseRankInspection()
        end)
    else
        controller.inspectPulseFrame = CreateFrame("Frame")
        controller.inspectPulseFrame:SetScript("OnUpdate", function(_, elapsed)
            controller.inspectPulseElapsed = controller.inspectPulseElapsed + elapsed
            if controller.inspectPulseElapsed < 3.0 then
                return
            end
            controller.inspectPulseElapsed = 0
            controller.PulseRankInspection()
        end)
    end

    local function ApplyUnitVisualState(unit, guid, rankNumber, assignedIcon)
        local state = controller.appliedState[unit]
        if not state then
            state = {}
            controller.appliedState[unit] = state
        end
        local rankValue = rankNumber or 0
        local iconValue = assignedIcon or 0
        if state.guid ~= guid or state.rankNumber ~= rankValue or state.assignedIcon ~= iconValue then
            state.guid = guid
            state.rankNumber = rankValue
            state.assignedIcon = iconValue
            controller.ColorFriendlyUnit(unit)
        end
    end

    function controller.ColorFriendlyUnit(unit)
        local friendlyFrame = config.getFriendlyFrame and config.getFriendlyFrame() or nil
        if not (config.isAvailable and config.isAvailable()) or not friendlyFrame or not UnitExists(unit) then
            return
        end

        local assignedIcon = ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForUnit
            and ZurkMapsPlayerIcons.GetAssignedIconForUnit(unit) or nil
        local isEliteOverlay = assignedIcon and (ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.IsOverlayOnlyIcon and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon))
        local hasReplacingAssignment = assignedIcon and not isEliteOverlay

        if isEliteOverlay then
            -- The dedicated Elite base+dragon native frames own the full composite.
            -- Hide the ordinary roster pin so unrelated special icons can never
            -- visually wedge between the gold dot and its dragon.
            pcall(friendlyFrame.SetUnitColor, friendlyFrame, unit, 1, 1, 1, 0)
            return
        end

        if hasReplacingAssignment or controller.GetRankNumber(unit) then
            pcall(friendlyFrame.SetUnitColor, friendlyFrame, unit, 1, 1, 1, 0)
            return
        end

        local r, g, b = 1, 0.82, 0.16
        if config.getClassColor then r, g, b = config.getClassColor(unit) end
        pcall(friendlyFrame.SetUnitColor, friendlyFrame, unit, r, g, b, 0.95)
    end

    function controller.GetUnitMapPosition(unit)
        if not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" or not config.getUiMapID then
            return nil, nil
        end

        local ok, position = pcall(C_Map.GetPlayerMapPosition, config.getUiMapID(), unit)
        if not ok or not position then
            return nil, nil
        end

        local x, y
        if type(position.GetXY) == "function" then
            local okXY, px, py = pcall(position.GetXY, position)
            if okXY then
                x, y = px, py
            end
        else
            x, y = position.x, position.y
        end

        if type(x) ~= "number" or type(y) ~= "number" then
            return nil, nil
        end
        return x, y
    end

    local function GetSpecialFrameLevel(friendlyFrame, offset)
        offset = tonumber(offset) or 0
        if config.getSpecialFrameLevel then
            local ok, level = pcall(config.getSpecialFrameLevel)
            level = ok and tonumber(level) or nil
            if level then return level + offset end
        end
        return (friendlyFrame and friendlyFrame:GetFrameLevel() or 0) + 4 + offset
    end

    function controller.GetOrCreateBlip(unit)
        local blip = controller.blips[unit]
        if blip then
            return blip
        end

        local friendlyFrame = config.getFriendlyFrame and config.getFriendlyFrame() or nil
        if not friendlyFrame then
            return nil
        end

        blip = CreateFrame("Frame", nil, friendlyFrame)
        if blip.SetFrameStrata and friendlyFrame.GetFrameStrata then blip:SetFrameStrata(friendlyFrame:GetFrameStrata()) end
        blip:SetFrameLevel(GetSpecialFrameLevel(friendlyFrame, 2))
        blip:EnableMouse(false)

        blip.shadow = blip:CreateTexture(nil, "ARTWORK")
        blip.shadow:SetPoint("TOPLEFT", blip, "TOPLEFT", -1, 1)
        blip.shadow:SetPoint("BOTTOMRIGHT", blip, "BOTTOMRIGHT", 1, -1)
        blip.shadow:SetTexCoord(0, 1, 0, 1)
        blip.shadow:SetVertexColor(0, 0, 0, 0.72)
        blip.shadow:Hide()

        blip.texture = blip:CreateTexture(nil, "OVERLAY")
        blip.texture:SetAllPoints()
        blip.texture:SetTexCoord(0, 1, 0, 1)
        blip:Hide()

        controller.blips[unit] = blip
        return blip
    end

    function controller.HideRankBlips()
        for _, blip in pairs(controller.blips) do
            blip:Hide()
        end
        controller.HideEliteOverlays()
        if controller.nativeSpecialFrame then controller.nativeSpecialFrame:Hide() end
        if controller.nativeEliteBaseFrame then controller.nativeEliteBaseFrame:Hide() end
        if controller.nativeEliteFrame then controller.nativeEliteFrame:Hide() end
        if controller.nativeShadowFrame then controller.nativeShadowFrame:Hide() end
    end

    function controller.EnsureNativeSpecialFrames()
        if controller.nativeSpecialAvailable ~= nil then
            return controller.nativeSpecialAvailable
        end

        local friendlyFrame = config.getFriendlyFrame and config.getFriendlyFrame() or nil
        if not friendlyFrame then
            controller.nativeSpecialAvailable = false
            return false
        end

        local okShadow, shadow = pcall(CreateFrame, "UnitPositionFrame", nil, friendlyFrame)
        local okSpecial, special = pcall(CreateFrame, "UnitPositionFrame", nil, friendlyFrame)
        local okEliteBase, eliteBase = pcall(CreateFrame, "UnitPositionFrame", nil, friendlyFrame)
        local okElite, elite = pcall(CreateFrame, "UnitPositionFrame", nil, friendlyFrame)
        if not okShadow or not shadow or not okSpecial or not special or not okEliteBase or not eliteBase or not okElite or not elite
            or type(shadow.AddUnit) ~= "function" or type(shadow.ClearUnits) ~= "function" or type(shadow.FinalizeUnits) ~= "function"
            or type(special.AddUnit) ~= "function" or type(special.ClearUnits) ~= "function" or type(special.FinalizeUnits) ~= "function"
            or type(eliteBase.AddUnit) ~= "function" or type(eliteBase.ClearUnits) ~= "function" or type(eliteBase.FinalizeUnits) ~= "function"
            or type(elite.AddUnit) ~= "function" or type(elite.ClearUnits) ~= "function" or type(elite.FinalizeUnits) ~= "function" then
            if shadow then shadow:Hide() end
            if special then special:Hide() end
            if eliteBase then eliteBase:Hide() end
            if elite then elite:Hide() end
            controller.nativeSpecialAvailable = false
            return false
        end

        shadow:SetAllPoints(friendlyFrame)
        special:SetAllPoints(friendlyFrame)
        eliteBase:SetAllPoints(friendlyFrame)
        -- Elite uses TWO dedicated native frames at the top of the player stack:
        -- a normal gold player dot immediately beneath its dragon. This keeps the
        -- composite together so another player's Raid Boss/rank/etc. icon cannot
        -- be drawn between the two pieces.
        local eliteOffsetX = (ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.eliteMapOffsetX) or 1
        local eliteOffsetY = (ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.eliteMapOffsetY) or 0
        elite:ClearAllPoints()
        elite:SetPoint("TOPLEFT", friendlyFrame, "TOPLEFT", eliteOffsetX, eliteOffsetY)
        elite:SetPoint("BOTTOMRIGHT", friendlyFrame, "BOTTOMRIGHT", eliteOffsetX, eliteOffsetY)
        if friendlyFrame.GetFrameStrata then
            local strata = friendlyFrame:GetFrameStrata()
            if shadow.SetFrameStrata then shadow:SetFrameStrata(strata) end
            if special.SetFrameStrata then special:SetFrameStrata(strata) end
            if eliteBase.SetFrameStrata then eliteBase:SetFrameStrata(strata) end
            if elite.SetFrameStrata then elite:SetFrameStrata(strata) end
        end
        shadow:SetFrameLevel(GetSpecialFrameLevel(friendlyFrame, 0))
        special:SetFrameLevel(GetSpecialFrameLevel(friendlyFrame, 1))
        eliteBase:SetFrameLevel(GetSpecialFrameLevel(friendlyFrame, 3))
        elite:SetFrameLevel(GetSpecialFrameLevel(friendlyFrame, 4))
        shadow:EnableMouse(false)
        special:EnableMouse(false)
        eliteBase:EnableMouse(false)
        elite:EnableMouse(false)
        pcall(shadow.SetUiMapID, shadow, config.getUiMapID and config.getUiMapID() or nil)
        pcall(special.SetUiMapID, special, config.getUiMapID and config.getUiMapID() or nil)
        pcall(eliteBase.SetUiMapID, eliteBase, config.getUiMapID and config.getUiMapID() or nil)
        pcall(elite.SetUiMapID, elite, config.getUiMapID and config.getUiMapID() or nil)
        controller.nativeShadowFrame = shadow
        controller.nativeSpecialFrame = special
        controller.nativeEliteBaseFrame = eliteBase
        controller.nativeEliteFrame = elite
        controller.nativeSpecialAvailable = true
        return true
    end

    function controller.GetSpecialTextureAndSize(unit, dotSize)
        local assignedIcon = ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForUnit
            and ZurkMapsPlayerIcons.GetAssignedIconForUnit(unit) or nil
        if assignedIcon and ZurkMapsPlayerIcons then
            if ZurkMapsPlayerIcons.IsOverlayOnlyIcon and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon) then
                -- Elite keeps the normal native gold player marker visible, while
                -- the dragon itself is ALSO positioned by UnitPositionFrame. Do not
                -- use a separately anchored coordinate overlay here: AV's calibrated
                -- UnitPositionFrame is the single source of truth for live position.
                local size = dotSize * (ZurkMapsPlayerIcons.eliteVisualScale or 1.50)
                return (ZurkMapsPlayerIcons.GetEliteAtlas and ZurkMapsPlayerIcons.GetEliteAtlas())
                    or "worldquest-questmarker-dragon", size, assignedIcon, nil
            end

            if ZurkMapsPlayerIcons.GetIconTexture then
                local texture = ZurkMapsPlayerIcons.GetIconTexture(assignedIcon)
                if texture then
                    local size = dotSize * (ZurkMapsPlayerIcons.manualIconScale or 0.84)
                    if tonumber(assignedIcon) == ZurkMapsPlayerIcons.RAID_BOSS_ICON_ID then
                        size = size * (ZurkMapsPlayerIcons.raidBossIconScale or 1.50)
                    end
                    return texture, size, assignedIcon, nil
                end
            end
        end

        local rankNumber = controller.GetRankNumber(unit)
        if rankNumber then
            return string.format("Interface\\PvPRankBadges\\PvPRank%02d", rankNumber), dotSize * controller.iconScale, nil, rankNumber
        end
        return nil, nil, nil, nil
    end

    function controller.GetOrCreateEliteOverlay(unit)
        local blip = controller.eliteOverlays[unit]
        if blip then
            return blip
        end

        local friendlyFrame = config.getFriendlyFrame and config.getFriendlyFrame() or nil
        if not friendlyFrame then
            return nil
        end

        blip = CreateFrame("Frame", nil, friendlyFrame)
        if blip.SetFrameStrata and friendlyFrame.GetFrameStrata then blip:SetFrameStrata(friendlyFrame:GetFrameStrata()) end
        blip:SetFrameLevel(GetSpecialFrameLevel(friendlyFrame, 3))
        blip:EnableMouse(false)
        blip.texture = blip:CreateTexture(nil, "OVERLAY")
        blip.texture:SetBlendMode("BLEND")
        blip:Hide()
        controller.eliteOverlays[unit] = blip
        return blip
    end

    function controller.HideEliteOverlays()
        for _, blip in pairs(controller.eliteOverlays) do
            blip:Hide()
        end
    end

    function controller.UpdateEliteOverlays(units, dotSize)
        controller.HideEliteOverlays()
        local friendlyFrame = config.getFriendlyFrame and config.getFriendlyFrame() or nil
        local mapFrame = config.getMapFrame and config.getMapFrame() or nil
        if not friendlyFrame then
            return
        end

        local frameWidth = friendlyFrame:GetWidth() or (mapFrame and mapFrame:GetWidth()) or config.mapWidth or 400
        local frameHeight = friendlyFrame:GetHeight() or (mapFrame and mapFrame:GetHeight()) or config.mapHeight or 400
        local seenGUIDs = ClearTable(controller.eliteSeenGUIDs)

        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                local assignedIcon = ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForUnit and ZurkMapsPlayerIcons.GetAssignedIconForUnit(unit) or nil
                if guid and not seenGUIDs[guid] and assignedIcon and ZurkMapsPlayerIcons
                    and ZurkMapsPlayerIcons.IsOverlayOnlyIcon and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon) then
                    local x, y = controller.GetUnitMapPosition(unit)
                    if x and y then
                        local blip = controller.GetOrCreateEliteOverlay(unit)
                        if blip then
                            local overlaySize = dotSize * (ZurkMapsPlayerIcons.eliteVisualScale or 1.55)
                            blip:SetSize(overlaySize, overlaySize)
                            blip.texture:ClearAllPoints()
                            blip.texture:SetAllPoints()
                            local atlasApplied = false
                            if blip.texture.SetAtlas then
                                atlasApplied = pcall(blip.texture.SetAtlas, blip.texture,
                                    ZurkMapsPlayerIcons.GetEliteAtlas and ZurkMapsPlayerIcons.GetEliteAtlas() or "worldquest-questmarker-dragon", false)
                            end
                            if atlasApplied then
                                blip.texture:SetVertexColor(1.00, 0.95, 0.26, 1.00)
                                blip:ClearAllPoints()
                                blip:SetPoint("CENTER", friendlyFrame, "TOPLEFT", x * frameWidth, -(y * frameHeight))
                                blip:Show()
                                seenGUIDs[guid] = true
                            else
                                blip:Hide()
                            end
                        end
                    end
                end
            end
        end
    end

    function controller.UpdateNativeSpecialBlips(units, seenGUIDs, dotSize)
        if not controller.EnsureNativeSpecialFrames() then
            return false
        end

        local special = controller.nativeSpecialFrame
        local eliteBase = controller.nativeEliteBaseFrame
        local elite = controller.nativeEliteFrame
        local shadow = controller.nativeShadowFrame
        pcall(special.SetUiMapID, special, config.getUiMapID and config.getUiMapID() or nil)
        pcall(eliteBase.SetUiMapID, eliteBase, config.getUiMapID and config.getUiMapID() or nil)
        pcall(elite.SetUiMapID, elite, config.getUiMapID and config.getUiMapID() or nil)
        pcall(shadow.SetUiMapID, shadow, config.getUiMapID and config.getUiMapID() or nil)
        pcall(special.ClearUnits, special)
        pcall(eliteBase.ClearUnits, eliteBase)
        pcall(elite.ClearUnits, elite)
        pcall(shadow.ClearUnits, shadow)

        local added = 0
        local eliteAdded = 0
        local specialAdded = 0
        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                if guid and not seenGUIDs[guid] then
                    local texture, size, assignedIcon, rankNumber = controller.GetSpecialTextureAndSize(unit, dotSize)
                ApplyUnitVisualState(unit, guid, rankNumber, assignedIcon)
                    if texture and size then
                        seenGUIDs[guid] = true
                        -- Native UnitPositionFrame positioning is the important part:
                        -- it uses exactly the same BG coordinate machinery as the gold blips.
                        if assignedIcon and ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.IsOverlayOnlyIcon
                            and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon) then
                            -- Render both pieces of Elite in adjacent, topmost native
                            -- frames. The base remains a normal-sized gold player dot.
                            pcall(eliteBase.AddUnit, eliteBase, unit, "Interface\\WorldMap\\WorldMapPartyIcon",
                                dotSize, dotSize, 1.00, 0.82, 0.16, 1, 1, false)
                            pcall(elite.AddUnit, elite, unit, texture, size, size, 1.00, 0.95, 0.26, 1, 1, false)
                            eliteAdded = eliteAdded + 1
                        else
                            pcall(shadow.AddUnit, shadow, unit, texture, size + 2, size + 2, 0, 0, 0, 0.72, 0, false)
                            pcall(special.AddUnit, special, unit, texture, size, size, 1, 1, 1, 1, 1, false)
                            specialAdded = specialAdded + 1
                        end
                        added = added + 1
                    end
                end
            end
        end

        pcall(shadow.FinalizeUnits, shadow)
        pcall(special.FinalizeUnits, special)
        pcall(eliteBase.FinalizeUnits, eliteBase)
        pcall(elite.FinalizeUnits, elite)
        shadow:SetShown(specialAdded > 0)
        special:SetShown(specialAdded > 0)
        eliteBase:SetShown(eliteAdded > 0)
        elite:SetShown(eliteAdded > 0)
        return true
    end

    function controller.UpdateFallbackBlips(units, seenGUIDs, dotSize)
        controller.HideRankBlips()
        local friendlyFrame = config.getFriendlyFrame and config.getFriendlyFrame() or nil
        local mapFrame = config.getMapFrame and config.getMapFrame() or nil
        local frameWidth = friendlyFrame:GetWidth() or (mapFrame and mapFrame:GetWidth()) or config.mapWidth or 400
        local frameHeight = friendlyFrame:GetHeight() or (mapFrame and mapFrame:GetHeight()) or config.mapHeight or 400

        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                local texture, size, assignedIcon, rankNumber = controller.GetSpecialTextureAndSize(unit, dotSize)
                    ApplyUnitVisualState(unit, guid, rankNumber, assignedIcon)
                if guid and not seenGUIDs[guid] and texture then
                    seenGUIDs[guid] = true
                    local x, y = controller.GetUnitMapPosition(unit)
                    if x and y then
                        local blip = controller.GetOrCreateBlip(unit)
                        if blip then
                            if assignedIcon and ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.ApplyAssignedIcon then
                                local assignedSize = dotSize * (ZurkMapsPlayerIcons.manualIconScale or 0.84)
                                if ZurkMapsPlayerIcons.IsOverlayOnlyIcon and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon) then
                                    assignedSize = dotSize
                                end
                                ZurkMapsPlayerIcons.ApplyAssignedIcon(blip, assignedIcon, assignedSize)
                            else
                                PlayerBlips.ApplyRankBadge(blip, rankNumber, size)
                            end
                            blip:ClearAllPoints()
                            blip:SetPoint("CENTER", friendlyFrame, "TOPLEFT", x * frameWidth, -(y * frameHeight))
                            blip:Show()
                        end
                    end
                end
            end
        end
    end

    function controller.UpdateBlips()
        local friendlyFrame = config.getFriendlyFrame and config.getFriendlyFrame() or nil
        if not (config.isAvailable and config.isAvailable()) or not friendlyFrame or not friendlyFrame:IsShown() then
            controller.HideRankBlips()
            return
        end

        local units = FillRosterUnits(controller.rosterUnits, true)
        local seenGUIDs = ClearTable(controller.seenGUIDs)
        local dotSize = config.getDotSize and config.getDotSize() or 10

        -- Prefer the native UnitPositionFrame:AddUnit path. It avoids separately
        -- calculating positions for special icons and keeps them locked to the
        -- exact same BG coordinates as Blizzard's live gold player blips.
        if controller.UpdateNativeSpecialBlips(units, seenGUIDs, dotSize) then
            -- Native special frames own ALL live special-player positioning,
            -- including Elite. Keep old coordinate-based Elite overlays hidden so
            -- there can never be a second, misaligned dragon fighting the native one.
            for _, blip in pairs(controller.blips) do blip:Hide() end
            controller.HideEliteOverlays()
            return
        end

        controller.UpdateFallbackBlips(units, seenGUIDs, dotSize)
        controller.UpdateEliteOverlays(units, dotSize)
    end

    return controller
end

ZurkMapsPlayerBlips.tooltipEliteOverlays = ZurkMapsPlayerBlips.tooltipEliteOverlays or {}

function ZurkMapsPlayerBlips.HideEliteTooltipOverlays()
    for _, icon in pairs(ZurkMapsPlayerBlips.tooltipEliteOverlays) do
        icon:Hide()
    end
end

local function GetOrCreateEliteTooltipOverlay(index)
    local icon = ZurkMapsPlayerBlips.tooltipEliteOverlays[index]
    if icon then return icon end

    icon = CreateFrame("Frame", nil, GameTooltip)
    icon:SetSize(20, 20)
    icon:SetFrameLevel(GameTooltip:GetFrameLevel() + 10)
    icon:EnableMouse(false)

    icon.gold = icon:CreateTexture(nil, "ARTWORK")
    icon.gold:SetPoint("CENTER", icon, "CENTER", 0, 0)
    icon.gold:SetSize(17, 17)
    icon.gold:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
    icon.gold:SetTexCoord(0, 1, 0, 1)
    icon.gold:SetVertexColor(1.00, 0.82, 0.16, 1.00)

    icon.elite = icon:CreateTexture(nil, "OVERLAY")
    icon.elite:SetPoint("CENTER", icon, "CENTER", 1, 0)
    icon.elite:SetSize(15, 15)
    icon.elite:SetBlendMode("BLEND")
    if icon.elite.SetAtlas then
        pcall(icon.elite.SetAtlas, icon.elite,
            (ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetEliteAtlas and ZurkMapsPlayerIcons.GetEliteAtlas()) or "worldquest-questmarker-dragon", false)
    end
    icon.elite:SetVertexColor(1.00, 0.95, 0.26, 1.00)

    icon:Hide()
    ZurkMapsPlayerBlips.tooltipEliteOverlays[index] = icon
    return icon
end

function ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays(records, isTest)
    -- Clear every prior overlay first. This table is sparse by tooltip line, so
    -- cleanup MUST use pairs() (not ipairs()) or stale Elite art can leak onto
    -- unrelated players farther down the tooltip.
    ZurkMapsPlayerBlips.HideEliteTooltipOverlays()
    if not records or not GameTooltip or not GameTooltip:IsShown() then return end

    local tooltipName = GameTooltip:GetName()
    if not tooltipName then return end

    for i, record in ipairs(records) do
        local assignedIcon
        if isTest then
            assignedIcon = ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForKey
                and record and record.iconKey and ZurkMapsPlayerIcons.GetAssignedIconForKey(record.iconKey, true) or nil
        else
            assignedIcon = ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForUnit
                and ZurkMapsPlayerIcons.GetAssignedIconForUnit(record) or nil
        end

        if assignedIcon and ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.IsOverlayOnlyIcon
            and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon) then
            local line = _G[tooltipName .. "TextLeft" .. i]
            if line then
                local icon = GetOrCreateEliteTooltipOverlay(i)
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", line, "LEFT", 0, 0)
                icon:Show()
            end
        end
    end
end

if GameTooltip and GameTooltip.HookScript and not ZurkMapsPlayerBlips.eliteTooltipHooked then
    ZurkMapsPlayerBlips.eliteTooltipHooked = true
    GameTooltip:HookScript("OnHide", ZurkMapsPlayerBlips.HideEliteTooltipOverlays)
end

-- Tooltip helpers used by both maps so a hovered friendly player's featured
-- rank/manual assignment is visible beside their class-colored name.
function ZurkMapsPlayerBlips.GetTooltipIconTagForUnit(unit, rankController)
    if not unit then return "" end

    local assignedIcon = ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForUnit
        and ZurkMapsPlayerIcons.GetAssignedIconForUnit(unit) or nil

    if assignedIcon and ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetIconTag then
        if ZurkMapsPlayerIcons.IsOverlayOnlyIcon and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon) then
            return (ZurkMapsPlayerIcons.GetStackedEliteTooltipTag and ZurkMapsPlayerIcons.GetStackedEliteTooltipTag(14)) or ""
        end
        return ZurkMapsPlayerIcons.GetIconTag(assignedIcon, 14)
    end

    local rankNumber = rankController and rankController.GetRankNumber and rankController.GetRankNumber(unit) or nil
    if rankNumber then
        return string.format([[|TInterface\PvPRankBadges\PvPRank%02d:14:14:0:0|t ]], rankNumber)
    end
    return ""
end

function ZurkMapsPlayerBlips.GetTooltipIconTagForTestPlayer(agent)
    if not agent then return "" end

    local assignedIcon = ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetAssignedIconForKey
        and agent.iconKey and ZurkMapsPlayerIcons.GetAssignedIconForKey(agent.iconKey, true) or nil
    if assignedIcon and ZurkMapsPlayerIcons and ZurkMapsPlayerIcons.GetIconTag then
        if ZurkMapsPlayerIcons.IsOverlayOnlyIcon and ZurkMapsPlayerIcons.IsOverlayOnlyIcon(assignedIcon) then
            return (ZurkMapsPlayerIcons.GetStackedEliteTooltipTag and ZurkMapsPlayerIcons.GetStackedEliteTooltipTag(14)) or ""
        end
        return ZurkMapsPlayerIcons.GetIconTag(assignedIcon, 14)
    end

    if agent.pvpRankNumber and agent.pvpRankNumber >= 12 and agent.pvpRankNumber <= 14 then
        return string.format([[|TInterface\PvPRankBadges\PvPRank%02d:14:14:0:0|t ]], agent.pvpRankNumber)
    end
    return ""
end
