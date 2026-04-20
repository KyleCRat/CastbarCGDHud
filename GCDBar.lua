local ADDON_NAME, NS = ...

local EVENT_HANDLERS = NS.EVENT_HANDLERS

local gcdBar
local GCD_FLASH_DURATION = 0.12
local ACTIVE_TICK_SECONDS = 0.02
NS.GCD_FLASH_DURATION = GCD_FLASH_DURATION

local function GetGCDInfo()
    local info = C_Spell.GetSpellCooldown(61304)
    if not info then
        return nil, nil, true
    end

    local start, duration = info.startTime, info.duration
    if not start or not duration then
        return nil, nil, true
    end

    if NS:IsSecretValue(start) or NS:IsSecretValue(duration) then
        return nil, nil, true
    end

    return start, duration
end

function NS:CreateGCDBar()
    local db = NS.db.gcdBar
    local startAngle, endAngle = NS:GetArcAngles(db, NS.DEFAULTS.gcdBar, NS.ARC_LIMITS.gcdBar)

    gcdBar = NS:CreateRadialBar(NS.hud, startAngle, endAngle, db.color, db.bgColor)
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

local function RestoreGCDColor()
    if gcdBar then
        gcdBar:SetFgColor(unpack(NS.db.gcdBar.color))
    end
end

function NS:CancelGCDFlash()
    if NS.gcdFlashTimer then
        NS.gcdFlashTimer:Cancel()
        NS.gcdFlashTimer = nil
    end

    NS.gcdFlashActive = false
    RestoreGCDColor()
end

function NS:ShowGCDFlash()
    if not gcdBar then return end

    if NS:IsCastBarActive() then
        RestoreGCDColor()
        gcdBar:Clear()
        HideGCDBg()

        return
    end

    if not NS.db.gcdBar.flashEnabled then
        RestoreGCDColor()
        gcdBar:Clear()
        HideGCDBg()

        return
    end

    if NS.gcdFlashTimer then
        NS.gcdFlashTimer:Cancel()
        NS.gcdFlashTimer = nil
    end

    NS.gcdFlashActive = true
    gcdBar:SetFgColor(unpack(NS.db.gcdBar.flashColor))
    gcdBar:SetFull()

    NS.gcdFlashTimer = C_Timer.NewTimer(GCD_FLASH_DURATION, function()
        NS.gcdFlashTimer = nil
        NS.gcdFlashActive = false
        RestoreGCDColor()
        gcdBar:Clear()
        HideGCDBg()
    end)
end

local function StartGCDUpdate()
    if NS.gcdTicker then return end
    NS:CancelGCDFlash()
    ShowGCDBg()
    NS.gcdTicker = C_Timer.NewTicker(ACTIVE_TICK_SECONDS, function()
        NS:UpdateGCDProgress()
    end)
end

local function StopGCDUpdate(showFlash)
    if NS.gcdTicker then
        NS.gcdTicker:Cancel()
        NS.gcdTicker = nil
    end
    gcdTracking = false

    if showFlash then
        NS:ShowGCDFlash()
    else
        NS:CancelGCDFlash()
        gcdBar:Clear()
        HideGCDBg()
    end
end

function NS:UpdateGCDProgress()
    local start, duration, unusableTiming = GetGCDInfo()
    if unusableTiming then
        StopGCDUpdate(false)

        return
    end

    if duration == 0 or start == 0 then
        StopGCDUpdate(gcdTracking)

        return
    end

    local elapsed = GetTime() - start
    local progress = elapsed / duration

    if progress >= 1 then
        StopGCDUpdate(true)

        return
    end

    gcdBar:SetProgress(math.max(0, math.min(1, progress)))
end

EVENT_HANDLERS["SPELL_UPDATE_COOLDOWN"] = function()
    local start, duration, unusableTiming = GetGCDInfo()
    if unusableTiming then
        if gcdTracking then StopGCDUpdate(false) end

        return
    end

    if duration == 0 or start == 0 then
        if gcdTracking then StopGCDUpdate(true) end

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
    ticker = C_Timer.NewTicker(ACTIVE_TICK_SECONDS, function()
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
