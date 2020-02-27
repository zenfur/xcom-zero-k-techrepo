function widget:GetInfo()
	return {
		name      = "ThunderBirdBombardment",
		desc      = "Attempt to make Bombard single position with command. Version 0,5",
		author    = "terve886",
		date      = "2019",
		license   = "PD", -- should be compatible with Spring
		layer     = 2,
		handler		= true, --for adding customCommand into UI
		enabled   = true  --  loaded by default?
	}
end

local UPDATE_FRAME = 50
local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local ceil = math.ceil
local TBStack = {}
local LandingPadCount = 0
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local GetUnitStates = Spring.GetUnitStates
local GetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local GetUnitRulesParam = Spring.GetUnitRulesParam
local ENEMY_DETECT_BUFFER  = 74
local Echo = Spring.Echo
local initDone = false
local Thunderbird_NAME = "bomberdisarm"
local Airfac_NAME = "factoryplane"
local Reef_NAME = "shipcarrier"
local Airpad_NAME = "staticrearm"
local GetSpecState = Spring.GetSpectatingState
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE
local CMD_RAW_MOVE  = 31109
local CMD_REMOVE = CMD.REMOVE
local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL
local CMD_AP_FLY_STATE = 34569
local CMD_DROP_BOMB = 35000

local CMD_TOGGLE_FLIGHT = 145
local CMD_LAND_ATTACK = 19996
local ThunderbirdUnitDefID = UnitDefNames["bomberdisarm"].id
local selectedTHunderbirds = nil

local cmdLandAttack = {
	id      = CMD_LAND_ATTACK,
	type    = CMDTYPE.ICON_MAP,
	tooltip = 'Makes Swift land optimally to fire at target area.',
	cursor  = 'Attack',
	action  = 'reclaim',
	params  = { },
	texture = 'LuaUI/Images/commands/Bold/dgun.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}


local landAttackController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	targetParams,
	landAttackOn = false,
	creationSpot,


	new = function(self, unitID)
		--Echo("landAttackController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		self.creationSpot = self.pos
		return self
	end,

	unset = function(self)
		--Echo("LandController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	setTargetParams = function (self, params)
		self.targetParams = params
	end,

	landAttack = function(self)
		self.landAttackOn = true
		GiveOrderToUnit(self.unitID, CMD_TOGGLE_FLIGHT, 1, {""}, 0)
		GiveOrderToUnit(self.unitID,CMD_INSERT, {1, CMD_RAW_MOVE, CMD_OPT_SHIFT,self.targetParams[1], self.targetParams[2], self.targetParams[3]}, {"alt"})
		GiveOrderToUnit(self.unitID,CMD_INSERT, {2, CMD_DROP_BOMB, CMD_OPT_SHIFT}, {"alt"})
		--
	end
}

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for unitID,TB in pairs(TBStack) do
			ammoState = GetUnitRulesParam(unitID, "noammo")
			if (TB.landAttackOn==true and ammoState==1)then
				TB.landAttackOn=false
				GiveOrderToUnit(unitID, CMD_TOGGLE_FLIGHT, 0, {""}, 0)
				Echo(LandingPadCount)
				if(LandingPadCount==0)then
					GiveOrderToUnit(unitID,CMD_INSERT, {1, CMD_RAW_MOVE, CMD_OPT_SHIFT,TB.creationSpot[1], TB.creationSpot[2], TB.creationSpot[3]}, {"alt"})
				end
			end
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Thunderbird_NAME)
			and (unitTeam==GetMyTeamID()) then
		TBStack[unitID] = landAttackController:new(unitID);
	end
	if ((UnitDefs[unitDefID].name==Airfac_NAME or UnitDefs[unitDefID].name==Airpad_NAME or UnitDefs[unitDefID].name==Reef_NAME)
			and (unitTeam==GetMyTeamID())) then
		LandingPadCount = LandingPadCount+1
	end
end

function widget:UnitDestroyed(unitID)
	if not (TBStack[unitID]==nil) then
		TBStack[unitID]=TBStack[unitID]:unset();
	end
	DefID = GetUnitDefID(unitID)
	if ((UnitDefs[DefID].name==Airfac_NAME or UnitDefs[DefID].name==Airpad_NAME or UnitDefs[DefID].name==Reef_NAME)
			and (GetUnitAllyTeam(unitID)==GetMyTeamID())) then
		LandingPadCount = LandingPadCount-1
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
	if selectedTHunderbirds ~= nil then
		if (cmdID == CMD_LAND_ATTACK and #params == 3)then
			for i=1, #selectedTHunderbirds do
				if(TBStack[selectedTHunderbirds[i]])then
					ammoState = GetUnitRulesParam(selectedTHunderbirds[i], "noammo")
					if (ammoState==0 or ammoState==nil)then
						TBStack[selectedTHunderbirds[i]]:setTargetParams(params)
						TBStack[selectedTHunderbirds[i]]:landAttack()
					end
				end
			end
			return true
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedTHunderbirds = filterPuppies(selectedUnits)
end

function filterPuppies(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (ThunderbirdUnitDefID == GetUnitDefID(unitID)) then
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
	if selectedTHunderbirds then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdLandAttack
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
		if (UnitDefs[DefID].name==Thunderbird_NAME)  then
			if  (TBStack[unitID]==nil) then
				TBStack[unitID]=landAttackController:new(unitID)
			end
		end
		if (UnitDefs[DefID].name==Airfac_NAME or UnitDefs[DefID].name==Airpad_NAME or UnitDefs[DefID].name==Reef_NAME)then
			LandingPadCount = LandingPadCount+1
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
