shopping = {}
shopping.storage = minetest.get_mod_storage()

local modpath = minetest.get_modpath(minetest.get_current_modname())
dofile(modpath.."/player_to_player_shop.lua")









minetest.register_privilege("shopping_admin", {
	description = "Lets player remove, add things to server shop, or nuke shop",
})


minetest.register_chatcommand("buy", {
	params = "<index>",
	description = "Buy from shop.",
	privs = {
		interact = true,
	},
	func = function(name, index)
		index = tonumber(index)
		if (not name) or (not index) then
			return false, "Bad args!"
		end

		return shopping.buy(name, index)
	end
})

minetest.register_chatcommand("shop", {
	description = "Show shop.",
	privs = {
		interact = true,
	},
	func = function(name)
		if not name then
			return false, "Bad args!"
		end

		return shopping.shop(name, 1)
	end
})


minetest.register_chatcommand("nukeshop", {
	description = "Clears shop",
	privs = {
		shopping_admin = true,
	},
	func = function()
		local mod_storage = shopping.storage
		mod_storage:set_string("shop", minetest.serialize({}))
		return true, "Shop nuked!"
	end
})


minetest.register_chatcommand("sell", {
	params = "<price>",
	description = "List for sale in player to player shop.",
	privs = {
		interact = true,
	},
	func = function(name, price)
		if (not name) then
			return false, "Bad args!"
		end

		--get price
		local num_price = tonumber(price)
		if not num_price then
			return false, "Invalid price"
		end
		local player = minetest.get_player_by_name(name)

		-- make sure player is valid
		if not player then
			return false, "Player not found."
		end
		-- get item_stack
		local item_stack = player:get_wielded_item()
		if item_stack:is_empty() then
			return false, "You are not holding any item."
		end

		return shopping.sell(name, item_stack, num_price) 
	end
})
