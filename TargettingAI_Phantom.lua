function widget:GetInfo()
   return {
      name         = "TargettingAI_Phantom",
      desc         = "attempt to make Phantom not fire Razors, metal extractors, solars and wind generators without order. Meant to be used with return fire state. Version 0,87",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 11,
      enabled      = true
   }
end


local UPDATE_FRAME=4
local PhantomStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitArmored = Spring.GetUnitArmored
local GetUnitStates = Spring.GetUnitStates
local IsUnitInLos = Spring.IsUnitInLos
local ENEMY_DETECT_BUFFER  = 40
local Echo = Spring.Echo
local Phantom_NAME = "cloaksnipe"
local Razor_NAME = "turretaalaser"
local Halbert_NAME = "hoverassault"
local Gauss_NAME = "turretgauss"
local Faraday_NAME = "turretemp"
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK



local PhantomController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	forceTarget,
	
	
	new = function(self, unitID)
		--Echo("PhantomController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("PhantomController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	setForceTarget = function(self, param)
		self.forceTarget = param[1]
	end,
	

	isEnemyTooClose = function (self)
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], 300)
		for i=1, #units do
			if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				DefID = GetUnitDefID(units[i])
				if not(DefID == nil)then
					enemyPosition = {GetUnitPosition(units[i])}
					if(enemyPosition[2]>-30)then
						if  (GetUnitIsDead(units[i]) == false) then
							local hasArmor = GetUnitArmored(units[i])
							if not((UnitDefs[DefID].name == Razor_NAME 
							or UnitDefs[DefID].name == Gauss_NAME 
							or UnitDefs[DefID].name == Faraday_NAME 
							or UnitDefs[DefID].name == Halbert_NAME) and hasArmor) then
								GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
								return true
							end
						end
					end
				end
			end
		end
		return false
	end,

	isEnemyInRange = function (self)
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range+ENEMY_DETECT_BUFFER)
		local target = nil
		for i=1, #units do
			if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				enemyPosition = {GetUnitPosition(units[i])}
				if(enemyPosition[2]>-30)then
					if (units[i]==self.forceTarget and GetUnitIsDead(units[i]) == false)then
						GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
						return true
					end

					DefID = GetUnitDefID(units[i])
					if not(DefID == nil)then
						if(IsUnitInLos(units[i]))then --Radar dots always return armor state as false
							if  (GetUnitIsDead(units[i]) == false)then
								local hasArmor = GetUnitArmored(units[i])
								if  (UnitDefs[DefID].metalCost >= 200 and
										not((UnitDefs[DefID].name == Razor_NAME
												or UnitDefs[DefID].name == Gauss_NAME
												or UnitDefs[DefID].name == Faraday_NAME
												or UnitDefs[DefID].name == Halbert_NAME) and hasArmor)) then
									if (target == nil) then
										target = units[i]
									end
									if (UnitDefs[GetUnitDefID(target)].metalCost < UnitDefs[DefID].metalCost)then
										target = units[i]
									end
								end
							end
						else
							if  (GetUnitIsDead(units[i]) == false)then
								if  (UnitDefs[DefID].metalCost >= 200 and
										not((UnitDefs[DefID].name == Razor_NAME
												or UnitDefs[DefID].name == Gauss_NAME
												or UnitDefs[DefID].name == Faraday_NAME
												or UnitDefs[DefID].name == Halbert_NAME))) then
									if (target == nil) then
										target = units[i]
									end
									if (UnitDefs[GetUnitDefID(target)].metalCost < UnitDefs[DefID].metalCost)then
										target = units[i]
									end
								end
							end
						end
					end
				end
			end
		end
		if (target == nil) then
			GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
		else
			GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, target, 0)
		end
	end,
	
	handle=function(self)
		if(GetUnitStates(self.unitID).firestate==1)then
			self.pos = {GetUnitPosition(self.unitID)}
			if not(self:isEnemyTooClose())then
				self:isEnemyInRange()
			end
		end
	end
}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (UnitDefs[unitDefID].name == Phantom_NAME and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (PhantomStack[unitID])then
			PhantomStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Phantom_NAME)
		and (unitTeam==GetMyTeamID()) then
			PhantomStack[unitID] = PhantomController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID) 
	if not (PhantomStack[unitID]==nil) then
		PhantomStack[unitID]=PhantomStack[unitID]:unset();
	end
end

function widget:GameFrame(n) 
	if (n%UPDATE_FRAME==0) then
		for _,Phantom in pairs(PhantomStack) do 
			Phantom:handle()
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
		if (UnitDefs[DefID].name==Phantom_NAME)  then
			if  (PhantomStack[units[i]]==nil) then
				PhantomStack[units[i]]=PhantomController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
