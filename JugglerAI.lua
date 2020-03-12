function widget:GetInfo()
   return {
      name         = "JugglerAI",
      desc         = "attempt to make AI for Juggler. Version 1.00",
      author       = "terve886, parts by ivand/Shaman",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 10,
	  handler		= true, --for adding customCommand into UI
      enabled      = true
   }
end
local sqrt = math.sqrt
local UPDATE_FRAME=10
local JuggleStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitVelocity = Spring.GetUnitVelocity
local GetGroundHeight = Spring.GetGroundHeight
local nearest = Spring.GetUnitNearestAlly
local target = Spring.SetUnitTarget
local GetUnitArmored = Spring.GetUnitArmored
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitHealth = Spring.GetUnitHealth
local GetUnitWeaponTarget  = Spring.GetUnitWeaponTarget 
local ENEMY_DETECT_BUFFER  = 60
local Echo = Spring.Echo
local Jugglenaut_NAME = "jumpsumo"
local Crab_NAME = "spidercrabe"
local Imp_NAME = "cloakbomb"
local Scuttle_NAME = "jumpbomb"
local Snitch_NAME = "shieldbomb"
local Puppy_NAME = "jumpscout"
local Limpet_NAME = "amphbomb"
local CMD_PUSH_PULL = 35666
local Pull = 0
local Push = 1
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924

local GRAVITY = -Game.gravity/30/30
local AIR_DENSITY = 1.2/4
local DRAG_COEFF = 1.0
local radius = UnitDefNames["jumpsumo"].radius

local selectedJugglers = nil

local CMD_TOGGLE_SWITCH = 19890
local JugglenautUnitDefID = UnitDefNames["jumpsumo"].id


local cmdToggle = {
	id      = CMD_TOGGLE_SWITCH,
	type    = CMDTYPE.ICON,
	tooltip = 'Makes Jugglenaut switch between push and pull automatically when enemy is near',
	action  = 'reclaim',
	params  = { }, 
	texture = 'LuaUI/Images/commands/states/ai_on.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},  
}

