-- Load this mock first, then the real clipping/controller/honor modules.
-- Unlike the earlier simulation smoke check, clipping is NOT stubbed out.
local F = {}
F.__index = F
function CreateFrame(_, _, parent)
    return setmetatable({ parent = parent, shown = true, points = {}, scripts = {} }, F)
end
function F:CreateTexture(_, layer, _, sublevel)
    local texture = CreateFrame(nil, nil, self)
    texture.layer, texture.sublevel = layer, sublevel or 0
    return texture
end
F.CreateFontString = F.CreateTexture
F.CreateMaskTexture = F.CreateTexture
function F:SetParent(parent) self.parent = parent end
function F:GetParent() return self.parent end
function F:SetPoint(point, relative, relativePoint, x, y)
    for i, data in ipairs(self.points) do
        if data[1] == point then table.remove(self.points, i); break end
    end
    self.points[#self.points + 1] = { point, relative or self.parent, relativePoint or point, x or 0, y or 0 }
end
function F:ClearAllPoints() self.points = {} end
function F:SetAllPoints(relative)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", relative or self.parent, "TOPLEFT")
    self:SetPoint("BOTTOMRIGHT", relative or self.parent, "BOTTOMRIGHT")
end
function F:GetPoint(i) return unpack(self.points[i] or {}) end
function F:GetNumPoints() return #self.points end
function F:SetWidth(w) self.width = w end
function F:SetHeight(h) self.height = h end
function F:SetSize(w, h) self.width, self.height = w, h end
local function Fraction(point, axis)
    if point:find(axis == 1 and "LEFT" or "BOTTOM") then return 0 end
    if point:find(axis == 1 and "RIGHT" or "TOP") then return 1 end
    return 0.5
end
function F:Axis(axis)
    local origin, size = 0, (axis == 1 and self.width or self.height) or 0
    local firstFraction, firstPosition
    for _, point in ipairs(self.points) do
        local start, length = point[2]:Axis(axis)
        local position = start + length * Fraction(point[3], axis) + point[axis + 3]
        local fraction = Fraction(point[1], axis)
        if firstFraction and fraction ~= firstFraction then
            size = (position - firstPosition) / (fraction - firstFraction)
            return position - size * fraction, size
        end
        firstFraction, firstPosition = fraction, position
        origin = position - size * fraction
    end
    return origin, size
end
function F:GetWidth() local _, size = self:Axis(1); return size end
function F:GetHeight() local _, size = self:Axis(2); return size end
function F:SetFrameLevel(level) self.level = level end
function F:GetFrameLevel() return self.level or 1 end
function F:GetFrameStrata() return "MEDIUM" end
function F:SetClipsChildren(value) self.clipsChildren = value end
function F:SetScript(event, fn) self.scripts[event] = fn end
function F:HookScript(event, fn)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
end
function F:Show() self.shown = true end
function F:Hide() self.shown = false end
function F:IsShown() return self.shown end
function F:SetShown(value) self.shown = value end
function F:SetTexture(value) self.texture = value end
function F:GetTexture() return self.texture end
function F:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
function F:GetDrawLayer() return self.layer, self.sublevel end
function F:SetTexCoord(...) self.uv = {...} end
function F:GetTexCoord() return unpack(self.uv or {0, 1, 0, 1}) end
function F:SetVertexColor(...) self.color = {...} end
function F:GetVertexColor() return unpack(self.color or {1, 1, 1, 1}) end
function F:SetAlpha(alpha) self.alpha = alpha end
function F:GetAlpha() return self.alpha or 1 end
function F:SetBlendMode(mode) self.blend = mode end
function F:GetBlendMode() return self.blend or "BLEND" end
function F:AddMaskTexture(mask) self.masks = self.masks or {}; table.insert(self.masks, mask) end
for _, name in ipairs({"EnableMouse", "RegisterEvent", "SetFrameStrata", "RegisterForClicks",
    "SetClampedToScreen", "SetMovable", "RegisterForDrag", "SetScale", "SetBackdrop",
    "SetBackdropColor", "SetBackdropBorderColor", "SetFont", "SetTextColor", "SetText",
    "SetOwner", "AddLine", "SetSnapToPixelGrid", "SetTexelSnappingBias"}) do
    F[name] = function() end
end

UIParent = CreateFrame(); UIParent:SetSize(1920, 1080)
GameTooltip = CreateFrame()
BackdropTemplateMixin = {}
C_Timer = { NewTicker = function() end }
local now, realHonor = 100, 20000
function GetTime() return now end
function UnitPVPRank() return 16 end
function GetPVPRankInfo() return "General", 12 end
function GetPVPRankProgress() return 0 end
function UnitFactionGroup() return "Horde" end
function GetPVPThisWeekStats() return 50, realHonor end
ZurkMapsHonorDB = { widget = {schemaVersion = 3, mode = "ATTACHED"} }

function RunHonorBarTests()
    local checks = 0
    local function Check(value, message) assert(value, message); checks = checks + 1 end
    local function Near(a, b, message) Check(math.abs(a - b) < 0.00001, message) end
    for _, module in ipairs({ZurkMapsWSGHonor, ZurkMapsABHonor, ZurkMapsAVHonor}) do
        local parent = CreateFrame(nil, nil, UIParent); parent:SetSize(340, 526)
        local bar = module.Create(parent, parent, 526)
        bar:ClearAllPoints(); bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 100)
        for _, horizontal in ipairs({false, true}) do
            for _, length in ipairs({300, 526, 1000}) do
                bar:SetSize(horizontal and length or 18, horizontal and 18 or length)
                module.simulatedHonor = 0
                module.Refresh(true)
                local renderer = bar.track:GetParent()
                local viewport = renderer:GetParent()
                Check(viewport.clipsChildren, "honor content must have a hard clipping boundary")
                Near(viewport:GetWidth(), bar:GetWidth() - 3, "clip must span full inner width")
                Near(viewport:GetHeight(), bar:GetHeight() - 3, "clip must span full inner height")
                for _, tex in ipairs({bar.fill, bar.incompleteOverlay, bar.unrealizedStripes, bar.currentLine}) do
                    Check(tex:GetParent() == renderer, "honor layers must share one renderer")
                    Check(not tex._zurkInteriorMirror, "honor content must not depend on a half-width mirror")
                    Check(not tex.masks, "honor content must not fade through stretched texture masks")
                end
                Check(bar.track.layer == "BACKGROUND", "track must remain behind fill")
                Check(bar.unrealizedStripes.sublevel > bar.incompleteOverlay.sublevel, "stripes must be above incomplete fill")

                -- Before the first breakpoint, all earned honor is striped.
                Check(bar.unrealizedStripes:IsShown(), "unrealized stripes must be visible")
                Near(horizontal and bar.unrealizedStripes:GetHeight() or bar.unrealizedStripes:GetWidth(), 15, "stripes must span full thickness")
                local progressAxis = horizontal and 1 or 2
                local before = table.concat(bar.unrealizedStripes.uv, ",")
                module.AddSimulatedHonor(1000)
                Check(bar._unrealizedStripeAnimator:IsShown(), "honor gain must start sweep")
                now = now + 0.5
                bar._unrealizedStripeAnimator.scripts.OnUpdate(bar._unrealizedStripeAnimator)
                Check(table.concat(bar.unrealizedStripes.uv, ",") ~= before, "sweep must move visible stripe UVs")
                now = now + 0.6
                bar._unrealizedStripeAnimator.scripts.OnUpdate(bar._unrealizedStripeAnimator)
                Check(not bar._unrealizedStripeAnimator:IsShown(), "sweep must settle")
                local settled = table.concat(bar.unrealizedStripes.uv, ",")
                module.Refresh(false)
                Check(table.concat(bar.unrealizedStripes.uv, ",") == settled, "idle stripes must stay still")

                -- Crossing a breakpoint must join completed and striped honor
                -- without a gap, and preserve the correct TOTAL progress.
                module.AddSimulatedHonor(bar.state.milestones[1].honor + 1000 - bar.state.currentHonor)
                local fillStart, fillLength = bar.fill:Axis(progressAxis)
                local stripeStart, stripeLength = bar.unrealizedStripes:Axis(progressAxis)
                Check(bar.fill:IsShown() and bar.unrealizedStripes:IsShown(), "breakpoint must retain both portions")
                Near(fillStart + fillLength, stripeStart, "completed and unrealized honor must meet")
                Near(fillLength + stripeLength, (length - 3) * bar.state.currentHonor / bar.state.maxHonor, "total honor length must be proportional")
                module.AddSimulatedHonor(bar.state.maxHonor - bar.state.currentHonor)
                Check(bar.fill:IsShown() and not bar.unrealizedStripes:IsShown(), "maximum must be fully realized")
                Near(horizontal and bar.fill:GetWidth() or bar.fill:GetHeight(), length - 3, "maximum must fill entire bar")
                Near(horizontal and bar.fill:GetHeight() or bar.fill:GetWidth(), 15, "maximum must fill entire thickness")
                module.AddSimulatedHonor(-module.GetSimulatedHonor())
                Check(bar.state.currentHonor == realHonor and bar.unrealizedStripes:IsShown(), "reset must restore actual honor and stripes")
            end
        end
    end
    Check(ZurkMapsAVHonor.GetBreakpointCelebrationSnapshot().currentHonor == realHonor, "simulation must not alter real breakpoint history")
    print(string.format("Honor bar: %d checks passed across WSG/AB/AV, both orientations, three sizes, fill and animation.", checks))
end
