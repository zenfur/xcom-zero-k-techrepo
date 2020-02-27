function widget:GetInfo()
   return {
      name         = "CrabCoverAI",
      desc         = "attempt to Crab cover upon aproaching bombing. Version 1.1",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 10,
      enabled      = true
   }
end
local UPDATE_FRAME=10
local CrabStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local IsUnitSelected = Spring.IsUnitSelected
local GetTeamUnits = Spring.GetTeamUnits
local Echo = Spring.Echo
local Crab_NAME = "spidercrabe"
local Raven_NAME = "bomberprec"
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_MOVE = CMD.MOVE
local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL
local CMD_RAW_MOVE  = 31109
local CMD_MOVE_ID = 10

local CrabAI = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	moveTarget,
	enemyClose = false,

	
	new = function(self, unitID)
		--Echo("CrabAI added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		self.moveTarget = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("CrabAI removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	setMoveTarget = function(self, params)
		self.moveTarget = params
		Echo("move params updated")
		self.enemyClose = false
	end,
	
	cancelMoveTarget = function(self)
		self.moveTarget = {GetUnitPosition(self.unitID)}
		Echo("movement cancelled")
	end,
	
	isEnemyInRange = function (self)
		self.pos = {GetUnitPosition(self.unitID)}
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range)
		for i=1, #units do
			if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				DefID = GetUnitDefID(units[i])
				if not(DefID == nil)then
					if  (GetUnitIsDead(units[i]) == false and UnitDefs[DefID].isBuilding == false) then
						if(IsUnitSelected(self.unitID) == false or UnitDefs[DefID].name==Raven_NAME) then
							if (self.enemyClose)then
								return true
							end
							GiveOrderToUnit(self.unitID,CMD_MOVE, self.pos, CMD_OPT_INTERNAL)
							self.enemyClose = true
							return true
						end
					end
				end
			end
		end
		if (self.enemyClose)then
			GiveOrderToUnit(self.unitID,CMD_MOVE, self.moveTarget, CMD_OPT_INTERNAL)
		end
		self.enemyClose = false
		return false
	end,
	
	
	handle = function(self)
		self:isEnemyInRange()
	end
}

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Crab_NAME)
		and (unitTeam==GetMyTeamID()) then
			CrabStack[unitID] = CrabAI:new(unitID);
		end
end

function widget:UnitDestroyed(unitID)
	if not (CrabStack[unitID]==nil) then
		CrabStack[unitID]=CrabStack[unitID]:unset();
	end
end

function widget:GameFrame(n) 
	if (n%UPDATE_FRAME==0) then
		for _,crab in pairs(CrabStack) do
			crab:handle()
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
	if (cmdID == CMD_RAW_MOVE  and #cmdParams == 3 and UnitDefs[unitDefID].name == Crab_NAME) then
		if (CrabStack[unitID]) then
			CrabStack[unitID]:setMoveTarget(cmdParams)
			return
		end
	end
	if (not(cmdID == CMD_MOVE_ID or cmdID == 2 or cmdID ==1) and UnitDefs[unitDefID].name == Crab_NAME) then
		if (CrabStack[unitID]) then
			CrabStack[unitID]:cancelMoveTarget()
		end
	end
end

function widget:CommandNotify(cmdID, params, options)
	if selectedUnits ~= nil then
		if (cmdID == CMD_SINGLE_ATTACK and (#params == 3 or #params == 1))then
			for i=1, #selectedUnits do
				if (UnitStack[selectedUnits[i]])then
					UnitStack[selectedUnits[i]]:setTargetParams(params)
					UnitStack[selectedUnits[i]]:singleAttack()
				end
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
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==Crab_NAME)  then
			if  (CrabStack[units[i]]==nil) then
				CrabStack[units[i]]=CrabAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
