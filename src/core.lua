local _, AutoTrackSwitcher = ...
AutoTrackSwitcher.Const = {
	CLASS_IDS = {
		NONE = 0,
		WARRIOR = 1,
		PALADIN = 2,
		HUNTER = 3,
		ROGUE = 4,
		PRIEST = 5,
		DEATH_KNIGHT = 6,
		SHAMAN = 7,
		MAGE = 8,
		WARLOCK = 9,
		DRUID = 11,
	},
	SHAPESHIFT_FORM_IDS = {
		DRUID = {
			AQUATIC_FORM = 2,
			TRAVEL_FORM = 4,
			FLIGHT_FORM = 5,
			FLIGHT_FORM_BALANCE = 6
		},
		SHAMAN = {
			GHOST_WOLF = 1,
		}
	}
}

local DEBUG_SEVERITY = {
	INFO = "INFO",
	DEBUG = "DEBUG",
	ERROR = "ERROR",
	WARNING = "WARNING",
}
local SEVERITY_COLOR_LOOKUP = {
	[DEBUG_SEVERITY.INFO] = "00ffffff",
	[DEBUG_SEVERITY.DEBUG] = "00ffffff",
	[DEBUG_SEVERITY.ERROR] = "00ff0000",
	[DEBUG_SEVERITY.WARNING] = "00eed202",
}
local GameVersionLookup = {
	SeasonOfDiscovery = 1,
	Hardcore = 2,
	Retail = 3,
	Wrath = 4,
}

AutoTrackSwitcher.DEBUG_SEVERITY = DEBUG_SEVERITY
AutoTrackSwitcher.DEBUG = false

AutoTrackSwitcher.dprint = function(severity, msg, ...)
	if AutoTrackSwitcher.DEBUG then
		print(string.format("[AutoTrackSwitcher]|c%s[%s] %s|r", SEVERITY_COLOR_LOOKUP[severity], severity, string.format(msg, ...)))
	end
end

AutoTrackSwitcher.print = function(msg, ...)
	print(string.format("[AutoTrackSwitcher] %s", string.format(msg, ...)))
end

-- Lua API
local dprint = AutoTrackSwitcher.dprint
local print = AutoTrackSwitcher.print
local tRemove = table.remove
local stringformat = string.format
local wipe = wipe

-- WoW API
local GetNumTrackingTypes = GetNumTrackingTypes or C_Minimap.GetNumTrackingTypes
local GetTrackingInfo = GetTrackingInfo or C_Minimap.GetTrackingInfo
local UnitAffectingCombat = UnitAffectingCombat
local IsMounted = IsMounted
local SetTracking = SetTracking or C_Minimap.SetTracking
local IsFalling = IsFalling
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local IsResting = IsResting
local GetInstanceInfo = GetInstanceInfo
local IsSpellKnown = IsSpellKnown
local GetShapeshiftForm = GetShapeshiftForm
local UnitClass = UnitClass

local Core = LibStub("AceAddon-3.0"):NewAddon("AutoTrackSwitcherCore", "AceEvent-3.0", "AceTimer-3.0")
AutoTrackSwitcher.Core = Core

function Core:OnInitialize()
	self._isRunning = false
	self._currentUpdateIndex = 0
	self._timer = nil
	self._trackingData = {}
	self._enabledSpellIds = {}
end

function Core:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
	self:RegisterEvent("SKILL_LINES_CHANGED", "OnSkillLinesChanged")
	self:RegisterEvent("LEARNED_SPELL_IN_TAB", "OnLearnedSpellInTab")
	self:RegisterEvent("ITEM_LOCKED", "OnItemLocked")
	self:RegisterEvent("ITEM_UNLOCKED", "OnItemUnlocked")
	self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")

	self:RegisterMessage("ConfigChange", "OnConfigChange")
end

