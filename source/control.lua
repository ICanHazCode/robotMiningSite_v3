require "config"
require "libs.all"
require "libs.control.entities"

require "control.robotMiningSite"
require "control.miningRobot"
require "control.forces"
require "control.speedTechnology"
require "control.migration_0_2_0"
require "control.migration_0_2_3"
require "control.migration_0_3_0"
require "control.migration_0_4_1"
require "control.migration_0_8_0"

local robotMiningSiteName = "robotMiningSite-new"
local robotMiningSiteNameLarge = "robotMiningSite-large"
local robotMiningSiteNameExtra = "robotMiningSite-extra"

-- global data stored and used:
-- global.robotMiningSite.speedResearch = $research_level
--                       .version = $version

---------------------------------------------------
-- Used API
---------------------------------------------------

-- entities V2

---------------------------------------------------
-- Loading
---------------------------------------------------
--[[script.on_init(function()
	migration()
end)

script.on_configuration_changed(function()
	migration()
end)


function migration()
	entities_init()
	if not global.robotMiningSite then
		global.robotMiningSite = {}
	end
	local g = global.robotMiningSite
	local prevVersion = g.version
	if not g.version then
		g.version = "0.10.0"
		speedTechnologyInit()
		info("Initialised")
	end
	if g.version < "0.2.0" then migration_0_2_0() end
	if g.version < "0.2.3" then migration_0_2_3() end
	if g.version < "0.3.0" then migration_0_3_0() end
	if g.version < "0.4.1" then migration_0_4_1() end
	
	if g.version > modVersion then
		error("Using savegame with newer robotMiningSite version ("..g.version..") than installed version ("..modVersion..")")
		g.version = modVersion
	end
	if g.version ~= prevVersion then
		info("Previous version: "..tostring(prevVersion).." migrated to "..g.version)
	end
end
]]
script.on_init(function()
	init_globals()
end)

script.on_load(function()
end)

local function on_configuration_change(_config_data)
	init_globals()
	local mod_changes = config_data["mod_changes"]
	if mod_changes and mod_changes["robotMiningSite"] then
		if not mod_changes["robotMiningSite"]["old_version"] then
			speeTechnologyInit()
			info("Initialized")
		end
		local ver = mod_changes["robotMiningSite"]["old_version"]
		local ver_parts = string.gmatch(ver, "%d+")
		local ver_rel, ver_mjr, ver_mnr = tonumber(ver_parts()), tonumber(ver_parts()), tonumber(ver_parts())
		if ver_rel == 0 and ver_mjr < 2 then migration_0_2_0() end
		if ver_rel == 0 and ver_mjr == 2 and ver_mnr < 3 then migration_0_2_3() end
		if ver_rel == 0 and ver_mjr < 3 then migration_0_3_0() end
		if (ver_rel == 0 and ver_mjr < 4) or (ver_rel == 0 and ver_mjr == 4 and ver_mnr < 1) then migration_0_4_1() end
	end
end



---------------------------------------------------
-- Tick
---------------------------------------------------
script.on_event(defines.events.on_tick, function(event)
	entities_tick()
end)

---------------------------------------------------
-- Building Entities
---------------------------------------------------

script.on_event(defines.events.on_built_entity, function(event)
	entities_build(event)
end)
script.on_event(defines.events.on_robot_built_entity, function(event)
	entities_build(event)
end)

---------------------------------------------------
-- Removing entities
---------------------------------------------------
script.on_event(defines.events.on_robot_pre_mined, function(event)
	entities_pre_mined(event)
end)

script.on_event(defines.events.on_pre_player_mined_item, function(event)
	entities_pre_mined(event)
end)
