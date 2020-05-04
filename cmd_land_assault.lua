----------------------------------------------------------------------------------------------------------------------
-- Config
----------------------------------------------------------------------------------------------------------------------
version = "1.0"
cmd_dsc = "Command Swift to land optimally to fire on target area."
is_debug = false

--- At which range away from target units should land
BASE_RANGE = 600
RANK_CAPACITY = 28
INTER_RANK_SPACING = 50
--- Rotation between two neibor Swifts in a rank. Configures the distance between two neibors, ideally should be a
--- simple distance value, but currently the logic is based on circular formation.
DR = math.pi / 80
--- Distance for the first "correctional checkpoint". The next one is in double distance and so on.
STEP_DX_0_NORM = 400

-- @formatter:off
function widget:GetInfo() return {
    name    = "Swift Land Assault",
    desc    = "[v" .. version .. "] \n"
            .. " \n" -- at least one char to be included by parser as a separate line
            .. cmd_dsc .. "\n"
            .. " \n"
            .. "  The command is added with the same shortkey as for Reclaim command.\n"
    	    .. "The widget computes optimal positions for each Swift to attack an area around a selected point.\n"
            .. 'If the attack force is far enough, it also queues a set of \"correctional checkpoints\" Swifts have '
            .. "to pass through, which makes the final formation more focused at the center of attacking area.\n"
            .. "  It also automatically manages Fly/Land states unless a toggle was issued manually.\n"
            .. " \n"
            .. "  To achieve final optimal positioning Swifts land in a phalanx " .. RANK_CAPACITY .. " wide starting "
            .. "at " .. BASE_RANGE .. " elmos away from target. Distance between neiboring ranks = "
            .. INTER_RANK_SPACING .. ", and distance between neiboring Swifts within rank is as close as possible "
            .. "without them trying to overlap. Note that the logic is still not enough to achieve a perfect formation "
            .. "especially if the army will occupy more than a few ranks of a formation, so bigger your force is or "
            .. " more is it spread out - further away you need to issue the command.\n"
            .. " \n"
            .. "  Limitations: does not work with command queues; does not compute the shortest traversal paths like "
            .. "custom formations widget does; only works with single point; does not work with moving targets; still "
            .. "flaky with > 50 Swifts and not recommended to use for < 5 swifts - it's more optimal to issue manual "
            .. "line formation instead.",
    author  = "terve886, dahn",
    date    = "2020",
    license = "CC0",
    layer   = 2,
    handler = true,
    enabled = false,
} end
-- @formatter:on

----------------------------------------------------------------------------------------------------------------------
-- Includes
----------------------------------------------------------------------------------------------------------------------

LIBS_PATH = "LuaUI/Widgets/Libs"

VFS.Include(LIBS_PATH .. "/cmd.lua")
if is_debug then VFS.Include(LIBS_PATH .. "/table_to_string.lua") end
VFS.Include(LIBS_PATH .. "/deepcopy.lua")
VFS.Include(LIBS_PATH .. "/vector.lua")

----------------------------------------------------------------------------------------------------------------------
-- Speedups
----------------------------------------------------------------------------------------------------------------------

-- @formatter:off
local sin   = math.sin
local cos   = math.cos
local floor = math.floor

local GetUnitCommands = Spring.GetUnitCommands
local GetUnitStates   = Spring.GetUnitStates
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetTeamUnits    = Spring.GetTeamUnits
local GetMyTeamID     = Spring.GetMyTeamID
local GetUnitDefID    = Spring.GetUnitDefID
local GetSpecState    = Spring.GetSpectatingState
local MarkerAddPoint  = Spring.MarkerAddPoint
local Echo            = Spring.Echo
-- @formatter:on

----------------------------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------------------------

-- @formatter:off
local CMD_LAND_ATTACK = 19996
local SWIFT_NAME      = "planefighter"
local SWIFT_DEF_ID    = UnitDefNames[SWIFT_NAME].id

local CMD_LAND_ATTACK_DEF = {
    id      = CMD_LAND_ATTACK,
    type    = CMDTYPE.ICON_MAP,
    tooltip = cmd_dsc,
    cursor  = 'Attack',
    action  = 'reclaim',
    params  = {},
    texture = 'LuaUI/Images/commands/Bold/dgun.png',
    pos     = {
        CMD.ONOFF,
        CMD.REPEAT,
        CMD.MOVE_STATE,
        CMD.FIRE_STATE,
        CMD.RETREAT,
    },
}
-- @formatter:on

----------------------------------------------------------------------------------------------------------------------
-- Globals
----------------------------------------------------------------------------------------------------------------------

local land_attacker_controllers = {}
local selected_land_attackers = nil

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

