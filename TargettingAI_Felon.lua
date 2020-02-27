function widget:GetInfo()
   return {
      name         = "TargettingAI_Felon",
      desc         = "attempt to make Felon not fire Razors, solars and most high hp assaults without order. Meant to be used with return fire state. Version 1.00",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 11,
      enabled      = true
   }
end

local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local sqrt = math.sqrt
local UPDATE_FRAME=4
local FelonStack = {}
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
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitArmored = Spring.GetUnitArmored
local GetUnitStates = Spring.GetUnitStates
local ENEMY_DETECT_BUFFER  = 4
local Echo = Spring.Echo
local Felon_NAME = "shieldfelon"
local Solar_NAME = "energysolar"
local Razor_NAME = "turretaalaser"
local Minotaur_NAME = "tankassault"
local Cyclops_NAME = "tankheavyassault"
local Dirtbag_NAME = "shieldscout"
local Halbert_NAME = "hoverassault"
local Jack_NAME = "jumpassault"
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK
local CMD_REMOVE = CMD.REMOVE



local FelonController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	damage,
	forceTarget,

	
	
	new = function(self, unitID)
		--Echo("FelonController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		local unitDefID = GetUnitDefID(self.unitID)
		local weaponDefID = UnitDefs[unitDefID].weapons[1].weaponDef
		local wd = WeaponDefs[weaponDefID]
		self.damage = wd.damages[4]
		return self
	end,

	unset = function(self)
		--Echo("FelonController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	setForceTarget = function(self, param)
		self.forceTarget = param[1]
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
						local hasArmor = GetUnitArmored(units[i])
						if  (GetUnitIsDead(units[i]) == false)then
							local hasArmor = GetUnitArmored(units[i])
							if not(UnitDefs[DefID].name == Solar_NAME 
							or UnitDefs[DefID].name == Dirtbag_NAME
							or UnitDefs[DefID].name == Minotaur_NAME
							or UnitDefs[DefID].name == Cyclops_NAME
							or (UnitDefs[DefID].name == Halbert_NAME and hasArmor)
							or UnitDefs[DefID].name == Razor_NAME and hasArmor) then
								if (target == nil) then
									target = units[i]
								end
								if (UnitDefs[GetUnitDefID(target)].metalCost > UnitDefs[DefID].metalCost)then
									target = units[i]
								end
							end
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
	
	isShieldInEffectiveRange = function (self)
		closestShieldID = nil
		closestShieldDistance = nil
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+320)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				DefID = GetUnitDefID(units[i])
				if not(DefID == nil)then
					if (GetUnitIsDead(units[i]) == false and UnitDefs[DefID].hasShield == true) then
						local shieldHealth = {GetUnitShieldState(units[i])}
						if (shieldHealth[2] and self.damage <= shieldHealth[2])then
							local enemyPositionX, enemyPositionY, enemyPositionZ = GetUnitPosition(units[i])
							
							local targetShieldRadius
							if (UnitDefs[DefID].weapons[2] == nil)then
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[1].weaponDef].shieldRadius
							else
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[2].weaponDef].shieldRadius
							end
							
							enemyShieldDistance = distance(self.pos[1], enemyPositionX, self.pos[3], enemyPositionZ)-targetShieldRadius
							if not(closestShieldDistance)then
								closestShieldDistance = enemyShieldDistance
							end
							
							if (enemyShieldDistance < closestShieldDistance and enemyShieldDistance > 20) then
								closestShieldDistance = enemyShieldDistance
								closestShieldID = units[i]
								closestShieldRadius = targetShieldRadius
								rotation = atan((self.pos[1]-enemyPositionX)/(self.pos[3]-enemyPositionZ))
							end
						end
					end
				end	
			end
		end
		if(closestShieldID ~= nil)then
			local enemyPositionX, enemyPositionY, enemyPositionZ = GetUnitPosition(closestShieldID)
			local targetPosRelative={
				sin(rotation) * (closestShieldRadius-14),
				nil,
				cos(rotation) * (closestShieldRadius-14),
			}

			local targetPosAbsolute = {}
			if (self.pos[3]<=enemyPositionZ) then
				targetPosAbsolute = {
					enemyPositionX-targetPosRelative[1],
					nil,
					enemyPositionZ-targetPosRelative[3],
				}
				else
					targetPosAbsolute = {
					enemyPositionX+targetPosRelative[1],
					nil,
					enemyPositionZ+targetPosRelative[3],
				}
			end
			targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
			GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
		else
			GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
		end
	end,
	
	handle=function(self)
		if(GetUnitStates(self.unitID).firestate==1)then
			self.pos = {GetUnitPosition(self.unitID)}
			if(self:isEnemyInRange())then
				return
			end
			self:isShieldInEffectiveRange()
		end
	end
}

function distance ( x1, y1, x2, y2 )
  local dx = (x1 - x2)
  local dy = (y1 - y2)
  return sqrt ( dx * dx + dy * dy )
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (UnitDefs[unitDefID].name == Felon_NAME and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (FelonStack[unitID])then
			FelonStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Felon_NAME)
		and (unitTeam==GetMyTeamID()) then
			FelonStack[unitID] = FelonController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID) 
	if not (FelonStack[unitID]==nil) then
		FelonStack[unitID]=FelonStack[unitID]:unset();
	end
end

function widget:GameFrame(n) 	
	--if (n%UPDATE_FRAME==0) then
		for _,Felon in pairs(FelonStack) do 
			Felon:handle()
		end
	--end
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
		if (UnitDefs[DefID].name==Felon_NAME)  then
			if  (FelonStack[units[i]]==nil) then
				FelonStack[units[i]]=FelonController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
