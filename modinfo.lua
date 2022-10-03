name = ""
description = ""
author = ""
version = ""
version_compatible = "" -- accepted lowest version of client
forumthread = ""
server_filter_tags = {}
icon_atlas = "modicon.xml"
icon = "modicon.tex"
api_version = 10
api_version_dst = 10
priority = 0
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
dst_compatible = true
dst_compatibility_specified = true
all_clients_require_mod = true
client_only_mod = false
restart_required = false
forcemanifest = nil -- if you don't want to verify file then set it to false
mod_dependencies={} --currently only support not client_only mod

-- translation goes below
configuration = {
    {
        name = "language",
        label = "Language",
        hover = "Set Language",
        options = {
            {description = "English", data = "en", hover = "English"},
            {description = "中文", data = "ch", hover = "Chinese"},
            {description = "Default", hover = "Accord to the game", data = "default"},
        },
        default = "default",
    },
}

translation = {
    {
        matchLanguage = function(lang)
            return lang == "zh" or lang == "zht" or lang == "zhr" or lang == "chs" or lang == "cht"
        end,
        translateFunction = function(key)
            return translation[1].dict[key] or nil
        end,
        dict = {
            name = "",
            unusable = "不可用",
            description = [[
]],
        },
    },
    {
        matchLanguage = function(lang)
            return lang == "en"
        end,
        dict = {
            name = "",
            description = [[
]],
        },
        translateFunction = function(key)
            return translation[2].dict[key] or key
        end,
    },
}
local function makeConfigurations(conf, translate, baseTranslate)
    local index = 0
    local config = {}
    local function trans(str)
        return translate(str) or baseTranslate(str)
    end

    local string = ""
    local keys = {
        letter = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
                  "U", "V", "W", "X", "Y", "Z"},
        number = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"},
        fn = {"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"},
        mod = {"LAlt", "RAlt", "LCtrl", "RCtrl", "LShift", "RShift"},
        func = {"Backspace", "Insert", "Home", "Delete", "End", "Pageup", "Pagedown", "Print", "Scrollock", "Pause",
                "Tab", "Capslock", "Space"},
        punctuation = {"Minus", "Equals", "Period", "Slash", "Semicolon", "Leftbracket", "Rightbracket", "Tiled",
                       "Backslash", "Up", "Down", "Left", "Right"}
    }
    for i = 1, #conf do
        local v = conf[i]
        if not v.disabled then
            index = index + 1
            config[index] = {
                name = v.name or "",
                label = v.name ~= "" and translate(v.name) or (v.label and trans(v.label)) or baseTranslate(v.name) or
                    nil,
                hover = v.name ~= "" and (v.hover and trans(v.hover)) or nil,
                default = v.default or "",
                options = v.name ~= "" and {{
                    description = "",
                    data = ""
                }} or nil,
                client = v.client or false
            }
            if v.unusable then
                config[index].label = config[index].label .. "[" .. trans("unusable") .. "]"
            end
            if v.key then
                local keylist = {}
                for j = 1, #v.key do
                    local key = v.key[j]
                    local kl = keys[key]
                    for k = 1, #kl do
                        keylist[#keylist + 1] = {
                            description = kl[k],
                            data = "KEY_" .. string.upper(kl[k])
                        }
                    end
                end
                keylist[#keylist + 1] = {
                    description = "Disabled",
                    data = false
                }
                config[index].options = keylist
                config[index].is_keylist = true
                config[index].default = false
            elseif v.options then
                for j = 1, #v.options do
                    local opt = v.options[j]
                    config[index].options[j] = {
                        description = opt.description and trans(opt.description) or "",
                        hover = opt.hover and trans(opt.hover) or "",
                        data = opt.data ~= nil and opt.data or ""
                    }
                end
            end
        end
    end
    configuration_options = config
end

local function makeInfo(translation)
    local localName = translation("name")
    local localDescription = translation("description")
    local localVersionInfo = translation("version") or ""
    if localVersionInfo ~= "" then
        if not localDescription then
            localDescription = ""
        end
        localDescription = localVersionInfo .. "\n" .. localDescription
    end
    if localName then
        name = localName
    end
    if localDescription then
        description = localDescription
    end
end

local function getLang()
    local string = ""
    local lang = string.lower(locale) or "en"
    return lang
end

local function generate()
    local lang = getLang()
    local localTranslation = translation[#translation].translateFunction
    local baseTranslation = translation[#translation].translateFunction
    for i = 1, #translation - 1 do
        local v = translation[i]
        if v.matchLanguage(lang) then
            localTranslation = v.translateFunction
            break
        end
    end
    makeInfo(localTranslation)
    makeConfigurations(configuration, localTranslation, baseTranslation)
end

generate()