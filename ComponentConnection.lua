--[=[
@Dummy
14/09/23
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(packages.Knit)
local Signal = require(Knit.Util.Signal)
local Symbol = require(Knit.Util.Symbol)
local Promise = require(Knit.Util.Promise)

local FN_MARKER = newproxy(true)
local RBXScriptConnection_MARKER = newproxy(true)

local PreviousComponent = {}
do
	PreviousComponent.__index = PreviousComponent
	
	--[=[
		PreviousComponent.__tostring , crée un symbol pour des méthodes de récuparation simple
	]=]
	
	PreviousComponent.__tostring = function(t)	
		return Symbol("Metatables("..t..")")
	end
	

	--[=[
		Ajout de métatables
		
		```lua
			local data = {}
			data.__index = data
			local newIndex = CreateComponent._oldTask(data)
			
			print(newIndex) = data[_old_task] = {}
			print(data) = data = {_old_task = {} }
		```
	]=]
	
	function PreviousComponent.addMetatables(meta)
		return setmetatable({
			_old_task = {},
		},meta)	
	end
	
	--[=[
		PreviousComponent.PromiseCheck  (task.defer pour des arguments. (optionel) )
		
		```lua
			local component = CreateComponent.new()
			local t = {}

			--function 
			local tSafe = component:safeTable(function(resolve,reject,onCancel) 
				t["Bonjour"] = "Bonjour c'est moi :)"
				t["Aurevoir"] = "Aurevoir :("
				print(t["Bonjour"])
				resolve(t)
			end):finally(function()
				print(t["Aurevoir"])
				table.clear(t)
			end):catch(warn)
		```
	]=]
	
	function PreviousComponent:PromiseChecker(args,t)
		if (type(args) == "function") then
			return Promise.new(args)
		elseif (type(args) == "table") then
			return Promise.new(function(resolve,reject,onCancel)
				if (args) and type(t) == "table" then
					t.__tostring = Symbol("Metatables("..tostring(args)..")")
					t[tostring(args)] = args
					return reject(t)
				end
			end)
		end
		if type(args) == nil then
			error("Promise non crée car, ("..tostring(args)..") possède une erreur.")
		end
	end
	
	local function addRbxScriptConnectionMarker(self,connection)
		if type(RBXScriptConnection_MARKER) == "userdata" then
			RBXScriptConnection_MARKER = getmetatable(RBXScriptConnection_MARKER)
			RBXScriptConnection_MARKER[Symbol(tostring(connection).." Marker")] = connection
			if self._PreviousComponent._old_task[tostring(RBXScriptConnection_MARKER)] == nil then
				self._PreviousComponent._old_task[tostring(RBXScriptConnection_MARKER)] = RBXScriptConnection_MARKER
				print(self,RBXScriptConnection_MARKER)
				return self._PreviousComponent._old_task[tostring(RBXScriptConnection_MARKER)]
			end
			return RBXScriptConnection_MARKER
		elseif type(RBXScriptConnection_MARKER) == "table" then
			RBXScriptConnection_MARKER = setmetatable({
				__index = self,
				__tostring = Symbol(tostring(RBXScriptConnection_MARKER) .."= ".."[@("..tostring(self)..")@]"),
				[Symbol(type(connection))] = connection,	
			},PreviousComponent)
			return RBXScriptConnection_MARKER
		else
			error(type(RBXScriptConnection_MARKER).."doit être soit un userdata soit une table",3)
		end
	end
	
	function PreviousComponent:Check(currentConnection)
		if (self._PreviousComponent._old_task[currentConnection]) == nil then
			return PreviousComponent.PromiseChecker(task.defer(addRbxScriptConnectionMarker,self,currentConnection),getmetatable(RBXScriptConnection_MARKER))
		else
			return debug.traceback(`{self._PreviousComponent._old_task[currentConnection]} doit être nil.`,2)
		end
	end
	
end

local CreateComponent = {}
CreateComponent.__index = CreateComponent

CreateComponent.ExistConnection = PreviousComponent.Check
CreateComponent.safeTable = PreviousComponent.PromiseChecker
CreateComponent._oldTask = PreviousComponent.addMetatables

local function addMetatablesForConnection()
	return CreateComponent._oldTask(CreateComponent)
end

function CreateComponent.new()
	return setmetatable({
		_instances = {},
		_PreviousComponent = addMetatablesForConnection()
	},CreateComponent)
end

local function onDestroyComponent(obj)
	local t = type(obj)
	if t == 'table' then
		return "table"
	elseif t == "function" then
		return "Destroy"
	elseif t == "RBXScriptConnection" then
		return "Disconnect"
	end
	if t == "Instance" then
		return "Destroy"
	elseif t == "thread" then
		return task.cancel(obj)
	end
	error("ne peut pas cancel un component car ce n'est pas un argument valable ",3)
end

local function addComponent(connection)
	if type(FN_MARKER) == "userdata" then
		FN_MARKER = getmetatable(FN_MARKER)
		FN_MARKER.__index = CreateComponent
		FN_MARKER[Symbol("RBXScriptConnection"..type(connection))] = connection
		return FN_MARKER
	elseif type(FN_MARKER) == "table" then
		FN_MARKER = setmetatable({
			__index = CreateComponent,
			__tostring = Symbol(tostring(FN_MARKER) .."= ".."[@("..tostring(connection)..")@]"),
			[Symbol(type(connection))] = connection,	
		},CreateComponent)
		return FN_MARKER
	else
		error(type(FN_MARKER).."doit être soit un userdata soit une table",3)
	end
end

--[=[
Construct marker
Crée un format de construction pour des instances 

local instance = CreateComponent.new() -- nouveau Index
local instanceReforced = instance:Construct(workspace:WaitForChild("SpawnLocation"))

print(instanceReforced)	-- SpawnLocation

```lua
local connection = CreateComponent.new()
connection:Connect(game:GetService("RunService").Stepped,function(t,dt)
	print(t%10)
end)
```

]=]

function CreateComponent:Construct(obj)
	print("En mode construction pour:",obj)
	local uniqueSymbol = Symbol(obj.Name)
	self._instances[uniqueSymbol] = obj
	return self._instances[uniqueSymbol]
end

--[=[
Connection marker
Crée une connection avec les arguments également

```lua
local connection = CreateComponent.new()
connection:Connect(game:GetService("RunService").Stepped,function(t,dt)
	print(t%10)
end)
```

]=]

function CreateComponent:Connect(RBXScriptConnection,fn)
	--print("En mode connection : ",type(RBXScriptConnection),type(fn))
	self:ExistConnection(RBXScriptConnection)
	task.spawn(addComponent,type(RBXScriptConnection))
	return RBXScriptConnection:Connect(fn)
end


return CreateComponent
