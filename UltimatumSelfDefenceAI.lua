function widget:GetInfo()
   return {
      name         = "UltimatumSelfDefenceAI",
      desc         = "attempt to make Ultimatum kill nearby high value targets if decloaked. Version 0,97",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 10,
      enabled      = true
   }
end
local UPDATE_FRAME=5
local currentFrame = 0
local StriderStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit


local Ultimatum_NAME = "striderantiheavy"
local Scorpion_NAME = "striderscorpion"
local Dante_NAME = "striderdante"

local GetUnitWeaponState = Spring.GetUnitWeaponState
local GetUnitIsCloaked = Spring.GetUnitIsCloaked
local GetUnitStates = Spring.GetUnitStates
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local IsUnitSelected = Spring.IsUnitSelected
local GetTeamUnits = Spring.GetTeamUnits
local GetTeamResources = Spring.GetTeamResources
local MarkerAddPoint = Spring.MarkerAddPoint
local GetCommandQueue = Spring.GetCommandQueue
local team_id
local Echo = Spring.Echo
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_MOVE = CMD.MOVE
local CMD_ATTACK_MOVE_ID = 16

local GetSpecState = Spring.GetSpectatingState


local UltimatumSelfDefenceAI = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	cooldownFrame,
	reloadTime,
	enemyNear = false,

	
	new = function(self, unitID)
		--Echo("UltimatumSelfDefenceAI added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		self.cooldownFrame = currentFrame+400
		local unitDefID = GetUnitDefID(self.unitID)
		self.reloadTime = WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].reload
		return self
	end,

	unset = function(self)
		--Echo("UltimatumSelfDefenceAI removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	isThreatInRange = function (self)
		if(GetUnitIsCloaked(self.unitID)==false)then
			self.pos = {GetUnitPosition(self.unitID)}
			local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+40)
			for i=1, #units do
				if  not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
					if  (GetUnitIsDead(units[i]) == false) then
						DefID = GetUnitDefID(units[i])
						if not(DefID == nil)then
							if(UnitDefs[DefID].metalCost >= 1500 and UnitDefs[DefID].isAirUnit==false)then
								GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
								return true
							end
						end
					end
				end
			end
		end
		return false
	end
}

function widget:GameFrame(n) 
	for _,Strider in pairs(StriderStack) do
		Strider:isThreatInRange()
	end
end



function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Ultimatum_NAME
	and unitTeam==GetMyTeamID()) then
		StriderStack[unitID] = UltimatumSelfDefenceAI:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (StriderStack[unitID]==nil) then
		StriderStack[unitID]=StriderStack[unitID]:unset();
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if (StriderStack[unitID] and damage~=0)then
		StriderStack[unitID].cooldownFrame=currentFrame+40
	end
end

function widget:GameFrame(n) 
	currentFrame = n
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
	team_id = Spring.GetMyTeamID()
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==Ultimatum_NAME) then
			if  (StriderStack[units[i]]==nil) then
				StriderStack[units[i]]=UltimatumSelfDefenceAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
