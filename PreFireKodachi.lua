function widget:GetInfo()
	return {
		name         = "PreFireKodachi",
		desc         = "attempt to make Kodachi fire targets that are in max range + AoE range. Version 1.00",
		author       = "terve886",
		date         = "2019",
		license      = "PD", -- should be compatible with Spring
		layer        = 11,
		handler		= true, --for adding customCommand into UI
		enabled      = true
	}
end

local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local abs = math.abs
local sqrt = math.sqrt
local HEADING_TO_RAD = (pi*2/65536 )
local UPDATE_FRAME=5
local currentFrame = 0
local KodachiStack = {}
local GetUnitHeading = Spring.GetUnitHeading
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
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local GetPlayerInfo = Spring.GetPlayerInfo
local GetMyPlayerID = Spring.GetMyPlayerID
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local GetUnitVelocity  = Spring.GetUnitVelocity
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local ENEMY_DETECT_BUFFER  = 80
local Echo = Spring.Echo
local ping = 0
local Kodachi_NAME = "tankraid"
local GetSpecState = Spring.GetSpectatingState
local myPlayerID = GetMyPlayerID()
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_MOVE = CMD.MOVE
local CMD_ATTACK_MOVE_ID = 16
local CMD_MOVE_ID = 10
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT

local selectedKodachis = nil
local CMD_SHOOT_BEHIND = 19839
local KodachiUnitDefID = UnitDefNames["tankraid"].id

local cmdForcePreFire = {
	id      = CMD_SHOOT_BEHIND,
	type    = CMDTYPE.ICON,
	tooltip = 'Makes Kodachi shoot towards enemy closest to it.',
	action  = 'oneclickwep',
	params  = { },
	texture = 'unitpics/weaponmod_flame_enhancer.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}


local KodachiController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	attackMove = false,
	targetFrame = 0,
	damage,


	new = function(self, unitID)
		--Echo("KodachiController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)-6
		self.pos = {GetUnitPosition(self.unitID)}
		local unitDefID = GetUnitDefID(self.unitID)
		local weaponDefID = UnitDefs[unitDefID].weapons[1].weaponDef
		local wd = WeaponDefs[weaponDefID]
		self.damage = wd.damages[4]
		return self
	end,

	unset = function(self)
		--Echo("KodachiController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD.STOP, {}, {""},1)
		return nil
	end,

	toggleOn = function (self)
		self.attackMove = true
	end,

	toggleOff = function (self)
		self.attackMove = false
	end,

	isEnemyInRange = function (self)
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range-20)
		for i=1, #units do
			if not (GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				enemyPosition = {GetUnitPosition(units[i])}
				if(enemyPosition[2]>-30)then
					DefID = GetUnitDefID(units[i])
					if (GetUnitIsDead(units[i]) == false and UnitDefs[DefID].isAirUnit==false)then
						GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
						return true
					end
				end
			end
		end
	end,

	forcePreFire = function(self)
		self.pos = {GetUnitPosition(self.unitID)}
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+550, false)
		if(enemyUnitID)then
			DefID = GetUnitDefID(enemyUnitID)
			if not(DefID == nil)then
				if (GetUnitIsDead(enemyUnitID) == false and UnitDefs[DefID].isAirUnit==false) then
					local enemyPosition = {GetUnitPosition(enemyUnitID)}
					local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
					local heading = GetUnitHeading(self.unitID)*HEADING_TO_RAD
					local myInfo ={GetPlayerInfo(myPlayerID)}
					local ping = myInfo[6]
					velocity = {GetUnitVelocity(self.unitID)}
					local targetPosRelative = {}
					if(abs(velocity[1])+abs(velocity[3])>2)then
						if (self.pos[3]<=enemyPosition[3]) then
							targetPosRelative={
								sin(rotation) * (self.range-10+147*ping*cos(abs(heading-rotation))),
								nil,
								cos(rotation) * (self.range-10+147*ping*cos(abs(heading-rotation))),
							}
						else
							targetPosRelative={
								sin(rotation) * (self.range-10-147*ping*cos(abs(heading-rotation))),
								nil,
								cos(rotation) * (self.range-10-147*ping*cos(abs(heading-rotation))),
							}
						end
					else
						targetPosRelative={
							sin(rotation) * (self.range-8),
							nil,
							cos(rotation) * (self.range-8),
						}
					end

					local targetPosAbsolute = {}
					if (self.pos[3]<=enemyPosition[3]) then
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
					GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
					self.targetFrame = currentFrame+30
					return true
				end
			end
		end
		GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
		return false
	end,

	isEnemyInEffectiveRange = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+ENEMY_DETECT_BUFFER, false)
		if(enemyUnitID)then
			DefID = GetUnitDefID(enemyUnitID)
			if not(DefID == nil)then
				if (GetUnitIsDead(enemyUnitID) == false and UnitDefs[DefID].isAirUnit==false) then
					local enemyPosition = {GetUnitPosition(enemyUnitID)}
					local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
					local heading = GetUnitHeading(self.unitID)*HEADING_TO_RAD

					velocity = {GetUnitVelocity(self.unitID)}
					local targetPosRelative = {}
					if(abs(velocity[1])+abs(velocity[3])>2)then
						if (self.pos[3]<=enemyPosition[3]) then
							targetPosRelative={
								sin(rotation) * (self.range-10+132*ping*cos(abs(heading-rotation))),
								nil,
								cos(rotation) * (self.range-10+132*ping*cos(abs(heading-rotation))),
							}
						else
							targetPosRelative={
								sin(rotation) * (self.range-10-132*ping*cos(abs(heading-rotation))),
								nil,
								cos(rotation) * (self.range-10-132*ping*cos(abs(heading-rotation))),
							}
						end
					else
						targetPosRelative={
							sin(rotation) * (self.range-8),
							nil,
							cos(rotation) * (self.range-8),
						}
					end

					local targetPosAbsolute = {}
					if (self.pos[3]<=enemyPosition[3]) then
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
					GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
					if (UnitDefs[DefID].isBuilding==false and self.attackMove) then
						if (self.pos[3]<=enemyPosition[3]) then
							GiveOrderToUnit(self.unitID,CMD_MOVE, {self.pos[1]-(targetPosRelative[1]+150), 50, self.pos[3]-(targetPosRelative[3]+150)}, 0)
						else
							GiveOrderToUnit(self.unitID,CMD_MOVE, {self.pos[1]+(targetPosRelative[1]+150), 50, self.pos[3]+(targetPosRelative[3]+150)}, 0)
						end
					end
					return true
				end
			end
		end
		GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
		return false
	end,

	isShieldInEffectiveRange = function (self)
		closestShieldID = nil
		closestShieldDistance = nil
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+320)
		for i=1, #units do
			if not(GetUnitAllyTeam(units[i]) == self.allyTeamID) then
				DefID = GetUnitDefID(units[i])
				if not(DefID == nil)then
					if (GetUnitIsDead(units[i]) == false and UnitDefs[DefID].hasShield == true) then
						local shieldHealth = {GetUnitShieldState(units[i])}
						if (shieldHealth[2] and self.damage <= shieldHealth[2])then
							local enemyPositionX, enemyPositionY, enemyPositionZ = GetUnitPosition(units[i])

							local targetShieldRadius
							if (UnitDefs[DefID].weapons[2] == nil)then
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[1].weaponDef].shieldRadius
							else
								targetShieldRadius = WeaponDefs[UnitDefs[DefID].weapons[2].weaponDef].shieldRadius
							end

							enemyShieldDistance = distance(self.pos[1], enemyPositionX, self.pos[3], enemyPositionZ)-targetShieldRadius
							if not(closestShieldDistance)then
								closestShieldDistance = enemyShieldDistance
								closestShieldID = units[i]
								closestShieldRadius = targetShieldRadius
								rotation = atan((self.pos[1]-enemyPositionX)/(self.pos[3]-enemyPositionZ))
							end

							if (enemyShieldDistance < closestShieldDistance and enemyShieldDistance > 20) then
								closestShieldDistance = enemyShieldDistance
								closestShieldID = units[i]
								closestShieldRadius = targetShieldRadius
								rotation = atan((self.pos[1]-enemyPositionX)/(self.pos[3]-enemyPositionZ))
							end
						end
					end
				end
			end
		end
		if(closestShieldID ~= nil)then
			local enemyPositionX, enemyPositionY, enemyPositionZ = GetUnitPosition(closestShieldID)
			local targetPosRelative={
				sin(rotation) * (closestShieldRadius-14),
				nil,
				cos(rotation) * (closestShieldRadius-14),
			}

			local targetPosAbsolute = {}
			if (self.pos[3]<=enemyPositionZ) then
				targetPosAbsolute = {
					enemyPositionX-targetPosRelative[1],
					nil,
					enemyPositionZ-targetPosRelative[3],
				}
			else
				targetPosAbsolute = {
					enemyPositionX+targetPosRelative[1],
					nil,
					enemyPositionZ+targetPosRelative[3],
				}
			end
			targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
			GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
		else
			GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
		end
	end,

	handle=function(self)
		if (self.targetFrame<currentFrame) then
			self.pos = {GetUnitPosition(self.unitID)}
			if (self:isEnemyInRange())then
				return
			end
			if(self:isEnemyInEffectiveRange())then
				return
			end
			self:isShieldInEffectiveRange()
		end
	end
}

