name = ""
description = ""
author = ""
version = ""
forumthread = ""
server_filter_tags = {""}
icon_atlas = "modicon.xml"
icon = "modicon.tex"
api_version_dst = 10
priority = 0
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false
configuration = {
    {
        name = "language",
        label = "Language",
        hover = "Set Language",
        options = {
            {description = "English", data = "en", hover = "English"},
            {description = "中文", data = "ch", hover = "Chinese"},
            {description = "Default", hover = "Accord to the game", data = "default"},
            default = "default",
        },
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
    for i = 1, #conf do
        local v = conf[i]
        if not v.disabled then
            index = index + 1
            config[index] = {
                name = v.name,
                label = (v.name and translate(v.name) or baseTranslate(v.name)) or v.label or "",
                hover = (v.hover and (translate(v.hover) or baseTranslate(v.hover))),
                options = {},
                default = v.default or "",
            }
            if v.unusable then
                config[index].label =
                    config[index].label .. "[" .. (translate("unusable") or baseTranslate("unusable")) .. "]"
            end
            for j = 1, #v.options do
                local opt = v.options[j]
                config[index].options[j] = {
                    description = (opt.description and (translate(opt.description) or baseTranslate(opt.description))) or
                        "",
                    hover = (opt.hover and (translate(opt.hover) or baseTranslate(opt.hover))) or "",
                    data = opt.data or "",
                }
            end
        end
    end
    configuration_options = config
end
local function makeInfo(translation)
    local localName = translation("name")
    local localDescription = translation("description")
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
