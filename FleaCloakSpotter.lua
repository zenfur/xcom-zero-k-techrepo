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
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit

local Flea_ID = "spiderscout"

local GetUnitWeaponState = Spring.GetUnitWeaponState
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local MarkerAddPoint = Spring.MarkerAddPoint
local GetCommandQueue = Spring.GetCommandQueue
local GetUnitHeading = Spring.GetUnitHeading
local Echo = Spring.Echo
local pi = math.pi
local HEADING_TO_RAD = (pi*2/65536 )
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_ATTACK_MOVE_ID = 16
local HalfPi = math.pi/2
local sin = math.sin
local cos = math.cos

local GetSpecState = Spring.GetSpectatingState


local CloakToCloakSpotAIMT
local CloakToCloakSpotAI = {
	unitID,
	pos,
	range,
	cooldownFrame,
	reloadTime,
	enemyNear = false,


	new = function(index, unitID)
		--Echo("CloakToCloakSpotAI added:" .. unitID)
		local self = {}
		setmetatable(self,CloakToCloakSpotAIMT)
		self.unitID = unitID
		self.range = UnitDefs[GetUnitDefID(self.unitID)].decloakDistance
		self.pos = {GetUnitPosition(self.unitID)}
		self.cooldownFrame = currentFrame+8
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
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+40, Spring.ENEMY_UNITS)
		for i=1, #units do
			if  (GetUnitIsDead(units[i]) == false) then
				return true
			end
		end
		return false
	end,

	handle = function(self)
		--local unitStates = GetUnitStates(self.unitID)
		if(GetCommandQueue(self.unitID,0)==0)then
			self.reloadState = GetUnitWeaponState(self.unitID, 1, "reloadState")
			if(currentFrame >= self.reloadState-self.reloadTime+120 and currentFrame >= self.cooldownFrame)then
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
CloakToCloakSpotAIMT={__index=CloakToCloakSpotAI}
function widget:UnitDecloaked(unitID, unitDefID, teamID)
	if(CloakerStack[unitID])then
		CloakerStack[unitID]:handle();
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (unitDefID == Flea_ID
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
		CloakerStack[unitID].cooldownFrame=currentFrame+8
	end
end

function widget:GameFrame(n)
	currentFrame = n
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
		if (unitDefID == Flea_ID) then
			if  (CloakerStack[units[i]]==nil) then
				CloakerStack[units[i]]=CloakToCloakSpotAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
