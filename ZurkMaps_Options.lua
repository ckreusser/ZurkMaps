-- Shared right-click options menu and battleground callout-channel routing.
ZurkMapsOptions = ZurkMapsOptions or {}

local Options = ZurkMapsOptions
Options.maps = Options.maps or {}
Options.menu = Options.menu or nil
Options.dismiss = Options.dismiss or nil

local BG_R, BG_G, BG_B = 1.00, 0.48, 0.02
local RW_R, RW_G, RW_B = 1.00, 0.22, 0.06
local BORDER_R, BORDER_G, BORDER_B = 0.84, 0.56, 0.31
local MENU_BORDER_R, MENU_BORDER_G, MENU_BORDER_B = 0.56, 0.56, 0.56
local MENU_LEAVE_GRACE = 0.50

local function GetChatColor(chatType, fallbackR, fallbackG, fallbackB)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if info and type(info.r) == "number" and type(info.g) == "number" and type(info.b) == "number" then
        return info.r, info.g, info.b
    end
    return fallbackR, fallbackG, fallbackB
end

function Options.RegisterMap(mapKey, config)
    if not mapKey or type(config) ~= "table" then return end
    Options.maps[mapKey] = config
    if config.db and config.db.calloutChannel ~= "RW" then
        config.db.calloutChannel = "BG"
    end
end

function Options.GetCalloutChannel(mapKey)
    local config = Options.maps[mapKey]
    local db = config and config.db
    return db and db.calloutChannel == "RW" and "RW" or "BG"
end

function Options.SetCalloutChannel(mapKey, value)
    local config = Options.maps[mapKey]
    if not config or not config.db then return end
    config.db.calloutChannel = value == "RW" and "RW" or "BG"
end

function Options.CanUseRaidWarning()
    if not (IsInRaid and IsInRaid()) then return false end
    return (UnitIsGroupLeader and UnitIsGroupLeader("player"))
        or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
end

local function SendChatCompat(message, chatType)
    if not message or message == "" then return false end
    chatType = chatType or "SAY"
    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        local ok = pcall(C_ChatInfo.SendChatMessage, { message = message, chatType = chatType })
        if ok then return true end
        ok = pcall(C_ChatInfo.SendChatMessage, message, chatType)
        if ok then return true end
    end
    if type(SendChatMessage) == "function" then
        local ok = pcall(SendChatMessage, message, chatType)
        if ok then return true end
    end
    return false
end

function Options.SendInstanceChat(message)
    SendChatCompat(message, "INSTANCE_CHAT")
end

function Options.SendCallout(mapKey, message)
    if not message or message == "" then return end
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "pvp" then
        if Options.GetCalloutChannel(mapKey) == "RW" and Options.CanUseRaidWarning() then
            SendChatCompat(message, "RAID_WARNING")
        else
            SendChatCompat(message, "INSTANCE_CHAT")
        end
    else
        SendChatCompat(message, "SAY")
    end
end

function Options.SendHeaderShare(message)
    if not message or message == "" then return end
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "pvp" then
        SendChatCompat(message, "INSTANCE_CHAT")
    else
        SendChatCompat(message, "SAY")
    end
end

local function ApplyAtlas(texture, atlasName, r, g, b, a, useAtlasSize)
    r, g, b, a = r or BORDER_R, g or BORDER_G, b or BORDER_B, a or 0.98
    texture:SetVertexColor(r, g, b, a)
    if texture.SetAtlas then
        texture:SetAtlas(atlasName, useAtlasSize and true or false)
    else
        texture:SetColorTexture(r, g, b, a)
    end
end

local function PositionMenuAtCursor(menu)
    if not menu then return end
    menu:ClearAllPoints()
    local scale = UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()
    x = x / scale
    y = y / scale
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 18, y + 18)
end

local function EnsureDismissFrame()
    if Options.dismiss then return Options.dismiss end
    local dismiss = CreateFrame("Button", "ZurkMapsOptionsDismiss", UIParent)
    dismiss:SetAllPoints(UIParent)
    dismiss:SetFrameStrata("DIALOG")
    dismiss:SetFrameLevel(89)
    dismiss:EnableMouse(true)
    dismiss:RegisterForClicks("AnyUp")
    dismiss:SetScript("OnClick", function()
        GameTooltip:Hide()
        if Options.menu then Options.menu:Hide() end
        dismiss:Hide()
    end)
    dismiss:Hide()
    Options.dismiss = dismiss
    return dismiss
