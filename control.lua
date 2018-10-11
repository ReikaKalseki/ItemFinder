require "config"
require "functions"

function initGlobal(force)
	if not global.finder then
		global.finder = {}
	end
end

local function createArrowAt(finder, entity)
	if not finder.arrows then finder.arrows = {} end
	local entity = entity.surface.create_entity{name = "orange-arrow-with-circle", position = entity.position}
	table.insert(finder.arrows, {entity = entity, creation = game.tick})
end

local function findItem(player, force, item)
	local found = {}
	local s = game.surfaces[1]
	if not game.entity_prototypes[item] then --in the world
		for _,e in pairs(s.find_entities_filtered{force = force, name = item}) do
			table.insert(found, {type = "Entity", position = e, count = 1})
		end
	end
	for _,e in pairs(s.find_entities_filtered{force = force}) do --inventories
		if (e.type == "car" or e.type == "cargo-wagon") and e.get_driver() == player then
			player.print("Skipping " .. e.name .. " as you are in it.")
		else
			local checks = {}
			local c = 0
			for name,itype in pairs(defines.inventory) do
				local inv = e.get_inventory(itype)
				if inv and (not checks[itype]) then --do not check same inv type twice
					checks[itype] = true
					c = c+inv.get_item_count(item)
				end
			end
			if c > 0 then
				table.insert(found, {type = "Inventory (" .. e.name .. ")", position = e, count = c})
			end
		end
	end
	for _,e in pairs(s.find_entities_filtered{type = "item-entity"}) do --dropped items; do not check force, as dropped items are always neutral
		local itype = e.stack
		if itype and itype.valid_for_read then
			if itype.name == item then
				table.insert(found, {type = "Spilled Item", position = e, count = itype.count})
			end
		end
	end
	for _,e in pairs(s.find_entities_filtered{type = {"transport-belt", "underground-belt", "loader"}, force = force}) do --item on belt
		for i = 1,2 do
			local line = e.get_transport_line(i)
			local c = line.get_item_count(item)
			if c > 0 then
				table.insert(found, {type = "Belt Item", position = e, count = c})
			end
		end
	end
	for _,e in pairs(s.find_entities_filtered{type = "inserter", force = force}) do --held item
		if e.held_stack and e.held_stack.valid_for_read then
			if e.held_stack.name == item then
				table.insert(found, {type = "Inserter", position = e, count = e.held_stack.count})
			end
		end
	end
	return found
end

script.on_event(defines.events.on_tick, function(event)
	if event.tick%60 ~= 0 then return end
	
	local finder = global.finder
	
	if finder.arrows and #finder.arrows > 0 then
		for i,entry in ipairs(finder.arrows) do
			if event.tick-entry.creation > 10*60 then
				entry.entity.destroy()
				table.remove(finder.arrows, i)
			end
		end
	end
end)

script.on_load(function()
	commands.add_command("findItem", {"cmd.find-item"}, function(event)
		local player = game.players[event.player_index]
		if not event.parameter then
			player.print("You must specify an item type to look for!")
			return
		end
		if not game.item_prototypes[event.parameter] then
			player.print("No such item type '" .. event.parameter .. "'!")
			return
		end
		local found = findItem(player, player.force, event.parameter, found)
		if #found > 0 then
			local finder = global.finder
			local total = 0
			for _,entry in pairs(found) do
				player.print("Found " .. entry.count .. " in form " .. entry.type .. " at " .. entry.position.position.x .. ", " .. entry.position.position.y)
				player.add_custom_alert(entry.position, {type = "virtual", name = "found-item-alert"}, {"virtual-signal-name.found-item-alert", serpent.block(entry.position.position)}, true)
				createArrowAt(finder, entry.position)
				total = total+entry.count
			end
			player.print("Found a total of " .. total .. " items.")
			player.play_sound{path="utility/alert_construction", position=player.position, volume_modifier=1}
		else
			player.print("Found no items.")
		end
	end)
end)

script.on_init(function()
	initGlobal(true)
end)

script.on_configuration_changed(function()
	initGlobal(true)
end)
--[[
script.on_event(defines.events.on_tick, function(event)
	
end)
--]]