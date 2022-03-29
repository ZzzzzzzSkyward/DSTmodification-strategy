# 《饥荒联机版》代码修改策略

## 摘要

这里介绍的策略只适用于小型mod对部分源码的有限改动情景。

## 1 环境配置策略

### 1.1 全局环境

lua语言将全局环境变量存储到表`_G`中。

定义全局变量`a=1`等效于`_G.a=1`或`_G["a"]=1`，如果之前已经存在变量`a`，则会覆盖`a`。

读取全局变量时如`b=a+1`等效于`_G.b=_G.a+1`，如果a未定义则报错。为了避免报错，可以使用函数`rawget`与`rawset`，将读取语句重写成`b=_G.rawget(_G,"a")`，如此当`a`未定义时，`rawget`就返回`nil`，避免了报错。进一步，为了避免`c=a.b`中`a`是`nil`时报错，往往需要写成`c=a~=nil and a.b`。

由于全局环境表`_G`一般是不会去动它的，所以今后代码中位于`_G`的函数我都不再加`_G`前缀了。

```lua
--此处插入一个练习
--使用pairs函数遍历_G，看看Klei在里面塞了多少东西
for i,v in pairs(_G) do print(i,v) end
--打开联机版控制台，复制粘贴，打开client_log.txt看看
```

我们通过这个练习注意到，`_VERSION="Lua 5.1"`，所以想要学习联机版的代码，就需要知道lua5.1的语法。

### 1.2 局部环境

所有用`local`关键词定义的变量都不是存在`_G`里的，比如`local a=1`，此时`print(_G.a)`，只会输出nil。此时`a`作为一个`upvalue`存在，是无法通过正常手段在其他环境中获取的。在lua5.2及以上版本，这些`upvalue`默认存储在局部环境表`_ENV`中。

```lua
--练习
a=1
local b=2
print(b)
print(_G.b)
print(a+b)
```

饥荒中的许多prefab（在prefabs/文件夹中）定义了大量的局部变量，我们无法正常获取这些变量。

### 1.3 mod环境

#### 1.3.1 文件结构

modinfo.lua在启动时加载，提供mod设置信息

modmain.lua在进入世界时加载，提供运行信息

注意到modinfo里的_G缺少大量基础函数，比如`pairs`与`ipairs`。

可以使用`require`语句和`modimport`函数加载其他文件。

#### 1.3.2 modinfo

一个modinfo.lua至少必须包含某些变量，这些变量可以在modindex.lua中查到，它们是

- modname=folder_name，自动设置成mod文件夹名

- locale=LOC.GetLocaleCode()

- ChooseTranslationTable = function(tbl)

  ​      local locale = LOC.GetLocaleCode()

  ​      return tbl[locale] or tbl[1]

  end

- api_version_dst=10

- 基本信息：

  - name
  - description
  - author
  - version
  - api_version=api_version_dst
  - dont_starve_compatible
  - reign_of_giants_compatible
  - configuration_options
  - dst_compatible

- mod类型：client_only_mod or all_clients_require_mod or server_only_mod

还有一些非必需的变量：

- forumthread
- priority
- server_filter_tags
- icon
- icon_atlas

基本信息、api_version_dst和mod类型三类变量需要你自己定义，程序会检查你有没有定义它们。

##### 1.3.2.1 configuration_options

它是一张表，每个配置项形如

```lua
{
        name = "set_idioma",
        label = "Language/Idioma/选择语言",
		hover = "Change mod language...",
        options =
        {
			{description = "English", data = "stringsEU"},
     		{description = "中國", data = "stringsCh"},
        },
        default="stringsEU"
},
```

在modmain.lua里通过`GetModConfigData("set_idioma")`就可以拿到`data`。

其中`name`是必需的，如果有`options`，`data`是必需的。

##### 1.3.2.2 mod类型

客户端`client_only`的意思是不需要服务器计算，比如翻译、动画、音乐、游戏背景图等。

