function widget:GetInfo()
	return {
		name         = "CaretakerRefresher",
		desc         = "Refreshes caretaker jobs prioritizing repair and reclaim. Version v0.3",
		author       = "zenfur, terve886",
		date         = "2019",
		license      = "MIT",
		layer        = 11,
		enabled      = true
	}
end


options_path = 'Settings/Unit Behaviour/Refresher AI'

options_order = {
	'updateRate',
	'orderOverride',
}

options = {
	updateRate = {
		name = 'Refresh rate (higher numbers are faster but more CPU intensive):',
		type = 'number',
		min = 10, max = 600, step = 10,
		value = 200,
	},

	orderOverride  = {
		name = 'Manual order expire time',
		type = 'number',
		min = 300, max = 30*180, step = 300,
		value = 30*60
	},
}

local sqrt = math.sqrt
local UPDATE_FRAME=options.updateRate.value
local UnitRegister = {}

local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GetUnitTeam = Spring.GetUnitTeam
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitTeam = Spring.GetUnitTeam
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitArmored = Spring.GetUnitArmored
local GetUnitStates = Spring.GetUnitStates
local IsUnitSelected = Spring.IsUnitSelected
local GetFeatureHealth = Spring.GetFeatureHealth


--[[
 ( number featureID ) -> nil | number health, number maxHealth, number resurrectProgress
--]]
local GetUnitHealth = Spring.GetUnitHealth
--[[
 ( number unitID ) -> nil | number health, number maxHealth, number paralyzeDamage,
                            number captureProgress, number buildProgress
--]]
local GetFeaturesInCylinder = Spring.GetFeaturesInCylinder
--[[ ( number x, number z, number radius )
  -> featureTable = { [1] = number featureID, etc... }
--]]
local GetFeatureResources = Spring.GetFeatureResources
--[[
( number featureID ) -> nil | number RemainingMetal, number maxMetal,
  number RemainingEnergy, number maxEnergy, number reclaimLeft, number reclaimTime
--]]
local GetFeaturePosition = Spring.GetFeaturePosition
--[[
 ( number featureID, [, boolean midPos [, boolean aimPos ] ] ) ->
 nil |
 number bpx, number bpy, number bpz [,
 number mpx, number mpy, number mpz [,
 number apx, number apy, number apz ]]
--]]

local Echo = Spring.Echo
local target_name = "staticcon"
local caretakerUnitDefID = UnitDefNames["staticcon"].id
local GetSpecState = Spring.GetSpectatingState

local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK
local CMD_PATROL = CMD.PATROL
local CMD_RECLAIM = CMD.RECLAIM
local CMD_REPAIR = CMD.REPAIR
local originX = 0.0
local originZ = 0.0

------------------------------------------------------------------------------
--[[
To use in future:
	CommandNotifyTF()
		ZK-Specific: Captures terraform commands from gui_lasso_terraform widget.
	CommandNotifyRaiseAndBuild()
		ZK-Specific: Captures raise-and-build commands from gui_lasso_terraform widget.
	widget:CommandNotify()
		This captures all the build-related commands from units in our group,
		and adds them to the global queue.

TODOs:
#2 Every options.updateRate + some random refresh said caretaker job
#3 Count caretakers, Count income, count storage
]]--

local JOB_SABOTAGE = 0
local JOB_REPAIR = 1
local JOB_RECLAIM = 2
local JOB_BUILD = 3
local JOB_OVERRIDE = 4
local JOB_GUARD = 5
local JOB_IDLE = 999

