local GLOBAL = _G or GLOBAL
GLOBAL.setmetatable(env, {
    __index = function(t, k)
        return GLOBAL.rawget(GLOBAL, k)
    end,
})
Assets = {}
PrefabFiles = {}
local scripts = {}
local assets = {}
for i, v in ipairs(scripts) do
    modimport(v .. ".lua")
end
for i, v in pairs(assets) do
    table.insert(Asset(i, v))
end