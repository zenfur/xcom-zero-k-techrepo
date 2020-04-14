function widget:GetInfo()
   return {
      name         = "PreFireFaraday",
      desc         = "attempt to make Faraday fire targets that are in max range + AoE range. Version 1.00",
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
local UPDATE_FRAME=10
local FaradayStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local target = Spring.SetUnitTarget
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local ENEMY_DETECT_BUFFER  = 72
local Echo = Spring.Echo
local Faraday_NAME = "turretemp"
local GetSpecState = Spring.GetSpectatingState
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_ATTACK = CMD.ATTACK
local CMD_STOP = CMD.STOP


local FaradayController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	enemyNear = false,
	damage,
	
	
	new = function(self, unitID)
		--Echo("FaradayController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)-6
		self.pos = {GetUnitPosition(self.unitID)}
		local unitDefID = GetUnitDefID(self.unitID)
		local weaponDefID = UnitDefs[unitDefID].weapons[1].weaponDef
		local wd = WeaponDefs[weaponDefID]
		self.damage = wd.damages[4]
		return self
	end,

	unset = function(self)
		--Echo("FaradayController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	isEnemyInRange = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range, false)
		if  (enemyUnitID and GetUnitIsDead(enemyUnitID) == false) then
			if (self.enemyNear == false)then
				GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""}, 1)
				self.enemyNear = true						
			end
			return true
		end
		self.enemyNear = false
		return false
	end,
	--################################################### Too memory intensive! Attempt to make the Faraday also fire at the most optimal target which would include as many enemies as possible in the firezone
	--isEnemyInRangeV2 = function (self)
	--	local OptimalTarget = 0
	--	local OptimalTargetID = 0
	--	for i=1, units=#GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range)) do
		--	if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then
			--	if  (GetUnitIsDead(units[i]) == false) then
			--		local targetsInArea = 0
			--		local targettedArea = {GetUnitPosition(units[i])}
			--		for i=1, units=#GetUnitsInSphere(GetUnitsInSphere(targettedArea[1], targettedArea[2], targettedArea[3], 70)) do
			--			if not (GetUnitAllyTeam(ID) == self.allyTeamID) then
			--				if  (GetUnitIsDead(ID) == false) then
			--					targetsInArea = targetsInArea +1
			--				end
			--			end
			--		end
			--		if (targetsInArea > OptimalTarget) then
			--			OptimalTarget = targetsInArea
			--			OptimalTargetID = units[i]
			--		end
			--	end
		--	end
		--end
		--if not(OptimalTarget == 0) then
		--	GiveOrderToUnit(self.unitID,CMD_ATTACK, OptimalTargetID, 0)
			--return true
		--end
		--return false
	--end,
	--################################################
	
	isEnemyInEffectiveRange = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+ENEMY_DETECT_BUFFER, false)
		if(enemyUnitID)then
			DefID = GetUnitDefID(enemyUnitID)
			if not(DefID == nil)then
				if (GetUnitIsDead(enemyUnitID) == false and UnitDefs[DefID].isAirUnit==false) then
					local enemyPosition = {GetUnitPosition(enemyUnitID)}
					local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
					local targetPosRelative={
						sin(rotation) * (self.range-8),
						nil,
						cos(rotation) * (self.range-8),
					}
					local testTargetPosRelative = {
						sin(rotation)*(self.range-50),
						nil,
						cos(rotation)*(self.range-50),
					}
		
					local targetPosAbsolute = {}
					local testTargetPosAbsolute = {}
					if (self.pos[3]<=enemyPosition[3]) then
						targetPosAbsolute = {
							self.pos[1]+targetPosRelative[1],
							nil,
							self.pos[3]+targetPosRelative[3],
						}
						testTargetPosAbsolute = {
							self.pos[1]+testTargetPosRelative[1],
							nil,
							self.pos[3]+testTargetPosRelative[3],
						}
						else
						targetPosAbsolute = {
							self.pos[1]-targetPosRelative[1],
							nil,
							self.pos[3]-targetPosRelative[3],
						}
						testTargetPosAbsolute = {
							self.pos[1]-testTargetPosRelative[1],
							nil,
							self.pos[3]-testTargetPosRelative[3],
						}
					end
					targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
					testTargetPosAbsolute[2]= GetGroundHeight(testTargetPosAbsolute[1],testTargetPosAbsolute[3])
					local friendlies = #GetUnitsInSphere(testTargetPosAbsolute[1], testTargetPosAbsolute[2], testTargetPosAbsolute[3], 130, self.allyTeamID)
					if (friendlies==0)then
						GiveOrderToUnit(self.unitID,CMD_ATTACK, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
						return true
					end
				end
			end
		end
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return false
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
							local enemyPositionX, enemyPositionY,enemyPositionZ = GetUnitPosition(units[i])
							
							local targetShieldRadius
							if (UnitDefs[DefID].weapons[2] == nil)then
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[1].weaponDef].shieldRadius
							else
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[2].weaponDef].shieldRadius
							end
							
							enemyShieldDistance = distance(self.pos[1], enemyPositionX, self.pos[3], enemyPositionZ)-targetShieldRadius
							if not(closestShieldDistance)then
								closestShieldDistance = enemyShieldDistance
								closestShieldID = units[i]
								closestShieldRadius = targetShieldRadius
								rotation = atan((self.pos[1]-enemyPositionX)/(self.pos[3]-enemyPositionZ))
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
		if(closestShieldID)then
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
			GiveOrderToUnit(self.unitID,CMD_ATTACK, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
		else
			GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		end
	end,
	
	handle=function(self)
		if(GetUnitStates(self.unitID).firestate~=0)then
			if(self:isEnemyInRange()) then
				return
			end
			if(self:isEnemyInEffectiveRange())then
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

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Faraday_NAME)
		and (unitTeam==GetMyTeamID()) then
			FaradayStack[unitID] = FaradayController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID) 
	if not (FaradayStack[unitID]==nil) then
		FaradayStack[unitID]=FaradayStack[unitID]:unset();
	end
end

function widget:GameFrame(n) 
	if (n%UPDATE_FRAME==0) then
		for _,newton in pairs(FaradayStack) do
			newton:handle()
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
	local units = Spring.GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==Faraday_NAME)  then
			if  (FaradayStack[units[i]]==nil) then
				FaradayStack[units[i]]=FaradayController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
