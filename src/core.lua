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

AutoTrackSwitcher.DEBUG = true

AutoTrackSwitcher.dprint = function(msg, ...)
	if AutoTrackSwitcher.DEBUG then
		print(string.format("[AutoTrackSwitcher] %s", string.format(msg, ...)))
	end
end

-- Lua API
local tRemove = table.remove
local stringformat = string.format
local wipe = wipe

-- WoW API
local GetNumTrackingTypes = GetNumTrackingTypes
local GetTrackingInfo = GetTrackingInfo
local UnitAffectingCombat = UnitAffectingCombat
local IsMounted = IsMounted
local SetTracking = SetTracking
local IsFalling = IsFalling
local IsDead = IsDead
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
	self:RegisterMessage("ConfigChange", "OnConfigChange")

	self:GetTrackingData()

	local db = AutoTrackSwitcher.Db
	self._updateInterval = db:GetProfileData("tracking", "interval")

	if db:GetCharacterData("first_time") then
		AutoTrackSwitcher.dprint("First time")
		local enabledSpellIds = {}
		for spellId, data in pairs(self._trackingData) do
			if not data.isNested then
				AutoTrackSwitcher.dprint("Enabling tracking skill %q", data.name)
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

	local numTrackingTypes = GetNumTrackingTypes()
	for i = 1, numTrackingTypes do
		local name, texture, active, category, nested, spellId = GetTrackingInfo(i)
		if spellId then
			self._trackingData[spellId] = {
				name = name,
				index = i,
				isNested = nested > -1,
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

function Core:SetActiveTracking()
	local db = AutoTrackSwitcher.Db

	wipe(self._enabledSpellIds)

	local updateDb = false
	local enabledSpellIds = db:GetCharacterData("tracking", "enabled_spell_ids")
	for spellId, enabled in pairs(enabledSpellIds) do
		if enabled and self._trackingData[spellId] then
			AutoTrackSwitcher.dprint("Enabling tracking skill %q", self._trackingData[spellId].name)
			self._enabledSpellIds[#self._enabledSpellIds+1] = spellId
		else
			AutoTrackSwitcher.dprint("Removing invalid tracking skill %q", self._trackingData[spellId].name)
			enabledSpellIds[spellId] = nil
			updateDb = true
		end
	end

	if updateDb then
		db:SetCharacterData("enabled_spell_ids", enabledSpellIds, "tracking")
	end
end

function Core:SetUpdateConditions()
	AutoTrackSwitcher.dprint("Update conditions")
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
	self._disableWhileDeadFunc = conditions.disable_while_dead and IsDead or falseFunc
end

function Core:RegisterModule(name, module, ...)
	local mod = self:NewModule(name, module, ...)
	AutoTrackSwitcher[name] = mod
end

function Core:OnUpdate()
	if self._disableForAreas[self._currentArea] then
		AutoTrackSwitcher.dprint(stringformat("Disable due to: In Disabled Area %q", self._currentArea))
		return
	end

	if self._disableForAreas.city and IsResting("player") then
		AutoTrackSwitcher.dprint(stringformat("Disable due to: In Disabled Area \"city\""))
		return
	end

	if self._disableInCombatFunc("player") then
		AutoTrackSwitcher.dprint(stringformat("Disable due to: In Combat"))
		return
	end

	if self._disableWhileFallingFunc() then
		AutoTrackSwitcher.dprint(stringformat("Disable due to: Falling"))
		return
	end

	if self._disableWhileDeadFunc() then
		AutoTrackSwitcher.dprint(stringformat("Disable due to: Dead"))
		return
	end

	self._currentUpdateIndex = (self._currentUpdateIndex % #self._enabledSpellIds) + 1
	local spellId = self._enabledSpellIds[self._currentUpdateIndex]

	local index = self._trackingData[spellId].index
	SetTracking(index, true)
end

function Core:Start()
	AutoTrackSwitcher.dprint("Starting")
	if self._isRunning then
		AutoTrackSwitcher.dprint("Already running")
		return
	end

	if #self._enabledSpellIds == 0 then
		AutoTrackSwitcher.dprint("No tracking spells enabled")
		return
	end

	if self._timer then -- Failsafe. Should never happen that we can start while a timer is already running, but just in case
		self:CancelTimer(self._timer)
	end

	self._timer = self:ScheduleRepeatingTimer("OnUpdate", self._updateInterval)
	self._isRunning = true
end

function Core:Stop()
	AutoTrackSwitcher.dprint("Stopping")
	if not self._isRunning then
		AutoTrackSwitcher.dprint("Not running")
		return
	end

	if self._timer then
		self:CancelTimer(self._timer)
		self._timer = nil
	end

	self._isRunning = false
end

function Core:SetInterval(interval)
	if interval < 2 then
		AutoTrackSwitcher.dprint("Interval can not be lower than 2 seconds")
		interval = 2
	elseif interval > 60 then
		AutoTrackSwitcher.dprint("Interval can not be higher than 60 seconds")
		interval = 60
	end

	self._updateInterval = interval

	if self._isRunning then
		AutoTrackSwitcher.dprint("Restarting timer")
		if self._timer then
			self:CancelTimer(self._timer)
		end
		self._timer = self:ScheduleRepeatingTimer("OnUpdate", self._updateInterval)
	end
end

function Core:OnPlayerEnteringWorld(event, isInitialLogin, isReloadingUi)
	local _, instanceType = GetInstanceInfo()
	self._currentArea = instanceType == "none" and "world" or instanceType
end

function Core:OnConfigChange(...)
	self:SetActiveTracking()
	self:SetUpdateConditions()

	if self._isRunning then
		local db = AutoTrackSwitcher.Db
		self._updateInterval = db:GetProfileData("tracking", "interval")

		self:Stop()

		if #self._enabledSpellIds > 0 then
			self:Start()
		end
	end
end