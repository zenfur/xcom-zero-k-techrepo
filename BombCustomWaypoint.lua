function widget:GetInfo()
	return {
		name         = "BombCustomWaypoint",
		desc         = "Adds command to factories with kamikaze units to make them go to another waypoint. Version 1,06",
		author       = "terve886",
		date         = "2020",
		license      = "PD", -- should be compatible with Spring
		layer        = 11,
		handler		= true, --for adding customCommand into UI
		enabled      = true
	}
end

local GL_LINE_STRIP = GL.LINE_STRIP
local glLineWidth = gl.LineWidth
local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local circleList

local FactoryStack = {}
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
local Shieldfac_NAME = "factoryshield"
local Amphfac_NAME = "factoryamph"
local Jumpfac_NAME = "factoryjump"
local Cloakfac_NAME = "factorycloak"
local Gunshipfac_NAME = "factorygunship"
local Imp_NAME = "cloakbomb"
local Scuttle_NAME = "jumpbomb"
local Snitch_NAME = "shieldbomb"
local Limpet_NAME = "amphbomb"
local Blastwing_NAME = "gunshipbomb"
local ENEMY_DETECT_BUFFER  = 40
local GetSpecState = Spring.GetSpectatingState
local pi = math.pi
local FULL_CIRCLE_RADIANT = 2 * pi
local HEADING_TO_RAD = (pi*2/65536 )
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_MOVE = CMD.MOVE
local CMD_RAW_MOVE  = 31109
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_UNIT_AI = 36214
local selectedFactories = nil

local sin = math.sin
local cos = math.cos
local atan = math.atan

local CMD_SET_BOMB_WAYPOINT = 19812
local ShieldfacUnitDefID = UnitDefNames["factoryshield"].id
local CloakfacUnitDefID = UnitDefNames["factorycloak"].id
local AmphfacUnitDefID = UnitDefNames["factoryamph"].id
local JumpfacUnitDefID = UnitDefNames["factoryjump"].id
local GunshipfacUnitDefID = UnitDefNames["factorygunship"].id

local cmdSetBombWayPoint = {
	id      = CMD_SET_BOMB_WAYPOINT,
	type    = CMDTYPE.ICON_MAP,
	tooltip = 'Set custom waypoint for bomb units.',
	cursor  = 'Target',
	action  = 'reclaim',
	params  = { },
	texture = 'LuaUI/Images/commands/Bold/wait_death.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}


local FactoryWaypointController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	targetParams = nil,




	new = function(self, unitID)
		--Echo("FactoryWaypointController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,


	unset = function(self)
		--Echo("FactoryWaypointController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,


	setTargetParams = function (self, params)
		self.targetParams = params
	end
}

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if not(FactoryStack[builderID]==nil) and FactoryStack[builderID].targetParams~=nil and (unitTeam==GetMyTeamID())then
		if (UnitDefs[unitDefID].name==Scuttle_NAME or UnitDefs[unitDefID].name==Snitch_NAME or UnitDefs[unitDefID].name==Limpet_NAME or UnitDefs[unitDefID].name==Imp_NAME or UnitDefs[unitDefID].name==Blastwing_NAME)then
			GiveOrderToUnit(unitID, CMD_RAW_MOVE, {FactoryStack[builderID].targetParams[1], FactoryStack[builderID].targetParams[2], FactoryStack[builderID].targetParams[3]},0)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Jumpfac_NAME or UnitDefs[unitDefID].name==Shieldfac_NAME or UnitDefs[unitDefID].name==Amphfac_NAME or UnitDefs[unitDefID].name==Cloakfac_NAME or UnitDefs[unitDefID].name==Gunshipfac_NAME)
			and (unitTeam==GetMyTeamID() and FactoryStack[unitID]==nil) then
		FactoryStack[unitID] = FactoryWaypointController:new(unitID);
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	if (UnitDefs[unitDefID].name==Jumpfac_NAME or UnitDefs[unitDefID].name==Shieldfac_NAME or UnitDefs[unitDefID].name==Amphfac_NAME or UnitDefs[unitDefID].name==Cloakfac_NAME or UnitDefs[unitDefID].name==Gunshipfac_NAME)
			and (unitTeam==GetMyTeamID() and FactoryStack[unitID]==nil) then
		FactoryStack[unitID] = FactoryWaypointController:new(unitID);
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if (UnitDefs[unitDefID].name==Jumpfac_NAME or UnitDefs[unitDefID].name==Shieldfac_NAME or UnitDefs[unitDefID].name==Amphfac_NAME or UnitDefs[unitDefID].name==Cloakfac_NAME or UnitDefs[unitDefID].name==Gunshipfac_NAME)
			and (unitTeam==GetMyTeamID() and FactoryStack[unitID]==nil) then
		FactoryStack[unitID] = FactoryWaypointController:new(unitID);
	end
end


function widget:UnitDestroyed(unitID)
	if not (FactoryStack[unitID]==nil) then
		FactoryStack[unitID]=FactoryStack[unitID]:unset();
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
	if selectedFactories ~= nil then
		if (cmdID == CMD_SET_BOMB_WAYPOINT)then
			for i=1, #selectedFactories do
				if (FactoryStack[selectedFactories[i]])then
					FactoryStack[selectedFactories[i]]:setTargetParams(params)
				end
			end
			return true
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedFactories = filterFactories(selectedUnits)
end

function filterFactories(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (CloakfacUnitDefID == GetUnitDefID(unitID) or JumpfacUnitDefID == GetUnitDefID(unitID) or ShieldfacUnitDefID == GetUnitDefID(unitID) or AmphfacUnitDefID == GetUnitDefID(unitID) or GunshipfacUnitDefID == GetUnitDefID(unitID)) then
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
	if selectedFactories then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdSetBombWayPoint
	end
end

function widget:DrawWorld()

	------Crash location estimator---
	for unitID, Unit in pairs (FactoryStack) do
		if (Unit.targetParams~=nil)then
			local numAoECircles = 5
			local aoe = 50
			local alpha = 0.75
			for i=1,numAoECircles do   --Reference: draw a AOE rings , gui_attack_aoe.lua by Evil4Zerggin
				local proportion = (i/(numAoECircles + 1))
				local radius = aoe * proportion
				local alphamult = alpha*(1-proportion)
				glColor(0, 4, 4,alphamult)
				gl.PushMatrix()
				gl.Translate(Unit.targetParams[1],Unit.targetParams[2],Unit.targetParams[3])
				gl.Scale(radius, radius, radius)
				gl.CallList(circleList)
				gl.PopMatrix()
			end
		end
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


	local circleVertex = function()
		local circleDivs, PI = 64 , pi
		for i = 1, circleDivs do
			local theta = 2 * PI * i / circleDivs
			glVertex(cos(theta), 0, sin(theta))
		end
	end
	local circleDraw = 	function() glBeginEnd(GL.LINE_LOOP, circleVertex ) end --Reference: draw a circle , gui_attack_aoe.lua by Evil4Zerggin
	circleList = gl.CreateList(circleDraw)


	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==Jumpfac_NAME or UnitDefs[DefID].name==Shieldfac_NAME or UnitDefs[DefID].name==Amphfac_NAME or UnitDefs[DefID].name==Cloakfac_NAME or UnitDefs[DefID].name==Gunshipfac_NAME)  then
			if  (FactoryStack[units[i]]==nil) then
				FactoryStack[units[i]]=FactoryWaypointController:new(units[i])
			end
		end
	end
end

function widget:Shutdown()
	if circleList then
		gl.DeleteList(circleList)
	end
end

function widget:PlayerChanged (playerID)
	DisableForSpec()
end