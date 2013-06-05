
money = nil

function save_money()
	local file = io.open(minetest.get_worldpath().."/money", "w")
	if file then
		file:write(minetest.serialize(money))
		file:close()
	end
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
		save_money()
	end
	player:set_inventory_formspec(
		"size[8,5;]"..
		"list[current_player;main;0,0.5;8,4;]"..
		"label[0,-0.4;Cash: "..money[player:get_player_name()].."]"
	)
end)

minetest.register_chatcommand("set_money", {
	params = "<name> <cash>",
	description = "Sets money of a player",
	privs = {server=true},
	func = function(name, param)
		local name, cash = string.match(param, "^([a-zA-Z0-9_]*) ([%d.-]+)$")
		money[name] = cash
		save_money()
		local player = minetest.get_player_by_name(name)
		if player then
			player:set_inventory_formspec(
				"size[8,5;]"..
				"list[current_player;main;0,0.5;8,4;]"..
				"label[0,-0.4;Cash: "..money[name].."]"
			)
		end
	end,
})