服务器端`server_only`的意思是不需要客户端计算，比如脑子（brains）、各种组件。

剩下的就是`all_clients_required`，进游戏会自动安装这类mod。

```lua
--使用
IsServer, IsDedicated = TheNet:GetIsServer(), TheNet:IsDedicated()
--可以读取到是不是服务器、专用服务器
--控制台里的远程/本地也可以
--然后你可以打印一下，看看这玩意是不是仅限服务器端的
AddPrefabPostInit("wilson",function(inst)
	    --比如威尔逊的饥饿值组件
		print(inst.components.hunger)
end)
```

#### 1.3.3 modmain

由于Klei为每个mod设置了不同的环境`env`，并提供了`GLOBAL`环境用来访问`_G`，我们可以手动改一下mod环境，比如

```lua
GLOBAL.setmetatable(env, {
    __index = function(t, k)
        return GLOBAL.rawget(GLOBAL, k)
    end,
})
```

如此一来，就不需要使用`GLOBAL.xxx`，而是直接输入`xxx`就能读到`GLOBAL`里的变量了。

在mods.lua中可以看到`env`里塞了什么东西：

```lua
local env =
	{
        -- lua
		pairs = pairs,
		ipairs = ipairs,
		print = print,
		math = math,
		table = table,
		type = type,
		string = string,
		tostring = tostring,
		require = require,
		Class = Class,

        -- runtime
		TUNING=TUNING,

        -- worldgen
		LEVELCATEGORY = LEVELCATEGORY,
        GROUND = GROUND,
        LOCKS = LOCKS,
        KEYS = KEYS,
        LEVELTYPE = LEVELTYPE,

        -- utility
		GLOBAL = _G,
		modname = modname,
		MODROOT = MODS_ROOT..modname.."/",
	}
env.env=env
env.modimport=function(modulename)end
```

上面提供的东西我们全都可以用，但剩下的比如`STRINGS`等就是在`GLOBAL=_G`中了。除了这些基础的变量，在modutils里还定义了大量函数以供调用。

`require`语句读取`scripts/`文件夹下的某个文件，返回该文件`return的东西`或`true`。`modimport`函数读取mod文件夹下的某个文件。如果想要去除`GLOBAL`前缀，为了保险起见，建议统一在所有文件中都加上。

```lua
require("a")
--与
modimport("scripts/a.lua")
--等价
--但是modimport的优势在于可以加载mod文件夹根目录的文件
```

## 2 变量修改策略

### 2.1 变量类型

由于lua语言允许c/c++，而且饥荒的底层引擎（动画、皮肤系统等）确实是用c/c++编写的，这导致我们在lua层无法修改c/c++层，除非你不用lua，用其他工具，这是非常困难的。

以皮肤系统为例，我们知道KLei检查是否拥有皮肤会调用`TheInventory:Check(Client)Ownership(user_id, item)`，这个接口定义在c/c++层。我们试图修改之：

```lua
oldClientCheckfn=TheInventory.CheckClientOwnership
oldCheckfn=TheInventory.CheckOwnership
newCheckfn=function(...)return true end
TheInventory.CheckClientOwnership=newCheckfn
print(TheInventory:CheckClientOwnership())
--attempt to index global 'TheInventory' (a userdata value)
print(TheInventory)
--InventoryProxy
InventoryProxy.CheckOwnership=newCheckfn
--修改成功！
--然而你会发现没有卵用
--进去看看我的财物
--炸了
```

由上述例子可见，lua无法修改c/c++，而且lua甚至看不到c/c++的任何内容，只知道接口（此例中是`InventoryProxy`）

### 2.2 全局变量

以`TUNING`为例说明这类变量。

