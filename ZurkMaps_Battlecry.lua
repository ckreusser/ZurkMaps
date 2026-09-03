-- Shared Battlecry widget factory. WSG uses this so its large map file does not
-- spend additional top-level locals on the editor implementation.
ZurkMapsBattlecry = ZurkMapsBattlecry or {}

-- Shared by the maps' framed icon and numbered-message buttons. Use the rank-up
-- popup's physical-pixel sizing so opposite edges and corners stay consistent.
-- Keep the button anchored to its map; only its border is snapped to pixels.
function ZurkMapsBattlecry.CreateButtonBorder(button, style)
    style = style or {}
    local border = CreateFrame("Frame", nil, button)
    border:SetFrameLevel(button:GetFrameLevel() + 2)
    border:EnableMouse(false)

    local rings = {}
    for index, color in ipairs({
        { 0.055, 0.035, 0.018, style.outerAlpha or 1 },
        { 0.70, 0.52, 0.20, style.innerAlpha or 1 },
    }) do
        local lines = {}
        for edge = 1, 4 do
            local line = border:CreateTexture(nil, "OVERLAY")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(unpack(color))
            if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
            if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
            lines[edge] = line
        end
        rings[index] = lines
    end

    function border:SnapToPixels()
        local unitFactor
        if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then
            unitFactor = PixelUtil.GetPixelToUIUnitFactor()
        elseif GetPhysicalScreenSize then
            local _, physicalHeight = GetPhysicalScreenSize()
            if physicalHeight and physicalHeight > 0 then unitFactor = 768 / physicalHeight end
        end
        local scale = math.max(0.01, (button:GetEffectiveScale() or 1) / math.max(0.01, unitFactor or 1))
        local width, height = button:GetWidth(), button:GetHeight()
        local left, top = button:GetLeft(), button:GetTop()
        if self._pixelScale == scale and self._buttonWidth == width and self._buttonHeight == height
            and self._buttonLeft == left and self._buttonTop == top then return end
        self._pixelScale, self._buttonWidth, self._buttonHeight = scale, width, height
        self._buttonLeft, self._buttonTop = left, top

        local function Pixels(value) return math.floor(value * scale + 0.5) end
        -- Snap both endpoints so adjoining AV message cells share the same
        -- boundary, even when their UI-unit height lands between pixels.
        local widthPixels = math.max(1, left and (Pixels(left + width) - Pixels(left)) or Pixels(width))
        local heightPixels = math.max(1, top and (Pixels(top) - Pixels(top - height)) or Pixels(height))
        local x = left and (Pixels(left) / scale - left) or 0
        local y = top and (Pixels(top) / scale - top) or 0
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", button, "TOPLEFT", x, y)
        self:SetSize(widthPixels / scale, heightPixels / scale)

        local stroke = math.max(1, Pixels(style.thickness or 1))
        local function Place(line, px, py, w, h)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", self, "TOPLEFT", px / scale, -py / scale)
            line:SetSize(w / scale, h / scale)
        end
        for index, lines in ipairs(rings) do
            local inset = (index - 1) * stroke
            local w, h = widthPixels - 2 * inset, heightPixels - 2 * inset
            Place(lines[1], inset, inset, w, stroke)
            Place(lines[2], inset, heightPixels - inset - stroke, w, stroke)
            -- Horizontal strokes own the corners, as in the rank-up popup.
            Place(lines[3], inset, inset + stroke, stroke, h - 2 * stroke)
            Place(lines[4], widthPixels - inset - stroke, inset + stroke, stroke, h - 2 * stroke)
        end

        if self.contentIcon then
            -- Use the same physical-pixel measurements for the artwork's inner
            -- margin. Independent texture snapping otherwise makes one side
            -- of a framed button look thicker than its opposite edge.
            local inset = (2 * stroke + math.max(0, Pixels(self.contentPadding))) / scale
            self.contentIcon:ClearAllPoints()
            self.contentIcon:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
            self.contentIcon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset)
        end
    end

    function border:FitContent(background, icon, padding)
        self.contentIcon = icon
        self.contentPadding = padding or 0
        for _, texture in ipairs({ background, icon }) do
            if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
            if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
        end
        background:ClearAllPoints()
        background:SetAllPoints(self)
        self._pixelScale = nil
        self:SnapToPixels()
    end

    border:SetScript("OnShow", border.SnapToPixels)
    -- Moving or scaling a parent doesn't necessarily resize the button in UI
    -- units. The cached check catches those changes without rebuilding frames.
    border:SetScript("OnUpdate", border.SnapToPixels)
    border:SnapToPixels()
    return border
