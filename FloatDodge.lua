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

local BuyoStack = {}
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitWeaponState = Spring.GetUnitWeaponState
local Echo = Spring.Echo
local Buyo_ID = UnitDefNames.amphfloater.id
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_UNIT_FLOAT_STATE = 33412
local currentFrame = 0




local FloatControllerMT
local FloatController = {
	unitID,
	allyTeamID = GetMyAllyTeamID(),



	new = function(index, unitID)
		--Echo("FloatController added:" .. unitID)
		local self = {}
		setmetatable(self, FloatControllerMT)
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
FloatControllerMT = {__index = FloatController}


function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if (unitDefID == Buyo_ID)
	and (unitTeam==GetMyTeamID()) then
		BuyoStack[unitID] = FloatController:new(unitID);
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if (unitDefID == Buyo_ID)
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

-- The rest of the code is there to disable the widget for spectators
local function DisableForSpec()
	if GetSpecState() then
		widgetHandler:RemoveWidget(widget)
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(GetMyTeamID())
	for i=1, #units do
		local unitID = units[i]
		local unitDefID = GetUnitDefID(unitID)
		if (unitDefID == Buyo_ID)  then
			if  (BuyoStack[unitID]==nil) then
				BuyoStack[unitID]=FloatController:new(unitID)
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