local CaretakerController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	selfTeamID = GetMyTeamID(),
	range,
	jobs,
	currentJob,
	last_job_id,
	jobTargetID,
	dontManageUntil = 0,

	new = function(self, unitID)
		--Echo("CaretakerController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		DefID = GetUnitDefID(unitID)
		self.range = UnitDefs[DefID].buildDistance - 25
		self.pos = {GetUnitPosition(self.unitID)}
		self.jobs = {}
		self.currentJob = JOB_IDLE
		self.last_job_id = -1
		return self
	end,

	unset = function(self)
		--Echo("CaretakerController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	setForceTarget = function(self, param)
		self.forceTarget = param[1]
	end,

	findJobs = function(self)
		self.jobTargetID = nil
		--Echo("Searching jobs...")
		units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range)
		wrecks = GetFeaturesInCylinder(self.pos[1], self.pos[3], self.range)
		reclaim_job = false
		sabotage_job = false
		repair_job = false
		build_job = false

		-- find ally build jobs in the area
		-- is nanoframe
		-- find reclaim jobs in the area
		-- find enemy build jobs in the area
		-- is enemy
		-- is nanoframe
		-- find ally repair jobs in the area

		max_dist = 0.0
		total_metal = 0.0
		for index, w in ipairs(wrecks) do
			if w and GetFeatureHealth(w) then
				metal  = select(1, GetFeatureResources(w))
				resurrect_progress = select(3, GetFeatureHealth(w))
				xx, yy, zz = GetFeaturePosition(w)
				dist = (xx-originX)*(xx-originX) + (zz-originZ)*(zz-originZ)
				if metal > 0 and resurrect_progress == 0 then
					total_metal = total_metal + metal
					if dist > max_dist then
						reclaim_job = w
						max_dist = dist
					end
				end
			end
		end

		for index, unit in ipairs(units) do
			unitAlliance = GetUnitAllyTeam(unit)
			hp, mxhp, _, _, bp = GetUnitHealth(unit)
			-- Echo("Unit alliance " .. unitAlliance .. " " .. self.allyTeamID)
			if unitAlliance ~= self.allyTeamID then
				if bp and bp < 1.0 then
					sabotage_job = unit
				end
			else
				if bp and bp < 1.0 then
					if GetUnitStates(self.unitID).movestate > 1 -- if set to ROAM accept ally buildorders
							or self.selfTeamID == GetUnitTeam(unit) then
						build_job = unit
					end
				elseif hp < mxhp then
					repair_job = unit
				end
			end
		end

		--Echo("Found jobs for " .. self.unitID)
		if reclaim_job then
			--Echo("Reclaim job found ".. reclaim_job)
		end
		if sabotage_job then
			--Echo("Sabotage job found " .. sabotage_job)
		end
		if repair_job then
			--Echo("Repair job found " .. repair_job)
		end
		if build_job then
			--Echo("Building job found " .. build_job)
		end

		return {repair = repair_job, sabotage = sabotage_job, reclaim = reclaim_job, build = build_job}
	end,

	handle=function(self)
		Echo(self.currentJob)
		if (GetUnitStates(self.unitID).movestate > 0) then
			--[[ manage todo:
				if guarding check if guard target is in range
				if repairing check if repair target is in range


			--]]if (self.currentJob == JOB_OVERRIDE and self.jobTargetID)then
			targetPositionX, targetPositionY, targetPositionZ = GetUnitPosition(self.jobTargetID)
			if(distance(self.pos[1],self.pos[3],targetPositionX,targetPositionZ)>self.range)then
				self.currentJob = JOB_IDLE
			end
		end
			--Echo("Current job " .. self.currentJob)
			if self.currentJob ~= JOB_OVERRIDE then -- and not IsUnitSelected(self.unitID)
				jobs = self:findJobs() -- active job hunting
				-- job selection
				if jobs["sabotage"] then
					--Echo("Selecting sabotage job")
					if self.last_job_id ~= jobs["sabotage"] then
						GiveOrderToUnit(self.unitID, CMD_RECLAIM, {jobs["sabotage"]}, {""}, 1)
						self.currentJob = JOB_SABOTAGE
						self.last_job_id = jobs["sabotage"]
					end
				elseif jobs["repair"] then
					--Echo("Selecting repair job")
					if self.last_job_id ~= jobs["repair"] then
						GiveOrderToUnit(self.unitID, CMD_REPAIR, {jobs["repair"]}, {""}, 1)
						self.currentJob = JOB_REPAIR
						self.last_job_id = jobs["repair"]
					end
				elseif jobs["reclaim"] then
					--Echo("Selecting reclaim job")
					if self.last_job_id ~= jobs["reclaim"] then
						--Echo("Last reclaim job id: " .. self.last_job_id)
						GiveOrderToUnit(self.unitID, CMD_RECLAIM, {Game.maxUnits + jobs["reclaim"]}, {""}, 1)--{self.pos[1], self.pos[2], self.pos[3], self.range}, {""}, 1)
						self.currentJob = JOB_RECLAIM
						self.last_job_id = jobs["reclaim"]
					end
				elseif jobs["build"] then
					--Echo("Selecting build job")
					if self.last_job_id ~= jobs["build"] then
						GiveOrderToUnit(self.unitID, CMD_REPAIR, {jobs["build"]}, {""}, 1)
						self.currentJob = JOB_BUILD
						self.last_job_id = jobs["build"]
					end
				end
			end
		end
	end
}

