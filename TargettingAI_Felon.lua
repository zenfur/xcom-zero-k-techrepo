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
local Felon_ID = UnitDefNames.shieldfelon.id
local Solar_ID = UnitDefNames.energysolar.id
local Razor_ID = UnitDefNames.turretaalaser.id
local Minotaur_ID = UnitDefNames.tankassault.id
local Cyclops_ID = UnitDefNames.tankheavyassault.id
local Dirtbag_ID = UnitDefNames.shieldscout.id
local Halbert_ID = UnitDefNames.hoverassault.id
local Jack_ID = UnitDefNames.jumpassault.id
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK
local CMD_REMOVE = CMD.REMOVE



local FelonControllerMT
local FelonController = {
	unitID,
	pos,
	range,
	damage,
	forceTarget,



	new = function(index, unitID)
		--Echo("FelonController added:" .. unitID)
		local self = {}
		setmetatable(self, FelonControllerMT)
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
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range+ENEMY_DETECT_BUFFER, Spring.ENEMY_UNITS)
		local target = nil
		for i=1, #units do
			local unitID = units[i]
			local enemyPosition = {GetUnitPosition(unitID)}
			if(enemyPosition[2]>-30)then
				if (unitID==self.forceTarget and GetUnitIsDead(unitID) == false)then
					GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, unitID, 0)
					return true
				end
				local unitDefID = GetUnitDefID(unitID)
				if not((unitDefID == nil) or GetUnitIsDead(unitID)) then
					local hasArmor = GetUnitArmored(unitID)
					if not(unitDefID == Solar_ID
						or unitDefID == Dirtbag_ID
						or unitDefID == Minotaur_ID
						or unitDefID == Cyclops_ID
						or (unitDefID == Halbert_ID and hasArmor)
						or unitDefID == Razor_ID and hasArmor) then
						if (target == nil) then
							target = unitID
						end
						if (UnitDefs[unitDefID].isAirUnit == true or UnitDefs[GetUnitDefID(target)].metalCost > UnitDefs[unitDefID].metalCost)then
							target = unitID
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
		local closestShieldID, closestShieldDistance, closestShieldRadius, rotation
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+320, Spring.ENEMY_UNITS)
		for i=1, #units do
			local unitDefID = GetUnitDefID(units[i])
			if not(unitDefID == nil)then
				if (GetUnitIsDead(units[i]) == false and UnitDefs[unitDefID].hasShield == true) then
					local shieldHealth = {GetUnitShieldState(units[i])}
					if (shieldHealth[2] and self.damage <= shieldHealth[2])then
						local enemyPositionX, enemyPositionY, enemyPositionZ = GetUnitPosition(units[i])

						local targetShieldRadius
						if (UnitDefs[unitDefID].weapons[2] == nil)then
							targetShieldRadius = WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].shieldRadius
						else
							targetShieldRadius = WeaponDefs[UnitDefs[unitDefID].weapons[2].weaponDef].shieldRadius
						end

						local enemyShieldDistance = distance(self.pos[1], enemyPositionX, self.pos[3], enemyPositionZ)-targetShieldRadius
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
		if(closestShieldID ~= nil)then
			local enemyPositionX, enemyPositionY, enemyPositionZ = GetUnitPosition(closestShieldID)
			local targetPosRelative={
				sin(rotation) * (closestShieldRadius-14),
				nil,
				cos(rotation) * (closestShieldRadius-14),
			}

			local targetPosAbsolute
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
FelonControllerMT = {__index = FelonController}

function distance ( x1, y1, x2, y2 )
  local dx = (x1 - x2)
  local dy = (y1 - y2)
  return sqrt ( dx * dx + dy * dy )
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (unitDefID == Felon_ID and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (FelonStack[unitID])then
			FelonStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Felon_ID)
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

-- The rest of the code is there to disable the widget for spectators
local function DisableForSpec()
	if GetSpecState() then
		widgetHandler:RemoveWidget(widget)
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		local unitDefID = GetUnitDefID(units[i])
		if (unitDefID == Felon_ID)  then
			if  (FelonStack[units[i]]==nil) then
				FelonStack[units[i]]=FelonController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
