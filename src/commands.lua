local _, AutoTrackSwitcher = ...

local DEBUG_SEVERITY = AutoTrackSwitcher.DEBUG_SEVERITY
local dprint = AutoTrackSwitcher.dprint
local print = AutoTrackSwitcher.print
local stringformat = string.format
local wipe = wipe

local Commands = {}
AutoTrackSwitcher.Core:RegisterModule("Commands", Commands, "AceConsole-3.0")

local CHAT_COMMAND_ALIAS = {
    help = "HELP",
    start = "START",
    stop = "STOP",
    
    -- Timer related
    interval = "INTERVAL",
    time = "INTERVAL",

    -- Settings
    settings = "SETTINGS",
    config = "SETTINGS",
    options = "SETTINGS",
}

local CONVERT_FUNCTIONS = {
    number = tonumber,
    string = function(arg) return arg end,
}

local CHAT_COMMANDS = {
    HELP = {
        syntax = "help",
        desc = "Display this help",
        func = "_help"
    },
    START = {
        syntax = "start",
        desc = "Start the addon",
        func = "_start",
    },
    STOP = {
        syntax = "stop",
        desc = "Stop the addon",
        func = "_stop",
    },
    INTERVAL = {
        syntax = "interval",
        desc = "Set in seconds how often the addon should change what is being tracked",
        func = "_set_interval",
        arguments = {
            {
                name = "seconds",
                type = "number",
                required = true,
            },
        }
    },
    SETTINGS = {
        syntax = "settings",
        desc = "Open the settings UI",
        func = "_settings",
    },
}

function Commands:OnInitialize()
end

function Commands:OnEnable()
    self:RegisterChatCommand("ats", "OnChatCommand")
end

function Commands:OnChatCommand(args)
	local firstArg, nextPosition = self:GetArgs(args, 1)
    local command = firstArg and CHAT_COMMAND_ALIAS[firstArg] or CHAT_COMMAND_ALIAS.help

    local commandData = CHAT_COMMANDS[command]
    if not commandData then
        commandData = CHAT_COMMANDS.HELP
    end

    local valid, arguments = self:_validateArguments(commandData, args, nextPosition)
    if valid then
        self[commandData.func](self, unpack(arguments))
    else
        print("Invalid command: \"/ats %s\"", args)
    end
end

local returnArguments = {}
function Commands:_validateArguments(commandData, args, nextPosition)
    wipe(returnArguments)

    local arguments = commandData.arguments
    if not arguments or #arguments == 0 then
        return true, returnArguments
    end

    for i = 1, #arguments do
        local argData = arguments[i]
        local arg = self:GetArgs(args, i, nextPosition)
        if arg then
            arg = CONVERT_FUNCTIONS[argData.type](arg)
            if arg then
                returnArguments[#returnArguments + 1] = arg
            else
                return false -- Invalid type
            end
        elseif argData.required then
            return false -- Missing arg
        end
    end

    return true, returnArguments
end

function Commands:invalid(nextPosition, args)
end

function Commands:_help(nextPosition, args)
    for command, help in pairs(CHAT_COMMANDS) do
        local arguments = help.arguments
        local argString = ""
        if arguments and #arguments > 0 then
            for i = 1, #arguments do
                local argument = arguments[i]
                if argument.required then
                    argString = stringformat("%s <%s:%s>", argString, argument.name, argument.type)
                else
                    argString = stringformat("%s [%s:%s]", argString, argument.name, argument.type)
                end
            end
        end
        print("\"%s%s\" - %s", help.syntax, argString, help.desc)
    end
end

function Commands:_start(nextPosition, args)
    AutoTrackSwitcher.Core:Start()
end

function Commands:_stop(nextPosition, args)
    AutoTrackSwitcher.Core:Stop()
end

function Commands:_set_interval(interval)
    AutoTrackSwitcher.Core:SetInterval(interval)
end

function Commands:_settings(nextPosition, args)
    local module = AutoTrackSwitcher.Options
    module.Toggle()
end