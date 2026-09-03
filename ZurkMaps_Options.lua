-- Shared right-click options menu and battleground callout-channel routing.
ZurkMapsOptions = ZurkMapsOptions or {}

local addonName = ...
local Options = ZurkMapsOptions
Options.maps = Options.maps or {}
Options.menu = Options.menu or nil
Options.dismiss = Options.dismiss or nil

local BG_R, BG_G, BG_B = 1.00, 0.48, 0.02
local RW_R, RW_G, RW_B = 1.00, 0.22, 0.06
local BORDER_R, BORDER_G, BORDER_B = 0.84, 0.56, 0.31
local MENU_BORDER_R, MENU_BORDER_G, MENU_BORDER_B = 0.56, 0.56, 0.56
local MENU_LEAVE_GRACE = 0.50
local DEFAULT_MAP_OPACITY = 0.72

local function GetAppearanceDB()
    ZurkMapsAppearanceDB = ZurkMapsAppearanceDB or {}
    local db = ZurkMapsAppearanceDB
    if db.opacityVersion ~= 2 then
        -- r8 stored a multiplier on top of the map's original 72% alpha.
        -- Convert once without changing the user's current appearance.
        db.opacity = (tonumber(db.opacity) or 1) * DEFAULT_MAP_OPACITY
        db.opacityVersion = 2
    end
    return db
end

function Options.UseClassBlips()
    return GetAppearanceDB().classBlips == true
end

function Options.GetOpacity()
    return math.max(0.10, math.min(1, tonumber(GetAppearanceDB().opacity) or DEFAULT_MAP_OPACITY))
end

function Options.GetFrameOpacity()
    return math.min(1, Options.GetOpacity() / DEFAULT_MAP_OPACITY)
end

local function ApplyMapOpacity(config)
    local alpha = Options.GetFrameOpacity()
    if config.frame then config.frame:SetAlpha(alpha) end
    -- Keep the original contrast at 72%, but let 100% become fully opaque.
    if config.mapTexture then config.mapTexture:SetAlpha(Options.GetOpacity() / alpha) end
end

function Options.ApplyOpacity()
    for _, config in pairs(Options.maps) do
        ApplyMapOpacity(config)
    end
    for bar in pairs(ZurkMapsHonorWidget and ZurkMapsHonorWidget.bars or {}) do
        bar:SetAlpha(bar:GetParent() == UIParent and Options.GetFrameOpacity() or 1)
    end
end

function Options.SetOpacity(value)
    GetAppearanceDB().opacity = math.max(0.10, math.min(1, tonumber(value) or DEFAULT_MAP_OPACITY))
    Options.ApplyOpacity()
end

-- SavedVariables are restored after the Lua files run. Frame registration alone
-- applies temporary defaults, so apply the saved alpha again once loading ends.
local appearanceLoader = CreateFrame("Frame")
appearanceLoader:RegisterEvent("ADDON_LOADED")
appearanceLoader:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then return end
    Options.ApplyOpacity()
    self:UnregisterEvent("ADDON_LOADED")
end)

function Options.SetClassBlips(enabled)
    GetAppearanceDB().classBlips = enabled == true
    for _, config in pairs(Options.maps) do
        if config.refreshBlips then config.refreshBlips() end
    end
end

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
    ApplyMapOpacity(config)
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
    button:SetHeight(20)
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    button.text:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetTextColor(1, 1, 1, 1)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.82, 0.45, 0.08)
    button:RegisterForClicks("LeftButtonUp")
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

local ShowChannelTooltip

local function CreateValueRow(parent, label)
    local row = CreateMenuButton(parent)
    row.text:SetText(label)
    row.value = row:CreateFontString(nil, "OVERLAY")
    row.value:SetFont("Fonts\\FRIZQT__.TTF", 10)
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.value:SetJustifyH("RIGHT")
    row.value:SetTextColor(0.82, 0.82, 0.82, 1)
    return row
end

