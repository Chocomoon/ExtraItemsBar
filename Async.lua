-- Extra Items Bar - async item loading.
-- Derived from ElvUI_WindTools Core/Utilities/Async.lua (fang2hou). Trimmed to
-- the functions used by this addon and de-coupled from the WindTools framework.
-- See NOTICE.txt for attribution.

local EIB = _G.EIB

local ipairs = ipairs
local pairs = pairs
local type = type

local Item = Item
local C_Item_GetItemInfoInstant = C_Item.GetItemInfoInstant

EIB.Async = {}

---@type table<string, table> Cache for loaded items
local cache = {
	item = {},
}

---@alias ItemCallback fun(itemInstance:ItemMixin)

---Load item data asynchronously and execute callback by item ID
---@param itemID number The item ID to load
---@param callback ItemCallback? Callback function to execute when item is loaded
---@return any? item Cached item data if available
function EIB.Async.WithItemID(itemID, callback)
	if type(itemID) ~= "number" then
		return
	end

	if not callback then
		callback = function(...) end
	end

	if type(callback) ~= "function" then
		return
	end

	if cache.item[itemID] then
		callback(cache.item[itemID])
		return cache.item[itemID]
	end

	local itemInstance = Item:CreateFromItemID(itemID)
	if itemInstance:IsItemEmpty() then
		return
	end

	itemInstance:ContinueOnItemLoad(function()
		callback(itemInstance)
	end)

	cache.item[itemID] = itemInstance

	return itemInstance
end

---Load item data asynchronously and execute callback by item link
---@param itemLink string The item link to load
---@param callback ItemCallback? Callback function to execute when item is loaded
---@return any
function EIB.Async.WithItemLink(itemLink, callback)
	if type(itemLink) ~= "string" then
		return
	end

	if not callback then
		callback = function(...) end
	end

	if type(callback) ~= "function" then
		return
	end

	local itemID = C_Item_GetItemInfoInstant(itemLink)
	if not itemID then
		return
	end

	return EIB.Async.WithItemID(itemID, callback)
end

---Load multiple items asynchronously from a table
---@param itemIDTable table Table containing item IDs
---@param tType string? Type of table processing
---@param callback ItemCallback? Callback for individual items
---@param tableCallback function? Callback for completed table
function EIB.Async.WithItemIDTable(itemIDTable, tType, callback, tableCallback)
	if type(itemIDTable) ~= "table" then
		return
	end

	if not callback then
		callback = function(...) end
	end

	if type(callback) ~= "function" then
		return
	end

	if not tableCallback then
		tableCallback = function(...) end
	end

	if type(tableCallback) ~= "function" then
		return
	end

	if type(tType) ~= "string" then
		tType = "value"
	end

	local totalItems = 0
	local completedItems = 0
	local results = {}

	-- Count total items first
	if tType == "list" then
		totalItems = #itemIDTable
	elseif tType == "value" then
		for _ in pairs(itemIDTable) do
			totalItems = totalItems + 1
		end
	elseif tType == "key" then
		for _, value in pairs(itemIDTable) do
			if value then
				totalItems = totalItems + 1
			end
		end
	end

	---Handle completion of individual item loading
	---@param itemID number The item ID that was loaded
	---@param itemInstance any The loaded item instance
	local function onItemComplete(itemID, itemInstance)
		completedItems = completedItems + 1
		results[itemID] = itemInstance

		-- Call individual callback
		callback(itemInstance)

		-- Check if all items are complete
		if completedItems >= totalItems then
			tableCallback(results, itemIDTable)
		end
	end

	if tType == "list" then
		for _, itemID in ipairs(itemIDTable) do
			EIB.Async.WithItemID(itemID, function(itemInstance)
				---Callback wrapper for list processing
				onItemComplete(itemID, itemInstance)
			end)
		end
	elseif tType == "value" then
		for _, itemID in pairs(itemIDTable) do
			EIB.Async.WithItemID(itemID, function(itemInstance)
				---Callback wrapper for value processing
				onItemComplete(itemID, itemInstance)
			end)
		end
	elseif tType == "key" then
		for itemID, value in pairs(itemIDTable) do
			if value then
				EIB.Async.WithItemID(itemID, function(itemInstance)
					---Callback wrapper for key processing
					onItemComplete(itemID, itemInstance)
				end)
			end
		end
	end

	-- Handle empty table case
	if totalItems == 0 then
		tableCallback({}, itemIDTable)
	end
end

---Load an equipment slot item asynchronously and execute callback
---@param itemSlotID number The equipment slot ID to load
---@param callback ItemCallback? Callback function to execute when item is loaded
function EIB.Async.WithItemSlotID(itemSlotID, callback)
	if type(itemSlotID) ~= "number" then
		return
	end

	if not callback then
		callback = function(...) end
	end

	if type(callback) ~= "function" then
		return
	end

	local itemInstance = Item:CreateFromEquipmentSlot(itemSlotID)
	if itemInstance:IsItemEmpty() then
		return
	end

	itemInstance:ContinueOnItemLoad(function()
		callback(itemInstance)
	end)

	return itemInstance
end