local checks = 0
local clock = 100
local reports = {}
local addonPackets = {}

function GetTime() return clock end
function UnitGUID(unit) if unit == "player" then return "Player-1-00001234" end end
function UnitName(unit) if unit == "player" then return "LocalReporter" end end
function IsInInstance() return true, "pvp" end
function Report(message) reports[#reports + 1] = message end

C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) C_ChatInfo.registeredPrefix = prefix; return true end,
    SendAddonMessage = function(prefix, message, channel)
        addonPackets[#addonPackets + 1] = {prefix, message, channel}
        return 0
    end,
}

ZurksWSGCalloutMapDB = {}

local function Check(value, message)
    assert(value, message)
    checks = checks + 1
end

local function Equal(actual, expected, message)
    assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end

function RunWSGHealthCoordinationTests()
    local health = ZurkMapsWSGEFCHealth
    Equal(C_ChatInfo.registeredPrefix, health.PREFIX, "coordination prefix registered")
    Equal(health.IsEnabled(), true, "automatic health reports default on")

    health.Reset("Carrier-Realm")
    health.Update("Carrier-Realm", 50)
    health.Update("Carrier-Realm", 39)
    Check(health.pending and health.pending.threshold == 40, "40 percent crossing queues instead of speaking immediately")
    Equal(#reports, 0, "stagger prevents immediate public report")
    Check(health.pending.dueAt > clock and health.pending.dueAt < clock + 0.75, "40 percent stagger stays short")

    clock = health.pending.dueAt
    Equal(health.ProcessPending(), false, "winner announces a private claim before reporting")
    Equal(#addonPackets, 1, "one coordination claim sent")
    Equal(addonPackets[1][1], health.PREFIX, "claim uses Zurk Maps prefix")
    Equal(addonPackets[1][3], "INSTANCE_CHAT", "claim uses battleground addon channel")
    Equal(#reports, 0, "claim settle window remains silent publicly")
    clock = health.pending.reportAt
    Equal(health.ProcessPending(), true, "claim winner reports after settle window")
    Equal(reports[#reports], ">>> EFC 39%! <<<", "winner reports current observed health")
    Equal(health.pending, nil, "successful report clears pending candidate")

    reports, addonPackets, clock = {}, {}, 200
    health.Reset("Carrier-Realm")
    health.Update("Carrier-Realm", 50)
    health.Update("Carrier-Realm", 39)
    local originalDue = health.pending.dueAt
    Equal(health.HandleClaim("H1|40|38|0|carrier", "OtherReporter"), true, "valid peer claim accepted")
    Check(health.pending.dueAt >= clock + health.CLAIM_BACKUP_SECONDS, "peer claim postpones local candidate as backup")
    clock = originalDue
    Equal(health.ProcessPending(), false, "postponed backup does not duplicate first candidate")
    Equal(#reports, 0, "peer claim avoids public duplicate")
    Equal(health.HandlePublicReport(">>> EFC 38%! <<<"), true, "peer public report recognized")
    Equal(health.pending, nil, "peer public report cancels backup")

    reports, addonPackets, clock = {}, {}, 300
    health.Reset("Carrier-Realm")
    health.Update("Carrier-Realm", 50)
    health.Update("Carrier-Realm", 39)
    health.HandleClaim("H1|40|39|0|carrier", "SilentWinner")
    clock = health.pending.dueAt
    health.ProcessPending()
    Check(health.pending and health.pending.claimSent, "backup claims when winning report never appears")
    clock = health.pending.reportAt
    health.ProcessPending()
    Equal(#reports, 1, "backup preserves health feature after failed winner")

    reports, addonPackets, clock = {}, {}, 400
    health.Reset("Carrier-Realm")
    health.Update("Carrier-Realm", 50)
    health.Update("Carrier-Realm", 39)
    health.HandlePublicReport(">>> EFC 39%! <<<")
    health.Update("Carrier-Realm", 19)
    Check(health.pending and health.pending.threshold == 20, "new urgent threshold survives earlier 40 percent report")
    Check(health.GetStaggerSeconds(10, 996) < health.GetStaggerSeconds(40, 996), "10 percent reports use the shortest stagger")

    ZurksWSGCalloutMapDB.autoEFCHealth = false
    health.Reset("Carrier-Realm")
    health.Update("Carrier-Realm", 50)
    health.Update("Carrier-Realm", 39)
    Equal(health.pending, nil, "disabled option suppresses automatic reports")
    Equal(health.HandleClaim("bad packet", "OtherReporter"), false, "malformed coordination packet rejected")
    ZurksWSGCalloutMapDB.autoEFCHealth = true

    print("WSG EFC health coordination: " .. checks .. " checks passed.")
end
