
function miningSiteWasBuilt(entity)
	info("Entity built in tick "..game.tick.." and added it for update tick")
	scheduleAdd(entity, game.tick + updateEveryTicks)
	
	local sizeSuffix = ""
	local name = entity.name
	if name:ends("-large") then
		sizeSuffix = "-large"
	elseif name:ends("-extra") then
		sizeSuffix = "-extra"
	end
	local pos = {x = entity.position.x-0.5, y=entity.position.y-0.5}
	local miningRoboport = entity.surface.create_entity({name="mining-roboport"..sizeSuffix,position=pos,force=miningForceForEntity(entity)})
	miningRoboport.operable = false
	miningRoboport.minable = false
	miningRoboport.destructible = false
	
	local pos = {x = entity.position.x-0.5, y=entity.position.y-0.5}
	local storageChest = entity.surface.create_entity({name="invisible-logistic-chest-storage",position=pos,force=miningForceForEntity(entity)})
	storageChest.operable = false
	storageChest.minable = false
	storageChest.destructible = false
	
	local pos = {x = entity.position.x-1, y=entity.position.y+1}
	local providerChest = entity.surface.create_entity({name="logistic-chest-passive-provider",position=pos,force=entity.force})
	providerChest.minable = false
	providerChest.destructible = false
	
	local pos = {x = entity.position.x+1, y=entity.position.y-0.5}
	local logisticsDecider = entity.surface.create_entity({name="logistic-decider-combinator",position=pos,force=entity.force})
	logisticsDecider.minable = false
	logisticsDecider.destructible = false
	
	-- Robot mining site should not be opened, since inventory is used only for safe deconstruction and collecting all items
	entity.operable = false
	
	return {
		miningRoboport = miningRoboport,
		storageChest = storageChest,
		providerChest = providerChest,
		logisticsDecider = logisticsDecider
	}
end

function moveItemsToPassiveProvider(entity,data)
	local invSource = data.storageChest.get_inventory(defines.inventory.chest)
	local invTarget = data.providerChest.get_inventory(defines.inventory.chest)
	local movedAll = moveInventoryToInventory(invSource,invTarget)
	killItemsInInventor(invTarget,"empty-item")
	return movedAll
end

-- parameters: entity
-- return values: tickDelayForNextUpdate, reasonMessage
function runMiningSiteInstructions(entity,data)
	local spaceLeft = moveItemsToPassiveProvider(entity,data)
	if not spaceLeft then -- stop mining if chest is full
		return updateEveryTicksWaiting,"no space in chest left"
	end

	local r = 10 --range
	if entity.name:ends("-large") then
		r = 20
	elseif entity.name:ends("-extra") then
		r = 40
	end
	local p = data.miningRoboport.position
	local searchArea = {{p.x - r, p.y - r}, {p.x + r, p.y + r}}
	local resources = entity.surface.find_entities_filtered{type="resource", area = searchArea}
	if not resources or #resources == 0 then
		return updateEveryTicksWaiting,"no resources available"
	end
	
	local network = data.miningRoboport.logistic_network
	if not network then	return updateEveryTicksWaiting,"no logistics network" end
	local totalRobots = network.all_construction_robots
	if not totalRobots or totalRobots==0 then	return updateEveryTicksWaiting,"no robots in network" end
	
	if not shouldMiningSiteRun(entity,data) then return updateEveryTicksWaiting,"logistics condition is false" end

	local robots = network.available_construction_robots
	if not robots or robots==0 then return updateEveryTicks,"no robots available" end
	
	local testStack = {name="iron-ore",count=1}
	local forceName = miningForceForEntity(entity)
	
	for i=1,robots+1 do
		local n = math.random(#resources)
		local position = resources[n].position
		
		if entity.surface.can_place_entity{name="item-on-ground", position=position, stack=testStack} then
			local itemStacksGenerated = mineResource(resources[n])
			for _,itemStack in pairs(itemStacksGenerated) do 
				local itemEntity = entity.surface.create_entity{name="item-on-ground", position=position, stack=itemStack}
				if itemEntity and itemEntity.valid then
					itemEntity.order_deconstruction(forceName)
				end
			end
		end

		table.remove(resources,n)
		if #resources==0 then break end
	end
	
	return updateEveryTicks,"working..."
end


-- checks logistics decider whether the mining site should be running or not
function shouldMiningSiteRun(entity,data)
	local network = data.providerChest.logistic_network
	if not network then return true end --no condition when no network available
	
	local condition = data.logisticsDecider.get_circuit_condition(defines.circuitconditionindex.decider_combinator)
	if not condition then return true end
	local parameters = condition.parameters

	local checkFirstItem = parameters.first_signal.name
	if not checkFirstItem then return true end -- no condition specified
	local actualAmount = network.get_item_count(checkFirstItem)

	local compareAgainstAmount
	if parameters.second_signal then
		local checkSecondItem = parameters.second_signal.name
		compareAgainstAmount = network.get_item_count(checkSecondItem)
	else
		compareAgainstAmount = parameters.constant
	end
	
	local diff = actualAmount - compareAgainstAmount
	if parameters.comparator == ">" then
		return diff > 0
	elseif parameters.comparator == "=" then
		return diff == 0
	else
		return diff < 0
	end
end


-- moves items from roboport / passive provider chest into robot mining site such that they are picked up by robot/player
function preMineRobotMiningSite(event)
-- entity Lua/Entity, name = 9, player_index = 1, tick = 96029 } 
	local entity = event.entity
	-- index 3 is defines.inventory.resultInventory (the current lua api does not contain the up-to-date indexes)
	local entityInv = entity.get_inventory(defines.inventory.chest)
	local data = global.robotMiningSite.entityData[idOfEntity(entity)]
	
	-- Move items from chests into robot mining site (player or bots pick them up)
	local inventoriesToClear = {
		data.miningRoboport.get_inventory(1),
		data.storageChest.get_inventory(defines.inventory.chest), 
		data.providerChest.get_inventory(defines.inventory.chest)
	}
	for _,invToClear in pairs(inventoriesToClear) do
		if not moveInventoryToInventory(invToClear,entityInv) then
			break
		end
	end
	
	-- since the player mines it all items have to be moved
	if event.player_index then
		-- if playerIndex is set in events table, every item must be moved in this method from the input chests, otherwise items get lost
		local p = game.players[event.player_index]
		local playerInventory = p.get_inventory(defines.inventory.player_main)
		for _,invToClear in pairs(inventoriesToClear) do
			if not moveInventoryToInventory(invToClear,playerInventory) then break end
		end
		for _,invToClear in pairs(inventoriesToClear) do
			if not invToClear.is_empty() then
				warn("needs to spill: "..serpent.block(invToClear.get_contents()))
				spillInventory(invToClear, entity.surface, entity.position)
			end
		end
	end
end


-- final removal of robot mining site
function removeMiningSite(idEntity,data)
	data.miningRoboport.destroy()
	data.storageChest.destroy()
	data.providerChest.destroy()
	data.logisticsDecider.destroy()
end