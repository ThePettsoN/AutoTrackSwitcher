local _, AutoTrackSwitcher = ...

local options = AutoTrackSwitcher.Options

local function generalsGroup(order, db)
    local availableTrackingSpells = AutoTrackSwitcher.Core._trackingData
    local trackingSpellLoc = {}
    for spelldId, data in pairs(availableTrackingSpells) do
        trackingSpellLoc[spelldId] = data.name
    end
    
    return {
        type = "group",
        name = "General",
        order = order,
        inline = true,
        args = {
            enabled_spells = {
                name = "Automatically switch between the following tracking skills",
                type = "multiselect",
                width = "full",
                order = 1,
                values = trackingSpellLoc,
                get = function(info, key)
                    return db:GetCharacterData("tracking", "enabled_spell_ids", key)
                end,
                set = function(info, key, newValue)
                    options:SetSetting("SetCharacterData", key, newValue, "tracking", "enabled_spell_ids")
                end,
            },
            interval = {
                name = "How often AutoTrackSwitcher should switch between each tracking skill",
                type = "range",
                width = "full",
                min = 2,
                max = 60,
                step = 1,
                get = function(info)
                    return db:GetProfileData("tracking", "interval")
                end,
                set = function(info, newValue)
                    options:SetSetting("SetProfileData", "interval", newValue, "tracking")
                end
            }
        },
    }
end

local function conditionsGroup(order, db)
    local const = AutoTrackSwitcher.Const
    -- TODO: Move to loc file
    local combatLocalization = {
        [const.ENUM_DISABLE_IN_COMBAT.YES] = "Yes",
        [const.ENUM_DISABLE_IN_COMBAT.NO] = "No",
        [const.ENUM_DISABLE_IN_COMBAT.UNMOUNTED] = "Only while unmounted",
    }
    
    local areaLocalization = {
        world = "World",
        party = "Dungeon",
        raid = "Raid",
        arena = "Arena",
        pvp = "Battleground",
        city = "City",
    }
    
    return {
        type = "group",
        name = "Conditions",
        order = order,
        inline = true,
        args = {
            disable_combat = {
                name = "Disable AutoTrackSwitcher in combat",
                type = "select",
                width = "full",
                order = 1,
                values = combatLocalization,
                get = function(info)
                    return db:GetProfileData("conditions", "disable_in_combat")
                end,
                set = function(info, newValue)
                    options:SetSetting("SetProfileData", "disable_in_combat", newValue, "conditions")
                end,
            },
            disable_in_areas = {
                name = "Disable AutoTrackSwitcher in the following areas",
                type = "multiselect",
                width = "full",
                order = 2,
                values = areaLocalization,
                get = function(info, key)
                    return db:GetProfileData("conditions", "disable_in_areas", key)
                end,
                set = function(info, key, newValue)
                    options:SetSetting("SetProfileData", key, newValue, "conditions", "disable_in_areas")
                end,
            },
            disable_while_falling = {
                type = "toggle",
                width = "full",
                order = 3,
                name = "Disable while falling",
                desc = "Disable AutoTrackSwitcher while the player is falling through the air.",
                get = function(info)
                    return db:GetProfileData("conditions", "disable_while_falling")
                end,
                set = function(info, newValue)
                    options:SetSetting("SetProfileData", "disable_while_falling", newValue, "conditions")
                end,
            },
            disable_while_dead = {
                type = "toggle",
                width = "full",
                order = 4,
                name = "Disable while dead",
                desc = "Disable AutoTrackSwitcher while the player is dead.",
                get = function(info)
                    return db:GetProfileData("conditions", "disable_while_dead")
                end,
                set = function(info, newValue)
                    options:SetSetting("SetProfileData", "disable_while_dead", newValue, "conditions")
                end,
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
            name = "General",
        },
        general = generalsGroup(2, db),
        conditions = conditionsGroup(3, db),
        -- conditions = conditionsGroup(4, db),
    }
    
    return {
        type = "group",
        name = "General",
        order = 1,
        args = args
    }
end

options.AddOptionTemplate("general", optionsTemplate)
