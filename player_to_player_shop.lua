local shop_inv = {}


local function save_shop()
	local list = shop_inv:get_list("main")
	local to_store = {}
	if list then
		for _, stack in pairs(list) do
			to_store[#to_store+1] = stack:to_string()
		end
	end

	shopping.storage:set_string("shop_inv", core.write_json(to_store))
	shopping.storage:set_int("shop_inv_size", shop_inv:get_size("main"))
end


local function load_shop()
	local str = shopping.storage:get_string("shop_inv") or "{}"
	if str == "" then str = "{}" end
	local stored = core.parse_json(str) or {}
	
	local shop_list = {}
	for _, stack in pairs(stored) do
		shop_list[#shop_list+1] = ItemStack(stack)
	end
	
	shop_inv:set_list("main", shop_list)
	shop_inv:set_size("main", shopping.storage:get_int("shop_inv_size") or 0)
end


shop_inv = core.create_detached_inventory("shop_inv", {
	allow_move = function() return 0 end,
	allow_put = function() return 0 end,
	allow_take = function(inv, listname, index, stack, player)
		if stack ~= inv:get_stack(listname, index) then return 0 end
	
		local size = stack:get_count()
		local name = player:get_player_name()
		local privs = minetest.get_player_privs(name)
		local meta = stack:get_meta()


		local price = meta:get_int("price")
		if jeans_economy.get_account(name) < price then
			minetest.chat_send_player(name, "Not enough money!")
			return 0
		end

		local player_inv = player:get_inventory()
		if not inv:room_for_item(listname, stack) then
			minetest.chat_send_player(name, "Not enough room in your inventory!")
			return
		end

		-- Sell
		core.after(0, function()
			-- re-order
			local s = inv:get_size(listname)
			inv:set_stack(listname, index, inv:get_stack(listname, s))
			inv:set_size(listname, s-1)

			local seller = meta:get_string("seller")
			if not (privs["shopping_admin"] or name == seller) then
				local price = meta:get_int("price")
				jeans_economy.book(name, seller, price, name .. " bought item for " .. price)
			end

			meta:set_string("price", "")
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


-- Add load old script here

local old_shop = core.deserialize(shopping.storage:get_string("shop"))

if old_shop then
	print("A")
end


-- functions



local function add_item_to_shop(itemstack, price, name)
	local s = shop_inv:get_size("main") + 1
	shop_inv:set_size("main", s)

	local meta = itemstack:get_meta()
	meta:set_int("price", price)
	meta:set_string("seller", name)
	meta:set_string("backup_description", meta:get_string("description"))
	meta:set_string("description", itemstack:get_description() .. "\n$" .. price)

	shop_inv:set_stack("main", s, itemstack)

	save_shop()

	return true, "Item listed!"
end



-- Shop
function shopping.shop(name)
	local count = shop_inv:get_size("main")
	local h = count / 4 + ((count % 4 > 0) and 1 or 0)

	local formspec = "size[11,10]"..
		"label[0,0;Shop]"..
		"button_exit[0.2,0.3;2,1;close;Close]"..

		"scroll_container[1,1.5;10,4;craft;vertical;0.1;true]"..
		"list[detached:shop_inv;main;0,0;8," .. h .. ";]"..
		"scroll_container_end[]"..

        "list[current_player;main;1,6;8,4;]"

	minetest.show_formspec(name, "shopping:shop_formspec", formspec)
end




-- I had to insult AI to figure this out -_-
local function remove_held_item(player_name)
	local player = minetest.get_player_by_name(player_name)
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
	remove_held_item(name)
	return rc, s
end





