function widget:GetInfo()
   return {
      name         = "SweepAttackNimbus",
      desc         = "attempt to make Nimbus sweep area with attacks to search for stealthy units. Version 1,00",
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
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local Echo = Spring.Echo
local Nimbus_NAME = "gunshipheavyskirm"
local ENEMY_DETECT_BUFFER  = 150
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


local CMD_TOGGLE_SWEEP = 19991
local NimbusUnitDefID = UnitDefNames["gunshipheavyskirm"].id

local cmdSweep = {
	id      = CMD_TOGGLE_SWEEP,
	type    = CMDTYPE.ICON,
	tooltip = 'Makes Nimbus sweep the area before it with attacks to search for stealthed units.',
	action  = 'oneclickwep',
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
	sweepDir = 1,
	enemyNear = false,

	
	
	
	new = function(self, unitID)
		--Echo("SweeperController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = (GetUnitMaxRange(self.unitID)-53)
		self.pos = {GetUnitPosition(self.unitID)}
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
		if (self.rotation > 2) then
			self.rotation = -1
			self.sweepDir = -self.sweepDir
		end
		local targetPosRelative = {
			sin(heading+0.16*self.rotation*self.sweepDir)*(self.range),
			nil,
			cos(heading+0.16*self.rotation*self.sweepDir)*(self.range),
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
	
	
	handle=function(self)
		if(self.toggle) then
			self.pos = {GetUnitPosition(self.unitID)}
			if(self:isEnemyInRange()) then
				return
			end
			self:sweep()
		end
	end
}



function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Nimbus_NAME)
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
		if (NimbusUnitDefID == GetUnitDefID(unitID)) then
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
		if (UnitDefs[DefID].name==Nimbus_NAME)  then
			if  (SweeperStack[units[i]]==nil) then
				SweeperStack[units[i]]=SweeperController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end

