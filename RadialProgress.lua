local ADDON_NAME, NS = ...

--[[
    Radial progress texture — adapted from WeakAuras' CircularProgressTexture
    and TextureCoords system.

    Uses up to 3 texture quads per progress bar, deforming vertices with
    SetVertexOffset and mapping UVs with SetTexCoord to create angular
    wedge shapes. The ring texture's alpha channel clips to the ring band.

    Angle convention: 0° = 12 o'clock, increases clockwise.
]]

local floor = math.floor
local tan = math.tan
local cos = math.cos
local sin = math.sin
local rad = math.rad
local max = math.max
local min = math.min

-- Default tex coords for a full quad
local defaultTexCoord = {
    ULx = 0, ULy = 0,
    LLx = 0, LLy = 1,
    URx = 1, URy = 0,
    LRx = 1, LRy = 1,
}

-- Exact coords for angles at 45° increments (0°, 45°, 90°, ... 315°)
-- Maps angle to a point on the edge of the unit square
local exactAngles = {
    { 0.5, 0 },   -- 0°
    { 1, 0 },     -- 45°
    { 1, 0.5 },   -- 90°
    { 1, 1 },     -- 135°
    { 0.5, 1 },   -- 180°
    { 0, 1 },     -- 225°
    { 0, 0.5 },   -- 270°
    { 0, 0 },     -- 315°
}

-- Convert angle (degrees, 0=top, clockwise) to a point on the unit square edge
local function angleToCoord(angle)
    angle = angle % 360

    if angle % 45 == 0 then
        local index = floor(angle / 45) + 1

        return exactAngles[index][1], exactAngles[index][2]
    end

    if angle < 45 then
        return 0.5 + tan(rad(angle)) / 2, 0
    elseif angle < 135 then
        return 1, 0.5 + tan(rad(angle - 90)) / 2
    elseif angle < 225 then
        return 0.5 - tan(rad(angle)) / 2, 1
    elseif angle < 315 then
        return 0, 0.5 - tan(rad(angle - 90)) / 2
    else
        return 0.5 + tan(rad(angle)) / 2, 0
    end
end

-- Corner cycle for quadrant-based traversal
local pointOrder = { "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR" }

-- Transform a texture coordinate for crop and rotation
local function TransformPoint(x, y, crop_x, crop_y, texRotation, mirror_h, mirror_v)
    x = x - 0.5
    y = y - 0.5

    x = x * 1.4142
    y = y * 1.4142

    x = x / crop_x
    y = y / crop_y

    if mirror_h then x = -x end
    if mirror_v then y = -y end

    if texRotation ~= 0 then
        local cos_r = cos(texRotation)
        local sin_r = sin(texRotation)
        x, y = cos_r * x - sin_r * y, sin_r * x + cos_r * y
    end

    x = x + 0.5
    y = y + 0.5

    return x, y
end