local JuggleAI = {
	unitID,
	allyTeamID = GetMyAllyTeamID(),
	range,
	maxHealth,
	toggle = true,
	checkpoint = -1,
	
	new = function(self, unitID)
		--Echo("JuggleAI added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.maxHealth = UnitDefs[GetUnitDefID(self.unitID)].health
		return self
	end,

	unset = function(self)
		--Echo("JuggleAI removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	getToggleState = function(self)
		return self.toggle
	end,
	
	toggleOn = function (self)
		self.toggle = true
		Echo("JuggleAI toggled On")
	end,
	
	toggleOff = function (self)
		self.toggle = false
		Echo("JuggleAI toggled Off")
	end,

    pushBombsAndPullAircraft = function (self)
        if (GetUnitHealth(self.unitID)<self.maxHealth*0.3)then --Health too low to pull units without risk of death.
            local target = {GetUnitWeaponTarget(self.unitID, 1)}
            if(target[1]==1)then
                if not(GetUnitAllyTeam(target[3]) == self.allyTeamID) then
                    DefID = GetUnitDefID(target[3])
                    if not(DefID == nil)then
                        if (UnitDefs[DefID].isAirUnit == true)then
                            GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0) --Still wants to pull Aircraft.
                            return
                        end
                    end
                end
            else
                target = {GetUnitWeaponTarget(self.unitID, 2)}
                if(target[1]==1)then
                    if not(GetUnitAllyTeam(target[3]) == self.allyTeamID) then
                        DefID = GetUnitDefID(target[3])
                        if not(DefID == nil)then
                            if (UnitDefs[DefID].isAirUnit == true)then
                                GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)--Still wants to pull Aircraft.
                                return
                            end
                        end
                    end
                end
            end
            GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
            return
        end

        local target = {GetUnitWeaponTarget(self.unitID, 1)}
        if(target[1]==1)then
            if not (GetUnitAllyTeam(target[3]) == self.allyTeamID) then
                DefID = GetUnitDefID(target[3])
                if not(DefID == nil)then
                    if(UnitDefs[DefID].name==Imp_NAME or UnitDefs[DefID].name==Scuttle_NAME or UnitDefs[DefID].name==Snitch_NAME or UnitDefs[DefID].name==Puppy_NAME or UnitDefs[DefID].name==Limpet_NAME) then
                        GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
                        return
                    end
                    if (UnitDefs[DefID].isAirUnit == true)then
                        GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)--Still wants to pull Aircraft.
                        return
                    end
                end
            end
        else
            target = {GetUnitWeaponTarget(self.unitID, 2)}
            if(target[1]==1)then
                if not (GetUnitAllyTeam(target[3]) == self.allyTeamID) then
                    DefID = GetUnitDefID(target[3])
                    if not(DefID == nil)then
                        if(UnitDefs[DefID].name==Imp_NAME or UnitDefs[DefID].name==Scuttle_NAME or UnitDefs[DefID].name==Snitch_NAME or UnitDefs[DefID].name==Puppy_NAME or UnitDefs[DefID].name==Limpet_NAME) then
                            GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
                            return
                        end
                        if (UnitDefs[DefID].isAirUnit == true)then
                            GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)--Still wants to pull Aircraft.
                            return
                        end
                    end
                end
            end
        end
    end,

	handle = function(self)
		if (GetUnitHealth(self.unitID)<self.maxHealth*0.3)then
			local target = {GetUnitWeaponTarget(self.unitID, 1)}
			if(target[1]==1)then
				if not(GetUnitAllyTeam(target[3]) == self.allyTeamID) then
					DefID = GetUnitDefID(target[3])
					if not(DefID == nil)then
						if (UnitDefs[DefID].isAirUnit == true)then
							GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)
							return
						end
					end
				end
			else
				target = {GetUnitWeaponTarget(self.unitID, 2)}
				if(target[1]==1)then
					if not(GetUnitAllyTeam(target[3]) == self.allyTeamID) then
						DefID = GetUnitDefID(target[3])
						if not(DefID == nil)then
							if (UnitDefs[DefID].isAirUnit == true)then
								GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)
								return
							end
						end
					end
				end
			end
			GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
			return
		end

		if (self.toggle)then
			self.checkpoint = self.checkpoint+1
			local target = {GetUnitWeaponTarget(self.unitID, 1)}
			if(target[1]==1)then
				if (WillHitMe(self.unitID, radius, target[3], Spring.GetUnitMass(target[3]), Spring.GetUnitRadius(target[3]), 25, 20))then
					GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
					return
				end
				if not(GetUnitAllyTeam(target[3]) == self.allyTeamID) then
					DefID = GetUnitDefID(target[3])
					local hasArmor = GetUnitArmored(target[3])
					if not(DefID == nil)then
						if (UnitDefs[DefID].isBuilding == false)then
							if (self.checkpoint == 5)then
								if (UnitDefs[DefID].isAirUnit==true or (UnitDefs[DefID].name==Crab_NAME and hasArmor==false))then
									GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)
									return
								else
									GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
								end
								return
							end
							if (self.checkpoint >= 10)then
								self.checkpoint = -1
								if((UnitDefs[DefID].mass>380 and UnitDefs[DefID].name~=Crab_NAME) or UnitDefs[DefID].name==Imp_NAME or UnitDefs[DefID].name==Scuttle_NAME or UnitDefs[DefID].name==Snitch_NAME or UnitDefs[DefID].name==Puppy_NAME or UnitDefs[DefID].name==Limpet_NAME) then
									GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
								else
									GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)
								end
								return
							end

							if (UnitDefs[DefID].isAirUnit==true or (UnitDefs[DefID].name==Crab_NAME and hasArmor==false))then
								GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)
								return
							end

							if((UnitDefs[DefID].mass>380 and UnitDefs[DefID].name~=Crab_NAME) or UnitDefs[DefID].name==Imp_NAME
									or UnitDefs[DefID].name==Scuttle_NAME
									or UnitDefs[DefID].name==Snitch_NAME
									or UnitDefs[DefID].name==Puppy_NAME
									or UnitDefs[DefID].name==Limpet_NAME) then
								GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
								return
							end
						end
					end
				end
			else
				target = {GetUnitWeaponTarget(self.unitID, 2)}
				if(target[1]==1)then
					if (WillHitMe(self.unitID, radius, target[3], Spring.GetUnitMass(target[3]), Spring.GetUnitRadius(target[3]), 25, 20))then
						GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
						return
					end
					if not(GetUnitAllyTeam(target[3]) == self.allyTeamID) then
						DefID = GetUnitDefID(target[3])
						local hasArmor = GetUnitArmored(target[3])
						if not(DefID == nil)then
							if (UnitDefs[DefID].isBuilding == false)then
								if (self.checkpoint == 5)then
									if (UnitDefs[DefID].isAirUnit==true or (UnitDefs[DefID].name==Crab_NAME and hasArmor==false))then
										GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)
										return
									else
										GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
									end
									return
								end
								if (self.checkpoint >= 10)then
									self.checkpoint = -1
									if((UnitDefs[DefID].mass>380 and UnitDefs[DefID].name~=Crab_NAME) or UnitDefs[DefID].name==Imp_NAME or UnitDefs[DefID].name==Scuttle_NAME or UnitDefs[DefID].name==Snitch_NAME or UnitDefs[DefID].name==Puppy_NAME or UnitDefs[DefID].name==Limpet_NAME) then
										GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
									else
										GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)
									end
									return
								end

								if (UnitDefs[DefID].isAirUnit==true or (UnitDefs[DefID].name==Crab_NAME and hasArmor==false))then
									GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Pull}, 0)
									return
								end

								if((UnitDefs[DefID].mass>380 and UnitDefs[DefID].name~=Crab_NAME) or UnitDefs[DefID].name==Imp_NAME
										or UnitDefs[DefID].name==Scuttle_NAME
										or UnitDefs[DefID].name==Snitch_NAME
										or UnitDefs[DefID].name==Puppy_NAME
										or UnitDefs[DefID].name==Limpet_NAME) then
									GiveOrderToUnit(self.unitID,CMD_PUSH_PULL, {Push}, 0)
									return
								end
							end
						end
					end
				end
			end
		else
			self:pushBombsAndPullAircraft()
		end
	end
}

