-- Shared manual player-icon assignment UI for Zurk Maps. All real-player assignments persist until changed or cleared.
-- Custom-map/minimap assignment remains available outside supported battleground maps.
-- Stock unit-frame context menus are restricted to supported battlegrounds so normal-world target menus
-- are not polluted by an addon option that only has battleground-map meaning.
ZurkMapsPlayerIcons = ZurkMapsPlayerIcons or {}

local PlayerIcons = ZurkMapsPlayerIcons
PlayerIcons.buildTag = "R4P_IDENTITY_PERSISTENCE_20260830"

PlayerIcons.DEV_ALLOW_ANYWHERE = true
PlayerIcons.testAssignments = PlayerIcons.testAssignments or {}

-- SavedVariables are deliberately resolved dynamically rather than captured in
-- file-scope locals. WoW can replace a SavedVariables global as the addon finishes
-- loading; keeping a stale table reference makes assignments appear to work during
-- one session but never reach the table that is actually saved to disk.
local function GetPersistentStores()
    if type(ZurkMapsPlayerIconsDB) ~= "table" then ZurkMapsPlayerIconsDB = {} end
    if type(ZurkMapsPlayerIconsDB.assignments) ~= "table" then ZurkMapsPlayerIconsDB.assignments = {} end
    if type(ZurkMapsPlayerIconsDB.byGUID) ~= "table" then ZurkMapsPlayerIconsDB.byGUID = {} end
    if type(ZurkMapsPlayerIconsDB.byName) ~= "table" then ZurkMapsPlayerIconsDB.byName = {} end
    if type(ZurkMapsPlayerIconsDB.byShortName) ~= "table" then ZurkMapsPlayerIconsDB.byShortName = {} end

    -- Keep these public aliases current for compatibility/debugging, but never
    -- trust them as permanent references internally.
    PlayerIcons.persistentAssignments = ZurkMapsPlayerIconsDB.assignments
    PlayerIcons.persistentByGUID = ZurkMapsPlayerIconsDB.byGUID
    PlayerIcons.persistentByName = ZurkMapsPlayerIconsDB.byName
    PlayerIcons.persistentByShortName = ZurkMapsPlayerIconsDB.byShortName
    return ZurkMapsPlayerIconsDB, ZurkMapsPlayerIconsDB.assignments,
        ZurkMapsPlayerIconsDB.byGUID, ZurkMapsPlayerIconsDB.byName, ZurkMapsPlayerIconsDB.byShortName
end

PlayerIcons.manualIconScale = 0.84
PlayerIcons.raidBossIconScale = 1.50
PlayerIcons.eliteVisualScale = 1.20
-- The Elite dragon atlas is visually left-heavy. Nudge the native map dragon
-- one pixel right so its center sits over the underlying gold player marker,
-- matching the known-good tooltip composite.
PlayerIcons.eliteMapOffsetX = 1
PlayerIcons.eliteMapOffsetY = 0
PlayerIcons.menuRegistered = PlayerIcons.menuRegistered or false
PlayerIcons.minimapSnapshotRecords = nil

PlayerIcons.RAID_BOSS_ICON_ID = 9
PlayerIcons.ELITE_ICON_ID = 10
PlayerIcons.iconOptions = {
    { id = 9, name = "Raid Boss" },
    { id = 10, name = "Elite" },
    { id = 1, name = "Star" },
    { id = 2, name = "Circle" },
    { id = 3, name = "Diamond" },
    { id = 4, name = "Triangle" },
    { id = 5, name = "Moon" },
    { id = 6, name = "Square" },
    { id = 7, name = "Cross" },
    { id = 8, name = "Skull" },
}

function PlayerIcons.GetIconTexture(iconID)
    iconID = tonumber(iconID)
    if iconID == PlayerIcons.RAID_BOSS_ICON_ID then
        return "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
    end
    if iconID == PlayerIcons.ELITE_ICON_ID then
        return nil
    end
    if not iconID or iconID < 1 or iconID > 8 then
        return nil
    end
    return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. iconID
end

function PlayerIcons.GetEliteAtlas()
    return "worldquest-questmarker-dragon"
end

function PlayerIcons.GetGoldBlipTag(size)
    size = tonumber(size) or 14
    return string.format("|TInterface\\WorldMap\\WorldMapPartyIcon:%d:%d:0:0:0:0:0:1:0:1:255:210:40:255|t ", size, size)
