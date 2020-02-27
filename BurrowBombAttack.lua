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
local IsUnitSelected = Spring.IsUnitSelected
local GetTeamUnits = Spring.GetTeamUnits
local ENEMY_DETECT_BUFFER  = 50
local Echo = Spring.Echo
local Imp_NAME = "cloakbomb"
local Snitch_NAME = "shieldbomb"
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE


local BurrowAttackController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	isSelected = false,
	
	
	
	new = function(self, unitID)
		--Echo("BurrowAttackController added:" .. unitID)
		self = deepcopy(self)
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
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+ENEMY_DETECT_BUFFER)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				if  (GetUnitIsDead(units[i]) == false and self.isSelected == false) then
					GiveOrderToUnit(self.unitID,CMD_ATTACK, {units[i]}, 0)
					return
				end
			end
		end
	end,
	
	
	handle=function(self)
		self.isSelected = IsUnitSelected(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		self:isEnemyInRange()
	end
}

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Imp_NAME or UnitDefs[unitDefID].name==Snitch_NAME)
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
		if (UnitDefs[DefID].name==Imp_NAME or UnitDefs[DefID].name==Snitch_NAME)  then
			if  (BurrowBombStack[units[i]]==nil) then
				BurrowBombStack[units[i]]=BurrowAttackController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end

