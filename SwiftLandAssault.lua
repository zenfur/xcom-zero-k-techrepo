function widget:GetInfo()
   return {
    name      = "SwiftLandAssault",
    desc      = "Attempt to make Swift land optimally to fire on target area with command. Version 0,5",
    author    = "terve886",
    date      = "2019",
    license   = "PD", -- should be compatible with Spring
    layer     = 2,
	handler		= true, --for adding customCommand into UI
    enabled   = true  --  loaded by default?
  }
end

local sin = math.sin
local cos = math.cos
local atan = math.atan
local SwiftStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local Echo = Spring.Echo
local Swift_ID = UnitDefNames.planefighter.id
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_MOVE = CMD.MOVE
local CMD_RAW_MOVE  = 31109

local CMD_TOGGLE_FLIGHT = 145
local CMD_LAND_ATTACK = 19996
local SwiftUnitDefID = UnitDefNames["planefighter"].id
local selectedSwifts = nil

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

local landAttackControllerMT
local landAttackController = {
	unitID,
	pos,
	range,
	targetParams,


	new = function(index, unitID)
		--Echo("landAttackController added:" .. unitID)
		local self = {}
		setmetatable(self, landAttackControllerMT)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
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
	self.pos = {GetUnitPosition(self.unitID)}
	local rotation = atan((self.pos[1]-self.targetParams[1])/(self.pos[3]-self.targetParams[3]))
		local targetPosRelative={
			sin(rotation) * (self.range-40),
			nil,
			cos(rotation) * (self.range-40),
		}

		local targetPosAbsolute = {}

		if (self.pos[3]<=self.targetParams[3]) then
			targetPosAbsolute = {
				self.targetParams[1]-targetPosRelative[1],
				nil,
				self.targetParams[3]-targetPosRelative[3],
			}

		else
			targetPosAbsolute = {
				self.targetParams[1]+targetPosRelative[1],
				nil,
				self.targetParams[3]+targetPosRelative[3],
			}

		end
		targetPosAbsolute[2] = GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
		GiveOrderToUnit(self.unitID, CMD_TOGGLE_FLIGHT, 1, {""}, 0)
		GiveOrderToUnit(self.unitID, CMD_MOVE, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
	end
}
landAttackControllerMT = {__index = landAttackController}


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (unitDefID == Swift_ID)
	and (unitTeam==GetMyTeamID()) then
		SwiftStack[unitID] = landAttackController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (SwiftStack[unitID]==nil) then
		SwiftStack[unitID]=SwiftStack[unitID]:unset();
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (cmdID == CMD_RAW_MOVE and unitDefID == Swift_ID) then
		if (SwiftStack[unitID]) then
			GiveOrderToUnit(unitID, CMD_TOGGLE_FLIGHT, 0, {""}, 0)
			return
		end
	end
end

--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedSwifts ~= nil then
		if (cmdID == CMD_LAND_ATTACK and #params == 3)then
			for i=1, #selectedSwifts do
				if(SwiftStack[selectedSwifts[i]])then
					SwiftStack[selectedSwifts[i]]:setTargetParams(params)
					SwiftStack[selectedSwifts[i]]:landAttack()
				end
			end
			return true
		else
			for i=1, #selectedSwifts do
				if(SwiftStack[selectedSwifts[i]])then
					GiveOrderToUnit(selectedSwifts[i], CMD_TOGGLE_FLIGHT, 0, {""}, 0)
				end
			end
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedSwifts = filterPuppies(selectedUnits)
end

function filterPuppies(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (SwiftUnitDefID == GetUnitDefID(unitID)) then
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
	if selectedSwifts then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdLandAttack
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
		if (unitDefID == Swift_ID)  then
			if  (SwiftStack[unitID]==nil) then
				SwiftStack[unitID]=landAttackController:new(unitID)
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