end

function ZurkMapsBattlecry.Create(options)
    if not options or not options.frame or not options.map or not options.mapBorder then
        return nil
    end

    local battlecry = {
        frame = options.frame,
        map = options.map,
        mapBorder = options.mapBorder,
        db = options.db or {},
        dbKey = options.dbKey or "battlecryMessage",
        buttonSize = options.buttonSize or 30,
        panelHeight = options.panelHeight or 72,
        hoverGrace = options.hoverGrace or 0.55,
        closeAt = nil,
        savingEdit = false,
        cancelingEdit = false,
        editing = false,
    }

    function battlecry:GetFriendlyFaction()
        if UnitFactionGroup then
            return UnitFactionGroup("player")
        end
        return nil
    end

    function battlecry:GetDefaultMessage()
        local faction = self:GetFriendlyFaction()
        if faction == "Alliance" then
            return "FOR THE ALLIANCE!"
        elseif faction == "Horde" then
            return "FOR THE HORDE!"
        end
        return "FOR THE TEAM!"
    end

    function battlecry:GetMessage()
        local saved = self.db and self.db[self.dbKey]
        if type(saved) == "string" and string.find(saved, "%S") then
            return saved
        end
        return self:GetDefaultMessage()
    end

    function battlecry:LoadSavedMessage(db, legacyMessage)
        self.db = type(db) == "table" and db or self.db or {}
        -- Migrate an older location only when the dedicated value has never
        -- existed. A user's saved string always wins over defaults and updates.
        if self.db[self.dbKey] == nil and type(legacyMessage) == "string" then
            self.db[self.dbKey] = legacyMessage
        end
        self.currentMessage = self:GetMessage()
        if self.editBox and not self.editBox:HasFocus() then
            self.editBox:SetText(self.currentMessage)
        end
        return self.currentMessage
    end
    battlecry:LoadSavedMessage(options.db, options.legacyMessage)

    function battlecry:TrimMessage(text)
        text = tostring(text or "")
        text = string.gsub(text, "^%s+", "")
        text = string.gsub(text, "%s+$", "")
        return text
    end

    function battlecry:SaveEditedMessage()
        if not self.editBox then
            return
        end
        self.savingEdit = true
        local text = self:TrimMessage(self.editBox:GetText())
        if text == "" then
            text = self:GetDefaultMessage()
        end
        self.db[self.dbKey] = text
        self.currentMessage = text
        self.editBox:SetText(text)
        self.editBox:ClearFocus()
        self.editing = false
        self.closeAt = nil
        if self.instruction then
            self.instruction:SetText("Click message to edit")
        end
        if self.panel and self.panel:IsShown() then
            self.panel:Hide()
        end
        self.savingEdit = false
    end

    function battlecry:ExecuteMessage()
        local message = self:TrimMessage(self:GetMessage())
        if message == "" then
            return
        end

        local slashCommand, slashArgs = string.match(message, "^/(%S+)%s*(.-)%s*$")
        if slashCommand then
            local command = string.lower(slashCommand)
            if command == "e" or command == "em" or command == "me" then
                if slashArgs and slashArgs ~= "" then
                    if options.sendMessage then
                        options.sendMessage(slashArgs, "EMOTE")
                    else
                        SendChatMessage(slashArgs, "EMOTE")
                    end
                end
                return
            end
            if DoEmote then
                DoEmote(string.upper(slashCommand))
                return
            end
        end

        if options.sendMessage then
            options.sendMessage(message, "YELL")
        else
            SendChatMessage(message, "YELL")
        end
    end

    function battlecry:CancelEditing()
        if not self.editBox then
            return
        end
        self.cancelingEdit = true
        self.editBox:SetText(self:GetMessage())
        self.editBox:ClearFocus()
        self.editing = false
        self.closeAt = nil
        if self.instruction then
            self.instruction:SetText("Click message to edit")
        end
        if self.panel and self.panel:IsShown() then
            self.panel:Hide()
        end
        self.cancelingEdit = false
    end

    function battlecry:ShowPanel()
        if not self.panel then
            return
        end
        self.currentMessage = self:GetMessage()
        self.savingEdit = false
        self.cancelingEdit = false
        self.editBox:SetText(self.currentMessage)
        if not self.editBox:HasFocus() then
            self.instruction:SetText("Click message to edit")
        end
        self.panel:Show()
    end

    function battlecry:GetIconTexture()
        local faction = self:GetFriendlyFaction()
        if faction == "Alliance" then
            return "Interface\\Icons\\Ability_Warrior_RallyingCry"
        elseif faction == "Horde" then
            return "Interface\\Icons\\Ability_Warrior_WarCry"
        end
        return "Interface\\Icons\\Ability_Warrior_BattleShout"
    end

    function battlecry:IsInteracting()
        return (self.button and self.button:IsMouseOver())
            or (self.panel and self.panel:IsShown()
                and (self.panel:IsMouseOver() or (self.editBox and self.editBox:HasFocus())))
    end

    battlecry.button = CreateFrame("Button", nil, battlecry.map)
    battlecry.button:SetSize(battlecry.buttonSize, battlecry.buttonSize)
    if options.anchorButton then
        battlecry.button:SetPoint("BOTTOMLEFT", options.anchorButton, "TOPLEFT", 0, options.buttonGap or 5)
    else
        battlecry.button:SetPoint("BOTTOMLEFT", battlecry.map, "BOTTOMLEFT", options.xOffset or 7, options.yOffset or 42)
    end
    battlecry.button:SetFrameLevel(battlecry.mapBorder:GetFrameLevel() + (options.frameLevelOffset or 3))
    battlecry.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    battlecry.background = battlecry.button:CreateTexture(nil, "BACKGROUND")
    battlecry.background:SetAllPoints()
    battlecry.background:SetColorTexture(0.08, 0.055, 0.025, options.backgroundAlpha or 0.52)

    battlecry.icon = battlecry.button:CreateTexture(nil, "ARTWORK")
    battlecry.icon:SetPoint("TOPLEFT", battlecry.button, "TOPLEFT", 3, -3)
    battlecry.icon:SetPoint("BOTTOMRIGHT", battlecry.button, "BOTTOMRIGHT", -3, 3)
    battlecry.icon:SetTexture(battlecry:GetIconTexture())
    battlecry.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    battlecry.icon:SetAlpha(options.iconAlpha or 0.68)

    if options.createBorder then
        battlecry.border = options.createBorder(battlecry.button)
        if battlecry.border then battlecry.border:SetAlpha(options.borderAlpha or 0.72) end
        if battlecry.border and battlecry.border.FitContent then
            battlecry.border:FitContent(battlecry.background, battlecry.icon, 1)
        end
    end

    battlecry.button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    battlecry.button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    battlecry.panel = CreateFrame(
        "Frame",
        options.panelName or nil,
        battlecry.frame,
        BackdropTemplateMixin and "BackdropTemplate" or nil
    )
    battlecry.panel:SetFrameStrata("DIALOG")
    battlecry.panel:SetFrameLevel(95)
    battlecry.panel:SetClampedToScreen(false)
    battlecry.panel:EnableMouse(true)
    battlecry.panel:SetScale(1)
    battlecry.panel:ClearAllPoints()
    battlecry.panel:SetPoint("TOPLEFT", battlecry.mapBorder, "BOTTOMLEFT", 0, 5)
    battlecry.panel:SetPoint("TOPRIGHT", battlecry.mapBorder, "BOTTOMRIGHT", 0, 5)
    battlecry.panel:SetHeight(battlecry.panelHeight)

    if battlecry.panel.SetBackdrop then
        battlecry.panel:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        battlecry.panel:SetBackdropColor(0.03, 0.03, 0.03, 0.97)
        battlecry.panel:SetBackdropBorderColor(0.62, 0.55, 0.38, 1)
    end

    battlecry.title = battlecry.panel:CreateFontString(nil, "OVERLAY")
    battlecry.title:SetPoint("TOPLEFT", battlecry.panel, "TOPLEFT", 12, -7)
    battlecry.title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    battlecry.title:SetTextColor(1, 0.82, 0.20, 1)
    battlecry.title:SetText("Battlecry")

    battlecry.instruction = battlecry.panel:CreateFontString(nil, "OVERLAY")
    battlecry.instruction:SetPoint("TOPLEFT", battlecry.title, "BOTTOMLEFT", 0, -1)
    battlecry.instruction:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    battlecry.instruction:SetTextColor(0.76, 0.70, 0.54, 1)
    battlecry.instruction:SetText("Click message to edit")

    battlecry.editBox = CreateFrame("EditBox", nil, battlecry.panel, "InputBoxTemplate")
    battlecry.editBox:SetPoint("TOPLEFT", battlecry.panel, "TOPLEFT", 12, -39)
    battlecry.editBox:SetPoint("TOPRIGHT", battlecry.panel, "TOPRIGHT", -84, -39)
    battlecry.editBox:SetHeight(22)
    battlecry.editBox:SetAutoFocus(false)
    battlecry.editBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    battlecry.editBox:SetMaxLetters(220)
    battlecry.editBox:SetTextInsets(4, 4, 0, 0)
    battlecry.editBox:SetText(battlecry:GetMessage())

    battlecry.editBox:SetScript("OnEditFocusGained", function(self)
        battlecry.editing = true
        battlecry.instruction:SetText("Press Enter or Okay to save")
        self:HighlightText()
    end)
    battlecry.editBox:SetScript("OnEnterPressed", function()
        battlecry:SaveEditedMessage()
    end)
    battlecry.editBox:SetScript("OnEscapePressed", function()
        battlecry:CancelEditing()
    end)
    battlecry.editBox:SetScript("OnEditFocusLost", function()
        if battlecry.savingEdit or battlecry.cancelingEdit then
            return
        end
        if battlecry.panel and battlecry.panel:IsShown() then
            battlecry:CancelEditing()
        end
    end)

    battlecry.okayButton = CreateFrame("Button", nil, battlecry.panel, "UIPanelButtonTemplate")
    battlecry.okayButton:SetSize(64, 22)
    battlecry.okayButton:SetPoint("TOPRIGHT", battlecry.panel, "TOPRIGHT", -10, -39)
    battlecry.okayButton:SetText("Okay")
    battlecry.okayButton:SetScript("OnMouseDown", function()
        battlecry.savingEdit = true
    end)
    battlecry.okayButton:SetScript("OnClick", function()
        battlecry:SaveEditedMessage()
    end)

    battlecry.button:SetScript("OnEnter", function(self)
        battlecry.closeAt = nil
        battlecry.icon:SetAlpha(options.hoverAlpha or 0.90)
        if battlecry.border then
            battlecry.border:SetAlpha(options.hoverAlpha or 0.90)
        end
        if options.onHoverStart then
            options.onHoverStart()
        end
        GameTooltip:Hide()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Battlecry")
        GameTooltip:AddLine(battlecry:GetMessage(), 0.72, 0.66, 0.50, true)
        GameTooltip:AddLine("Left-click to yell. Right-click to edit.", 0.72, 0.66, 0.50, true)
        GameTooltip:Show()
    end)

    battlecry.button:SetScript("OnLeave", function()
        battlecry.icon:SetAlpha(options.iconAlpha or 0.68)
        if battlecry.border then
            battlecry.border:SetAlpha(options.borderAlpha or 0.72)
        end
        GameTooltip:Hide()
    end)

    battlecry.button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            GameTooltip:Hide()
            battlecry:ShowPanel()
            battlecry.editBox:SetFocus()
        elseif mouseButton == "LeftButton" then
            battlecry:ExecuteMessage()
        end
    end)

    battlecry.panel:SetScript("OnEnter", function()
        battlecry.closeAt = nil
    end)
    battlecry.panel:SetScript("OnLeave", function()
        if not battlecry.editBox:HasFocus() then
            battlecry.closeAt = GetTime() + battlecry.hoverGrace
        end
    end)
    battlecry.panel:SetScript("OnUpdate", function(self)
        if not self:IsShown() then
            return
        end
        if battlecry.editBox:HasFocus() then
            battlecry.closeAt = nil
            return
        end
        if battlecry.button:IsMouseOver() or self:IsMouseOver() then
            battlecry.closeAt = nil
            return
        end
        if not battlecry.closeAt then
            battlecry.closeAt = GetTime() + battlecry.hoverGrace
            return
        end
        if GetTime() >= battlecry.closeAt then
            battlecry.closeAt = nil
            self:Hide()
        end
    end)
    battlecry.panel:SetScript("OnHide", function()
        battlecry.closeAt = nil
        battlecry.savingEdit = false
        battlecry.cancelingEdit = false
        if battlecry.editBox:HasFocus() then
            battlecry:SaveEditedMessage()
        end
    end)

    battlecry.panel:Hide()
    battlecry.frame:HookScript("OnHide", function()
        battlecry.panel:Hide()
    end)

    return battlecry
end