end

local function CreateMenuButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(18)
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    button.text:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetTextColor(1, 1, 1, 1)
    button:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1.0, 0.90, 0.40, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self.text:SetTextColor(1, 1, 1, 1)
    end)
    return button
end

local function CreateDivider(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.52, 0.52, 0.52, 0.52)
    return line
end

local ShowChannelTooltip, SetChannelHover

local function EnsureMenuFrame()
    if Options.menu then return Options.menu end

    local frame = CreateFrame("Frame", "ZurkMapsOptionsMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(140, 144)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(90)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 20,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
        frame:SetBackdropColor(0.0, 0.0, 0.0, 0.998)
        frame:SetBackdropBorderColor(0.62, 0.62, 0.62, 0.95)
    end

    frame.opaqueBG = frame:CreateTexture(nil, "BACKGROUND")
    frame.opaqueBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    frame.opaqueBG:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    frame.opaqueBG:SetColorTexture(0, 0, 0, 0.96)

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont("Fonts\\FRIZQT__.TTF", 13)
    frame.title:SetText("Options")
    frame.title:SetTextColor(1.0, 0.84, 0.15, 1)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -10)

    frame.headerDivider = CreateDivider(frame)
    frame.headerDivider:ClearAllPoints()
    frame.headerDivider:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
    frame.headerDivider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -11, -29)
    frame.headerDivider:Show()

    frame.channelLabel = frame:CreateFontString(nil, "OVERLAY")
    frame.channelLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.channelLabel:SetText("Callout Channel:")
    frame.channelLabel:SetTextColor(0.72, 0.72, 0.72, 1)
    frame.channelLabel:SetJustifyH("LEFT")
    frame.channelLabel:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -14)

    frame.switchRow = CreateFrame("Frame", nil, frame)
    frame.switchRow:SetSize(112, 20)
    frame.switchRow:SetPoint("TOP", frame, "TOP", 0, -48)

    frame.leftLabel = frame.switchRow:CreateFontString(nil, "OVERLAY")
    frame.leftLabel:SetFont("Fonts\\FRIZQT__.TTF", 12)
    frame.leftLabel:SetText("/bg")
    frame.leftLabel:SetShadowColor(0, 0, 0, 1)
    frame.leftLabel:SetShadowOffset(1, -1)
    frame.leftLabel:SetPoint("LEFT", frame.switchRow, "LEFT", 0, 0)

    frame.switchTrack = CreateFrame("Frame", nil, frame.switchRow, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.switchTrack:SetSize(42, 16)
    frame.switchTrack:SetPoint("CENTER", frame.switchRow, "CENTER", -2, 0)
    frame.leftLabel:ClearAllPoints()
    frame.leftLabel:SetPoint("RIGHT", frame.switchTrack, "LEFT", -4, -1)
    if frame.switchTrack.SetBackdrop then
        frame.switchTrack:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame.switchTrack:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        frame.switchTrack:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.90)
    end

    frame.switchTrack.inner = frame.switchTrack:CreateTexture(nil, "ARTWORK")
    frame.switchTrack.inner:SetPoint("TOPLEFT", frame.switchTrack, "TOPLEFT", 2, -2)
    frame.switchTrack.inner:SetPoint("BOTTOMRIGHT", frame.switchTrack, "BOTTOMRIGHT", -2, 2)
    frame.switchTrack.inner:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    frame.switchTrack.inner:SetVertexColor(0.01, 0.01, 0.01, 1.00)

    frame.switchTrack.thumbPlate = frame.switchTrack:CreateTexture(nil, "OVERLAY")
    frame.switchTrack.thumbPlate:SetSize(0, 0)
    frame.switchTrack.thumbPlate:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    frame.switchTrack.thumbPlate:SetVertexColor(0.26, 0.26, 0.28, 0.00)
    frame.switchTrack.thumbPlate:Hide()

    frame.switchTrack.thumb = frame.switchTrack:CreateTexture(nil, "OVERLAY")
    frame.switchTrack.thumb:SetSize(20, 12)
    if frame.switchTrack.thumb.SetAtlas then
        frame.switchTrack.thumb:SetAtlas("wowlabs-switch-slots-key", false)
    end
    frame.switchTrack.thumb:SetBlendMode("BLEND")
    frame.switchTrack.thumb:SetVertexColor(1, 1, 1, 1)
    frame.switchTrack.thumb:SetAlpha(0.98)

    frame.rightLabel = frame.switchRow:CreateFontString(nil, "OVERLAY")
    frame.rightLabel:SetFont("Fonts\\FRIZQT__.TTF", 12)
    frame.rightLabel:SetText("/RW")
    frame.rightLabel:SetShadowColor(0, 0, 0, 1)
    frame.rightLabel:SetShadowOffset(1, -1)
    frame.rightLabel:SetPoint("LEFT", frame.switchTrack, "RIGHT", 4, -1)

    frame.switchClickArea = CreateFrame("Button", nil, frame)
    frame.switchClickArea:ClearAllPoints()
    frame.switchClickArea:SetPoint("TOPLEFT", frame.channelLabel, "TOPLEFT", -2, 2)
    frame.switchClickArea:SetPoint("BOTTOMRIGHT", frame.switchRow, "BOTTOMRIGHT", 2, -2)
    frame.switchClickArea:RegisterForClicks("LeftButtonUp")
    frame.switchClickArea:SetFrameLevel(frame.switchRow:GetFrameLevel() + 10)
    frame.switchClickArea:SetScript("OnEnter", function(self)
        SetChannelHover(frame, true)
        ShowChannelTooltip(self)
    end)
    frame.switchClickArea:SetScript("OnLeave", function()
        SetChannelHover(frame, false)
        GameTooltip:Hide()
    end)

    frame.honorRow = CreateFrame("Frame", nil, frame)
    frame.honorRow:SetSize(116, 18)
    frame.honorLabel = frame.honorRow:CreateFontString(nil, "OVERLAY")
    frame.honorLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.honorLabel:SetText("Honor Bar")
    frame.honorLabel:SetTextColor(1, 1, 1, 1)
    frame.honorLabel:SetPoint("LEFT", frame.honorRow, "LEFT", 0, 0)

    frame.honorModeValue = frame.honorRow:CreateFontString(nil, "OVERLAY")
    frame.honorModeValue:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.honorModeValue:SetPoint("RIGHT", frame.honorRow, "RIGHT", 0, 0)
    frame.honorModeValue:SetJustifyH("RIGHT")

    frame.honorToggle = CreateFrame("CheckButton", nil, frame.honorRow, "UICheckButtonTemplate")
    frame.honorToggle:SetSize(1, 1)
    frame.honorToggle:Hide()
    frame.honorToggle:EnableMouse(false)

    frame.honorClickArea = CreateFrame("Button", nil, frame.honorRow)
    frame.honorClickArea:SetAllPoints(frame.honorRow)
    frame.honorClickArea:RegisterForClicks("LeftButtonUp")
    frame.honorClickArea:SetFrameLevel(frame.honorRow:GetFrameLevel() + 10)
    frame.honorClickArea:SetScript("OnEnter", function(self)
        frame.honorLabel:SetTextColor(1.0, 0.90, 0.40, 1)
        if frame.honorModeValue then frame.honorModeValue:SetTextColor(1.0, 0.90, 0.40, 1) end
        GameTooltip:Hide()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Honor Bar Mode")
        GameTooltip:AddLine("Off: hidden everywhere.", 0.78, 0.78, 0.78, true)
        GameTooltip:AddLine("Attached: follows the active Zurk Map.", 0.78, 0.78, 0.78, true)
        GameTooltip:AddLine("Persistent: stays on your UI outside battlegrounds.", 0.78, 0.78, 0.78, true)
        GameTooltip:AddLine("Click to cycle modes.", 1.0, 0.82, 0.20, true)
        GameTooltip:Show()
    end)
    frame.honorClickArea:SetScript("OnLeave", function()
        frame.honorLabel:SetTextColor(1, 1, 1, 1)
        if frame.honorModeValue then
            local mode = frame.honorBarMode or "ATTACHED"
            if mode == "OFF" then
                frame.honorModeValue:SetTextColor(0.55, 0.55, 0.55, 1)
            elseif mode == "PERSISTENT" then
                frame.honorModeValue:SetTextColor(1.0, 0.82, 0.20, 1)
            else
                frame.honorModeValue:SetTextColor(0.82, 0.82, 0.82, 1)
            end
        end
        GameTooltip:Hide()
    end)
    frame.honorRow:Hide()

    frame.honorUnlockRow = CreateFrame("Frame", nil, frame)
    frame.honorUnlockRow:SetSize(116, 18)
    frame.honorUnlockLabel = frame.honorUnlockRow:CreateFontString(nil, "OVERLAY")
    frame.honorUnlockLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.honorUnlockLabel:SetText("Unlock Honor Bar")
    frame.honorUnlockLabel:SetTextColor(1, 1, 1, 1)
    frame.honorUnlockLabel:SetPoint("LEFT", frame.honorUnlockRow, "LEFT", 0, 0)

    frame.honorUnlockToggle = CreateFrame("CheckButton", nil, frame.honorUnlockRow, "UICheckButtonTemplate")
    frame.honorUnlockToggle:SetSize(20, 20)
    frame.honorUnlockToggle:SetPoint("LEFT", frame.honorUnlockLabel, "RIGHT", 4, 0)
    frame.honorUnlockToggle:SetChecked(false)
    frame.honorUnlockToggle:EnableMouse(false)
    frame.honorUnlockClickArea = CreateFrame("Button", nil, frame.honorUnlockRow)
    frame.honorUnlockClickArea:SetAllPoints(frame.honorUnlockRow)
    frame.honorUnlockClickArea:RegisterForClicks("LeftButtonUp")
    frame.honorUnlockClickArea:SetFrameLevel(frame.honorUnlockRow:GetFrameLevel() + 10)
    frame.honorUnlockClickArea:SetScript("OnEnter", function()
        frame.honorUnlockLabel:SetTextColor(1.0, 0.90, 0.40, 1)
    end)
    frame.honorUnlockClickArea:SetScript("OnLeave", function()
        frame.honorUnlockLabel:SetTextColor(1, 1, 1, 1)
    end)
    frame.honorUnlockRow:Hide()

    frame.testRow = CreateFrame("Frame", nil, frame)
    frame.testRow:SetSize(116, 18)
    frame.testLabel = frame.testRow:CreateFontString(nil, "OVERLAY")
    frame.testLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.testLabel:SetText("Test Mode")
    frame.testLabel:SetTextColor(1, 1, 1, 1)
    frame.testLabel:SetPoint("LEFT", frame.testRow, "LEFT", 0, 0)

    frame.testToggle = CreateFrame("CheckButton", nil, frame.testRow, "UICheckButtonTemplate")
    frame.testToggle:SetSize(20, 20)
    frame.testToggle:SetPoint("LEFT", frame.testLabel, "RIGHT", 4, 0)
    frame.testToggle:SetChecked(false)
    frame.testToggle:EnableMouse(false)
    frame.testClickArea = CreateFrame("Button", nil, frame.testRow)
    frame.testClickArea:SetAllPoints(frame.testRow)
    frame.testClickArea:RegisterForClicks("LeftButtonUp")
    frame.testClickArea:SetFrameLevel(frame.testRow:GetFrameLevel() + 10)
    frame.testClickArea:SetScript("OnEnter", function()
        frame.testLabel:SetTextColor(1.0, 0.90, 0.40, 1)
    end)
    frame.testClickArea:SetScript("OnLeave", function()
        frame.testLabel:SetTextColor(1, 1, 1, 1)
    end)
    frame.honorRow:Hide()
    frame.testRow:Hide()

    frame.dividers = { CreateDivider(frame), CreateDivider(frame) }
    frame.buttons = {}
    for i = 1, 8 do
        frame.buttons[i] = CreateMenuButton(frame)
    end
    frame.closeButton = CreateMenuButton(frame)
    frame.closeButton.text:SetText("Close Map")

    frame:SetScript("OnMouseUp", nil)
    frame:SetScript("OnShow", function(self)
        self.leaveElapsed = 0
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        local hovered = false
        if self.IsMouseOver then
            hovered = self:IsMouseOver()
        elseif MouseIsOver then
            hovered = MouseIsOver(self)
        end

        if hovered then
            self.leaveElapsed = 0
            return
        end

        self.leaveElapsed = (self.leaveElapsed or 0) + (elapsed or 0)
        if self.leaveElapsed >= MENU_LEAVE_GRACE then
            self.leaveElapsed = 0
            self:Hide()
        end
    end)
    frame:SetScript("OnHide", function(self)
        self.leaveElapsed = 0
        SetChannelHover(frame, false)
        GameTooltip:Hide()
        if Options.dismiss then Options.dismiss:Hide() end
    end)

    Options.menu = frame
    return frame
