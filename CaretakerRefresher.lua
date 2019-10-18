function widget:GetInfo()
   return {
      name         = "CaretakerRefresher",
      desc         = "Refreshes caretaker jobs prioritizing repair and reclaim. Version v0.1",
      author       = "zenfur",
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

local ENEMY_DETECT_BUFFER  = 40
local Echo = Spring.Echo
local target_name = "staticcon"

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

 -- area job removal tool stuff --
	widget:MousePress()
		Captures the starting coords for the area select, sets state.
	widget:MouseMove()
		Tracks the mouse after a selection has started, and updates the selection
		radius for drawing.
	widget:MouseRelease()
		Captures the final values for the area select and activates the removal function.
		Also updates state depending on shift, to allow for additional selections or to deactivate
		the tool.

Jobs:
#1 Register Caretakers on create and unregister on death - done
#2 Every options.updateRate + some random refresh said caretaker job
#3 Count caretakers, Count income, count storage
#4 Count jobs in caretaker's range -> Reclaim, Aggresive reclaim, Repair, Build
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
	dontManageUntil = 0,
	
	new = function(self, unitID)
		Echo("CaretakerController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		DefID = GetUnitDefID(unitID)
		self.range = UnitDefs[DefID].buildDistance
		self.pos = {GetUnitPosition(self.unitID)}
		self.jobs = {}
		return self
	end,

	unset = function(self)
		Echo("CaretakerController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	setForceTarget = function(self, param)
		self.forceTarget = param[1]
	end,

	findJobs = function(self)
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
		for index, w in ipairs(wrecks) do
			if w then
				metal = select(1, GetFeatureResources(w))
				xx, yy, zz = GetFeaturePosition(w)
				dist = (xx-originX)*(xx-originX) + (zz-originZ)*(zz-originZ)
				if metal > 0 then
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
				if bp < 1.0 then
					sabotage_job = unit
				end
			else
				if bp < 1.0 then
					if GetUnitStates(self.unitID).movestate > 1 -- if set to ROAM accept ally buildorders
					  or self.selfTeamID == GetUnitTeam(unit) then
						build_job = unit
					end
				elseif hp < mxhp then
					repair_job = unit
				end
			end
		end
		
		Echo("Found jobs for " .. self.unitID)
		if reclaim_job then
			Echo("Reclaim job found")
		end
		if sabotage_job then
			Echo("Sabotage job found")
		end
		if repair_job then
			Echo("Repair job found")
		end
		if build_job then
			Echo("Building job found")
		end
		return {repair = repair_job, sabotage = sabotage_job, reclaim = reclaim_job, build = build_job}
	end,
	
	handle=function(self)
		if (GetUnitStates(self.unitID).movestate > 0) then
			--[[ manage todo:
				if guarding check if guard target is in range
				if repairing check if repair target is in range
				if constructing check for jobs if repair or 
			--]]
			-- GiveOrderToUnit(self.unitID, CMD_STOP, {}, {""},1)
			-- GiveOrderToUnit(self.unitID, CMD_PATROL, {GetUnitPosition(self.unitID)}, {""},1)
			jobs = self:findJobs()
			if jobs["sabotage"] then
				Echo("Ordering Sabotage job!")
				GiveOrderToUnit(self.unitID, CMD_RECLAIM, {jobs["sabotage"]}, {""}, 1)
				self.currentJob = JOB_SABOTAGE
			elseif jobs["repair"] then 
				GiveOrderToUnit(self.unitID, CMD_REPAIR, {jobs["repair"]}, {""}, 1)
				self.currentJob = JOB_REPAIR
			elseif jobs["reclaim"] then
				GiveOrderToUnit(self.unitID, CMD_RECLAIM, {jobs["reclaim"]}, {""}, 1)
				self.currentJob = JOB_RECLAIM
			elseif jobs["build"] then
				GiveOrderToUnit(self.unitID, CMD_REPAIR, {jobs["build"]}, {""}, 1)
				self.currentJob = JOB_BUILD
			end
			
		end
	end
}

-- function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	--if (UnitDefs[unitDefID].name == target_name and cmdID == CMD_ATTACK  and #cmdParams == 1) then
	-- if the command is issued when unit is selected - and the command is "repair" or "reclaim" - exempt from management
	-- if the command is patrol - resume the management
-- end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if (string.match(UnitDefs[unitDefID].name, "dyn"))
    and (unitTeam==GetMyTeamID()) then
        originX, _, originZ = GetUnitPosition(unitID)
    end

	if (UnitDefs[unitDefID].name==target_name)
	and (unitTeam==GetMyTeamID()) then
		UnitRegister[unitID] = CaretakerController:new(unitID);
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if not (UnitRegister[unitID]==nil) then
		UnitRegister[unitID]=UnitRegister[unitID]:unset();
	end
end

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






