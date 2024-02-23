local MODULE = ...

local copytable = require "copytable"
local wait = require "wait"

local string = string
local table = table
local alias_flag = alias_flag
local custom_colour = custom_colour
local error_code = error_code
local error_desc = error_desc
local trigger_flag = trigger_flag

local ipairs = ipairs
local pairs = pairs
local AddAlias = AddAlias
local AddTrigger = AddTrigger
local ColourNote = ColourNote
local DeleteTrigger = DeleteTrigger
local DeleteTriggerGroup = DeleteTriggerGroup
local EnableTrigger = EnableTrigger
local Execute = Execute
local SetTriggerOption = SetTriggerOption

module(MODULE)


enabled = false

local ALIAS_NAME_PREFIX = string.format("alias_%s_", MODULE)
local GROUP_DEFAULT_NAME = "group_" .. MODULE
local TRIGGER_NAME_PREFIX = string.format("trigger_%s_", MODULE)
local TRIGGER_GAME_MAP = "game_map"

minigame = {} -- Track the progress of each game

local TRIGGERS = {
    {
        name = "run_fail",
        match = "^You die\\.$",
        script = MODULE .. ".run_finish",
        options = {sequence=0, keep_evaluating=true},
    }, {
        name = "run_success",
        match = "^As Aion is struck down, profound ripples begin to spread through space and time\\.$",
        script = MODULE .. ".run_finish",
    }, {
        name = "vortex",
        match = "^A vortex draws you inexorably towards Aion!$",
        script = MODULE .. ".vortex",
    }, {
        name = "sanctuary",
        match = "^Aion calls upon his divinity to sanctify himself\\.$",
        script = MODULE .. ".sanctuary",
    }, {
        name = "crystal_restore",
        match = "^The Restorative Crystal glows brightly, restoring your health! \\[\\d+\\] \\[\\d+\\] \\[\\d+\\]$",
        script = MODULE .. ".crystal_restore",
    }, {
        name = TRIGGER_GAME_MAP,
        match = "^(?<nw>...) (?<n>...) (?<ne>...)\\n +\\n(?<w>...) (?<c>...) (?<e>...)\\n +\\n(?<sw>...) (?<s>...) (?<se>...)\\Z",
        flags = -trigger_flag.Enabled, -- Disable by default
        script = MODULE .. ".game_map",
        options = {multi_line=true, lines_to_match=5},
    }, {
        name = "array_start",
        match = "^A large array formation appears beneath your feet!$",
        script = MODULE .. ".array_start",
    }, {
        name = "hourglass_start",
        match = "^A large hourglass appears behind Aion, the sands within trickling down ever faster!$",
        script = MODULE .. ".hourglass_start",
    }, {
        name = "runewords_start",
        match = "^Runewords begin to coalesce all around you!$",
        script = MODULE .. ".runewords_start",
    }, {
        name = "storm_start",
        match = "^Aion summons a chaotic storm of energy! Best find a safe spot to hide!$",
        script = MODULE .. ".storm_start",
    }, {
        name = "spinning_start",
        match = "^Aion summons a spinning wall of chaotic energy!$",
        script = MODULE .. ".spinning_start",
    }, {
        name = "angelfire_start",
        match = "^Aion summons burning waves of Angelfire! Dodge them!$",
        script = MODULE .. ".angelfire_start",
    },
}


function string:trim()
    return self:match("^%s*(.-)%s*$")
end


local function plugin_msg(...)
    ColourNote(
        "silver", "black", "[",
        "yellow", "", "Aion2",
        "silver", "", "] ",
        ...
    )
end


local function einfo(msg)
    -- Change this to another channel if ACM not installed.
    Execute("einfo " .. msg)
end


local function add_alias(data)
    local flags = alias_flag.Enabled + alias_flag.IgnoreAliasCase
        + alias_flag.RegularExpression + alias_flag.Replace
        + alias_flag.Temporary
    local code = AddAlias(
        ALIAS_NAME_PREFIX .. data.name,
        data.match,
        "", -- Response
        flags + (data.flags or 0),
        data.script
    )
    if (code == error_code.eOK) then
        return true
    end
    local err = "Error adding alias %s (%d)."
    err = err:format(data.name, code)
    plugin_msg("silver", "", err)
    return false
end


