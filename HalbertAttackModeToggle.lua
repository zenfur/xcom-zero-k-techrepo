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

local HalbertStack = {}
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitStates = Spring.GetUnitStates
local Echo = Spring.Echo
local Halbert_ID = UnitDefNames.hoverassault.id
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
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


local AttackModeControllerMT
local AttackModeController = {
	unitID,
	allyTeamID = GetMyAllyTeamID(),
	toggle = false,



	new = function(index, unitID)
		--Echo("AttackModeController added:" .. unitID)
		local self = {}
		setmetatable(self, AttackModeControllerMT)
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
AttackModeControllerMT = {__index=AttackModeController}


function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Halbert_ID)
		and (unitTeam==GetMyTeamID()) then
			HalbertStack[unitID] = AttackModeController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID)
	if not (HalbertStack[unitID]==nil) then
		HalbertStack[unitID]=HalbertStack[unitID]:unset();
	end
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
		widgetHandler:RemoveWidget(widget)
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(GetMyTeamID())
	for i=1, #units do
		local unitID = units[i]
		local unitDefID = GetUnitDefID(unitID)
		if (unitDefID == Halbert_ID)  then
			if  (HalbertStack[unitID]==nil) then
				HalbertStack[unitID]=AttackModeController:new(unitID)
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