```lua
TUNING =
    {
        MAX_SERVER_SIZE = 6,
        DEMO_TIME = total_day_time * 2 + day_time*.2,
        AUTOSAVE_INTERVAL = total_day_time,
        SEG_TIME = seg_time,
        TOTAL_DAY_TIME = total_day_time,
        DAY_SEGS_DEFAULT = day_segs,
        DUSK_SEGS_DEFAULT = dusk_segs,
        NIGHT_SEGS_DEFAULT = night_segs,
        ...
    }
```

这个表里定义了一堆常量，所有文件都可以引用之，也可以修改之。

### 2.3 类的成员变量

modutil.lua里定义了一些函数用来将你自己的代码注入到类中。以`Prefab`为例说明。

```lua
--prefabs.lua
Prefab = Class( function(self, name, fn, assets, deps, force_path_search)
    self.name = string.sub(name, string.find(name, "[^/]*$"))  --remove any legacy path on the name
    self.desc = ""
    self.fn = fn
    self.assets = assets or {}
    self.deps = deps or {}
    self.force_path_search = force_path_search or false

    if PREFAB_SKINS[self.name] ~= nil then
		for _,prefab_skin in pairs(PREFAB_SKINS[self.name]) do
			table.insert( self.deps, prefab_skin )
		end
    end
end)
--这个类里的第三个参数fn就是用于初始化这个prefab的函数
--amulet.lua
return Prefab("amulet", red, assets)
--生命护符的初始化函数为red
local function red()
    --inst代表我们这个prefab
    local inst = commonfn("redamulet", "resurrector", true)
	--如果不是服务器就不要执行以下代码
    if not TheWorld.ismastersim then
        return inst
    end

    -- red amulet now falls off on death, so you HAVE to haunt it
    -- This is more straightforward for prototype purposes, but has side effect of allowing amulet steals
    -- inst.components.inventoryitem.keepondeath = true

    inst.components.equippable:SetOnEquip(onequip_red)
    inst.components.equippable:SetOnUnequip(onunequip_red)

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst.components.finiteuses:SetMaxUses(TUNING.REDAMULET_USES)
    inst.components.finiteuses:SetUses(TUNING.REDAMULET_USES)

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_INSTANT_REZ)

    return inst
end
--有一个所有护符通用的commonfn
local function commonfn(anim, tag, should_sink)
    --entity定义在c/c++层，这些函数我们没法改
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()

    MakeInventoryPhysics(inst)
	--AnimState定义在c/c++层，也没法改
    inst.AnimState:SetBank("amulets")
    inst.AnimState:SetBuild("amulets")
    inst.AnimState:PlayAnimation(anim)
	--标签是一种很好用的东西
    if tag ~= nil then
        inst:AddTag(tag)
    end
	--定义在prefab上的变量，非常好，我们可以轻松地改掉
    inst.foleysound = "dontstarve/movement/foley/jewlery"

    if not should_sink then
        --不知道哪来的函数，有点难改
        MakeInventoryFloatable(inst, "med", nil, 0.6)
    end
	--定义在c/c++层的，如果不是服务器就不用继续执行了
    inst.entity:SetPristine()
	--定义在lua层的，如果不是服务器就不用继续执行了
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable.dapperness = TUNING.DAPPERNESS_SMALL
    inst.components.equippable.is_magic_dapperness = true

    inst:AddComponent("inventoryitem")
    if should_sink then
        inst.components.inventoryitem:SetSinks(true)
    end

    return inst
end
```

对`Prefab`类我们有注入函数`AddPrefabPostInit`，在这个prefab创建后执行。