local function add_trigger(data)
    local name = TRIGGER_NAME_PREFIX .. data.name
    local flags = trigger_flag.Enabled + trigger_flag.RegularExpression
        + trigger_flag.Replace + trigger_flag.Temporary
    local code = AddTrigger(
        name, data.match,
        "", -- Response
        flags + (data.flags or 0),
        custom_colour.NoChange,
        0, "", -- Wildcard / Sound
        data.script
    )
    if (code ~= error_code.eOK) then
        local err = "Error adding trigger %s (%d)."
        err = err:format(data.name, code)
        plugin_msg("silver", "", err)
        return false    
    end
    for option, value in pairs(data.options or {}) do
        SetTriggerOption(name, option, value)
    end
    -- if group wasn't set through trigger options, set default value
    if not (data.options and data.options.group) then
        SetTriggerOption(name, "group", GROUP_DEFAULT_NAME)
    end
    return true, name
end


local function add_triggers()
    for i, trigger in ipairs(TRIGGERS) do
        add_trigger(trigger)
    end
end


local function delete_trigger(name)
    local success = true
    EnableTrigger(name, false)
    wait.make(function()
        wait.time(0.1)
        local code = DeleteTrigger(name)
        if (code ~= error_code.eOK) then
            success = false
            local msg = "Failed to delete trigger %s (%d)."
            msg = msg:format(name, code)
            plugin_msg("silver", "", msg)
        end
    end)
    return success
end


local function delete_triggers()
    DeleteTriggerGroup(GROUP_DEFAULT_NAME)
end


local function reset_minigame_state()
    -- track progression of each game. Value of 0 indicates the game
    -- isn't running; otherwise, value is the game's current phase.
    minigame = {
        ["array"] = 0, ["hourglass"] = 0, ["runewords"] = 0,
        ["energy_storm"] = 0, ["spinning_energy"] = 0, ["angelfire"] = 0,    
    }
end


local function is_moving_danger(roomContents)
    -- Determine whether a string signifies moving danger on the game
    -- map. If it does, return the direction in which the danger is
    -- moving; otherwise, return nil.
    local MOVING_DANGER = {
        ["^^^"] = "north", [">>>"] = "east",
        ["vvv"] = "south", ["<<<"] = "west",
    }
    return MOVING_DANGER[roomContents]
end


local function get_dangerous_rooms(map)
    -- Return a list of the dangerous rooms on a game map. Keys are
    -- positions (nw, n, ne, etc.), and values are the direction in
    -- which that danger is moving.
    local danger = {}
    for dir, contents in pairs(map) do
        danger[dir] = is_moving_danger(contents)
    end
    return danger
end


function enable(alias, line, wc)
    local setting = wc.setting:trim():lower()
    if (setting == "") then
        enabled = not enabled
    elseif (setting == "on") then
        enabled = true
    elseif (setting == "off") then
        enabled = false
    else
        plugin_msg("silver", "", "Syntax: ", "yellow", "", "aion2 [on|off]")
        return
    end
    local msg = "Assistant turned %s."
    if (enabled) then
        add_triggers()
        plugin_msg("silver", "", msg:format("on"))
        return true
    end
    reset_minigame_state()
    delete_triggers()
    plugin_msg("silver", "", msg:format("off"))
    return false
end


function begin_battle()
    enable(nil, nil, {setting="on"})
    einfo("Aion fight started")
end


function vortex()
    einfo("Vortex")
end


function sanctuary()
    einfo("Aion sanc'd")
end


function crystal_restore()
    wait.make(function()
        wait.time(15)
        einfo("Restorative Crystal available")
    end)
end


function run_finish(trigger, line, wc)
    enable(nil, nil, {setting="off"})
    -- DeleteTriggerGroup() will have failed to delete this trigger,
    -- since it's in the process of running.
    delete_trigger(trigger)
end


function game_map(trigger, line, wc)
    local map = {
        nw = wc.nw, n = wc.n, ne = wc.ne,
        w = wc.w, c = wc.c, e = wc.e,
        sw = wc.sw, s = wc.s, se = wc.se,
    }

    -- Check whether all map-based games are running, in case there's
    -- more than one (think this is impossible, but no harm checking).
    if (minigame.energy_storm > 0) then
        storm_map(map)
    end
    if (minigame.spinning_energy > 0) then
        spinning_map(map)
    end
    if (minigame.angelfire > 0) then
        angelfire_map(map)
    end
end


function array_start()
    minigame.array = 1
    add_trigger{
        name = "array_finish",
        match = "^The array activates where you once were, freezing time in an empty space\\.$",
        script = MODULE .. ".array_finish",
    }
    einfo("Array")
end


function array_finish(trigger, line, wc)
    minigame.array = 0
    delete_trigger(trigger)
    einfo("Array finished")
end


function hourglass_start()
    minigame.hourglass = 1
    add_trigger{
        name = "hourglass_finish",
        match = "^You see the hourglass shatter, but fortunately you escape the billowing sands of time\\.$",
        script = MODULE .. ".hourglass_finish",
    }
    einfo("Hourglass")