end

function PlayerIcons.IsOverlayOnlyIcon(iconID)
    return tonumber(iconID) == PlayerIcons.ELITE_ICON_ID
end

function PlayerIcons.GetIconTag(iconID, size)
    iconID = tonumber(iconID)
    size = tonumber(size) or 14
    if iconID == PlayerIcons.ELITE_ICON_ID then
        if type(CreateAtlasMarkup) == "function" then
            return CreateAtlasMarkup(PlayerIcons.GetEliteAtlas(), size, size) .. " "
        end
        return "[Elite] "
    end
    local texture = PlayerIcons.GetIconTexture(iconID)
    if texture then
        return string.format("|T%s:%d:%d:0:0|t ", texture, size, size)
    end
    return ""
end

function PlayerIcons.GetStackedEliteTooltipTag(size)
    -- Reserve one icon-sized slot. The real gold blip + Elite dragon are layered
    -- over this exact tooltip line by ZurkMapsPlayerBlips.ApplyEliteTooltipOverlays().
    return "     "
end


function PlayerIcons.GetIconLabel(option)
    if not option then return "" end
    local tag = PlayerIcons.GetIconTag(option.id, 15)
    if tag and tag ~= "" then
        return tag .. option.name
    end
    return option.name
end

function PlayerIcons.IsInSupportedBattleground()
    local mapID = nil
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, result = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then mapID = result end
    end
    if mapID == 1460 or mapID == 1366 then
        return true
    end

    -- Fallback for cases where the battleground map API has not populated yet.
    local instanceName = nil
    if GetInstanceInfo then
        instanceName = GetInstanceInfo()
    end
    local realZone = GetRealZoneText and GetRealZoneText() or nil
    local zone = GetZoneText and GetZoneText() or nil
    return instanceName == "Warsong Gulch" or instanceName == "Arathi Basin" or instanceName == "Alterac Valley"
        or realZone == "Warsong Gulch" or realZone == "Arathi Basin" or realZone == "Alterac Valley"
        or zone == "Warsong Gulch" or zone == "Arathi Basin" or zone == "Alterac Valley"
end

function PlayerIcons.IsAssignmentUIAllowed()
    if PlayerIcons.DEV_ALLOW_ANYWHERE then
        return true
    end

    return PlayerIcons.IsInSupportedBattleground()
end

