function widget:GetInfo()
   return {
      name         = "TargettingAI_Impaler",
      desc         = "attempt to make Impaler not fire Razors, solars and wind generators without order. Meant to be used with return fire state. Version 1.00",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 11,
      enabled      = true
   }
end

local UPDATE_FRAME=4
local ImpalerStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local ENEMY_DETECT_BUFFER  = 40
local Echo = Spring.Echo
local Impaler_ID = UnitDefNames.vehheavyarty.id
local Crab_ID = UnitDefNames.spidercrabe.id
local Fencer_ID = UnitDefNames.vehsupport.id
local Caretaker_ID = UnitDefNames.staticcon.id
local Badger_Mine_ID = UnitDefNames.wolverine_mine.id
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK



local ImpalerControllerMT
local ImpalerController = {
	unitID,
	pos,
	range,
	damage,
	forceTarget,


	new = function(index, unitID)
		--Echo("ImpalerController added:" .. unitID)
		local self = {}
		setmetatable(self, ImpalerControllerMT)
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
		--Echo("ImpalerController removed:" .. self.unitID)
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
			local enemyPosition = {GetUnitPosition(units[i])}
			if(enemyPosition[2]>-30)then
				if (units[i]==self.forceTarget and GetUnitIsDead(units[i]) == false)then
					GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
					return true
				end
				local unitDefID = GetUnitDefID(units[i])
				if not((unitDefID == nil) or GetUnitIsDead(units[i])) then
					if (UnitDefs[unitDefID].isBuilding and unitDefID ~= Badger_Mine_ID or unitDefID == Crab_ID or unitDefID == Fencer_ID or unitDefID == Caretaker_ID) then
						if (target == nil) then
							target = units[i]
						end
						if (UnitDefs[GetUnitDefID(target)].metalCost < UnitDefs[unitDefID].metalCost)then
							target = units[i]
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
ImpalerControllerMT = {__index = ImpalerController}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (unitDefID == Impaler_ID and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (ImpalerStack[unitID])then
			ImpalerStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Impaler_ID)
		and (unitTeam==GetMyTeamID()) then
			ImpalerStack[unitID] = ImpalerController:new(unitID);
		end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if (unitDefID == Impaler_ID)
		and not ImpalerStack[unitID] then
		ImpalerStack[unitID] = ImpalerController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (ImpalerStack[unitID]==nil) then
		ImpalerStack[unitID]=ImpalerStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	--if (n%UPDATE_FRAME==0) then
		for _,Impaler in pairs(ImpalerStack) do
			Impaler:handle()
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
		if (unitDefID == Impaler_ID)  then
			if  (ImpalerStack[units[i]]==nil) then
				ImpalerStack[units[i]]=ImpalerController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