---------------------------------------------------------------------------
-- TextureCoord object — manages one texture quad's coords + vertex offsets
---------------------------------------------------------------------------
local function CreateCoord(texture)
    local coord = {
        ULx = 0, ULy = 0,
        LLx = 0, LLy = 1,
        URx = 1, URy = 0,
        LRx = 1, LRy = 1,

        ULvx = 0, ULvy = 0,
        LLvx = 0, LLvy = 0,
        URvx = 0, URvy = 0,
        LRvx = 0, LRvy = 0,

        texture = texture,
    }

    function coord:MoveCorner(width, height, corner, x, y)
        local rx = defaultTexCoord[corner .. "x"] - x
        local ry = defaultTexCoord[corner .. "y"] - y
        self[corner .. "vx"] = -rx * width
        self[corner .. "vy"] = ry * height
        self[corner .. "x"] = x
        self[corner .. "y"] = y
    end

    function coord:SetFull()
        self.ULx = 0; self.ULy = 0
        self.LLx = 0; self.LLy = 1
        self.URx = 1; self.URy = 0
        self.LRx = 1; self.LRy = 1
        self.ULvx = 0; self.ULvy = 0
        self.LLvx = 0; self.LLvy = 0
        self.URvx = 0; self.URvy = 0
        self.LRvx = 0; self.LRvy = 0
    end

    function coord:SetAngle(width, height, angle1, angle2)
        local index = floor((angle1 + 45) / 90)

        local middleCorner = pointOrder[index + 1]
        local startCorner = pointOrder[index + 2]
        local endCorner1 = pointOrder[index + 3]
        local endCorner2 = pointOrder[index + 4]

        self:MoveCorner(width, height, middleCorner, 0.5, 0.5)
        self:MoveCorner(width, height, startCorner, angleToCoord(angle1))

        local edge1 = floor((angle1 - 45) / 90)
        local edge2 = floor((angle2 - 45) / 90)

        if edge1 == edge2 then
            self:MoveCorner(width, height, endCorner1, angleToCoord(angle2))
        else
            self:MoveCorner(width, height, endCorner1,
                defaultTexCoord[endCorner1 .. "x"],
                defaultTexCoord[endCorner1 .. "y"])
        end

        self:MoveCorner(width, height, endCorner2, angleToCoord(angle2))
    end

    function coord:Transform(crop_x, crop_y, texRotation, mirror_h, mirror_v)
        self.ULx, self.ULy = TransformPoint(self.ULx, self.ULy, crop_x, crop_y, texRotation, mirror_h, mirror_v)
        self.LLx, self.LLy = TransformPoint(self.LLx, self.LLy, crop_x, crop_y, texRotation, mirror_h, mirror_v)
        self.URx, self.URy = TransformPoint(self.URx, self.URy, crop_x, crop_y, texRotation, mirror_h, mirror_v)
        self.LRx, self.LRy = TransformPoint(self.LRx, self.LRy, crop_x, crop_y, texRotation, mirror_h, mirror_v)
    end

    function coord:Apply()
        self.texture:SetVertexOffset(UPPER_RIGHT_VERTEX, self.URvx, self.URvy)
        self.texture:SetVertexOffset(UPPER_LEFT_VERTEX, self.ULvx, self.ULvy)
        self.texture:SetVertexOffset(LOWER_RIGHT_VERTEX, self.LRvx, self.LRvy)
        self.texture:SetVertexOffset(LOWER_LEFT_VERTEX, self.LLvx, self.LLvy)
        self.texture:SetTexCoord(self.ULx, self.ULy, self.LLx, self.LLy, self.URx, self.URy, self.LRx, self.LRy)
    end

    function coord:Show()
        self:Apply()
        self.texture:Show()
    end

    function coord:Hide()
        self.texture:Hide()
    end

    return coord
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- Create a circular progress bar
-- parent: parent frame (textures created on this)
-- startAngle, endAngle: angular range in degrees (0=top, clockwise)
-- fgColor, bgColor: {r, g, b, a}
-- crop_x, crop_y: texture crop (0-1 scale, default 0.41 to show ring band)
-- mirror: flip horizontally (for left side)
function NS:CreateRadialBar(parent, startAngle, endAngle, fgColor, bgColor, crop_x, crop_y, mirror)
    crop_x = crop_x or 0.41
    crop_y = crop_y or 0.41
    mirror = mirror or false

    local width = parent:GetWidth()
    local height = parent:GetHeight()

    -- Background: full arc, dimmed
    local bgTextures = {}
    local bgCoords = {}
    for i = 1, 3 do
        local tex = parent:CreateTexture(nil, "BORDER")
        tex:SetTexture(NS.RING_TEXTURE)
        tex:SetVertexColor(unpack(bgColor))
        tex:SetAllPoints()
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
        bgTextures[i] = tex
        bgCoords[i] = CreateCoord(tex)
    end

    -- Foreground: animated arc
    local fgTextures = {}
    local fgCoords = {}
    for i = 1, 3 do
        local tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(NS.RING_TEXTURE)
        tex:SetVertexColor(unpack(fgColor))
        tex:SetAllPoints()
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
        tex:Hide()
        fgTextures[i] = tex
        fgCoords[i] = CreateCoord(tex)
    end

    local bar = {
        fgCoords = fgCoords,
        bgCoords = bgCoords,
        fgTextures = fgTextures,
        bgTextures = bgTextures,
        startAngle = startAngle,
        endAngle = endAngle,
        width = width,
        height = height,
        crop_x = crop_x,
        crop_y = crop_y,
        mirror = mirror,
        invert = false,
        clockwise = true,
        bgVisible = true,
    }

    local function updateCoords(coords, angle1, angle2)
        local w, h = bar.width, bar.height
        local cx, cy = bar.crop_x, bar.crop_y
        local texRot = 0
        local mirror_h = bar.mirror

        if angle2 - angle1 >= 360 then
            coords[1]:SetFull()
            coords[1]:Transform(cx, cy, texRot, mirror_h, false)
            coords[1]:Show()
            coords[2]:Hide()
            coords[3]:Hide()

            return
        end

        if angle1 == angle2 then
            coords[1]:Hide()
            coords[2]:Hide()
            coords[3]:Hide()

            return
        end

        local index1 = floor((angle1 + 45) / 90)
        local index2 = floor((angle2 + 45) / 90)

        if index1 + 1 >= index2 then
            coords[1]:SetAngle(w, h, angle1, angle2)
            coords[1]:Transform(cx, cy, texRot, mirror_h, false)
            coords[1]:Show()
            coords[2]:Hide()
            coords[3]:Hide()
        elseif index1 + 3 >= index2 then
            local firstEnd = (index1 + 1) * 90 + 45
            coords[1]:SetAngle(w, h, angle1, firstEnd)
            coords[1]:Transform(cx, cy, texRot, mirror_h, false)
            coords[1]:Show()

            coords[2]:SetAngle(w, h, firstEnd, angle2)
            coords[2]:Transform(cx, cy, texRot, mirror_h, false)
            coords[2]:Show()

            coords[3]:Hide()
        else
            local firstEnd = (index1 + 1) * 90 + 45
            local secondEnd = firstEnd + 180

            coords[1]:SetAngle(w, h, angle1, firstEnd)
            coords[1]:Transform(cx, cy, texRot, mirror_h, false)
            coords[1]:Show()

            coords[2]:SetAngle(w, h, firstEnd, secondEnd)
            coords[2]:Transform(cx, cy, texRot, mirror_h, false)
            coords[2]:Show()

            coords[3]:SetAngle(w, h, secondEnd, angle2)
            coords[3]:Transform(cx, cy, texRot, mirror_h, false)
            coords[3]:Show()
        end
    end

    -- Show background
    updateCoords(bgCoords, startAngle, endAngle)

    function bar:SetProgress(progress)
        progress = max(0, min(1, progress))

        if self.invert then
            progress = 1 - progress
        end

        if progress <= 0 then
            self:Clear()

            return
        end

        local totalArc = self.endAngle - self.startAngle
        if self.clockwise then
            local currentAngle = self.startAngle + totalArc * progress
            updateCoords(self.fgCoords, self.startAngle, currentAngle)
        else
            local currentAngle = self.endAngle - totalArc * progress
            updateCoords(self.fgCoords, currentAngle, self.endAngle)
        end
    end

    -- Show a filled arc between two progress values (e.g. latency window)
    function bar:SetProgressRange(progressStart, progressEnd)
        if self.invert then
            progressStart, progressEnd = 1 - progressEnd, 1 - progressStart
        end

        progressStart = max(0, min(1, progressStart))
        progressEnd = max(0, min(1, progressEnd))

        if progressStart >= progressEnd then
            self:Clear()

            return
        end

        local totalArc = self.endAngle - self.startAngle
        local angleStart, angleEnd

        if self.clockwise then
            angleStart = self.startAngle + totalArc * progressStart
            angleEnd = self.startAngle + totalArc * progressEnd
        else
            angleStart = self.endAngle - totalArc * progressEnd
            angleEnd = self.endAngle - totalArc * progressStart
        end

        updateCoords(self.fgCoords, angleStart, angleEnd)
    end

    function bar:Clear()
        for i = 1, 3 do
            self.fgCoords[i]:Hide()
        end
    end

    function bar:SetFull()
        updateCoords(self.fgCoords, self.startAngle, self.endAngle)
    end

    function bar:ShowBackground()
        self.bgVisible = true
        updateCoords(self.bgCoords, self.startAngle, self.endAngle)
    end

    function bar:HideBackground()
        self.bgVisible = false
        for i = 1, 3 do
            self.bgCoords[i]:Hide()
        end
    end

    function bar:SetFgColor(r, g, b, a)
        for i = 1, 3 do
            self.fgTextures[i]:SetVertexColor(r, g, b, a)
        end
    end

    function bar:SetBgColor(r, g, b, a)
        for i = 1, 3 do
            self.bgTextures[i]:SetVertexColor(r, g, b, a)
        end
    end

    function bar:SetFgDrawLayer(layer, subLevel)
        for i = 1, 3 do
            self.fgTextures[i]:SetDrawLayer(layer, subLevel)
        end
    end

    function bar:SetBgDrawLayer(layer, subLevel)
        for i = 1, 3 do
            self.bgTextures[i]:SetDrawLayer(layer, subLevel)
        end
    end

    return bar
end
