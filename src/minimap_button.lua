local TOCNAME, AutoTrackFinder = ...

local LibIcon = LibStub("LibDBIcon-1.0")

local MinimapButton = {}
AutoTrackFinder.Core:RegisterModule("MinimapButton", MinimapButton)

function MinimapButton:OnInitialize()
end

function MinimapButton:OnEnable()
    local db = AutoTrackFinder.Db
    local minimapSettings = db:GetProfileData("minimap")
    local gfiLDB = LibStub("LibDataBroker-1.1"):NewDataObject(TOCNAME, {
        type = "launcher",
        icon = "Interface\\ARCHEOLOGY\\Arch-Icon-Marker",
        OnClick = function(_, button)
            if button == "LeftButton" then
                AutoTrackFinder.Options:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText(TOCNAME)
        end
    })
    LibIcon:Register(TOCNAME, gfiLDB, minimapSettings)
end