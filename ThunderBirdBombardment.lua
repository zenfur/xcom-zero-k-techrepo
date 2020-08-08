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
local TBStack = {}
local LandingPadCount = 0
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitRulesParam = Spring.GetUnitRulesParam
local Echo = Spring.Echo
local Thunderbird_ID = UnitDefNames.bomberdisarm.id
local Airfac_ID = UnitDefNames.factoryplane.id
local Reef_ID = UnitDefNames.shipcarrier.id
local Airpad_ID = UnitDefNames.staticrearm.id
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_RAW_MOVE  = 31109
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


local landAttackControllerMT
local landAttackController = {
	unitID,
	pos,
	range,
	targetParams,
	landAttackOn = false,
	creationSpot,


	new = function(index, unitID)
		--Echo("landAttackController added:" .. unitID)
		local self = {}
		setmetatable(self, landAttackControllerMT)
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
landAttackControllerMT = {__index = landAttackController}

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for unitID,TB in pairs(TBStack) do
			local ammoState = GetUnitRulesParam(unitID, "noammo")
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
	if (unitDefID == Thunderbird_ID)
			and (unitTeam==GetMyTeamID()) then
		TBStack[unitID] = landAttackController:new(unitID);
	end
	if ((unitDefID == Airfac_ID or unitDefID == Airpad_ID or unitDefID == Reef_ID)
			and (unitTeam==GetMyTeamID())) then
		LandingPadCount = LandingPadCount+1
	end
end

function widget:UnitDestroyed(unitID)
	if not (TBStack[unitID]==nil) then
		TBStack[unitID]=TBStack[unitID]:unset();
	end
	local unitDefID = GetUnitDefID(unitID)
	if ((unitDefID == Airfac_ID or unitDefID == Airpad_ID or unitDefID == Reef_ID)
			and (GetUnitAllyTeam(unitID)==GetMyTeamID())) then
		LandingPadCount = LandingPadCount-1
	end
end

--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedTHunderbirds ~= nil then
		if (cmdID == CMD_LAND_ATTACK and #params == 3)then
			for i=1, #selectedTHunderbirds do
				if(TBStack[selectedTHunderbirds[i]])then
					local ammoState = GetUnitRulesParam(selectedTHunderbirds[i], "noammo")
					if (ammoState==nil or ammoState == 0)then
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
	selectedTHunderbirds = filterSelection(selectedUnits)
end

function filterSelection(units)
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
		widgetHandler:RemoveWidget(widget)
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(GetMyTeamID())
	for i=1, #units do
		local unitID = units[i]
		local unitDefID = GetUnitDefID(unitID)
		if (unitDefID == Thunderbird_ID)  then
			if  (TBStack[unitID]==nil) then
				TBStack[unitID]=landAttackController:new(unitID)
			end
		end
		if (unitDefID == Airfac_ID or unitDefID == Airpad_ID or unitDefID == Reef_ID)then
			LandingPadCount = LandingPadCount+1
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