local function DetermineGameVersion()
	if not C_Engraving then
		AutoTrackSwitcher.GameVersion = GameVersionLookup.Retail
	elseif C_Console then
		AutoTrackSwitcher.GameVersion = GameVersionLookup.Wrath
	elseif C_GameRules.IsHardcoreActive() then
		AutoTrackSwitcher.GameVersion = GameVersionLookup.Hardcore
	else
		AutoTrackSwitcher.GameVersion = GameVersionLookup.SeasonOfDiscovery
	end
end

function Core:Initialize()
	self:GetTrackingData()

	local db = AutoTrackSwitcher.Db
	self._updateInterval = db:GetProfileData("tracking", "interval")

	if db:GetCharacterData("first_time") then
		dprint(DEBUG_SEVERITY.INFO, "First time")
		local enabledSpellIds = {}
		for spellId, data in pairs(self._trackingData) do
			if not data.isNested then
				dprint(DEBUG_SEVERITY.INFO, "Enabling tracking skill %q", data.name)
				enabledSpellIds[spellId] = true
				self._enabledSpellIds[#self._enabledSpellIds+1] = spellId
			end
		end
		db:SetCharacterData("enabled_spell_ids", enabledSpellIds, "tracking")
		db:SetCharacterData("first_time", false)
	else
		self:SetActiveTracking()
	end

	self:SetUpdateConditions()
end

function Core:GetTrackingData()
	wipe(self._trackingData)

	DetermineGameVersion()
	if AutoTrackSwitcher.GameVersion == GameVersionLookup.SeasonOfDiscovery then
		-- Hardcoded for now. Should probably refactor at some point

		if IsSpellKnown(2580) then -- Mining
			local name = GetSpellInfo(2580)
			self._trackingData[2580] = {
				name = name,
				index = 2580,
				isNested = false,
				texture = 136025
			}
		end
		if IsSpellKnown(2383) then -- Herb
			local name = GetSpellInfo(2383)
			self._trackingData[2383] = {
				name = name,
				index = 2383,
				isNested = false,
				texture = 133939,
			}
		end

		return
	end

	local numTrackingTypes = GetNumTrackingTypes()
	for i = 1, numTrackingTypes do
		local name, texture, active, category, nested, spellId = GetTrackingInfo(i)
		if spellId then
			self._trackingData[spellId] = {
				name = name,
				index = i,
				isNested = nested > -1,
				texture = texture
			}
		end
	end
end

local function falseFunc(...)
	return false
end

local function conditionUnmountedCombatFunc(...)
	if UnitAffectingCombat("player") then
		if IsMounted() then
			return false
		end

		local _, _, classId = UnitClass("player")
		local consts = AutoTrackSwitcher.Const
		if classId == consts.CLASS_IDS.DRUID then
			local druidShapeshiftFormIds = consts.SHAPESHIFT_FORM_IDS.DRUID

			local shapeshiftFormId = GetShapeshiftForm()
			if shapeshiftFormId == druidShapeshiftFormIds.AQUATIC_FORM or
			shapeshiftFormId == druidShapeshiftFormIds.TRAVEL_FORM or
			(IsSpellKnown(24858) and shapeshiftFormId == druidShapeshiftFormIds.FLIGHT_FORM_BALANCE) or
			shapeshiftFormId == druidShapeshiftFormIds.FLIGHT_FORM then
				return false
			end
		elseif classId == consts.CLASS_IDS.SHAMAN then
			local shapeshiftForm = GetShapeshiftForm()
			if shapeshiftForm == consts.SHAPESHIFT_FORM_IDS.SHAMAN.GHOST_WOLF then -- If shaman and in ghost wolf
				return false
			end
		end

		return true
	end
end

local function isTracking(trackingData)
	if AutoTrackSwitcher.GameVersion == GameVersionLookup.SeasonOfDiscovery then

		if not MiniMapTrackingFrame:IsShown() then
			return false
		end

		local trackingTextureId = GetTrackingTexture()
		if not trackingTextureId then
			return false
		end

		return trackingTextureId == trackingData.texture
	end

	local _, _, active = GetTrackingInfo(trackingData.index)
	return active
end

function Core:SetActiveTracking()
	local db = AutoTrackSwitcher.Db

	wipe(self._enabledSpellIds)

	local updateDb = false
	local enabledSpellIds = db:GetCharacterData("tracking", "enabled_spell_ids")
	for spellId, enabled in pairs(enabledSpellIds) do
		if enabled and self._trackingData[spellId] then
			dprint(DEBUG_SEVERITY.INFO, "Enabling tracking skill %q", self._trackingData[spellId].name)
			self._enabledSpellIds[#self._enabledSpellIds + 1] = spellId
		else
			dprint(DEBUG_SEVERITY.INFO, "Removing invalid tracking skill %q", spellId)
			enabledSpellIds[spellId] = nil
			updateDb = true
		end
	end

	if updateDb then
		db:SetCharacterData("enabled_spell_ids", enabledSpellIds, "tracking")
	end
end

function Core:SetUpdateConditions()
	dprint(DEBUG_SEVERITY.INFO, "Update conditions")
	local db = AutoTrackSwitcher.Db
	local conditions = db:GetProfileData("conditions")
	local const = AutoTrackSwitcher.Const

	if conditions.disable_in_combat == const.ENUM_DISABLE_IN_COMBAT.NO then
		self._disableInCombatFunc = falseFunc
	elseif conditions.disable_in_combat == const.ENUM_DISABLE_IN_COMBAT.YES then
		self._disableInCombatFunc = UnitAffectingCombat
	elseif conditions.disable_in_combat == const.ENUM_DISABLE_IN_COMBAT.UNMOUNTED then
		self._disableInCombatFunc = conditionUnmountedCombatFunc
	end

	self._disableForAreas = conditions.disable_in_areas
	self._disableWhileFallingFunc = conditions.disable_while_falling and IsFalling or falseFunc
	self._disableWhileDeadFunc = conditions.disable_while_dead and UnitIsDeadOrGhost or falseFunc
end

function Core:RegisterModule(name, module, ...)
	local mod = self:NewModule(name, module, ...)
	AutoTrackSwitcher[name] = mod
end

function Core:OnUpdate()
	self:SendMessage("OnUpdate", self._updateInterval)

	if self._item_locked then
		dprint(DEBUG_SEVERITY.INFO, stringformat("Disable due to: Item locked"))
		return
	end

	if self._loot_opened then
		dprint(DEBUG_SEVERITY.INFO, stringformat("Disable due to: Loot Window opened"))
		return
	end

	if self._disableForAreas[self._currentArea] then
		dprint(DEBUG_SEVERITY.INFO, stringformat("Disable due to: In Disabled Area %q", self._currentArea))
		return
	end

	if self._disableForAreas.city and IsResting("player") then
		dprint(DEBUG_SEVERITY.INFO, stringformat("Disable due to: In Disabled Area \"city\""))
		return
	end

	if self._disableInCombatFunc("player") then
		dprint(DEBUG_SEVERITY.INFO, stringformat("Disable due to: In Combat"))
		return
	end

	if self._disableWhileFallingFunc("player") then
		dprint(DEBUG_SEVERITY.INFO, stringformat("Disable due to: Falling"))
		return
	end

	if self._disableWhileDeadFunc("player") then
		dprint(DEBUG_SEVERITY.INFO, stringformat("Disable due to: Dead"))
		return
	end

	local spell = UnitCastingInfo("player")
	if spell then
		dprint(DEBUG_SEVERITY.INFO, stringformat("Disable due to: Casting Spell"))
		return
	end

	self._currentUpdateIndex = (self._currentUpdateIndex % #self._enabledSpellIds) + 1
	local spellId = self._enabledSpellIds[self._currentUpdateIndex]
	local trackingData = self._trackingData[spellId]

	if isTracking(trackingData) then
		dprint(DEBUG_SEVERITY.INFO, stringformat("Already tracking"))
		return
	end

	if AutoTrackSwitcher.GameVersion == GameVersionLookup.SeasonOfDiscovery then
		CastSpellByName(trackingData.name)
	else
		SetTracking(trackingData.index, true)
	end
	self:SendMessage("OnTrackingChanged", trackingData.texture)
end

function Core:Start(initial)
	dprint(DEBUG_SEVERITY.INFO, "Starting")
	if self._isRunning then
		print("Addon already running!")
		return
	end

	if #self._enabledSpellIds == 0 then
		dprint(DEBUG_SEVERITY.INFO, "No tracking spells enabled")
		return
	end

	if self._timer then -- Failsafe. Should never happen that we can start while a timer is already running, but just in case
		self:CancelTimer(self._timer)
	end

	self._timer = self:ScheduleRepeatingTimer("OnUpdate", self._updateInterval)
	self._isRunning = true
	self:SendMessage("OnStart", self._updateInterval)

	if initial then
		self:OnUpdate()
		print("Addon started!")
	end
end

function Core:Stop(initial)
	dprint(DEBUG_SEVERITY.INFO, "Stopping")
	if not self._isRunning then
		print("Addon not running!")
		return
	end

	if self._timer then
		self:CancelTimer(self._timer)
		self._timer = nil
	end

	self._isRunning = false
	self:SendMessage("OnStop")

	if initial then
		print("Addon stopped!")
	end
end

function Core:IsRunning()
	return self._isRunning
end

function Core:SetInterval(interval, skipRestart)
	if interval < 2 then
		dprint(DEBUG_SEVERITY.INFO, "Interval can not be lower than 2 seconds")
		interval = 2
	elseif interval > 60 then
		dprint(DEBUG_SEVERITY.INFO, "Interval can not be higher than 60 seconds")
		interval = 60
	elseif interval == 2 then
		interval = 2.001 -- Blizzard's Cooldown frame limits the text to >2 seconds. This hack shows it without any noticable delay
	end

	self._updateInterval = interval

	if not skipRestart and self._isRunning then
		dprint(DEBUG_SEVERITY.INFO, "Restarting timer")
		if self._timer then
			self:CancelTimer(self._timer)
		end
		self._timer = self:ScheduleRepeatingTimer("OnUpdate", self._updateInterval)
	end
end

function Core:OnPlayerEnteringWorld(event, isInitialLogin, isReloadingUi)
	dprint(DEBUG_SEVERITY.INFO, "OnPlayerEnteringWorld: %q, %q", tostring(isInitialLogin), tostring(isReloadingUi))
	self:Initialize()

	local _, instanceType = GetInstanceInfo()
	self._currentArea = instanceType == "none" and "world" or instanceType
end

function Core:OnSkillLinesChanged()
	dprint(DEBUG_SEVERITY.INFO, "Skill list changed. Fetching data anew")
	self:GetTrackingData()
	self:OnConfigChange()
end

function Core:OnLearnedSpellInTab()
	dprint(DEBUG_SEVERITY.INFO, "New spell learned. Fetching data anew")
	self:GetTrackingData()
	self:OnConfigChange()
end

function Core:OnConfigChange(...)
	self:SetActiveTracking()
	self:SetUpdateConditions()

	local db = AutoTrackSwitcher.Db
	self:SetInterval(db:GetProfileData("tracking", "interval"), true)

	if self._isRunning then
		self:Stop(false)

		if #self._enabledSpellIds > 0 then
			self:Start(false)
		end
	end
end

function Core:OnItemLocked()
	self._item_locked = true
end

function Core:OnItemUnlocked()
	self._item_locked = false
end

function Core:OnLootOpened(autoLoot)
	if not autoLoot then
		self._loot_opened = true
	end
end

function Core:OnLootClosed()
	self._loot_opened = false
end