local function GetDragAccelerationVec(vx, vy, vz, mass, radius)


    local sx = vx <= 0 and -1 or 1
    local sy = vy <= 0 and -1 or 1
    local sz = vz <= 0 and -1 or 1

    local dragScale = 0.5 * AIR_DENSITY * DRAG_COEFF * (math.pi * radius * radius * 0.01 * 0.01)

    return
        math.clamp((vx * vx * dragScale * -sx) / mass, -math.abs(vx), math.abs(vx)),
        math.clamp((vy * vy * dragScale * -sy) / mass, -math.abs(vy), math.abs(vy)),
        math.clamp((vz * vz * dragScale * -sz) / mass, -math.abs(vz), math.abs(vz));
end

function WillHitMe(unitID, unitRadius, targetID, targetMass, targetRadius, frames, distTolerance)
	DefID = GetUnitDefID(targetID)
	if(DefID and UnitDefs[DefID].isAirUnit==true)then
		return false
	end
	local tvx, tvy, tvz = GetUnitVelocity(targetID)
	if (tvx==nil)then
		return false
	end
	local _, _, _, umx, umy, umz  = GetUnitPosition(unitID, true) --mid pos
	local tx, ty, tz, tmx, tmy, tmz  = GetUnitPosition(targetID, true) --mid pos
	
	if (tmx==nil)then
		return false
	end
	local tox, toy, toz = tmx - tx, tmy - ty, tmz - tz --offsets

	for i = 1, frames do
		height = GetGroundHeight(tx, tz)
		if ty > height then
			tvy = tvy + GRAVITY
			local dx, dy, dz = GetDragAccelerationVec(tvx, tvy, tvz, targetMass, targetRadius)
			tvx, tvy, tvz = tvx + dx, tvy + dy, tvz + dz --drag will decrease velocity

			tx, ty, tz = tx + tvx, ty + tvy, tz + tvz

			if ty <= GetGroundHeight(tx, tz) then --crashed onto land
				tvy = 0
			end
		else
			tx, ty, tz = tx + tvx, height, tz + tvz
		end

		tmx, tmy, tmz = tx + tox, ty + toy, tz + toz --apply offsets

		local distance = sqrt( (umx - tmx)^2 + (umy - tmy)^2 + (umz - tmz)^2 ) - unitRadius - targetRadius

		if distance < distTolerance then
			return true
		end
	end
	return false
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Jugglenaut_NAME)
		and (unitTeam==GetMyTeamID()) then
			JuggleStack[unitID] = JuggleAI:new(unitID);
		end
end

function widget:UnitDestroyed(unitID)
	if not (JuggleStack[unitID]==nil) then
		JuggleStack[unitID]=JuggleStack[unitID]:unset();
	end
end

function widget:GameFrame(n) 
	if (n%UPDATE_FRAME==0) then
		for _,juggle in pairs(JuggleStack) do
			juggle:handle()
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
	if selectedJugglers ~= nil then
		if (cmdID == CMD_TOGGLE_SWITCH)then
			local toggleStateGot = false
			local toggleState
			for i=1, #selectedJugglers do
				if (JuggleStack[selectedJugglers[i]])then
					if (toggleStateGot == false)then
						toggleState = JuggleStack[selectedJugglers[i]]:getToggleState()
						toggleStateGot = true
					end
					if (toggleState) then
						JuggleStack[selectedJugglers[i]]:toggleOff()
					else
						JuggleStack[selectedJugglers[i]]:toggleOn()
					end
				end
			end
			return true
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedJugglers = filterJuggles(selectedUnits)
end

function filterJuggles(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (JugglenautUnitDefID == GetUnitDefID(unitID)) then
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
	if selectedJugglers then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdToggle
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
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==Jugglenaut_NAME)  then
			if  (JuggleStack[units[i]]==nil) then
				JuggleStack[units[i]]=JuggleAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
