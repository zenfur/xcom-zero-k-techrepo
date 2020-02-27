function widget:GetInfo()
	return {
		name      = "RavenMexHunter",
		desc      = "Attempt to make Ravens target mexes on AttackMove. Version 0,5",
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
local currentFrame = 0
local UPDATE_FRAME=5
local RavenStack = {}
local MexTargetStack = {}
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
local GetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local GetUnitWeaponState = Spring.GetUnitWeaponState
local GetUnitRulesParam = Spring.GetUnitRulesParam
local GetUnitFuel = Spring.GetUnitFuel
local ENEMY_DETECT_BUFFER  = 74
local Echo = Spring.Echo
local initDone = false
local Raven_NAME = "bomberprec"
local Metal_NAME = "staticmex"
local GetSpecState = Spring.GetSpectatingState
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_ATTACK = CMD.ATTACK
local CMD_ATTACK_MOVE = 16
local CMD_MOVE = CMD.MOVE
local CMD_RAW_MOVE  = 31109
local CMD_REMOVE = CMD.REMOVE
local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL
local CMD_AP_FLY_STATE = 34569
local selectedRavens = nil
local RavenUnitDefID = UnitDefNames["bomberprec"].id



local MexHuntController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	target,
	hunting = false,
	initilised = false,


	new = function(self, unitID)
		--Echo("MexHuntController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("MexHuntController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		if(MexTargetStack[self.target]~=nil)then
			MexTargetStack[self.target]=nil
		end
		return nil
	end,



	handle = function(self)
		ammoState = GetUnitRulesParam(self.unitID, "noammo")
		if (self.hunting and (ammoState==0 or ammoState==nil))then
			self.pos = {GetUnitPosition(self.unitID)}
			local units = GetUnitsInCylinder(self.pos[1], self.pos[3], 600)
			for i=1, #units do
				if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then
					DefID = GetUnitDefID(units[i])
					if not(DefID == nil)then
						if  (GetUnitIsDead(units[i]) == false)then
							if(UnitDefs[DefID].name == Metal_NAME)then
								if (MexTargetStack[units[i]]==nil)then
									GiveOrderToUnit(self.unitID, CMD_ATTACK, {units[i]}, 0)
									--Echo("set target")
									MexTargetStack[units[i]]=units[i]
									self.hunting = false
									self.target = units[i]
									return
								end
							end
						end
					end
				end
			end
		end
	end
}


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Raven_NAME)
			and (unitTeam==GetMyTeamID()) then
		RavenStack[unitID] = MexHuntController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (RavenStack[unitID]==nil) then
		RavenStack[unitID]=RavenStack[unitID]:unset();
	end
	if not (MexTargetStack[unitID]==nil) then
		MexTargetStack[unitID]=nil;
	end
end

function widget:GameFrame(n)
	currentFrame = n
	if (n%UPDATE_FRAME==0) then
		for unitID,raven in pairs(RavenStack) do
			raven:handle()
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

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (UnitDefs[unitDefID].name == Raven_NAME) then
		if (cmdID == CMD_ATTACK_MOVE) then
			if (RavenStack[unitID]) then
				if(RavenStack[unitID].target)then
					RavenStack[unitID].target=nil
				end
				RavenStack[unitID].hunting=true
				return
			end
		end
		if(cmdID == CMD_STOP or cmdID == CMD_RAW_MOVE)then
			if(RavenStack[unitID])then
				RavenStack[unitID].hunting=false
				if (MexTargetStack[RavenStack[unitID].target])then
					MexTargetStack[RavenStack[unitID].target]=nil
				end
			end
		end
	end
end

--- COMMAND HANDLING



function widget:SelectionChanged(selectedUnits)
	selectedRavens = filterRavens(selectedUnits)
end

function filterRavens(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (RavenUnitDefID == GetUnitDefID(unitID)) then
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
		if (UnitDefs[DefID].name==Raven_NAME)  then
			if  (RavenStack[unitID]==nil) then
				RavenStack[unitID]=MexHuntController:new(unitID)
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
