local TOCNAME, AutoTrackSwitcher = ...

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

-- Lua APIs
local pairs = pairs

local Options = {
	optionTemplates = {},
}
AutoTrackSwitcher.Core:RegisterModule("Options", Options, "AceEvent-3.0")

function Options:OnInitialize()
end

function Options:OnEnable()
	AceConfig:RegisterOptionsTable(TOCNAME, self.GetConfig)
	AceConfigDialog:AddToBlizOptions(TOCNAME, "AutoTrackSwitcher")
end

function Options.Toggle()
	if AceConfigDialog.OpenFrames[TOCNAME] then
		AceConfigDialog:Close(TOCNAME)
	else
		AceConfigDialog:Open(TOCNAME)
	end
end

local config_template = {
	type = "group",
	name = "AutoTrackSwitcher",
	args = {},
}
function Options.GetConfig()
	local args = config_template.args
	for name, func in pairs(Options.optionTemplates) do
		args[name] = func()
	end

	config_template.args.profiles = AceDBOptions:GetOptionsTable(AutoTrackSwitcher.Db._db)
	return config_template
end

function Options.AddOptionTemplate(name, template_func)
	assert(not Options.optionTemplates[name])
	Options.optionTemplates[name] = template_func
end

function Options:SetSetting(funcName, ...)
	local db = AutoTrackSwitcher.Db
	db[funcName](db, ...)
	self:SendMessage("CONFIG_CHANGE")
end

