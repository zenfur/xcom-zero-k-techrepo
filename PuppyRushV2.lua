function widget:GetInfo()
	return {
		name      = "PuppyRushV2",
		desc      = "Makes puppies shoot temselves towards enemy when enemy is close. Version 1.2",
		author    = "terve886",
		date      = "2019",
		license   = "PD", -- should be compatible with Spring
		layer     = 2,
		handler		= true, --for adding customCommand into UI
		enabled   = true  --  loaded by default?
	}
end

local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local ceil = math.ceil
local abs = math.abs
local HEADING_TO_RAD = (pi*2/65536 )
local UPDATE_FRAME=30
local PuppyStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local IsUnitSelected = Spring.IsUnitSelected
local GetUnitVelocity  = Spring.GetUnitVelocity
local GetUnitHeading = Spring.GetUnitHeading
local GetPlayerInfo = Spring.GetPlayerInfo
local GetMyPlayerID = Spring.GetMyPlayerID
local GetUnitArmored = Spring.GetUnitArmored
local myPlayerID = GetMyPlayerID()
local ping = 0
local ENEMY_DETECT_BUFFER  = 74
local Echo = Spring.Echo
local Puppy_NAME = "jumpscout"
local Swift_NAME = "planefighter"
local Owl_NAME = "planescout"
local GetSpecState = Spring.GetSpectatingState
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE
local CMD_REMOVE = CMD.REMOVE
local CMD_RAW_MOVE = 31109
local jumpCost = 15
local currentFrame = 0

local RushProduction = false
local CMD_TOGGLE_Rush = 19997
local CMD_TOGGLE_Rush_PRODUCTION = 19998
local PuppyUnitDefID = UnitDefNames["jumpscout"].id
local JumpFacUnitDefID = UnitDefNames["factoryjump"].id
local selectedPuppies = nil
local selectedJumpFacs = nil

local weaponDefID = UnitDefs[PuppyUnitDefID].weapons[1].weaponDef
local PuppyWeapon = WeaponDefs[weaponDefID]
local PuppyDamage =PuppyWeapon.damages[1]

