local ADDON_NAME, NS = ...

local TEXTURE_PATH = "Interface\\AddOns\\CastbarGCDHud\\Media\\Textures\\"
NS.TEXTURE_PATH = TEXTURE_PATH
NS.RING_TEXTURE = TEXTURE_PATH .. "Ring_20px"

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
local DEFAULTS = {
    locked = true,
    position = nil,
    width = 600,
    height = 600,
    castBar = {
        color = { 0.2, 0.6, 1.0, 1.0 },
        bgColor = { 0.3, 0.3, 0.3, 0.4 },
        latencyColor = { 0.8, 0.0, 0.0, 0.7 },
        clockwise = true,
        invert = false,
        bgAlwaysShow = true,
    },
    gcdBar = {
        color = { 0.5, 0.0, 0.0, 0.5 },
        bgColor = { 0.3, 0.3, 0.3, 0.4 },
        clockwise = true,
        invert = true, -- GCD starts full, empties
        bgAlwaysShow = true,
    },
}
NS.DEFAULTS = DEFAULTS

function NS:Print(msg)
    print(("|cff4fc3f7%s|r %s"):format(ADDON_NAME, msg))
end

-- Event dispatch
local EVENT_HANDLERS = {}
NS.EVENT_HANDLERS = EVENT_HANDLERS

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, ...)
    local handler = EVENT_HANDLERS[event]
    if handler then handler(self, ...) end
end)
frame:RegisterEvent("ADDON_LOADED")
NS.eventFrame = frame

EVENT_HANDLERS["ADDON_LOADED"] = function(self, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")

    CastbarGCDHudDB = CastbarGCDHudDB or {}
    NS.db = CastbarGCDHudDB

    -- Deep-merge defaults into saved data
    for k, v in pairs(DEFAULTS) do
        if type(v) == "table" then
            NS.db[k] = NS.db[k] or {}
            for k2, v2 in pairs(v) do
                if NS.db[k][k2] == nil then
                    NS.db[k][k2] = v2
                end
            end
        elseif NS.db[k] == nil then
            NS.db[k] = v
        end
    end

    NS:CreateHUD()
    NS:InitSettings()
    NS:Print("loaded. /cgh to configure.")
end

-- HUD container
function NS:CreateHUD()
    local hud = CreateFrame("Frame", "CastbarGCDHudFrame", UIParent)
    hud:SetSize(NS.db.width, NS.db.height)
    hud:SetFrameStrata("MEDIUM")

    -- Restore saved position
    local pos = NS.db.position
    if pos then
        hud:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        hud:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Movable (click-through when locked)
    hud:SetMovable(true)
    hud:RegisterForDrag("LeftButton")
    hud:SetClampedToScreen(true)

    hud:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    hud:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        NS.db.position = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    hud:EnableMouse(not NS.db.locked)

    NS.hud = hud

    NS:CreateCastBar()
    NS:CreateGCDBar()
end

-- Destroy and recreate bars (called after size/settings changes)
function NS:RebuildBars()
    -- Stop any active tickers
    if NS.castTicker then
        NS.castTicker:Cancel()
        NS.castTicker = nil
    end
    if NS.gcdTicker then
        NS.gcdTicker:Cancel()
        NS.gcdTicker = nil
    end

    -- Destroy old HUD
    if NS.hud then
        NS.hud:Hide()
        NS.hud:SetParent(nil)
        NS.hud = nil
    end

    NS:CreateHUD()
end

-- Slash command
local cmds = {
    {
        triggers = { "lock", "l" },
        name = "Lock",
        description = "Toggle frame lock",
        func = function()
            NS.db.locked = not NS.db.locked
            NS.hud:EnableMouse(not NS.db.locked)
            NS:Print(NS.db.locked and "Locked." or "Unlocked.")
        end,
    },
    {
        triggers = { "test", "t" },
        name = "Test",
        description = "Show test animation",
        func = function()
            NS:TestBars()
        end,
    },
    {
        triggers = { "options", "o" },
        name = "Options",
        description = "Open settings",
        func = function()
            if NS.settingsCategory then
                Settings.OpenToCategory(NS.settingsCategory:GetID())
            end
        end,
    },
}

SLASH_CASTBARGCDHUD1 = "/cgh"
SLASH_CASTBARGCDHUD2 = "/castbargcdhud"
SlashCmdList["CASTBARGCDHUD"] = function(msg)
    msg = strtrim(msg):lower()
    for _, cmd in ipairs(cmds) do
        for _, trigger in ipairs(cmd.triggers) do
            if msg == trigger then
                cmd.func()

                return
            end
        end
    end

    for _, cmd in ipairs(cmds) do
        NS:Print(("/%s %s — %s"):format("cgh", cmd.triggers[1], cmd.description))
    end
end
