function widget:GetInfo()
	return {
		name         = "FleaCloakSpotter",
		desc         = "attempt to make Flea search for cloaked units when Flea is decloaked by cloaked enemy unit. Version 0,97",
		author       = "terve886",
		date         = "2019",
		license      = "PD", -- should be compatible with Spring
		layer        = 10,
		enabled      = true
	}
end
local UPDATE_FRAME=5
local currentFrame = 0
local CloakerStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit

local Flea_NAME = "spiderscout"
local Blastwing_NAME = "gunshipbomb"
local Imp_NAME = "cloakbomb"
local Snitch_NAME = "shieldbomb"

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
local GetUnitHeading = Spring.GetUnitHeading
local team_id
local Echo = Spring.Echo
local pi = math.pi
local FULL_CIRCLE_RADIANT = 2 * pi
local HEADING_TO_RAD = (pi*2/65536 )
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_MOVE = CMD.MOVE
local CMD_ATTACK_MOVE_ID = 16
local HalfPi = math.pi/2
local atan = math.atan
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt

local GetSpecState = Spring.GetSpectatingState


local CloakToCloakSpotAI = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	cooldownFrame,
	reloadTime,
	enemyNear = false,


	new = function(self, unitID)
		--Echo("CloakToCloakSpotAI added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = UnitDefs[GetUnitDefID(self.unitID)].decloakDistance
		self.pos = {GetUnitPosition(self.unitID)}
		self.cooldownFrame = currentFrame+400
		local unitDefID = GetUnitDefID(self.unitID)
		self.reloadTime = WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].reload
		return self
	end,

	unset = function(self)
		--Echo("CloakToCloakSpotAI removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,


	isEnemyInRange = function (self)
		self.pos = {GetUnitPosition(self.unitID)}
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+40)
		for i=1, #units do
			if  not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				if  (GetUnitIsDead(units[i]) == false) then
					return true
				end
			end
		end
		return false
	end,

	handle = function(self)
		local unitStates = GetUnitStates(self.unitID)
		if(GetCommandQueue(self.unitID,0)==0)then
			self.reloadState = GetUnitWeaponState(self.unitID, 1, "reloadState")
			if(currentFrame >= self.reloadState-self.reloadTime+120)then
				if(self:isEnemyInRange()==false)then
					MarkerAddPoint (self.pos[1], self.pos[2], self.pos[3], "enemyCloakerNearby", true)
					local heading = GetUnitHeading(self.unitID)*HEADING_TO_RAD
					for i=0, 3 do

						local targetPosRelative = {
							sin(heading+i*HalfPi)*(self.range),
							nil,
							cos(heading+i*HalfPi)*(self.range),
						}

						local targetPosAbsolute= {
							targetPosRelative[1]+self.pos[1],
							nil,
							targetPosRelative[3]+self.pos[3],
						}

						GiveOrderToUnit(self.unitID, CMD_INSERT,{i, CMD_ATTACK_MOVE_ID, CMD_OPT_SHIFT, targetPosAbsolute[1], self.pos[2], targetPosAbsolute[3]},{"alt"})

					end

					GiveOrderToUnit(self.unitID, CMD_INSERT,{4, CMD_ATTACK_MOVE_ID, CMD_OPT_SHIFT, self.pos[1], self.pos[2], self.pos[3]},{"alt"})
					local targetPosRelative = {
						sin(heading)*(20),
						nil,
						cos(heading)*(20),
					}

					local targetPosAbsolute= {
						targetPosRelative[1]+self.pos[1],
						nil,
						targetPosRelative[3]+self.pos[3],
					}
					GiveOrderToUnit(self.unitID, CMD_INSERT,{5, CMD_ATTACK_MOVE_ID, CMD_OPT_SHIFT, targetPosAbsolute[1], self.pos[2], targetPosAbsolute[3]},{"alt"})
				end
			end
		end
	end
}
function widget:UnitDecloaked(unitID, unitDefID, teamID)
	if(CloakerStack[unitID])then
		CloakerStack[unitID]:handle();
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Flea_NAME
			and unitTeam==GetMyTeamID()) then
		CloakerStack[unitID] = CloakToCloakSpotAI:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (CloakerStack[unitID]==nil) then
		CloakerStack[unitID]=CloakerStack[unitID]:unset();
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if (CloakerStack[unitID] and damage~=0)then
		CloakerStack[unitID].cooldownFrame=currentFrame+40
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
		if (UnitDefs[DefID].name==Flea_NAME) then
			if  (CloakerStack[units[i]]==nil) then
				CloakerStack[units[i]]=CloakToCloakSpotAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