```lua
--modutil.lua
env.postinitfns.PrefabPostInit = {}
env.AddPrefabPostInit = function(prefab, fn)
		initprint("AddPrefabPostInit", prefab)
		if env.postinitfns.PrefabPostInit[prefab] == nil then
			env.postinitfns.PrefabPostInit[prefab] = {}
		end
		table.insert(env.postinitfns.PrefabPostInit[prefab], fn)
end
--mainfunctions.lua
if prefab then
        local inst = prefab.fn(TheSim)

        if inst ~= nil then

            inst:SetPrefabName(inst.prefab or name)
	        --注意这里就是注入的地方
            local modfns = modprefabinitfns[inst.prefab or name]
            if modfns ~= nil then
                for k,mod in pairs(modfns) do
                    mod(inst)
                end
            end

            if inst.prefab ~= name then
                modfns = modprefabinitfns[name]
                if modfns ~= nil then
                    for k,mod in pairs(modfns) do
                        mod(inst)
                    end
                end
            end

            for k,prefabpostinitany in pairs(ModManager:GetPostInitFns("PrefabPostInitAny")) do
                prefabpostinitany(inst)
            end

            return inst.entity:GetGUID()
        else
            print( "Failed to spawn", name )
            return -1
        end
end
```

由于你已经获取到了`inst`，所以任何属于`inst`的变量你都可以改了。

### 2.4局部变量

任何局部变量都无法用正常手段修改

以abigail.lua为例

```lua
--abigail.lua
local assets = {
	Asset("ANIM", "anim/player_ghost_withhat.zip"),
    Asset("SOUND", "sound/ghost.fsb"),
}
return Prefab("abigail", fn, assets, prefabs)
--我想修改assets，可以这么做吗？
AddPrefabPostInit("abigail",function(inst)
        assets[1]=Asset("ANIM", "anim/player_ghost_withouthat.zip")
end
)
--不行，读不到assets
```

对于这种情况，有两种办法：

#### 2.4.1覆盖原文件

复制一份abigail.lua，然后在modmain里写：

```lua
PrefabFiles={"abigail"}
```

这样系统会优先读mod文件，达到修改的效果。

这么做有至少两个缺点：1.Klei更新你就要更新，2.不兼容其他这么做的mod。如果你保证能够避免这两个缺点，那么也不失为一个好方法。

#### 2.4.2 debug工具

`name,value=debug.getupvalue(env, id)`与`debug.setupvalue(env, id, value)`是lua自带的调试工具。它能获取到局部变量。

以下是一个简单的例子，但是它只实现了一层作用域的hack。

```lua
function GetAllValue(env)
    local up = 1
    local name, value = nil, nil
    local ret = {}
    while true do
        name, value = debug.getupvalue(env, up)
        if not name then
            break
        else
            ret[name] = {value = value, up = up}
            up = up + 1
        end
    end
    return ret
end
function GetValue(env, key)
    local up = 1
    local name, value = nil, nil
    while true do
        name, value = debug.getupvalue(env, up)
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
function SetValue(env, key, val)
    local name, value, up = GetValue(env, key)
    if name then
        debug.setupvalue(env, up, val)
    else
        print("SetValue: ", "key", key, "not found in", env)
    end
end
```

我们的目标是把这个工具做成适用于所有局部变量的东西。在上述函数`GetValue`中，我们输入`Prefabs[prefab_name].fn`作为`env`，其中`prefab_name`是某个prefab的名字，就可以读到这个成员函数里使用的所有变量了。但事情往往是这样的：

```lua
local c=AnotherFnInAnotherFile()
local d=Whatever.variable.defined.in.another.file
local function f3(a)
    return a+d
end
local function f2()
    return f3(c)
end
local function f1()
    return c==d and f2() or nil
end
local function fn()
    a=f1()
end
```

这个时候你想要改d的话，就必须使用`SetValue(GetValue(GetValue(GetValue(fn,"f1"),"f2"),"f3"),"d",your_custom_d)`，这肯定要写成递归或栈吧。进一步，我们还想规定一下语法，比如`SetSyntaxValue(fn,"f1.f2.f3.d",your_custom_d)`这种易读的写法，这可以使用正则表达式实现。

### 2.5 服务器变量

客户端要读数据需要向服务器发请求，比如组件，饥荒自带的组件封装了网络模块，只需要调用`AddNetwork()`就行。你可以发现有些组件具有同名`_replica`与`_classified`组件，我也不太懂。

