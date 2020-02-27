function widget:GetInfo()
   return {
      name         = "TargettingAI_Dominatrix",
      desc         = "attempt to make Dominatrix not fire Razors, metal extractors, solars and wind generators without order. Meant to be used with return fire state. Version 0,87",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 11,
      enabled      = true
   }
end


local UPDATE_FRAME=4
local DominatrixStack = {}
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
local GetUnitHealth = Spring.GetUnitHealth
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local ENEMY_DETECT_BUFFER  = 40
local Echo = Spring.Echo
local Dominatrix_NAME = "vehcapture"
local Solar_NAME = "energysolar"
local Wind_NAME = "energywind"
local Razor_NAME = "turretaalaser"
local Metal_NAME = "staticmex"
local Dirtbag_NAME = "shieldscout"
local Flea_NAME = "spiderscout"
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK



local DominatrixController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	forceTarget,
	
	
	new = function(self, unitID)
		--Echo("DominatrixController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("DominatrixController removed:" .. self.unitID)
		self.alive = false
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	setForceTarget = function(self, param)
		self.forceTarget = param[1]
	end,
	
	isEnemyInRange = function (self)
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range+ENEMY_DETECT_BUFFER)
		local target = nil
		local targetMaxHealth = nil
		local targetMaxHealth = nil
		local targetMaxHealth = nil
		for i=1, #units do
			if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then
			
				if (units[i]==self.forceTarget and GetUnitIsDead(units[i]) == false)then
					GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
					return true
				end
				DefID = GetUnitDefID(units[i])
				if not(DefID == nil)then
					local enemyHealthStats = {GetUnitHealth(units[i])}
					local enemyBuildProgress = enemyHealthStats[5]
					
					if  (enemyBuildProgress and GetUnitIsDead(units[i]) == false and enemyBuildProgress >=0.80 and
					not(UnitDefs[DefID].name == Solar_NAME 
					or UnitDefs[DefID].name == Wind_NAME 
					or UnitDefs[DefID].name == Flea_NAME 
					or UnitDefs[DefID].name == Dirtbag_NAME 
					or UnitDefs[DefID].name == Metal_NAME)) then
					
						local enemyMaxHealth = enemyHealthStats[2]
						local enemyRemainingHealth = enemyHealthStats[1]
						local enemyCaptureProgress = enemyHealthStats[4]
						if (enemyCaptureProgress==0)then
							enemyRemainingHealth = enemyRemainingHealth+200
						end
						if (target == nil) then
							target = units[i]
							targetMaxHealth = enemyMaxHealth
							targetRemainingHealth = enemyRemainingHealth
							targetCaptureProgress = enemyCaptureProgress
						elseif(targetCaptureProgress 
						and targetRemainingHealth*(2-targetCaptureProgress)*(2+targetRemainingHealth/targetMaxHealth)/UnitDefs[GetUnitDefID(target)].metalCost 
						   > enemyRemainingHealth*(2-enemyCaptureProgress)*(2+enemyRemainingHealth/enemyMaxHealth)/UnitDefs[DefID].metalCost)then
							target = units[i]
							targetMaxHealth = enemyMaxHealth
							targetRemainingHealth = enemyRemainingHealth
							targetCaptureProgress = enemyCaptureProgress
						end
						
					end
				end
			end
		end
		if (target == nil) then
			GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
			return false
		else
			GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, target, 0)
			return true
		end
	end,
	
	handle=function(self)
		if(GetUnitStates(self.unitID).firestate==1)then
			self.pos = {GetUnitPosition(self.unitID)}
			self:isEnemyInRange()
		end
	end
}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (UnitDefs[unitDefID].name == Dominatrix_NAME and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (DominatrixStack[unitID])then
			DominatrixStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Dominatrix_NAME)
		and (unitTeam==GetMyTeamID()) then
			DominatrixStack[unitID] = DominatrixController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID) 
	if not (DominatrixStack[unitID]==nil) then
		DominatrixStack[unitID]=DominatrixStack[unitID]:unset();
	end
end

function widget:GameFrame(n) 
	if (n%UPDATE_FRAME==0) then
		for _,Dominatrix in pairs(DominatrixStack) do 
			Dominatrix:handle()
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
		if (UnitDefs[DefID].name==Dominatrix_NAME)  then
			if  (DominatrixStack[units[i]]==nil) then
				DominatrixStack[units[i]]=DominatrixController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end

