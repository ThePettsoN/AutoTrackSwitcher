local _, AutoTrackSwitcher = ...

local Db = {}
AutoTrackSwitcher.Core:RegisterModule("Db", Db, "AceEvent-3.0")

local ENUM_DISABLE_IN_COMBAT = {
	YES = 1,
	NO = 2,
	UNMOUNTED = 3,
}
AutoTrackSwitcher.Const.ENUM_DISABLE_IN_COMBAT = ENUM_DISABLE_IN_COMBAT

local DEFAULTS = {
	profile = {
		ui = {
			button = {
				font = {
					path = "Fonts\\FRIZQT__.TTF",
					size = 32,
					flags = "",
				},
				position  = {
					x = 0,
					y = 0,
					stored = false
				},
				size = {
					width = 64,
					height = 64,
				},
				cosmetics = {
					swipe = true,
					show_text = true,
				},
				conditions = {
					show = true,
					show_while_stopped = true
				}
			},
		},
		tracking = {
			interval = 2.001,
			enable_interval_per_tracking_type = false,
			individual = {},
		},
		minimap = {
			hide = false,
			lock = false,
		},
		conditions = {
			disable_in_combat = ENUM_DISABLE_IN_COMBAT.UNMOUNTED,
			disable_in_areas = {
				world = false,
				party = true,
				raid = true,
				arena = true,
				pvp = true,
				city = true,
			},
			disable_while_falling = true
		}
    },
    char = {
		tracking = {
			enabled_spell_ids = {},
		},
		first_time = true,
	},
}

function Db:OnInitialize()
    self._db = LibStub("AceDB-3.0"):New("AutoTrackSwitcherDB", DEFAULTS)
	self._db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	self._db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
end

function Db:OnProfileChanged()
	self:SendMessage("ConfigChange")
end

function Db:SetCharacterData(key, value, ...)
	local data = self._db.char
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end
	data[key] = value
end

function Db:GetCharacterData(...)
	local data = self._db.char
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end
	return data
end

function Db:SetProfileData(key, value, ...)
	local data = self._db.profile
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end
	data[key] = value
end

function Db:GetProfileData(...)
	local data = self._db.profile
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end

	return data
end
