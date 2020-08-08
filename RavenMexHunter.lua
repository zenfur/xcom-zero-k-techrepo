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

local UPDATE_FRAME=5
local RavenStack = {}
local MexTargetStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitIsDead = Spring.GetUnitIsDead
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitRulesParam = Spring.GetUnitRulesParam
local Echo = Spring.Echo
local Raven_ID = UnitDefNames.bomberprec.id
local Metal_ID = UnitDefNames.staticmex.id
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK
local CMD_ATTACK_MOVE = 16
local CMD_RAW_MOVE  = 31109


local MexHuntControllerMT
local MexHuntController = {
	unitID,
	pos,
	target,
	hunting = false,
	initilised = false,


	new = function(index, unitID)
		--Echo("MexHuntController added:" .. unitID)
		local self = {}
		setmetatable(self,MexHuntControllerMT)
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

<<<<<<< HEAD


	handle = function(self)
		local ammoState = GetUnitRulesParam(self.unitID, "noammo")
		if (self.hunting and (ammoState==0 or ammoState==nil))then
			self.pos = {GetUnitPosition(self.unitID)}
			local units = GetUnitsInCylinder(self.pos[1], self.pos[3], 600, Spring.ENEMY_UNITS)
			for i=1, #units do
				local unitDefID = GetUnitDefID(units[i])
				if not(unitDefID == nil)then
					if (GetUnitIsDead(units[i]) == false)then
						if(unitDefID == Metal_ID)then
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
}


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (unitDefID == Raven_ID)
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
	if (n%UPDATE_FRAME==0) then
		for unitID,raven in pairs(RavenStack) do
			raven:handle()
		end
	end
end
MexHuntControllerMT = {__index=MexHuntController}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (unitDefID == Raven_ID) then
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
		if (unitDefID == Raven_ID)  then
			if  (RavenStack[unitID]==nil) then
				RavenStack[unitID]=MexHuntController:new(unitID)
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
