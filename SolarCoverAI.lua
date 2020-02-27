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
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local IsUnitSelected = Spring.IsUnitSelected
local GetTeamUnits = Spring.GetTeamUnits
local Echo = Spring.Echo
local Solar_NAME = "energysolar"
local Wind_NAME = "energywind"
local Swift_NAME = "planefighter"
local Owl_NAME = "planescout"
local Raptor_NAME = "planeheavyfighter"
local Trident_NAME = "gunshipaa"
local Angler_NAME = "amphaa"
local Germlin_NAME = "cloakaa"
local Flail_NAME = "hoveraa"
local Toad_NAME = "jumpaa"
local Vandal_NAME = "shieldaa"
local Zephyr_NAME = "shipaa"
local Tarantula_NAME = "spideraa"
local Ettin_NAME = "tankaa"
local Gnat_NAME = "gunshipemp"
local Widow_NAME = "spiderantiheavy"
local Welder_NAME = "tankcon"
local Metal_NAME = "staticmex"

local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_ONOFF = 35667

local SolarAI = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range = 450,
	enemyNear = false,
	
	new = function(self, unitID)
		--Echo("SolarAI added:" .. unitID)
		self = deepcopy(self)
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
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				if  (GetUnitIsDead(units[i]) == false) then
					DefID = GetUnitDefID(units[i])
					if (DefID ~= nil and not(UnitDefs[DefID].isBuilder and UnitDefs[DefID].energyStorage == 0 and UnitDefs[DefID].name~=Welder_NAME
					or UnitDefs[DefID].name==Swift_NAME
					or UnitDefs[DefID].name==Raptor_NAME
					or UnitDefs[DefID].name==Trident_NAME
					or UnitDefs[DefID].name==Angler_NAME
					or UnitDefs[DefID].name==Germlin_NAME
					or UnitDefs[DefID].name==Toad_NAME
					or UnitDefs[DefID].name==Flail_NAME
					or UnitDefs[DefID].name==Vandal_NAME
					or UnitDefs[DefID].name==Tarantula_NAME
					or UnitDefs[DefID].name==Ettin_NAME
					or UnitDefs[DefID].name==Gnat_NAME
					or UnitDefs[DefID].name==Widow_NAME
					or UnitDefs[DefID].name==Solar_NAME
					or UnitDefs[DefID].name==Zephyr_NAME
					or UnitDefs[DefID].name==Wind_NAME
					or UnitDefs[DefID].name==Metal_NAME
					or UnitDefs[DefID].name==Owl_NAME))then
						if (self.enemyNear == false)then
							GiveOrderToUnit(self.unitID,CMD_ONOFF, 0,{""})
							self.enemyNear = true
						end
						return true
					end
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


function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Solar_NAME)
		and (unitTeam==GetMyTeamID()) then
			SolarStack[unitID] = SolarAI:new(unitID);
		end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if ((UnitDefs[unitDefID].name==Solar_NAME)
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
		if (UnitDefs[DefID].name==Solar_NAME)  then
			if  (SolarStack[units[i]]==nil) then
				SolarStack[units[i]]=SolarAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