`ModRPCHandler`是给mod用的定义网络模块，具体见https://forums.kleientertainment.com/forums/topic/122473-new-modding-rpcs-api

## 3 修改模式

### 3.1 装饰器模式

装饰器是一个能够为原函数添加新功能的函数

```lua
--oldfn指旧函数，newfn指新函数
function wrapperBefore(oldfn,newfn)
	--因为不知道参数有多少，所以是可变参数
	return function(...)
		newfn(...)
		return oldfn(...)
	end
end
```

这个例子简单地实现了在原函数之前执行新函数的操作。

类似地，可以在之后执行，也可以替换执行。

```lua
function wrapperAfter(oldfn,newfn)
	return function(...)
		oldfn(...)
		return newfn(...)
	end
end
function wrapperSubstitute(oldfn,newfn)
	return function(...)
		return newfn(...)
	end
end
```

举个栗子：

```lua
local OldStop = self.Stop
function self:Stop(sgparam)
    OldStop(self, sgparam)
    if self.driftangle and self.inst:HasTag("aquatic") and self.inst:HasTag("player") and GLOBAL.StopUpdatingComponents[self] == self.inst then
        self:StartUpdatingInternal()
    end
end
local OldClose = self.Close
function self:Close()
    OldClose(self)
    if self.isboat then
        self.inst:RemoveEventCallback("percentusedchange", BoatState, self.contanier)
    end
end
```

## 4 Debug

### 4.1 读日志

在`Documents\Klei\DoNotStarveTogether\`文件夹里有几个日志，其中client_log一定会出现。

1.   client_log.txt
2.   server_log.txt
3.   master_server_log.txt
4.   caves_server_log.txt

我们以client_log为例读一读

`[00:00:00]: System Memory:`一些系统信息

`[00:00:06]: loaded modindex`开始加载modinfo了，这时你能看到一些关于mod的信息

`[00:00:16]: Reset() returning`加载mod完毕

`[00:00:16]: Do AutoLogin`开始登录

（未完待续）

### 4.2 使用print调试

一般我调试c/c++/python/js都可以加断点，也可以单步调试，但我好像不懂怎么调试一个游戏。所以还是老办法，每隔几行就print一下，然后看日志。

但是为了节省代码量，我们希望这个print功能具有如下特点：

1. 能够有一个标志全部启用/禁用
2. 能够输出所在函数、行号
3. 在2的基础上，回溯追踪打印出函数调用栈
4. 支持代码测试

这些功能有的很容易实现，我来写一个

```lua
--当然是可变参数了
function Print(...)
    --[[getinfo(level,arg)
    level=0,env=getinfo
    level=1,env=Print
    level=2,env=调用Print的函数
    ...
    ]]
    local info=debug.getinfo(2)
    local defaultvalue="???"
    --读文件名
    --@xxx.lua
    local filename=info.source or defaultvalue
    --读函数名
    local fnname=info.name or defaultvalue
    local lua,c="Lua","C"
    local type=fnname.what
    if type~=lua and type~=c then
        --lua的二进制程序
        type="LuaBinary"
    end
    --读行号，读不到就读函数定义句的行号
    local line=info.currentline~=-1 and info.currentline or info.linedefined
    --合成字符串
    local str=packstring(filename,":",line,"\n",type," Function ",fnname,"\n",...)
    print(str)
end
```

然后，我们就可以稍微修改一下，得到一个循环追踪版本的print函数了。其实`debug.traceback(msg)`就封装了这个功能。

```lua
function Print(...)
	local maxlevel=10
    for level=2,maxlevel do
        --复制粘贴，稍微改改
    end
end
```

然后我们想要支持代码测试，即`assert`语句但不报错只提示。我想，可以用`debug.getupvalue`来实现，能够支持像`Assert("inst.components.hunger.value",1)->"Test passed, value==1" | "Test failed, value=2, not 1" | "Test aborted, hunger is nil, everything in inst.components are {...}"`这样的。



