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

local sin = math.sin
local cos = math.cos
local atan = math.atan
local UPDATE_FRAME=4
local currentFrame = 0
local UnitStack = {}
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local Jugglenaut_ID = UnitDefNames.jumpsumo.id
local Dirtbag_ID = UnitDefNames.shieldscout.id
local Imp_ID = UnitDefNames.cloakbomb.id
local Scuttle_ID = UnitDefNames.jumpbomb.id
local Snitch_ID = UnitDefNames.shieldbomb.id
local Limpet_ID = UnitDefNames.amphbomb.id
local Widow_ID = UnitDefNames.spiderantiheavy.id
local Ultimatum_ID = UnitDefNames.striderantiheavy.id
local Echo = Spring.Echo
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_JUMP = 38521


local JumpToAvoidSuiciderControllerMT
local JumpToAvoidSuiciderController = {
	unitID,
	pos,
	jumpRange,
	jumpTarget,
	jumpOnCooldown = currentFrame,
	jumpCooldown,
	unitCost,


	new = function(index, unitID)
		--Echo("JumpToAvoidSuiciderController added:" .. unitID)
		local self = {}
		setmetatable(self,JumpToAvoidSuiciderControllerMT)
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
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], 210, Spring.ENEMY_UNITS)
		for i=1, #units do
			if  (GetUnitIsDead(units[i]) == false) then
				local unitDefID = GetUnitDefID(units[i])
				if not(unitDefID == nil)then
					if (unitDefID == Snitch_ID or unitDefID == Limpet_ID or unitDefID == Imp_ID or unitDefID == Scuttle_ID or
							(unitDefID == Widow_ID and self.unitCost>=570) or
							(UnitDefIDHasSecondaryDisintegrator(unitDefID) and self.unitCost>=900))then

						local rotation = atan((self.pos[1]-self.jumpTarget[1])/(self.pos[3]-self.jumpTarget[3]))
						local targetPosRelative={
							sin(rotation) * (self.jumpRange-30),
							nil,
							cos(rotation) * (self.jumpRange-30),
						}

						local targetPosAbsolute
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
		return false
	end,

	--Jump always away from the bomb unit
	isSuiciderTooCloseV2 = function (self)
		self.pos = {GetUnitPosition(self.unitID)}
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], 210, Spring.ENEMY_UNITS)
		for i=1, #units do
			if  (GetUnitIsDead(units[i]) == false) then
				local unitDefID = GetUnitDefID(units[i])
				if not(unitDefID == nil)then
					if (unitDefID == Snitch_ID or unitDefID == Limpet_ID or unitDefID == Imp_ID or unitDefID == Scuttle_ID or
							((unitDefID == Widow_ID or unitDefID == Ultimatum_ID) and self.unitCost>=570) or (UnitDefIDHasSecondaryDisintegrator(unitDefID) and self.unitCost>=900)
							)then
						local enemyPosition = {GetUnitPosition(units[i])}

						local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
						local targetPosRelative={
							sin(rotation) * (self.jumpRange-30),
							nil,
							cos(rotation) * (self.jumpRange-30),
						}

						local targetPosAbsolute
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
		return false
	end,

	handle=function(self)
		if(self.jumpOnCooldown <= currentFrame)then
			self:isSuiciderTooCloseV2()
		end
	end
}
JumpToAvoidSuiciderControllerMT={__index=JumpToAvoidSuiciderController}

function UnitDefIDHasSecondaryDisintegrator(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	if not string.match(unitDef.name, "dyn") then return false end
	local secondaryWeapon = unitDef.weapons[2]
	if not secondaryWeapon then return false end
	local weaponDef = WeaponDefs[secondaryWeapon.weaponDef]
	if not weaponDef then return false end
	return weaponDef.damages[1] >= 2000
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (cmdID == CMD_JUMP) then
		if (UnitStack[unitID])then
			UnitStack[unitID]:trackJumpCooldown()
		end
	end
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam ~= GetMyTeamID() then return end
	local unitDef = UnitDefs[unitDefID]
	local custom = unitDef.customParams
	if(unitDef.isBuilding == false and custom.canjump and custom.canjump=='1' and not(unitDefID == Jugglenaut_ID or unitDefID == Scuttle_ID)) then
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
		local unitDef = UnitDefs[unitDefID]
		local custom = unitDef.customParams
		if(custom.canjump and unitDef.isBuilding == false and custom.canjump=='1' and not(unitDefID == Jugglenaut_ID or unitDefID == Scuttle_ID or unitDefID == Dirtbag_ID)) then
			UnitStack[units[i]] = JumpToAvoidSuiciderController:new(units[i]);
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
