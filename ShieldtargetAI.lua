function widget:GetInfo()
   return {
      name         = "ShieldtargetAI",
      desc         = "attempt to make units fire the shields of enemy units. Version 0,99",
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
local UPDATE_FRAME=10
local UnitStack = {}
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
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local Jack_NAME = "jumpassault"
local Scythe_NAME = "cloakheavyraid"
local Raven_NAME = "bomberprec"
local Phoenix_NAME = "bomberriot"
local Ripper_NAME = "vehriot"
local Faraday_NAME = "turretemp"
local Stardust_NAME = "turretriot"
local Ogre_NAME = "tankriot"
local Reaver_NAME = "cloakriot"
local Kodachi_NAME = "tankraid"
local Dirtbag_NAME = "shieldscout"
local Venom_NAME = "spideremp"
local Moderator_NAME = "jumpskirm"
local Dominatrix_NAME = "vehcapture"
local Widow_NAME = "spiderantiheavy"
local Bandit_NAME = "shieldraid"
local Scorcher_NAME = "vehraid"
local Redback_NAME = "spiderriot"
local Pyro_NAME = "jumpraid"
local Nimbus_NAME = "gunshipheavyskirm"
local Mace_NAME = "hoverriot"
local Dante_NAME = "striderdante"
local Scorpion_NAME = "striderscorpion"
local Ultimatum_NAME = "striderantiheavy"
local Halbert_NAME = "hoverassault"
local Lobster_NAME = "amphlaunch"
local Puppy_NAME = "jumpscout"
local Jugglenaut_NAME = "jumpsumo"
local Recluse_NAME = "spiderskirm"
local Gauss_NAME = "turretgauss"
local Desolator_NAME = "turretheavy"
local Felon_NAME = "shieldfelon"
local Scalpel_NAME = "hoverskirm"
local Stinger_NAME = "turretheavylaser"
local Locust_NAME = "gunshipraid"
local ENEMY_DETECT_BUFFER  = 35
local Echo = Spring.Echo
local GetSpecState = Spring.GetSpectatingState
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK


local ShieldTargettingController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	enemyNear = false,
	damage,
	
	
	
	new = function(self, unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		local unitDefID = GetUnitDefID(self.unitID)
		local weaponDefID = UnitDefs[unitDefID].weapons[1].weaponDef
		local wd = WeaponDefs[weaponDefID]
		if(weaponDefID and wd.damages[4])then
			self.damage = wd.damages[4]
			Echo("ShieldTargettingController added:" .. unitID)
			return self
		end
		return nil
	end,

	unset = function(self)
		Echo("ShieldTargettingController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	isEnemyInRange = function (self)
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				if  (GetUnitIsDead(units[i]) == false) then
					if (self.enemyNear == false)then
						GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)	
						self.enemyNear = true						
					end
					return true
				end
			end
		end
		self.enemyNear = false
		return false
	end,
	
	isShieldInEffectiveRange = function (self)
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+320)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				DefID = GetUnitDefID(units[i])
				if not(DefID == nil)then
					if (GetUnitIsDead(units[i]) == false and UnitDefs[DefID].hasShield == true) then
						local shieldHealth = {GetUnitShieldState(units[i])}
						if (shieldHealth[2] and self.damage <= shieldHealth[2])then
							local enemyPosition = {GetUnitPosition(units[i])}
							local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
							
							local targetShieldRadius
							if (UnitDefs[DefID].weapons[2] == nil)then
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[1].weaponDef].shieldRadius
							else
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[2].weaponDef].shieldRadius
							end
				
							local targetPosRelative={
								sin(rotation) * (targetShieldRadius-14),
								nil,
								cos(rotation) * (targetShieldRadius-14),
							}
				
							local targetPosAbsolute = {}
							if (self.pos[3]<=enemyPosition[3]) then
								targetPosAbsolute = {
									enemyPosition[1]-targetPosRelative[1],
									nil,
									enemyPosition[3]-targetPosRelative[3],
								}
								else
									targetPosAbsolute = {
									enemyPosition[1]+targetPosRelative[1],
									nil,
									enemyPosition[3]+targetPosRelative[3],
								}
							end
							targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
							GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
							return
						end
					end
				end
			end
		end
		GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
	end,
	
	
	
	
	handle=function(self)
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
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	enemyNear = false,
	damage,
	
	
	
	new = function(self, unitID)
		Echo("BuildingShieldTargettingController added:" .. unitID)
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
		Echo("ShieldTargettingController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	isEnemyInRange = function (self)
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+14)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				if  (GetUnitIsDead(units[i]) == false) then
					if (self.enemyNear == false)then
						GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""}, 1)	
						self.enemyNear = true						
					end
					return true
				end
			end
		end
		self.enemyNear = false
		return false
	end,
	
	
	
	isShieldInEffectiveRange = function (self)
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+320)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				DefID = GetUnitDefID(units[i])
				if not(DefID == nil)then
					if (GetUnitIsDead(units[i]) == false and UnitDefs[DefID].hasShield == true) then
						local shieldHealth = {GetUnitShieldState(units[i])}
						if (shieldHealth[2] and self.damage <= shieldHealth[2])then
							local enemyPosition = {GetUnitPosition(units[i])}
							local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
							
							local targetShieldRadius
							if (UnitDefs[DefID].weapons[2] == nil)then
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[1].weaponDef].shieldRadius								
							else
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[2].weaponDef].shieldRadius
							end
				
							local targetPosRelative={
								sin(rotation) * (targetShieldRadius-14),
								nil,
								cos(rotation) * (targetShieldRadius-14),
							}
				
							local targetPosAbsolute = {}
							if (self.pos[3]<=enemyPosition[3]) then
								targetPosAbsolute = {
									enemyPosition[1]-targetPosRelative[1],
									nil,
									enemyPosition[3]-targetPosRelative[3],
								}
								else
									targetPosAbsolute = {
									enemyPosition[1]+targetPosRelative[1],
									nil,
									enemyPosition[3]+targetPosRelative[3],
								}
							end
							targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
							GiveOrderToUnit(self.unitID,CMD_ATTACK, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
							return
						end
					end
				end
			end
		end
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
	end,
	
	handle=function(self)
		if(GetUnitStates(self.unitID).firestate~=0)then
			if(self:isEnemyInRange()) then
				return
			end
			self:isShieldInEffectiveRange()
		end
	end
}

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].isBuilding == false)then
		if(unitTeam==GetMyTeamID() and UnitDefs[unitDefID].weapons[1] and GetUnitMaxRange(unitID) < 695 and not(UnitDefs[unitDefID].name==Jack_NAME 
			or UnitDefs[unitDefID].name==Scythe_NAME 
			or UnitDefs[unitDefID].name==Phoenix_NAME 
			or UnitDefs[unitDefID].name==Raven_NAME  
			or UnitDefs[unitDefID].name==Ogre_NAME 
			or UnitDefs[unitDefID].name==Reaver_NAME 
			or UnitDefs[unitDefID].name==Kodachi_NAME 
			or UnitDefs[unitDefID].name==Moderator_NAME
			or UnitDefs[unitDefID].name==Dominatrix_NAME
			or UnitDefs[unitDefID].name==Venom_NAME 
			or UnitDefs[unitDefID].name==Bandit_NAME
			or UnitDefs[unitDefID].name==Scorcher_NAME
			or UnitDefs[unitDefID].name==Redback_NAME
			or UnitDefs[unitDefID].name==Pyro_NAME
			or UnitDefs[unitDefID].name==Nimbus_NAME
			or UnitDefs[unitDefID].name==Mace_NAME
			or UnitDefs[unitDefID].name==Widow_NAME
			or UnitDefs[unitDefID].name==Scorpion_NAME
			or UnitDefs[unitDefID].name==Dante_NAME
			or UnitDefs[unitDefID].name==Ultimatum_NAME
			or UnitDefs[unitDefID].name==Halbert_NAME
			or UnitDefs[unitDefID].name==Puppy_NAME
			or UnitDefs[unitDefID].name==Lobster_NAME
			or UnitDefs[unitDefID].name==Jugglenaut_NAME
			or UnitDefs[unitDefID].name==Recluse_NAME
			or UnitDefs[unitDefID].name==Felon_NAME
			or UnitDefs[unitDefID].name==Dirtbag_NAME
			or UnitDefs[unitDefID].name==Scalpel_NAME
			or string.match(UnitDefs[unitDefID].name, "dyn") 
			or UnitDefs[unitDefID].name==Locust_NAME
			or UnitDefs[unitDefID].name==Ripper_NAME)) then
				UnitStack[unitID] = ShieldTargettingController:new(unitID);
		end
	else
		if(unitTeam==GetMyTeamID() and (UnitDefs[unitDefID].name==Gauss_NAME or UnitDefs[unitDefID].name==Desolator_NAME or UnitDefs[unitDefID].name==Stinger_NAME))then
			UnitStack[unitID] = BuildingShieldTargettingController:new(unitID);
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
		widgetHandler:RemoveWidget()
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		unitDefID = GetUnitDefID(units[i])
		if (UnitDefs[unitDefID].isBuilding == false)then
			if(UnitDefs[unitDefID].weapons[1] and GetUnitMaxRange(units[i]) < 695 and not(UnitDefs[unitDefID].name==Jack_NAME 
			or UnitDefs[unitDefID].name==Scythe_NAME 
			or UnitDefs[unitDefID].name==Phoenix_NAME 
			or UnitDefs[unitDefID].name==Raven_NAME  
			or UnitDefs[unitDefID].name==Ogre_NAME 
			or UnitDefs[unitDefID].name==Reaver_NAME 
			or UnitDefs[unitDefID].name==Kodachi_NAME 
			or UnitDefs[unitDefID].name==Moderator_NAME
			or UnitDefs[unitDefID].name==Dominatrix_NAME
			or UnitDefs[unitDefID].name==Venom_NAME 
			or UnitDefs[unitDefID].name==Bandit_NAME
			or UnitDefs[unitDefID].name==Scorcher_NAME
			or UnitDefs[unitDefID].name==Redback_NAME
			or UnitDefs[unitDefID].name==Pyro_NAME
			or UnitDefs[unitDefID].name==Nimbus_NAME
			or UnitDefs[unitDefID].name==Mace_NAME
			or UnitDefs[unitDefID].name==Widow_NAME
			or UnitDefs[unitDefID].name==Scorpion_NAME
			or UnitDefs[unitDefID].name==Dante_NAME
			or UnitDefs[unitDefID].name==Ultimatum_NAME
			or UnitDefs[unitDefID].name==Halbert_NAME
			or UnitDefs[unitDefID].name==Puppy_NAME
			or UnitDefs[unitDefID].name==Lobster_NAME
			or UnitDefs[unitDefID].name==Jugglenaut_NAME
			or UnitDefs[unitDefID].name==Recluse_NAME
			or UnitDefs[unitDefID].name==Felon_NAME
			or UnitDefs[unitDefID].name==Dirtbag_NAME
			or UnitDefs[unitDefID].name==Scalpel_NAME
			or string.match(UnitDefs[unitDefID].name, "dyn")
			or UnitDefs[unitDefID].name==Locust_NAME
			or UnitDefs[unitDefID].name==Ripper_NAME)) then
				if  (UnitStack[units[i]]==nil) then
					UnitStack[units[i]] = ShieldTargettingController:new(units[i]);
				end
			end
		else
			if  (UnitStack[units[i]]==nil) then
				if(UnitDefs[unitDefID].name==Gauss_NAME or UnitDefs[unitDefID].name==Desolator_NAME or UnitDefs[unitDefID].name==Stinger_NAME)then
					UnitStack[units[i]] = BuildingShieldTargettingController:new(units[i]);
				end
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end

