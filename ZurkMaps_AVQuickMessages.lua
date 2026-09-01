-- Five saved Alterac Valley battleground-message buttons.
-- Left-click sends the saved message; right-click opens a Zurk-style editor.
ZurkMapsAVQuickMessages = ZurkMapsAVQuickMessages or {}

local Quick = ZurkMapsAVQuickMessages

local RAID_MARKER_INDEX = {
    star = 1,
    circle = 2,
    diamond = 3,
    triangle = 4,
    moon = 5,
    square = 6,
    cross = 7,
    x = 7,
    skull = 8,
}

local function Trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function SplitLines(text)
    local lines = {}
    text = tostring(text or "")
    text = text:gsub("\r\n", "\n")
    text = text:gsub("\r", "\n")
    if text == "" then return lines end
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function ExpandRaidMarkersForPreview(text)
    text = tostring(text or "")
    return (text:gsub("%{([%a]+)%}", function(tag)
        local index = RAID_MARKER_INDEX[string.lower(tag or "")]
        if not index then return "{" .. tostring(tag or "") .. "}" end
        return string.format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t", index)
    end))
end

function Quick.Create(options)
    if not options or not options.frame or not options.map or not options.mapBorder then return nil end

    local quick = {
        frame = options.frame,
        map = options.map,
        mapBorder = options.mapBorder,
        db = options.db or {},
        width = options.width or 15,
        cellHeight = options.cellHeight or 18,
        count = 5,
        currentSlot = nil,
        saving = false,
        canceling = false,
        buttons = {},
        baseEditorHeight = options.editorHeight or 150,
        editorWidth = options.editorWidth or 300,
        minVisibleLines = options.minVisibleLines or 5,
        lineHeight = options.lineHeight or 13,
        maxEditorHeight = options.maxEditorHeight or 420,
    }

    quick.db.avQuickMessages = quick.db.avQuickMessages or {}
    quick.maxLines = math.max(quick.minVisibleLines, math.floor((quick.maxEditorHeight - quick.baseEditorHeight) / quick.lineHeight) + quick.minVisibleLines)


    function quick:GetMessage(slot)
        local value = self.db.avQuickMessages[slot]
        if type(value) == "string" then return value end
        return ""
    end

    function quick:SetMessage(slot, text)
        self.db.avQuickMessages[slot] = tostring(text or "")
    end

    function quick:ResolveLine(line)
        line = Trim(line)
        if line == "" then return "", nil, nil end

        local slashCommand, slashArgs = string.match(line, "^/(%S+)%s*(.-)%s*$")
        if not slashCommand then return line, nil, nil end

        local command = string.lower(slashCommand)
        local mappedType = nil
        local previewLabel = nil
        if command == "bg" or command == "battleground" or command == "bgchat" then
            mappedType = "INSTANCE_CHAT"
            previewLabel = "BG"
        elseif command == "s" or command == "say" then
            mappedType = "SAY"
            previewLabel = "SAY"
        elseif command == "y" or command == "yell" then
            mappedType = "YELL"
            previewLabel = "YELL"
        elseif command == "p" or command == "party" then
            mappedType = "PARTY"
            previewLabel = "PARTY"
        elseif command == "raid" or command == "ra" then
            mappedType = "RAID"
            previewLabel = "RAID"
        elseif command == "rw" then
            mappedType = "RAID_WARNING"
            previewLabel = "RW"
        elseif command == "i" or command == "instance" then
            mappedType = "INSTANCE_CHAT"
            previewLabel = "INSTANCE"
        end

        if not mappedType then
            return line, nil, nil
        end

        local payload = Trim(slashArgs)
        if payload == "" then return "", mappedType, previewLabel end

        if mappedType == "INSTANCE_CHAT" and options.isInBattleground and not options.isInBattleground() then
            mappedType = "SAY"
        end

        return payload, mappedType, previewLabel
    end

    function quick:GetConfiguredChannelLabel()
        if options.getCurrentChannelLabel then
            local label = options.getCurrentChannelLabel()
            if label == "RW" then return "RW" end
            if label == "BG" then return "BG" end
        end
        return "BG"
    end

    function quick:GetConfiguredChannelHint()
        return "/" .. self:GetConfiguredChannelLabel()
    end


    function quick:GetLineCount(textValue)
        local text = tostring(textValue or "")
        if text == "" then return 1 end
        local _, count = string.gsub(text, "\n", "\n")
        return count + 1
    end

    function quick:EnforceMaxLines()
        local text = tostring(self.editBox:GetText() or "")
        local lines = SplitLines(text)
        if #lines <= self.maxLines then
            self.lastGoodText = text
            return
        end

        local kept = {}
        for i = 1, self.maxLines do
            kept[#kept + 1] = lines[i] or ""
        end
        local clamped = table.concat(kept, "\n")
        if clamped ~= text then
            self.editBox:SetText(clamped)
            self.editBox:SetCursorPosition(string.len(clamped))
        end
        self.lastGoodText = clamped
    end

    function quick:UpdateEditMetrics()
        if not self.panelOuter or not self.panel or not self.editBackdrop or not self.editBox then return end

        local text = tostring(self.editBox:GetText() or "")
        local lineCount = self:GetLineCount(text)
        local visibleLines = math.max(self.minVisibleLines, lineCount)
        local explicitHeight = visibleLines * self.lineHeight
        local measuredHeight = explicitHeight

        -- Explicit newline counts are not enough here: a pasted message can be
        -- one long logical line that word-wraps into many visible rows. Mirror
        -- the EditBox text into an invisible FontString at the same width so
        -- the dialog grows for wrapped rows as well as Enter-created rows.
        if self.measureText and self.measureText.GetStringHeight then
            local textWidth = tonumber(self.editBox:GetWidth()) or 0
            if textWidth <= 1 then
                textWidth = math.max(1, self.editorWidth - 34)
            end
            self.measureText:SetWidth(textWidth)
            self.measureText:SetText(text ~= "" and text or " ")
            measuredHeight = math.max(measuredHeight, tonumber(self.measureText:GetStringHeight()) or 0)
        end

        local baseTextHeight = math.max(self.minVisibleLines * self.lineHeight, self.baseTextHeight or 0)
        local extraHeight = math.max(0, measuredHeight - baseTextHeight)
        local desiredHeight = math.min(self.maxEditorHeight, self.baseEditorHeight + math.ceil(extraHeight))

        -- Keep the native four-sided EditBox anchoring (which preserves the
        -- blinking caret on Classic) while expanding the surrounding dialog.
        self.panelOuter:SetHeight(desiredHeight + 4)
    end

    function quick:PreviewEditor()
        local text = Trim(self.editBox:GetText())
        if not DEFAULT_CHAT_FRAME then return end
        if text == "" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[Preview]|r <empty>")
            return
        end

        local lines = SplitLines(text)
        for _, rawLine in ipairs(lines) do
            local cleanLine, _, previewLabel = self:ResolveLine(rawLine)
            cleanLine = Trim(cleanLine)
            if cleanLine ~= "" then
                local label = self:GetConfiguredChannelLabel()
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99[%s Preview]|r %s", label, ExpandRaidMarkersForPreview(cleanLine)))
            end
        end
    end

    function quick:Send(slot)
        local message = Trim(self:GetMessage(slot))
        if message == "" then
            self:OpenEditor(slot, self.buttons[slot])
            return
        end

        if options.sendBGMessage then
            local lines = SplitLines(message)
            for _, rawLine in ipairs(lines) do
                local cleanLine = self:ResolveLine(rawLine)
                cleanLine = Trim(cleanLine)
                if cleanLine ~= "" then
                    options.sendBGMessage(cleanLine)
                end
            end
        end
    end

    quick.stackOuter = CreateFrame("Frame", nil, quick.map, BackdropTemplateMixin and "BackdropTemplate" or nil)
    quick.stackOuter:SetSize(quick.width + 2, (quick.cellHeight * quick.count) + 2)
    quick.stackOuter:SetPoint("TOPRIGHT", quick.map, "TOPRIGHT", -5, -5)
    quick.stackOuter:SetFrameLevel(quick.mapBorder:GetFrameLevel() + 4)
    if quick.stackOuter.SetBackdrop then
        quick.stackOuter:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        quick.stackOuter:SetBackdropBorderColor(0.035, 0.022, 0.012, 1)
    end

    quick.stack = CreateFrame("Frame", nil, quick.stackOuter)
    quick.stack:SetSize(quick.width, quick.cellHeight * quick.count)
    quick.stack:SetPoint("CENTER", quick.stackOuter, "CENTER", 0, 0)
    quick.stack:SetFrameLevel(quick.mapBorder:GetFrameLevel() + 5)

    for i = 1, quick.count do
        local button = CreateFrame("Button", nil, quick.stack, BackdropTemplateMixin and "BackdropTemplate" or nil)
        button:SetSize(quick.width, quick.cellHeight)
        button:SetPoint("TOP", quick.stack, "TOP", 0, -((i - 1) * quick.cellHeight))
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button.slot = i

        if button.SetBackdrop then
            button:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            button:SetBackdropColor(0.028, 0.019, 0.010, 0.90)
            button:SetBackdropBorderColor(0.62, 0.46, 0.27, 0.95)
        end

        button.text = button:CreateFontString(nil, "OVERLAY")
        button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        button.text:SetTextColor(1.0, 0.84, 0.18, 1)
        button.text:SetText(tostring(i))

        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

        button:SetScript("OnEnter", function(self)
            GameTooltip:Hide()
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("AV Message " .. self.slot)
            local message = Trim(quick:GetMessage(self.slot))
            if message ~= "" then
                GameTooltip:AddLine(message, 0.82, 0.82, 0.82, true)
            else
                GameTooltip:AddLine("Not set", 0.58, 0.58, 0.58, true)
            end
            GameTooltip:AddLine("Left-click to send to " .. quick:GetConfiguredChannelHint() .. ".", 0.72, 0.66, 0.50, true)
            GameTooltip:AddLine("Right-click to edit.", 0.72, 0.66, 0.50, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                quick:OpenEditor(self.slot, self)
            else
                quick:Send(self.slot)
            end
        end)

        quick.buttons[i] = button
    end

    quick.panelOuter = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    quick.panelOuter:SetSize(quick.editorWidth + 4, quick.baseEditorHeight + 4)
    quick.panelOuter:SetFrameStrata("DIALOG")
    quick.panelOuter:SetFrameLevel(119)
    quick.panelOuter:SetClampedToScreen(true)
    quick.panelOuter:EnableMouse(true)
    quick.panelOuter:Hide()

    quick.panel = CreateFrame("Frame", nil, quick.panelOuter, BackdropTemplateMixin and "BackdropTemplate" or nil)
    quick.panel:SetPoint("TOPLEFT", quick.panelOuter, "TOPLEFT", 2, -2)
    quick.panel:SetPoint("BOTTOMRIGHT", quick.panelOuter, "BOTTOMRIGHT", -2, 2)
    quick.panel:SetFrameStrata("DIALOG")
    quick.panel:SetFrameLevel(120)
    quick.panel:EnableMouse(true)
    if quick.panel.SetBackdrop then
        quick.panel:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        quick.panel:SetBackdropColor(0.03, 0.03, 0.03, 0.97)
        quick.panel:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
    end

    quick.title = quick.panel:CreateFontString(nil, "OVERLAY")
    quick.title:SetPoint("TOPLEFT", quick.panel, "TOPLEFT", 12, -8)
    quick.title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    quick.title:SetTextColor(1, 0.82, 0.20, 1)

    quick.instruction = quick.panel:CreateFontString(nil, "OVERLAY")
    quick.instruction:SetPoint("TOPLEFT", quick.title, "BOTTOMLEFT", 0, -2)
    quick.instruction:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    quick.instruction:SetTextColor(0.76, 0.70, 0.54, 1)
    quick.instruction:SetText("Enter creates a new line - Okay saves")

    quick.editBackdrop = CreateFrame("Frame", nil, quick.panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    quick.editBackdrop:SetPoint("TOPLEFT", quick.panel, "TOPLEFT", 11, -42)
    quick.editBackdrop:SetPoint("BOTTOMRIGHT", quick.panel, "BOTTOMRIGHT", -11, 34)
    if quick.editBackdrop.SetBackdrop then
        quick.editBackdrop:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = true,
            tileSize = 8,
            edgeSize = 1,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        quick.editBackdrop:SetBackdropColor(0.015, 0.012, 0.009, 0.96)
        quick.editBackdrop:SetBackdropBorderColor(0.42, 0.34, 0.23, 0.95)
    end

    -- Plain multiline EditBox using the caret-visible four-sided configuration.
    quick.editBox = CreateFrame("EditBox", nil, quick.editBackdrop)
    quick.editBox:SetPoint("TOPLEFT", quick.editBackdrop, "TOPLEFT", 6, -5)
    quick.editBox:SetPoint("BOTTOMRIGHT", quick.editBackdrop, "BOTTOMRIGHT", -6, 5)
    quick.editBox:SetAutoFocus(false)
    quick.editBox:SetMultiLine(true)
    quick.editBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    quick.editBox:SetTextColor(0.92, 0.92, 0.92, 1)
    quick.editBox:SetMaxLetters(options.maxLetters or 1000)
    quick.editBox:SetJustifyH("LEFT")
    quick.editBox:SetJustifyV("TOP")

    -- Invisible text mirror used only to measure visual word-wrapped height.
    quick.measureText = quick.panel:CreateFontString(nil, "OVERLAY")
    quick.measureText:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    quick.measureText:SetJustifyH("LEFT")
    quick.measureText:SetJustifyV("TOP")
    if quick.measureText.SetWordWrap then quick.measureText:SetWordWrap(true) end
    if quick.measureText.SetNonSpaceWrap then quick.measureText:SetNonSpaceWrap(true) end
    quick.measureText:SetAlpha(0)
    quick.baseTextHeight = math.max(quick.minVisibleLines * quick.lineHeight, quick.baseEditorHeight - 86)

    quick.preview = CreateFrame("Button", nil, quick.panel, "UIPanelButtonTemplate")
    quick.preview:SetSize(64, 22)
    quick.preview:SetPoint("BOTTOMRIGHT", quick.panel, "BOTTOMRIGHT", -82, 9)
    quick.preview:SetText("Preview")

    quick.okay = CreateFrame("Button", nil, quick.panel, "UIPanelButtonTemplate")
    quick.okay:SetSize(64, 22)
    quick.okay:SetPoint("BOTTOMRIGHT", quick.panel, "BOTTOMRIGHT", -10, 9)
    quick.okay:SetText("Okay")

    function quick:SaveEditor()
        if not self.currentSlot then return end
        self.saving = true
        self:SetMessage(self.currentSlot, self.editBox:GetText())
        self.editBox:ClearFocus()
        self.currentSlot = nil
        self.panelOuter:Hide()
        self.saving = false
    end

    function quick:CancelEditor()
        self.canceling = true
        self.editBox:ClearFocus()
        self.currentSlot = nil
        self.panelOuter:Hide()
        self.canceling = false
    end

    function quick:OpenEditor(slot, owner)
        GameTooltip:Hide()
        self.currentSlot = slot
        self.title:SetText("AV Message " .. slot)
        self.editBox:SetText(self:GetMessage(slot))
        self.lastGoodText = self.editBox:GetText() or ""
        self.panelOuter:ClearAllPoints()
        owner = owner or self.buttons[slot] or self.stack
        self.panelOuter:SetPoint("TOPRIGHT", owner, "TOPLEFT", -5, 0)
        self.panelOuter:Show()
        self.editBox:SetFocus()
        self.editBox:SetCursorPosition(string.len(self.editBox:GetText() or ""))
        self:UpdateEditMetrics()
    end

    quick.editBox:SetScript("OnEscapePressed", function() quick:CancelEditor() end)
    quick.editBox:SetScript("OnEnterPressed", function(self)
        self:Insert("\n")
        quick:UpdateEditMetrics()
    end)
    quick.editBox:SetScript("OnTextChanged", function(self)
        quick:EnforceMaxLines()
        if quick.currentSlot then
            quick:SetMessage(quick.currentSlot, self:GetText())
        end
        quick:UpdateEditMetrics()
    end)
    quick.editBox:SetScript("OnEditFocusLost", function()
        if quick.saving or quick.canceling then return end
        if quick.panelOuter:IsShown() then quick:CancelEditor() end
    end)
    quick.okay:SetScript("OnMouseDown", function() quick.saving = true end)
    quick.okay:SetScript("OnClick", function() quick:SaveEditor() end)
    quick.preview:SetScript("OnMouseDown", function() quick.saving = true end)
    quick.preview:SetScript("OnClick", function()
        quick:PreviewEditor()
        quick.saving = false
        quick.editBox:SetFocus()
    end)

    quick.frame:HookScript("OnHide", function()
        if quick.panelOuter then quick.panelOuter:Hide() end
    end)

    return quick
end
