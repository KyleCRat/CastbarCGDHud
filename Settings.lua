local ADDON_NAME, NS = ...

---------------------------------------------------------------------------
-- Color picker
---------------------------------------------------------------------------
local function Clamp01(value, fallback)
    if type(value) ~= "number" then
        value = fallback or 0
    end

    return math.max(0, math.min(1, value))
end

local function OpenColorPicker(colorTable, onChanged)
    local oldR = Clamp01(colorTable[1], 1)
    local oldG = Clamp01(colorTable[2], 1)
    local oldB = Clamp01(colorTable[3], 1)
    local oldA = Clamp01(colorTable[4], 1)

    local lastR, lastG, lastB, lastA = oldR, oldG, oldB, oldA
    local initializing = true

    local function SetColor(r, g, b, a)
        colorTable[1] = Clamp01(r, oldR)
        colorTable[2] = Clamp01(g, oldG)
        colorTable[3] = Clamp01(b, oldB)
        colorTable[4] = Clamp01(a, oldA)
    end

    local function Apply()
        if initializing then return end

        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        local newA = ColorPickerFrame:GetColorAlpha()
        newA = newA ~= nil and newA or oldA

        if newR == lastR and newG == lastG and newB == lastB and newA == lastA then
            return
        end

        lastR, lastG, lastB, lastA = newR, newG, newB, newA
        SetColor(newR, newG, newB, newA)

        if onChanged then
            onChanged()
        end
    end

    local function Cancel()
        SetColor(oldR, oldG, oldB, oldA)

        if onChanged then
            onChanged()
        end
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = oldR,
        g = oldG,
        b = oldB,
        opacity = oldA,
        hasOpacity = true,
        swatchFunc = Apply,
        opacityFunc = Apply,
        cancelFunc = Cancel,
    })

    initializing = false
end

local function CreateColorSettingInitializer(label, colorTable, onChanged)
    return CreateSettingsButtonInitializer(label, "Edit Color", function()
        OpenColorPicker(colorTable, onChanged)
    end, "Open the color picker with opacity.", true)
end

---------------------------------------------------------------------------
-- Live settings preview
---------------------------------------------------------------------------
local PREVIEW_DURATION = 2.0
local PREVIEW_RESTART_DELAY = 1.0
local PREVIEW_LATENCY_RATIO = 0.18
local PREVIEW_TICK_SECONDS = 0.02

local function IsAddonSettingsSelected()
    return SettingsPanel
        and SettingsPanel:IsShown()
        and NS.settingsCategory
        and SettingsPanel:GetCurrentCategory() == NS.settingsCategory
end

local function RestoreBackgroundVisibility()
    if NS.castBar then
        if NS.db.castBar.bgAlwaysShow then
            NS.castBar:ShowBackground()
        else
            NS.castBar:HideBackground()
        end
    end

    if NS.gcdBar then
        if NS.db.gcdBar.bgAlwaysShow then
            NS.gcdBar:ShowBackground()
        else
            NS.gcdBar:HideBackground()
        end
    end
end

function NS:UpdateSettingsPreview()
    if not IsAddonSettingsSelected() then
        self:StopSettingsPreview()

        return
    end

    if not self.castBar or not self.gcdBar then
        return
    end

    local cycleDuration = PREVIEW_DURATION + PREVIEW_RESTART_DELAY
    local elapsed = (GetTime() - (self.settingsPreviewStartTime or GetTime())) % cycleDuration

    if elapsed >= PREVIEW_DURATION then
        self.castBar:Clear()
        self.gcdBar:Clear()
        if self.latencyBar then self.latencyBar:Clear() end
        RestoreBackgroundVisibility()

        return
    end

    local progress = elapsed / PREVIEW_DURATION

    self.castBar:ShowBackground()
    self.gcdBar:ShowBackground()
    self.castBar:SetProgress(progress)
    self.gcdBar:SetProgress(progress)
    if self.latencyBar then self.latencyBar:SetProgressRange(1 - PREVIEW_LATENCY_RATIO, 1) end
