function widget:GetInfo()
   return {
      name         = "PreFireOgre",
      desc         = "attempt to make Ogre fire targets that are in max range + AoE range. Version 1.00",
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
local abs = math.abs
local sqrt = math.sqrt
local HEADING_TO_RAD = (pi*2/65536 )
local UPDATE_FRAME=10
local OgreStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local GetUnitVelocity  = Spring.GetUnitVelocity
local GetUnitHeading = Spring.GetUnitHeading
local GetPlayerInfo = Spring.GetPlayerInfo
local GetMyPlayerID = Spring.GetMyPlayerID
local myPlayerID = GetMyPlayerID()
local ping = 0
local ENEMY_DETECT_BUFFER  = 74
local Echo = Spring.Echo
local Ogre_ID = UnitDefNames.tankriot.id
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924


local OgreControllerMT
local OgreController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	enemyNear = false,
	damage,


	new = function(index, unitID)
		--Echo("OgreController added:" .. unitID)
		local self = {}
		setmetatable(self, OgreControllerMT)
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
		--Echo("OgreController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD.STOP, {}, {""},1)
		return nil
	end,

	isEnemyInRange = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+ping*20+22, false)
		if  (enemyUnitID and GetUnitIsDead(enemyUnitID) == false) then
			if (self.enemyNear == false)then
				GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
				self.enemyNear = true
			end
			return true
		end
		self.enemyNear = false
		return false
	end,

	isEnemyInEffectiveRange = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+ENEMY_DETECT_BUFFER+ping*20, false)
		if(enemyUnitID)then
			local unitDefID = GetUnitDefID(enemyUnitID)
			if not(unitDefID == nil)then
				if (GetUnitIsDead(enemyUnitID) == false and UnitDefs[unitDefID].isAirUnit==false) then
					local enemyPosition = {GetUnitPosition(enemyUnitID)}
					local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
					local heading = GetUnitHeading(self.unitID)*HEADING_TO_RAD
					local velocity = {GetUnitVelocity(self.unitID)}

					local targetPosRelative
					local testTargetPosRelative
					if(abs(velocity[1])+abs(velocity[3])>1)then
						if(self.pos[3]<=enemyPosition[3])then
							targetPosRelative={
								sin(rotation) * (self.range-10+120*ping*cos(abs(heading-rotation))),
								nil,
								cos(rotation) * (self.range-10+120*ping*cos(abs(heading-rotation))),
							}
							testTargetPosRelative = {
								sin(rotation)*(self.range-50+120*ping*cos(abs(heading-rotation))),
								nil,
								cos(rotation)*(self.range-50+120*ping*cos(abs(heading-rotation))),
							}
						else
							targetPosRelative={
								sin(rotation) * (self.range-10-120*ping*cos(abs(heading-rotation))),
								nil,
								cos(rotation) * (self.range-10-120*ping*cos(abs(heading-rotation))),
							}
							testTargetPosRelative = {
								sin(rotation)*(self.range-50-120*ping*cos(abs(heading-rotation))),
								nil,
								cos(rotation)*(self.range-50-120*ping*cos(abs(heading-rotation))),
							}
						end
					else
						targetPosRelative={
							sin(rotation) * (self.range-8),
							nil,
							cos(rotation) * (self.range-8),
						}
						testTargetPosRelative = {
							sin(rotation)*(self.range-40),
							nil,
							cos(rotation)*(self.range-40),
						}
					end

					local targetPosAbsolute
					local testTargetPosAbsolute
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
						GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
						return true
					end
				end
			end
		end
		GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
		return false
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
		if(GetUnitStates(self.unitID).firestate~=0)then
			self.pos = {GetUnitPosition(self.unitID)}
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
OgreControllerMT = {__index = OgreController}

function distance ( x1, y1, x2, y2 )
  local dx = (x1 - x2)
  local dy = (y1 - y2)
  return sqrt ( dx * dx + dy * dy )
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Ogre_ID)
		and (unitTeam==GetMyTeamID()) then
			OgreStack[unitID] = OgreController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID)
	if not (OgreStack[unitID]==nil) then
		OgreStack[unitID]=OgreStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		local myInfo ={GetPlayerInfo(myPlayerID)}
		ping = myInfo[6]
		for _,ogre in pairs(OgreStack) do
			ogre:handle()
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
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		local unitDefID = GetUnitDefID(units[i])
		if (unitDefID == Ogre_ID)  then
			if  (OgreStack[units[i]]==nil) then
				OgreStack[units[i]]=OgreController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
