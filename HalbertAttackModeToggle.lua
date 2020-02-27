function widget:GetInfo()
   return {
    name      = "HalbertAttackModeToggle",
    desc      = "Hotkey for toggling Halbert attack mode. Version 0,5",
    author    = "terve886",
    date      = "2019",
    license   = "PD", -- should be compatible with Spring
    layer     = 2,
	handler		= true, --for adding customCommand into UI
    enabled   = true  --  loaded by default?
  }
end

local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local ceil = math.ceil
local UPDATE_FRAME=30
local HalbertStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local GetUnitStates = Spring.GetUnitStates
local Echo = Spring.Echo
local Halbert_NAME = "hoverassault"
local GetSpecState = Spring.GetSpectatingState
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE
local CMD_REMOVE = CMD.REMOVE
local CMD_FIRE_STATE = CMD.FIRE_STATE


local CMD_TOGGLE_ATTACK_MODE = 16997
local HalbertUnitDefID = UnitDefNames["hoverassault"].id

local selectedHalberts = nil

local cmdAttackModeToggle = {
	id      = CMD_TOGGLE_ATTACK_MODE,
	type    = CMDTYPE.ICON,
	tooltip = 'Hotkey to change Halbert fire state.',
	action  = 'oneclickwep',
	params  = { }, 
	texture = 'LuaUI/Images/commands/Bold/dgun.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},  
}


local AttackModeController = {
	unitID,
	allyTeamID = GetMyAllyTeamID(),
	toggle = false,

	
	
	new = function(self, unitID)
		--Echo("AttackModeController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		local unitStates = GetUnitStates(self.unitID)
		if (unitStates.firestate == 2)then
			self.toggle = true
		else
			self.toggle = false
		end
		return self
	end,

	unset = function(self)
		--Echo("AttackModeController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	getToggleState = function(self)
		return self.toggle
	end,
	
	toggleOn = function (self)
		Echo("Halbert attack mode fire at will!")
		GiveOrderToUnit(self.unitID,CMD_FIRE_STATE, 2, 0)
		self.toggle = true
	end,
	
	toggleOff = function (self)
		Echo("Halbert attack mode hold fire")
		GiveOrderToUnit(self.unitID,CMD_FIRE_STATE, 0, 0)
		self.toggle = false
	end,
	
	handle=function(self)
		if (self.toggle) then
			self.pos = {GetUnitPosition(self.unitID)}
			if(self:isEnemyInRange()) then
				return
			end
			self:isEnemyInRushRange()
		end
	end
}


function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Halbert_NAME)
		and (unitTeam==GetMyTeamID()) then
			HalbertStack[unitID] = AttackModeController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID) 
	if not (HalbertStack[unitID]==nil) then
		HalbertStack[unitID]=HalbertStack[unitID]:unset();
	end
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedHalberts ~= nil then
		if (cmdID == CMD_TOGGLE_ATTACK_MODE)then
			local toggleStateGot = false
			local toggleState
			for i=1, #selectedHalberts do
				if (HalbertStack[selectedHalberts[i]])then
					if (toggleStateGot == false)then
						toggleState = HalbertStack[selectedHalberts[i]]:getToggleState()
						toggleStateGot = true
					end
					if (toggleState) then
						HalbertStack[selectedHalberts[i]]:toggleOff()
					else
						HalbertStack[selectedHalberts[i]]:toggleOn()
					end
				end
			end
			return true
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedHalberts = filterHalberts(selectedUnits)
end

function filterHalberts(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (HalbertUnitDefID == GetUnitDefID(unitID)) then
			n = n + 1
			filtered[n] = unitID
		end
	end
	if n == 0 then
		return nil
	else
		return filtered
	end
end


function widget:CommandsChanged()
	if selectedHalberts then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdAttackModeToggle
	end
end



-- The rest of the code is there to disable the widget for spectators
local function DisableForSpec()
	if GetSpecState() then
		widgetHandler:RemoveWidget()
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(GetMyTeamID())
	for i=1, #units do
		unitID = units[i]
		DefID = GetUnitDefID(unitID)
		if (UnitDefs[DefID].name==Halbert_NAME)  then
			if  (HalbertStack[unitID]==nil) then
				HalbertStack[unitID]=AttackModeController:new(unitID)
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
