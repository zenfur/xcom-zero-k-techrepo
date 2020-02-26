function widget:GetInfo()
   return {
    name      = "FloatDodge",
    desc      = "Makes Buyos sink while reloading. Version 1.0",
    author    = "terve886",
    date      = "2020",
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
local BuyoStack = {}
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
local GetUnitWeaponState = Spring.GetUnitWeaponState
local myPlayerID = GetMyPlayerID()
local ping = 0
local ENEMY_DETECT_BUFFER  = 74
local Echo = Spring.Echo
local Buyo_NAME = "amphfloater"
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
local CMD_UNIT_FLOAT_STATE = 33412
local currentFrame = 0




local FloatController = {
	unitID,
	allyTeamID = GetMyAllyTeamID(),
	
	
	
	new = function(self, unitID)
		--Echo("FloatController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		return self
	end,

	unset = function(self)
		--Echo("FloatController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,



	handle=function(self)
		--local CMDDescID = Spring.FindUnitCmdDesc(self.unitID, CMD_UNIT_FLOAT_STATE)
		--if CMDDescID then
		--local cmdDesc = Spring.GetUnitCmdDescs(self.unitID, CMDDescID, CMDDescID)
		--local nparams = cmdDesc[1].params
		--if(nparams[1]~="2")then
		if(GetUnitWeaponState(self.unitID, 1, "reloadState") <= currentFrame+12)then
			GiveOrderToUnit(self.unitID,CMD_UNIT_FLOAT_STATE, 1, 0)
		else
			GiveOrderToUnit(self.unitID,CMD_UNIT_FLOAT_STATE, 0, 0)
		end
		--end
		--end
	end
}


function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if (UnitDefs[unitDefID].name==Buyo_NAME)
	and (unitTeam==GetMyTeamID()) then
		BuyoStack[unitID] = FloatController:new(unitID);
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if (UnitDefs[unitDefID].name==Buyo_NAME)
		and not BuyoStack[unitID] then
		BuyoStack[unitID] = FloatController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID) 
	if not (BuyoStack[unitID]==nil) then
		BuyoStack[unitID]=BuyoStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	currentFrame = n
	for _,Buyo in pairs(BuyoStack) do
		Buyo:handle()
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
	local units = GetTeamUnits(GetMyTeamID())
	for i=1, #units do
		unitID = units[i]
		DefID = GetUnitDefID(unitID)
		if (UnitDefs[DefID].name==Buyo_NAME)  then
			if  (BuyoStack[unitID]==nil) then
				BuyoStack[unitID]=FloatController:new(unitID)
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
