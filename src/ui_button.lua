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
    self.iconButton:SetTexture(134441)
end
