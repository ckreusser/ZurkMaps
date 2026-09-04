-- Local AV rehearsal. Movement is in map-height units, independent of UI size.
-- No chat, saved variables, live player assignments, or honor changes.
ZurkMapsAVTest = {}
local Test = ZurkMapsAVTest
local ASPECT = 276 / 512
local FOOT_SPEED = .70 / 360 -- All movement is 30% slower than the first rehearsal.
local MOUNT_SECONDS, FLAG_SECONDS = 3, 10
local CLASSES = {
    Horde = {"WARRIOR","SHAMAN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID"},
    Alliance = {"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID"},
}
local RANKS = {[1]=12,[2]=13,[3]=14,[8]=13,[17]=12,[18]=13,[19]=14,[28]=12,[35]=14}
local MIRRORS = {
    ICEBLOOD_GY="STONEHEARTH_GY", ICEBLOOD_TOWER="STONEHEARTH",
    RELIEF_HUT="STORMPIKE_AID", WEST_FW="DB_NORTH", EAST_FW="DB_SOUTH",
    FROSTWOLF_GY="STORMPIKE_GY", TOWER_POINT="ICEWING",
}
-- Follow the visible road east of Icewing, past SP GY, then across the bridge.
-- Shared in reverse by the two riders sent back from Aid to Icewing.
local NORTH_ROAD = {
    {.580,.350},{.580,.328},{.575,.310},{.583,.289},{.588,.270},
    {.593,.248},{.605,.228},{.608,.219},{.592,.211},{.575,.196},
    {.558,.178},{.552,.161},{.536,.146},{.516,.147},{.491,.153},
    {.459,.154},{.429,.153},{.402,.153},
}
local SOUTH_ROAD = {
    {.570,.625},{.552,.664},{.536,.700},{.549,.744},
    {.555,.786},{.565,.828},{.543,.864},
}
local SLOW_MOUNTS, eligible = {}, {}
for i = 1, 39 do if not RANKS[i] then eligible[#eligible + 1] = i end end
for i = 1, 13 do SLOW_MOUNTS[eligible[math.floor((i-.5)*#eligible/13)+1]] = true end

local function Distance(ax, ay, bx, by)
    return math.sqrt(((bx - ax) * ASPECT)^2 + (by - ay)^2)
end

local function Add(route, x, y, action, value)
    route[#route + 1] = {x=x, y=y, action=action, value=value}
end

local function Points(route, points)
    for _, point in ipairs(points) do Add(route, point[1], point[2]) end
end

local function Objective(route, definitions, id, guardSeconds)
    local objective = assert(definitions[id], "Missing AV test objective: " .. id)
    local x, y = objective.x / 100, objective.y / 100
    Add(route, x, y, "flag", id)
    if guardSeconds then Add(route, x, y, "fight", guardSeconds) end
    Add(route, x, y, "mount")
end

local function Road(route, road, first, last)
    local direction = first <= last and 1 or -1
    for i = first, last, direction do Add(route, road[i][1], road[i][2]) end
end

local function NPC(route, npcs, key, duration)
    local npc = assert(npcs[key], "Missing AV honor NPC: " .. key)
    Add(route, npc.x/100, npc.y/100, "npc", key)
    route[#route].duration = duration or npc.fightSeconds
    Add(route, npc.x/100, npc.y/100, "mount")
end

local function OpeningGY(route, definitions, id)
    local previous = route[#route]
    Add(route, previous.x, previous.y, "opening rally", id)
    Objective(route, definitions, id)
end

local function BuildRoute(agent, definitions, npcs)
    local route = {}
    if agent.faction == "Horde" then
        Add(route, .765, .710)
        Add(route, .755, .710, "mount") -- a short westward walk, then a visible mount cast
        -- Take the cave access road west into the valley before peeling right/east
        -- of Iceblood GY. The old diagonal cut visibly crossed the mountains.
        Points(route, {{.720,.705},{.690,.700},{.655,.685},{.615,.672},
            {.590,.650},{.575,.625},{.600,.603},{.620,.578},{.625,.550},{.595,.516}})
        if agent.role == "captain" then
            Points(route, {{.545,.492},{.490,.472},{.472,.433}})
            Add(route, .475, .414, "dismount") -- undercut Balinda from the left
            Add(route, .490, .397)
            NPC(route, npcs, "BALINDA", agent.fightSeconds)
            for _, key in ipairs({"GREYWAND","LARGENT","LONADIN"}) do
                NPC(route, npcs, key)
            end
        else
            if agent.role == "bunker" then
                Points(route, {{.620,.480},{.630,.455}})
                Add(route, .638, .442, "dismount")
                NPC(route, npcs, "STOUTHANDLE")
                NPC(route, npcs, "MANCUSO")
                NPC(route, npcs, "RANDOLPH")
                Objective(route, definitions, "STONEHEARTH", agent.guardSeconds)
                Points(route, {{.610,.408},{.575,.380}})
            else
                -- The main raid bows well west of Stonehearth Bunker to stay out
                -- of its defensive fire; only the bunker squad takes the close line.
                Points(route, {{.585,.490},{.555,.470},{.530,.445},{.535,.415},{.560,.382}})
            end
            if agent.role == "graveyard" then
                NPC(route, npcs, "SPENCER")
                OpeningGY(route, definitions, "STONEHEARTH_GY")
            end
        end
        Road(route, NORTH_ROAD, 1, 3)
        Road(route, NORTH_ROAD, 3, 13)
        Road(route, NORTH_ROAD, 13, #NORTH_ROAD)
        Objective(route, definitions, "STORMPIKE_AID")
        if agent.backtrack then
            Road(route, NORTH_ROAD, #NORTH_ROAD, 3)
            NPC(route, npcs, "KARL_PHILIPS")
            Objective(route, definitions, "ICEWING", agent.guardSeconds)
            Road(route, NORTH_ROAD, 3, #NORTH_ROAD)
            Objective(route, definitions, "STORMPIKE_AID")
        end
        Add(route, .365, .153)
        NPC(route, npcs, "MORTIMER")
        Objective(route, definitions, agent.tower)
        if agent.lateGraveyard then
            Road(route, NORTH_ROAD, #NORTH_ROAD, 13)
            NPC(route, npcs, "DUFFY")
            Objective(route, definitions, "STORMPIKE_GY", agent.guardSeconds)
            Road(route, NORTH_ROAD, 13, #NORTH_ROAD)
        end
        Add(route, .350, .144, "wait towers", {"DB_NORTH","DB_SOUTH"})
    else
        Add(route, .675, .050)
        Add(route, .665, .050, "mount")
        Add(route, .604, .133)
        Road(route, NORTH_ROAD, 12, 1)
        Points(route, {{.575,.373},{.576,.425},{.561,.484}})
        if agent.role == "captain" then
            Points(route, {{.510,.507},{.463,.531}})
            Add(route, .410, .548, "dismount")
            NPC(route, npcs, "GALVANGAR", agent.fightSeconds)
            for _, key in ipairs({"VOLTALAR","LEWIS"}) do
                NPC(route, npcs, key)
            end
        else
            Add(route, .568, .534)
            if agent.role == "bunker" then
                Add(route, .519, .568, "dismount")
                NPC(route, npcs, "DARDOSH")
                Objective(route, definitions, "ICEBLOOD_TOWER", agent.guardSeconds)
                Add(route, .550, .610)
            elseif agent.role == "graveyard" then
                NPC(route, npcs, "STRONGHOOF")
                NPC(route, npcs, "GRUMMUS")
                NPC(route, npcs, "RUGBA")
                OpeningGY(route, definitions, "ICEBLOOD_GY")
            end
            Add(route, .570, .625)
        end
        Road(route, SOUTH_ROAD, 1, 2)
        Road(route, SOUTH_ROAD, 2, 4)
        Road(route, SOUTH_ROAD, 4, #SOUTH_ROAD)
        NPC(route, npcs, "MULFORT")
        Objective(route, definitions, "RELIEF_HUT")
        if agent.backtrack then
            Road(route, SOUTH_ROAD, #SOUTH_ROAD, 2)
            NPC(route, npcs, "LOUIS_PHILIPS")
            NPC(route, npcs, "MURP")
            Objective(route, definitions, "TOWER_POINT", agent.guardSeconds)
            Road(route, SOUTH_ROAD, 2, #SOUTH_ROAD)
            Objective(route, definitions, "RELIEF_HUT")
        end
        Add(route, .532, .873)
        Objective(route, definitions, agent.tower)
        if agent.lateGraveyard then
            Points(route, {{.555,.831},{.551,.802}})
            NPC(route, npcs, "MALGOR")
            Objective(route, definitions, "FROSTWOLF_GY", agent.guardSeconds)
            Road(route, SOUTH_ROAD, 5, #SOUTH_ROAD)
        end
        Add(route, .523, .885, "wait towers", {"WEST_FW","EAST_FW"})
    end
    local boss = npcs[agent.faction == "Horde" and "VANNDAR" or "DREKTHAR"]
    local south = agent.faction == "Horde" and 1 or -1
    local gatherX = boss.x/100 + ((agent.id % 7)-3) * .003
    local gatherY = boss.y/100 + south * (.012 + (agent.id % 3) * .002)
    Add(route, gatherX, gatherY, "dismount")
    agent.gatherX, agent.gatherY = gatherX, gatherY
    return route
end

local function FirstFlagETA(agent)
    local seconds, multiplier = agent.launchDelay, 1
    for index = 2, #agent.route do
        local previous, point = agent.route[index - 1], agent.route[index]
        seconds = seconds + Distance(previous.x, previous.y, point.x, point.y) / (FOOT_SPEED * multiplier)
        if point.action == "mount" then
            seconds = seconds + MOUNT_SECONDS
            multiplier = agent.mountMultiplier
        elseif point.action == "npc" then
            seconds = seconds + (point.duration or 0)
        elseif point.action == "fight" then
            seconds = seconds + (point.value or 0)
        elseif point.action == "flag" then
            return seconds + FLAG_SECONDS
        end
    end
end

function Test.Create(options)
    options = options or {}
    local random = options.random or math.random
    local sim = {
        elapsed=0, agents={}, teams={Horde={}, Alliance={}}, objectives={}, events={}, npcs={}, npcEvents={},
        captureSeconds=options.captureSeconds or 300, footSpeed=FOOT_SPEED,
        captainCount=random(1,5), bunkerCount=random(2,4), lateGraveyardCount=random(2,5),
    }
    local definitions = {}
    for _, npc in ipairs(options.honorNPCs or {}) do
        sim.npcs[npc.key] = {id=npc.id, key=npc.key, x=npc.x, y=npc.y, faction=npc.faction,
            kind=npc.kind, healthPct=100, phase="alive", fightSeconds=random(10,18)}
    end
    for _, objective in ipairs(options.objectives or {}) do
        definitions[objective.id] = objective
        sim.objectives[objective.id] = {phase="controlled",
            owner=(objective.defaultTexture == 10 or objective.defaultTexture == 14) and "Alliance"
                or ((objective.defaultTexture == 9 or objective.defaultTexture == 12) and "Horde" or nil)}
    end
    for _, faction in ipairs({"Horde", "Alliance"}) do
        for i = 1, 40 do
            local role = i == 1 and "graveyard"
                or (i <= 1 + sim.captainCount and "captain")
                or (i <= 1 + sim.captainCount + sim.bunkerCount and "bunker") or "main"
            local increase = SLOW_MOUNTS[i] and .60 or 1.00
            local hasBonus = random(1,100) <= 35
            local bonus = hasBonus and random(3,9) / 100 or 0
            local agent = {
                id=i, name=(options.names and options.names[i]) or ("AVTester" .. i),
                faction=faction, classToken=CLASSES[faction][((i-1) % #CLASSES[faction]) + 1],
                iconKey="TEST:AV:" .. faction .. ":" .. i, pvpRankNumber=RANKS[i],
                raidBoss=i == 40, role=role, mountIncrease=increase, baseMountIncrease=increase,
                mountBonus=bonus, hasMountBonus=hasBonus, backtrack=i == 30 or i == 31,
                mountMultiplier=(1 + increase) * (1 + bonus),
                fightSeconds=random(35,55), guardSeconds=random(20,35),
                lateGraveyard=i > 40 - sim.lateGraveyardCount,
                tower=faction == "Horde" and (i % 2 == 0 and "DB_NORTH" or "DB_SOUTH")
                    or (i % 2 == 0 and "WEST_FW" or "EAST_FW"),
                launchDelay=0, routeIndex=1, mounted=false, phase="staging",
            }
            agent.route = BuildRoute(agent, definitions, sim.npcs)
            agent.x, agent.y = agent.route[1].x, agent.route[1].y
            sim.teams[faction][i] = agent
            sim.agents[#sim.agents + 1] = agent
        end
    end
    -- Everyone leaves within a second. Only the opening flag scout rallies by
    -- the road if needed to preserve the ten-second difference between GYs.
    local hordeETA = FirstFlagETA(sim.teams.Horde[1])
    local allianceETA = FirstFlagETA(sim.teams.Alliance[1])
    -- The fight orbit ends a few yards from the NPC's nominal coordinate. Give
    -- both opening scouts time to reach this rally so the mirrored +10s launch
    -- remains stable without delaying the other 78 players.
    local firstFlagAt = math.max(hordeETA, allianceETA - 10) + 20
    sim.firstFlagTimes = {Horde=firstFlagAt, Alliance=firstFlagAt + 10}
    for _, agent in ipairs(sim.agents) do
        agent.remaining = agent.launchDelay
    end

    function sim:SetFeatured(agent, featured)
        agent.mountIncrease = (featured or agent.raidBoss or agent.pvpRankNumber) and 1 or agent.baseMountIncrease
        agent.mountMultiplier = (1 + agent.mountIncrease) * (1 + agent.mountBonus)
    end

    local function Emit(id, state)
        local event = {id=id, phase=state.phase, faction=state.attacker or state.owner, at=sim.elapsed}
        sim.events[#sim.events + 1] = event
        if options.onObjective then options.onObjective(event, sim) end
    end

    local function SetTravel(agent)
        agent.phase = agent.mounted and "riding" or "walking"
        agent.remaining, agent.objectiveID, agent.npcKey = nil, nil, nil
    end

    local function CanAssault(agent, id)
        local mirrorID = agent.faction == "Alliance" and MIRRORS[id]
        if not mirrorID then return true end
        local mirror = sim.objectives[mirrorID]
        return mirror and mirror.contestedAt and sim.elapsed >= mirror.contestedAt + 10
    end

    local function Arrive(agent, point)
        if point.action == "mount" then
            if agent.mounted then return end
            agent.phase, agent.remaining = "mounting", MOUNT_SECONDS
        elseif point.action == "dismount" then
            agent.mounted = false
            SetTravel(agent)
        elseif point.action == "fight" then
            agent.mounted, agent.phase, agent.remaining = false, "fighting", point.value
            agent.fightX, agent.fightY, agent.fightStep = point.x, point.y, 0
        elseif point.action == "opening rally" then
            local flag = definitions[point.value]
            local approach = Distance(agent.x, agent.y, flag.x/100, flag.y/100) / (FOOT_SPEED * agent.mountMultiplier)
            agent.phase, agent.releaseAt = "rallying", sim.firstFlagTimes[agent.faction] - FLAG_SECONDS - approach
        elseif point.action == "wait towers" then
            agent.phase, agent.waitObjectives = "waiting for towers", point.value
        elseif point.action == "npc" then
            local npc = sim.npcs[point.value]
            if npc.phase == "dead" then return end
            agent.phase, agent.mounted, agent.npcKey = "fighting NPC", false, point.value
            agent.fightX, agent.fightY, agent.fightStep = point.x, point.y, 0
            if npc.phase == "alive" then
                npc.phase, npc.startedAt, npc.endsAt = "fighting", sim.elapsed, sim.elapsed + point.duration
                sim.npcEvents[#sim.npcEvents + 1] = {key=npc.key, phase="fighting", at=sim.elapsed}
            end
        elseif point.action == "flag" then
            local state = sim.objectives[point.value]
            if state.phase ~= "controlled" then return end
            agent.mounted, agent.objectiveID = false, point.value
            if state.claimant then
                agent.phase = "waiting for flag"
            else
                state.claimant = agent
                agent.phase, agent.remaining = "contesting", FLAG_SECONDS
                agent.flagStartedAt = sim.elapsed
            end
        end
    end

    local function Move(agent, x, y, step)
        local distance = Distance(agent.x, agent.y, x, y)
        if distance <= step then agent.x, agent.y = x, y; return true end
        agent.x = agent.x + (x - agent.x) * step / distance
        agent.y = agent.y + (y - agent.y) * step / distance
        return false
    end

    local function ResumeAfterDismountedTask(agent)
        local nextPoint = agent.route[agent.routeIndex + 1]
        if nextPoint and nextPoint.action == "mount" then
            -- Cast at the player's current location. Combat movement can leave a
            -- player a few yards from the route's nominal NPC/flag coordinate.
            agent.routeIndex = agent.routeIndex + 1
            agent.mounted, agent.phase, agent.remaining = false, "mounting", MOUNT_SECONDS
        else
            SetTravel(agent)
        end
    end

    local function TickAgent(agent, dt)
        if agent.finished then return end
        local phase = agent.phase
        if phase == "rallying" then
            if sim.elapsed >= agent.releaseAt then SetTravel(agent) end
        elseif phase == "waiting for towers" then
            local ready = true
            for _, id in ipairs(agent.waitObjectives) do
                if not sim.objectives[id].contestedAt then ready = false end
            end
            if ready then SetTravel(agent) end
        elseif phase == "staging" or phase == "mounting" then
            agent.remaining = agent.remaining - dt
            if agent.remaining <= 0 then
                if phase == "mounting" then agent.mounted = true end
                SetTravel(agent)
            end
        elseif phase == "contesting" then
            agent.remaining = math.max(0, agent.remaining - dt)
            if agent.remaining <= 0 and CanAssault(agent, agent.objectiveID) then
                local state = sim.objectives[agent.objectiveID]
                state.phase, state.attacker = "contested", agent.faction
                state.contestedAt, state.endsAt = sim.elapsed, sim.elapsed + sim.captureSeconds
                Emit(agent.objectiveID, state)
                ResumeAfterDismountedTask(agent)
            end
        elseif phase == "waiting for flag" then
            if sim.objectives[agent.objectiveID].phase ~= "controlled" then ResumeAfterDismountedTask(agent) end
        elseif phase == "fighting" or phase == "fighting NPC" then
            local finished
            if phase == "fighting NPC" then
                finished = sim.npcs[agent.npcKey].phase == "dead"
            else
                agent.remaining = agent.remaining - dt
                finished = agent.remaining <= 0
            end
            local angle = (agent.id + agent.fightStep) * 2.39996
            if Move(agent, agent.fightX + math.cos(angle) * .009,
                agent.fightY + math.sin(angle) * .005, FOOT_SPEED * dt) then
                agent.fightStep = agent.fightStep + 1
            end
            if finished then ResumeAfterDismountedTask(agent) end
        else
            local point = agent.route[agent.routeIndex + 1]
            if not point then agent.finished, agent.phase = true, "holding"; return end
            local speed = FOOT_SPEED * (agent.mounted and agent.mountMultiplier or 1)
            if Move(agent, point.x, point.y, speed * dt) then
                agent.routeIndex = agent.routeIndex + 1
                Arrive(agent, point)
            end
        end
    end

    function sim:Advance(elapsed)
        -- Bound each movement step so flags cannot be skipped by a low FPS
        -- frame. This clock keeps running when the map is closed.
        while elapsed > .000001 do
            local dt = math.min(.05, elapsed)
            self.elapsed = self.elapsed + dt
            for _, agent in ipairs(self.agents) do TickAgent(agent, dt) end
            for key, npc in pairs(self.npcs) do
                if npc.phase == "fighting" then
                    local pct = math.max(0, math.ceil(100 * (npc.endsAt-self.elapsed) / (npc.endsAt-npc.startedAt)))
                    if pct ~= npc.healthPct then
                        npc.healthPct = pct
                        if pct == 0 then
                            npc.phase, npc.killedAt = "dead", self.elapsed
                            self.npcEvents[#self.npcEvents + 1] = {key=key, phase="dead", at=self.elapsed}
                        end
                        if options.onNPCState then options.onNPCState(npc) end
                    end
                end
            end
            for id, state in pairs(self.objectives) do
                if state.phase == "contested" and self.elapsed >= state.endsAt then
                    state.phase, state.owner = "captured", state.attacker
                    state.capturedAt, state.endsAt = self.elapsed, nil
                    Emit(id, state)
                end
            end
            elapsed = elapsed - dt
        end
    end
    return sim
end
