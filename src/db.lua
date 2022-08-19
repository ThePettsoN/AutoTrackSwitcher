local _, AutoTrackSwitcher = ...

local Db = {}
AutoTrackSwitcher.Core:RegisterModule("Db", Db)

local ENUM_DISABLE_IN_COMBAT = {
	YES = 1,
	NO = 2,
	UNMOUNTED = 3,
}
AutoTrackSwitcher.Const.ENUM_DISABLE_IN_COMBAT = ENUM_DISABLE_IN_COMBAT

local DEFAULTS = {
    profile = {
        tracking = {
            interval = 2,
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
			disable_while_falling = true,
			disable_while_dead = true,
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