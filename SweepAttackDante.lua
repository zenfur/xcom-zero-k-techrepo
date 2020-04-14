function widget:GetInfo()
   return {
      name         = "SweepAttackDante",
      desc         = "attempt to make Dante sweep area with flame to search for stealthy units. Version 1,00",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 11,
	  handler		= true, --for adding customCommand into UI
      enabled      = true
   }
end
local UPDATE_FRAME=10
local SweeperStack = {}
local GetUnitHeading = Spring.GetUnitHeading
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local Echo = Spring.Echo
local Dante_NAME = "striderdante"
local ENEMY_DETECT_BUFFER  = 40
local GetSpecState = Spring.GetSpectatingState
local pi = math.pi
local FULL_CIRCLE_RADIANT = 2 * pi
local HEADING_TO_RAD = (pi*2/65536 )
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_MOVE = CMD.MOVE
local selectedSweepers = nil
local atan = math.atan
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt


local CMD_TOGGLE_SWEEP = 19990
local DanteUnitDefID = UnitDefNames["striderdante"].id

local cmdSweep = {
	id      = CMD_TOGGLE_SWEEP,
	type    = CMDTYPE.ICON,
	tooltip = 'Makes Dante sweep the area before it with attacks to search for stealthed units.',
	action  = 'reclaim',
	params  = { }, 
	texture = 'unitpics/weaponmod_autoflechette.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},  
}


local SweeperController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	rotation = 0,
	toggle = false,
	enemyNear = false,
	damage,

	
	
	
	new = function(self, unitID)
		--Echo("SweeperController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = (GetUnitMaxRange(self.unitID)-15)
		self.pos = {GetUnitPosition(self.unitID)}
		local unitDefID = GetUnitDefID(self.unitID)
		local weaponDefID = UnitDefs[unitDefID].weapons[1].weaponDef
		local wd = WeaponDefs[weaponDefID]
		self.damage = wd.damages[4]
		return self
	end,


	unset = function(self)
		--Echo("SweeperController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	isEnemyInRange = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+ENEMY_DETECT_BUFFER, false)
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
	
	getToggleState = function(self)
		return self.toggle
	end,
	
	toggleOn = function (self)
		self.toggle = true
	end,
	
	toggleOff = function (self)
		self.toggle = false
		GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
	end,
	
	
	sweep = function(self)
		local heading = GetUnitHeading(self.unitID)*HEADING_TO_RAD
		if (self.rotation > 3) then
			self.rotation = -3
		end
		local targetPosRelative = {
			sin(heading+0.2*self.rotation)*(self.range-120),
			nil,
			cos(heading+0.2*self.rotation)*(self.range-120),
			}	
			self.rotation = self.rotation+1
		local targetPosAbsolute = {
			targetPosRelative[1]+self.pos[1],
			nil,
			targetPosRelative[3]+self.pos[3],
			}
		targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
		GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
	end,
	
	
	isEnemyInRange2 = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+22, false)
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
		self.pos = {GetUnitPosition(self.unitID)}
		if(self.toggle) then
			if(self:isEnemyInRange()) then
				return
			end
			self:sweep()
		else
			if(GetUnitStates(self.unitID).firestate~=0)then
				if(self:isEnemyInRange2()) then
					return
				end
				self:isShieldInEffectiveRange()
			end
		end
	end
}

function distance ( x1, y1, x2, y2 )
  local dx = (x1 - x2)
  local dy = (y1 - y2)
  return sqrt ( dx * dx + dy * dy )
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Dante_NAME)
		and (unitTeam==GetMyTeamID()) then
			SweeperStack[unitID] = SweeperController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID) 
	if not (SweeperStack[unitID]==nil) then
		SweeperStack[unitID]=SweeperStack[unitID]:unset();
	end
end

function widget:GameFrame(n) 
	if (n%UPDATE_FRAME==0) then
		for _,sweeper in pairs(SweeperStack) do
			sweeper:handle()
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


--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedSweepers ~= nil then
		if (cmdID == CMD_TOGGLE_SWEEP)then
			local toggleStateGot = false
			local toggleState
			for i=1, #selectedSweepers do
				if (SweeperStack[selectedSweepers[i]])then
					if (toggleStateGot == false)then
						toggleState = SweeperStack[selectedSweepers[i]]:getToggleState()
						toggleStateGot = true
					end
					if (toggleState) then
						SweeperStack[selectedSweepers[i]]:toggleOff()
					else
						SweeperStack[selectedSweepers[i]]:toggleOn()
					end
				end
			end
			return true
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedSweepers = filterSweepers(selectedUnits)
end

function filterSweepers(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (DanteUnitDefID == GetUnitDefID(unitID)) then
			n = n + 1
			filtered[n] = unitID
		end
	end
	if n == 0 then
		return nil
	else
		return filtered
	end
end

function widget:CommandsChanged()
	if selectedSweepers then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdSweep
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
		if (UnitDefs[DefID].name==Dante_NAME)  then
			if  (SweeperStack[units[i]]==nil) then
				SweeperStack[units[i]]=SweeperController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
