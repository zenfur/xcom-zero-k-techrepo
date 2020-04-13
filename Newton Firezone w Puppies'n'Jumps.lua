local versionNum = '0.408'

function widget:GetInfo()
	return {
		name		= "Newton Firezone w Puppies'n'Jumps",
		desc 		= "v".. (versionNum) .."Adds the Firezone command for Newtons. Allies in an area are targeted.",
		author		= "wolas, xponen, Google Frog, terve886", --xponen (add crash location estimator), terve886 (additional behaviour for Puppies and airJumpers
		date		= "2019",
		license		= "GNU GPL, v2 or later",
		layer		= 20,
		handler		= true, --for adding customCommand into UI
		enabled		= true  --loaded by default?
	}
end

-- Based on Improved Newtons by wolas. ZK official version has less usage of pairs and a well integrated command instead of the hotkeys.
--------------
--CONSTANTS---
--------------
VFS.Include("LuaRules/Configs/customcmds.h.lua")

local REAIM_TIME = 8
local checkRate = 2 -- how fast Newton retarget. Default every 2 frame. Basically you control responsives and accuracy. On big setups checkRate = 1 is not recomended + count your ping in
local newtonUnitDefID = UnitDefNames["turretimpulse"].id
local newtonUnitDefRange = UnitDefNames["turretimpulse"].maxWeaponRange
local mapGravity = Game.gravity/30/30
local goneBallisticThresholdSQ = 8^2 --square of speed (in elmo per frame) before ballistic calculator predict unit trajectory

local GL_LINE_STRIP = GL.LINE_STRIP
local glLineWidth = gl.LineWidth
local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local circleList

local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local GetMouseState = Spring.GetMouseState
local GetUnitsInRectangle = Spring.GetUnitsInRectangle
local GetUnitDefID = Spring.GetUnitDefID
local GetSelectedUnits = Spring.GetSelectedUnits
local GiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitVelocity = Spring.GetUnitVelocity
local GetPlayerInfo = Spring.GetPlayerInfo
local GetMyPlayerID = Spring.GetMyPlayerID
local IsCheatingEnabled = Spring.IsCheatingEnabled
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitHealth = Spring.GetUnitHealth
local Echo = Spring.Echo
local GetGameFrame = Spring.GetGameFrame
local ValidUnitID =  Spring.ValidUnitID
local GetUnitTransporter = Spring.GetUnitTransporter
local GetUnitRadius = Spring.GetUnitRadius
local IsGUIHidden = Spring.IsGUIHidden
local GetUnitHeading = Spring.GetUnitHeading
local GetUnitWeaponState = Spring.GetUnitWeaponState
local IsUnitSelected = Spring.IsUnitSelected



local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE
local CMD_RAW_MOVE = 31109
local CMD_REMOVE = CMD.REMOVE
local CMD_JUMP = 38521
local jumpCost = 15
local ping = 0


local floor = math.floor
local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local ceil = math.ceil
local sqrt = math.sqrt
local atan2 = math.atan2
local huge = math.huge
local max = math.max
local min = math.min
local abs = math.abs
local HEADING_TO_RAD = (pi*2/65536 )

local CMD_NEWTON_FIREZONE = 10283
local CMD_STOP_NEWTON_FIREZONE = 10284
local CMD_SAFE_FALL = 17000

local Puppy_NAME = "jumpscout"
local PuppyUnitDefID = UnitDefNames["jumpscout"].id
local selectedPuppies = nil
local PuppyStack = {}
local myPlayerID = GetMyPlayerID()

local Pyro_NAME = "jumpraid"
local PyroUnitDefID = UnitDefNames["jumpraid"].id
local Jack_NAME = "jumpassault"
local Constable_NAME = "jumpcon"
local JackUnitDefID = UnitDefNames["jumpassault"].id
local selectedJumpers = nil
local JumperStack = {}

local cmdSafeFall = {
	id      = CMD_SAFE_FALL,
	type    = CMDTYPE.ICON,
	tooltip = 'Makes unit land safely from fall.',
	action  = 'reclaim',
	params  = { },
	texture = 'LuaUI/Images/commands/Bold/dgun.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}

local cmdFirezone = {
	id      = CMD_NEWTON_FIREZONE,
	type    = CMDTYPE.ICON_UNIT_OR_RECTANGLE,
	tooltip = 'Set a Newton firezone. Newtons will fire at all units in the area (including allies).',
	cursor  = 'Attack',
	action  = 'setfirezone',
	params  = { },
	texture = 'LuaUI/Images/commands/Bold/capture.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}

local cmdStopFirezone = {
	id      = CMD_STOP_NEWTON_FIREZONE,
	type    = CMDTYPE.ICON ,
	tooltip = 'Disasociate Newton from current firezone.',
	cursor  = 'Stop',
	action  = 'cancelfirezone',
	params  = { },
	texture = 'LuaUI/Images/commands/Bold/stop.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}

local bombUnitDefIDs = {
	[PuppyUnitDefID] = true,
}
for udid = 1, #UnitDefs do
	local ud = UnitDefs[udid]
	if ud.canKamikaze then
		bombUnitDefIDs[udid] = true
	end
end

--------------
---OPTIONS----
--------------

local launchPredictLevel = 2
local alwaysDrawFireZones = false
local transportPredictLevel = 1
local transportPredictionSpeedSq = 5^2

options_path = 'Settings/Interface/Falling Units'--/Formations'
options_order = { 'lbl_newton', 'predictNewton', 'alwaysDrawZones', 'lbl_transports', 'predictDrop', 'transportSpeed'}
options = {
	lbl_newton = { name = 'Newton Launchers', type = 'label'},
	predictNewton = {
		type='radioButton',
		name='Predict impact location for',
		items = {
			{name = 'All units', key = 'all', desc = "All units will have their impact predicted whenever they take damge."},
			{name = 'Launched units', key = 'newton', desc = "Units hit by a gravity gun will have their impact predited."},
			{name = 'Firezone units', key = 'firezone', desc = "Only units launched with a firezone will have their impact predicted."},
			{name = 'No units', key = 'none', desc = "No impact prediction."},
		},
		value = 'newton',  --default at start of widget
		OnChange = function(self)
			local key = self.value
			if key == 'all' then
				launchPredictLevel = 3
			elseif key == 'newton' then
				launchPredictLevel = 2
			elseif key == 'firezone' then
				launchPredictLevel = 1
			elseif key == 'none' then
				launchPredictLevel = 0
			end
		end,
	},
	alwaysDrawZones = {
		name = "Always draw firezones",
		desc = "Enable to always draw Newton firezones. Otherwise they are only drawn on selection.",
		type = 'bool',
		value = false,
		OnChange = function(self)
			alwaysDrawFireZones = self.value
		end,
	},
	lbl_transports = { name = 'Transports', type = 'label'},
	predictDrop = {
		type='radioButton',
		name='Predict transport drop location for',
		items = {
			{name = 'All units', key = 'all', desc = "All units will have their drop location predicted."},
			{name = 'Bombs only', key = 'bomb', desc = "Crawling bombs will have their drop loction predicted."},
			{name = 'No units', key = 'none', desc = "No units will have their impact position predicted."},
		},
		value = 'bomb',  --default at start of widget
		OnChange = function(self)
			local key = self.value
			if key == 'all' then
				transportPredictLevel = 2
			elseif key == 'bomb' then
				transportPredictLevel = 1
			elseif key == 'none' then
				transportPredictLevel = 0
			end
		end,
	},
	transportSpeed = {
		name = "Drop prediction speed threshold",
		desc = "Draw prediction for transports above this speed.",
		type = 'number',
		min = 0, max = 8, step = 0.2,
		value = 5,
		OnChange = function(self)
			transportPredictionSpeedSq = self.value^2
		end,
	},
}

--------------
--VARIABLE----
--------------
local springPoints = {}			--[newtonGroupID] -> {points}
springPoints[100] = {y = 100}
springPoints[100] = nil
local tempPoints = {}

local groups = {count = 0, data = {}}

local newtonIDs = {} 		--[unitID] -> newtonGroupid
local newtonTrianglePoints = {}	--[unitID] -> { newtonTriangle Points}
local selectedNewtons = nil		--temprorary {newtons}

local intensivity = 255
local colorIndex = 0

local victim = {}
local groupTarget = {}
local victimStillBeingAttacked = {}
local victimLandingLocation = {}

local queueTrajectoryEstimate = {targetFrame=-1,unitList={}} --for use in scheduling the time to calculate unit trajectory
local transportedUnits = {}

--local cmdRate = 0
--local cmdRateS = 0
local softEnabled = false	--if zero newtons has orders, uses less
local currentFrame = GetGameFrame()

local EMPTY_TABLE = {}

--------------
--METHODS-----
--------------
local function LimitRectangleSize(rect,units)  --limit rectangle size to Newton's range
	local maxX = 0
	local minX = huge
	local maxZ = 0
	local minZ = huge
	for i = 1, #units do
		local unitID = units[i]
		if GetUnitDefID(unitID) == newtonUnitDefID then
			local x,_,z = GetUnitPosition(unitID)
			if x + newtonUnitDefRange > maxX then
				maxX = x + newtonUnitDefRange
			end
			if z + newtonUnitDefRange > maxZ then
				maxZ = z + newtonUnitDefRange
			end
			if x - newtonUnitDefRange < minX then
				minX = x - newtonUnitDefRange
			end
			if z - newtonUnitDefRange < minZ then
				minZ = z - newtonUnitDefRange
			end
		end
	end
	rect.x = min(maxX,rect.x)
	rect.z = min(maxZ,rect.z)
	rect.x2 = min(maxX + 252,rect.x2)
	rect.z2 = min(maxZ + 252,rect.z2)
	rect.x = max(minX - 252,rect.x)
	rect.z = max(minZ - 252,rect.z)
	rect.x2 = max(minX,rect.x2)
	rect.z2 = max(minZ,rect.z2)
	return rect
end

local function FixRectangle(rect)
	rect.x = floor((rect.x+8)/16)*16
	rect.z = floor((rect.z+8)/16)*16
	rect.x2= floor((rect.x2+8)/16)*16
	rect.z2= floor((rect.z2+8)/16)*16

	if (rect.x2 < rect.x) then
		tmp = rect.x
		rect.x = rect.x2
		rect.x2 = tmp
	end
	if (rect.z2 < rect.z) then
		tmp = rect.z
		rect.z = rect.z2
		rect.z2 = tmp
	end

	rect.y_xy   = GetGroundHeight(rect.x, rect.z)
	rect.y_x2y2 = GetGroundHeight(rect.x2, rect.z2)
	rect.y_xy2  = GetGroundHeight(rect.x, rect.z2)
	rect.y_x2y  = GetGroundHeight(rect.x2, rect.z)

	return rect
end

local function PickColor()
	local color = {}
	ind = colorIndex % 6
	if colorIndex > 5 and ind == 0 then
		intensivity = floor(intensivity / 2)
	end

	if (ind == 0 ) then
		color[1] = intensivity
		color[2] = 0
		color[3] = 0
	elseif (ind == 1) then
		color[1] = 0
		color[2] = intensivity
		color[3] = 0
	elseif (ind == 2) then
		color[1] = 0
		color[2] = 0
		color[3] = intensivity
	elseif (ind == 3) then
		color[1] = intensivity
		color[2] = intensivity
		color[3] = 0
	elseif (ind == 4) then
		color[1] = intensivity
		color[2] = 0
		color[3] = intensivity
	elseif (ind == 5) then
		color[1] = 0
		color[2] = intensivity
		color[3] = intensivity
	end

	colorIndex = colorIndex + 1
	if colorIndex > 30 then
		colorIndex = 0
	end
	return color
end

local function RemoveDeadGroups(units)
	for i = 1, #units do
		local unitID = units[i]
		if newtonIDs[unitID] then
			local groupID, index = newtonIDs[unitID].groupID, newtonIDs[unitID].index
			local groupData = groups.data[groupID]
			local newtons = groupData.newtons

			newtons.data[index] = newtons.data[newtons.count]
			newtonIDs[newtons.data[newtons.count]].index = index
			newtons.data[newtons.count] = nil
			newtons.count = newtons.count - 1

			newtonIDs[unitID] = nil
			newtonTrianglePoints[unitID] = nil

			if newtons.count == 0 then

				local egNewtons = groups.data[groups.count].newtons -- end group
				for j = 1, egNewtons.count do
					newtonIDs[egNewtons.data[j]].groupID = groupID
				end

				--displace/re-occupy dead group with another group
				victimStillBeingAttacked[groupID] = victimStillBeingAttacked[groups.count]
				victimStillBeingAttacked[groups.count] = nil
				groupTarget[groupID] = groupTarget[groups.count]
				groupTarget[groups.count] = nil

				groups.data[groupID] = groups.data[groups.count]
				groups.data[groups.count] = nil
				groups.count = groups.count - 1

				if groups.count == 0 then
					softEnabled = false
				end
			end
		end
	end
end

local function NewGroup(groupNewtons, points)
	points = LimitRectangleSize(points, groupNewtons)
	points = FixRectangle(points)

	RemoveDeadGroups(groupNewtons)

	local reaimPos = {}
	reaimPos[1] = (points.x + points.x2)/2
	reaimPos[3] = (points.z + points.z2)/2
	reaimPos[2] = GetGroundHeight(reaimPos[1], reaimPos[3])

	groups.count = groups.count + 1
	groups.data[groups.count] = {
		newtons = {count = #groupNewtons, data = {}},
		points = points,
		color = PickColor(),
		reaimPos = reaimPos,
		needInit = true,
	}
	local newtons = groups.data[groups.count].newtons.data

	for i = 1, #groupNewtons do
		local unitID = groupNewtons[i]
		newtons[i] = unitID
		newtonIDs[unitID] = {groupID = groups.count, index = i}
		local x, y, z = GetUnitPosition (unitID)
		newtonTrianglePoints[unitID] = {
			y,
			x - 15, z - 15,
			x, z + 15,
			x +15, z -15
		}
	end

	softEnabled = true
end

local PuppyLandingController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	attackActive = false,
	landingTarget,
	reloadState,
	reloading = false,
	forceland = false,


	new = function(self, unitID)
		--Echo("PuppyLandingController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.pos = {GetUnitPosition(self.unitID)}
		self.landingTarget = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("PuppyLandingController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	setLandingLocation = function(self, params)
		self.landingTarget = params
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

	avoidCrash = function(self)
		if(victimLandingLocation[self.unitID])then
			self.pos = {GetUnitPosition(self.unitID)}
			if(distance(self.pos[1],self.pos[3],self.landingTarget[1],self.landingTarget[3])<=640+ping*200+abs(12000/(self.pos[2]-self.landingTarget[2])) or self.forceland)then
				unitVel = {GetUnitVelocity(self.unitID)}
				local yVel = unitVel[2]
				if (yVel <=0)then
					self:land()
				end
			end
		end
	end,

	land = function(self)
		if(self:getJumpCount() >=1)then

			self.pos = {GetUnitPosition(self.unitID)}
			local gHeight = GetGroundHeight(self.pos[1],self.pos[3])
			if (gHeight+5<=self.pos[2])then --Failsafe to prevent accidentally activating the command on ground
				self.reloadState = GetUnitWeaponState(self.unitID, 1, "reloadState")
				if(currentFrame >= self.reloadState)then
					self.reloading = false
					EstimateCrashLocation(self.unitID)
				else
					self.reloading = true
				end
				local vel = {GetUnitVelocity(self.unitID)}
				local speedMultiplier = ceil(vel[4]/20)
				local rotation = atan((self.pos[1]-self.landingTarget[1])/(self.pos[3]-self.landingTarget[3]))
				local targetPosRelative={
					sin(rotation) * (175+ping*200*speedMultiplier),
					nil,
					cos(rotation) * (175+ping*200*speedMultiplier),
				}

				Echo(ping*400*speedMultiplier)
				local targetPosAbsolute = {}
				if (self.pos[3]<=self.landingTarget[3]) then
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

				--Echo("landing ordered")
				self.attackActive = true
			end
		end
	end,

	orderStop=function(self, frame)
		if (self.attackActive)then
			local reload = GetUnitWeaponState(self.unitID, 1, "reloadState")
			if(self.reloading and reload > self.reloadState)then
				self.reloadState = reload-1
				self.reloading = false
				return
			end

			if (reload > self.reloadState)then
				if(reload <= frame+20)then
					GiveOrderToUnit(self.unitID, CMD_UNIT_CANCEL_TARGET,0,0)
					self.attackActive = false
					victimLandingLocation[self.unitID] = nil
					self.forceland = false
					GiveOrderToUnit(self.unitID, CMD_REMOVE, {CMD_RAW_MOVE},{'alt'});
					GiveOrderToUnit(self.unitID,CMD_RAW_MOVE, self.landingTarget, 0)
				end
			end
		end
	end,

	handle=function(self, frame)
		self:orderStop(frame)
		self:avoidCrash()
	end
}

local JumperLandingController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	targetFrame = 0,
	jumpActive = false,
	landingTarget,


	new = function(self, unitID)
		--Echo("JumperLandingController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("JumperLandingController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	setLandingLocation = function(self, params)
		self.landingTarget = params
	end,

	avoidCrash = function(self)

		if (IsUnitSelected(self.unitID))then
			return
		end

		self.pos = {GetUnitPosition(self.unitID)}
		if(victimLandingLocation[self.unitID])then
			if(distance(self.pos[1],self.pos[3],self.landingTarget[1],self.landingTarget[3])<=200+abs(6000/(self.pos[2]-self.landingTarget[2])))then
				unitVel = {GetUnitVelocity(self.unitID)}
				local yVel = unitVel[2]
				if (yVel <=0)then
					self:land()
				end
			end
		end
	end,

	land = function(self)
		EstimateCrashLocation(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		local gHeight = GetGroundHeight(self.pos[1],self.pos[3])
		if (gHeight+5<=self.pos[2])then --Failsafe to prevent accidentally activating the command on ground
			GiveOrderToUnit(self.unitID, CMD_JUMP, {self.pos[1], gHeight, self.pos[3]}, 0)
			Echo("jump order given")
			self.jumpActive = true
			self.targetFrame = currentFrame + 9
		end
	end,

	orderStop=function(self)
		if (self.jumpActive and self.targetFrame <= currentFrame)then
			self.jumpActive = false
			GiveOrderToUnit(self.unitID, CMD_REMOVE, {CMD_RAW_MOVE},{'alt'});
			GiveOrderToUnit(self.unitID,CMD_RAW_MOVE, self.landingTarget, 0)
		end
	end,

	handle=function(self)
		self:avoidCrash()
		self:orderStop()
	end
}

-------------------------------------------------------------------
-------------------------------------------------------------------
--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedNewtons ~= nil then
		if (cmdID == CMD_NEWTON_FIREZONE) and #params > 3 and params[4] ~= 0 then
			local points = {}
			if #params > 4 then
				points.x = params[1]
				points.z = params[3]
				points.x2 = params[4]
				points.z2 = params[6]
			else
				local radius = params[4]
				points.x = params[1]
				points.z = params[3]
				local mx, my = GetMouseState()
				local _, pos = TraceScreenRay(mx,my, true)
				points.x2 = pos[1]
				points.z2 = pos[3]
			end
			NewGroup(selectedNewtons, points)
		elseif (cmdID == CMD_STOP_NEWTON_FIREZONE) then
			RemoveDeadGroups(selectedNewtons)
		end
	end
	if (selectedPuppies ~= nil)then
		if (cmdID == CMD_SAFE_FALL)then
			for i=1, #selectedPuppies do
				if(PuppyStack[selectedPuppies[i]])then
					PuppyStack[selectedPuppies[i]].forceland = true
					PuppyStack[selectedPuppies[i]]:land()
				end
			end
		end
	end
	if (selectedJumpers ~= nil)then
		if (cmdID == CMD_SAFE_FALL)then
			for i=1, #selectedJumpers do
				if(JumperStack[selectedJumpers[i]])then
					JumperStack[selectedJumpers[i]]:land()
				end
			end
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedNewtons = filterNewtons(selectedUnits)
	selectedPuppies = filterPuppies(selectedUnits)
	selectedJumpers = filterJumpers(selectedUnits)
end

function filterNewtons(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (newtonUnitDefID == GetUnitDefID(unitID)) then
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

function filterJumpers(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (PyroUnitDefID == GetUnitDefID(unitID) or JackUnitDefID == GetUnitDefID(unitID)) then
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
	if (selectedNewtons) then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdFirezone
		customCommands[#customCommands+1] = cmdStopFirezone
	end
	if (selectedPuppies or selectedJumpers) then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdSafeFall
	end
end

function distance ( x1, y1, x2, y2 )
	local dx = (x1 - x2)
	local dy = (y1 - y2)
	return sqrt ( dx * dx + dy * dy )
end
-------------------------------------------------------------------
-------------------------------------------------------------------
--- SPECTATOR CHECK
local function IsSpectatorAndExit()
	local _, _, spec = GetPlayerInfo(GetMyPlayerID(), false)
	if spec then
		Echo("Newton Firezone disabled for spectator.")
		widgetHandler:RemoveWidget(widget)
	end
end

local function RemoveIfSpectator()
	if GetSpectatingState() and (not IsCheatingEnabled()) then
		Echo("Newton Firezone disabled for spectator.")
		widgetHandler:RemoveWidget(widget) --input self (widget) because we are using handler=true,
	end
end

function widget:PlayerChanged()
	--RemoveIfSpectator()
end
-------------------------------------------------------------------
-------------------------------------------------------------------
--- UNIT HANDLING

local function SquareDistance (points, target)
	local xCenter = (points.x2 + points.x)/2
	local zCenter = (points.z2 + points.z)/2
	local x,_,z = GetUnitPosition(target)
	local diffX = xCenter - x
	local diffZ = zCenter - z
	return (diffX*diffX + diffZ*diffZ)
end

function widget:UnitDestroyed(unitID)
	if newtonIDs[unitID] ~= nil then
		RemoveDeadGroups({unitID})
	end
	if victimLandingLocation[unitID] then
		victimLandingLocation[unitID]= nil
	end
	if (PuppyStack[unitID]~= nil) then
		PuppyStack[unitID]=PuppyStack[unitID]:unset();
	end
	if (JumperStack[unitID]~= nil) then
		JumperStack[unitID]=JumperStack[unitID]:unset();
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Puppy_NAME)
			and (unitTeam==GetMyTeamID()) then
		PuppyStack[unitID] = PuppyLandingController:new(unitID);
	end
	if (UnitDefs[unitDefID].name==Pyro_NAME or UnitDefs[unitDefID].name==Jack_NAME or UnitDefs[unitDefID].name==Constable_NAME)
			and (unitTeam==GetMyTeamID()) then
		JumperStack[unitID] = JumperLandingController:new(unitID);
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

local function AddTrajectoryEstimate(unitID)
	if currentFrame >= queueTrajectoryEstimate["targetFrame"] then
		queueTrajectoryEstimate["targetFrame"] = (currentFrame-(currentFrame % 15)) + 15 --"(frame-(frame % 15))" group continous integer into steps of 15. eg [1 ... 30] into [1,15,30]
	end
	queueTrajectoryEstimate["unitList"][unitID] = true
end

local function UpdateTransportedUnits()
	for unitID,_ in pairs(transportedUnits) do
		if ValidUnitID(unitID) then
			local transport = GetUnitTransporter(unitID)
			if transport and ValidUnitID(transport) then
				EstimateCrashLocation(unitID, transport)
			else
				transportedUnits[unitID] = nil
			end
		else
			transportedUnits[unitID] = nil
		end
	end
end

function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if (transportPredictLevel == 2) or ((transportPredictLevel == 1) and bombUnitDefIDs[unitDefID]) then
		transportedUnits[unitID] = true
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if victim[unitID] then --is current victim of any Newton group?
		victim[unitID] = currentFrame + 90 --delete 3 second later (if nobody attack it afterward)

		--notify group that target is still being attacked
		for group=1, groups.count do
			if groupTarget[group] == unitID then
				victimStillBeingAttacked[group] = unitID --signal a "wait, this group is attacking this unit!"
			end
		end
		--ech("still being attacked")
	end

	if ((launchPredictLevel == 2) and damage == 0) or (launchPredictLevel == 3) or ((launchPredictLevel == 1) and victim[unitID]) then
		--estimate trajectory of any unit hit by weapon
		AddTrajectoryEstimate(unitID)
	end
end

function widget:GameFrame(n)
	currentFrame = n
	if n%2 == 0 then
		UpdateTransportedUnits()
	end

	-- estimate for recently launched units
	if queueTrajectoryEstimate["targetFrame"] == n then
		for unitID,_ in pairs(queueTrajectoryEstimate["unitList"]) do
			EstimateCrashLocation(unitID)
			queueTrajectoryEstimate["unitList"][unitID]=nil
		end
	end

	--empty whitelist to widget:UnitDamaged() monitoring
	for unitID, frame in pairs(victim) do
		if frame<=n then
			victim[unitID] = nil
		end
	end

	if softEnabled then --is disabled if group is empty
		-- update attack orders
		if n % checkRate == 0 then
			for g = 1, groups.count do
				local groupData = groups.data[g]
				local points = groupData.points
				local newtons = groupData.newtons.data
				if points ~= nil then
					local units = GetUnitsInRectangle(points.x, points.z, points.x2, points.z2)
					local stop = true
					local unitToAttack = nil
					local shortestDistance = 999999
					for i = 1, #units do
						local unitID = units[i]
						local targetDefID = GetUnitDefID(unitID)
						if (not targetDefID) or not UnitDefs[targetDefID].isImmobile then
							stop = false
							if victimStillBeingAttacked[g] == unitID then --wait signal from UnitDamaged() that a unit is still being pushed
								victimStillBeingAttacked[g] = nil--clear wait signal
								unitToAttack = nil
								break --wait for next frame until UnitDamaged() stop signalling wait.
								--NOTE: there is periodic pause when Newton reload in UnitDamaged() (every 0.2 second), this allowed the wait signal to be empty and prompted Newton-groups to retarget.
							end

							local distToBoxCenter = SquareDistance (points, unitID)
							if distToBoxCenter < shortestDistance then --get smallest distance to box's center
								shortestDistance = distToBoxCenter --shortest square distance
								unitToAttack = unitID --shoot this unit at end of this loop
							end
						end
					end
					if unitToAttack and (groupTarget[g]~=unitToAttack) then --there are target, and target is different than previous target (prevent command spam)?
						GiveOrderToUnitArray(newtons, CMD_ATTACK, {unitToAttack}, 0 ) --shoot unit
						groupTarget[g] = unitToAttack --flag this group as having a target!
						victimStillBeingAttacked[g] = nil --clear wait signal
						victim[unitToAttack] = n + 90 --add UnitDamaged() whitelist, and expire after 3 second later
					end
					if stop then --no unit in the box, and still have target?
						if groupTarget[g] or groupData.needInit then
							groupData.reaimTimer = 0
							groupData.needInit = nil
							groupTarget[g] = nil --no target
							victimStillBeingAttacked[g] = nil --clear wait signal
							GiveOrderToUnitArray(newtons, CMD_ATTACK, groupData.reaimPos, 0)
						end

						if groupData.reaimTimer then
							groupData.reaimTimer = groupData.reaimTimer + 1
							if groupData.reaimTimer >= REAIM_TIME then
								GiveOrderToUnitArray(newtons,CMD_STOP, EMPTY_TABLE, 0) --cancel attacking any out-of-box unit
								groupData.reaimTimer = nil
							end
						end
					end
				end
			end
		end
	end

	if (n%4 == 0)then
		local myInfo ={GetPlayerInfo(myPlayerID)}
		ping = myInfo[6]
		for VictimID,Puppy in pairs(PuppyStack) do
			if(victimLandingLocation[VictimID])then
				Puppy:setLandingLocation(victimLandingLocation[VictimID])
			end
			Puppy:handle(currentFrame)
		end
	end

	if (n%10 == 0)then
		for VictimID,Jumper in pairs(JumperStack) do
			if(victimLandingLocation[VictimID])then
				Jumper:setLandingLocation(victimLandingLocation[VictimID])
			end
			Jumper:handle()
		end
	end

	if n % 150 == 0 then --recheck crash estimated location every 5 second
		for victimID, _ in pairs (victimLandingLocation) do
			local x,y,z = GetUnitPosition(victimID)
			if x then
				local grndHeight = max(0, GetGroundHeight(x,z)) + 30
				if y <= grndHeight then
					victimLandingLocation[victimID]=nil
				end
			else
				victimLandingLocation[victimID]=nil
			end
		end
	end
end

-------------------------------------------------------------------
-------------------------------------------------------------------
--- DRAWING

local function DrawRectangleLine(rect)
	glVertex(rect.x,rect.y_xy, rect.z)
	glVertex(rect.x2,rect.y_x2y, rect.z)
	glVertex(rect.x2,rect.y_x2y2, rect.z2)
	glVertex(rect.x,rect.y_xy2, rect.z2)
	glVertex(rect.x,rect.y_xy, rect.z)
end

local function DrawTriangle(triangle)
	glVertex(triangle[2], triangle[1], triangle[3])
	glVertex(triangle[4], triangle[1], triangle[5])
	glVertex(triangle[6], triangle[1], triangle[7])
	glVertex(triangle[2], triangle[1], triangle[3])
end

function widget:DrawWorld()
	if IsGUIHidden() then
		return
	end
	glLineWidth(2.0)
	glColor(1, 1, 0)
	if selectedNewtons or alwaysDrawFireZones then
		for g = 1, groups.count do
			local data = groups.data[g]
			local points = data.points
			local color = data.color
			local newtons = data.newtons
			glColor(color[1],color[2],color[3]) -- for some odd reason I see only 6 colors..
			glBeginEnd(GL_LINE_STRIP, DrawRectangleLine, points)
			for i = 1, newtons.count do
				glBeginEnd(GL_LINE_STRIP,DrawTriangle, newtonTrianglePoints[newtons.data[i]])
			end
		end
	end
	--for unitID, triangle in pairs ( newtonTrianglePoints) do
	--	glBeginEnd(GL_LINE_STRIP, DrawTriangle, triangle)
	--end

	------Crash location estimator---
	for victimID, position in pairs (victimLandingLocation) do
		local numAoECircles = 9
		local aoe = 100
		local alpha = 0.75
		for i=1,numAoECircles do   --Reference: draw a AOE rings , gui_attack_aoe.lua by Evil4Zerggin
			local proportion = (i/(numAoECircles + 1))
			local radius = aoe * proportion
			local alphamult = alpha*(1-proportion)
			glColor(1, 0, 0,alphamult)
			gl.PushMatrix()
			gl.Translate(position[1],position[2],position[3])
			gl.Scale(radius, radius, radius)
			gl.CallList(circleList)
			gl.PopMatrix()
		end
	end
end

------Crash location estimator---
function EstimateCrashLocation(victimID, transportID)
	if not ValidUnitID(victimID) then
		return
	end
	local defID = GetUnitDefID(victimID)
	if not UnitDefs[defID] or UnitDefs[defID].canFly then --if speccing with limited LOS or the unit can fly, then skip predicting trajectory.
		return
	end

	local xVel,yVel,zVel, compositeVelocity = GetUnitVelocity(transportID or victimID)
	if not xVel then
		return
	end

	local currentVelocitySQ = (compositeVelocity and compositeVelocity^2 or (xVel^2+yVel^2+zVel^2)) --elmo per second square
	local gravity = mapGravity
	if transportID then
		if transportPredictionSpeedSq and (currentVelocitySQ < transportPredictionSpeedSq) then
			victimLandingLocation[victimID]=nil
			return
		end
	else
		if (currentVelocitySQ < goneBallisticThresholdSQ) then --speed insignificant compared to unit speed
			victimLandingLocation[victimID]=nil
			return
		end
	end
	local x,y,z = GetUnitPosition(victimID)
	local radius = GetUnitRadius(victimID)
	local mass = UnitDefs[defID].mass
	local airDensity = 1.2/4 --see Spring/rts/Map/Mapinfo.cpp
	local future_locationX, future_height,future_locationZ = SimulateWithDrag(xVel,yVel,zVel, x,y,z, gravity ,mass,radius, airDensity)
	if future_locationX then
		victimLandingLocation[victimID]={future_locationX,future_height, future_locationZ}
	end
end

function widget:Initialize()
	--IsSpectatorAndExit()

	local circleVertex = function()
		local circleDivs, PI = 64 , pi
		for i = 1, circleDivs do
			local theta = 2 * PI * i / circleDivs
			glVertex(cos(theta), 0, sin(theta))
		end
	end
	local circleDraw = 	function() glBeginEnd(GL.LINE_LOOP, circleVertex ) end --Reference: draw a circle , gui_attack_aoe.lua by Evil4Zerggin
	circleList = gl.CreateList(circleDraw)
	WG.NewtonFirezone_AddGroup = NewGroup

	local units = GetTeamUnits(GetMyTeamID())
	for i=1, #units do
		unitID = units[i]
		DefID = GetUnitDefID(unitID)
		if (UnitDefs[DefID].name==Puppy_NAME)  then
			if  (PuppyStack[unitID]==nil) then
				PuppyStack[unitID]=PuppyLandingController:new(unitID)
			end
		end
		if (UnitDefs[DefID].name==Pyro_NAME or UnitDefs[DefID].name==Jack_NAME or UnitDefs[DefID].name==Constable_NAME)  then
			if  (JumperStack[unitID]==nil) then
				JumperStack[unitID] = JumperLandingController:new(unitID)
			end
		end
	end
end

function widget:Shutdown()
	if circleList then
		gl.DeleteList(circleList)
	end

	WG.NewtonFirezone_AddGroup = nil
end
---------------------------------
---------------------------------
-- SIMULATION / Prediction
--a) simple balistic
function SimulateWithoutDrag(xVel,yVel,zVel, x,y,z,gravity)
	local hitGround=false
	local reachApex = false
	local iterationSoFar=1
	local step =5 --how much gameframe to skip (set how much gameframe does 1 iteration will represent)
	local maximumIteration = 360 --1 iteration crudely simulate 5 frame (skip 4 frame), therefore 360 iteration is roughly 2 minute simulation into future
	local future_locationX, future_locationZ, future_height= 0,0,0
	while (not hitGround and iterationSoFar < maximumIteration) do --not hit ground yet?
		local future_time = iterationSoFar*step
		future_locationX =xVel*future_time
		future_locationZ =zVel*future_time
		future_height =(yVel)*future_time - (gravity/2)*future_time*future_time
		local groundHeight =GetGroundHeight(future_locationX+x,future_locationZ+z)
		if gravity*future_time >= yVel then --is falling down phase?
			reachApex = true
		end
		if future_height+y <= groundHeight and reachApex then --reach ground & is falling down?
			hitGround = true
		end
		iterationSoFar = iterationSoFar +1
	end
	return future_locationX+x,future_height+y,future_locationZ+z
end
--b) complex balistic with airdrag
--SOURCE CODE copied from:
--1) http://www2.hawaii.edu/~kjbeamer/
--2) http://www.codeproject.com/Articles/19107/Flight-of-a-projectile
--Some Theory from:
--1) Kamalu J. Beamer ,"Projectile Motion Using Runge-Kutta Methods" PDF, 13 April 2013
--2) Vit Buchta, "Flight of Projectile" CodeProject article, 8 Jun 2007
--(No copyright licence was stated)

local function Vec2dot(X,Y) --a function that takes dot products of two specific vectors X and Y
	local tmp={hrzn=0,vert=0};
	tmp.hrzn = X.hrzn * Y.hrzn;
	tmp.vert = X.vert * Y.vert;
	return(tmp.hrzn+ tmp.vert);
end

local function Vec2sum(X,Y) --a function that adds two specific vectors X and Y
	local tmp={hrzn=0,vert=0};
	tmp.hrzn = X.hrzn + Y.hrzn;
	tmp.vert = X.vert + Y.vert;
	return(tmp);
end

local function Vec2sum4(W,X,Y,Z) --a function that sums four 3-vectors W,X,Y,Z
	local tmp={hrzn=0,vert=0};
	tmp.hrzn = W.hrzn + X.hrzn + Y.hrzn + Z.hrzn;
	tmp.vert = W.vert + X.vert + Y.vert + Z.vert;
	return(tmp);
end

local function Scalar_vec2mult(X,Y) --a function that multiplies vector Y by double X
	local tmp = {hrzn=0,vert=0};
	tmp.hrzn = X * Y.hrzn;
	tmp.vert = X * Y.vert;
	return(tmp);
end

local function f_x(t,x,v) --gives the formal definition of v = dx/dt
	return(v)
end

local function f_v(t,xold,vold,mass,area,gravity,airDensity) -- a function that returns acceleration as a function of x, v and all other variables; all based on force law
	local tmp = {hrzn=0,vert=0};
	local rho=1
	local b=(1.0/2.0)*airDensity*area*rho;
	local horizontalSign = -1*abs(vold.hrzn)/vold.hrzn
	local verticalSign = -1*abs(vold.vert)/vold.vert
	--MethodA: current spring implementation--
	tmp.hrzn = (b/mass)*(vold.hrzn^2)*horizontalSign;--horizontal is back-and-forth movement
	tmp.vert = -gravity+(b/mass)*(vold.vert^2)*verticalSign; --is vertical movement
	--MethodB: ideal implementation (more accurate to real airdrag, not implemented in spring)--
	-- local totalVelocity = math.sqrt(vold.hrzn^2+vold.vert^2)
	-- tmp.hrzn = (b/mass)*(totalVelocity^2)*(vold.hrzn/totalVelocity)*horizontalSign;
	-- tmp.vert = -g+(b/mass)*(totalVelocity^2)*(vold.vert/totalVelocity)*verticalSign;
	return(tmp);
end

--4th order Runge-Kutta algorithm--
--Numerical method for differential equation--
--Algorithm:
--[[
for n=0,1,2....,N-1 do
	k1=stepSize * derivativeOfEquation(currentX,currentV)
	k2=stepSize * derivativeOfEquation(currentX+stepSize/2, currentV+k1/2)
	k3=stepSize * derivativeOfEquation(currentX+stepSize/2, currentV+k2/2)
	k4=stepSize * derivativeOfEquation(currentX+stepSize, currentV+k3)
	nextX = currentX + stepSize
	nextV = currentV + (k1+2*k2+2*k3+k4)/6
end
--]]
--For projectile simulation:
--The derivative of X is V (velocity), and the derivative of V is A (acceleration)
--the equation for A is given as the Drag equation while X and V is not available due to complexity
local function VecFRK4xv(ytype,t,xold, vold,dt,mass,area,gravity,airDensity)
	local k1x = Scalar_vec2mult(dt,f_x(t,xold,vold));
	local k1v = Scalar_vec2mult(dt,f_v(t,xold,vold,mass,area,gravity,airDensity));
	local k2x = Scalar_vec2mult(dt,f_x(t+dt/2.0,Vec2sum(xold,Scalar_vec2mult(0.5,k1x)),Vec2sum(vold,Scalar_vec2mult(0.5,k1v))));
	local k2v = Scalar_vec2mult(dt,f_v(t+dt/2.0,Vec2sum(xold,Scalar_vec2mult(0.5,k1x)),Vec2sum(vold,Scalar_vec2mult(0.5,k1v)),mass,area,gravity,airDensity));
	local k3x = Scalar_vec2mult(dt,f_x(t+dt/2.0,Vec2sum(xold,Scalar_vec2mult(0.5,k2x)),Vec2sum(vold,Scalar_vec2mult(0.5,k2v))));
	local k3v = Scalar_vec2mult(dt,f_v(t+dt/2.0,Vec2sum(xold,Scalar_vec2mult(0.5,k2x)),Vec2sum(vold,Scalar_vec2mult(0.5,k2v)),mass,area,gravity,airDensity));
	local k4x = Scalar_vec2mult(dt,f_x(t+dt,Vec2sum(xold,k3x),Vec2sum(vold,k3v)));
	local k4v = Scalar_vec2mult(dt,f_v(t+dt,Vec2sum(xold,k3x),Vec2sum(vold,k3v),mass,area,gravity,airDensity));
	local k2x2 = Scalar_vec2mult(2.0,k2x);
	local k2v2 = Scalar_vec2mult(2.0,k2v);
	local k3x2 = Scalar_vec2mult(2.0,k3x);
	local k3v2 = Scalar_vec2mult(2.0,k3v);

	if (ytype==0) then
		return(Scalar_vec2mult((1.0/6.0),Vec2sum4(k1x,k2x2,k3x2,k4x)));
	else
		return(Scalar_vec2mult((1.0/6.0),Vec2sum4(k1v,k2v2,k3v2,k4v)));
	end
end

function SimulateWithDrag(velX,velY,velZ, x,y,z, gravity,mass,radius, airDensity)
	radius = radius *0.01 --in centi-elmo (centimeter, or 10^-2) instead of elmo. See Spring/rts/Sim/Objects/SolidObject.cpp
	local horizontalVelocity = sqrt(velX^2+velZ^2)
	local horizontalAngle = atan2 (velX/horizontalVelocity, velZ/horizontalVelocity)
	local hrznAngleCos = cos(horizontalAngle)
	local hrznAngleSin = sin(horizontalAngle)

	local area=(radius*radius)*pi;

	local xold={hrzn=0,vert=0}; --position
	local vold={hrzn=0,vert=0}; --velocity
	local currPosition = {x = x, y = 0, z = z}
	local prevPosition = {x = 0, y = 0, z = 0}

	vold.hrzn = horizontalVelocity --initial horizontal component of velocity
	vold.vert = velY --initial vertical component of velocity

	xold.hrzn = 0.0; --initial at the origin
	xold.vert = 0.0;

	--PRINT OUT A TABLE OF TRAJECTORY:
	-- Echo("Time    dist-Pos    dist-Vel    vert-Pos    vert-Vel");
	-- Echo(t0.. " " .. xold.hrzn .. " " .. vold.hrzn .. " " .. xold.vert .. " " .. vold.vert);

	local t0 = 0; --initial frame
	local dt = 15; --frame increment
	local Tmax = 1800 --max 2 minute
	for t=t0,Tmax,dt do
		local xt = Vec2sum(xold,VecFRK4xv(0,t,xold,vold,dt,mass,area,gravity,airDensity));
		local vt = Vec2sum(vold,VecFRK4xv(1,t,xold,vold,dt,mass,area,gravity,airDensity));
		xold = xt;
		vold = vt;
		prevPosition.x, prevPosition.y, prevPosition.z = currPosition.x, currPosition.y, currPosition.z
		currPosition.x = xt.hrzn*hrznAngleSin + x --break down xt.hrzn (distance) into components. Note: math.sin for X and math.cos for Z due to orientation of x & z axis in Spring.
		currPosition.z = xt.hrzn*hrznAngleCos + z
		currPosition.y = xt.vert + y
		local groundHeight = GetGroundHeight(currPosition.x,currPosition.z)
		if currPosition.y < groundHeight then --if the unit hits the ground, stop calculating...
			local interpolation = (prevPosition.y - groundHeight) / (prevPosition.y - currPosition.y)
			currPosition.x = prevPosition.x + interpolation * (currPosition.x - prevPosition.x)
			currPosition.z = prevPosition.z + interpolation * (currPosition.z - prevPosition.z)
			break;
		end
		-- Echo(t.. " " .. xold.hrzn .. " " .. vold.hrzn .. " " .. xold.vert .. " " .. vold.vert);
	end
	if xold.hrzn then
		return currPosition.x, GetGroundHeight(currPosition.x,currPosition.z), currPosition.z
	end
	return
end