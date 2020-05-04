--[[
These CMD_* constants are here to save table lookups when accessing CMD.* values.
See [Lua_Performance](https://springrts.com/wiki/Lua_Performance).

CMD defs:
- Engine: [/rts/Sim/Units/CommandAI/Command.h](https://github.com/spring/spring/blob/5c28061093a8ff47aa5021d12159bc4c503c7188/rts/Sim/Units/CommandAI/Command.h)
- Zero-K: [/LuaRules/Configs/customcmds.lua](https://github.com/ZeroK-RTS/Zero-K/blob/77708b2f0ef3d156192478aa29e4fef94c9dd9a5/LuaRules/Configs/customcmds.lua)
]]

---
-- Engine
---

CMD_STOP            = CMD.STOP
CMD_INSERT          = CMD.INSERT
CMD_REMOVE          = CMD.REMOVE
CMD_WAIT            = CMD.WAIT
CMD_TIMEWAIT        = CMD.TIMEWAIT
CMD_DEATHWAIT       = CMD.DEATHWAIT
CMD_SQUADWAIT       = CMD.SQUADWAIT
CMD_GATHERWAIT      = CMD.GATHERWAIT
CMD_MOVE            = CMD.MOVE
CMD_PATROL          = CMD.PATROL
CMD_FIGHT           = CMD.FIGHT
CMD_ATTACK          = CMD.ATTACK
CMD_AREA_ATTACK     = CMD.AREA_ATTACK
CMD_GUARD           = CMD.GUARD
CMD_AISELECT        = CMD.AISELECT
CMD_GROUPSELECT     = CMD.GROUPSELECT
CMD_GROUPADD        = CMD.GROUPADD
CMD_GROUPCLEAR      = CMD.GROUPCLEAR
CMD_REPAIR          = CMD.REPAIR
CMD_FIRE_STATE      = CMD.FIRE_STATE
CMD_MOVE_STATE      = CMD.MOVE_STATE
CMD_SETBASE         = CMD.SETBASE
CMD_INTERNAL        = CMD.INTERNAL
CMD_SELFD           = CMD.SELFD
CMD_LOAD_UNITS      = CMD.LOAD_UNITS
CMD_LOAD_ONTO       = CMD.LOAD_ONTO
CMD_UNLOAD_UNITS    = CMD.UNLOAD_UNITS
CMD_UNLOAD_UNIT     = CMD.UNLOAD_UNIT
CMD_ONOFF           = CMD.ONOFF
CMD_RECLAIM         = CMD.RECLAIM
CMD_CLOAK           = CMD.CLOAK
CMD_STOCKPILE       = CMD.STOCKPILE
CMD_MANUALFIRE      = CMD.MANUALFIRE
CMD_RESTORE         = CMD.RESTORE
CMD_REPEAT          = CMD.REPEAT
CMD_TRAJECTORY      = CMD.TRAJECTORY
CMD_RESURRECT       = CMD.RESURRECT
CMD_CAPTURE         = CMD.CAPTURE
CMD_AUTOREPAIRLEVEL = CMD.AUTOREPAIRLEVEL
CMD_IDLEMODE        = CMD.IDLEMODE
CMD_FAILED          = CMD.FAILED

CMDTYPE_ICON                      = CMDTYPE.ICON
CMDTYPE_ICON_MODE                 = CMDTYPE.ICON_MODE
CMDTYPE_ICON_MAP                  = CMDTYPE.ICON_MAP
CMDTYPE_ICON_AREA                 = CMDTYPE.ICON_AREA
CMDTYPE_ICON_UNIT                 = CMDTYPE.ICON_UNIT
CMDTYPE_ICON_UNIT_OR_MAP          = CMDTYPE.ICON_UNIT_OR_MAP
CMDTYPE_ICON_FRONT                = CMDTYPE.ICON_FRONT
CMDTYPE_ICON_UNIT_OR_AREA         = CMDTYPE.ICON_UNIT_OR_AREA
CMDTYPE_NEXT                      = CMDTYPE.NEXT
CMDTYPE_PREV                      = CMDTYPE.PREV
CMDTYPE_ICON_UNIT_FEATURE_OR_AREA = CMDTYPE.ICON_UNIT_FEATURE_OR_AREA
CMDTYPE_ICON_BUILDING             = CMDTYPE.ICON_BUILDING
CMDTYPE_CUSTOM                    = CMDTYPE.CUSTOM
CMDTYPE_ICON_UNIT_OR_RECTANGLE    = CMDTYPE.ICON_UNIT_OR_RECTANGLE
CMDTYPE_NUMBER                    = CMDTYPE.NUMBER

CMD_OPT_ALT      = CMD.OPT_ALT
CMD_OPT_CTRL     = CMD.OPT_CTRL
CMD_OPT_SHIFT    = CMD.OPT_SHIFT
CMD_OPT_RIGHT    = CMD.OPT_RIGHT
CMD_OPT_INTERNAL = CMD.OPT_INTERNAL
CMD_OPT_META     = CMD.OPT_META

---
-- Zero-K
---

--VFS.Include("LuaRules/Configs/customcmds.lua")
---- Note: there is LuaRules/Configs/customcmds.lua which does the same but in a programmatic manner which completely
---- destroys any IDE's auto-completion, so here is the full explicit list.
--
--CMD_RETREAT_ZONE           = cmds.RETREAT_ZONE
--CMD_RESETFIRE              = cmds.RESETFIRE
--CMD_RESETMOVE              = cmds.RESETMOVE
--CMD_BUILDPREV              = cmds.BUILDPREV
--CMD_RADIALBUILDMENU        = cmds.RADIALBUILDMENU
--CMD_SET_AI_START           = cmds.SET_AI_START
--CMD_BUILD                  = cmds.BUILD
--CMD_NEWTON_FIREZONE        = cmds.NEWTON_FIREZONE
--CMD_STOP_NEWTON_FIREZONE   = cmds.STOP_NEWTON_FIREZONE
--CMD_SET_FERRY              = cmds.SET_FERRY
--CMD_CHEAT_GIVE             = cmds.CHEAT_GIVE
--CMD_FACTORY_GUARD          = cmds.FACTORY_GUARD
--CMD_AREA_GUARD             = cmds.AREA_GUARD
--CMD_ORBIT                  = cmds.ORBIT
--CMD_ORBIT_DRAW             = cmds.ORBIT_DRAW
--CMD_GLOBAL_BUILD           = cmds.GLOBAL_BUILD
--CMD_GBCANCEL               = cmds.GBCANCEL
--CMD_STOP_PRODUCTION        = cmds.STOP_PRODUCTION
--CMD_SELECTION_RANK         = cmds.SELECTION_RANK
--CMD_SELECT_MISSILES        = cmds.SELECT_MISSILES
--CMD_AREA_MEX               = cmds.AREA_MEX
--CMD_STEALTH                = cmds.STEALTH
--CMD_CLOAK_SHIELD           = cmds.CLOAK_SHIELD
--CMD_MINE                   = cmds.MINE
--CMD_RAW_MOVE               = cmds.RAW_MOVE
--CMD_RAW_BUILD              = cmds.RAW_BUILD
--CMD_EMBARK                 = cmds.EMBARK
--CMD_DISEMBARK              = cmds.DISEMBARK
--CMD_TRANSPORTTO            = cmds.TRANSPORTTO
--CMD_EXTENDED_LOAD          = cmds.EXTENDED_LOAD
--CMD_EXTENDED_UNLOAD        = cmds.EXTENDED_UNLOAD
--CMD_LOADUNITS_SELECTED     = cmds.LOADUNITS_SELECTED
--CMD_AUTO_CALL_TRANSPORT    = cmds.AUTO_CALL_TRANSPORT
--CMD_MORPH_UPGRADE_INTERNAL = cmds.MORPH_UPGRADE_INTERNAL
--CMD_UPGRADE_STOP           = cmds.UPGRADE_STOP
--CMD_MORPH                  = cmds.MORPH
--CMD_MORPH_STOP             = cmds.MORPH_STOP
--CMD_REARM                  = cmds.REARM
--CMD_FIND_PAD               = cmds.FIND_PAD
--CMD_UNIT_FLOAT_STATE       = cmds.UNIT_FLOAT_STATE
--CMD_PRIORITY               = cmds.PRIORITY
--CMD_MISC_PRIORITY          = cmds.MISC_PRIORITY
--CMD_RETREAT                = cmds.RETREAT
--CMD_UNIT_BOMBER_DIVE_STATE = cmds.UNIT_BOMBER_DIVE_STATE
--CMD_AP_FLY_STATE           = cmds.AP_FLY_STATE
--CMD_AP_AUTOREPAIRLEVEL     = cmds.AP_AUTOREPAIRLEVEL
--CMD_UNIT_SET_TARGET        = cmds.UNIT_SET_TARGET
--CMD_UNIT_CANCEL_TARGET     = cmds.UNIT_CANCEL_TARGET
--CMD_UNIT_SET_TARGET_CIRCLE = cmds.UNIT_SET_TARGET_CIRCLE
--CMD_ONECLICK_WEAPON        = cmds.ONECLICK_WEAPON
--CMD_ANTINUKEZONE           = cmds.ANTINUKEZONE
--CMD_PLACE_BEACON           = cmds.PLACE_BEACON
--CMD_WAIT_AT_BEACON         = cmds.WAIT_AT_BEACON
--CMD_ABANDON_PW             = cmds.ABANDON_PW
--CMD_RECALL_DRONES          = cmds.RECALL_DRONES
--CMD_TOGGLE_DRONES          = cmds.TOGGLE_DRONES
--CMD_GOO_GATHER             = cmds.GOO_GATHER
--CMD_PUSH_PULL              = cmds.PUSH_PULL
--CMD_WANT_ONOFF             = cmds.WANT_ONOFF
--CMD_UNIT_KILL_SUBORDINATES = cmds.UNIT_KILL_SUBORDINATES
--CMD_DISABLE_ATTACK         = cmds.DISABLE_ATTACK
--CMD_UNIT_AI                = cmds.UNIT_AI
--CMD_WANT_CLOAK             = cmds.WANT_CLOAK
--CMD_PREVENT_OVERKILL       = cmds.PREVENT_OVERKILL
--CMD_TRANSFER_UNIT          = cmds.TRANSFER_UNIT
--CMD_DONT_FIRE_AT_RADAR     = cmds.DONT_FIRE_AT_RADAR
--CMD_JUMP                   = cmds.JUMP
--CMD_TIMEWARP               = cmds.TIMEWARP
--CMD_TURN                   = cmds.TURN
--CMD_WANTED_SPEED           = cmds.WANTED_SPEED
--CMD_AIR_STRAFE             = cmds.AIR_STRAFE
--CMD_RAMP                   = cmds.RAMP
--CMD_LEVEL                  = cmds.LEVEL
--CMD_RAISE                  = cmds.RAISE
--CMD_SMOOTH                 = cmds.SMOOTH
--CMD_RESTORE                = cmds.RESTORE
--CMD_BUMPY                  = cmds.BUMPY
--CMD_TERRAFORM_INTERNAL     = cmds.TERRAFORM_INTERNAL
