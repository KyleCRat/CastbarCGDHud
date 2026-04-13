local ADDON_NAME, NS = ...

local EVENT_HANDLERS = NS.EVENT_HANDLERS

local castBar
local latencyBar

local function GetLatencySeconds()
    local _, _, _, latencyWorld = GetNetStats()

    return latencyWorld / 1000
end

function NS:CreateCastBar()
    local db = NS.db.castBar
    local startAngle = 190
    local endAngle = 350

    castBar = NS:CreateRadialBar(NS.hud, startAngle, endAngle, db.color, db.bgColor)
    castBar.invert = db.invert
    castBar.clockwise = db.clockwise
    NS.castBar = castBar

    latencyBar = NS:CreateRadialBar(NS.hud, startAngle, endAngle, db.latencyColor, { 0, 0, 0, 0 })
    latencyBar.invert = db.invert
    latencyBar.clockwise = db.clockwise
    NS.latencyBar = latencyBar

    -- Hide bg if not always showing
    if not db.bgAlwaysShow then
        castBar:HideBackground()
    end
    latencyBar:HideBackground()

    local f = NS.eventFrame
    f:RegisterEvent("UNIT_SPELLCAST_START")
    f:RegisterEvent("UNIT_SPELLCAST_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_FAILED")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    f:RegisterEvent("UNIT_SPELLCAST_DELAYED")
end

local function IsPlayerUnit(unit)
    return unit == "player" or unit == "vehicle"
end

local casting = false
local channeling = false

local function ShowCastBg()
    if not NS.db.castBar.bgAlwaysShow then
        castBar:ShowBackground()
    end
end

local function HideCastBg()
    if not NS.db.castBar.bgAlwaysShow then
        castBar:HideBackground()
    end
end

local function UpdateLatencyZone(durationMS)
    local latencySec = GetLatencySeconds()
    local castDuration = durationMS / 1000

    if castDuration <= 0 then
        latencyBar:Clear()

        return
    end

    local latencyRatio = latencySec / castDuration
    latencyRatio = math.min(latencyRatio, 0.3)

    if latencyRatio <= 0.005 then
        latencyBar:Clear()

        return
    end

    latencyBar:SetProgressRange(1 - latencyRatio, 1)
end

local function StartCastUpdate()
    if NS.castTicker then return end
    ShowCastBg()
    NS.castTicker = C_Timer.NewTicker(0.02, function()
        NS:UpdateCastProgress()
    end)
end

local function StopCastUpdate()
    if NS.castTicker then
        NS.castTicker:Cancel()
        NS.castTicker = nil
    end
    castBar:Clear()
    latencyBar:Clear()
    HideCastBg()
    casting = false
    channeling = false
end

function NS:UpdateCastProgress()
    if casting then
        local name, _, _, startTimeMS, endTimeMS = UnitCastingInfo("player")
        if not name then
            StopCastUpdate()

            return
        end

        local now = GetTime() * 1000
        local progress = (now - startTimeMS) / (endTimeMS - startTimeMS)
        castBar:SetProgress(math.max(0, math.min(1, progress)))

        return
    end

    if channeling then
        local name, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
        if not name then
            StopCastUpdate()

            return
        end

        local now = GetTime() * 1000
        local progress = (endTimeMS - now) / (endTimeMS - startTimeMS)
        castBar:SetProgress(math.max(0, math.min(1, progress)))
    end
end

EVENT_HANDLERS["UNIT_SPELLCAST_START"] = function(self, unit)
    if not IsPlayerUnit(unit) then return end
    casting = true
    channeling = false

    local _, _, _, startTimeMS, endTimeMS = UnitCastingInfo("player")
    if startTimeMS and endTimeMS then
        UpdateLatencyZone(endTimeMS - startTimeMS)
    end

    StartCastUpdate()
end

EVENT_HANDLERS["UNIT_SPELLCAST_CHANNEL_START"] = function(self, unit)
    if not IsPlayerUnit(unit) then return end
    channeling = true
    casting = false

    local _, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
    if startTimeMS and endTimeMS then
        UpdateLatencyZone(endTimeMS - startTimeMS)
    end

    StartCastUpdate()
end

EVENT_HANDLERS["UNIT_SPELLCAST_STOP"] = function(self, unit)
    if not IsPlayerUnit(unit) then return end
    if casting then StopCastUpdate() end
end

EVENT_HANDLERS["UNIT_SPELLCAST_CHANNEL_STOP"] = function(self, unit)
    if not IsPlayerUnit(unit) then return end
    if channeling then StopCastUpdate() end
end

EVENT_HANDLERS["UNIT_SPELLCAST_FAILED"] = function(self, unit)
    if not IsPlayerUnit(unit) then return end
    StopCastUpdate()
end

EVENT_HANDLERS["UNIT_SPELLCAST_INTERRUPTED"] = function(self, unit)
    if not IsPlayerUnit(unit) then return end
    StopCastUpdate()
end

EVENT_HANDLERS["UNIT_SPELLCAST_SUCCEEDED"] = function(self, unit)
    if not IsPlayerUnit(unit) then return end
    if casting then StopCastUpdate() end
end

EVENT_HANDLERS["UNIT_SPELLCAST_DELAYED"] = function() end

EVENT_HANDLERS["UNIT_SPELLCAST_CHANNEL_UPDATE"] = function() end