function PlayerIcons.NormalizePlayerName(name)
    name = tostring(name or "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" then return nil end
    return string.lower(name)
end

local function IsValidIconID(iconID)
    iconID = tonumber(iconID)
    return iconID and ((iconID >= 1 and iconID <= 8)
        or iconID == PlayerIcons.RAID_BOSS_ICON_ID
        or iconID == PlayerIcons.ELITE_ICON_ID)
end

local function AddUniqueValue(values, seen, value)
    if not value or value == "" or seen[value] then return end
    seen[value] = true
    values[#values + 1] = value
end

local function NormalizeGUID(guid)
    guid = tostring(guid or "")
    if guid == "" then return nil end
    if string.sub(guid, 1, 5) == "GUID:" then guid = string.sub(guid, 6) end
    if guid == "" then return nil end
    return guid
end

local function NormalizeNameAlias(name)
    name = PlayerIcons.NormalizePlayerName(name)
    if not name then return nil end
    if string.sub(name, 1, 5) == "name:" then name = string.sub(name, 6) end
    return name ~= "" and name or nil
end

local function GetUnitNameAliases(unit)
    local names, seen = {}, {}
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return names end

    local hasQualified = false
    local fullName = GetUnitName and GetUnitName(unit, true) or nil
    fullName = NormalizeNameAlias(fullName)
    if fullName then
        AddUniqueValue(names, seen, fullName)
        if string.find(fullName, "-", 1, true) then hasQualified = true end
    end

    if UnitFullName then
        local name, realm = UnitFullName(unit)
        name = NormalizeNameAlias(name)
        realm = NormalizeNameAlias(realm)
        if name and realm and realm ~= "" then
            AddUniqueValue(names, seen, name .. "-" .. realm)
            hasQualified = true
        elseif name and not hasQualified then
            AddUniqueValue(names, seen, name)
        end
    end

    -- Realm-less names are only a fallback when WoW did not expose a qualified
    -- name. GUID remains the canonical identity in every normal roster path.
    if not hasQualified then
        AddUniqueValue(names, seen, NormalizeNameAlias(UnitName and UnitName(unit) or nil))
    end
    return names
end

local function GetUnitShortNameAliases(unit)
    local names, seen = {}, {}
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return names end

    local shortName = NormalizeNameAlias(UnitName and UnitName(unit) or nil)
    if shortName then AddUniqueValue(names, seen, shortName) end

    if UnitFullName then
        local name = UnitFullName(unit)
        name = NormalizeNameAlias(name)
        if name then AddUniqueValue(names, seen, name) end
    end

    local fullName = GetUnitName and GetUnitName(unit, true) or nil
    fullName = NormalizeNameAlias(fullName)
    if fullName then
        local dash = string.find(fullName, "-", 1, true)
        if dash and dash > 1 then fullName = string.sub(fullName, 1, dash - 1) end
        AddUniqueValue(names, seen, fullName)
    end
    return names
end

local function NamesOverlap(left, right)
    local seen = {}
    for _, value in ipairs(left or {}) do
        value = NormalizeNameAlias(value)
        if value then seen[value] = true end
    end
    for _, value in ipairs(right or {}) do
        value = NormalizeNameAlias(value)
        if value and seen[value] then return true end
    end
    return false
end

local function FillGroupUnitsForIdentity()
    local units = { "player" }
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    return units
end

local function ResolveRecordToLiveUnit(record)
    if not record then return nil end
    local recordGUID = NormalizeGUID(record.guid)
    local recordNames = record.names or {}
    local recordShortNames = record.shortNames or {}

    local function matches(unit)
        if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
        local guid = NormalizeGUID(UnitGUID(unit))
        if recordGUID and guid then return guid == recordGUID end
        if NamesOverlap(recordNames, GetUnitNameAliases(unit)) then return true end
        if #recordShortNames > 0 and NamesOverlap(recordShortNames, GetUnitShortNameAliases(unit)) then return true end
        return false
    end

    if matches(record.unit) then return record.unit end
    for _, unit in ipairs(FillGroupUnitsForIdentity()) do
        if matches(unit) then return unit end
    end
    return nil
end

local function RehydrateRecordIdentity(record)
    if not record or record.isTest then return record end
    local unit = ResolveRecordToLiveUnit(record)
    if not unit then return record end
    record.unit = unit
    record.guid = NormalizeGUID(UnitGUID(unit)) or record.guid
    record.names = GetUnitNameAliases(unit)
    record.shortNames = GetUnitShortNameAliases(unit)
    if record.guid then
        record.key = "GUID:" .. record.guid
    elseif record.names and record.names[1] then
        record.key = "NAME:" .. record.names[1]
    end
    record.aliasKeys = {}
    for _, alias in ipairs(record.names or {}) do record.aliasKeys[#record.aliasKeys + 1] = "NAME:" .. alias end
    return record
end

local function MirrorLegacyKey(key, iconID)
    if not key then return end
    local _, assignments = GetPersistentStores()
    if IsValidIconID(iconID) then
        assignments[key] = tonumber(iconID)
    else
        assignments[key] = nil
    end
end

local function StorePersistentIdentity(guid, names, iconID, shortNames)
    iconID = IsValidIconID(iconID) and tonumber(iconID) or nil
    guid = NormalizeGUID(guid)
    names = names or {}
    shortNames = shortNames or {}
    local db, assignments, byGUID, byName, byShortName = GetPersistentStores()

    -- Remove raw/mixed legacy aliases before writing canonical keys. Otherwise a
    -- cleared icon can be resurrected later by the compatibility lookup path.
    local normalizedNames = {}
    local nameSet = {}
    for _, name in ipairs(names) do
        name = NormalizeNameAlias(name)
        if name and not nameSet[name] then
            nameSet[name] = true
            normalizedNames[#normalizedNames + 1] = name
        end
    end
    for key in pairs(assignments) do
        if type(key) == "string" then
            local remove = false
            if guid and (key == guid or key == ("GUID:" .. guid)) then
                remove = true
            else
                local candidate = key
                if string.sub(candidate, 1, 5) == "NAME:" or string.sub(candidate, 1, 5) == "name:" then
                    candidate = string.sub(candidate, 6)
                end
                candidate = NormalizeNameAlias(candidate)
                if candidate and nameSet[candidate] then remove = true end
            end
            if remove then assignments[key] = nil end
        end
    end

    if guid then
        byGUID[guid] = iconID
        MirrorLegacyKey("GUID:" .. guid, iconID)
        if type(db.raidBossPlayers) == "table" then
            db.raidBossPlayers[guid] = nil
            db.raidBossPlayers["GUID:" .. guid] = nil
        end
    end
    for _, name in ipairs(normalizedNames) do
        byName[name] = iconID
        MirrorLegacyKey("NAME:" .. name, iconID)
        if type(db.raidBossPlayers) == "table" then
            db.raidBossPlayers[name] = nil
            db.raidBossPlayers["NAME:" .. name] = nil
        end
    end

    -- Realm formatting is not always identical across every Classic roster path.
    -- Keep a GUID-tied short-name index as a SAFE fallback: the same short name
    -- on another realm cannot steal this assignment because lookup also requires
    -- the current player's GUID.
    if guid then
        for _, shortName in ipairs(shortNames) do
            shortName = NormalizeNameAlias(shortName)
            if shortName then
                local bucket = byShortName[shortName]
                if type(bucket) ~= "table" then bucket = {}; byShortName[shortName] = bucket end
                bucket[guid] = iconID
                if not next(bucket) then byShortName[shortName] = nil end
            end
        end
    end
end

local function ReadLegacyKey(key)
    if not key then return nil end
    local _, assignments = GetPersistentStores()
    local value = tonumber(assignments[key])
    return IsValidIconID(value) and value or nil
end

local function ResolvePersistentIdentity(guid, names, shortNames)
    guid = NormalizeGUID(guid)
    names = names or {}
    shortNames = shortNames or {}
    local iconID = nil

    local _, _, byGUID, byName, byShortName = GetPersistentStores()
    if guid then
        local value = tonumber(byGUID[guid])
        if IsValidIconID(value) then iconID = value end
    end

    if not iconID then
        for _, name in ipairs(names) do
            name = NormalizeNameAlias(name)
            local value = name and tonumber(byName[name]) or nil
            if IsValidIconID(value) then iconID = value break end
        end
    end

    if not iconID and guid then
        for _, shortName in ipairs(shortNames) do
            shortName = NormalizeNameAlias(shortName)
            local bucket = shortName and byShortName[shortName] or nil
            local value = type(bucket) == "table" and tonumber(bucket[guid]) or nil
            if IsValidIconID(value) then iconID = value break end
        end
    end

    -- Compatibility with every prior SavedVariables shape. Any hit is immediately
    -- healed into the canonical GUID/name stores so it remains stable thereafter.
    if not iconID and guid then iconID = ReadLegacyKey("GUID:" .. guid) or ReadLegacyKey(guid) end
    if not iconID then
        for _, name in ipairs(names) do
            name = NormalizeNameAlias(name)
            if name then
                iconID = ReadLegacyKey("NAME:" .. name) or ReadLegacyKey(name)
                if iconID then break end
            end
        end
    end

    if iconID then StorePersistentIdentity(guid, names, iconID, shortNames) end
    return iconID
end

-- Additive migration from every older persistence shape. This is idempotent and
-- runs against the CURRENT SavedVariables table, not a file-load-time snapshot.
local function MigratePersistentStorage()
    local db, assignments = GetPersistentStores()
    if tonumber(db.assignmentSchemaVersion) == 5 then return end

    local legacyEntries = {}
    if type(db.raidBossPlayers) == "table" then
        for key, remembered in pairs(db.raidBossPlayers) do
            if remembered and type(key) == "string" then
                legacyEntries[#legacyEntries + 1] = { key = key, iconID = PlayerIcons.RAID_BOSS_ICON_ID }
            end
        end
    end
    for key, iconID in pairs(assignments) do
        if IsValidIconID(iconID) and type(key) == "string" then
            legacyEntries[#legacyEntries + 1] = { key = key, iconID = tonumber(iconID) }
        end
    end

    -- Raid-Boss-only memory was collected first; unified assignments appear later
    -- and therefore win when an old build contains both forms for one player.
    for _, entry in ipairs(legacyEntries) do
        local key, iconID = entry.key, entry.iconID
        if string.sub(key, 1, 5) == "GUID:" then
            StorePersistentIdentity(string.sub(key, 6), nil, iconID)
        elseif string.sub(key, 1, 5) == "NAME:" then
            StorePersistentIdentity(nil, { string.sub(key, 6) }, iconID)
        elseif string.match(key, "^Player%-%d+%-.+") then
            StorePersistentIdentity(key, nil, iconID)
        else
            StorePersistentIdentity(nil, { key }, iconID)
        end
    end
    -- All Raid-Boss-only memory has now been folded into the unified assignment
    -- stores; dropping the legacy table prevents a cleared assignment resurfacing.
    db.raidBossPlayers = nil
    db.assignmentSchemaVersion = 5
end

local function EnsurePersistentStorage()
    GetPersistentStores()
    MigratePersistentStorage()
end

function PlayerIcons.GetUnitGUIDKey(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local guid = NormalizeGUID(UnitGUID(unit))
    return guid and ("GUID:" .. guid) or nil
end

function PlayerIcons.GetUnitNameKeys(unit)
    local keys = {}
    for _, name in ipairs(GetUnitNameAliases(unit)) do keys[#keys + 1] = "NAME:" .. name end
    return keys
end

function PlayerIcons.GetUnitNameKey(unit)
    local keys = PlayerIcons.GetUnitNameKeys(unit)
    return keys[1]
end

function PlayerIcons.GetUnitAssignmentKeys(unit)
    local keys = {}
    local guidKey = PlayerIcons.GetUnitGUIDKey(unit)
    if guidKey then keys[#keys + 1] = guidKey end
    for _, key in ipairs(PlayerIcons.GetUnitNameKeys(unit)) do keys[#keys + 1] = key end
    return keys
end

function PlayerIcons.GetUnitKey(unit)
    local keys = PlayerIcons.GetUnitAssignmentKeys(unit)
    return keys[1]
end

function PlayerIcons.GetAssignedIconForKey(key, isTest)
    if not key then return nil end
    if not isTest then EnsurePersistentStorage() end
    if isTest then
        local value = tonumber(PlayerIcons.testAssignments[key])
        return IsValidIconID(value) and value or nil
    end

    if string.sub(key, 1, 5) == "GUID:" then
        return ResolvePersistentIdentity(string.sub(key, 6), nil)
    elseif string.sub(key, 1, 5) == "NAME:" then
        return ResolvePersistentIdentity(nil, { string.sub(key, 6) })
    elseif string.match(key, "^Player%-%d+%-.+") then
        return ResolvePersistentIdentity(key, nil)
    end
    return ResolvePersistentIdentity(nil, { key })
end

function PlayerIcons.GetAssignedIconForUnit(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    EnsurePersistentStorage()
    return ResolvePersistentIdentity(UnitGUID(unit), GetUnitNameAliases(unit), GetUnitShortNameAliases(unit))
end

function PlayerIcons.AssignKey(key, iconID, isTest)
    if not key then return end
    if not isTest then EnsurePersistentStorage() end
    if isTest then
        PlayerIcons.testAssignments[key] = IsValidIconID(iconID) and tonumber(iconID) or nil
        return
    end

    if string.sub(key, 1, 5) == "GUID:" then
        StorePersistentIdentity(string.sub(key, 6), nil, iconID)
    elseif string.sub(key, 1, 5) == "NAME:" then
        StorePersistentIdentity(nil, { string.sub(key, 6) }, iconID)
    elseif string.match(key, "^Player%-%d+%-.+") then
        StorePersistentIdentity(key, nil, iconID)
    else
        StorePersistentIdentity(nil, { key }, iconID)
    end
end

function PlayerIcons.GetAssignedIconForRecord(record)
    if not record then return nil end
    if not record.isTest then EnsurePersistentStorage() end
    if record.isTest then return PlayerIcons.GetAssignedIconForKey(record.key, true) end
    RehydrateRecordIdentity(record)

    local names = record.names or {}
    if #names == 0 and record.aliasKeys then
        for _, key in ipairs(record.aliasKeys) do
            if type(key) == "string" and string.sub(key, 1, 5) == "NAME:" then
                names[#names + 1] = string.sub(key, 6)
            end
        end
    end
    local guid = record.guid
    if not guid and type(record.key) == "string" and string.sub(record.key, 1, 5) == "GUID:" then
        guid = string.sub(record.key, 6)
    end
    return ResolvePersistentIdentity(guid, names, record.shortNames)
        or PlayerIcons.GetAssignedIconForKey(record.key, false)
end

function PlayerIcons.AssignRecord(record, iconID)
    if not record then return end
    if not record.isTest then EnsurePersistentStorage() end
    if record.isTest then
        PlayerIcons.AssignKey(record.key, iconID, true)
        return
    end

    -- The context menu can stay open while raid unit tokens are recycled. Resolve
    -- the captured player back to the live roster before saving so we never turn a
    -- temporary/missing GUID into a fragile name-only assignment.
    RehydrateRecordIdentity(record)
    local names = record.names or {}
    if #names == 0 and record.aliasKeys then
        for _, key in ipairs(record.aliasKeys) do
            if type(key) == "string" and string.sub(key, 1, 5) == "NAME:" then
                names[#names + 1] = string.sub(key, 6)
            end
        end
    end
    local guid = record.guid
    if not guid and type(record.key) == "string" and string.sub(record.key, 1, 5) == "GUID:" then
        guid = string.sub(record.key, 6)
    end
    StorePersistentIdentity(guid, names, iconID, record.shortNames)
end

function PlayerIcons.HideEliteOverlay(blip)
    if blip and blip.eliteOverlay then
        blip.eliteOverlay:Hide()
    end
end

function PlayerIcons.ApplyEliteOverlay(blip, size)
    if not blip then return end
    -- Elite is an embellishment, not a replacement marker: keep a normal-sized
    -- gold player blip and layer the dragon around it.
    local baseSize = size or 10
    if blip.SetSize then blip:SetSize(baseSize, baseSize) end
    if blip.shadow then blip.shadow:Hide() end
    if blip.texture then
        blip.texture:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
        blip.texture:SetTexCoord(0, 1, 0, 1)
        blip.texture:SetVertexColor(1.00, 0.82, 0.16, 1)
    end

    local overlay = blip.eliteOverlay
    if not overlay then
        overlay = blip:CreateTexture(nil, "OVERLAY", nil, 7)
        overlay:SetBlendMode("BLEND")
        blip.eliteOverlay = overlay
    end
    local overlaySize = baseSize * (PlayerIcons.eliteVisualScale or 1.50)
    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", blip, "CENTER", 0, 0)
    overlay:SetSize(overlaySize, overlaySize)
    local atlasApplied = false
    if overlay.SetAtlas then
        atlasApplied = pcall(overlay.SetAtlas, overlay, PlayerIcons.GetEliteAtlas(), false)
    end
    if atlasApplied then
        -- Match the known-good WSG/AB Elite dragon gold.
        overlay:SetVertexColor(1.00, 0.95, 0.26, 1.00)
        overlay:Show()
    else
        overlay:Hide()
    end
end

function PlayerIcons.ApplyAssignedIcon(blip, iconID, size)
    if not blip then return end
    iconID = tonumber(iconID)

    if iconID == PlayerIcons.ELITE_ICON_ID then
        PlayerIcons.ApplyEliteOverlay(blip, size)
        return
    end

    PlayerIcons.HideEliteOverlay(blip)

    local texture = PlayerIcons.GetIconTexture(iconID)
    if not texture then return end

    if iconID == PlayerIcons.RAID_BOSS_ICON_ID then
        size = size * (PlayerIcons.raidBossIconScale or 1.50)
    end

    if blip.shadow then
        blip.shadow:SetTexture(texture)
        blip.shadow:SetTexCoord(0, 1, 0, 1)
        blip.shadow:SetVertexColor(0, 0, 0, 0.72)
        blip.shadow:Show()
    end

    blip:SetSize(size, size)
    if blip.texture then
        blip.texture:SetTexture(texture)
        blip.texture:SetTexCoord(0, 1, 0, 1)
        blip.texture:SetVertexColor(1, 1, 1, 1)
    end
end

function PlayerIcons.MakeUnitRecord(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local guid = NormalizeGUID(UnitGUID(unit))
    local names = GetUnitNameAliases(unit)
    local shortNames = GetUnitShortNameAliases(unit)
    local key = guid and ("GUID:" .. guid) or (names[1] and ("NAME:" .. names[1]) or nil)
    if not key then return nil end
    local name = (GetUnitName and GetUnitName(unit, true)) or UnitName(unit) or unit
    local _, classToken = UnitClass(unit)
    local aliasKeys = {}
    for _, alias in ipairs(names) do aliasKeys[#aliasKeys + 1] = "NAME:" .. alias end
    return {
        key = key,
        guid = guid,
        names = names,
        shortNames = shortNames,
        aliasKeys = aliasKeys,
        name = name,
        classToken = classToken,
        unit = unit,
        isTest = false,
    }
end

function PlayerIcons.MakeTestRecord(agent)
    if not agent or not agent.iconKey then return nil end
    return {
        key = agent.iconKey,
        name = agent.name or "Test Player",
        classToken = agent.classToken,
        isTest = true,
    }
end

function PlayerIcons.GetColoredName(record)
    local name = (record and record.name) or "Player"
    local classToken = record and record.classToken
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if not color then return name end
    local r = math.floor((color.r or 1) * 255 + 0.5)
    local g = math.floor((color.g or 1) * 255 + 0.5)
    local b = math.floor((color.b or 1) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", r, g, b, name)
end


function PlayerIcons.PopulateIconOptions(parentDescription, record)
    if not parentDescription or not record or not record.key then return end

    for _, option in ipairs(PlayerIcons.iconOptions) do
        local optionID = option.id
        parentDescription:CreateRadio(
            PlayerIcons.GetIconLabel(option),
            function()
                return PlayerIcons.GetAssignedIconForRecord(record) == optionID
            end,
            function()
                PlayerIcons.AssignRecord(record, optionID)
            end
        )
    end

    parentDescription:CreateDivider()
    parentDescription:CreateButton("Clear Icon", function()
        PlayerIcons.AssignRecord(record, nil)
    end)

end

function PlayerIcons.AddAssignIconSubmenu(rootDescription, record)
    if not rootDescription or not record then return end
    local assignDescription = rootDescription:CreateButton("Assign Icon", function() end)
    PlayerIcons.PopulateIconOptions(assignDescription, record)
end

function PlayerIcons.OpenAssignmentMenuForRecords(owner, records)
    if not PlayerIcons.IsAssignmentUIAllowed() or not records or #records == 0 then
        return false
    end
    if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then
        return false
    end

    local snapshot = {}
    for _, record in ipairs(records) do
        if record and record.key then
            local names, shortNames, aliasKeys = {}, {}, {}
            for _, value in ipairs(record.names or {}) do names[#names + 1] = value end
            for _, value in ipairs(record.shortNames or {}) do shortNames[#shortNames + 1] = value end
            for _, value in ipairs(record.aliasKeys or {}) do aliasKeys[#aliasKeys + 1] = value end
            snapshot[#snapshot + 1] = {
                key = record.key,
                guid = record.guid,
                names = names,
                shortNames = shortNames,
                aliasKeys = aliasKeys,
                name = record.name,
                classToken = record.classToken,
                unit = record.unit,
                isTest = record.isTest,
            }
        end
    end
    if #snapshot == 0 then return false end

    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(owner or UIParent, function(_, rootDescription)
        rootDescription:CreateTitle("Assign Icon")
        -- Each captured player is its own submenu row, so hovering the name/arrow
        -- reveals the icon choices. This mirrors the intended minimap workflow.
        for _, record in ipairs(snapshot) do
            local playerDescription = rootDescription:CreateButton(PlayerIcons.GetColoredName(record), function() end)
            PlayerIcons.PopulateIconOptions(playerDescription, record)
        end
    end)
    return true
end

function PlayerIcons.OpenAssignmentMenuForUnits(owner, units)
    if not units then return false end
    local records, seen = {}, {}
    for _, unit in ipairs(units) do
        local record = PlayerIcons.MakeUnitRecord(unit)
        if record and not seen[record.key] then
            seen[record.key] = true
            records[#records + 1] = record
        end
    end
    return PlayerIcons.OpenAssignmentMenuForRecords(owner, records)
end

function PlayerIcons.OpenAssignmentMenuForTestPlayers(owner, agents)
    if not agents then return false end
    local records = {}
    for _, agent in ipairs(agents) do
        local record = PlayerIcons.MakeTestRecord(agent)
        if record then records[#records + 1] = record end
    end
    return PlayerIcons.OpenAssignmentMenuForRecords(owner, records)
end

function PlayerIcons.ShouldShowForUnit(unit)
    return PlayerIcons.IsInSupportedBattleground()
        and unit
        and UnitExists(unit)
        and UnitIsPlayer(unit)
        and UnitIsFriend("player", unit)
end

function PlayerIcons.ModifyUnitMenu(_, rootDescription, contextData)
    local unit = contextData and contextData.unit
    if not PlayerIcons.ShouldShowForUnit(unit) then return end
    local record = PlayerIcons.MakeUnitRecord(unit)
    if not record then return end
    PlayerIcons.AddAssignIconSubmenu(rootDescription, record)
end

function PlayerIcons.TryRegisterUnitMenus()
    if PlayerIcons.menuRegistered then return true end
    if not Menu or type(Menu.ModifyMenu) ~= "function" then return false end

    local tags = {
        "MENU_UNIT_SELF",
        "MENU_UNIT_PLAYER",
        "MENU_UNIT_PARTY",
        "MENU_UNIT_RAID",
        "MENU_UNIT_RAID_PLAYER",
        "MENU_UNIT_TARGET",
        "MENU_UNIT_FOCUS",
    }
    for _, tag in ipairs(tags) do
        Menu.ModifyMenu(tag, PlayerIcons.ModifyUnitMenu)
    end
    PlayerIcons.menuRegistered = true
    return true
end

function PlayerIcons.GetGroupUnitsFromTooltip()
    if not PlayerIcons.IsAssignmentUIAllowed() or not GameTooltip or not GameTooltip:IsShown() then
        return nil
    end

    local tooltipTexts = {}
    local tooltipName = GameTooltip:GetName()
    local lineCount = GameTooltip.NumLines and GameTooltip:NumLines() or 0
    if tooltipName then
        for i = 1, lineCount do
            local line = _G[tooltipName .. "TextLeft" .. i]
            local text = line and line:GetText()
            if text and text ~= "" then tooltipTexts[text] = true end
        end
    end
    if not next(tooltipTexts) then return nil end

    -- Include the local player explicitly. Party unit tokens exclude self, while raid
    -- tokens may include self; the GUID de-duplication below handles either case.
    local units = { "player" }
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end

    local records, seen = {}, {}
    for _, unit in ipairs(units) do
        if UnitExists(unit) and UnitIsPlayer(unit) and UnitIsFriend("player", unit) then
            local shortName = UnitName(unit)
            local fullName = (GetUnitName and GetUnitName(unit, true)) or shortName
            if (shortName and tooltipTexts[shortName]) or (fullName and tooltipTexts[fullName]) then
                local record = PlayerIcons.MakeUnitRecord(unit)
                if record and not seen[record.key] then
                    seen[record.key] = true
                    records[#records + 1] = record
                end
            end
        end
    end

    return #records > 0 and records or nil
end

function PlayerIcons.HealVisibleRosterAssignments()
    local function heal(unit)
        if unit and UnitExists(unit) and UnitIsPlayer(unit) then
            PlayerIcons.GetAssignedIconForUnit(unit)
        end
    end

    heal("player")
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do heal("raid" .. i) end
    else
        for i = 1, 4 do heal("party" .. i) end
    end
end

function PlayerIcons.SetupMinimapHook()
    if PlayerIcons.minimapHooked or not Minimap or not Minimap.HookScript then return end
    PlayerIcons.minimapHooked = true

    Minimap:HookScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            PlayerIcons.minimapSnapshotRecords = PlayerIcons.GetGroupUnitsFromTooltip()
        end
    end)

    Minimap:HookScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" then return end
        local records = PlayerIcons.minimapSnapshotRecords
        PlayerIcons.minimapSnapshotRecords = nil
        if not records or #records == 0 then return end

        local function openMenu()
            PlayerIcons.OpenAssignmentMenuForRecords(self, records)
        end
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, openMenu)
        else
            openMenu()
        end
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "ZurkMaps" then
        EnsurePersistentStorage()
    end
    PlayerIcons.TryRegisterUnitMenus()
    PlayerIcons.SetupMinimapHook()
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        EnsurePersistentStorage()
        PlayerIcons.HealVisibleRosterAssignments()
    end
end)

PlayerIcons.TryRegisterUnitMenus()
PlayerIcons.SetupMinimapHook()
