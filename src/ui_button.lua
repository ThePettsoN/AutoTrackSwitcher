local TOCNAME, AutoTrackSwitcher = ...

local AceGUI = LibStub("AceGUI-3.0", "AceEvent-3.0")
local UiButton = {}
AutoTrackSwitcher.Core:RegisterModule("UiButton", UiButton, "AceEvent-3.0")

local function GetActualTrackingTexture()
    if not MiniMapTrackingFrame:IsShown() then
        return 134441
    end

    return GetTrackingTexture() or 134441
end

function UiButton:OnInitialize()
    self._db = AutoTrackSwitcher.Db
    self._fontSettings = self._db:GetProfileData("ui", "button", "font")

    self:RegisterMessage("OnStart", "OnStart")
    self:RegisterMessage("OnStop", "OnStop")
    self:RegisterMessage("OnUpdate", "OnUpdate")
    self:RegisterMessage("OnTrackingChanged", "OnTrackingChanged")
    self:RegisterMessage("ConfigChange", "OnConfigChange")
    
end

function UiButton:OnEnable()
    local iconButton = AceGUI:Create("SimpleIconButton")
    
    iconButton:SetCallback("OnClick", function(_, _, button) self:OnClick(button) end)
    iconButton:SetCallback("OnStopMoving", function(_, _, x, y) self:OnStopMoving(x, y) end)
    iconButton:SetTooltip(string.format("%s\n\nLeft-Click: Start/Stop AutoTrackSwitch\nRight-Click: Open Settings\nShift+Left-Click: Move this button", TOCNAME))

    self.iconButton = iconButton
    self:UpdateTexture()
    self:ApplyConfig()
end

function UiButton:ApplyConfig()
    -- db settings
    local button = self.iconButton
    local buttonData = self._db:GetProfileData("ui", "button")

    -- Font
    local fontSettings = buttonData.font
    button:SetLabelFontSettings(fontSettings.path, fontSettings.size, fontSettings.flags)

    -- Position
    local position = buttonData.position
    if position.stored then
        button:SetPosition(position.x, position.y)
    end

    -- Size
    local size = buttonData.size
    button:SetSize(size.width, size.height)

    -- Cosmetics
    local cosmetics = buttonData.cosmetics
    button:SetDrawSwipe(cosmetics.swipe)
    button:SetShowText(cosmetics.show_text)

    self:UpdateVisibility()
end

function UiButton:UpdateVisibility()
    local conditions = self._db:GetProfileData("ui", "button", "conditions")

    if conditions.show then
        if self._running then
            -- Show while running
            self.iconButton:Show()
            self.iconButton:SetDesaturated(false)
        else
            if conditions.show_while_stopped then
                -- Show while stopped
                self.iconButton:Show()
                self.iconButton:SetDesaturated(true)
            else
                -- Do not show while stopped
                self.iconButton:Hide()
            end
        end
    else
        -- Do not show
        self.iconButton:Hide()
    end
end

function UiButton:UpdateTexture()
    local trackingTextureId = GetActualTrackingTexture()
    self.iconButton:SetTexture(trackingTextureId)
end

function UiButton:OnStart(eventName, interval)
    self:UpdateTexture()
    self.iconButton:SetCooldownDuration(interval)
    self._running = true
    self:UpdateVisibility()
end

function UiButton:OnUpdate(eventName, interval)
    self.iconButton:SetCooldownDuration(interval)
end

function UiButton:OnTrackingChanged(eventName, texture)
    self.iconButton:SetTexture(texture)
end

function UiButton:OnStop()
    self:UpdateTexture()
    self.iconButton:ClearCooldown()
    self._running = false
    self:UpdateVisibility()
end

function UiButton:OnClick(button)
    if button == "LeftButton" then
        AutoTrackSwitcher.Commands:Toggle()
    else
        AutoTrackSwitcher.Options:Toggle()
    end
end

function UiButton:OnStopMoving(x, y)
	self._db:SetProfileData("x", floor(x + 0.5), "ui", "button", "position")
	self._db:SetProfileData("y", floor(y + 0.5), "ui", "button", "position")
	self._db:SetProfileData("stored", true, "ui", "button", "position")
end

function UiButton:OnConfigChange()
    self:ApplyConfig()
end
