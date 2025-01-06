shopping = {}
shopping.storage = core.get_mod_storage()

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath.."/player_to_player_shop.lua")









core.register_privilege("shopping_admin", {
	description = "Lets player remove, add things to server shop, or nuke shop",
})


core.register_chatcommand("shop", {
	description = "Show shop.",
	privs = {
		interact = true,
	},
	func = function(name)
		if not name then
			return false, "Bad args!"
		end

		return shopping.shop(name)
	end
})


core.register_chatcommand("nukeshop", {
	description = "Clears shop",
	privs = {
		shopping_admin = true,
	},
	func = function()
		local mod_storage = shopping.storage
		mod_storage:set_string("shop_inv", core.write_json({}) or "")
		mod_storage:set_int("shop_inv_size", 0)
		return true, "Shop nuked!"
	end
})


core.register_chatcommand("sell", {
	params = "<price>",
	description = "List for sale in player to player shop.",
	privs = {
		interact = true,
	},
	func = function(name, price)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end
		
		if (not name) or (not price) then
			return false, "Bad args!"
		end

		local num_price = math.floor(tonumber(price))
		if (not num_price) or num_price < 1 then
			return false, "Invalid price"
		end

		local item_stack = player:get_wielded_item()
		if item_stack:is_empty() then
			return false, "You are not holding any item."
		end

		return shopping.sell(name, item_stack, num_price) 
	end
})
