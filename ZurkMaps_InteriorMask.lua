-- Texture-only clipping: borders, buttons, and rank badges stay outside the mask.
ZurkMapsInteriorMask = {}

local function DisableSnapping(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

function ZurkMapsInteriorMask.Create(parent, bounds, inset, radius, hardEdges)
    local clip = { masks = {}, bounds = bounds, inset = inset, hardEdges = hardEdges }
    if not parent.CreateMaskTexture then return clip end

    local rectangle = parent:CreateMaskTexture()
    rectangle:SetPoint("TOPLEFT", bounds, "TOPLEFT", inset, -inset)
    rectangle:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -inset, inset)
    rectangle:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    DisableSnapping(rectangle)
    clip.rectangle = rectangle
    clip.masks[1] = rectangle

    -- MaskTexture does not honor SetTexCoord on this client. Keep each mask
    -- corner-sized and use a separately oriented asset, with no UV transforms.
    -- White outside these small squares preserves the rest of the interior.
    local corners = {
        { "TOPLEFT",     inset, -inset, "InteriorCornerMask" },
        { "TOPRIGHT",   -inset, -inset, "InteriorCornerMask_TopRight" },
        { "BOTTOMLEFT",  inset,  inset, "InteriorCornerMask_BottomLeft" },
        { "BOTTOMRIGHT",-inset,  inset, "InteriorCornerMask_BottomRight" },
    }
    for _, corner in ipairs(corners) do
        local mask = parent:CreateMaskTexture()
        mask:SetPoint(corner[1], bounds, corner[1], corner[2], corner[3])
        mask:SetSize(radius, radius)
        mask:SetTexture("Interface\\AddOns\\ZurkMaps\\Media\\" .. corner[4], "CLAMPTOWHITE", "CLAMPTOWHITE")
        DisableSnapping(mask)
        clip.masks[#clip.masks + 1] = mask
    end
    return clip
end

function ZurkMapsInteriorMask.Apply(clip, texture)
    DisableSnapping(texture)
    if not texture.AddMaskTexture or not clip.rectangle or texture._zurkInteriorClip then return end

    -- WoW permits at most THREE masks per texture. Render the same graphic in
    -- two scissored halves, each with at most the rectangle and its two corners.
    -- Frame clipping makes the center join hard, so translucent artwork is
    -- drawn exactly once there instead of overlapping two feathered masks.
    local parent = texture:GetParent()
    local bounds, inset = clip.bounds, clip.inset
    local function CreateHalf(right)
        local viewport = CreateFrame("Frame", nil, parent)
        viewport:SetFrameLevel(parent:GetFrameLevel())
        viewport:EnableMouse(false)
        viewport:SetClipsChildren(true)
        if right then
            viewport:SetPoint("TOPLEFT", bounds, "TOP", 0, -inset)
            viewport:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -inset, inset)
        else
            viewport:SetPoint("TOPLEFT", bounds, "TOPLEFT", inset, -inset)
            viewport:SetPoint("BOTTOMRIGHT", bounds, "BOTTOM", 0, inset)
        end
        -- Use a child renderer so the viewport clips all of its regions.
        local renderer = CreateFrame("Frame", nil, viewport)
        renderer:SetAllPoints(viewport)
        renderer:SetFrameLevel(parent:GetFrameLevel())
        renderer:EnableMouse(false)
        return renderer
    end

    local left, right = CreateHalf(false), CreateHalf(true)
    local layer, sublevel = texture:GetDrawLayer()
    local mirror = right:CreateTexture(nil, layer, nil, sublevel)
    mirror:SetTexture(texture:GetTexture())
    mirror:SetTexCoord(texture:GetTexCoord())
    mirror:SetVertexColor(texture:GetVertexColor())
    mirror:SetAlpha(texture:GetAlpha())
    mirror:SetBlendMode(texture:GetBlendMode())
    if not texture:IsShown() then mirror:Hide() end
    DisableSnapping(mirror)

    texture:SetParent(left)
    -- Keep the full graphic's geometry and UVs on both halves. Clipping alone
    -- chooses which half is visible, including while a progress fill grows.
    mirror:SetAllPoints(texture)
    -- Tall honor bars magnify WHITE8X8's filtered mask boundary into a long
    -- fade. Their viewports already enforce the exact rectangular boundary,
    -- so only the fixed-size corner masks should affect their alpha.
    if not clip.hardEdges then
        texture:AddMaskTexture(clip.rectangle)
        mirror:AddMaskTexture(clip.rectangle)
    end
    for _, index in ipairs({ 2, 4 }) do texture:AddMaskTexture(clip.masks[index]) end
    for _, index in ipairs({ 3, 5 }) do mirror:AddMaskTexture(clip.masks[index]) end

    -- Existing map-opacity and honor-animation callers retain the original
    -- texture. Forward visual changes; the mirror already follows its anchors.
    for _, name in ipairs({
        "SetTexture", "SetTexCoord", "SetVertexColor", "SetAlpha",
        "SetBlendMode", "SetColorTexture", "SetDrawLayer", "Show", "Hide", "SetShown",
    }) do
        local originalMethod = texture[name]
        texture[name] = function(self, ...)
            local result = originalMethod(self, ...)
            mirror[name](mirror, ...)
            return result
        end
    end
    texture._zurkInteriorClip = clip
    texture._zurkInteriorMirror = mirror
end
