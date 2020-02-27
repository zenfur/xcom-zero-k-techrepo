function widget:GetInfo()
   return {
      name         = "ScorpionAndDanteSelfDefenceAI",
      desc         = "attempt to make Scorpion use Stun barrage against high threat targets or when low on health. Version 0,97",
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

local GetUnitHealth = Spring.GetUnitHealth
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
local CMD_Dgun = 105

local GetSpecState = Spring.GetSpectatingState


local ScorpionAndDanteSelfDefenceAI = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	cooldownFrame,
	reloadTime,
	maxHealth,

	
	new = function(self, unitID)
		--Echo("ScorpionAndDanteSelfDefenceAI added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		self.cooldownFrame = currentFrame+400
		self.maxHealth = UnitDefs[GetUnitDefID(self.unitID)].health
		local unitDefID = GetUnitDefID(self.unitID)
		self.reloadTime = WeaponDefs[UnitDefs[unitDefID].weapons[3].weaponDef].reload
		return self
	end,

	unset = function(self)
		--Echo("ScorpionAndDanteSelfDefenceAI removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	isThreatInRange = function (self)
		if(GetUnitHealth(self.unitID)<self.maxHealth*0.3)then --is Health Critical?
			if(GetUnitIsCloaked(self.unitID)==false and self.cooldownFrame<currentFrame and GetUnitWeaponState(self.unitID, 3, "reloadState") <= currentFrame)then --Health is critical
				self.pos = {GetUnitPosition(self.unitID)}
				local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+40)
				for i=1, #units do
					if  not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
						if  (GetUnitIsDead(units[i]) == false) then
							DefID = GetUnitDefID(units[i])
							if not(DefID == nil)then
								if(UnitDefs[DefID].metalCost >= 1500 and UnitDefs[DefID].isAirUnit==false)then
									GiveOrderToUnit(self.unitID,CMD_INSERT, {0, CMD_Dgun, CMD_OPT_SHIFT, units[i]}, {"alt"})
									self.cooldownFrame = currentFrame+40
									return true
								end
								enemyposition = {GetUnitPosition(units[i])}
								if (#GetUnitsInSphere(enemyposition[1],enemyposition[2],enemyposition[3], 180, self.allyTeamID)==0)then	
									GiveOrderToUnit(self.unitID,CMD_INSERT, {0, CMD_Dgun, CMD_OPT_SHIFT, units[i]}, {"alt"})
									self.cooldownFrame = currentFrame+40
									return true
								end
							end
						end
					end
				end
			end
		else --Health is not critical
		if(GetUnitIsCloaked(self.unitID)==false and self.cooldownFrame<currentFrame and GetUnitWeaponState(self.unitID, 3, "reloadState") <= currentFrame)then
				self.pos = {GetUnitPosition(self.unitID)}
				local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+40)
				for i=1, #units do
					if  not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
						if  (GetUnitIsDead(units[i]) == false) then
							DefID = GetUnitDefID(units[i])
							if not(DefID == nil)then
								if(UnitDefs[DefID].metalCost >= 1500 and UnitDefs[DefID].isAirUnit==false)then
									GiveOrderToUnit(self.unitID,CMD_INSERT, {0, CMD_Dgun, CMD_OPT_SHIFT, units[i]}, {"alt"})
									self.cooldownFrame = currentFrame+40
									return true
								end
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
	currentFrame = n
	for _,Strider in pairs(StriderStack) do
		Strider:isThreatInRange()
	end
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if ((UnitDefs[unitDefID].name==Scorpion_NAME or  UnitDefs[unitDefID].name==Dante_NAME) and unitTeam==GetMyTeamID()) then
		StriderStack[unitID] = ScorpionAndDanteSelfDefenceAI:new(unitID);
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
		if (UnitDefs[DefID].name==Scorpion_NAME or UnitDefs[DefID].name==Dante_NAME) then
			if  (StriderStack[units[i]]==nil) then
				StriderStack[units[i]]=ScorpionAndDanteSelfDefenceAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
