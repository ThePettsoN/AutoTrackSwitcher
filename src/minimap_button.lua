local TOCNAME, AutoTrackSwitcher = ...
local tooltipText = string.format("%s\n\nLeft-Click: Start/Stop AutoTrackSwitch\nRight-Click: Open Settings", TOCNAME)

local LibIcon = LibStub("LibDBIcon-1.0")

local MinimapButton = {}
AutoTrackSwitcher.Core:RegisterModule("MinimapButton", MinimapButton)

function MinimapButton:OnInitialize()
end

function MinimapButton:OnEnable()
    local db = AutoTrackSwitcher.Db
    local minimapSettings = db:GetProfileData("minimap")
    local gfiLDB = LibStub("LibDataBroker-1.1"):NewDataObject(TOCNAME, {
        type = "launcher",
        icon = "Interface\\ARCHEOLOGY\\Arch-Icon-Marker",
        OnClick = function(_, button)
            if button == "LeftButton" then
                AutoTrackSwitcher.Commands:Toggle()
            else
                AutoTrackSwitcher.Options:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText(tooltipText)
        end
    })
    LibIcon:Register(TOCNAME, gfiLDB, minimapSettings)
    self._button = _G["LibDBIcon10_" .. TOCNAME]
end

function MinimapButton:Show()
    LibIcon:Show(TOCNAME)
end

function MinimapButton:Hide()
    LibIcon:Hide(TOCNAME)
end

function MinimapButton:SetStarted()
    local icon = self._button.icon
    icon:SetVertexColor(0, 1, 0, 1)
end

function MinimapButton:SetStopped()
    local icon = self._button.icon
    icon:SetVertexColor(1, 1, 1, 1)
end
