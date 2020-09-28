function widget:GetInfo()
	return {
		name         = "ShieldtargetAI",
		desc         = "attempt to make units fire the shields of enemy units. Version 1.00",
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
local UnitStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local GetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local Jack_ID = UnitDefNames.jumpassault.id
local Scythe_ID = UnitDefNames.cloakheavyraid.id
local Raven_ID = UnitDefNames.bomberprec.id
local Phoenix_ID = UnitDefNames.bomberriot.id
local Ripper_ID = UnitDefNames.vehriot.id
local Ogre_ID = UnitDefNames.tankriot.id
local Reaver_ID = UnitDefNames.cloakriot.id
local Kodachi_ID = UnitDefNames.tankraid.id
local Dirtbag_ID = UnitDefNames.shieldscout.id
local Venom_ID = UnitDefNames.spideremp.id
local Moderator_ID = UnitDefNames.jumpskirm.id
local Dominatrix_ID = UnitDefNames.vehcapture.id
local Widow_ID = UnitDefNames.spiderantiheavy.id
local Bandit_ID = UnitDefNames.shieldraid.id
local Scorcher_ID = UnitDefNames.vehraid.id
local Redback_ID = UnitDefNames.spiderriot.id
local Pyro_ID = UnitDefNames.jumpraid.id
local Nimbus_ID = UnitDefNames.gunshipheavyskirm.id
local Mace_ID = UnitDefNames.hoverriot.id
local Dante_ID = UnitDefNames.striderdante.id
local Scorpion_ID = UnitDefNames.striderscorpion.id
local Ultimatum_ID = UnitDefNames.striderantiheavy.id
local Halbert_ID = UnitDefNames.hoverassault.id
local Lobster_ID = UnitDefNames.amphlaunch.id
local Puppy_ID = UnitDefNames.jumpscout.id
local Jugglenaut_ID = UnitDefNames.jumpsumo.id
local Recluse_ID = UnitDefNames.spiderskirm.id
local Gauss_ID = UnitDefNames.turretgauss.id
local Desolator_ID = UnitDefNames.turretheavy.id
local Felon_ID = UnitDefNames.shieldfelon.id
local Scalpel_ID = UnitDefNames.hoverskirm.id
local Stinger_ID = UnitDefNames.turretheavylaser.id
local Locust_ID = UnitDefNames.gunshipraid.id
local Revenant_ID = UnitDefNames.gunshipassault.id
local FELON_MIN_SHIELD = UnitDefs[Felon_ID].customParams.shield_power * 0.9
local ENEMY_DETECT_BUFFER  = 35
local Echo = Spring.Echo
local GetSpecState = Spring.GetSpectatingState
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_UNIT_SET_TARGET_CIRCLE = 34925
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK

local ShieldTargettingController = {
	enemyNear = false,
	extra_range = 22,

	new = function(self, unitID)
		if(unitID)then
			self = deepcopy(self)
			self.unitID = unitID
			self.range = GetUnitMaxRange(self.unitID)
			self.pos = {GetUnitPosition(self.unitID)}
			self.drec = false
			self.isFelon = (GetUnitDefID(self.unitID) == Felon_ID)
			local unitDefID = GetUnitDefID(self.unitID)
			local weaponDefID = UnitDefs[unitDefID].weapons[1].weaponDef
			local wd = WeaponDefs[weaponDefID]
			if(weaponDefID and wd.damages[4])then
				self.damage = wd.damages[4]
				--Echo("ShieldTargettingController added:" .. unitID)
				return self
			end
		end
		return nil
	end,

	unset = function(self)
		--Echo("ShieldTargettingController removed:" .. self.unitID)
		if not self.drec then
			self:stop()
		end
		return nil
	end,

	isEnemyInRange = function (self)
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range + self.extra_range, Spring.ENEMY_UNITS)
		for i=1, #units do
			if  (GetUnitIsDead(units[i]) == false) then
				if (self.enemyNear == false)then
					self:stop()
					self.enemyNear = true
				end
				return true
			end
		end
		self.enemyNear = false
		return false
	end,

	isShieldInEffectiveRange = function (self)
		local closestShieldID = nil
		local closestShieldDistance = nil
		local closestShieldRadius = nil
		local rotation = nil
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+520, Spring.ENEMY_UNITS)
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
		if(closestShieldID ~= nil and (not self.isFelon or select(2, GetUnitShieldState(self.unitID)) > FELON_MIN_SHIELD ))then
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
			self:fire(targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3])
		else
			local target = {GetUnitWeaponTarget(self.unitID, 1)}
			if(target[1]==2)then
				self:stop()
			end
		end
	end,

	stop=function(self)
		GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
	end,

	fire=function(self, x, y, z)
		GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {x, y, z}, 0)
	end,



	handle=function(self)
		if self.drec then
			return
		end
		if(GetUnitStates(self.unitID).firestate~=0)then
			self.pos = {GetUnitPosition(self.unitID)}
			if(self:isEnemyInRange()) then
				return
			end
			self:isShieldInEffectiveRange()
		end
	end
}

