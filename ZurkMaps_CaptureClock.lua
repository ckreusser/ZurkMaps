-- Shared AV/AB capture-clock presentation. Each map owns timing, placement,
-- objective state, and click handlers; this module only draws and animates clocks.
ZurkMapsCaptureClock = ZurkMapsCaptureClock or {}
local Clock = ZurkMapsCaptureClock

local BORDER_PULSE_SECONDS = 0.24
local FADE_SECONDS = 0.30
-- Match the map/honor rim proportions for this six-unit tooltip border.
local BACKGROUND_INSET = 1.125
local BACKGROUND_CORNER_RADIUS = 1.5
local BORDER_GOLD = { 1.00, 0.78, 0.06 }
local FACTION_BORDER = {
    Alliance = { 0.18, 0.52, 1.00 },
    Horde = { 1.00, 0.16, 0.08 },
}

function Clock.SetBorderExpansion(box, amount)
    if not box or not box.border then return end
    amount = math.max(0, tonumber(amount) or 0)
    box.border:ClearAllPoints()
    box.border:SetPoint("TOPLEFT", box, "TOPLEFT", -amount, amount)
    box.border:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", amount, -amount)
end

function Clock.SetBorderColor(box, faction)
    if not box or not box.border or not box.border.SetBackdropBorderColor then return end
    local color = FACTION_BORDER[faction] or BORDER_GOLD
    box.border:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end

function Clock.SetRemaining(box, value)
    if not box then return end
    local seconds = tonumber(value)
    if not seconds then
        box.minute:SetText("?")
        box.secondTens:SetText("?")
        box.secondOnes:SetText("?")
        return
    end
    seconds = math.max(0, math.ceil(seconds))
    box.minute:SetText(tostring(math.floor(seconds / 60)))
    box.secondTens:SetText(tostring(math.floor((seconds % 60) / 10)))
    box.secondOnes:SetText(tostring(seconds % 10))
end

local function CreateGlyph(parent, offsetX)
    local glyph = parent:CreateFontString(nil, "OVERLAY")
    glyph:SetPoint("CENTER", parent:GetParent(), "CENTER", offsetX, 0)
    glyph:SetFont("Fonts\\ARIALN.TTF", 8, "")
    glyph:SetTextColor(1, 1, 1, 1)
    glyph:SetShadowColor(0, 0, 0, 1)
    glyph:SetShadowOffset(1, -1)
    return glyph
end

function Clock.Create(parent, frameLevel)
    local box = CreateFrame("Button", nil, parent)
    box:SetSize(25, 13)
    box:SetFrameLevel(frameLevel)
    box.border = CreateFrame("Frame", nil, box, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box.border:SetFrameLevel(box:GetFrameLevel() + 1)
    if box.border.SetBackdrop then
        box.border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 6,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end
    Clock.SetBorderExpansion(box, 0)
    Clock.SetBorderColor(box, nil)

    -- Fill beneath the rim, then clip its interior and rounded corners using
    -- the same hard-edged masks as maps and honor bars. Follow the border itself
    -- so the background still fills it throughout the completion pulse.
    box.background = box:CreateTexture(nil, "BACKGROUND")
    box.background:SetAllPoints(box.border)
    box.background:SetTexture("Interface\\Buttons\\WHITE8X8")
    box.background:SetVertexColor(0.018, 0.014, 0.006, 1)
    box.interiorMask = ZurkMapsInteriorMask.Create(box, box.border,
        BACKGROUND_INSET, BACKGROUND_CORNER_RADIUS, true)
    ZurkMapsInteriorMask.Apply(box.interiorMask, box.background)

    -- Fixed glyph anchors keep proportional numerals from shifting the clock.
    box.minute = CreateGlyph(box.border, -6.5)
    box.colon = CreateGlyph(box.border, -2.2)
    box.secondTens = CreateGlyph(box.border, 1.9)
    box.secondOnes = CreateGlyph(box.border, 6.0)
    box.colon:SetText(":")
    Clock.SetRemaining(box, 0)
    box:Hide()
    return box
end

function Clock.Reset(box)
    box:SetAlpha(1)
    box:EnableMouse(true)
    Clock.SetBorderExpansion(box, 0)
    Clock.SetBorderColor(box, nil)
end

function Clock.Complete(box, faction)
    Clock.Reset(box)
    Clock.SetRemaining(box, 0)
    Clock.SetBorderColor(box, faction)
    box:EnableMouse(false)
    box:Show()
end

-- Called every rendered frame; returns true once the completion is hidden.
function Clock.AnimateCompletion(box, animationTime)
    if animationTime < BORDER_PULSE_SECONDS then
        local progress = math.max(0, math.min(1, animationTime / BORDER_PULSE_SECONDS))
        local pulse = math.sin(progress * math.pi)
        Clock.SetBorderExpansion(box, pulse * pulse * 2)
        box:SetAlpha(1)
    else
        Clock.SetBorderExpansion(box, 0)
        local fadeProgress = (animationTime - BORDER_PULSE_SECONDS) / FADE_SECONDS
        box:SetAlpha(math.max(0, 1 - fadeProgress))
        if fadeProgress >= 1 then
            Clock.Reset(box)
            box:Hide()
            return true
        end
    end
    return false
end
