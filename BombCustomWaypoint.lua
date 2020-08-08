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

local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local circleList

local FactoryStack = {}
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local Echo = Spring.Echo
local Shieldfac_ID = UnitDefNames.factoryshield.id
local Amphfac_ID = UnitDefNames.factoryamph.id
local Jumpfac_ID = UnitDefNames.factoryjump.id
local Cloakfac_ID = UnitDefNames.factorycloak.id
local Gunshipfac_ID = UnitDefNames.factorygunship.id
local Imp_ID = UnitDefNames.cloakbomb.id
local Scuttle_ID = UnitDefNames.jumpbomb.id
local Snitch_ID = UnitDefNames.shieldbomb.id
local Limpet_ID = UnitDefNames.amphbomb.id
local Blastwing_ID = UnitDefNames.gunshipbomb.id
local GetSpecState = Spring.GetSpectatingState
local pi = math.pi
local CMD_STOP = CMD.STOP
local CMD_RAW_MOVE  = 31109
local CMD_FIRE_STATE = CMD.FIRE_STATE
local selectedFactories = nil

local sin = math.sin
local cos = math.cos

local CMD_SET_BOMB_WAYPOINT = 19812

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

local FactoryWaypointControllerMT
local FactoryWaypointController = {
	new = function(index, unitID)
		--Echo("FactoryWaypointController added:" .. unitID)
		local self = {}
		setmetatable(self,FactoryWaypointControllerMT)
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
FactoryWaypointControllerMT = {__index=FactoryWaypointController}

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if not(FactoryStack[builderID]==nil) and FactoryStack[builderID].targetParams~=nil and (unitTeam==GetMyTeamID())then
		if (unitDefID == Scuttle_ID or unitDefID == Snitch_ID or unitDefID.id == Limpet_ID or unitDefID.id == Imp_ID or unitDefID == Blastwing_ID)then
			GiveOrderToUnit(unitID, CMD_RAW_MOVE, {FactoryStack[builderID].targetParams[1], FactoryStack[builderID].targetParams[2], FactoryStack[builderID].targetParams[3]},0)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (unitDefID == Jumpfac_ID or unitDefID == Shieldfac_ID or unitDefID == Amphfac_ID or unitDefID == Cloakfac_ID or unitDefID ==Gunshipfac_ID)
			and (unitTeam==GetMyTeamID() and FactoryStack[unitID]==nil) then
		FactoryStack[unitID] = FactoryWaypointController:new(unitID);
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widget:UnitFinished(unitID, unitDefID, unitTeam)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widget:UnitDestroyed(unitID)
end


function widget:UnitDestroyed(unitID)
	if not (FactoryStack[unitID]==nil) then
		FactoryStack[unitID]=FactoryStack[unitID]:unset();
	end
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
		local unitDefID = GetUnitDefID(unitID)
		if (Cloakfac_ID == unitDefID or Jumpfac_ID == unitDefID or Shieldfac_ID == unitDefID or Amphfac_ID == unitDefID or Gunshipfac_ID == unitDefID) then
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
		widgetHandler:RemoveWidget(widget)
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
		local unitDefID = GetUnitDefID(units[i])
		if (Cloakfac_ID == unitDefID or Jumpfac_ID == unitDefID or Shieldfac_ID == unitDefID or Amphfac_ID == unitDefID or Gunshipfac_ID == unitDefID)  then
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