function distance ( x1, y1, x2, y2 )
	local dx = (x1 - x2)
	local dy = (y1 - y2)
	return sqrt ( dx * dx + dy * dy )
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (KodachiStack[unitID])then
		if (cmdID == CMD_ATTACK_MOVE_ID or cmdID == CMD_MOVE_ID) then
			KodachiStack[unitID]:toggleOn()
		else
			KodachiStack[unitID]:toggleOff()
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Kodachi_NAME)
			and (unitTeam==GetMyTeamID()) then
		KodachiStack[unitID] = KodachiController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (KodachiStack[unitID]==nil) then
		KodachiStack[unitID]=KodachiStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	currentFrame = n
	if (n%UPDATE_FRAME==0) then
		local myInfo ={GetPlayerInfo(myPlayerID)}
		ping = myInfo[6]
		for _,kodachi in pairs(KodachiStack) do
			kodachi:handle()
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

--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedKodachis ~= nil then
		if (cmdID == CMD_SHOOT_BEHIND)then
			local toggleStateGot = false
			local toggleState
			for i=1, #selectedKodachis do
				if (KodachiStack[selectedKodachis[i]])then
					KodachiStack[selectedKodachis[i]]:forcePreFire()
				end
			end
			return true
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedKodachis = filterKodachis(selectedUnits)
end

function filterKodachis(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (KodachiUnitDefID == GetUnitDefID(unitID)) then
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
	if selectedKodachis then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdForcePreFire
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
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==Kodachi_NAME)  then
			if  (KodachiStack[units[i]]==nil) then
				KodachiStack[units[i]]=KodachiController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
