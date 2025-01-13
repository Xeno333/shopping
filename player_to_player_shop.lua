local shop_inv = {}
local shop_inv_expired = {}
local max_price = core.settings:get("shopping_max_price") or 1000

local clean_timer = 1 -- seconds
local shop_lifetime = 2--60*60*24*7 -- seconds equal to 7 days
local expire_time = 2--60*60*24*7





local function save_shop()
	-- main
	local list = shop_inv:get_list("main")
	local to_store = {}
	if list then
		for _, stack in pairs(list) do
			to_store[#to_store+1] = stack:to_string()
		end
	end

	shopping.storage:set_string("shop_inv", core.write_json(to_store))
	shopping.storage:set_int("shop_inv_size", shop_inv:get_size("main"))

	-- shop_inv_expired
	list = shop_inv_expired:get_list("main")
	to_store = {}
	if list then
		for _, stack in pairs(list) do
			to_store[#to_store+1] = stack:to_string()
		end
	end

	shopping.storage:set_string("shop_inv_expired", core.write_json(to_store))
	shopping.storage:set_int("shop_inv_expired_size", shop_inv_expired:get_size("main"))
end


local function load_shop()
	-- main
	local str = shopping.storage:get_string("shop_inv") or "{}"
	if str == "" then str = "{}" end
	local stored = core.parse_json(str) or {}

	local shop_list = {}
	for _, stack in pairs(stored) do
		shop_list[#shop_list+1] = ItemStack(stack)
	end

	shop_inv:set_list("main", shop_list)
	shop_inv:set_size("main", shopping.storage:get_int("shop_inv_size") or 0)

	-- shop_inv_expired
	str = shopping.storage:get_string("shop_inv_expired") or "{}"
	if str == "" then str = "{}" end
	stored = core.parse_json(str) or {}

	shop_list = {}
	for _, stack in pairs(stored) do
		shop_list[#shop_list+1] = ItemStack(stack)
	end

	shop_inv_expired:set_list("main", shop_list)
	shop_inv_expired:set_size("main", shopping.storage:get_int("shop_inv_expired_size") or 0)
end




core.register_chatcommand("nukeshop", {
	description = "Clears shop",
	privs = {
		shopping_admin = true,
	},
	func = function()
		local mod_storage = shopping.storage
		mod_storage:set_string("shop_inv", core.write_json({}) or "")
		mod_storage:set_int("shop_inv_size", 0)


		mod_storage:set_string("shop_inv_expired", core.write_json({}) or "")
		mod_storage:set_int("shop_inv_expired_size", 0)

		load_shop()

		return true, "Shop nuked!"
	end
})






-- shops


shop_inv = core.create_detached_inventory("shop_inv", {
	allow_move = function() return 0 end,
	allow_put = function() return 0 end,
	allow_take = function(inv, listname, index, stack, player)
		if stack ~= inv:get_stack(listname, index) then return 0 end
	
		local name = player:get_player_name()
		local privs = core.get_player_privs(name)
		local meta = stack:get_meta()
		local price = meta:get_int("price")


		if not (privs["shopping_admin"] or name == seller) then
			if jeans_economy.get_account(name) < price then
				core.chat_send_player(name, "Not enough money!")
				return 0
			end
		end

		local player_inv = player:get_inventory()
		if not player_inv:room_for_item(listname, stack) then
			core.chat_send_player(name, "Not enough room in your inventory!")
			return 0
		end

		-- Sell
		core.after(0, function()
			-- re-order
			local s = inv:get_size(listname)
			inv:set_stack(listname, index, inv:get_stack(listname, s))
			inv:set_stack(listname, s, ItemStack(""))
			inv:set_size(listname, s-1)

			local seller = meta:get_string("seller")
			if not (privs["shopping_admin"] or name == seller) then
				local price = meta:get_int("price")
				jeans_economy.book(name, seller, price, name .. " bought item for " .. price)
			end

			meta:set_string("price", "")
			meta:set_string("timer", "")
			meta:set_string("seller", "")
			meta:set_string("description", meta:get_string("backup_description"))
			meta:set_string("backup_description", "")

			player_inv:add_item("main", stack)

			save_shop()
		end)

		return 0
	end
})

shop_inv_expired = core.create_detached_inventory("shop_inv_expired", {
	allow_move = function() return 0 end,
	allow_put = function() return 0 end,
	allow_take = function(inv, listname, index, stack, player)
		if stack ~= inv:get_stack(listname, index) then return 0 end
	
		local name = player:get_player_name()
		local privs = core.get_player_privs(name)
		local meta = stack:get_meta()

		if not (privs["shopping_admin"] or name == seller) then
			return 0
		end

		local player_inv = player:get_inventory()
		if not player_inv:room_for_item(listname, stack) then
			core.chat_send_player(name, "Not enough room in your inventory!")
			return 0
		end
		
		-- Sell
		core.after(0, function()
			-- re-order
			local s = inv:get_size(listname)
			inv:set_stack(listname, index, inv:get_stack(listname, s))
			inv:set_stack(listname, s, ItemStack(""))
			inv:set_size(listname, s-1)

			meta:set_string("price", "")
			meta:set_string("timer", "")
			meta:set_string("seller", "")
			meta:set_string("description", meta:get_string("backup_description"))
			meta:set_string("backup_description", "")

			player_inv:add_item("main", stack)

			save_shop()
		end)

		return 0
	end
})


load_shop()










-- functions


local function add_item_to_shop(itemstack, price, name)
	price = math.abs(price)

	local s = shop_inv:get_size("main") + 1
	shop_inv:set_size("main", s)

	if price > max_price then
		return false, "Max price is $" .. max_price
	end

	local meta = itemstack:get_meta()
	meta:set_int("price", price)
	meta:set_int("timer", shop_lifetime) -- 7 days
	meta:set_string("seller", name)
	local desc = itemstack:get_description()
	meta:set_string("backup_description", desc)
	meta:set_string("description", desc .. "\n$" .. price .. "\nSold by: " .. name)

	shop_inv:set_stack("main", s, itemstack)

	save_shop()

	return true, "Item listed for $" .. price
end



-- Add load old script here

local old_shop = core.deserialize(shopping.storage:get_string("shop"))

if old_shop and shopping.storage:get_int("shop_version") == 0 then
	for _, v in pairs(old_shop) do
		local item = v[1]
		if item and item ~= "" then
			local price = math.floor(math.abs(v[2] or 1))
			local name = v[3]

			-- Truncate value over max_price to 1
			if price > max_price then price = 1 end
			add_item_to_shop(ItemStack(item), price, name)
		end
	end

	shopping.storage:set_int("shop_version", 1)

	core.log("action", "[shopping] Updated shop to version 1.")
end





-- Shop
function shopping.shop(name, inv, tab, inv_ref)
	if not inv then inv = "detached:shop_inv;main" end
	if not tab then tab = 1 end
	if not inv_ref then inv_ref = shop_inv end

	local count = inv_ref:get_size("main")
	local h = count / 4 + ((count % 4 > 0) and 1 or 0)

	local formspec = "size[11,10]"..
		"label[0,0;Shop]"..
		"button_exit[0.2,0.3;2,1;close;Close]"..

		"tabheader[0,0;tab;Shop,Expired;" .. tab .. ";false;true]"..

		"scroll_container[1,1.5;11,4;scrollbar;vertical;0.1;true]"..
		"list[" .. inv .. ";0,0;8," .. h .. ";]"..
		"scroll_container_end[]"..
		"scrollbar[0.4,1.2;0.3,3;vertical;scrollbar;1]"..

        "list[current_player;main;1,6;8,4;]"

	core.show_formspec(name, "shopping:shop_formspec", formspec)
end





core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "shopping:shop_formspec" then
		local name = player:get_player_name()
		if fields.tab == "2" then
			shopping.shop(name, "detached:shop_inv_expired;main", 2, shop_inv_expired)
			
		elseif fields.tab then
			shopping.shop(name, "detached:shop_inv;main", 1, shop_inv)
		end
	end
end)



-- I had to insult AI to figure this out -_-
local function remove_held_item(player_name)
	local player = core.get_player_by_name(player_name)
	if not player then
		return
	end

	local inv = player:get_inventory()
	local wielded_index = player:get_wield_index()

	inv:set_stack("main", wielded_index, ItemStack(""))
end




-- Sell
function shopping.sell(name, itemstack, price)
	if price < 0 then return false, "Bad price!" end
	local rc, s = add_item_to_shop(itemstack, price, name)
	if rc then remove_held_item(name) end
	return rc, s
end








local function shop_clean_on_timer()
	local num = shop_inv:get_size("main")

	for i = 1, num do
		local itemstack = shop_inv:get_stack("main", i)
		local meta = itemstack:get_meta()

		local time = 0--meta:get_int("timer") - clean_timer

		-- Expire
		if time <= 0 then
			meta:set_int("timer", expire_time)

			meta:set_string("description", meta:get_string("backup_description") .. core.colorize("#FF0000", "\nEXPIRED\n") .. "belongs to: " .. meta:get_string("seller"))

			-- expire
			local s = shop_inv_expired:get_size("main")+1
			shop_inv_expired:set_size("main", s)
			shop_inv_expired:set_stack("main", s, ItemStack(itemstack:to_string()))

			-- remove
			s = shop_inv:get_size("main")
			shop_inv:set_stack("main", i, shop_inv:get_stack("main", s))
			shop_inv:set_stack("main", s, ItemStack(""))
			shop_inv:set_size("main", s-1)
		end
	end

	-- expire old done
	num = shop_inv_expired:get_size("main")

	for i = 1, num do
		local itemstack = shop_inv_expired:get_stack("main", i)
		local meta = itemstack:get_meta()

		local time = meta:get_int("timer") - clean_timer

		-- expire
		if time <= 0 then
			-- remove
			local s = shop_inv_expired:get_size("main")
			shop_inv_expired:set_stack("main", i, shop_inv_expired:get_stack("main", s))
			shop_inv_expired:set_stack("main", s, ItemStack(""))
			shop_inv_expired:set_size("main", s-1)
		end
	end

	save_shop()

	core.after(clean_timer, shop_clean_on_timer)
end


core.after(clean_timer, shop_clean_on_timer)