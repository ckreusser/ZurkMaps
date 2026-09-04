local F = {}
F.__index = F
TEST_FRAME_COUNT, TEST_NOW, TEST_IN_AV, TEST_CLASS_COLORS = 0, 0, false, true
function CreateFrame(_, _, parent)
    TEST_FRAME_COUNT = TEST_FRAME_COUNT + 1
    return setmetatable({parent=parent, scripts={}, shown=true, width=276, height=512}, F)
end
function F:GetParent() return self.parent end
function F:GetWidth() return self.width end
function F:GetHeight() return self.height end
function F:GetScale() return 1 end
function F:GetCenter() return 0,0 end
function F:SetSize(w,h) self.width,self.height=w,h end
function F:CreateTexture() return CreateFrame(nil,nil,self) end
function F:SetTexture(value) self.texturePath=value; self.textureWrites=(self.textureWrites or 0)+1 end
function F:SetVertexColor(...) self.color={...} end
function F:SetAlpha(value) self.alpha=value end
function F:SetScript(event,fn) self.scripts[event]=fn end
function F:SetFrameLevel(level) self.level=level end
function F:GetFrameLevel() return self.level or 1 end
function F:SetPoint(...) self.point={...} end
function F:Show() self.shown=true end
function F:Hide() self.shown=false end
function F:SetShown(value) self.shown=value end
function F:IsShown() return self.shown end
function F:SetValue(value) self.value=value end
for _, name in ipairs({"SetAllPoints","SetTexCoord","EnableMouse","RegisterForClicks","SetFrameStrata",
    "ClearAllPoints","RegisterEvent","SetBlendMode","SetMinMaxValues","SetStatusBarTexture",
    "SetStatusBarColor","SetAttribute","SetHeight","SetWidth"}) do F[name]=function() end end
UIParent,GameTooltip=CreateFrame(),CreateFrame()
SlashCmdList={}
function GetTime() return TEST_NOW end
function UnitFactionGroup() return "Horde" end
function SendChatMessage() error("simulation must never send chat") end
function GetNumMapLandmarks() return 1 end
function GetMapLandmarkInfo() return "Stonehearth Graveyard","Horde controlled",12,.6,.35 end
ZurkMapsOptions={UseClassBlips=function() return TEST_CLASS_COLORS end}
ZurkMapsPlayerIcons={
    RAID_BOSS_ICON_ID=9,manualIconScale=.84,testAssignments={},
    AssignKey=function(key,icon,isTest)
        assert(isTest,"simulation must not change live assignments")
        ZurkMapsPlayerIcons.testAssignments[key]=icon
    end,
    GetAssignedIconForKey=function(key,isTest)
        assert(isTest); return ZurkMapsPlayerIcons.testAssignments[key]
    end,
    IsOverlayOnlyIcon=function(icon) return icon==10 end,
    HideEliteOverlay=function() end,
    ApplyAssignedIcon=function(blip,icon,size)
        blip:SetSize(size,size); blip.texture:SetTexture("assigned:"..icon)
    end,
}
ZurkMapsCaptureClock={
    Create=function(parent) return CreateFrame(nil,nil,parent) end,
    SetBorderExpansion=function() end,SetBorderColor=function() end,
    SetRemaining=function(box,remaining) box.remaining=remaining end,
    Complete=function(box,faction) box.completed=faction end,
    AnimateCompletion=function() return true end,
}
