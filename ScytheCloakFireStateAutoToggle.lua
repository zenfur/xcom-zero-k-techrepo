function widget:GetInfo()
   return {
      name         = "ScytheCloakFireStateAutoToggle",
      desc         = "Makes Scythes automatically return fire when cloaked and fire at will when decloaked. Version 0,97",
      author       = "terve886",
      date         = "2020",
      license      = "PD", -- should be compatible with Spring
      layer        = 10,
      enabled      = true
   }
end
local UPDATE_FRAME=5
local currentFrame = 0
local ScytheStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit

local Scythe_NAME = "cloakheavyraid"
local Scythe_UnitDef = UnitDefNames[Scythe_NAME].id


local GetUnitWeaponState = Spring.GetUnitWeaponState
local GetUnitIsCloaked = Spring.GetUnitIsCloaked
local GetUnitStates = Spring.GetUnitStates
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local IsUnitSelected = Spring.IsUnitSelected
local GetTeamUnits = Spring.GetTeamUnits
local GetTeamResources = Spring.GetTeamResources
local MarkerAddPoint = Spring.MarkerAddPoint
local GetCommandQueue = Spring.GetCommandQueue
local GetUnitHeading = Spring.GetUnitHeading
local team_id
local Echo = Spring.Echo
local pi = math.pi
local FULL_CIRCLE_RADIANT = 2 * pi
local HEADING_TO_RAD = (pi*2/65536 )
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_MOVE = CMD.MOVE
local CMD_ATTACK_MOVE_ID = 16
local CMD_FIRE_STATE = CMD.FIRE_STATE
local HalfPi = math.pi/2
local atan = math.atan
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt

local GetSpecState = Spring.GetSpectatingState



function widget:UnitDecloaked(unitID, unitDefID, teamID)
	if (unitDefID==Scythe_UnitDef) then
		GiveOrderToUnit(unitID,CMD_FIRE_STATE, 2, 0)
	end
end 

function widget:UnitCloaked(unitID, unitDefID, teamID)
	if (unitDefID==Scythe_UnitDef) then
		GiveOrderToUnit(unitID,CMD_FIRE_STATE, 1, 0)
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
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
