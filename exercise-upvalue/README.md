# The Use of Upvalue

## 1 Introduction

Modders generally use 3 methods to hack:

1. Overwrite
2. Hook (with many postinits)
3. Debug

While the first two methods are commonly seen, the third has not yet been popular. Each method has its pros and cons, modders choose freely what they want. Debug library provides modders with the ability to access `upvalue`, the very variables stored in the local environment outside a function.

Because prefab file never passed their `env`, postinits cannot access those local variables which restricts the possibility to mod. Luckily, `debug.getupvalue` and `debug.setupvalue` broadens the chance modders access a local variable.

The chance you can access it fully depends on whether it is a `local` value or `up` value. Although there is `debug.getlocalvalue`, it is even more constrained to certain conditions. So I'm not talking about that.

## 2 Understand Environment

Every file, code and function has its own environment, a table, where values are stored in a table.

modmain.lua's environment is `env`, anything you `require` has its environment set to `_G`. The global environment is `_G`, which means there is nothing larger than `_G`.

An environment can be very small and limited. For example, modinfo.lua's environment is barely an empty table. You cannot even access `_G` in it. When set to an empty table, you lose all libraries.

```lua
function a()
    print("what is the environment?")
end
setfenv(a,{})
a()
-- crash, print is nil
-- that is because print is stored in _G, as _G.print
```

So what is a prefab's environment? They are loaded in `_G`, but you must differentiate. When you call those functions like `load`, `loadstring`, `loadfile`, `pcall`, `xpcall`, you recognize two environments, one is the inner, the other is the current environment. So you can write `load("print('1')","","t",{print=function()print('2')end})()` to change the inner environment and let `print("1")` prints '2'.

And you notice that every prefab file ends with a return statement. If a file returns something, you can write `local ret=require("this file")` to get that thing. You should distinguish what happened, the return value, previously in prefab file's environment, suddenly shows up in another new environment, yet it is using its old environment.

There are tools to get/set environment.

- `setfenv(number_or_function,env)` sets environment. If the first param is number, it refers to the stack. 1 is the current function, 2 is the function who called the current, 3 is the 2nd function before. You understand it by recalling when DST crashes you get a stack traceback.
- `getfenv(number_or_function)` returns environment.
- `setmetatable(table1,metatable1)` sets the table1's environment to metatable1.
- `getmetatable(table1)` returns environment.
- `rawget(table1,key)`returns a table's value without seeking its environment.
- `rawset(table1,key)`sets a table's value without seeking its environment. If key is already in environment, rawset is useful for distinguishing the two.
- as a counterpart, `rawset(getmetatable(table1),key)` sets environment's key.

With the above tools, you can get/set a table/function's environment.

One trick you can do is dynamic variable searching. If `metatable1.__index(_,key)` is defined, and table1 doesn't contains a `key`, Lua will try to call our `__index` function. And here we can do many things like a) search it in a local environment, b) search it in _G, c) print an error, d) cause a crash,...

## 3 Access Local Variables

 I first noticed that in `_G` there is a table called `Prefabs`, containing all prefabs' definitions. For example, Woodie's init function can be accessed by:

```lua
local woodie_init_fn=_G.Prefabs.woodie.fn
-- or if you are doing things in modmain.lua
local woodie_init_fn=GLOBAL.Prefabs.woodie.fn
-- but not
local woodie_init_fn=Prefabs.woodie.fn
-- because there is also a Prefabs in env, thus you get a crash
```

Once you get woodie's init function, you look at woodie.lua and realize its name is `MakePlayerCharacter`, defined in player_common.lua. So you don't want to read that common function, instead, you want to focus on woodie specific function. But you have to find a way from there to here. The bridge is `common_postinit` and `master_postinit`, thus you get a chain like `_G.Prefabs.woodie.fn.master_postinit`. While `_G.Prefabs.woodie.fn` is accessible because it is a table, `master_postinit` is not. The debug library does the trick that it paves the road into a function's variable, treating a function as a table containing all upvalues.

Finally, you can trace all the way up and find a path towards where your target variable is. For example, variable `IsWereMode` can be accessed by the chain `_G.Prefabs.woodie.fn.master_postinit.onrespawnedfromghost.IsWereMode`

