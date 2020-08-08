function widget:GetInfo()
   return {
      name         = "BurrowBombAttack",
      desc         = "attempt to make Imp and Snitch move towards enemies in their decloak radius. Version 0,77",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 11,
      enabled      = true
   }
end
local UPDATE_FRAME=4
local BurrowBombStack = {}
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local IsUnitSelected = Spring.IsUnitSelected
local GetTeamUnits = Spring.GetTeamUnits
local ENEMY_DETECT_BUFFER  = 50
local Echo = Spring.Echo
local Imp_ID = UnitDefNames.cloakbomb.id
local Snitch_ID = UnitDefNames.shieldbomb.id
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK

local BurrowAttackControllerMT
local BurrowAttackController = {
	unitID,
	pos,
	range,
	isSelected = false,



	new = function(index, unitID)
		--Echo("BurrowAttackController added:" .. unitID)
		local self = {}
		setmetatable(self,BurrowAttackControllerMT)
		self.unitID = unitID
		self.range = UnitDefs[GetUnitDefID(self.unitID)].decloakDistance
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("BurrowAttackController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,



	isEnemyInRange = function (self)
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+ENEMY_DETECT_BUFFER, Spring.ENEMY_UNITS)
		for i=1, #units do
			if  (GetUnitIsDead(units[i]) == false and self.isSelected == false) then
				GiveOrderToUnit(self.unitID,CMD_ATTACK, {units[i]}, 0)
				return
			end
		end
	end,


	handle=function(self)
		self.isSelected = IsUnitSelected(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		self:isEnemyInRange()
	end
}
BurrowAttackControllerMT = {__index=BurrowAttackController}

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Imp_ID or unitDefID == Snitch_ID)
		and (unitTeam==GetMyTeamID()) then
			BurrowBombStack[unitID] = BurrowAttackController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID)
	if not (BurrowBombStack[unitID]==nil) then
		BurrowBombStack[unitID]=BurrowBombStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for _,bomb in pairs(BurrowBombStack) do
			bomb:handle()
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
		if (unitDefID == Imp_ID or unitDefID == Snitch_ID)  then
			if  (BurrowBombStack[units[i]]==nil) then
				BurrowBombStack[units[i]]=BurrowAttackController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
