-- Uniform map resizing about the visible top-left corner. Capture the actual
-- mouse grab point so frame padding and the grip's inset don't distort dragging.
ZurkMapsMapResize = {}

function ZurkMapsMapResize.Begin(frame, bounds)
    local uiScale = UIParent:GetEffectiveScale()
    local frameScale = frame:GetEffectiveScale() / uiScale
    local boundsScale = bounds:GetEffectiveScale() / uiScale
    local left, top = bounds:GetLeft() * boundsScale, bounds:GetTop() * boundsScale
    local cursorX, cursorY = GetCursorPosition()
    local grabX, grabY = cursorX / uiScale - left, top - cursorY / uiScale
    return {
        left = left,
        top = top,
        frameOffsetX = frame:GetLeft() * frameScale - left,
        frameOffsetY = frame:GetTop() * frameScale - top,
        grabX = grabX,
        grabY = grabY,
        grabLengthSquared = grabX * grabX + grabY * grabY,
        startScale = frame:GetScale(),
    }
end

function ZurkMapsMapResize.Update(frame, state, minScale, maxScale)
    local uiScale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local dx, dy = cursorX / uiScale - state.left, state.top - cursorY / uiScale
    local ratio = state.grabLengthSquared > 0
        and (dx * state.grabX + dy * state.grabY) / state.grabLengthSquared or 1
    -- Project onto the map's resize diagonal to preserve its aspect ratio.
    local scale = math.max(minScale, math.min(maxScale, state.startScale * ratio))
    ratio = scale / state.startScale
    frame:SetScale(scale)
    local frameScale = frame:GetEffectiveScale() / uiScale
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
        (state.left + state.frameOffsetX * ratio) / frameScale,
        (state.top + state.frameOffsetY * ratio) / frameScale)
    return scale
end
