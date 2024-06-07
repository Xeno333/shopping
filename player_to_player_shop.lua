
shopping.items_per_page = 48




local function give_item_to_player(player_name, item_stack)
	local player = minetest.get_player_by_name(player_name)
	if not player then
		-- Player not found, handle error
		return false
	end

	local inv = player:get_inventory()
	if not inv:room_for_item("main", item_stack) then
		-- Player does not have enough room for the item stack
		minetest.chat_send_player(player_name, "Not enough room in your inventory.")
		return false
	end

	inv:add_item("main", item_stack)

	return true
end



local function remove_entry(list, index)
	-- Shift elements to the left starting from the removed index
	for i = index, #list - 1 do
		list[i] = list[i + 1]
	end
	-- Remove the last element (which is now a duplicate)
	list[#list] = nil
end



local function add_item_to_shop(itemstack, price, name)
	local mod_storage = shopping.storage
	local shop = minetest.deserialize(mod_storage:get_string("shop")) or {}

	shop[#shop + 1] = {itemstack:to_string(), price, name}

	mod_storage:set_string("shop", minetest.serialize(shop))
	return true, "Item listed!"
end

local function get_item_from_shop(name, index)
	local mod_storage = shopping.storage
	local shop = minetest.deserialize(mod_storage:get_string("shop")) or {}

	if (index == 0) or (index > #shop) then
		return false, "Invalid index!"
	end
	

	privs = minetest.get_player_privs(name)
	if privs["shopping_admin"] then
		if give_item_to_player(name, shop[index][1]) then
			remove_entry(shop, index)
		else
			return false, "Failed!"
		end
		
		mod_storage:set_string("shop", minetest.serialize(shop))
		return true, "Item bought as admin!"
	end


	if (jeans_economy.get_account(name) < shop[index][2]) and (not (name == shop[index][3])) then
		return false, "You don't have enough money!"
	else
		if not (name == shop[index][3]) then
			jeans_economy.book(name, shop[index][3], shop[index][2], name .. " bought item for " .. shop[index][2])
		end

		if give_item_to_player(name, shop[index][1]) then
			remove_entry(shop, index)
		else
			return false, "Failed!"
		end

		mod_storage:set_string("shop", minetest.serialize(shop))
		return true, "Item bought!"
	end
end


-- Buy
function shopping.buy(name, index)
	return get_item_from_shop(name, index)
end


-- Shop
function shopping.shop(name, page)
	local mod_storage = shopping.storage
	local shop = minetest.deserialize(mod_storage:get_string("shop")) or {}

	local formspec = "size[9,8.5]"  -- Increased width to accommodate the scrollbar
	formspec = formspec .. "label[4.2,0;Shop]"  -- Title of the formspec
	formspec = formspec .. "button_exit[0.2,0.2;2,1;close;Close]" -- Add a Close button

	-- Pagination logic
	local total_pages = math.ceil(#shop / shopping.items_per_page)
	page = page or 1 -- Ensure page is initialized
	local start_index = (page - 1) * shopping.items_per_page + 1
	local end_index = math.min(page * shopping.items_per_page, #shop)

	-- Display items in the shop for the current page
	local row = 1
	local col = 0
	for i = start_index, end_index do
		if col == 8 then
			col = 0
			row = row + 1
		end
		local item_stack = shop[i][1]
		local price = shop[i][2]
		local seller_name = shop[i][3]

		local meta = ItemStack(item_stack):get_meta()
		local metadata_str = ""
		-- Collect all metadata fields
		for key, value in pairs(meta:to_table().fields) do
			metadata_str = metadata_str .. key .. ": " .. value .. "\n"
		end

		formspec = formspec .. "item_image_button[" .. col .. "," .. row .. ";1,1;" .. item_stack .. ";buy_" .. i .. ";" .. "$" .. price .. "]" ..
		"tooltip[buy_" .. i .. ";" .. "Seller: " .. seller_name .. "\n" .. minetest.formspec_escape(metadata_str) .. "]"
		col = col + 1
	end

	-- Previous page button
	if page > 1 then
		formspec = formspec .. "button[0,8;2,1;prev;<< Prev]"
	end
	-- Next page button
	if page < total_pages then
		formspec = formspec .. "button[7,8;2,1;next;Next >>]"
	end

	formspec = formspec .. "field[3.5,8;2,1;page;;" .. page .. "]" -- Add a hidden field to hold the current page

	minetest.show_formspec(name, "shopping:shop_formspec", formspec)
end

-- Register a callback to handle button clicks in the shop formspec
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "shopping:shop_formspec" then
		local player_name = player:get_player_name()
		local page = tonumber(fields.page) or 1

		
		if fields.next then
			page = page + 1
			shopping.shop(player_name, page)
			return
		elseif fields.prev then
			page = page - 1
			shopping.shop(player_name, page)
			return
		elseif fields.close then
			return
		end
		for field, _ in pairs(fields) do
			if field:sub(1, 4) == "buy_" then
				local index = tonumber(field:sub(5))
				if index then
					local success, s = shopping.buy(player_name, index)
					minetest.chat_send_player(player_name, s)
					shopping.shop(player_name, page)
				end
			end
		end
		elseif fields.page then
			local mod_storage = shopping.storage
			local shop = minetest.deserialize(mod_storage:get_string("shop")) or {}
			local total_pages = math.ceil(#shop / shopping.items_per_page)

			if page < 1 then
				page = 1
			elseif page > 1 then
				page = total_pages
			end

			shopping.shop(player_name, page)
		return
	end
end)





-- I had to insult AI to figure this out -_-
local function remove_held_item(player_name)
	local player = minetest.get_player_by_name(player_name)
	if not player then
		-- Player not found, handle error
		return
	end

	local wielded_item = player:get_wielded_item()

	if wielded_item:is_empty() then
		-- Player is not holding anything, no need to remove
		return
	end

	local inv = player:get_inventory()
	local wielded_index = player:get_wield_index()

	-- Remove the wielded item from the player's inventory
	inv:set_stack("main", wielded_index, ItemStack(nil))
end




-- Sell
function shopping.sell(name, itemstack, price)
	rc, s = add_item_to_shop(itemstack, price, name)
	remove_held_item(name)
	return rc, s
	--return true, player_name .. " listed " .. item_name .. " for " .. price
end





