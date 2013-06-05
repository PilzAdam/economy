
local money = nil

function save_money()
	local file = io.open(minetest.get_worldpath().."/money", "w")
	if file then
		file:write(minetest.serialize(money))
		file:close()
	end
end

function update_money()
	for _,player in ipairs(minetest.env:get_connected_players()) do
		player:set_inventory_formspec(
			"size[8,5;]"..
			"list[current_player;main;0,0.5;8,4;]"..
			"label[0,-0.4;Cash: "..money[player:get_player_name()].."]"
		)
	end
	save_money()
end

local file = io.open(minetest.get_worldpath().."/money", "r")
if file then
	money = minetest.deserialize(file:read("*all"))
end
if not money or not type(money) == "table" then
	money = {}
end

save_money()

minetest.register_on_joinplayer(function(player)
	if not money[player:get_player_name()] then
		money[player:get_player_name()] = 0
	end
	update_money()
end)

minetest.register_chatcommand("set_money", {
	params = "<name> <cash>",
	description = "Sets money of a player",
	privs = {server=true},
	func = function(name, param)
		local name, cash = string.match(param, "^([a-zA-Z0-9_]*) ([%d.-]+)$")
		money[name] = tonumber(cash)
		update_money()
	end,
})

shop = {}
shop.size = 0
local players_start_i = {}

local function get_formspec(pos, start_i, pagenum, name)
	local pagemax = math.floor((shop.size-1) / (6*4) + 1)
	local inv = minetest.env:get_meta(pos):get_inventory()
	local def = inv:get_stack("buy", 1):get_definition()
	local price = 0
	if def and def.worthiness then
		price = def.worthiness+def.worthiness*0.1
	end
	local price2 = 0
	def = inv:get_stack("sell", 1):get_definition()
	if def and def.worthiness then
		price2 = def.worthiness-def.worthiness*0.1
	end
	local f=
		"size[8,10]"..
		"list[current_player;main;0,6;8,4;]"..
		"list[nodemeta:"..pos.x..","..pos.y..","..pos.z..";main;0,0;8,4;"..tostring(start_i).."]"..
		"list[nodemeta:"..pos.x..","..pos.y..","..pos.z..";buy;4.5,4;1,1;]"..
		"button[5.5,4;2,1;shop_buy;Buy ("..price..")]"..
		"list[nodemeta:"..pos.x..","..pos.y..","..pos.z..";sell;4.5,5;1,1;]"..
		"button[5.5,5;2,1;shop_sell;Sell ("..price2..")]"..
		"label[1.7,4.1;"..tostring(pagenum).."/"..tostring(pagemax).."]"..
		"button[0,4;1.6,1;shop_prev;<<]"..
		"button[2.4,4;1.6,1;shop_next;>>]"..
		"label[0,5;Cash: "..money[name].."]"
	return f
end

minetest.after(0, function()
	local inv = minetest.create_detached_inventory("shop", {
		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			return 0
		end,
		allow_put = function(inv, listname, index, stack, player)
			return 0
		end,
		allow_take = function(inv, listname, index, stack, player)
			return 0
		end,
		on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
		end,
		on_put = function(inv, listname, index, stack, player)
		end,
		on_take = function(inv, listname, index, stack, player)
		end,
	})
	local shop_list = {}
	for name,def in pairs(minetest.registered_items) do
		if def.worthiness then
			table.insert(shop_list, name)
		end
	end
	table.sort(shop_list)
	inv:set_size("main", #shop_list)
	for _,itemstring in ipairs(shop_list) do
		inv:add_item("main", ItemStack(itemstring))
	end
	shop.size = #shop_list
end)

minetest.register_node("economy:shop", {
	description = "Shop",
	on_construct = function(pos)
		local m = minetest.env:get_meta(pos)
		m:set_string("infotext", "Shop")
		m:get_inventory():set_size("buy", 1)
		m:get_inventory():set_size("sell", 1)
		m:get_inventory():set_size("main", shop.size)
		m:get_inventory():set_list("main", minetest.get_inventory({type="detached",name="shop"}):get_list("main"))
	end,
	on_rightclick = function(pos, node, clicker, itemstack)
		minetest.show_formspec(clicker:get_player_name(), minetest.pos_to_string(pos), get_formspec(pos, 0, 1, clicker:get_player_name()))
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		if (from_list == "main" and to_list == "buy") or (from_list == "buy" and to_list == "main") then
			return count
		end
		return 0
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "sell" then
			return stack:get_count()
		end
		return 0
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if listname == "sell" then
			return stack:get_count()
		end
		return 0
	end,
	on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		minetest.show_formspec(player:get_player_name(), minetest.pos_to_string(pos), get_formspec(pos, players_start_i[player:get_player_name()] or 0, (players_start_i[player:get_player_name()] or 0) / (8*4) + 1, player:get_player_name()))
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.show_formspec(player:get_player_name(), minetest.pos_to_string(pos), get_formspec(pos, players_start_i[player:get_player_name()] or 0, (players_start_i[player:get_player_name()] or 0) / (8*4) + 1, player:get_player_name()))
	end,
	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		minetest.show_formspec(player:get_player_name(), minetest.pos_to_string(pos), get_formspec(pos, players_start_i[player:get_player_name()] or 0, (players_start_i[player:get_player_name()] or 0) / (8*4) + 1, player:get_player_name()))
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if fields.shop_prev or fields.shop_next then
		local pos = minetest.string_to_pos(formname)
		local start_i = players_start_i[player:get_player_name()] or 0

		if fields.shop_prev then
			start_i = start_i - 8*4
		end
		if fields.shop_next then
			start_i = start_i + 8*4
		end

		if start_i < 0 then
			start_i = start_i + 8*4
		end
		if start_i >= shop.size then
			start_i = start_i - 8*4
		end
			
		if start_i < 0 or start_i >= shop.size then
			start_i = 0
		end

		players_start_i[player:get_player_name()] = start_i
		minetest.show_formspec(player:get_player_name(), minetest.pos_to_string(pos), get_formspec(pos, start_i, start_i / (8*4) + 1, player:get_player_name()))
	elseif fields.shop_buy then
		local pos = minetest.string_to_pos(formname)
		local inv = minetest.env:get_meta(pos):get_inventory()
		local def = inv:get_stack("buy", 1):get_definition()
		local price = 0
		if def and def.worthiness then
			price = def.worthiness+def.worthiness*0.1
		end
		if money[player:get_player_name()] >= price then
			money[player:get_player_name()] = money[player:get_player_name()]-price
			update_money()
			player:get_inventory():add_item("main", inv:get_stack("buy", 1))
			minetest.show_formspec(player:get_player_name(), minetest.pos_to_string(pos), get_formspec(pos, players_start_i[player:get_player_name()] or 0, (players_start_i[player:get_player_name()] or 0) / (8*4) + 1, player:get_player_name()))
		end
	elseif fields.shop_sell then
		local pos = minetest.string_to_pos(formname)
		local inv = minetest.env:get_meta(pos):get_inventory()
		local def = inv:get_stack("sell", 1):get_definition()
		local price = 0
		if def and def.worthiness then
			price = def.worthiness-def.worthiness*0.1
		end
		money[player:get_player_name()] = money[player:get_player_name()]+price
		update_money()
		inv:set_stack("sell", 1, ItemStack(""))
		minetest.show_formspec(player:get_player_name(), minetest.pos_to_string(pos), get_formspec(pos, players_start_i[player:get_player_name()] or 0, (players_start_i[player:get_player_name()] or 0) / (8*4) + 1, player:get_player_name()))
	end
end)
