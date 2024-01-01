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
    
end

function UiButton:OnEnable()
    local iconButton = AceGUI:Create("SimpleIconButton")
    iconButton:SetLabelFontSettings(self._fontSettings.path, self._fontSettings.size, self._fontSettings.flags)
    iconButton:SetCallback("OnClick", function(_, _, button) self:OnClick(button) end)
    iconButton:SetCallback("OnStopMoving", function(_, _, x, y) self:OnStopMoving(x, y) end)

    self.iconButton = iconButton
    self:UpdateTexture()

    local positionData = self._db:GetProfileData("ui", "button", "position")
    if positionData.stored then
        iconButton:SetPosition(positionData.x, positionData.y)
    end
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

function UiButton:OnStopMoving(x, y)
	self._db:SetProfileData("x", floor(x + 0.5), "ui", "button", "position")
	self._db:SetProfileData("y", floor(y + 0.5), "ui", "button", "position")
	self._db:SetProfileData("stored", true, "ui", "button", "position")
end
