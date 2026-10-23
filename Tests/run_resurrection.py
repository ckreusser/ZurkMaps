"""Check resurrection clocks, animations, hover fades and independent map settings. Requires lupa."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for name in ('ZurkMaps_Resurrection.lua', 'ZurkMaps_AB.lua', 'ZurkMaps_WSG.lua', 'ZurkMaps_AV.lua', 'ZurkMaps_Options.lua'):
    lua.execute('assert(loadstring(...))', (root / name).read_text(encoding='utf-8-sig'))
    print('Lua 5.1 compile:', name)

lua.execute(r'''
now, inBG, testing, ghost, sample = 0, false, false, false, nil
db = {}
function GetTime() return now end
function GetAreaSpiritHealerTime() return sample end
function UnitIsGhost() return ghost end
function StaticPopup_Visible() return ghost and 'popup' or nil end
local methods = {}
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:Hide()
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:Show() self.shown = true end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:SetText(text) self.text = text end
function methods:SetPoint(...) self.point = {...} end
function methods:SetSize(w,h) self.width,self.height = w,h end
function methods:SetHeight(h) self.height=h end
function methods:GetHeight() return self.height or 400 end
function methods:SetScale(scale) self.scale=scale end
function methods:SetAlpha(alpha) self.alpha=alpha end
function methods:ClearAllPoints() self.point=nil end
function methods:SetFont(...) self.font = {...} end
function methods:SetTextColor(...) self.color = {...} end
function methods:SetWordWrap(value) self.wordWrap=value end
function methods:SetClipsChildren(value) self.clipsChildren=value end
function methods:GetFrameLevel() return 10 end
function methods:CreateTexture() return CreateFrame('Texture') end
function methods:CreateMaskTexture() return CreateFrame('MaskTexture') end
function methods:AddMaskTexture(mask) self.mask=mask end
function methods:CreateFontString() return CreateFrame('FontString') end
for _, name in ipairs({'SetFrameLevel','EnableMouse','SetAllPoints','SetColorTexture',
    'SetTexCoord','SetJustifyH','SetJustifyV','SetShadowColor','SetShadowOffset',
    'SetDesaturated','SetBlendMode','SetVertexColor','SetRotation'}) do
    methods[name]=function() end
end
function methods:SetTexture(texture) self.texture=texture end
function CreateFrame() return setmetatable({shown=true,scripts={},events={}}, {__index=methods}) end
GameTooltip = {
    IsOwned=function(self, owner) return self.owner == owner end,
    SetOwner=function(self, owner) self.owner=owner end,
    SetText=function(self,text) self.text=text end,
    AddLine=function() end, Show=function() end,
    Hide=function(self) self.owner=nil end,
}
ZurkMapsBattlecry = {CreateButtonBorder=function() return {FitContent=function(_,bg,icon) assert(bg and icon) end} end}
''')
lua.execute((root / 'ZurkMaps_Resurrection.lua').read_text())
lua.execute(r'''
clock = ZurkMapsResurrection.Create(CreateFrame(), CreateFrame(), {
    shoutButton=(function() local button=CreateFrame(); button:SetSize(45,45); return button end)(),
    getMapScale=function() return mapScale or 1 end,
    getDB=function() return db end,
    isInBattleground=function() return inBG end,
    isTestMode=function() return testing end,
})
function event(name) clock.driver.scripts.OnEvent(clock.driver, name) end
function tick(time) now=time; clock.driver.scripts.OnUpdate(clock.driver, 0.1) end
function digits() return clock.timerText.text end
assert(not clock:IsShown())
testing=true; tick(0); assert(clock:IsShown() and digits()=='30')
tick(20); assert(digits()=='10')
tick(21); assert(digits()=='9' and clock.timerText.point[4]==0)
mapScale=0.55; clock:Refresh(); assert(clock.timerText.point[4]==0)
mapScale=1; clock:Refresh()
tick(29); assert(digits()=='1' and clock.timerText.point[4]==0)
tick(30); assert(digits()=='30')
assert(clock.timerText.point[4]==0 and clock.timerText.point[5]==0)
assert(clock.icon.texture=='Interface\\RaidFrame\\Raid-Icon-Rez')
assert(clock.point[1]=='CENTER' and clock.point[3]=='BOTTOM' and clock.point[5]==29.5)
for _, scale in ipairs({0.55, 0.75, 1, 1.5, 2}) do
    mapScale=scale; clock:Refresh()
    local displayScale=scale*clock.scale
    assert(clock.scale==1 and displayScale==scale)
    assert(clock.timerText.font[2]*displayScale>=11)
    assert(clock.timerText.point[4]==0 and clock.timerText.point[5]==0)
    assert(clock.timerText.width==clock.width and clock.timerText.height==clock.timerText.font[2]*2)
    assert(clock.timerText.wordWrap==false)
    assert(clock.point[5]==29.5)
end
mapScale=1; clock:Refresh()
assert(clock.timerText.color[1]==1 and clock.timerText.color[2]==1 and clock.timerText.color[3]==0)
clock:SetEnabled(false); assert(not clock:IsShown() and db.showResurrectionTimer==false)
clock:SetEnabled(true); assert(clock:IsShown())
testing=false; inBG=true; event('PLAYER_ENTERING_WORLD'); assert(digits()=='--')
sample=0; ghost=true; event('AREA_SPIRIT_HEALER_IN_RANGE'); tick(31); assert(digits()=='--')
sample=20; tick(32); assert(digits()=='20')
tick(33); assert(digits()=='19') -- unchanged API snapshot must not freeze timer
sample=18; tick(34); assert(digits()=='18')
ghost=false; event('PLAYER_UNGHOST'); tick(53); assert(digits()=='29' and clock.estimated)
local savedDeadline=clock.liveDeadline
testing=true; tick(54); assert(digits()=='30')
testing=false; tick(55); assert(clock.liveDeadline==savedDeadline and digits()=='27')
assert(clock.fill.alpha==0.60)
clock.scripts.OnEnter(clock); assert(not GameTooltip:IsOwned(clock) and clock.fill.alpha==1)
clock:SetEnabled(false); assert(not clock:IsShown() and not GameTooltip:IsOwned(clock) and clock.fill.alpha==0.60)
clock:SetEnabled(true); assert(clock:IsShown())
inBG=false; tick(56); assert(not clock:IsShown() and clock.liveDeadline==nil)
inBG=true; tick(57); assert(digits()=='--')
ghost=true; sample=12; event('PLAYER_ENTERING_WORLD'); tick(58); assert(digits()=='12')
assert(clock.driver.events.AREA_SPIRIT_HEALER_IN_RANGE)
assert(clock.driver.events.AREA_SPIRIT_HEALER_OUT_OF_RANGE)
testing=true; tick(100); assert(clock.fillProgress==0 and clock.shine.alpha==0)
assert(clock.fill.mask==clock.fillMask and clock.fill.width==36 and clock.fill.height==36)
for _, time in ipairs({127,128,129,129.5,129.9}) do
    tick(time)
    assert(clock.fill.width==36 and clock.fill.height==36)
    assert(clock.fill.point[1]=='BOTTOMLEFT' and clock.fill.point[4]==0 and clock.fill.point[5]==0)
    assert(clock.fillClip.height==36)
    assert(math.abs(clock.fillMask.point[5]-(-2+40*clock.fillProgress))<0.001)
end
tick(115); assert(math.abs(clock.fillProgress-0.5)<0.001)
local previousMaskY=clock.fillMask.point[5]
for frame=1,10 do
    now=115+frame/60; clock:UpdateEffects()
    local maskY=clock.fillMask.point[5]
    assert(maskY>previousMaskY and maskY-previousMaskY<0.03)
    previousMaskY=maskY
end
tick(129); assert(clock.fillProgress>0.96)
tick(130); assert(clock.completionStrength==1)
tick(130.2); assert(clock.shine.alpha>0.5 and clock.completionStrength==1)
tick(131.5); assert(clock.completionStrength==1 and clock.completed.alpha==0.60)
tick(131.75); assert(clock.completionStrength>0 and clock.completionStrength<1)
tick(132); assert(clock.shine.alpha==0 and clock.fillProgress<0.1)
assert(clock.completed.alpha==0 and clock.icon.alpha==0.50)
clock:SetEnabled(false); tick(160); clock:SetEnabled(true)
assert(clock.shine.alpha==0) -- no completion flash from an unseen cycle
testing=false; ghost=true; sample=1; event('AREA_SPIRIT_HEALER_IN_RANGE'); tick(161)
sample=30; tick(162); tick(162.2); assert(clock.shine.alpha>0)
tick(164); assert(clock.shine.alpha==0)
clock.scripts.OnEnter(clock)
assert(clock.textLayer.alpha==0)
now=164.06; clock:UpdateEffects(); assert(clock.textLayer.alpha>0 and clock.textLayer.alpha<1)
now=164.13; clock:UpdateEffects(); assert(clock.textLayer.alpha==1)
clock.scripts.OnLeave(clock)
now=164.19; clock:UpdateEffects(); assert(clock.textLayer.alpha>0 and clock.textLayer.alpha<1)
local partialAlpha=clock.textLayer.alpha
clock.scripts.OnEnter(clock); assert(clock.textLayer.alpha==partialAlpha)
now=164.32; clock:UpdateEffects(); assert(clock.textLayer.alpha==1)
clock.scripts.OnLeave(clock); now=164.45; clock:UpdateEffects(); assert(clock.textLayer.alpha==0)
local wsgDB, wsgTesting, wsgLive = {}, false, false
local wsgClock=ZurkMapsResurrection.Create(CreateFrame(),CreateFrame(),{
    getMapScale=function() return 0.55 end,
    getPosition=function() return 334*0.26,444*0.08 end,
    getDB=function() return wsgDB end,
    isTestMode=function() return wsgTesting end,
    isInBattleground=function() return wsgLive end,
})
assert(not wsgClock:IsShown())
wsgTesting=true; wsgClock:Refresh()
assert(wsgClock:IsShown() and wsgClock.timerText.text=='30')
assert(wsgClock.point[4]==334*0.26 and wsgClock.point[5]==444*0.08)
wsgClock:SetEnabled(false); assert(not wsgClock:IsShown() and clock:IsEnabled())
clock:SetEnabled(false); wsgClock:SetEnabled(true)
assert(wsgClock:IsShown() and not clock:IsEnabled())
now=179.45; wsgClock:Refresh(); assert(wsgClock.timerText.text=='15')
wsgTesting=false; wsgClock:Refresh(); assert(not wsgClock:IsShown())
wsgLive=true; wsgClock:Refresh(); assert(wsgClock:IsShown() and wsgClock.timerText.text=='--')
wsgClock.scripts.OnEnter(wsgClock); assert(not GameTooltip:IsOwned(wsgClock))
wsgClock:SetEnabled(false); assert(wsgDB.showResurrectionTimer==false and wsgClock.textLayer.alpha==0)
local avDB, avTesting, avLive = {}, false, false
local avClock=ZurkMapsResurrection.Create(CreateFrame(),CreateFrame(),{
    getMapScale=function() return 0.65 end,
    getPosition=function() return 7+33/2-280/2,516*0.12 end,
    getDB=function() return avDB end,
    isTestMode=function() return avTesting end,
    isInBattleground=function() return avLive end,
})
assert(not avClock:IsShown())
avTesting=true; avClock:Refresh()
assert(avClock:IsShown() and avClock.timerText.text=='30')
assert(avClock.point[4]==-116.5 and math.abs(avClock.point[5]-61.92)<0.001)
avClock:SetEnabled(false); assert(not avClock:IsShown() and avDB.showResurrectionTimer==false)
avClock:SetEnabled(true); assert(avClock:IsShown() and not wsgClock:IsEnabled() and not clock:IsEnabled())
avTesting=false; avClock:Refresh(); assert(not avClock:IsShown())
avLive=true; avClock:Refresh(); assert(avClock:IsShown() and avClock.timerText.text=='--')
''')
print('PASS: countdown, rollover, stable digits, yellow text, toggle, sync, stale snapshots, test/live transitions, tooltip cleanup, zone reset and ghost reload')
