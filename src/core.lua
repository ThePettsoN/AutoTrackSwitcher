local TOCNAME, AutoTrackSwitcher = ...
local Core = LibStub("AceAddon-3.0"):NewAddon("AutoTrackSwitcherCore", "AceEvent-3.0", "AceTimer-3.0")
AutoTrackSwitcher.Core = Core
local PUtils = LibStub:GetLibrary("PUtils-2.0")
local DebugUtils = PUtils.Debug
local GameUtils = PUtils.Game
local TableUtils = PUtils.Table
AutoTrackSwitcher.PUtils = PUtils

AutoTrackSwitcher.Const = {}
 
-- Lua API
local tRemove = table.remove
local wipe = wipe

-- WoW API
local GetContainerNumFreeSlots = GetContainerNumFreeSlots or C_Container.GetContainerNumFreeSlots
local GetContainerItemInfo = GetContainerItemInfo or C_Container.GetContainerItemInfo
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
local MiniMapTracking = MiniMapTrackingFrame or MiniMapTracking

local function isTracking(trackingData)
	if GameUtils.IsClassic() then
		if not MiniMapTracking:IsShown() then
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

local function TrackSpell(trackingData)
	if GameUtils.IsClassic() then
		CastSpellByName(trackingData.name)
	else
		SetTracking(trackingData.index, true)
	end
end

local function falseFunc(...)
	return false
end

local function trueFunc(...)
	return true
end

local function conditionUnmountedCombatFunc(...)
	if UnitAffectingCombat("player") then
		if IsMounted() then
			return false
		end

		local _, _, classId = UnitClass("player")
		if GameUtils.ComparePlayerClass("DRUID") then
			local druidShapeshiftFormIds = GameUtils.ShapeshiftIdLookup.DRUID

			local shapeshiftFormId = GetShapeshiftForm()
			if shapeshiftFormId == druidShapeshiftFormIds.AQUATIC_FORM or
					shapeshiftFormId == druidShapeshiftFormIds.TRAVEL_FORM or
					(IsSpellKnown(24858) and shapeshiftFormId == druidShapeshiftFormIds.FLIGHT_FORM_BALANCE) or
					shapeshiftFormId == druidShapeshiftFormIds.FLIGHT_FORM then
				return false
			end
		elseif GameUtils.ComparePlayerClass("SHAMAN") then
			local shapeshiftForm = GetShapeshiftForm()
			if shapeshiftForm == GameUtils.ShapeshiftIdLookup.SHAMAN.GHOST_WOLF then -- If shaman and in ghost wolf
				return false
			end
		end

		return true
	end
end

local Free = 1
local ItemLocked = bit.lshift(Free, 1) --		2
local LootOpened = bit.lshift(Free, 2) --		4
local ZoneChanged = bit.lshift(Free, 3) --		8
local PlayerCombat = bit.lshift(Free, 4) --		16
local PlayerDead = bit.lshift(Free, 5) --		32
local PlayerCasting = bit.lshift(Free, 6) --	64
local PlayerFalling = bit.lshift(Free, 7) --	128
local TalkingWithNPC = bit.lshift(Free, 8) --	256

function Core:OnInitialize()
	DebugUtils.initialize(self, TOCNAME)
	for name, mod in pairs(self.modules) do
		DebugUtils.initializeModule(mod, self, name)
	end
	-- self:setSeverity(DebugUtils.Severities.Debug)

	self._currentUpdateIndex = 0
	self._timer = nil
	self._updateTimer = nil
	self._numTimesFalling = 0

	self._started = false -- Tracks if addon is started. Does not mean that the timer is nessearily running
	self._running = false

	self._trackingData = {}
	self._trackedSpellIds = {}
	
	self._bit = Free
end

function Core:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
	self:RegisterEvent("SKILL_LINES_CHANGED", "OnSkillLinesChanged")
	self:RegisterEvent("LEARNED_SPELL_IN_TAB", "OnLearnedSpellInTab")
	self:RegisterEvent("ITEM_LOCKED", "OnItemLocked")
	self:RegisterEvent("ITEM_UNLOCKED", "OnItemUnlocked")
	self:RegisterEvent("BAG_UPDATE", "OnBagUpdate")
	self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnPlayerEnterCombat")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerLeaveCombat")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "OnZoneChanged")
	self:RegisterEvent("PLAYER_DEAD", "OnPlayerDead")
	self:RegisterEvent("PLAYER_UNGHOST", "OnPlayerUnGhost")
	self:RegisterEvent("UNIT_SPELLCAST_START", "OnSpellcastStart")
	self:RegisterEvent("UNIT_SPELLCAST_STOP", "OnSpellcastStop")
	self:RegisterEvent("GOSSIP_SHOW", "OnStartTalkWithNPC")
	self:RegisterEvent("GOSSIP_CLOSED", "OnStopTalkWithNPC")
	self:RegisterEvent("MERCHANT_SHOW", "OnStartTalkWithNPC")
	self:RegisterEvent("MERCHANT_CLOSED", "OnStopTalkWithNPC")

	self:RegisterMessage("ConfigChange", "OnConfigChange")

	local db = AutoTrackSwitcher.Db
	self:SetInterval(db:GetProfileData("tracking"), true)