--- Collective brain
local mission_control = {
    --- An average of all selected Swifts positions.
    cluster_center,
    --- A point the command was issued to.
    target_pos,
    --- An angle between the target position and the cluster center.
    rotation,
    --- Where the phalanx starts.
    base_rotation,
    
    --- Sets `target_pos`, computes and sets `cluster_pos` and `rotation`.
    process_target = function(self, target_pos)
        self.target_pos = target_pos
        
        self:_comp_cluster_center()
        
        self.rotation = v_atan(self.cluster_center, target_pos)
        
        local phalanx_length = RANK_CAPACITY -- avoiding `math.min`. see https://springrts.com/wiki/Lua_Performance
        if (#selected_land_attackers < phalanx_length) then phalanx_length = #selected_land_attackers end
        self.base_rotation = self.rotation - (DR * (phalanx_length - 1)) / 2
        
        if is_debug then
            MarkerAddPoint(self.target_pos[1], self.target_pos[2], self.target_pos[3], "target", false)
            MarkerAddPoint(self.cluster_center[1], self.cluster_center[2], self.cluster_center[3], "cluster center", false)
            Echo("rotation: " .. self.rotation)
        end
    end,
    
    _comp_cluster_center = function(self)
        self.cluster_center = { 0, 0, 0 }
        for i = 1, #selected_land_attackers do
            local controller = land_attacker_controllers[selected_land_attackers[i]]
            local pos = { GetUnitPosition(controller.unit_id) }
            self.cluster_center = v_add(self.cluster_center, pos)
        end
        self.cluster_center = v_div(self.cluster_center, #selected_land_attackers)
    end
}

--- Individual Swift controller. May use data from `mission_control`
local LandAttackerController = {
    unit_id,
    selection_idx,
    pos,
    rotation,
    max_range,
    target_pos,
    is_activated,
    
    new = function(self, unit_id)
        self = deepcopy(self)
        self.unit_id = unit_id
        self.max_range = GetUnitMaxRange(self.unit_id)
        self.pos = { GetUnitPosition(self.unit_id) }
        self.is_activated = false
        if is_debug then Echo("LandAttackController | added unit: " .. self.unit_id) end
        return self
    end,
    
    unset = function(self)
        GiveOrderToUnit(self.unit_id, CMD_STOP, {}, {}, 1)
        if is_debug then Echo("LandAttackController | removed unit: " .. self.unit_id) end
        return nil
    end,
    
    --- Executes a Land Attack order based on data in `mission_control`
    execute = function(self)
        self.pos = { GetUnitPosition(self.unit_id) }
        local landing_x, target_to_landing_dx = self:_compute_landing_x()
        
        -- this is weird and looks suboptimal
        -- but checkpoint orders do not work without this queue emptying for some reason even if we issue the first
        -- order directly not with insertion in hope to empty the queue
        local cmds = GetUnitCommands(self.unit_id, -1)
        for i = 0, #cmds do
            if cmds[i] and cmds[i].id ~= nil then
                GiveOrderToUnit(self.unit_id, CMD_REMOVE, { cmds[i].id }, CMD_OPT_ALT)
            end
        end
        
        local step_dx = v_mul(v_normalize(target_to_landing_dx), STEP_DX_0_NORM)
        local i = -1
        local x = landing_x
        local dst = v_norm(v_sub(x, self.pos))
        while dst > STEP_DX_0_NORM do
            x[2] = GetGroundHeight(x[1], x[3])
            GiveOrderToUnit(self.unit_id, CMD_INSERT,
                    { i, CMD_MOVE, CMD_OPT_INTERNAL, x[1], x[2], x[3] },
                    CMD_OPT_ALT
            )
            i = i - 1
            step_dx = v_mul(2, step_dx)
            dst = dst - v_norm(step_dx)
            x = v_add(x, step_dx)
        end
        
        GiveOrderToUnit(self.unit_id, CMD_IDLEMODE, 1, {}, CMD_OPT_ALT)
        
        self.is_activated = true
        
        if is_debug then Echo("LandAttackController"
                .. " | landing: " .. table_to_string(landing_x)
                .. " | attacker: " .. table_to_string(self.pos)
        ) end
    end,
    
    --- Processes any other non Land Attack order to manage Fly/Land state
    process_cmd = function(self)
        local is_autoland = GetUnitStates(self.unit_id).autoland
        if is_debug then Echo("LandAttackController | process_cmd | is_autoland = " .. tostring(is_autoland)
                .. " | is_activated = " .. tostring(self.is_activated)
                .. " | unit: " .. self.unit_id
        ) end
        if (is_autoland and self.is_activated) then
            self:_cancel()
        end
    end,
    
    _cancel = function(self)
        if is_debug then Echo("LandAttackController | cancel | unit: " .. self.unit_id) end
        GiveOrderToUnit(self.unit_id, CMD_IDLEMODE, 0, {}, 0)
        self.is_activated = false
    end,
    
    _compute_landing_x = function(self)
        local rotation = mission_control.base_rotation + DR * (self.selection_idx % RANK_CAPACITY)
        
        local rank_idx = floor(self.selection_idx / RANK_CAPACITY)
        local range = BASE_RANGE + INTER_RANK_SPACING * rank_idx
        
        local target_to_landing_dx = v_mul({ sin(rotation), 0, cos(rotation) }, range)
        
        local landing_x = v_add(mission_control.target_pos, target_to_landing_dx)
        landing_x[2] = GetGroundHeight(landing_x[1], landing_x[3])
        
        if is_debug then Echo("LandAttackController | _compute_landing_pos | " .. table_to_string(landing_x)) end
        return landing_x, target_to_landing_dx
    end,
}

function find_land_attackers(units)
    local res = {}
    local n = 0
    for i = 1, #units do
        local unit_id = units[i]
        if (SWIFT_DEF_ID == GetUnitDefID(unit_id)) then
            n = n + 1
            res[n] = unit_id
        end
    end
    if n == 0 then
        return nil
    else
        return res
    end
end

function widget:UnitFinished(unit_id, unit_def_if, unit_team)
    if (unit_def_if == SWIFT_DEF_ID and unit_team == GetMyTeamID()) then
        land_attacker_controllers[unit_id] = LandAttackerController:new(unit_id);
    end
end

function widget:UnitDestroyed(unit_id)
    local land_attacker_controller = land_attacker_controllers[unit_id]
    if (land_attacker_controller ~= nil) then
        land_attacker_controllers[unit_id] = land_attacker_controller:unset()
    end
end

----------------------------------------------------------------------------------------------------------------------
-- Command Handling
----------------------------------------------------------------------------------------------------------------------

function debug_cmd(callin_name, unit_id, cmd_id, cmd_params, cmd_opts)
    local cmd
    if cmd_id == CMD_LAND_ATTACK then cmd = "LAND_ATTACK" else cmd = CMD[cmd_id] end
    if cmd == nil then cmd = cmd_id .. "(?)" end
    if is_debug then Echo(callin_name
            .. " | " .. cmd
            .. " | params: " .. table_to_string(cmd_params)
            .. " | opts: " .. table_to_string(cmd_opts)
            .. " | unit: " .. unit_id
    ) end
end

--- FIGHT, PATROL, GUARD, LOOPBACKATTACK, etc are processed here
---
--- From https://springrts.com/wiki/Lua:Callins :
--- Called after when a unit accepts a command, after AllowCommand returns true.
--- (Synced/Unsynced shared)
function widget:UnitCommand(unit_id, unit_def_if, unit_team, cmd_id, cmd_params, cmd_opts, cmd_tag)
    if is_debug then debug_cmd("UnitCommand", unit_id, cmd_id, cmd_params, cmd_opts) end
    if (unit_def_if == SWIFT_DEF_ID) then
        local ctrl = land_attacker_controllers[unit_id]
        if (ctrl) then ctrl:process_cmd(cmd_id) end
    end
end

--- Called for newly introduced CMD_LAND_ATTACK
---
--- From https://springrts.com/wiki/Lua:Callins :
--- Called when a command is issued. Returning true deletes the command and does not send it through the network.
--- (Unsynced only)
function widget:CommandNotify(cmd_id, cmd_params, cmd_opts)
    if selected_land_attackers ~= nil then
        if is_debug then debug_cmd("CommandNotify", unit_id, cmd_id, cmd_params, cmd_opts) end
        if (cmd_id == CMD_LAND_ATTACK and #cmd_params == 3) then
            local target_pos = cmd_params
            mission_control:process_target(target_pos)
            for i = 1, #selected_land_attackers do
                land_attacker_controllers[selected_land_attackers[i]]:execute(target_pos)
            end
            return true
        else
            for i = 1, #selected_land_attackers do
                local land_attacker_controller = land_attacker_controllers[selected_land_attackers[i]]
                if (land_attacker_controller) then land_attacker_controller:process_cmd(cmd_id) end
            end
        end
    end
end

function widget:SelectionChanged(selected_units)
    selected_land_attackers = find_land_attackers(selected_units)
    if selected_land_attackers ~= nil then
        for i = 1, #selected_land_attackers do
            local land_attacker_controller = land_attacker_controllers[selected_land_attackers[i]]
            if (land_attacker_controller) then land_attacker_controller.selection_idx = i end
        end
    end
end

function widget:CommandsChanged()
    if selected_land_attackers then
        local customCommands = widgetHandler.customCommands
        customCommands[#customCommands + 1] = CMD_LAND_ATTACK_DEF
    end
end

----------------------------------------------------------------------------------------------------------------------
-- Disable for spec
----------------------------------------------------------------------------------------------------------------------

local function DisableForSpec()
    if GetSpecState() then
        widgetHandler:RemoveWidget()
    end
end

function widget:PlayerChanged(playerID)
    DisableForSpec()
end

function widget:Initialize()
    DisableForSpec()
    local units = GetTeamUnits(GetMyTeamID())
    for i = 1, #units do
        unit_id = units[i]
        if (UnitDefs[GetUnitDefID(unit_id)].name == SWIFT_NAME) then
            if (land_attacker_controllers[unit_id] == nil) then
                land_attacker_controllers[unit_id] = LandAttackerController:new(unit_id)
            end
        end
    end
end

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