end

function NS:StartSettingsPreview()
    if self.settingsPreviewTicker then
        self:UpdateSettingsPreview()

        return
    end

    self.settingsPreviewStartTime = GetTime()
    self:UpdateSettingsPreview()
    self.settingsPreviewTicker = C_Timer.NewTicker(PREVIEW_TICK_SECONDS, function()
        NS:UpdateSettingsPreview()
    end)
end

function NS:StopSettingsPreview()
    if self.settingsPreviewTicker then
        self.settingsPreviewTicker:Cancel()
        self.settingsPreviewTicker = nil
    end

    self.settingsPreviewStartTime = nil

    if self.castBar then self.castBar:Clear() end
    if self.gcdBar then self.gcdBar:Clear() end
    if self.latencyBar then self.latencyBar:Clear() end
    RestoreBackgroundVisibility()
end

local function UpdatePreviewForSelectedCategory()
    if IsAddonSettingsSelected() then
        NS:StartSettingsPreview()
    else
        NS:StopSettingsPreview()
    end
end

local function RegisterSettingsPreviewCallbacks()
    if NS.settingsPreviewCallbacksRegistered then
        return
    end

    NS.settingsPreviewCallbacksRegistered = true
    EventRegistry:RegisterCallback("Settings.CategoryChanged", UpdatePreviewForSelectedCategory, NS)
    EventRegistry:RegisterCallback("SettingsPanel.OnHide", function()
        NS:StopSettingsPreview()
    end, NS)
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------
function NS:InitSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("CastbarGCDHud")

    local function rebuild()
        NS:RebuildBars()
    end

    -----------------------------------------------------------------------
    -- General
    -----------------------------------------------------------------------
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))

    -- Width
    local widthOpts = Settings.CreateSliderOptions(100, 1200, 10)
    widthOpts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return tostring(math.floor(value))
    end)
    local widthSetting = Settings.RegisterAddOnSetting(
        category, "CGH_width", "width", NS.db, "number", "Width", NS.DEFAULTS.width
    )
    Settings.CreateSlider(category, widthSetting, widthOpts, "Width of the HUD frame")
    Settings.SetOnValueChangedCallback("CGH_width", function(_, _, newValue)
        NS.db.width = newValue
        rebuild()
    end)

    -- Height
    local heightOpts = Settings.CreateSliderOptions(100, 1200, 10)
    heightOpts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return tostring(math.floor(value))
    end)
    local heightSetting = Settings.RegisterAddOnSetting(
        category, "CGH_height", "height", NS.db, "number", "Height", NS.DEFAULTS.height
    )
    Settings.CreateSlider(category, heightSetting, heightOpts, "Height of the HUD frame")
    Settings.SetOnValueChangedCallback("CGH_height", function(_, _, newValue)
        NS.db.height = newValue
        rebuild()
    end)

    -----------------------------------------------------------------------
    -- Cast Bar
    -----------------------------------------------------------------------
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Cast Bar"))

    layout:AddInitializer(CreateColorSettingInitializer("Foreground Color", NS.db.castBar.color, rebuild))
    layout:AddInitializer(CreateColorSettingInitializer("Background Color", NS.db.castBar.bgColor, rebuild))
    layout:AddInitializer(CreateColorSettingInitializer("Latency Color", NS.db.castBar.latencyColor, rebuild))

    -- Fill direction
    local castClockwiseSetting = Settings.RegisterAddOnSetting(
        category, "CGH_castClockwise", "clockwise", NS.db.castBar, "boolean", "Grow Clockwise", NS.DEFAULTS.castBar.clockwise
    )
    Settings.CreateCheckbox(category, castClockwiseSetting, "Fill the cast bar clockwise instead of counterclockwise")
    Settings.SetOnValueChangedCallback("CGH_castClockwise", function(_, _, newValue)
        NS.db.castBar.clockwise = newValue
        if NS.castBar then NS.castBar.clockwise = newValue end
        if NS.latencyBar then NS.latencyBar.clockwise = newValue end
        NS:UpdateSettingsPreview()
    end)

    -- Invert
    local castInvertSetting = Settings.RegisterAddOnSetting(
        category, "CGH_castInvert", "invert", NS.db.castBar, "boolean", "Invert Cast Bar", NS.DEFAULTS.castBar.invert
    )
    Settings.CreateCheckbox(category, castInvertSetting, "Reverse fill direction")
    Settings.SetOnValueChangedCallback("CGH_castInvert", function(_, _, newValue)
        NS.db.castBar.invert = newValue
        if NS.castBar then NS.castBar.invert = newValue end
        if NS.latencyBar then NS.latencyBar.invert = newValue end
        NS:UpdateSettingsPreview()
    end)

    -- BG Always Show
    local castBgSetting = Settings.RegisterAddOnSetting(
        category, "CGH_castBgAlwaysShow", "bgAlwaysShow", NS.db.castBar, "boolean",
        "Always Show Background", NS.DEFAULTS.castBar.bgAlwaysShow
    )
    Settings.CreateCheckbox(category, castBgSetting, "Show background ring even when not casting")
    Settings.SetOnValueChangedCallback("CGH_castBgAlwaysShow", function(_, _, newValue)
        NS.db.castBar.bgAlwaysShow = newValue
        if NS.castBar then
            if newValue then
                NS.castBar:ShowBackground()
            else
                NS.castBar:HideBackground()
            end
        end
    end)

    -----------------------------------------------------------------------
    -- GCD Bar
    -----------------------------------------------------------------------
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("GCD Bar"))

    layout:AddInitializer(CreateColorSettingInitializer("GCD Foreground Color", NS.db.gcdBar.color, rebuild))
    layout:AddInitializer(CreateColorSettingInitializer("GCD Background Color", NS.db.gcdBar.bgColor, rebuild))

    -- Fill direction
    local gcdClockwiseSetting = Settings.RegisterAddOnSetting(
        category, "CGH_gcdClockwise", "clockwise", NS.db.gcdBar, "boolean", "Grow Clockwise", NS.DEFAULTS.gcdBar.clockwise
    )
    Settings.CreateCheckbox(category, gcdClockwiseSetting, "Fill the GCD bar clockwise instead of counterclockwise")
    Settings.SetOnValueChangedCallback("CGH_gcdClockwise", function(_, _, newValue)
        NS.db.gcdBar.clockwise = newValue
        if NS.gcdBar then NS.gcdBar.clockwise = newValue end
        NS:UpdateSettingsPreview()
    end)

    -- Invert
    local gcdInvertSetting = Settings.RegisterAddOnSetting(
        category, "CGH_gcdInvert", "invert", NS.db.gcdBar, "boolean", "Invert GCD Bar", NS.DEFAULTS.gcdBar.invert
    )
    Settings.CreateCheckbox(category, gcdInvertSetting, "Reverse fill direction")
    Settings.SetOnValueChangedCallback("CGH_gcdInvert", function(_, _, newValue)
        NS.db.gcdBar.invert = newValue
        if NS.gcdBar then NS.gcdBar.invert = newValue end
    end)

    -- BG Always Show
    local gcdBgSetting = Settings.RegisterAddOnSetting(
        category, "CGH_gcdBgAlwaysShow", "bgAlwaysShow", NS.db.gcdBar, "boolean",
        "Always Show Background", NS.DEFAULTS.gcdBar.bgAlwaysShow
    )
    Settings.CreateCheckbox(category, gcdBgSetting, "Show background ring even when GCD is not active")
    Settings.SetOnValueChangedCallback("CGH_gcdBgAlwaysShow", function(_, _, newValue)
        NS.db.gcdBar.bgAlwaysShow = newValue
        if NS.gcdBar then
            if newValue then
                NS.gcdBar:ShowBackground()
            else
                NS.gcdBar:HideBackground()
            end
        end
    end)

    Settings.RegisterAddOnCategory(category)
    NS.settingsCategory = category
    RegisterSettingsPreviewCallbacks()
end