local cmdRush = {
	id      = CMD_TOGGLE_Rush,
	type    = CMDTYPE.ICON,
	tooltip = 'Makes Puppy rocket rush enemies that get close.',
	action  = 'oneclickwep',
	params  = { },
	texture = 'LuaUI/Images/commands/Bold/dgun.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}

local cmdRushProduction = {
	id      = CMD_TOGGLE_Rush_PRODUCTION,
	type    = CMDTYPE.ICON,
	tooltip = 'Global toggle to Puppies starting with PuppyRush',
	action  = 'oneclickwep',
	params  = { },
	texture = 'LuaUI/Images/commands/Bold/dgun.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}


local RushController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	toggle = false,
	attackActive = 0,
	target = nil,
	forceTarget,


	new = function(self, unitID)
		--Echo("RushController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.toggle = RushProduction
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("RushController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	setForceTarget = function(self, param)
		self.forceTarget = param[1]
	end,

	getToggleState = function(self)
		return self.toggle
	end,

	toggleOn = function (self)
		Echo("PuppyRush ON!")
		self.toggle = true
	end,

	toggleOff = function (self)
		Echo("PuppyRush off")
		self.toggle = false
		GiveOrderToUnit(self.unitID, CMD_REMOVE, { CMD_ATTACK },{'alt'});
	end,


	getJumpCount = function(self)
		local hp = GetUnitHealth(self.unitID)
		if hp then
			local jumps = ceil(hp/jumpCost)
			if (jumps>3)then
				return 3
			else
				return jumps
			end
		end
		return 0
	end,


	isEnemyInRangeV2 = function (self)
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range+100*ping)

		for i=1, #units do
			if(self.target==units[i])then
				return true
			end
		end

		local target = nil
		for i=1, #units do
			if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				if  (GetUnitIsDead(units[i]) == false) then
					target = units[i]
					DefID = GetUnitDefID(target)
					if(DefID)then
						hp, mxhp, _, _, bp = GetUnitHealth(units[i])
						local hasArmor = GetUnitArmored(units[i])
						if (target==self.forceTarget or (GetUnitHealth(target) and GetUnitHealth(target)<=PuppyDamage and UnitDefs[DefID].metalCost > 51 and hasArmor == false and bp>0.8))then
							GiveOrderToUnit(self.unitID, CMD_ATTACK, target, 0)
							self.target = target
							return true
						end
					end
				end
			end
		end
		if(target)then
			GiveOrderToUnit(self.unitID, CMD_ATTACK, target, 0)
			self.target = target
			return true
		else
			return false
		end
	end,

	isEnemyInRushRange = function (self)
		if(self.attackActive<currentFrame)then
			local jumps = self:getJumpCount()
			local target = nil
			local units = GetUnitsInCylinder(self.pos[1], self.pos[3], (self.range-10)*jumps)
			for i=1, #units do
				if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then
					DefID = GetUnitDefID(units[i])
					if not(DefID == nil)then
						hp, mxhp, _, _, bp = GetUnitHealth(units[i])
						local hasArmor = GetUnitArmored(units[i])
						if  (GetUnitIsDead(units[i]) == false and UnitDefs[DefID].metalCost > 51 and bp > 0.8 and hasArmor == false and not(UnitDefs[DefID].name==Swift_NAME or UnitDefs[DefID].name==Owl_NAME)) then
							target = units[i]
							if (target==self.forceTarget)then
								break
							end
						end
					end
				end
			end
			if(target~=nil)then
				local enemyPosition = {GetUnitPosition(target)}
				local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
				local heading = GetUnitHeading(self.unitID)*HEADING_TO_RAD
				velocity = {GetUnitVelocity(self.unitID)}

				local targetPosRelative = {}
				local targetPosRelative2 = {}
				if(abs(velocity[1])+abs(velocity[3])>3)then
					if(self.pos[3]<=enemyPosition[3])then
						targetPosRelative={
							sin(rotation) * (self.range-10+90*ping*cos(abs(heading-rotation))),
							nil,
							cos(rotation) * (self.range-10+90*ping*cos(abs(heading-rotation))),
						}
						targetPosRelative2={
							sin(rotation) * (self.range+40+90*ping*cos(abs(heading-rotation))),
							nil,
							cos(rotation) * (self.range+40+90*ping*cos(abs(heading-rotation))),
						}
					else
						targetPosRelative={
							sin(rotation) * (self.range-10-90*ping*cos(abs(heading-rotation))),
							nil,
							cos(rotation) * (self.range-10-90*ping*cos(abs(heading-rotation))),
						}
						targetPosRelative2={
							sin(rotation) * (self.range+40-90*ping*cos(abs(heading-rotation))),
							nil,
							cos(rotation) * (self.range+40-90*ping*cos(abs(heading-rotation))),
						}
					end
				else
					targetPosRelative={
						sin(rotation) * (self.range-8),
						nil,
						cos(rotation) * (self.range-8),
					}

					targetPosRelative2={
						sin(rotation) * (self.range+40),
						nil,
						cos(rotation) * (self.range+40),
					}
				end

				local targetPosAbsolute = {}
				local movePosAbsolute = {}

				if (self.pos[3]<=enemyPosition[3]) then
					targetPosAbsolute = {
						self.pos[1]+targetPosRelative[1],
						nil,
						self.pos[3]+targetPosRelative[3],
					}
					movePosAbsolute = {
						self.pos[1]+targetPosRelative2[1],
						nil,
						self.pos[3]+targetPosRelative2[3],
					}
				else
					targetPosAbsolute = {
						self.pos[1]-targetPosRelative[1],
						nil,
						self.pos[3]-targetPosRelative[3],
					}
					movePosAbsolute = {
						self.pos[1]-targetPosRelative2[1],
						nil,
						self.pos[3]-targetPosRelative2[3],
					}
				end
				targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
				movePosAbsolute[2]= GetGroundHeight(movePosAbsolute[1],movePosAbsolute[3])
				GiveOrderToUnit(self.unitID, CMD_ATTACK, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)

				GiveOrderToUnit(self.unitID, CMD_INSERT,{1, CMD_RAW_MOVE, CMD_OPT_SHIFT, movePosAbsolute[1], movePosAbsolute[2], movePosAbsolute[3]}, {"alt"})
				self.attackActive = currentFrame+14
				return true
			else
				GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
				return false
			end
		end
	end,

	orderStop=function(self)
		if(self.attackActive == currentFrame)then
			GiveOrderToUnit(self.unitID, CMD_REMOVE, { CMD_ATTACK },{'alt'});
		end
	end,

	handle=function(self)
		if (self.toggle) then
			self:orderStop()
			self.pos = {GetUnitPosition(self.unitID)}
			if(self:isEnemyInRangeV2()) then
				return
			end
			self:isEnemyInRushRange()
		end
	end
}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (UnitDefs[unitDefID].name == Puppy_NAME and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		for _,Puppy in pairs(PuppyStack) do
			if(Puppy.unitID == unitID)then
				Puppy:setForceTarget(cmdParams)
				return
			end
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Puppy_NAME)
			and (unitTeam==GetMyTeamID()) then
		PuppyStack[unitID] = RushController:new(unitID);
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if (UnitDefs[unitDefID].name==Puppy_NAME)
			and not PuppyStack[unitID] then
		PuppyStack[unitID] = RushController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (PuppyStack[unitID]==nil) then
		PuppyStack[unitID]=PuppyStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	currentFrame = n
	local myInfo ={GetPlayerInfo(myPlayerID)}
	ping = myInfo[6]
	for _,Puppy in pairs(PuppyStack) do
		Puppy:handle()
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

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if (PuppyStack[unitID] and damage~=15 and damage~=0)then
		PuppyStack[unitID]:toggleOn()
	end
end
--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedPuppies ~= nil then
		if (cmdID == CMD_TOGGLE_Rush)then
			local toggleStateGot = false
			local toggleState
			for i=1, #selectedPuppies do
				if(PuppyStack[selectedPuppies[i]])then
					if (toggleStateGot == false)then
						toggleState = PuppyStack[selectedPuppies[i]]:getToggleState()
						toggleStateGot = true
					end
					if (toggleState) then
						PuppyStack[selectedPuppies[i]]:toggleOff()
					else
						PuppyStack[selectedPuppies[i]]:toggleOn()
					end
				end
			end
			return true
		end
	end
	if (cmdID == CMD_TOGGLE_Rush_PRODUCTION)then
		if (RushProduction)then
			RushProduction = false
			Echo("RushProduction turned OFF")
		else
			RushProduction = true
			Echo("RushProduction turned ON")
		end
		return true
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedPuppies = filterPuppies(selectedUnits)
	selectedJumpFacs = filterJumpFacs(selectedUnits)
end

function filterPuppies(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (PuppyUnitDefID == GetUnitDefID(unitID)) then
			n = n + 1
			filtered[n] = unitID
		end
	end
	if n == 0 then
		return nil
	else
		return filtered
	end
end


function filterJumpFacs(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (JumpFacUnitDefID == GetUnitDefID(unitID)) then
			n = n + 1
			filtered[n] = unitID
		end
	end
	if n == 0 then
		return nil
	else
		return filtered
	end
end

function widget:CommandsChanged()
	if selectedPuppies then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdRush
	end
	if selectedJumpFacs then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdRushProduction
	end
end



-- The rest of the code is there to disable the widget for spectators
local function DisableForSpec()
	if GetSpecState() then
		widgetHandler:RemoveWidget()
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(GetMyTeamID())
	for i=1, #units do
		unitID = units[i]
		DefID = GetUnitDefID(unitID)
		if (UnitDefs[DefID].name==Puppy_NAME)  then
			if  (PuppyStack[unitID]==nil) then
				PuppyStack[unitID]=RushController:new(unitID)
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
