-- Real simulation, sampled at the same cadence as the map updater.
local checks = 0
local function Check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function Distance(ax, ay, bx, by)
    return math.sqrt(((bx-ax)*276/512)^2 + (by-ay)^2)
end
for _, seed in ipairs({7,42,99}) do
    math.randomseed(seed)
    local sim = ZurkMapsAVTest.Create({objectives=TEST_OBJECTIVES, honorNPCs=TEST_NPCS, onObjective=function(event, model)
        if event.phase == "contested" then
            local claimant = model.objectives[event.id].claimant
            for _, objective in ipairs(TEST_OBJECTIVES) do
                if objective.id == event.id then
                    Check(Distance(claimant.x, claimant.y, objective.x/100, objective.y/100) < .000001,
                        "flag claimant must be standing at the objective marker")
                end
            end
        end
    end})
    Check(#sim.agents == 80, "both teams must be simulated")
    Check(sim.captainCount >= 1 and sim.captainCount <= 5, "captain breakaway size")
    local states, movingOnFoot, movingMounted = {}, 0, 0
    for faction, team in pairs(sim.teams) do
        local slow, boss, ranks, boosted = 0, 0, {}, 0
        for _, agent in ipairs(team) do
            if agent.mountIncrease == .6 then slow = slow + 1 end
            if agent.raidBoss then boss = boss + 1 end
            if agent.pvpRankNumber then ranks[agent.pvpRankNumber] = true end
            if agent.pvpRankNumber or agent.raidBoss then
                Check(agent.mountIncrease == 1, "rank 12-14 and Raid Boss must have +100% mounts")
            end
            Check(agent.launchDelay == 0, "everyone must start immediately")
            Check(agent.mountBonus == 0 or (agent.mountBonus >= .03 and agent.mountBonus <= .09), "mount bonus bounds")
            Check(agent.hasMountBonus == (agent.mountBonus > 0), "bonus chance must be rolled before bonus amount")
            if agent.mountBonus > 0 then boosted = boosted + 1 end
            states[agent] = {mounts=0, fights=0}
        end
        Check(#team == 40 and slow == 13, faction .. " mount mix")
        Check(boss >= 1 and ranks[12] and ranks[13] and ranks[14], "featured icons per raid")
        Check(boosted > 0 and boosted < 40, "mount bonus is a chance")
    end
    Check(math.abs(sim.footSpeed - .7/360) < .00000001, "all movement must be 30% slower")
    local step = .05
    for tick = 1, 24000 do
        local before = {}
        for _, agent in ipairs(sim.agents) do
            before[agent] = {x=agent.x, y=agent.y, phase=agent.phase, mounted=agent.mounted}
        end
        sim:Advance(step)
        if tick == 22 then
            for _, agent in ipairs(sim.agents) do
                Check(Distance(agent.x, agent.y, agent.route[1].x, agent.route[1].y) > 0,
                    "every blip must already be moving at 1.1 seconds")
                Check(agent.x < agent.route[1].x and agent.y == agent.route[1].y,
                    "the opening walk must be a short move west")
            end
        end
        for _, agent in ipairs(sim.agents) do
            local previous, state = before[agent], states[agent]
            local movement = Distance(previous.x, previous.y, agent.x, agent.y)
            local limit = sim.footSpeed * step * (previous.mounted and agent.mountMultiplier or 1)
            assert(movement <= limit + .00000001, "unit teleported or exceeded movement speed")
            if previous.phase == "walking" and movement > 0 then movingOnFoot = movingOnFoot + 1 end
            if previous.phase == "riding" and movement > 0 then movingMounted = movingMounted + 1 end
            if previous.phase == "mounting" or previous.phase == "contesting" or previous.phase == "waiting for flag" then
                assert(movement == 0, "flag channel/mount cast must be stationary")
            end
            if previous.phase == "fighting" or previous.phase == "fighting NPC" or previous.phase == "contesting" then
                assert(not previous.mounted, "combat and flag contests must never use mount speed")
            end
            if state.mustMountBy then
                if agent.phase == "mounting" then
                    state.mustMountBy = nil
                else
                    Check(sim.elapsed <= state.mustMountBy, "players must mount after objective/fight: " .. agent.faction .. agent.id
                        .. " " .. tostring(previous.phase) .. ">" .. tostring(agent.phase) .. " @" .. sim.elapsed)
                end
            end
            if agent.phase ~= previous.phase then
                if agent.phase == "mounting" then state.mountStart = sim.elapsed end
                if previous.phase == "mounting" then
                    Check(math.abs(sim.elapsed - state.mountStart - 3) < .06, "mount cast must take three seconds")
                    state.mounts = state.mounts + 1
                end
                if agent.phase == "fighting" or agent.phase == "fighting NPC" then
                    Check(not agent.mounted, "combat must remove mount speed")
                    state.fights = state.fights + 1
                end
                if previous.phase == "fighting" or previous.phase == "fighting NPC" then
                    state.mustMountBy = sim.elapsed + .11
                elseif previous.phase == "contesting" then
                    local nextPoint = agent.route[agent.routeIndex + 1]
                    if not nextPoint or nextPoint.action ~= "fight" then state.mustMountBy = sim.elapsed + .11 end
                end
                if agent.finished then
                    local towers = agent.faction == "Horde" and {"DB_NORTH","DB_SOUTH"} or {"WEST_FW","EAST_FW"}
                    Check(sim.objectives[towers[1]].contestedAt and sim.objectives[towers[2]].contestedAt,
                        "both base towers must be contested before boss gathering")
                end
                if agent.phase == "contesting" then state.flagStart, state.flagID = sim.elapsed, agent.objectiveID end
                if previous.phase == "contesting" and (state.flagID == "STONEHEARTH_GY" or state.flagID == "ICEBLOOD_GY") then
                    Check(math.abs(sim.elapsed - state.flagStart - 10) < .25, "first GY channel must take ten seconds")
                end
            end
        end
    end
    Check(movingOnFoot > 0 and movingMounted > 0, "walking and riding must both occur")
    local primaryH, primaryA = sim.objectives.STONEHEARTH_GY, sim.objectives.ICEBLOOD_GY
    Check(math.abs(primaryA.contestedAt - primaryH.contestedAt - 10) < .75, "Alliance first GY must trail by about ten seconds")
    local groups = {
        {"STORMPIKE_AID","DB_NORTH","DB_SOUTH","STORMPIKE_GY","STONEHEARTH","STONEHEARTH_GY","ICEWING"},
        {"RELIEF_HUT","WEST_FW","EAST_FW","FROSTWOLF_GY","ICEBLOOD_TOWER","ICEBLOOD_GY","TOWER_POINT"},
    }
    for _, group in ipairs(groups) do
        local base, north, south, rear = unpack(group)
        Check(sim.objectives[base].contestedAt < sim.objectives[north].contestedAt, "base before north/west tower")
        Check(sim.objectives[base].contestedAt < sim.objectives[south].contestedAt, "base before south/east tower")
        Check(sim.objectives[rear].contestedAt > math.max(sim.objectives[north].contestedAt, sim.objectives[south].contestedAt), "nearby GY after towers")
        for _, id in ipairs(group) do
            local objective = sim.objectives[id]
            Check(objective.phase == "captured", id .. " must complete")
            Check(math.abs(objective.capturedAt - objective.contestedAt - 300) < .06, "five-minute capture")
            local claimant, definition = objective.claimant
            for _, item in ipairs(TEST_OBJECTIVES) do if item.id == id then definition = item end end
            Check(claimant ~= nil and definition ~= nil, "captures require a physical claimant")
        end
    end
    Check(#sim.events == 28, "each of fourteen objectives contests and completes once")
    local startedNPC, killedNPCs = {}, 0
    for _, event in ipairs(sim.npcEvents) do
        if event.phase == "fighting" then
            Check(not startedNPC[event.key], "each honor NPC may start fighting only once")
            startedNPC[event.key] = event.at
        else
            Check(startedNPC[event.key] and event.at > startedNPC[event.key], "NPC must be fought before dying")
            killedNPCs = killedNPCs + 1
        end
    end
    Check(killedNPCs == 22, "both captain groups must finish all honor NPCs")
    Check(sim.npcs.VANNDAR.phase == "alive" and sim.npcs.DREKTHAR.phase == "alive", "armies gather without killing generals")
    local backtrackCount = {Horde=0, Alliance=0}
    local safeSHCurveCount = 0
    for _, agent in ipairs(sim.agents) do
        Check(agent.finished, "all squads must finish their routes")
        Check(not agent.mounted and Distance(agent.x, agent.y, agent.gatherX, agent.gatherY) < .000001,
            "completed players gather dismounted at their boss rally point")
        local boss = sim.npcs[agent.faction == "Horde" and "VANNDAR" or "DREKTHAR"]
        Check(Distance(agent.x, agent.y, boss.x/100, boss.y/100) < .018,
            "final rally must be immediately beside the enemy general")
        Check(agent.faction == "Horde" and agent.y > boss.y/100 or agent.faction == "Alliance" and agent.y < boss.y/100,
            "rally must be south of Vann / north of Drek")
        local visitedAid, visitedTower, undercut, rightOfIB = false, false, false, false
        local roadEast, bridge, aidVisits, backtrackVisited, lastNPC = false, false, 0, false, nil
        local caveRoadIndex, ibDetourIndex
        for _, point in ipairs(agent.route) do
            if point.value == "STORMPIKE_AID" or point.value == "RELIEF_HUT" then
                visitedAid = true
                aidVisits = aidVisits + 1
                if agent.role == "captain" then
                    Check(lastNPC == (agent.faction == "Horde" and "LONADIN" or "MULFORT"),
                        "captain squad finishes NPC sweep before joining Aid/Relief")
                end
            end
            if point.action == "npc" then lastNPC = point.value end
            if point.value == "ICEWING" or point.value == "TOWER_POINT" then
                Check(aidVisits == 1, "backtracking starts after first Aid/Relief visit")
                backtrackVisited = true
            end
            if point.value == agent.tower then visitedTower = true end
            if point.x == .588 and point.y == .270 then roadEast = true end
            if point.x == .459 and point.y == .154 then bridge = true end
            if agent.faction == "Horde" and point.x == .575 and point.y == .625 then caveRoadIndex = _ end
            if agent.faction == "Horde" and point.x == .620 and point.y == .578 then ibDetourIndex = _ end
            if agent.faction == "Horde" and point.x == .530 and point.y == .445 then
                safeSHCurveCount = safeSHCurveCount + 1
            end
            if agent.faction == "Horde" and point.y > .55 and point.y < .60 and point.x > .60 then rightOfIB = true end
            if agent.faction == "Horde" and point.action == "dismount" and point.x < .5186 and point.y > .3868 then undercut = true end
        end
        Check(visitedAid and visitedTower, "every squad rejoins the base/tower advance")
        if agent.faction == "Horde" then
            Check(rightOfIB, "Horde must pass east of IB GY")
            Check(caveRoadIndex and ibDetourIndex and caveRoadIndex < ibDetourIndex,
                "Horde must join the road before veering east of IB GY")
            Check(roadEast and bridge, "Horde road must pass east of Icewing and cross the bridge")
        end
        if agent.backtrack then
            backtrackCount[agent.faction] = backtrackCount[agent.faction] + 1
            Check(backtrackVisited and aidVisits == 2, "two riders assault rear bunker and rejoin Aid/Relief")
        else
            Check(not backtrackVisited, "only detached riders assault Icewing/Tower Point")
        end
        if agent.role == "captain" then
            Check(states[agent].fights >= 2 and states[agent].mounts >= 2, "captain group must fight and remount before later objectives")
            if agent.faction == "Horde" then Check(undercut, "Balinda approach must be below/left") end
        end
    end
    Check(backtrackCount.Horde == 2 and backtrackCount.Alliance == 2, "exactly two backtracking riders per faction")
    Check(safeSHCurveCount >= 30, "the large majority of Horde must take the wide Stonehearth avoidance curve")
    local hordeGYStops = 0
    for _, agent in ipairs(sim.teams.Horde) do
        local stopsAtSHGY = false
        for _, point in ipairs(agent.route) do
            if point.value == "SPENCER" then stopsAtSHGY = true end
        end
        if stopsAtSHGY then hordeGYStops = hordeGYStops + 1 end
    end
    Check(hordeGYStops == 1, "only the dedicated Horde GY scout stops for Stonehearth honor NPCs")
    for _, agent in ipairs(sim.teams.Horde) do
        if agent.baseMountIncrease == .6 then
            sim:SetFeatured(agent, true)
            Check(agent.mountIncrease == 1, "assigning Raid Boss upgrades a slow mount")
            Check(agent.mountMultiplier == 2*(1+agent.mountBonus), "upgraded mount retains original bonus")
            sim:SetFeatured(agent, false)
            Check(agent.mountIncrease == .6, "clearing assigned Raid Boss restores ordinary mount")
            break
        end
    end
end
print(string.format("AV simulation: %d checks plus per-step speed/channel checks passed for three complete matches.", checks))