Anything you can find located in a chain can be accessed, and the contrary, can't.

## 4 Build Tools

Won't explain it, if you are curious or want to build your own utility, you may try yourself.

The following code works in `_G`, if you want to work in modmain.lua you either defines those global values as local ones like `local debug=GLOBAL.debug` or you indirectly access global environment by `GLOBAL.getmetatable(GLOBAL).__index = function(t, k)return GLOBAL.rawget(t, k)end`

```lua
function GetValue(obj, key)
    local up = 1
    local name, value = nil, nil
    while true do
        name, value = debug.getupvalue(obj, up)
        if not name then
            break
        elseif name == key then
            break
        else
            up = up + 1
        end
    end
    return name, value, up
end

function GetAllValue(obj)
    local up = 1
    local name, value = nil, nil
    local ret = {}
    while true do
        name, value = debug.getupvalue(obj, up)
        if not name then
            break
        else
            ret[name] = {
                value = value,
                up = up
            }
            up = up + 1
        end
    end
    return ret
end
function GetValueRecursive(obj, key, depth)
    local MAXDEPTH = 10
    if type(depth) ~= "number" then
        depth = 1
    end
    if depth > MAXDEPTH then
        print("GetValueRecursive: reached max depth", obj, key, depth)
        return nil, nil, nil
    end
    -- print("[get]", obj, key)
    local up = 1
    local name, value = nil, nil
    local temp_name, temp_value, temp_up = nil, nil, nil
    local ret = nil
    while true do
        name, value = debug.getupvalue(obj, up)
        -- print("[upvalue]", name, value, up)
        if name == nil then
            break
        elseif name == key then
            ret = value
            break
        elseif type(value) == "function" then
            temp_name, temp_value, temp_up = GetValueRecursive(value, key, depth + 1)
            if temp_value then
                obj = temp_name
                ret = temp_value
                up = temp_up
                break
            end
        end
        up = up + 1
    end
    return obj, ret, up
end
function GetValueSuccessive(obj, ...)
    local names = {...}
    if #names == 0 then
        return nil, nil, nil
    end
    local up = 1
    local name, value = nil, obj
    for _, key in ipairs(names) do
        if type(value) ~= "function" then
            print("Upvalue", obj, key, "terminated before", key)
        end
        obj = value
        name, value, up = GetValue(value, key)
        -- print("[upvalue]", name, value, up)
        if not name then
            print("Upvalue", key, "not found in", obj)
            return nil, nil, nil
        end
    end
    return obj, value, up
end
function MakeUpvalueEnv(fn, globalenv, localenv)
    if not globalenv then
        globalenv = env
    end
    if not localenv then
        localenv = fn
    end
    local ret = {
        env = globalenv
    }
    local metaret = {
        values = {}
    }
    metaret.__index = function(_, k)
        if not metaret.values[k] then
            local a, b, c = UPVALUE.get(localenv, k)
            if a and c then
                metaret.values[k] = {a, b, c}
            else
                metaret.values[k] = {}
            end
        end
        if metaret.values[k][1] then
            return metaret.values[k][2]
        end
        return globalenv[k]
    end
    metaret.__newindex = function(_, k, v)
        if not metaret.values[k] then
            metaret:__index(k)
        end
        local info = metaret.values[k]
        if info[1] then
            UPVALUE.set(info[1], info[3], v)
            metaret.value[k][2] = v
        else
            rawset(globalenv, k, v)
        end
    end
    setmetatable(ret, metaret)
    setfenv(fn, ret)
    return fn
end
function packstring(...)
    local n = select('#', ...)
    n = math.min(n, 10)
    local args = {...}
    local function safepack(args, n)
        local str = ""
        for i = 1, n do
            str = str .. tostring(args[i]) .. " "
        end
        return str
    end
    local success, str = pcall(safepack, args, n)
    if success and str then
        return str
    end
    print("error in packstring")
    return ""
end
UPVALUE = {
    get = function(obj, key)
        if type(obj) == "string" then
            obj = safeget(GLOBAL, obj)
        end
        if type(obj) ~= "function" then
            print("UPVALUE.get:", obj, "is not a function")
            return nil, nil, nil
        end
        local upperfn, value, up = GetValueRecursive(obj, key)
        if value then
            return upperfn, value, up
        else
            print("[UPVALUE]", "key", key, "not found in", obj)
            return nil, nil, nil
        end
    end,
    fetch = function(obj, ...)
        if type(obj) == "string" then
            obj = rawget(GLOBAL, obj)
        end
        if type(obj) ~= "function" then
            print("UPVALUE.fetch:", obj, "is not a function")
            return nil, nil, nil
        end
        local upperfn, value, up = GetValueSuccessive(obj, ...)
        if value then
            return upperfn, value, up
        else
            local keys = {...}
            print("[UPVALUE]", "key", keys[1], "not found", packstring(obj, ...))
            return nil, nil, nil
        end
    end,
    set = function(fn, up, value)
        if type(fn) ~= "function" then
            print("[UPVALUE]", "value", value, "is not a function")
        end
        debug.setupvalue(fn, up, value)
    end,
    inject = function(fn, up, value, globalenv)
        if type(value) == "function" or type(value) == "table" then
            MakeUpvalueEnv(value, globalenv or env, fn)
        end
        debug.setupvalue(fn, up, value)
    end
}
--[[
    wtype:before|after|substitute|override
]]
function UpvalueWrapper(obj, key, newfn, wtype)
    local upperfn, oldfn, up = nil, nil, nil
    if type(key) == "string" then
        upperfn, oldfn, up = UPVALUE.get(obj, key)
    elseif type(key) == "table" and #key > 0 and type(key[1]) == "string" then
        upperfn, oldfn, up = UPVALUE.fetch(obj, unpack(key))
    end
    if not upperfn then
        return
    end
    if not wtype then
        wtype = "override"
    end
    if wtype == "before" then
        --UPVALUE.set(upperfn, up, MakeWrapper(oldfn, newfn))
    elseif wtype == "after" then
        --UPVALUE.set(upperfn, up, MakeWrapperAfter(oldfn, newfn))
    elseif wtype == "substitute" then
        --UPVALUE.set(upperfn, up, MakeWrapperSubstitute(oldfn, newfn))
    elseif wtype == "override" then
        --UPVALUE.set(upperfn, up, newfn)
    else
        print("[UPVALUE]", "wtype", wtype, "not supported")
    end
end
```

