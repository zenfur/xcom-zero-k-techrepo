function widget:GetInfo()
   return {
      name         = "TargettingAI_Puppy",
      desc         = "attempt to make Puppy not attack nanoframes, solars and wind generators or armored Halberts/Razors/Faradays without order. Meant to be used with return fire state. Version 1.00",
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
local PuppyStack = {}
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
local GetUnitHealth = Spring.GetUnitHealth
local ENEMY_DETECT_BUFFER  = 40
local Echo = Spring.Echo
local Puppy_NAME = "jumpscout"
local Solar_NAME = "energysolar"
local Wind_NAME = "energywind"
local Razor_NAME = "turretaalaser"
local Metal_NAME = "staticmex"
local Halbert_NAME = "hoverassault"
local Gauss_NAME = "turretgauss"
local Faraday_NAME = "turretemp"
local Badger_Mine_NAME = "wolverine_mine"
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK



local PuppyController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	damage,
	forceTarget,
	
	
	new = function(self, unitID)
		--Echo("PuppyController added:" .. unitID)
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
		--Echo("PuppyController removed:" .. self.unitID)
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
						if  (GetUnitIsDead(units[i]) == false)then
							hp, mxhp, _, _, bp = GetUnitHealth(units[i])
							local hasArmor = GetUnitArmored(units[i])
							if not(UnitDefs[DefID].name == Solar_NAME 
							or UnitDefs[DefID].name == Wind_NAME 
							or UnitDefs[DefID].name == Badger_Mine_NAME
							or (UnitDefs[DefID].name == Razor_NAME 
							or UnitDefs[DefID].name == Gauss_NAME 
							or UnitDefs[DefID].name == Faraday_NAME
							or UnitDefs[DefID].name == Halbert_NAME) and hasArmor) and (bp and bp>0.8)then
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

function distance ( x1, y1, x2, y2 )
  local dx = (x1 - x2)
  local dy = (y1 - y2)
  return sqrt ( dx * dx + dy * dy )
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (UnitDefs[unitDefID].name == Puppy_NAME and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (PuppyStack[unitID])then
			PuppyStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Puppy_NAME)
		and (unitTeam==GetMyTeamID()) then
			PuppyStack[unitID] = PuppyController:new(unitID);
		end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if (UnitDefs[unitDefID].name==Puppy_NAME)
		and not PuppyStack[unitID] then
		PuppyStack[unitID] = PuppyController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID) 
	if not (PuppyStack[unitID]==nil) then
		PuppyStack[unitID]=PuppyStack[unitID]:unset();
	end
end

function widget:GameFrame(n) 	
	--if (n%UPDATE_FRAME==0) then
		for _,Puppy in pairs(PuppyStack) do 
			Puppy:handle()
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
		if (UnitDefs[DefID].name==Puppy_NAME)  then
			if  (PuppyStack[units[i]]==nil) then
				PuppyStack[units[i]]=PuppyController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
