local _, AutoTrackSwitcher = ...

local Core = LibStub("AceAddon-3.0"):NewAddon("AutoTrackSwitcherCore", "AceTimer-3.0", "AceConsole-3.0")

function Core:OnInitialize()
	self._running = false
	self._trackingInfo = {}
	self._updateList = {}
	self._currentIndex = 0
	self._updateInterval = 2
end

function Core:OnEnable()
	local numTrackingTypes = GetNumTrackingTypes()
	for i = 1, numTrackingTypes do
		local name, texture, active, category, nested, spellId = GetTrackingInfo(i)
		if spellId and nested < 0 then
			self._trackingInfo[spellId] = {
				name = name,
				id = i,
				nested = nested,
			}
			self._updateList[#self._updateList + 1] = spellId
		end
	end

	self:RegisterChatCommand("ats", "OnChatCommand")
end

function Core:OnDisable()
end

function Core:OnUpdate()
	if UnitAffectingCombat("player") and not IsMounted() then
		return -- Skip if in combat and not mounted
	end

	self._currentIndex = (self._currentIndex % #self._updateList) + 1
	local spellId = self._updateList[self._currentIndex]
	local info = self._trackingInfo[spellId]

	SetTracking(info.id, true)
end

function Core:OnChatCommand(args)
	if not self._running then
		local temp = {}
		for i = 1, #self._updateList do
			local spellId = self._updateList[i]
			local info = self._trackingInfo[spellId]
			temp[#temp + 1] = string.format("\"%s\"", info.name)
		end

		print(string.format("AutoTrackSwitcher started! Currently switching between: %s", table.concat(temp, ", ")))
		self._timer = self:ScheduleRepeatingTimer("OnUpdate", self._updateInterval)
		self._running = true
	else
		print("AutoTrackSwitcher stopped!")
		self:CancelTimer(self._timer)
		self._running = false
	end
end