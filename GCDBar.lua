local ADDON_NAME, NS = ...

local EVENT_HANDLERS = NS.EVENT_HANDLERS

local gcdBar

local function GetGCDInfo()
    local info = C_Spell.GetSpellCooldown(61304)
    if not info then
        return 0, 0
    end

    return info.startTime, info.duration
end

function NS:CreateGCDBar()
    local db = NS.db.gcdBar
    gcdBar = NS:CreateRadialBar(NS.hud, 10, 170, db.color, db.bgColor)
    gcdBar.invert = db.invert
    gcdBar.clockwise = db.clockwise
    NS.gcdBar = gcdBar

    if not db.bgAlwaysShow then
        gcdBar:HideBackground()
    end

    NS.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
end

local gcdTracking = false

local function ShowGCDBg()
    if not NS.db.gcdBar.bgAlwaysShow then
        gcdBar:ShowBackground()
    end
end

local function HideGCDBg()
    if not NS.db.gcdBar.bgAlwaysShow then
        gcdBar:HideBackground()
    end
end

local function StartGCDUpdate()
    if NS.gcdTicker then return end
    ShowGCDBg()
    NS.gcdTicker = C_Timer.NewTicker(0.02, function()
        NS:UpdateGCDProgress()
    end)
end

local function StopGCDUpdate()
    if NS.gcdTicker then
        NS.gcdTicker:Cancel()
        NS.gcdTicker = nil
    end
    gcdBar:Clear()
    HideGCDBg()
    gcdTracking = false
end

function NS:UpdateGCDProgress()
    local start, duration = GetGCDInfo()
    if duration == 0 or start == 0 then
        StopGCDUpdate()

        return
    end

    local elapsed = GetTime() - start
    local progress = elapsed / duration

    if progress >= 1 then
        StopGCDUpdate()

        return
    end

    gcdBar:SetProgress(math.max(0, math.min(1, progress)))
end

EVENT_HANDLERS["SPELL_UPDATE_COOLDOWN"] = function()
    local start, duration = GetGCDInfo()
    if duration == 0 or start == 0 then
        if gcdTracking then StopGCDUpdate() end

        return
    end

    gcdTracking = true
    StartGCDUpdate()
end

-- Test function for both bars
function NS:TestBars()
    NS:Print("Running test animation...")
    local startTime = GetTime()
    local duration = 2.0

    if NS.castBar then NS.castBar:ShowBackground() end
    if NS.gcdBar then NS.gcdBar:ShowBackground() end

    local ticker
    ticker = C_Timer.NewTicker(0.02, function()
        local elapsed = GetTime() - startTime
        local progress = elapsed / duration

        if progress >= 1 then
            ticker:Cancel()
            NS.castBar:Clear()
            NS.gcdBar:Clear()
            if not NS.db.castBar.bgAlwaysShow then NS.castBar:HideBackground() end
            if not NS.db.gcdBar.bgAlwaysShow then NS.gcdBar:HideBackground() end
            NS:Print("Test complete.")

            return
        end

        NS.castBar:SetProgress(progress)
        NS.gcdBar:SetProgress(progress)
    end)
end