end

local function UpdateSwitchVisuals(frame)
    local selected = frame.currentChannel or "BG"
    local OFF_R, OFF_G, OFF_B = 0.43, 0.43, 0.43

    if selected == "RW" then
        frame.leftLabel:SetTextColor(OFF_R, OFF_G, OFF_B, 1)
        frame.rightLabel:SetTextColor(RW_R, RW_G, RW_B, 1)
        frame.switchTrack.thumb:ClearAllPoints()
        frame.switchTrack.thumb:SetPoint("CENTER", frame.switchTrack, "CENTER", 9, 0)
    else
        frame.leftLabel:SetTextColor(BG_R, BG_G, BG_B, 1)
        frame.rightLabel:SetTextColor(OFF_R, OFF_G, OFF_B, 1)
        frame.switchTrack.thumb:ClearAllPoints()
        frame.switchTrack.thumb:SetPoint("CENTER", frame.switchTrack, "CENTER", -9, 0)
    end

    frame.switchTrack.thumb:SetVertexColor(1, 1, 1, 1)
    frame.switchTrack.thumb:SetAlpha(0.98)
end

local function UpdateTestToggleVisuals(frame)
    if not frame.testRow then return end
    local active = frame.testModeActive and true or false
    if frame.testToggle and frame.testToggle.SetChecked then
        frame.testToggle:SetChecked(active)
    end
