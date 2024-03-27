local _, AutoTrackSwitcher = ...

local options = AutoTrackSwitcher.Options

local LSM = LibStub("LibSharedMedia-3.0")

local function getFonts()
    local fonts = {}
    for name, path in next, LSM:HashTable("font") do
        fonts[path] = name
    end
    
    return fonts
end

local function buttonGeneralGroup(order, db)
    return {
        type = "group",
        name = "General",
        order = order,
        inline = true,
        args = {
            show = {
                type = "toggle",
                width = "full",
                order = 1,
                name = "Show UI Button",
                desc = "Shows a button on the screen that can be used to start/stop the addon and shows status of it",
                get = function(info)
                    return db:GetProfileData("ui", "button", "conditions", "show")
                end,
                set = function(info, newValue)
                    options:SetSetting("SetProfileData", "show", newValue, "ui", "button", "conditions")
                end,
            },
            show_while_stopped = {
                type = "toggle",
                width = "full",
                order = 2,
                name = "...Only while addon is active",
                desc = "Only show the button while the addon is active and running",
                get = function(info)
                    return not db:GetProfileData("ui", "button", "conditions", "show_while_stopped")
                end,
                set = function(info, newValue)
                    options:SetSetting("SetProfileData", "show_while_stopped", not newValue, "ui", "button", "conditions")
                end,
            },
        }
    }
end

local function buttonTextGroup(order, db)
    return {
        type = "group",
        name = "Text Formatting",
        order = order,
        inline = true,
        args = {
            name = {
                type = "select",
                order = 1,
                name = "Font",
                values = getFonts(),
                get = function(info)
                    return db:GetProfileData("ui", "button", "font", "path")
                end,
                set = function(info, newFont)
                    options:SetSetting("SetProfileData", "path", newFont, "ui", "button", "font")
                end,
            },
            size = {
                type = "range",
                order = 2,
                name = "Size",
                min = 8,
                max = 120,
                step = 1,
                get = function(info)
                    return db:GetProfileData("ui", "button", "font", "size")
                end,
                set = function(info, newSize)
                    options:SetSetting("SetProfileData", "size", newSize, "ui", "button", "font")
                end
            },
        }
    }
end

local function buttonSizeGroup(order, db)
    return {
        type = "group",
        name = "Button Size",
        order = order,
        inline = true,
        args = {
            width = {
                type = "range",
                order = 3,
                name = "Width",
                width = "full",
                min = 8,
                max = 512,
                step = 1,
                get = function(info)
                    return db:GetProfileData("ui", "button", "size", "width")
                end,
                set = function(info, newWidth)
                    options:SetSetting("SetProfileData", "width", newWidth, "ui", "button", "size")
                end
            },
            height = {
                type = "range",
                order = 4,
                name = "Height",
                width = "full",
                min = 8,
                max = 512,
                step = 1,
                get = function(info)
                    return db:GetProfileData("ui", "button", "size", "height")
                end,
                set = function(info, newHeight)
                    options:SetSetting("SetProfileData", "height", newHeight, "ui", "button", "size")
                end
            },
        },
    }
end

local function optionsTemplate()
    local db = AutoTrackSwitcher.Db
    local args = {
        header = {
            order = 1,
            type = "header",
            width = "full",
            name = "UI"
        },
        buttonConditions = buttonGeneralGroup(2, db),
        buttonText = buttonTextGroup(3, db),
        buttonSize = buttonSizeGroup(4, db),
        reset_button_position = {
            name = "Reset button position",
            order = 5,
            type = "execute",
            width = "full",
            func = function(...)
                local x = GetScreenWidth() / 2
                local y = GetScreenHeight() / 2
                options:SetSetting("SetProfileData", "x", x, "ui", "button", "position")
                options:SetSetting("SetProfileData", "y", y, "ui", "button", "position")
            end,
        }
    }
    
    return {
        type = "group",
        name = "UI",
        order = 1,
        args = args
    }
end

options.AddOptionTemplate("ui", optionsTemplate)
