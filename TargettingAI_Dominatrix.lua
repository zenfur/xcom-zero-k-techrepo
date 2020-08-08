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
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local ENEMY_DETECT_BUFFER  = 40
local Echo = Spring.Echo
local Dominatrix_ID = UnitDefNames.vehcapture.id
local Solar_ID = UnitDefNames.energysolar.id
local Wind_ID = UnitDefNames.energywind.id
local Razor_ID = UnitDefNames.turretaalaser.id
local Metal_ID = UnitDefNames.staticmex.id
local Dirtbag_ID = UnitDefNames.shieldscout.id
local Flea_ID = UnitDefNames.spiderscout.id
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK



local DominatrixControllerMT
local DominatrixController = {
	unitID,
	pos,
	range,
	forceTarget,


	new = function(index, unitID)
		--Echo("DominatrixController added:" .. unitID)
		local self = {}
		setmetatable(self, DominatrixControllerMT)
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
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range+ENEMY_DETECT_BUFFER, Spring.ENEMY_UNITS)
		local target = nil
		local targetMaxHealth = nil
		local targetRemainingHealth = nil
		local targetCaptureProgress = nil
		for i=1, #units do
			if (units[i]==self.forceTarget and GetUnitIsDead(units[i]) == false)then
				GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
				return true
			end
			local unitDefID = GetUnitDefID(units[i])
			if not(unitDefID == nil)then
				local enemyHealthStats = {GetUnitHealth(units[i])}
				local enemyBuildProgress = enemyHealthStats[5]

				if  (enemyBuildProgress and GetUnitIsDead(units[i]) == false and enemyBuildProgress >=0.80 and
				not(unitDefID == Solar_ID
				or unitDefID == Wind_ID
				or unitDefID == Flea_ID
				or unitDefID == Dirtbag_ID
				or unitDefID == Metal_ID)) then

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
					   > enemyRemainingHealth*(2-enemyCaptureProgress)*(2+enemyRemainingHealth/enemyMaxHealth)/UnitDefs[unitDefID].metalCost)then
						target = units[i]
						targetMaxHealth = enemyMaxHealth
						targetRemainingHealth = enemyRemainingHealth
						targetCaptureProgress = enemyCaptureProgress
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
DominatrixControllerMT = {__index = DominatrixController}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (unitDefID == Dominatrix_ID and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (DominatrixStack[unitID])then
			DominatrixStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Dominatrix_ID)
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
		if (unitDefID == Dominatrix_ID)  then
			if  (DominatrixStack[units[i]]==nil) then
				DominatrixStack[units[i]]=DominatrixController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