end

local function GetHonorBarMode(config)
    if config and type(config.getHonorBarMode) == "function" then
        local mode = config.getHonorBarMode()
        if mode == "OFF" or mode == "ATTACHED" or mode == "PERSISTENT" then return mode end
    end
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.GetMode then
        return ZurkMapsHonorWidget.GetMode()
    end
    if config and type(config.isHonorBarVisible) == "function" and not config.isHonorBarVisible() then return "OFF" end
    return "ATTACHED"
end

local function SetHonorBarMode(config, mapKey, mode)
    if config and type(config.setHonorBarMode) == "function" then
        config.setHonorBarMode(mode)
    elseif ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetMode then
        ZurkMapsHonorWidget.SetMode(mode, mapKey)
    elseif config and type(config.setHonorBarVisible) == "function" then
        config.setHonorBarVisible(mode ~= "OFF")
    end
end

local function UpdateHonorToggleVisuals(frame)
    if not frame.honorRow then return end
    local mode = frame.honorBarMode or "ATTACHED"
    if frame.honorLabel then frame.honorLabel:SetText("Honor Bar") end
    if frame.honorModeValue then
        local label = mode == "OFF" and "Off" or (mode == "PERSISTENT" and "Persistent" or "Attached")
        frame.honorModeValue:SetText(label)
        if mode == "OFF" then
            frame.honorModeValue:SetTextColor(0.55, 0.55, 0.55, 1)
        elseif mode == "PERSISTENT" then
            frame.honorModeValue:SetTextColor(1.0, 0.82, 0.20, 1)
        else
            frame.honorModeValue:SetTextColor(0.82, 0.82, 0.82, 1)
        end
    end
