
playerlevels = {
	-- example_user = {stone=1, tool=2},
	singleplayer = {wood=1,furnace=1},
}

local crafting = {
	normal = {},
	cooking = {},
	fuel = {},
}

local old_register_craft = minetest.register_craft
local old_get_craft_result = minetest.get_craft_result

minetest.register_craft = function(def)
	if def.type == nil or def.type == "shapeless" then
		old_register_craft(def)
		crafting.normal[ItemStack(def.output):get_name()] = {
			level = def.level or {},
		}
	elseif def.type == "cooking" then
		crafting.cooking[def.recipe] = {
			time = def.burntime or 1,
			output = def.output,
			level = def.level or {},
		}
	elseif def.type == "fuel" then
		crafting.fuel[def.recipe] = {
			time = def.burntime,
			replacement = def.replacement,
		}
	end
end

minetest.get_craft_result = function(input)
	if input.method == "normal" then
		local result, test = old_get_craft_result(input)
		local def = crafting.normal[result.item:get_name()]
		if not def then
			return result
		end
		for name,rating in pairs(def.level) do
			if not input.level[name] or input.level[name] < rating then
				return
			end
		end
		return result
	elseif input.method == "cooking" then
		local ret = {time=-1, item=ItemStack("")}
		local ret2 = {items={}}
		local def = crafting.cooking[input.items[1]:get_name()]
		if not def then
			return ret, ret2
		end
		if input.level then
			for name,rating in pairs(def.level) do
				if not input.level[name] or input.level[name] < rating then
					return ret, ret2
				end
			end
		end
		ret.time = def.time
		ret.item = ItemStack(def.output)
		ret2.items[1] = input.items[1]:peek_item(input.items[1]:get_count()-1)
		if def.replacement then
			for _,rep in ipairs(def.replacement) do
				if rep[1] == input.items[1]:get_name() then
					ret2.items[1] = rep[2]
				end
			end
		end
		return ret, ret2
		
	elseif input.method == "fuel" then
		local ret = {time=-1}
		local ret2 = {items={}}
		for i,stack in ipairs(input.items) do
			local def = crafting.fuel[stack:get_name()]
			if def then
				ret.time = ret.time + def.time
				ret2.items[i] = stack:peek_item(stack:get_count()-1)
				if def.replacement then
					for _,rep in ipairs(def.replacement) do
						if rep[1] == stack:get_name() then
							ret2.items[i] = rep[2]
						end
					end
				end
			end
		end
		return ret, ret2
	end
end

minetest.get_craft_recipe = nil
minetest.get_all_craft_recipes = nil


local function update_workbench(pos, playername)
	local meta = minetest.env:get_meta(pos)
	local inv = meta:get_inventory()
	local result = minetest.get_craft_result({
		method = "normal",
		width = 3,
		items = inv:get_list("craft"),
		level = playerlevels[playername],
	})
	if not result then
		return
	end
	inv:set_stack("result", 1, result.item)
end

minetest.register_node("crafting:workbench", {
	description = "Workbench",
	tiles = {"workbench_top.png", "workbench_side.png"},
	groups = {choppy=2,oddly_breakable_by_hand=2,flammable=3},
	sounds = {
		dug = {
			name = "default_dug_node",
			gain = 1,
		},
		footstep = {
			name = "default_hard_footstep",
			gain = 0.3,
		},
		place = {
			name = "default_place_node",
			gain = 0.5,
		},
	},
	on_construct = function(pos)
		local meta = minetest.env:get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("craft", 9)
		inv:set_size("result", 1)
		meta:set_string("formspec", 
			"size[8,7.5;]"..
			"list[current_player;main;0,3.5;8,4;]"..
			"list[current_name;craft;3,0;3,3;]"..
			"list[current_name;result;6.5,1;1,1;]"
		)
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index,to_list, to_index, count, player)
		if to_list == "result" then
			return 0
		end
		return count
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "result" then
			return 0
		end
		return stack:get_count()
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		return stack:get_count()
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		update_workbench(pos, player:get_player_name())
	end,
	on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local inv = minetest.env:get_meta(pos):get_inventory()
		if from_list == "result" then
			for i,stack in ipairs(inv:get_list("craft")) do
				stack:take_item()
				inv:set_stack("craft", i, stack)
			end
		end
		update_workbench(pos, player:get_player_name())
	end,
	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		local inv = minetest.env:get_meta(pos):get_inventory()
		if listname == "result" then
			for i,stack in ipairs(inv:get_list("craft")) do
				stack:take_item()
				inv:set_stack("craft", i, stack)
			end
		end
		update_workbench(pos, player:get_player_name())
	end,
	can_dig = function(pos)
		local inv = minetest.env:get_meta(pos):get_inventory()
		return inv:is_empty("craft") and inv:is_empty("result")
	end,
})

minetest.register_on_joinplayer(function(player)
	player:set_inventory_formspec(
		"size[8,5;]"..
		"list[current_player;main;0,0.5;8,4;]"
	)
	if not playerlevels[player:get_player_name()] then
		playerlevels[player:get_player_name()] = {}
	end
end)
