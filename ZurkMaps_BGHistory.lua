-- Shared per-battleground honor history for Zurk Maps honor-bar estimates.
ZurkMapsBGHistory = ZurkMapsBGHistory or {}

local History = ZurkMapsBGHistory
local MAX_LOCAL_RUNS = 40
local AVERAGE_RUNS = 10

ZurkMapsHonorDB = ZurkMapsHonorDB or {}

local BG_CONFIG = {
    ["Warsong Gulch"] = { dbName = "ZurksWSGCalloutMapDB", historyKey = "wsgHonorHistory", currentKey = "currentWSGHonorRun" },
    ["Arathi Basin"] = { dbName = "ZurksABCalloutMapDB", historyKey = "abHonorHistory", currentKey = "currentABHonorRun" },
    ["Alterac Valley"] = { dbName = "ZurksAVCalloutMapDB", historyKey = "avHonorHistory", currentKey = "currentAVHonorRun" },
}

local function GetCurrentBattleground()
    local instanceName = GetInstanceInfo and GetInstanceInfo() or nil
    local realZone = GetRealZoneText and GetRealZoneText() or nil
    local zone = GetZoneText and GetZoneText() or nil
    if BG_CONFIG[instanceName] then return instanceName end
    if BG_CONFIG[realZone] then return realZone end
    if BG_CONFIG[zone] then return zone end
    return nil
end

local function EnsureDB(instanceName)
    local config = BG_CONFIG[instanceName]
    if not config then return nil, nil end
    _G[config.dbName] = _G[config.dbName] or {}
    local db = _G[config.dbName]
    db[config.historyKey] = db[config.historyKey] or {}
    return db, config
end

local function StartRun(instanceName)
    local db, config = EnsureDB(instanceName)
    if not db or not config then return end
    ZurkMapsHonorDB = ZurkMapsHonorDB or {}
    ZurkMapsHonorDB.lastBattleground = instanceName
    ZurkMapsHonorDB.lastBattlegroundTime = GetServerTime and GetServerTime() or time()
    if db[config.currentKey] then return end
    db[config.currentKey] = {
        instanceName = instanceName,
        playerName = UnitName and UnitName("player") or nil,
        enteredTime = GetServerTime and GetServerTime() or time(),
        honor = 0,
    }
end

local function FinishRun(instanceName)
    local db, config = EnsureDB(instanceName)
    if not db or not config then return end
    local run = db[config.currentKey]
    if not run then return end

    run.leftTime = GetServerTime and GetServerTime() or time()
    run.honor = math.floor((tonumber(run.honor) or 0) + 0.5)
    if run.honor > 0 then
        table.insert(db[config.historyKey], 1, run)
        while #db[config.historyKey] > MAX_LOCAL_RUNS do
            table.remove(db[config.historyKey])
        end
    end
    db[config.currentKey] = nil
end

local function SyncZoneState()
    local current = GetCurrentBattleground()
    for instanceName, config in pairs(BG_CONFIG) do
        local db = _G[config.dbName]
        if instanceName == current then
            StartRun(instanceName)
        elseif db and db[config.currentKey] then
            FinishRun(instanceName)
        end
    end
end

local function RecordHonorMessage(text)
    local instanceName = GetCurrentBattleground()
    if not instanceName then return end
    StartRun(instanceName)
    if type(text) ~= "string" then return end
    if issecretvalue and issecretvalue(text) then return end

    local amount = text:match("%d+%.%d+") or text:match("%d+")
    amount = tonumber(amount)
    if not amount then return end

    local db, config = EnsureDB(instanceName)
    local run = db and config and db[config.currentKey] or nil
    if run then run.honor = (tonumber(run.honor) or 0) + amount end
end

local function AddSample(samples, seen, honor, enteredTime, source)
    honor = tonumber(honor)
    if not honor or honor <= 0 then return end
    enteredTime = tonumber(enteredTime) or 0
    if enteredTime > 0 then
        for _, existing in ipairs(samples) do
            if (existing.enteredTime or 0) > 0 and math.abs(existing.enteredTime - enteredTime) <= 15 then
                return
            end
        end
    else
        local key = source .. ":" .. tostring(math.floor(honor + 0.5)) .. ":" .. tostring(#samples + 1)
        if seen[key] then return end
        seen[key] = true
    end
    samples[#samples + 1] = { honor = math.floor(honor + 0.5), enteredTime = enteredTime, source = source }
end

local function AddLocalSamples(instanceName, samples, seen)
    local db, config = EnsureDB(instanceName)
    if not db or not config then return end
    for _, run in ipairs(db[config.historyKey]) do
        if run.instanceName == instanceName then
            AddSample(samples, seen, run.honor, run.enteredTime, "ZurkMaps")
        end
    end
end

local function AddNovaSamples(instanceName, samples, seen)
    if type(NITdatabase) ~= "table" or type(NITdatabase.global) ~= "table" then return end
    local realm = GetRealmName and GetRealmName() or nil
    local realmData = realm and NITdatabase.global[realm] or nil
    local instances = realmData and realmData.instances or nil
    if type(instances) ~= "table" then return end

    local playerName = UnitName and UnitName("player") or nil
    for _, run in ipairs(instances) do
        if type(run) == "table"
            and run.instanceName == instanceName
            and run.type == "bg"
            and (not playerName or not run.playerName or run.playerName == playerName)
            and tonumber(run.leftTime or 0) > 0 then
            local honor = tonumber(run.honor) or 0
            if run.preHonor and run.postHonor then
                honor = (tonumber(run.postHonor) or 0) - (tonumber(run.preHonor) or 0)
            end
            AddSample(samples, seen, honor, run.enteredTime, "NIT")
        end
    end
end


function History.GetMostRecentBattleground()
    ZurkMapsHonorDB = ZurkMapsHonorDB or {}
    local current = GetCurrentBattleground()
    if current then return current end
    local saved = ZurkMapsHonorDB.lastBattleground
    if BG_CONFIG[saved] then return saved end
    return nil
end

function History.GetBattlegroundAcronym(instanceName)
    if instanceName == "Warsong Gulch" then return "WSG" end
    if instanceName == "Arathi Basin" then return "AB" end
    if instanceName == "Alterac Valley" then return "AV" end
    return "BG"
end

function History.GetBattlegroundPlural(instanceName)
    local acronym = History.GetBattlegroundAcronym(instanceName)
    return acronym .. "s"
end

function History.GetRecentSamples(instanceName, limit)
    if not BG_CONFIG[instanceName] then return {} end
    limit = tonumber(limit) or AVERAGE_RUNS
    local samples, seen = {}, {}
    AddLocalSamples(instanceName, samples, seen)
    AddNovaSamples(instanceName, samples, seen)
    table.sort(samples, function(a, b) return (a.enteredTime or 0) > (b.enteredTime or 0) end)
    while #samples > limit do table.remove(samples) end
    return samples
end

function History.GetAverageHonor(instanceName, limit)
    local samples = History.GetRecentSamples(instanceName, limit or AVERAGE_RUNS)
    if #samples == 0 then return nil, 0 end
    local total = 0
    for _, sample in ipairs(samples) do total = total + (sample.honor or 0) end
    return total / #samples, #samples
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == "ZurkMaps" then
            for instanceName in pairs(BG_CONFIG) do EnsureDB(instanceName) end
            C_Timer.After(1, SyncZoneState)
        end
        return
    end
    if event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        RecordHonorMessage(...)
        return
    end
    C_Timer.After(0.5, SyncZoneState)
end)
