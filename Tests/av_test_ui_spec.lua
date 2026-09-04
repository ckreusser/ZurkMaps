local checks=0
local function Check(value,message) assert(value,message); checks=checks+1 end
local function Tick(seconds)
    for _=1,math.floor(seconds/.05+.5) do
        TEST_NOW=TEST_NOW+.05
        testMovementFrame.scripts.OnUpdate(testMovementFrame,.05)
        if frame:IsShown() then avObjectiveTimers.updateFrame.scripts.OnUpdate(nil,.05) end
    end
end
local function TickUntil(predicate, seconds)
    for _=1,seconds*2 do
        if predicate() then return end
        Tick(.5)
    end
    Check(predicate(), "simulation did not reach expected state within timeout")
end
math.randomseed(42)
local liveBalinda=ZurkMapsAVLieutenants.GetState(11949)
liveBalinda.healthPct=72
SlashCmdList.AVCALLOUTS("test")
Check(avTestMode and frame:IsShown(),"test must start and open map")
Check(#avTestAgents==40,"only the friendly faction's 40 players are displayed")
local originalSimulation=avTestSimulation
local originalBlip=avTestBlips[1]
local countAfterStart=TEST_FRAME_COUNT
Check(testMovementFrame:GetParent()~=frame,"simulation must not be a child of the hideable map")
for _,rankIndex in ipairs({1,2,3,8}) do
    local agent,blip=avTestAgents[rankIndex],avTestBlips[rankIndex]
    Check(blip.texture.texturePath==ZurkMapsPlayerBlips.GetRankBadgeTexture(agent.pvpRankNumber,agent.classToken),
        "class recoloring must not replace rank helmet")
end
Check(avTestBlips[40].texture.texturePath=="assigned:9","Raid Boss must render")
Check(ZurkMapsAVLieutenants.GetDisplayState(11949).healthPct==100,"test NPCs start at full health")
local promoted
for _,agent in ipairs(avTestAgents) do if agent.mountIncrease==.6 then promoted=agent; break end end
ZurkMapsPlayerIcons.AssignKey(promoted.iconKey,9,true)
UpdateAVTestBlips()
Check(promoted.mountIncrease==1,"assigned Raid Boss icon must upgrade mount tier")
TEST_CLASS_COLORS=false
UpdateAVTestBlips()
Check(avTestBlips[2].texture.texturePath=="Interface\\PvPRankBadges\\PvPRank13","gold mode rank badge")
Check(avTestBlips[40].texture.texturePath=="assigned:9","Raid Boss must survive toggle")
TEST_CLASS_COLORS=true
TickUntil(function() return avTestSimulation.npcs.BALINDA.healthPct<95 end,240)
local balindaInfo=ZurkMapsAVLieutenants.byID[11949]
Check(balindaInfo.healthBar:IsShown() and balindaInfo.healthBar.value<95,
    "simulated NPC combat must render health loss outside AV")
local balindaTextureWrites=balindaInfo.blip.texture.textureWrites
TickUntil(function() return avTestSimulation.npcs.BALINDA.healthPct<50 end,90)
Check(balindaInfo.blip.texture.textureWrites==balindaTextureWrites,
    "health ticks must not repeatedly rebuild the NPC marker")
Check(not liveBalinda.dead and liveBalinda.healthPct==72,"displayed combat must leave live NPC health unchanged")
TickUntil(function() return avTestSimulation.objectives.STONEHEARTH_GY.phase=="contested" end,240)
local sh=FindObjective("Stonehearth Graveyard")
Check(sh.currentTexture==13,"SH GY must show the Horde contested icon")
Check(avObjectiveTimers.states[sh.id].endsAt>TEST_NOW,"test assault must start real timer renderer")
local endsAt=avObjectiveTimers.states[sh.id].endsAt
TEST_IN_AV=true
RefreshObjectives()
Check(sh.currentTexture==13,"live POI refresh must not overwrite rehearsal")
avObjectiveTimers.eventFrame.scripts.OnEvent(nil,"CHAT_MSG_ADDON","Capping","123-10~","INSTANCE_CHAT")
Check(avObjectiveTimers.states[sh.id].endsAt==endsAt and next(avObjectiveTimers.pendingZMCompatTimes)==nil,
    "live sync must not alter rehearsal timers")

SlashCmdList.AVCALLOUTS("hide")
Check(not frame:IsShown() and avTestMode,"hide must keep test enabled without reopening map")
local before=avTestSimulation.elapsed
Tick(1)
TickUntil(function() return avTestSimulation.objectives.STORMPIKE_AID.phase=="contested" end,240)
UpdateVisibility()
Check(not frame:IsShown(),"zone/visibility update must respect hidden test map")
Check(avTestSimulation.elapsed>before,"simulation must advance while hidden")
Check(avTestSimulation.objectives.STORMPIKE_AID.phase=="contested","hidden simulation must process objectives")
SlashCmdList.AVCALLOUTS("show")
Check(frame:IsShown() and avTestSimulation==originalSimulation,"reopen must resume same simulation")
Check(avTestBlips[1]==originalBlip,"reopen must reuse player blip frames")
Tick(900)
Check(sh.currentTexture==12,"finished GY must flip faction")
Check(FindObjective("Dun Baldar North Bunker").currentTexture==5,"finished bunker must burn")
Check(fireCount==8,"eight contested towers must play their destruction effects")
Check(ZurkMapsAVLieutenants.GetDisplayState(11949).dead,"NPC fight must display simulated death")
Check(ZurkMapsAVLieutenants.GetDisplayState(11949).transitioning and balindaInfo.blip.scripts.OnUpdate,
    "simulated NPC death must begin the real death transition")
balindaInfo.blip.scripts.OnUpdate(balindaInfo.blip,.83)
Check(balindaInfo.blip.texture.texturePath=="Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" and not balindaInfo.healthBar:IsShown(),
    "dead NPC must display the death skull and hide its health bar")
Check(balindaInfo.blip.texture.textureWrites==balindaTextureWrites+1,
    "NPC marker must change texture exactly once when it dies")
Check(not balindaInfo.blip.scripts.OnUpdate and balindaInfo.blip:IsShown(),
    "captain death skull must remain persistent like the live marker")
local spencerInfo=ZurkMapsAVLieutenants.byID[13138]
local spencerState=ZurkMapsAVLieutenants.GetDisplayState(13138)
Check(spencerState.dead and spencerState.transitioning and spencerInfo.blip.scripts.OnUpdate,
    "ordinary honor NPC must begin death transition")
spencerInfo.blip.scripts.OnUpdate(spencerInfo.blip,.83)
Check(spencerInfo.blip.texture.texturePath=="Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
    and spencerInfo.blip.scripts.OnUpdate,"ordinary NPC must show a fading death skull")
spencerInfo.blip.scripts.OnUpdate(spencerInfo.blip,5)
Check(spencerInfo.blip:IsShown() and spencerInfo.blip.alpha>0 and spencerInfo.blip.alpha<1,
    "ordinary death skull must fade gradually")
spencerInfo.blip.scripts.OnUpdate(spencerInfo.blip,5.1)
Check(not spencerInfo.blip:IsShown() and spencerState.deathSkullExpired,
    "ordinary death skull must disappear after the live ten-second fade")
Check(not liveBalinda.dead and liveBalinda.healthPct==72,"NPC test fight must not modify live state")
Check(not ZurkMapsAVLieutenants.GetDisplayState(11948).dead,"Vanndar must remain alive at rally")
for _,state in pairs(avObjectiveTimers.states) do Check(state.endsAt==nil,"completed timers must clear") end
SlashCmdList.AVCALLOUTS("hide")
SlashCmdList.AVCALLOUTS("test off")
Check(not avTestMode and avTestSimulation==nil and not frame:IsShown(),"stop must clear simulation and preserve requested closure")
Check(ZurkMapsAVLieutenants.GetDisplayState(11949)==liveBalinda,"stopping rehearsal must restore live NPC state")
Check(balindaInfo.blip.texture.texturePath=="Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
    "stopping rehearsal must restore the live NPC artwork")
ZurkMapsAVLieutenants.SetTestNPCHealth(11949,0)
Check(not liveBalinda.dead,"test health setter must do nothing outside test mode")
Check(sh.currentTexture==12,"stop in AV must restore live POI state")
Check(FindObjective("Dun Baldar North Bunker").currentTexture==10,"stop must clear simulated destroyed towers")
for _,state in pairs(avObjectiveTimers.states) do Check(state.endsAt==nil,"stop must reset simulated clocks") end
local countBeforeRestart=TEST_FRAME_COUNT
SlashCmdList.AVCALLOUTS("test")
Check(TEST_FRAME_COUNT==countBeforeRestart and avTestBlips[1]==originalBlip,"restarting test must not leak blip frames")
Check(avTestSimulation~=originalSimulation and avTestSimulation.elapsed==0,"restart must start fresh")
Check(sh.currentTexture==14,"new run must restore initial objective control")
Check(not ZurkMapsAVLieutenants.GetDisplayState(11949).dead and ZurkMapsAVLieutenants.GetDisplayState(11949).healthPct==100,
    "restarting rehearsal must restore NPCs")
print(string.format("AV UI integration: %d checks passed for icons, timers, live-state isolation, hide/show and restart.",checks))
