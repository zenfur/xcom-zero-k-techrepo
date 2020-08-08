function widget:GetInfo()
   return {
      name         = "RazorCoverAI",
      desc         = "attempt to make Razor not engage AA if surrounded by ground enemy units. Version 1.0",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 10,
      enabled      = true
   }
end
local UPDATE_FRAME=10
local RazorStack = {}
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitArmored = Spring.GetUnitArmored
local Echo = Spring.Echo

local Razor_ID = UnitDefNames.turretaalaser.id
local ignoreDefIDs = {
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
  [UnitDefNames.energysolar.id] = true,
	[UnitDefNames.staticmex.id] = true
}
-- precalculate the unitDefIDs we want to ignore
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isAirUnit or unitDef.isBuilder and unitDef.energyStorage == 0 then
		ignoreDefIDs = true
	end
end

local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_FIRE_STATE = CMD.FIRE_STATE

local RazorAIMT
local RazorAI = {
	unitID,
	pos,
	range = 330,
	enemyNear = false,

	new = function(index, unitID)
		--Echo("RazorAI added:" .. unitID)
		local self = {}
		setmetatable(self, RazorAIMT)
		self.unitID = unitID
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("RazorAI removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,


	isEnemyInRange = function (self)
		if(GetUnitArmored(self.unitID))then
			local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range, Spring.ENEMY_UNITS)
			for i=1, #units do
				if (GetUnitIsDead(units[i]) == false) then
					local unitDefID = GetUnitDefID(units[i])
					if (unitDefID ~= nil and ignoreDefIDs[unitDefID]) then
						if (self.enemyNear == false)then
							GiveOrderToUnit(self.unitID,CMD_FIRE_STATE, 0, 0)
							self.enemyNear = true
						end
						return true
					end
				end
			end
		end
		if (self.enemyNear)then
			GiveOrderToUnit(self.unitID,CMD_FIRE_STATE, 2, 0)
		end
		self.enemyNear = false
		return false
	end,


	handle = function(self)
		self:isEnemyInRange()
	end
}
RazorAIMT = {__index=RazorAI}


function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Razor_ID)
		and (unitTeam==GetMyTeamID()) then
			RazorStack[unitID] = RazorAI:new(unitID);
		end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if ((unitDefID == Razor_ID)
		and not RazorStack[unitID]) then
			RazorStack[unitID] = RazorAI:new(unitID)
	end
end

function widget:UnitDestroyed(unitID)
	if not (RazorStack[unitID]==nil) then
		RazorStack[unitID]=RazorStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for _,unitID in pairs(RazorStack) do
			unitID:handle()
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
		if (unitDefID == Razor_ID) then
			if (RazorStack[units[i]]==nil) then
				RazorStack[units[i]]=RazorAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
