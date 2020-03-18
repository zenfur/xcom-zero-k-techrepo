function widget:GetInfo()
	return {
		name         = "JumpDodgeAI",
		desc         = "attempt to make jumpers jump away from hostile kamikaze units. Version 0,99",
		author       = "terve886",
		date         = "2019",
		license      = "PD", -- should be compatible with Spring
		layer        = 11,
		enabled      = true
	}
end

local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local UPDATE_FRAME=4
local currentFrame = 0
local UnitStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local Jugglenaut_NAME = "jumpsumo"
local Dirtbag_NAME ="shieldscout"
local Imp_NAME = "cloakbomb"
local Scuttle_NAME = "jumpbomb"
local Snitch_NAME = "shieldbomb"
local Limpet_NAME = "amphbomb"
local Widow_NAME = "spiderantiheavy"
local Ultimatum_NAME = "striderantiheavy"
local ENEMY_DETECT_BUFFER  = 35
local Echo = Spring.Echo
local GetSpecState = Spring.GetSpectatingState
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK
local CMD_JUMP = 38521


local JumpToAvoidSuiciderController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	jumpRange,
	jumpTarget,
	jumpOnCooldown = currentFrame,
	jumpCooldown,
	unitCost,


	new = function(self, unitID)
		--Echo("JumpToAvoidSuiciderController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		local unitDefID = GetUnitDefID(self.unitID)
		self.jumpRange = UnitDefs[unitDefID].customParams.jump_range
		self.jumpCooldown =UnitDefs[unitDefID].customParams.jump_reload*40
		self.jumpOnCooldown = currentFrame
		self.pos = {GetUnitPosition(self.unitID)}
		self.jumpTarget = {GetUnitPosition(self.unitID)}
		self.unitCost = UnitDefs[unitDefID].metalCost
		return self
	end,

	unset = function(self)
		--Echo("JumpToAvoidSuiciderController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	trackJumpCooldown = function(self)
		self.jumpOnCooldown = currentFrame+self.jumpCooldown
	end,

	--Jump always towards factory the unit was made/spawnpoint
	isSuiciderTooClose = function (self)
		self.pos = {GetUnitPosition(self.unitID)}
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], 210)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				if  (GetUnitIsDead(units[i]) == false) then
					local DefID = GetUnitDefID(units[i])
					if not(DefID == nil)then
						if (UnitDefs[DefID].name==Snitch_NAME or UnitDefs[DefID].name==Limpet_NAME or UnitDefs[DefID].name==Imp_NAME or UnitDefs[DefID].name==Scuttle_NAME or
								(UnitDefs[DefID].name==Widow_NAME and self.unitCost>=570) or
								(string.match(UnitDefs[DefID].name, "dyn") and UnitDefs[DefID].weapons[2] and WeaponDefs[UnitDefs[DefID].weapons[2].weaponDef]
										and WeaponDefs[UnitDefs[DefID].weapons[2].weaponDef].damages[1]>=2000 and self.unitCost>=900))then

							local rotation = atan((self.pos[1]-self.jumpTarget[1])/(self.pos[3]-self.jumpTarget[3]))
							local targetPosRelative={
								sin(rotation) * (self.jumpRange-30),
								nil,
								cos(rotation) * (self.jumpRange-30),
							}

							local targetPosAbsolute = {}
							if (self.pos[3]<=self.jumpTarget[3]) then
								targetPosAbsolute = {
									self.pos[1]+targetPosRelative[1],
									nil,
									self.pos[3]+targetPosRelative[3],
								}
							else
								targetPosAbsolute = {
									self.pos[1]-targetPosRelative[1],
									nil,
									self.pos[3]-targetPosRelative[3],
								}
							end
							targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
							GiveOrderToUnit(self.unitID,CMD_JUMP, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
							return true
						end
					end
				end
			end
		end
		return false
	end,

	--Jump always away from the bomb unit
	isSuiciderTooCloseV2 = function (self)
		self.pos = {GetUnitPosition(self.unitID)}
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], 210)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				if  (GetUnitIsDead(units[i]) == false) then
					local DefID = GetUnitDefID(units[i])
					if not(DefID == nil)then
						if (UnitDefs[DefID].name==Snitch_NAME or UnitDefs[DefID].name==Limpet_NAME or UnitDefs[DefID].name==Imp_NAME or UnitDefs[DefID].name==Scuttle_NAME or
								((UnitDefs[DefID].name==Widow_NAME or UnitDefs[DefID].name==Ultimatum_NAME) and self.unitCost>=570) or
								(string.match(UnitDefs[DefID].name, "dyn") and UnitDefs[DefID].weapons[2] and WeaponDefs[UnitDefs[DefID].weapons[2].weaponDef]
										and WeaponDefs[UnitDefs[DefID].weapons[2].weaponDef].damages[1]>=2000 and self.unitCost>=900))then
							local enemyPosition = {GetUnitPosition(units[i])}

							local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
							local targetPosRelative={
								sin(rotation) * (self.jumpRange-30),
								nil,
								cos(rotation) * (self.jumpRange-30),
							}

							local targetPosAbsolute = {}
							if (self.pos[3]<=enemyPosition[3]) then
								targetPosAbsolute = {
									self.pos[1]-targetPosRelative[1],
									nil,
									self.pos[3]-targetPosRelative[3],
								}
							else
								targetPosAbsolute = {
									self.pos[1]+targetPosRelative[1],
									nil,
									self.pos[3]+targetPosRelative[3],
								}
							end
							targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
							GiveOrderToUnit(self.unitID,CMD_JUMP, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
							return true
						end
					end
				end
			end
		end
		return false
	end,

	handle=function(self)
		if(self.jumpOnCooldown <= currentFrame)then
			self:isSuiciderTooCloseV2()
		end
	end
}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (cmdID == CMD_JUMP) then
		if (UnitStack[unitID])then
			UnitStack[unitID]:trackJumpCooldown()
		end
	end
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	custom = UnitDefs[unitDefID].customParams
	if(unitTeam==GetMyTeamID() and UnitDefs[unitDefID].isBuilding == false and custom.canjump and custom.canjump=='1' and not(UnitDefs[unitDefID].name==Jugglenaut_NAME or UnitDefs[unitDefID].name==Scuttle_NAME)) then
		UnitStack[unitID] = JumpToAvoidSuiciderController:new(unitID);
	end
end


function widget:UnitDestroyed(unitID)
	if not (UnitStack[unitID]==nil) then
		UnitStack[unitID]=UnitStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	currentFrame = n
	if (n%UPDATE_FRAME==0) then
		for _,unit in pairs(UnitStack) do
			unit:handle()
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
		unitDefID = GetUnitDefID(units[i])
		custom = UnitDefs[unitDefID].customParams
		if(custom.canjump and UnitDefs[unitDefID].isBuilding == false and custom.canjump=='1' and not(UnitDefs[unitDefID].name==Jugglenaut_NAME or UnitDefs[unitDefID].name==Scuttle_NAME or UnitDefs[unitDefID].name==Dirtbag_NAME)) then
			UnitStack[units[i]] = JumpToAvoidSuiciderController:new(units[i]);
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end