function distance ( x1, y1, x2, y2 )
	local dx = (x1 - x2)
	local dy = (y1 - y2)
	return sqrt ( dx * dx + dy * dy )
end

function widget:CommandNotify(cmdID, params, options)
	if selectedCaretakers ~= nil then
		if (cmdID == CMD_STOP) then
			for i=1, #selectedCaretakers do
				UnitRegister[selectedCaretakers[i]].currentJob = JOB_IDLE
				UnitRegister[selectedCaretakers[i]].last_job_id = -1
			end
		else
			for i=1, #selectedCaretakers do
				UnitRegister[selectedCaretakers[i]].currentJob = JOB_OVERRIDE
				if #params==1 then
					UnitRegister[selectedCaretakers[i]].jobTargetID = params[1]
				else
					UnitRegister[selectedCaretakers[i]].jobTargetID = nil
				end
				UnitRegister[selectedCaretakers[i]].last_job_id = -1
			end
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedCaretakers = filterCaretakers(selectedUnits)
end

function filterCaretakers(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (caretakerUnitDefID == GetUnitDefID(unitID)) then
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



function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not (UnitRegister[unitID] == nil) then
		UnitRegister[unitID].currentJob = JOB_IDLE
		UnitRegister[unitID].last_job_id = -1
		UnitRegister[unitID]:handle()
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (string.match(UnitDefs[unitDefID].name, "dyn"))
			and (unitTeam==GetMyTeamID()) then
		originX, _, originZ = GetUnitPosition(unitID)
		Echo("Commander found, initializing X, Y, Z as " .. originX .. " " .. _ .. " " .. originZ)
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==target_name)
			and (unitTeam==GetMyTeamID()) then
		UnitRegister[unitID] = CaretakerController:new(unitID);
	end
end

-- removing transferred units
function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if not (UnitRegister[unitID]==nil) and unitID == GetMyTeamID() then
		UnitRegister[unitID]=UnitRegister[unitID]:unset();
	end
end

-- accepting transferred units - add them to register
function widget:UnitGiven(unitID, unitDefID, newTeam, unitTeam)
	if (UnitDefs[unitDefID].name==target_name)
			and (unitTeam==GetMyTeamID()) then
		UnitRegister[unitID] = CaretakerController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (UnitRegister[unitID]==nil) then
		UnitRegister[unitID]=UnitRegister[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%options.updateRate.value==0) then
		for _, TargetUnit in pairs(UnitRegister) do
			TargetUnit:handle()
			-- todo: switch to scheduled management model using value below
			TargetUnit.dontManageUntil = TargetUnit.dontManageUntil + options.updateRate.value + n%4
		end
	end
end

function widget:Initialize()
	-- disable if spectating or resigned
	widget:PlayerChanged()

	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==target_name)  then
			if  (UnitRegister[units[i]]==nil) then
				UnitRegister[units[i]]=CaretakerController:new(units[i])
			end
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
function widget:PlayerChanged(playerID)
	if GetSpecState() then
		Echo( widget:GetInfo().name .. ": Spectator mode. Widget removed." )
		widgetHandler:RemoveWidget(widget)
		return
	end
end
