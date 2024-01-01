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
    self._fontSettings = self._db:GetProfileData("general", "font")

    self:RegisterMessage("OnStart", "OnStart")
    self:RegisterMessage("OnStop", "OnStop")
    self:RegisterMessage("OnUpdate", "OnUpdate")
    self:RegisterMessage("OnTrackingChanged", "OnTrackingChanged")
    
end

function UiButton:OnEnable()
    local iconButton = AceGUI:Create("SimpleIconButton")
    iconButton:SetLabelFontSettings(self._fontSettings.path, self._fontSettings.size, self._fontSettings.flags)
    iconButton:SetCallback("OnClick", function(_, _, button)
        self:OnClick(button)
    end)
    self.iconButton = iconButton

    self:UpdateTexture()
end

function UiButton:UpdateTexture()
    local trackingTextureId = GetActualTrackingTexture()
    self.iconButton:SetTexture(trackingTextureId)
end

function UiButton:OnStart(eventName, interval)
    self:UpdateTexture()
    self.iconButton:SetCooldownDuration(interval)
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
end

function UiButton:OnClick(button)
    if button == "LeftButton" then
        AutoTrackSwitcher.Commands:Toggle()
    else
        AutoTrackSwitcher.Options:Toggle()
    end
end