end

local function UpdateHonorUnlockVisuals(frame)
    if not frame.honorUnlockRow then return end
    local active = frame.honorBarUnlocked and true or false
    if frame.honorUnlockToggle and frame.honorUnlockToggle.SetChecked then
        frame.honorUnlockToggle:SetChecked(active)
    end
end

local function IsTestModeActive(config)
    if config and type(config.isTestModeActive) == "function" then
        return config.isTestModeActive() and true or false
    end
    return false
end

local function IsHonorBarVisible(config)
    return GetHonorBarMode(config) ~= "OFF"
end

local function IsHonorBarUnlocked(config)
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.IsUnlocked then
        return ZurkMapsHonorWidget.IsUnlocked() and true or false
    end
    if config and type(config.isHonorBarUnlocked) == "function" then
        return config.isHonorBarUnlocked() and true or false
    end
    return false
end

local function SetCurrentChannel(frame, value)
    if not frame.mapKey then return end
    local nextValue = value == "RW" and "RW" or "BG"
    Options.SetCalloutChannel(frame.mapKey, nextValue)
    frame.currentChannel = nextValue
    UpdateSwitchVisuals(frame)
end

local function ToggleCurrentChannel(frame)
    if not frame.mapKey then return end
    local current = Options.GetCalloutChannel(frame.mapKey)
    local nextValue = current == "RW" and "BG" or "RW"
    Options.SetCalloutChannel(frame.mapKey, nextValue)
    frame.currentChannel = nextValue
    UpdateSwitchVisuals(frame)
