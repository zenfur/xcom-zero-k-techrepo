function widget:GetInfo()
   return {
      name         = "SolarCoverAI",
      desc         = "attempt to make Solar collector cover when enemy near. Version 1.01",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 10,
      enabled      = true
   }
end
local UPDATE_FRAME=10
local SolarStack = {}
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local Echo = Spring.Echo

local Solar_ID = UnitDefNames.energysolar.id
local Welder_ID = UnitDefNames.tankcon.id

local ignoreUnitDefs = {
	[UnitDefNames.planefighter.id] = true,
	[UnitDefNames.planeheavyfighter.id] = true,
	[UnitDefNames.gunshipaa.id] = true,
	[UnitDefNames.amphaa.id] = true,
	[UnitDefNames.cloakaa.id] = true,
	[UnitDefNames.hoveraa.id] = true,
	[UnitDefNames.jumpaa.id] = true,
	[UnitDefNames.shieldaa.id] = true,
	[UnitDefNames.shipaa.id] = true,
	[UnitDefNames.spideraa.id] = true,
	[UnitDefNames.tankaa.id] = true,
	[UnitDefNames.planescout.id] = true,
	[UnitDefNames.planelightscout.id] = true,
	[UnitDefNames.energywind.id] = true,
	[UnitDefNames.staticmex.id] = true,
	[Solar_ID] = true,
}
-- precalculate the unitDefIDs we want to ignore
for unitDefID,unitDef in pairs(UnitDefs) do
	if UnitDefs[unitDefID].isBuilder and UnitDefs[unitDefID].energyStorage == 0 and unitDefID ~= Welder_ID then
		ignoreUnitDefs[unitDefID] = true
	end
end

local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_ONOFF = 35667

local SolarAIMT
local SolarAI = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range = 450,
	enemyNear = false,

	new = function(index, unitID)
		--Echo("SolarAI added:" .. unitID)
		local self = {}
		setmetatable(self, SolarAIMT)
		self.unitID = unitID
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("SolarAI removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,


	isEnemyInRange = function (self)
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range, Spring.ENEMY_UNITS)
		for i=1, #units do
			if (GetUnitIsDead(units[i]) == false) then
				local unitDefID = GetUnitDefID(units[i])
				if (unitDefID ~= nil and not ignoreUnitDefs[unitDefID]) then
					if (self.enemyNear == false)then
						GiveOrderToUnit(self.unitID,CMD_ONOFF, 0,{""})
						self.enemyNear = true
					end
					return true
				end
			end
		end
		if (self.enemyNear)then
			GiveOrderToUnit(self.unitID,CMD_ONOFF, 1, {""})
		end
		self.enemyNear = false
		return false
	end,


	handle = function(self)
		self:isEnemyInRange()
	end
}
SolarAIMT = {__index=SolarAI}


function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Solar_ID)
		and (unitTeam==GetMyTeamID()) then
			SolarStack[unitID] = SolarAI:new(unitID);
		end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if ((unitDefID == Solar_ID)
		and not SolarStack[unitID]) then
			SolarStack[unitID] = SolarAI:new(unitID)
	end
end

function widget:UnitDestroyed(unitID)
	if not (SolarStack[unitID]==nil) then
		SolarStack[unitID]=SolarStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for _,solar in pairs(SolarStack) do
			solar:handle()
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
		if (unitDefID == Solar_ID)  then
			if (SolarStack[units[i]]==nil) then
				SolarStack[units[i]]=SolarAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