local BuildingShieldTargettingController = {
	new = function(self, unitID)
		self = self:new(unitID)
		self.extra_range = 14
		self.stop = function(self)
			GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		end
		self.fire = function(self, x, y, z)
			GiveOrderToUnit(self.unitID,CMD_ATTACK, {x, y, z}, 0)
		end
		local baseIsEnemyInRange = self.IsEnemyInRange
		self.IsEnemyInRange = function()
			self.pos = {GetUnitPosition(self.unitID)}
			return baseIsEnemyInRange()
		end
	end
}

function distance ( x1, y1, x2, y2 )
	local dx = (x1 - x2)
	local dy = (y1 - y2)
	return sqrt ( dx * dx + dy * dy )
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].isBuilding == false)then
		if(unitTeam==GetMyTeamID() and UnitDefs[unitDefID].weapons[1] and GetUnitMaxRange(unitID) < 695 and not(unitDefID == Jack_ID
				or unitDefID == Scythe_ID
				or unitDefID == Phoenix_ID
				or unitDefID == Raven_ID
				or unitDefID == Ogre_ID
				or unitDefID == Moderator_ID
				or unitDefID == Dominatrix_ID
				or unitDefID == Pyro_ID
				or unitDefID == Nimbus_ID
				or unitDefID == Widow_ID
				or unitDefID == Scorpion_ID
				or unitDefID == Ultimatum_ID
				or unitDefID == Halbert_ID
				or unitDefID == Puppy_ID
				or unitDefID == Lobster_ID
				or unitDefID == Jugglenaut_ID
				or unitDefID == Recluse_ID
				or unitDefID == Dirtbag_ID
				or unitDefID == Scalpel_ID
				or string.match(UnitDefs[unitDefID].name, "dyn")
				or unitDefID == Locust_ID
				or unitDefID == Revenant_ID)) then
			UnitStack[unitID] = ShieldTargettingController:new(unitID);
		end
	else
		if(unitTeam==GetMyTeamID() and (unitDefID == Gauss_ID or unitDefID == Desolator_ID or unitDefID == Stinger_ID))then
			UnitStack[unitID] = BuildingShieldTargettingController:new(unitID);
		end
	end
end

function widget:CommandNotify(id, params, options)
	local selectedUnits = Spring.GetSelectedUnits()
	for _, unitID in pairs(selectedUnits) do	-- check selected units...
		if UnitStack[unitID] then	--  was issued to one of our units.
			if id == CMD_UNIT_SET_TARGET or id == CMD_UNIT_SET_TARGET_CIRCLE then
				-- Direct order to set a priority target
				UnitStack[unitID].drec = true
			elseif id == CMD_STOP or id == CMD_UNIT_CANCEL_TARGET then
				-- Cancel direct order
				UnitStack[unitID].drec = false
			end
		end
	end
end

function widget:UnitDestroyed(unitID)
	if not (UnitStack[unitID]==nil) then
		UnitStack[unitID]=UnitStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for _,unit in pairs(UnitStack) do
			unit:handle()
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
		widgetHandler:RemoveWidget(widget)
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		local unitDefID = GetUnitDefID(units[i])
		if (UnitDefs[unitDefID].isBuilding == false)then
			if(UnitDefs[unitDefID].weapons[1] and GetUnitMaxRange(units[i]) < 695 and not(unitDefID == Jack_ID
					or unitDefID == Scythe_ID
					or unitDefID == Phoenix_ID
					or unitDefID == Raven_ID
					or unitDefID == Ogre_ID
					or unitDefID == Moderator_ID
					or unitDefID == Dominatrix_ID
					or unitDefID == Pyro_ID
					or unitDefID == Nimbus_ID
					or unitDefID == Widow_ID
					or unitDefID == Scorpion_ID
					or unitDefID == Ultimatum_ID
					or unitDefID == Halbert_ID
					or unitDefID == Puppy_ID
					or unitDefID == Lobster_ID
					or unitDefID == Jugglenaut_ID
					or unitDefID == Recluse_ID
					or unitDefID == Dirtbag_ID
					or unitDefID == Scalpel_ID
					or string.match(UnitDefs[unitDefID].name, "dyn")
					or unitDefID == Locust_ID
					or unitDefID == Revenant_ID)) then
				if  (UnitStack[units[i]]==nil) then
					UnitStack[units[i]] = ShieldTargettingController:new(units[i]);
				end
			end
		else
			if  (UnitStack[units[i]]==nil) then
				if(unitDefID == Gauss_ID or unitDefID == Desolator_ID or unitDefID == Stinger_ID)then
					UnitStack[units[i]] = BuildingShieldTargettingController:new(units[i]);
				end
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