end

ShowChannelTooltip = function(owner)
    -- Force a clean rebuild so adding/removing the optional note recalculates
    -- tooltip height immediately instead of retaining the previous layout.
    GameTooltip:Hide()
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    else
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 95)
    end
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Callout Channel Toggle", 1.0, 0.82, 0.0)

    local showNote = Options.menu and Options.menu.currentChannel == "RW"
    if showNote then
        GameTooltip:AddLine("Note: Will callout in /bg without Leader/Assist", 0.72, 0.78, 0.90, true)
        local note = _G[GameTooltip:GetName() .. "TextLeft2"]
        if note then
            if GameTooltipTextSmall then
                note:SetFontObject(GameTooltipTextSmall)
            end
            note:SetTextColor(0.72, 0.78, 0.90, 1)
        end
    end

    GameTooltip:Show()
end

SetChannelHover = function(frame, hovered)
    if not frame or not frame.channelLabel or not frame.switchTrack then return end
    if hovered then
        frame.channelLabel:SetTextColor(1.0, 0.90, 0.40, 1)
        if frame.switchTrack.SetBackdropBorderColor then
            frame.switchTrack:SetBackdropBorderColor(0.75, 0.75, 0.75, 0.95)
        end
    else
        frame.channelLabel:SetTextColor(0.72, 0.72, 0.72, 1)
        if frame.switchTrack.SetBackdropBorderColor then
            frame.switchTrack:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.90)
        end
    end
end

