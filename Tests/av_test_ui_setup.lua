local frame, map, mapBorder = CreateFrame(), CreateFrame(), CreateFrame()
-- Use the real NPC renderer/state manager with bare marker frames, omitting
-- only the unrelated patrol artwork and secure-click setup from LT.Create.
ZurkMapsAVLieutenants.map=map
ZurkMapsAVLieutenants.mapBorder=mapBorder
ZurkMapsAVLieutenants.addonFrame=frame
for _,npc in ipairs(ZurkMapsAVLieutenants.data) do
    npc.blip=CreateFrame(nil,nil,map)
    npc.blip.texture=npc.blip:CreateTexture()
end
local friendlyPlayersClipFrame = CreateFrame(nil,nil,frame)
local friendlyPlayersFrame = CreateFrame(nil,nil,frame)
local MAP_WIDTH,MAP_HEIGHT,AV_FRIENDLY_PLAYER_DOT_SIZE=276,512,10
local AV_TEST_GOLD_R,AV_TEST_GOLD_G,AV_TEST_GOLD_B=1,.82,.18
local AVMapRank={iconScale=.924}
local manualVisibility, testPreviousManualVisibility, avTestSimulation
local avTestMode=false
local ResetObjectivesToInitial, RefreshObjectives, ApplyAVTestObjective
local avObjectiveTimers
local objectiveButtons={}
for _,objective in ipairs(OBJECTIVES) do
    local button=CreateFrame()
    button.icon=button:CreateTexture()
    objectiveButtons[objective.id]=button
end
local function IsInAlteracValley() return TEST_IN_AV end
local function IsInBattlegroundInstance() return false end
local function ClearTestHoverLock() end
local function ClearFriendlyPlayerTooltip() end
local function UpdateLivePlayerHitButtons() end
local function ApplyHonorBarVisibility() end
local function ApplyObjectiveTexture(texture,objective,index) texture.textureIndex=index end
local function GetAVUiMapID() return nil end
local function UpdateAVFriendlyPositionCalibration() return false end
local function IsDestroyedTowerState(objective,index) return objective.kind=="tower" and index==5 end
local fireCount=0
local function PlayTowerDestroyedEffect() fireCount=fireCount+1 end