local function EnsureMenuFrame()
    if Options.menu then return Options.menu end
    local frame = CreateFrame("Frame", "ZurkMapsOptionsMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(216, 230)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(90)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.025, 0.022, 0.018, 1)
        frame:SetBackdropBorderColor(0.62, 0.57, 0.47, 1)
    end
    -- Tooltip background artwork has built-in transparency even at alpha 1.
    frame.opaqueBG = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.opaqueBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    frame.opaqueBG:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    frame.opaqueBG:SetColorTexture(0.025, 0.022, 0.018, 1)
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont("Fonts\\FRIZQT__.TTF", 12)
    frame.title:SetTextColor(1, 0.82, 0.35, 1)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -11)
    frame.headerDivider = CreateDivider(frame)
    frame.headerDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -28)
    frame.headerDivider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -28)

    frame.switchClickArea = CreateValueRow(frame, "Callout Channel")
    frame.channelLabel = frame.switchClickArea.text
    frame.switchClickArea.value:Hide()
    frame.rightLabel = frame.switchClickArea:CreateFontString(nil, "OVERLAY")
    frame.rightLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.rightLabel:SetText("/RW")
    frame.rightLabel:SetPoint("RIGHT", frame.switchClickArea, "RIGHT", 0, 0)
    frame.switchTrack = CreateFrame("Frame", nil, frame.switchClickArea, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.switchTrack:SetSize(40, 18)
    frame.switchTrack:SetPoint("RIGHT", frame.rightLabel, "LEFT", -4, 0)
    frame.switchTrack:EnableMouse(false)
    if frame.switchTrack.SetBackdrop then
        frame.switchTrack:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame.switchTrack:SetBackdropColor(0.08, 0.07, 0.05, 1)
        frame.switchTrack:SetBackdropBorderColor(0.55, 0.50, 0.40, 1)
    end
    frame.switchTrack.thumb = frame.switchTrack:CreateTexture(nil, "OVERLAY")
    frame.switchTrack.thumb:SetAtlas("wowlabs-switch-slots-key", false)
    -- Keep the native artwork, wider with less vertical stretch. Its transparent
    -- margins fit within the enlarged track while the visible key fills its height.
    frame.switchTrack.thumb:SetSize(20, 18)
    frame.leftLabel = frame.switchClickArea:CreateFontString(nil, "OVERLAY")
    frame.leftLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.leftLabel:SetText("/bg")
    frame.leftLabel:SetPoint("RIGHT", frame.switchTrack, "LEFT", -4, 0)
    frame.switchClickArea:HookScript("OnEnter", function(self) ShowChannelTooltip(self) end)
    frame.switchClickArea:HookScript("OnLeave", function() GameTooltip:Hide() end)

    frame.classButton = CreateValueRow(frame, "Teammate Blips")
    frame.classButton:SetScript("OnClick", function(self)
        Options.SetClassBlips(not Options.UseClassBlips())
        self.value:SetText(Options.UseClassBlips() and "Class Colors" or "Gold")
    end)
    frame.honorRow = CreateValueRow(frame, "Honor Bar")
    frame.honorLabel, frame.honorModeValue = frame.honorRow.text, frame.honorRow.value
    frame.honorClickArea = frame.honorRow
    frame.honorRow:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Honor Bar")
        GameTooltip:AddLine("Click to cycle: Off, Attached, Persistent.", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine("Attached follows the map. Persistent stays visible outside battlegrounds.", 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)
    frame.honorRow:HookScript("OnLeave", function() GameTooltip:Hide() end)
    frame.honorUnlockRow = CreateValueRow(frame, "Honor Bar Position")
    frame.honorUnlockClickArea = frame.honorUnlockRow
    frame.testRow = CreateValueRow(frame, "Test Mode")
    frame.testClickArea = frame.testRow
    frame.dividers = { CreateDivider(frame), CreateDivider(frame) }
    frame.buttons = {}
    for i = 1, 8 do frame.buttons[i] = CreateMenuButton(frame) end
    frame.closeButton = CreateMenuButton(frame)
    frame.closeButton.text:SetText("Close Map")
    frame.opacityLabel = frame:CreateFontString(nil, "OVERLAY")
    frame.opacityLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.opacityLabel:SetText("Map Opacity")
    frame.opacityValue = frame:CreateFontString(nil, "OVERLAY")
    frame.opacityValue:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.opacityValue:SetTextColor(0.82, 0.82, 0.82, 1)
    frame.opacitySlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    frame.opacitySlider:SetOrientation("HORIZONTAL")
    frame.opacitySlider:SetMinMaxValues(10, 100)
    frame.opacitySlider:SetValueStep(1)
    frame.opacitySlider:SetObeyStepOnDrag(true)
    frame.opacitySlider:SetSize(180, 16)
    -- Hide template endpoint captions; the value is aligned with other settings.
    for _, key in ipairs({ "Low", "High", "Text" }) do
        if frame.opacitySlider[key] then frame.opacitySlider[key]:Hide() end
    end
    frame.opacitySlider:SetScript("OnMouseDown", function() frame.opacityDragging = true end)
    frame.opacitySlider:SetScript("OnMouseUp", function() frame.opacityDragging = false end)
    frame.opacitySlider:SetScript("OnHide", function() frame.opacityDragging = false end)
    frame.opacitySlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        frame.opacityValue:SetText(value .. "%")
        if not frame.building then Options.SetOpacity(value / 100) end
    end)
    frame:SetScript("OnShow", function(self) self.leaveElapsed = 0 end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        local hovered = self.IsMouseOver and self:IsMouseOver() or (MouseIsOver and MouseIsOver(self))
        if hovered or self.opacityDragging then self.leaveElapsed = 0; return end
        self.leaveElapsed = (self.leaveElapsed or 0) + (elapsed or 0)
        if self.leaveElapsed >= MENU_LEAVE_GRACE then self:Hide() end
    end)
    frame:SetScript("OnHide", function(self)
        self.leaveElapsed = 0
        GameTooltip:Hide()
        if Options.dismiss then Options.dismiss:Hide() end
    end)
    Options.menu = frame
    return frame
end

local function UpdateSwitchVisuals(frame)
    local raidWarning = frame.currentChannel == "RW"
    frame.leftLabel:SetTextColor(0.43, 0.43, 0.43, 1)
    frame.rightLabel:SetTextColor(0.43, 0.43, 0.43, 1)
    if raidWarning then
        frame.rightLabel:SetTextColor(RW_R, RW_G, RW_B, 1)
    else
        frame.leftLabel:SetTextColor(BG_R, BG_G, BG_B, 1)
    end
    frame.switchTrack.thumb:ClearAllPoints()
    -- Anchor each stop to its own inner edge so resizing the track or thumb
    -- cannot leave the slider off-center or hanging over an endpoint.
    local endpoint = raidWarning and "RIGHT" or "LEFT"
    frame.switchTrack.thumb:SetPoint(endpoint, frame.switchTrack, endpoint, raidWarning and -2 or 2, 0)
end

local function UpdateTestToggleVisuals(frame)
    frame.testRow.value:SetText(frame.testModeActive and "On" or "Off")
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
    frame.honorUnlockRow.value:SetText(frame.honorBarUnlocked and "Unlocked" or "Locked")
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

local function BuildMenu(frame, config)
    frame.mapKey = config.mapKey
    frame.config = config
    frame.title:SetText((config.mapKey or "Map") .. " Options")
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

    local rowY = -34
    local function PlaceRow(row)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, rowY)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, rowY)
        row:Show()
        rowY = rowY - 20
    end
    local function PlaceDivider(index)
        rowY = rowY - 3
        local line = frame.dividers[index]
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, rowY)
        line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, rowY)
        line:Show()
        rowY = rowY - 4
    end
    PlaceRow(frame.switchClickArea)
    frame.classButton.value:SetText(Options.UseClassBlips() and "Class Colors" or "Gold")
    PlaceRow(frame.classButton)
    local showHonor = (ZurkMapsHonorWidget and ZurkMapsHonorWidget.GetMode) or
        (type(config.isHonorBarVisible) == "function" and type(config.setHonorBarVisible) == "function")
    if showHonor then
        PlaceRow(frame.honorRow)
        local canUnlock = (ZurkMapsHonorWidget and ZurkMapsHonorWidget.IsUnlocked) or
            (type(config.isHonorBarUnlocked) == "function" and type(config.setHonorBarUnlocked) == "function")
        if frame.honorBarMode ~= "OFF" and canUnlock then PlaceRow(frame.honorUnlockRow) end
    end
    PlaceDivider(1)
    for _, entry in ipairs(config.commands or {}) do
        if entry.label == "Start Test" then PlaceRow(frame.testRow); break end
    end
    local usedButtons = 0
    for _, entry in ipairs(config.commands or {}) do
        if entry.label and entry.command and entry.label ~= "Hide Map"
            and entry.label ~= "Start Test" and entry.label ~= "Stop Test" then
            usedButtons = usedButtons + 1
            local button = frame.buttons[usedButtons]
            if button then
                button.text:SetText(entry.label)
                button:SetScript("OnClick", function()
                    if config.runCommand then config.runCommand(entry.command) end
                    frame:Hide()
                end)
                PlaceRow(button)
            end
        end
    end
    PlaceRow(frame.closeButton)
    frame.closeButton:SetScript("OnClick", function()
        if config.runCommand then config.runCommand(config.closeCommand or "hide") end
        frame:Hide()
    end)
    PlaceDivider(2)
    rowY = rowY - 2
    frame.opacityLabel:ClearAllPoints()
    frame.opacityLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, rowY)
    frame.opacityValue:ClearAllPoints()
    frame.opacityValue:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, rowY)
    frame.opacitySlider:ClearAllPoints()
    frame.opacitySlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, rowY - 15)
    frame.opacitySlider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, rowY - 15)
    frame.building = true
    frame.opacitySlider:SetValue(Options.GetOpacity() * 100)
    frame.building = false
    frame.opacityValue:SetText(math.floor(Options.GetOpacity() * 100 + 0.5) .. "%")
    frame:SetHeight(40 - rowY)
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
    Options.ApplyOpacity()
    BuildMenu(menu, config)

    GameTooltip:Hide()
    PositionMenuAtCursor(menu)

    dismiss:Show()
    menu:Show()
    return true
end

-- One startup hint, after every map has registered its slash commands.
local loginHint = CreateFrame("Frame")
loginHint:RegisterEvent("PLAYER_LOGIN")
loginHint:SetScript("OnEvent", function(self)
    print("|cff33ff99Zurk Maps|r: |cffffff00/wsg|r (Warsong Gulch)  |cffffff00/ab|r (Arathi Basin)  |cffffff00/av|r (Alterac Valley)")
    self:UnregisterEvent("PLAYER_LOGIN")
end)
