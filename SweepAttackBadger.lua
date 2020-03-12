function widget:GetInfo()
	return {
		name         = "SweepAttackBadger",
		desc         = "attempt to make Badger sweep area with flame to search for stealthy units. Version 1,06",
		author       = "terve886",
		date         = "2019",
		license      = "PD", -- should be compatible with Spring
		layer        = 11,
		handler		= true, --for adding customCommand into UI
		enabled      = true
	}
end
local UPDATE_FRAME=90
local SweeperStack = {}
local GetUnitHeading = Spring.GetUnitHeading
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitStates = Spring.GetUnitStates
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local Echo = Spring.Echo
local Badger_NAME = "veharty"
local ENEMY_DETECT_BUFFER  = 40
local GetSpecState = Spring.GetSpectatingState
local pi = math.pi
local FULL_CIRCLE_RADIANT = 2 * pi
local HEADING_TO_RAD = (pi*2/65536 )
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_MOVE = CMD.MOVE
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_UNIT_AI = 36214
local selectedSweepers = nil

local sin = math.sin
local cos = math.cos
local atan = math.atan

local CMD_TOGGLE_SWEEP = 19991
local CMD_TOGGLE_SWEEP_DEFAULT = 19992
local BadgerUnitDefID = UnitDefNames["veharty"].id

local cmdSweep = {
	id      = CMD_TOGGLE_SWEEP,
	type    = CMDTYPE.ICON_MAP,
	tooltip = 'Makes Badger sweep selected area with attacks to search for stealthed units.',
	cursor  = 'Attack',
	action  = 'reclaim',
	params  = { },
	texture = 'unitpics/weaponmod_autoflechette.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}
local cmdSweepDefault = {
	id      = CMD_TOGGLE_SWEEP_DEFAULT,
	type    = CMDTYPE.ICON,
	tooltip = 'Makes Badger sweep the area before it with attacks to search for stealthed units.',
	action  = 'oneclickwep',
	params  = { },
	texture = 'unitpics/weaponmod_autoflechette.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}


local SweeperController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	rotation = 0,
	toggle = false,
	targetParams,
	enemyNear = false,
	fireState,
	fireStateGot = false,
	default = true,




	new = function(self, unitID)
		--Echo("SweeperController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = (GetUnitMaxRange(self.unitID)-15)
		self.pos = {GetUnitPosition(self.unitID)}
		local unitStates = GetUnitStates(self.unitID)
		self.fireState = unitStates.firestate
		return self
	end,


	unset = function(self)
		--Echo("SweeperController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	isEnemyInRange = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+ENEMY_DETECT_BUFFER, false)
		if  (enemyUnitID and GetUnitIsDead(enemyUnitID) == false) then
			if (self.enemyNear == false)then
				GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
				self.enemyNear = true
			end
			return true
		end
		self.enemyNear = false
		return false
	end,

	getToggleState = function(self)
		return self.toggle
	end,

	toggleOn = function (self)
		if(self.fireStateGot == false)then
			local unitStates = GetUnitStates(self.unitID)
			self.fireState = unitStates.firestate
			self.fireStateGot = true
		end
		GiveOrderToUnit(self.unitID,CMD_FIRE_STATE, 0, 0)
		self.toggle = true
	end,

	toggleOff = function (self)
		self.toggle = false
		self.fireStateGot = false
		GiveOrderToUnit(self.unitID,CMD_FIRE_STATE, self.fireState, 0)
		GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
	end,

	setTargetParams = function (self, params)
		self.targetParams = params
	end,


	sweepDefault = function(self)
		local heading = GetUnitHeading(self.unitID)*HEADING_TO_RAD
		if (self.rotation > 3) then
			self.rotation = -3
		end
		local targetPosRelative = {
			sin(heading+0.2*self.rotation)*(self.range),
			nil,
			cos(heading+0.2*self.rotation)*(self.range),
		}
		self.rotation = self.rotation+1
		local targetPosAbsolute = {
			targetPosRelative[1]+self.pos[1],
			nil,
			targetPosRelative[3]+self.pos[3],
		}
		targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
		GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
	end,

	sweep = function(self)
		--local heading = GetUnitHeading(self.unitID)*HEADING_TO_RAD
		if (self.rotation > 3) then
			self.rotation = -3
		end
		local heading = atan((self.pos[1]-self.targetParams[1])/(self.pos[3]-self.targetParams[3]))
		local targetPosRelative = {
			sin(heading+0.2*self.rotation)*(self.range),
			nil,
			cos(heading+0.2*self.rotation)*(self.range),
		}

		self.rotation = self.rotation+1

		local targetPosAbsolute
		if (self.pos[3]<=self.targetParams[3]) then
			targetPosAbsolute = {
				self.pos[1]+targetPosRelative[1],
				nil,
				self.pos[3]+targetPosRelative[3],
			}
		else
			targetPosAbsolute = {
				self.pos[1]-targetPosRelative[1],
				nil,
				self.pos[3]-targetPosRelative[3],
			}
		end

		targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
		GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
	end,


	handle=function(self)
		self.pos = {GetUnitPosition(self.unitID)}
		--if(self:isEnemyInRange()) then
		--	return
		--end
		if(self.toggle)then
			if(self.default)then
				self:sweepDefault()
			else
				self:sweep()
			end
		end
	end
}



function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Badger_NAME)
			and (unitTeam==GetMyTeamID()) then
		SweeperStack[unitID] = SweeperController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (SweeperStack[unitID]==nil) then
		SweeperStack[unitID]=SweeperStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for _,sweeper in pairs(SweeperStack) do
			sweeper:handle()
		end
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
	if selectedSweepers ~= nil then
		if (cmdID == CMD_TOGGLE_SWEEP)then
			local toggleStateGot = false
			local toggleState
			for i=1, #selectedSweepers do
				if (SweeperStack[selectedSweepers[i]])then
					if (toggleStateGot == false)then
						toggleState = SweeperStack[selectedSweepers[i]]:getToggleState()
						toggleStateGot = true
					end
					if (toggleState) then
						SweeperStack[selectedSweepers[i]]:toggleOff()
					else
						SweeperStack[selectedSweepers[i]]:toggleOn()
						SweeperStack[selectedSweepers[i]]:setTargetParams(params)
						SweeperStack[selectedSweepers[i]].default=false
					end
				end
			end
		end
		if (cmdID == CMD_TOGGLE_SWEEP_DEFAULT)then
			local toggleStateGot = false
			local toggleState
			for i=1, #selectedSweepers do
				if (SweeperStack[selectedSweepers[i]])then
					if (toggleStateGot == false)then
						toggleState = SweeperStack[selectedSweepers[i]]:getToggleState()
						toggleStateGot = true
					end
					if (toggleState) then
						SweeperStack[selectedSweepers[i]]:toggleOff()
					else
						SweeperStack[selectedSweepers[i]]:toggleOn()
						SweeperStack[selectedSweepers[i]].default=true
					end
				end
			end
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedSweepers = filterSweepers(selectedUnits)
end

function filterSweepers(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (BadgerUnitDefID == GetUnitDefID(unitID)) then
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
	if selectedSweepers then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdSweepDefault
		customCommands[#customCommands+1] = cmdSweep
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
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==Badger_NAME)  then
			if  (SweeperStack[units[i]]==nil) then
				SweeperStack[units[i]]=SweeperController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end