end


function hourglass_finish(trigger, line, wc)
    minigame.hourglass = 0
    delete_trigger(trigger)
    einfo("Hourglass finished")
end


function runewords_start()
    minigame.runewords = 1
    add_trigger{
        name = "runewords_finish",
        match = "^The deadly temporal attack misses you\\.$",
        script = MODULE .. ".runewords_finish",
    }
    einfo("Runewords")
end


function runewords_finish(trigger, line, wc)
    minigame.runewords = 0
    delete_trigger(trigger)
    einfo("Runewords finished")
end


function storm_start()
    minigame.energy_storm = 1
    add_trigger{
        name = "storm_map",
        match = "^\\<MAPSTART\\>\\n {9} (?<nw>.)   (?<n>.)   (?<ne>.)  {6}\\n +\\n {9} (?<w>.)   (?<c>.)   (?<e>.)  {6}\\n +\\n {9} (?<sw>.)   (?<s>.)   (?<se>.)  {6}\\n +\\n\\<MAPEND\\>\\Z",
        script = MODULE .. ".game_map",
        options = {multi_line=true, lines_to_match=8},
    }
    add_trigger{
        name = "storm_energy",
        match = "^(?:\\(.+\\) +)?Chaotic energies rage all around you\\.$",
        script = MODULE .. ".storm_energy",
    }
    add_trigger{
        name = "storm_finish",
        match = "^You see chaotic energies explode in a maelstrom of arcane energies to the \\w+!$",
        script = MODULE .. ".storm_finish",
    }
    Execute("glance;map")
    einfo("Energy storm")
end