local function BuildMenu(frame, config)
    frame.mapKey = config.mapKey
    frame.config = config
    frame.title:SetText("Options")
    frame.currentChannel = Options.GetCalloutChannel(frame.mapKey)
    frame.testModeActive = IsTestModeActive(config)
    frame.honorBarMode = GetHonorBarMode(config)
    frame.honorBarVisible = frame.honorBarMode ~= "OFF"
    frame.honorBarUnlocked = IsHonorBarUnlocked(config)
    UpdateSwitchVisuals(frame)
    UpdateHonorToggleVisuals(frame)
    UpdateHonorUnlockVisuals(frame)
    UpdateTestToggleVisuals(frame)

    frame.switchClickArea:SetScript("OnClick", function()
        ToggleCurrentChannel(frame)
        if frame.switchClickArea:IsMouseOver() then
            ShowChannelTooltip(frame.switchClickArea)
        end
    end)
    frame.honorClickArea:SetScript("OnClick", function()
        local current = frame.honorBarMode or "ATTACHED"
        local nextMode = current == "OFF" and "ATTACHED" or (current == "ATTACHED" and "PERSISTENT" or "OFF")
        SetHonorBarMode(config, frame.mapKey, nextMode)
        frame.honorBarMode = GetHonorBarMode(config)
        frame.honorBarVisible = frame.honorBarMode ~= "OFF"
        frame.honorBarUnlocked = IsHonorBarUnlocked(config)
        BuildMenu(frame, config)
    end)

    frame.honorUnlockClickArea:SetScript("OnClick", function()
        frame.honorBarUnlocked = not frame.honorBarUnlocked
        if ZurkMapsHonorWidget and ZurkMapsHonorWidget.SetGlobalUnlocked then
            ZurkMapsHonorWidget.SetGlobalUnlocked(frame.honorBarUnlocked)
        elseif type(config.setHonorBarUnlocked) == "function" then
            config.setHonorBarUnlocked(frame.honorBarUnlocked)
        end
        UpdateHonorUnlockVisuals(frame)
    end)

    frame.testClickArea:SetScript("OnClick", function()
        if frame.testModeActive then
            if config.runCommand then config.runCommand("test off") end
            frame.testModeActive = false
        else
            if config.runCommand then config.runCommand("test") end
            frame.testModeActive = true
        end
        UpdateTestToggleVisuals(frame)
    end)

    for _, button in ipairs(frame.buttons) do button:Hide() end
    for _, divider in ipairs(frame.dividers) do divider:Hide() end
    frame.honorRow:Hide()
    frame.honorUnlockRow:Hide()
    frame.testRow:Hide()

    local rowY = -72
    local usedButtons = 0
    local usedDividers = 0

    local showTestToggle = false
    local showHonorToggle = (ZurkMapsHonorWidget and ZurkMapsHonorWidget.GetMode) or
        (type(config.isHonorBarVisible) == "function" and type(config.setHonorBarVisible) == "function")
    local showHonorUnlock = frame.honorBarMode ~= "OFF" and ((ZurkMapsHonorWidget and ZurkMapsHonorWidget.IsUnlocked) or
        (type(config.isHonorBarUnlocked) == "function" and type(config.setHonorBarUnlocked) == "function"))
    for _, entry in ipairs(config.commands or {}) do
        if entry.label == "Start Test" or entry.label == "Stop Test" then
            showTestToggle = true
        elseif entry.label and entry.command and entry.label ~= "Hide Map" then
            usedButtons = usedButtons + 1
            local button = frame.buttons[usedButtons]
            if button then
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, rowY)
                button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, rowY)
                button.text:SetText(entry.label)
                button:SetScript("OnClick", function()
                    if config.runCommand then config.runCommand(entry.command) end
                    frame:Hide()
                end)
                button:Show()
                rowY = rowY - 20
            end
        end
    end

    if showHonorToggle then
        frame.honorRow:ClearAllPoints()
        frame.honorRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, rowY)
        frame.honorRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, rowY)
        frame.honorRow:Show()
        rowY = rowY - 20
    end

    if showHonorUnlock then
        frame.honorUnlockRow:ClearAllPoints()
        frame.honorUnlockRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, rowY)
        frame.honorUnlockRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, rowY)
        frame.honorUnlockRow:Show()
        rowY = rowY - 20
    end

    if showTestToggle then
        frame.testRow:ClearAllPoints()
        frame.testRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, rowY)
        frame.testRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, rowY)
        frame.testRow:Show()
        rowY = rowY - 20
    end

    frame.closeButton:ClearAllPoints()
    frame.closeButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, rowY)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, rowY)
    frame.closeButton:SetScript("OnClick", function()
        if config.runCommand then
            config.runCommand(config.closeCommand or "hide")
        end
        frame:Hide()
    end)

    local finalHeight = math.max(128, 28 - rowY)
    frame:SetHeight(finalHeight)
end

function Options.OpenMapMenu(mapKey)
    local config = Options.maps[mapKey]
    if not config then return false end

    local menu = EnsureMenuFrame()
    local dismiss = EnsureDismissFrame()

    config.mapKey = mapKey
    if ZurkMapsHonorWidget and ZurkMapsHonorWidget.GetMode and ZurkMapsHonorWidget.GetMode() == "ATTACHED"
        and ZurkMapsHonorWidget.SetActiveMap then
        ZurkMapsHonorWidget.SetActiveMap(mapKey)
    end
    BuildMenu(menu, config)

    GameTooltip:Hide()
    PositionMenuAtCursor(menu)

    dismiss:Show()
    menu:Show()
    return true
end