end

function Core:RegisterModule(name, module, ...)
	local mod = self:NewModule(name, module, ...)
	AutoTrackSwitcher[name] = mod

	if self.__putils_debug then
		DebugUtils.initializeModule(mod, self, name)
	end
end

function Core:Initialize()
	self:InitializeTrackingData()
end

function Core:InitializeTrackingData()
	self:UpdateTrackingData()

	local db = AutoTrackSwitcher.Db

	if db:GetCharacterData("first_time") then
		self:debug("First Time")
		local enabledSpellIds = {}
		for spellId, data in pairs(self._trackingData) do
			if not data.isNested then
				self:debug("Enabling tracking skill %q", data.name)
				enabledSpellIds[spellId] = true
				self._trackedSpellIds[#self._trackedSpellIds+1] = spellId
			end
		end
		db:SetCharacterData("enabled_spell_ids", enabledSpellIds, "tracking")
		db:SetCharacterData("first_time", false)
	else
		self:SetActiveTracking()
	end

	self:SetUpdateConditions()
end

function Core:SetUpdateConditions()
	self:debug("Update conditions")
	local db = AutoTrackSwitcher.Db
	local conditions = db:GetProfileData("conditions")

	local const = AutoTrackSwitcher.Const
	if conditions.disable_in_combat == const.ENUM_DISABLE_IN_COMBAT.YES then
		self._disableInCombatFunc = trueFunc
	elseif conditions.disable_in_combat == const.ENUM_DISABLE_IN_COMBAT.UNMOUNTED then
		self._disableInCombatFunc = conditionUnmountedCombatFunc
	else
		self._disableInCombatFunc = falseFunc
	end

	self._disableForAreas = conditions.disable_in_areas
	self._checkDisableWhileFalling = conditions.disable_while_falling
end

-- TODO: Move to PUtils
function Core:bitAdd(mask, name, ignoreStopping)
	self:debug("Adding %s to %s (%s)", tostring(mask), tostring(self._bit), name)
	self._bit = bit.bor(self._bit, mask)
	self:debug("(A) New bit %s", tostring(self._bit))

	if not ignoreStopping and self._started then
		self:debug("Paused due to: %s", name)
		self:Stop()
	end
end

function Core:bitRemove(mask, name, ignoreStarting)
	self:debug("Removing %s from %s (%s)", tostring(mask), tostring(self._bit), name)
	self._bit = bit.band(self._bit, bit.bnot(mask))
	self:debug("(R) New bit %s", tostring(self._bit))

	if not ignoreStarting and self._started then
		self:debug("Resumed due to: %s", name)
		self:Start()
	end
end

function Core:bitCheck(mask)
	return bit.band(self._bit, mask) == mask
end


function Core:UpdateTrackingData()
	wipe(self._trackingData)

	if GameUtils.IsClassic() then
		local spells = {
			2580, -- Find Minerals
			2383, -- Find Herbs
			2481, -- Find Treasure
			5500, -- Sense Demons
			5502, -- Sense Undead
			1494, -- Track Beasts
			19878, -- Track Demons
			19879, -- Track Dragonkin
			19880, -- Track Elementals
			19882, -- Track Giants
			19885, -- Track Hidden
			19883, -- Track Humanoids (Hunter)
			5225, -- Track Humanoids (Druid)
			19884 -- Track Undead
		}

		for i = 1, #spells do
			local id = spells[i]
			if IsSpellKnown(id) then -- Mining
				local name, _, texture = GetSpellInfo(id)
				self._trackingData[id] = {
					name = name,
					index = id,
					isNested = false,
					texture = texture
				}
			end
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

function Core:SetActiveTracking()
	local db = AutoTrackSwitcher.Db

	wipe(self._trackedSpellIds)

	local updateDb = false
	local enabledSpellIds = db:GetCharacterData("tracking", "enabled_spell_ids")
	for spellId, enabled in pairs(enabledSpellIds) do
		if enabled and self._trackingData[spellId] then
			self:debug("Enabling tracking skill %q", self._trackingData[spellId].name)
			self._trackedSpellIds[#self._trackedSpellIds + 1] = spellId
		else
			self:debug("Removing invalid tracking skill %q", spellId)
			enabledSpellIds[spellId] = nil
			updateDb = true
		end
	end

	if updateDb then
		db:SetCharacterData("enabled_spell_ids", enabledSpellIds, "tracking")
	end
end

function Core:GetTimer()
	if self._intervalPerTrackingType then
		local nextIndex = (self._currentUpdateIndex % #self._trackedSpellIds) + 1
		local spellId = self._trackedSpellIds[nextIndex]
		local interval = self._individualTrackingTimers[tostring(spellId)]
		return interval
	else
		return self._updateInterval
	end
end

function Core:Start(isInitial)
	self:debug("Starting")
	if isInitial and self._running then
		self:printf("AutoTrackSwitcher already running!")
		return
	end

	if #self._trackedSpellIds == 0 then
		self:debug("No tracking spells enabled")
		return
	end

	if self._timer then -- Failsafe. Should never happen that we can start while a timer is already running, but just in case
		self:CancelTimer(self._timer)
	end

	if self._updateTimer then -- Failsafe. Should never happen that we can start while a timer is already running, but just in case
		self:CancelTimer(self._updateTimer)
	end

	self._numTimesFalling = 0
	self._started = true
	if isInitial then
		self:printf("AutoTrackSwitcher started!")
	end

	if self._bit ~= Free then
		self:debug("Couldn't start. Something is blocking")
		return
	end

	local interval = self:GetTimer()
	if not self._intervalPerTrackingType then
		self._timer = self:ScheduleRepeatingTimer("OnDoLogic", interval)
	end

	self._updateTimer = self:ScheduleRepeatingTimer("OnUpdate", 0.5)

	self._running = true
	self:SendMessage("OnStart", interval)

	if isInitial then
		self:OnDoLogic()
	end
end

function Core:Stop(isInitial)
	self:debug("Stopping")
	if not self._started then
		self:printf("AutoTrackSwitcher not started!")
		return
	end

	if self._timer then
		self:CancelTimer(self._timer)
		self._timer = nil
	end

	if isInitial then
		if self._updateTimer then
			self:CancelTimer(self._updateTimer)
			self._updateTimer = nil
		end
		self:bitRemove(PlayerFalling, "PlayerFalling", true)
	end

	self:SendMessage("OnStop")
	self._running = false

	if isInitial then
		self:printf("AutoTrackSwitcher stopped!")
		self._started = false
	end
end

function Core:IsRunning()
	return self._running
end

function Core:IsStarted()
	return self._started
end

function Core:SetInterval(tracking, skipRestart)
	local interval = math.min(math.max(tracking.interval, 2.01), 60)

	self._updateInterval = interval
	self._intervalPerTrackingType = tracking.enable_interval_per_tracking_type

	self._individualTrackingTimers = TableUtils.clone(tracking.individual, self._individualTrackingTimers or {})
	for k, v in pairs(self._individualTrackingTimers) do
		self._individualTrackingTimers[k] = math.min(math.max(v, 2.01), 60)
	end

	if self._started and not skipRestart then
		self:debug("Restarting timer")
		self:Stop()
		self:Start()
	end
end

function Core:OnPlayerEnteringWorld(event, isInitialLogin, isReloadingUi)
	self:debug("OnPlayerEnteringWorld: %q, %q", tostring(isInitialLogin), tostring(isReloadingUi))
	self:Initialize()
end

function Core:OnSkillLinesChanged()
	self:debug("Skill list changed. Fetching data anew")
	self:UpdateTrackingData()
	self:OnConfigChange()
end

function Core:OnLearnedSpellInTab()
	self:debug("New spell learned. Fetching data anew")
	self:UpdateTrackingData()
	self:OnConfigChange()
end

function Core:OnItemLocked(eventName, bagIndex, slotIndex)
	self:bitAdd(ItemLocked, "ItemLocked")
	self._bagIndex = bagIndex
	self._slotIndex = slotIndex
end

function Core:OnItemUnlocked(eventName, bagIndex, slotIndex)
	self:bitRemove(ItemLocked, "ItemLocked")

	self._bagIndex = nil
	self._slotIndex = nil
end

function Core:OnBagUpdate(eventName, bagIndex)
	-- ITEM_UNLOCKED is not called when a item is deleted from the inventory.
	-- So we need to check on bag update if the item slot is empty and release then

	if bagIndex ~= self._bagIndex then
		return
	end

	local info = GetContainerItemInfo(bagIndex, self._slotIndex)
	if info then
		return
	end

	self:bitRemove(ItemLocked, "ItemLocked")

	self._bagIndex = nil
	self._slotIndex = nil
end

function Core:OnLootOpened(autoLoot)
	self:bitAdd(LootOpened, "LootOpened", true)

	if not autoLoot then
		if self._started then
			self:debug("Paused due to: Loot Window opened")
			self:Stop()
		end
	elseif self._started then
		local total = 0
		for i = 0, 4 do
			total = total + GetContainerNumFreeSlots(i)
		end
		if total == 0 then
			self:debug("Paused due to: Loot Window opened (inventory full)")
			self:Stop()
		end
	end
end

function Core:OnLootClosed()
	self:bitRemove(LootOpened, "LootOpened")
end

function Core:OnZoneChanged()
	local _, instanceType = GetInstanceInfo()
	local currentArea = instanceType == "none" and "world" or instanceType

	local shouldStop = self._disableForAreas[currentArea] or (self._disableForAreas.city and IsResting("player"))
	if shouldStop then
		self:bitAdd(ZoneChanged, "ZoneChanged")
	else
		self:bitRemove(ZoneChanged, "ZoneChanged")
	end
end

function Core:OnPlayerEnterCombat()
	if self._disableInCombatFunc("player") then
		self:bitAdd(PlayerCombat, "PlayerCombat")
	end
end

function Core:OnPlayerLeaveCombat()
	self:bitRemove(PlayerCombat, "PlayerCombat")
end

function Core:OnPlayerDead()
	self:bitAdd(PlayerDead, "PlayerDead")
end

function Core:OnPlayerUnGhost()
	self:bitRemove(PlayerDead, "PlayerDead")
end

function Core:OnSpellcastStart(event, unit)
	if unit ~= "player" then
		return
	end

	self:bitAdd(PlayerCasting, "PlayerCasting")
end

function Core:OnSpellcastStop(event, unit)
	if unit ~= "player" then
		return
	end

	self:bitRemove(PlayerCasting, "PlayerCasting")
end

function Core:OnStartTalkWithNPC(event)
	self:bitAdd(TalkingWithNPC, "TalkingWithNPC")
end

function Core:OnStopTalkWithNPC(event)
	self:bitRemove(TalkingWithNPC, "TalkingWithNPC")
end

function Core:OnConfigChange(...)
	self:SetActiveTracking()
	self:SetUpdateConditions()
	self:OnZoneChanged()
	
	if UnitAffectingCombat("player") then
		self:OnPlayerEnterCombat()
	else
		self:OnPlayerLeaveCombat()
	end

	local db = AutoTrackSwitcher.Db
	self:SetInterval(db:GetProfileData("tracking"), true)

	if self._started then
		self:Stop()

		if #self._trackedSpellIds > 0 then
			self:Start()
		end
	end
end

function Core:CheckIsFalling()
	if IsFalling() then -- Is falling
		if self:bitCheck(PlayerFalling) then -- Already marked as falling
			return
		end

		if self._numTimesFalling < 4 then
			self._numTimesFalling = self._numTimesFalling + 1
			return
		end

		self:bitAdd(PlayerFalling, "PlayerFalling")
		return
	end

	-- Not falling
	if self:bitCheck(PlayerFalling) then -- Marked as falling
		self:bitRemove(PlayerFalling, "PlayerFalling")
	end

	if self._numTimesFalling > 0 then
		self._numTimesFalling = 0
	end
end

function Core:OnUpdate()
	if self._checkDisableWhileFalling then
		self:CheckIsFalling()
	end
end

function Core:OnDoLogic()
	local interval = self:GetTimer()
	self:SendMessage("OnDoLogic", interval)

	self._currentUpdateIndex = (self._currentUpdateIndex % #self._trackedSpellIds) + 1
	local spellId = self._trackedSpellIds[self._currentUpdateIndex]
	local trackingData = self._trackingData[spellId]

	if self._intervalPerTrackingType then
		self._timer = self:ScheduleTimer("OnDoLogic", interval)
	end

	if isTracking(trackingData) then
		self:debug("Already tracking")
		return
	end

	TrackSpell(trackingData)
	self:SendMessage("OnTrackingChanged", trackingData.texture)
end
