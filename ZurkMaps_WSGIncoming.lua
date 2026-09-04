-- Incoming WSG location reports. English callout vocabulary and interpretation
-- notes live in WSG_CALLOUTS.md. Parse is independent of the WoW UI for testing.
ZurkMapsWSGIncoming = {}
local Incoming = ZurkMapsWSGIncoming
Incoming.DURATION = 8
Incoming.FADE_DURATION = 0.75

local vocabulary = {}
local function Words(text)
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    return words
end

local function Add(areas, aliases, options)
    for _, alias in ipairs(aliases) do
        local words = Words(alias)
        local bucket = vocabulary[words[1]] or {}
        vocabulary[words[1]] = bucket
        bucket[#bucket + 1] = { words = words, areas = areas, options = options or {} }
    end
end

Add({"FLAG_ROOM"}, {"flag room", "flagroom", "fr", "flag room floor", "first floor", "1st floor", "1st", "floor 1", "on 1", "1f", "flag stand", "flagstand", "cap spot", "cap point", "window room", "window"})
Add({"FLAG_ROOM"}, {"efr"}, {side = "enemy"})
Add({"SECOND_FLOOR"}, {"second floor", "2nd floor", "second", "2nd", "floor 2", "on 2", "2f", "balcony", "balc", "connector", "con"})
Add({"SECOND_FLOOR"}, {"2"}, {number = true})
Add({"ROOF"}, {"roof", "rooftop", "roof top", "third floor", "3rd floor", "3rd", "floor 3", "on 3", "3f"})
Add({"ROOF"}, {"eroof"}, {side = "enemy"})
Add({"ROOF"}, {"3"}, {number = true})
Add({"BANANA"}, {"banana", "bananas", "bananna", "banana ramp", "roof ramp"})
Add({"TOPSIDE"}, {"topside", "top side"})
Add({"TUNNEL"}, {"tunnel", "tun", "tunn", "tunnel entrance", "tunnel exit", "tunnel mouth", "bottom tunnel", "bottom of tunnel", "lower tunnel", "boots", "speed", "speed buff", "speed room"})
Add({"TUNNEL"}, {"etun", "etunnel"}, {side = "enemy"})
Add({"TOP_OF_TUNNEL"}, {"top of tunnel", "top of the tunnel", "top tunnel", "tunnel top", "top of tun", "tot", "t o t", "on top of tunnel", "on top of the tunnel"})
Add({"TOP_OF_TUNNEL"}, {"etot"}, {side = "enemy"})
Add({"RAMP"}, {"ramp", "ramps", "ramp entrance", "bottom ramp", "bottom of ramp"})
Add({"RAMP"}, {"eramp"}, {side = "enemy"})
Add({"GRAVEYARD"}, {"graveyard", "grave yard", "gy", "g y", "graveyard jump", "gy jump"})
Add({"GRAVEYARD"}, {"egy"}, {side = "enemy"})
Add({"LEAF_HUT"}, {"leaf", "leaf hut", "leafhut", "leaves", "leaf buff", "resto", "resto hut", "restoration", "restoration hut", "restoration buff", "healing hut", "heal hut", "health hut"})
Add({"LEAF_HUT"}, {"eleaf"}, {side = "enemy"})
Add({"ZERK_HUT"}, {"zerk", "zerker", "zerk hut", "zerker hut", "zerkhut", "berserk", "berserker", "berserking", "berserker hut", "berserking hut", "berserking buff", "zerker buff", "zerk buff", "bers"})
Add({"ZERK_HUT"}, {"ezerk", "ezerker"}, {side = "enemy"})
Add({"LEAF_HUT", "ZERK_HUT"}, {"hut", "huts", "buff hut"})
-- These fine-grained rooms/landmarks share the existing map's broader regions.
Add({"FLAG_ROOM", "SECOND_FLOOR"}, {"lobby", "stairs", "stairway", "staircase"})
Add({"TOPSIDE", "GRAVEYARD", "RAMP"}, {"fence", "fences"})
Add({"ROOF", "SECOND_FLOOR", "TOPSIDE", "TOP_OF_TUNNEL"}, {"top", "up top", "upper", "upstairs"})
Add({"FLAG_ROOM", "SECOND_FLOOR", "ROOF", "BANANA", "TOPSIDE", "TUNNEL", "RAMP", "GRAVEYARD"}, {"base", "in base", "inside base"})
Add({"GRAVEYARD", "LEAF_HUT"}, {"gy side", "graveyard side", "grave yard side"}, {lane = "gy"})
Add({"RAMP", "ZERK_HUT"}, {"ramp side"}, {lane = "ramp"})
Add({"MID_WEST", "MID", "MID_EAST"}, {"mid", "middle", "midfield", "mid field", "field"}, {fixed = true})
Add({"MID"}, {"center mid", "centre mid", "middle mid", "center", "centre"}, {fixed = true})
Add({"MID_WEST"}, {"west", "mid west", "west mid", "middle west", "west side", "catapult"}, {fixed = true})
Add({"MID_EAST"}, {"east", "mid east", "east mid", "middle east", "east side"}, {fixed = true})
-- Left/right depend on the speaker's facing; don't silently choose a compass side.
Add({"MID_WEST", "MID_EAST"}, {"left", "right", "left mid", "right mid", "mid left", "mid right", "left side", "right side"}, {fixed = true})
Add({"TREE"}, {"tree", "big tree"}, {fixed = true})
Add({"TREE", "MID_WEST", "MID_EAST"}, {"stump", "stumps", "trees"}, {fixed = true})
Add({"MID_EAST", "HORDE_LEAF_HUT", "HORDE_TOPSIDE"}, {"construction", "crane"}, {fixed = true})
Add({"MID_EAST"}, {"east construction", "east crane", "mid construction", "mid crane"}, {fixed = true})
Add({"HORDE_LEAF_HUT"}, {"leaf construction", "leaf hut construction", "leaf crane", "leaf hut crane"}, {fixed = true})
Add({"HORDE_TOPSIDE"}, {"sawmill", "saw mill", "sawmill construction", "sawmill crane"}, {fixed = true})
Add({"ALLY_ROOF", "ALLY_BANANA"}, {"shrine"}, {fixed = true})
Add({"ALLY_ROOF"}, {"flower box", "flowerbox", "planter"}, {fixed = true})
for _, bucket in pairs(vocabulary) do
    table.sort(bucket, function(a, b) return #a.words > #b.words end)
end

local qualifiers = {
    ally = "ALLY", alli = "ALLY", alliance = "ALLY", allies = "ALLY",
    horde = "HORDE", hordes = "HORDE", alliances = "ALLY",
    north = "ALLY", northern = "ALLY", south = "HORDE", southern = "HORDE",
    our = "friendly", ours = "friendly", own = "friendly", home = "friendly", friendly = "friendly",
    their = "enemy", theirs = "enemy", enemy = "enemy", enemys = "enemy", opposing = "enemy",
    e = "enemy",
}
local filler = {}
for _, word in ipairs(Words("efc fc ffc is at in on the a an of to from near by going heading moving running leaving exiting entering toward towards through down up out outside inside now still seen spotted last maybe possibly probably or and then but actually instead he hes she shes they theyre it its there here back side end jump off ;")) do filler[word] = true end
local negations = {["not"] = true, no = true, isnt = true, arent = true, wasnt = true, never = true}
local corrections = {but = true, actually = true, instead = true, now = true}
local questions = {is = true, are = true, can = true, could = true, does = true, did = true, anyone = true, wheres = true}
local nonLocations = {has = true, have = true, used = true, using = true, popped = true, got = true, took = true, needs = true, need = true}

local function Normalize(message)
    local text = message:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- A linked item called Boots or a texture is not a location report.
    text = text:gsub("|h.-|h.-|h", " "):gsub("|t.-|t", " "):gsub("|a.-|a", " ")
    text = text:gsub("\226\128\153", ""):gsub("'", "")
    text = text:gsub("%f[%a]enemy%s+flag%s+carrier%f[%A]", "efc")
    text = text:gsub("%f[%a]their%s+flag%s+carrier%f[%A]", "efc")
    text = text:gsub("%f[%a]enemy%s+fc%f[%A]", "efc"):gsub("%f[%a]their%s+fc%f[%A]", "efc")
    text = text:gsub("%f[%a]our%s+flag%s+carrier%f[%A]", "ffc")
    text = text:gsub("%f[%a]friendly%s+flag%s+carrier%f[%A]", "ffc")
    text = text:gsub("%f[%a]flag%s+carrier%f[%A]", "fc")
    text = text:gsub("[,;%.]", " ; "):gsub("[^%w%s;]", " "):gsub("%s+", " ")
    return Words(text)
end

local function ResolveSide(side, faction)
    if side == "ALLY" or side == "HORDE" then return side end
    if faction ~= "Alliance" and faction ~= "Horde" then return nil end
    local friendly = faction == "Alliance" and "ALLY" or "HORDE"
    if side == "friendly" then return friendly end
    if side == "enemy" then return friendly == "ALLY" and "HORDE" or "ALLY" end
end

function Incoming.Parse(message, faction)
    if type(message) ~= "string" or #message > 1024 then return {} end
    -- Questions are requests for information, not sightings.
    if message:find("?", 1, true) then return {} end
    local normalizedTokens = Normalize(message)
    local tokens, hasEnemyShorthand = {}, false
    for _, token in ipairs(normalizedTokens) do
        local suffix = token ~= "efc" and token:sub(1, 1) == "e" and #token > 1 and token:sub(2) or nil
        if token == "e" then
            tokens[#tokens + 1] = token
            hasEnemyShorthand = true
        elseif suffix and vocabulary[suffix] then
            -- A leading E is common WSG shorthand for "enemy": eroof, etun,
            -- ebanana, and the equivalent spaced forms all share one rule.
            tokens[#tokens + 1] = "e"
            tokens[#tokens + 1] = suffix
            hasEnemyShorthand = true
        else
            tokens[#tokens + 1] = token
        end
    end
    if questions[tokens[1]] then return {} end
    local explicit = false
    for _, token in ipairs(tokens) do
        if token == "where" or token == "wheres" or token == "whereabouts" then return {} end
        if token == "efc" then explicit = true end
    end
    local matches, consumed = {}, {}
    local index = 1
    while index <= #tokens do
        local found
        for _, entry in ipairs(vocabulary[tokens[index]] or {}) do
            local match = true
            if entry.options.number then
                local following = tokens[index + 1]
                match = explicit and (not following or following == ";" or following == "now" or following == "or")
            end
            for offset, word in ipairs(entry.words) do
                if tokens[index + offset - 1] ~= word then match = false; break end
            end
            if match then found = entry; break end
        end
        if found then
            local last = index + #found.words - 1
            matches[#matches + 1] = {first = index, last = last, entry = found}
            for position = index, last do consumed[position] = true end
            index = last + 1
        else
            index = index + 1
        end
    end
    -- Bare short answers are useful for testing and real callouts. Free-form
    -- chatter needs an EFC subject, so "I love banana bread" stays inert.
    if not explicit then
        for position, token in ipairs(tokens) do
            if not consumed[position] and not filler[token] and not qualifiers[token]
                and not negations[token] then return {} end
        end
    end

    local result, seen = {}, {}
    local function Include(id)
        if not seen[id] then seen[id] = true; result[#result + 1] = id end
    end
    local shorthandSide = hasEnemyShorthand and ResolveSide("enemy", faction) or nil
    local subject, side, negated, previous = "efc", shorthandSide, false, 0
    for matchIndex, match in ipairs(matches) do
        local gapSide, conflictingSide, hasQualifier
        for position = previous + 1, match.first - 1 do
            local token = tokens[position]
            if token == "efc" or token == "fc" or token == "ffc" then
                subject, side, negated, gapSide, conflictingSide, hasQualifier = token, shorthandSide, false, nil, nil, nil
            elseif token == ";" then
                side, gapSide, conflictingSide, hasQualifier = shorthandSide, nil, nil, nil
            elseif corrections[token] then
                negated = false
            elseif negations[token] then
                negated = true
            elseif qualifiers[token] then
                local resolved = ResolveSide(qualifiers[token], faction)
                if gapSide and resolved ~= gapSide then conflictingSide = true end
                gapSide, hasQualifier = resolved, true
            end
        end
        if conflictingSide then side = nil elseif hasQualifier then side = gapSide end
        local options = match.entry.options
        local selectedSide = options.side and ResolveSide(options.side, faction) or side or shorthandSide
        -- Also accept suffix forms such as "efc roof horde". A qualifier before
        -- another location belongs to that following location, never both.
        if matchIndex == #matches then
            for position = match.last + 1, #tokens do
                local token = tokens[position]
                if token == ";" or token == "fc" or token == "ffc" then break end
                if tokens[position + 1] == "fc" or tokens[position + 1] == "ffc" then break end
                if qualifiers[token] then selectedSide = ResolveSide(qualifiers[token], faction) end
            end
        end
        -- A death/return report in this subject's clause is not a location fix.
        local ended = false
        local clauseStart, clauseEnd = match.first, match.last
        while clauseStart > 1 and tokens[clauseStart - 1] ~= ";" and tokens[clauseStart - 1] ~= "fc" and tokens[clauseStart - 1] ~= "ffc" do clauseStart = clauseStart - 1 end
        while clauseEnd < #tokens and tokens[clauseEnd + 1] ~= ";" and tokens[clauseEnd + 1] ~= "fc" and tokens[clauseEnd + 1] ~= "ffc" do clauseEnd = clauseEnd + 1 end
        for position = clauseStart, clauseEnd do
            local token = tokens[position]
            if token == "dead" or token == "died" or token == "returned" or token == "capped" or token == "captured" then ended = true end
        end
        local before = match.first - 1
        while tokens[before] == "the" or tokens[before] == "a" or tokens[before] == "his" do before = before - 1 end
        local describesAbility = nonLocations[tokens[before]]
        if subject == "efc" and not negated and not ended and not describesAbility then
            if options.fixed then
                for _, id in ipairs(match.entry.areas) do Include(id) end
            else
                local sides = selectedSide and {selectedSide} or {"ALLY", "HORDE"}
                for _, prefix in ipairs(sides) do
                    for _, area in ipairs(match.entry.areas) do Include(prefix .. "_" .. area) end
                    if options.lane then
                        local west = (prefix == "ALLY") == (options.lane == "gy")
                        Include(west and "MID_WEST" or "MID_EAST")
                    end
                end
            end
        end
        previous = match.last
    end
    return result
end

local raceFactions = {
    Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance", Draenei = "Alliance",
    Orc = "Horde", Scourge = "Horde", Undead = "Horde", Tauren = "Horde", Troll = "Horde", BloodElf = "Horde",
}

local function IsInWarsongGulch()
    if not GetInstanceInfo then return false end
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    -- Classic WSG's instance ID is independent of the client's language.
    return instanceType == "pvp" and instanceID == 489
end

function Incoming.IsFriendlySender(guid)
    if type(guid) ~= "string" or not guid:match("^Player%-") then return false end
    if guid == UnitGUID("player") then return true end -- self /say is the test path
    local function CheckUnit(unit)
        if UnitGUID(unit) == guid then return not not UnitIsFriend("player", unit) end
    end
    for _, unit in ipairs({"target", "focus", "mouseover"}) do
        local friendly = CheckUnit(unit)
        if friendly ~= nil then return friendly end
    end
    local raid = IsInRaid and IsInRaid()
    for index = 1, (raid and 40 or 4) do
        local friendly = CheckUnit((raid and "raid" or "party") .. index)
        if friendly ~= nil then return friendly end
    end
    -- Nearby ungrouped /say speakers normally have cached player info; don't
    -- infer friendliness from readable language or a name alone.
    if GetPlayerInfoByGUID then
        local _, _, _, race = GetPlayerInfoByGUID(guid)
        local faction = race and raceFactions[race]
        return faction ~= nil and faction == UnitFactionGroup("player")
    end
    return false
end

function Incoming.Create(map, zones, nestedZones, createHighlight)
    local controller = {overlays = {}, zones = {}, activeIDs = {}}
    for _, list in ipairs({zones, nestedZones}) do
        for _, zone in ipairs(list) do controller.zones[zone.id] = zone end
    end
    local driver = CreateFrame("Frame", nil, map)
    driver:SetAllPoints()
    driver:EnableMouse(false)
    driver:Hide()
    controller.driver = driver

    function controller:Clear()
        for _, overlay in pairs(self.overlays) do
            if overlay.SetCalloutActive then overlay:SetCalloutActive(false) end
            overlay:Hide()
        end
        self.activeIDs, self.startedAt, self.expiresAt = {}, nil, nil
        self.interactionID = nil
        self.lastMessage, self.lastAuthor = nil, nil
        driver:Hide()
    end

    function controller:IsAreaActive(id)
        if not id then return false end
        for _, activeID in ipairs(self.activeIDs) do
            if activeID == id then return true end
        end
        return false
    end

    function controller:SetAreaInteraction(id, active, pressed)
        if self.interactionID and (not active or self.interactionID ~= id) then
            local previous = self.overlays[self.interactionID]
            if previous and previous.SetHoverInteraction then previous:SetHoverInteraction(false) end
            self.interactionID = nil
        end
        if not active or not self:IsAreaActive(id) then return false end
        local overlay = self.overlays[id]
        if not overlay or not overlay.SetHoverInteraction then return false end
        if self.interactionID ~= id then
            self.interactionID = id
            overlay:SetHoverInteraction(true)
        end
        if overlay.SetInteractionPressed then overlay:SetInteractionPressed(pressed) end
        return true
    end

    function controller:Receive(message, author, guid, fromBattleground)
        if not map:IsVisible() or ZurksWSGCalloutMapDB.incomingCallouts == false then return false end
        if fromBattleground and not IsInWarsongGulch() then return false end
        local ids = Incoming.Parse(message, UnitFactionGroup("player"))
        if #ids == 0 then return false end
        if fromBattleground then
            -- Blizzard delivers instance chat only from our battleground team.
            -- Accept distant teammates even before their unit/race is cached.
            if type(guid) ~= "string" or not guid:match("^Player%-") then return false end
        elseif not Incoming.IsFriendlySender(guid) then
            return false
        end
        self:Clear()
        for _, id in ipairs(ids) do
            local zone = self.zones[id]
            if zone then
                local overlay = self.overlays[id]
                if not overlay then
                    overlay = createHighlight()
                    overlay:SetZone(zone)
                    self.overlays[id] = overlay
                end
                if overlay.SetCalloutActive then overlay:SetCalloutActive(true) end
                if overlay.SetCalloutPulseAlpha then overlay:SetCalloutPulseAlpha(1, 1) else overlay:SetAlpha(1) end
                overlay:Show()
                self.activeIDs[#self.activeIDs + 1] = id
            end
        end
        if #self.activeIDs == 0 then return false end
        self.startedAt = GetTime()
        self.expiresAt = self.startedAt + Incoming.DURATION
        self.lastMessage, self.lastAuthor = message, author
        driver:Show()
        return true
    end

    driver:SetScript("OnUpdate", function(_, elapsed)
        local now = GetTime()
        if not controller.expiresAt or now >= controller.expiresAt then controller:Clear(); return end
        local age = now - controller.startedAt
        local fade = math.min(1, (controller.expiresAt - now) / Incoming.FADE_DURATION)
        local pulse = 0.60 + 0.40 * math.cos(age * math.pi * 2 / 1.2)
        local alpha = pulse * fade
        for _, id in ipairs(controller.activeIDs) do
            local overlay = controller.overlays[id]
            if overlay.SetCalloutPulseAlpha then overlay:SetCalloutPulseAlpha(alpha, fade) else overlay:SetAlpha(alpha) end
            if overlay.UpdateCalloutAnimation then overlay:UpdateCalloutAnimation(age) end
            if overlay.UpdateInteractionAnimation then overlay:UpdateInteractionAnimation(elapsed) end
        end
    end)
    map:HookScript("OnHide", function() controller:Clear() end)
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("CHAT_MSG_SAY")
    listener:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
    listener:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
    listener:RegisterEvent("PLAYER_ENTERING_WORLD")
    listener:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    listener:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_SAY" then
            local message, author = ...
            local guid = select(12, ...)
            controller:Receive(message, author, guid)
        elseif event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
            local message, author = ...
            local guid = select(12, ...)
            controller:Receive(message, author, guid, true)
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            controller:Clear()
        end
    end)
    controller.listener = listener
    return controller
end