function storm_map(map)
    local energy = {} -- ! rooms
    local empty = {} -- Empty rooms
    for dir, contents in pairs(map) do
        if (contents == "!") then
            table.insert(energy, dir)
        elseif (contents == " ") then
            table.insert(empty, dir)
        end
    end

    if (#energy == 0) then
        -- No !s, so player must find safety on their own.
        einfo("Locate safe room.")
        return
    end

    -- There is at least one !, so these energies explode on entry.
    -- Find empty rooms to suggest.  
    if (map.c == "#") then
        -- If player is in center, do not suggest nw/ne/se/sw.
        local allEmpty = copytable.shallow(empty)
        empty = {}
        for i, dir in ipairs(allEmpty) do
            if (#dir == 1) then
                table.insert(empty, dir)
            end
        end
    end

    table.sort(empty)
    local msg = "Safe: %s."
    msg = msg:format(#empty > 0 and table.concat(empty, ", ") or "c")
    einfo(msg)
end


function storm_energy()
    einfo("Storm energy here")
end


function storm_finish(trigger, line, wc)
    minigame.energy_storm = 0
    delete_trigger(TRIGGER_NAME_PREFIX .. "storm_map")
    delete_trigger(TRIGGER_NAME_PREFIX .. "storm_energy")
    delete_trigger(trigger)
    einfo("Energy storm finished")
end


function spinning_start()
    minigame.spinning_energy = 1
    EnableTrigger(TRIGGER_NAME_PREFIX .. TRIGGER_GAME_MAP, true)
    add_trigger{
        name = "spinning_finish",
        match = "^The chaotic energies fade away\\.\\.\\.$",
        script = MODULE .. ".spinning_finish",
    }
    einfo("Spinning energy")
end


function spinning_map(map)
    minigame.spinning_energy = minigame.spinning_energy + 1

    local locations = {} -- Alphabetized dirs for consistent output
    local danger = get_dangerous_rooms(map)
    for dir in pairs(danger) do table.insert(locations, dir) end
    table.sort(locations)

    if (minigame.spinning_energy > 2) then
        -- On all maps but the first, provide simplified output
        local msg = "%s moving %s. %s moving %s."
        msg = msg:format(
            locations[1], danger[locations[1]],
            locations[2], danger[locations[2]]
        )
        einfo(msg)
        return
    end

    -- First instance of map for this game. Provide detailed output.
    local msg = "%s: %s. Move %s."
    local clockwise = map.c:match("^%^.v$") and true or false

    -- Construct a pair that indicates bad rooms, like "nw, se"
    local startRooms = table.concat(locations, ", ")

    -- Determine optimal movement based on location and motion of
    -- energy (need check only 4/8 positions since energies are always
    -- opposite)
    if (danger.nw) then
        moveTo = clockwise and "east" or "north"
    elseif (danger.n) then
        moveTo = clockwise and "east and south" or "east and north"
    elseif (danger.ne) then
        moveTo = clockwise and "north" or "east"
    elseif (danger.e) then
        moveTo = clockwise and "north and east" or "south and east"
    end

    msg = msg:format(
        clockwise and "Clockwise" or "Reverse",
        startRooms, moveTo
    )
    einfo(msg)
end


function spinning_finish(trigger, line, wc)
    minigame.spinning_energy = 0
    EnableTrigger(TRIGGER_NAME_PREFIX .. TRIGGER_GAME_MAP, false)
    delete_trigger(trigger)
    einfo("Spinning energy finished")
end


function angelfire_start()
    minigame.angelfire = 1
    add_trigger{
        name = "angelfire_northwest",
        match = "^ .   .   .  \\<\\<\\<\\n +\\n .   .   .  \\<\\<\\<\\n +\\n .   .   .  \\<\\<\\<\\n +\\n\\^\\^\\^ \\^\\^\\^ \\^\\^\\^\\Z",
        script = MODULE .. ".angelfire_first",
        options = {multi_line=true, lines_to_match=7},
    }
    add_trigger{
        name = "angelfire_northeast",
        match = "^\\>\\>\\> +\\n +\\n\\>\\>\\>  .   .   . \\n +\\n\\>\\>\\>  .   .   . \\n +\\n    \\^\\^\\^ \\^\\^\\^ \\^\\^\\^\\Z",
        script = MODULE .. ".angelfire_first",
        options = {multi_line=true, lines_to_match=7},
    }
    add_trigger{
        name = "angelfire_southeast",
        match = "^    vvv vvv vvv\\n +\\n\\>\\>\\>  .   .   . \\n +\\n\\>\\>\\>  .   .   . \\n +\\n\\>\\>\\>  .   .   . \\Z",
        script = MODULE .. ".angelfire_first",
        options = {multi_line=true, lines_to_match=7},
    }
    add_trigger{
        name = "angelfire_southwest",
        match = "^vvv vvv vvv\\n +\\n .   .   .  \\<\\<\\<\\n +\\n .   .   .  \\<\\<\\<\\n +\\n .   .   .  \\<\\<\\<\\Z",
        script = MODULE .. ".angelfire_first",
        options = {multi_line=true, lines_to_match=7},
    }
    add_trigger{
        name = "angelfire_finish",
        match = "^The waves of angel fire have passed!$",
        script = MODULE .. ".angelfire_finish",
    }
    einfo("Angelfire")
end


function angelfire_first(trigger, line, wc)
    minigame.angelfire = minigame.angelfire + 1
    for _, suffix in ipairs{"northwest", "northeast", "southeast", "southwest"} do
        local name = string.format("%sangelfire_%s", TRIGGER_NAME_PREFIX, suffix)
        delete_trigger(name)
    end
    EnableTrigger(TRIGGER_NAME_PREFIX .. TRIGGER_GAME_MAP, true)

    local moveTo = trigger:match("(%a+)$")
    local msg = "Move %s."
    einfo(msg:format(moveTo))
end


function angelfire_map(map)
    minigame.angelfire = minigame.angelfire + 1
    if (minigame.angelfire ~= 4) then
        einfo("Angelfire advanced")
        return
    end

    -- This is the middle phase, when player must move. Find in
    -- which corner the player is standing (if any) and suggest to
    -- move to the opposite one. (Note: technically this can give
    -- wrong answers, in cases where the player moved to the wrong
    -- corner. If that happened, they're probably dead anyway, so not
    -- worth making this more complicated to catch those cases.)
    local PLAYER_LOCATION = " # "
    for _, dir in ipairs{"nw", "ne", "se", "sw"} do
        if (map[dir] == PLAYER_LOCATION) then
            local msg = "Move %s now."
            einfo(msg:format(dir))
            return
        end
    end

    -- Player is not in a corner. RIP.
    einfo("Angelfire advanced")
end


function angelfire_finish(trigger, line, wc)
    minigame.angelfire = 0
    EnableTrigger(TRIGGER_NAME_PREFIX .. TRIGGER_GAME_MAP, false)
    delete_trigger(trigger)
    einfo("Angelfire finished")
end


reset_minigame_state()
delete_triggers()
add_alias{
    name = "enable",
    match = "^aion2(?<setting> .*)?$",
    script = MODULE .. ".enable",
}
add_trigger{
    name = "begin_battle",
    match = "^A vortex of space pulls you inexorably towards Aion!$",
    script = MODULE .. ".begin_battle",
    options = {group="group_aion_permanent"}, -- Avoid delete_triggers()
}
plugin_msg(
    "silver", "black", "Plugin installed. ",
    "yellow", "", "aion2 [on|off] ",
    "silver", "", "to toggle, or simply go fight Aion."
)