## 5 Use Tool

```lua
AddPrefabPostInit("woodie",function(inst)
	--_G.Prefabs.woodie.fn
	local fn=ThePrefab.woodie.fn
	local function IsWereMode(mode)
		env.print("hacked is were mode")
		return WEREMODE_NAMES[mode] ~= nil
	end
    --fn.master_postinit.onrespawnedfromghost.IsWereMode
	-- _env is the environment of IsWereMode, value is IsWereMode, index is a number related to its position in file
	local _env,value,index=UPVALUE.fetch(fn,"master_postinit","onrespawnedfromghost","IsWereMode")
	--or local _1,_2,_3=UPVALUE.get(fn,"IsWereMode") but this is more costly
	--inject our own IsWereMode into its original _env. the index is required to locate and replace old function
	--so this looks like another kind of postinit, that is something like Add Environment Function Post Init(_env,function_name,fn) if you combine the two steps together
	UPVALUE.inject(_env,index,IsWereMode,env) -- the last param is our own environment
	--When you try to make such a postinit function, you can take a look at UpvalueWrapper, which does exactly the same thing and even allows you to choose AddEnvironmentFunctionPostInit, AddEnvironmentFunctionPreInit, and ReplaceEnvironmentFunctionPostInit
end)
```

## 6 Notes

- debug library is potentially very costly if you don't handle it well. Because to get a local variable debug may travel between many functions, searching for a proper name. A wise way to go direct to the destination is using `UPVALUE.fetch` and pass one by one the chain nodes.
- You can disable print() when an error occurs.
- With the same reason above, if you want to use a variable at your hand, you might want to add an `env.` prefix to your variables to prevent from numerous error prints.