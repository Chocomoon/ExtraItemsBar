-- Extra Items Bar - Blizzard "Interface Options" panel.
-- Replaces the ElvUI options tree of the original module. Option set mirrors
-- ElvUI_WindTools Options/Item.lua (extraItemsBar section). See NOTICE.txt.

local EIB = _G.EIB

local L = setmetatable({}, {
	__index = function(_, key)
		return EIB.L[key]
	end
})

local async = EIB.Async

local _G = _G
local format = format
local ipairs = ipairs
local pairs = pairs
local tconcat = table.concat
local tinsert = tinsert
local tonumber = tonumber
local tostring = tostring
local tremove = tremove

local CreateFrame = CreateFrame
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_SetText = UIDropDownMenu_SetText

local ColorPickerFrame = _G.ColorPickerFrame

local function GetDB()
	return EIB.db.profile.extraItemsBar
end

local customListSelected1, customListSelected2

local currentBarID = 1
local showCustom = false
local showBlacklist = false
local showAbout = false
local barFrame, aboutFrame, customFrame, blacklistFrame, rightScroll, rightContent

local UpdateRightPane

local function GetIconString(icon, height, width)
	if icon then
		return format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t ", icon, height, width)
	end
	return ""
end

-- Plain-text version of the "button groups" reference tooltip
local groupTooltip = (function()
	local tags = {
		general = L["General"],
		leg = L["Legacy"],
		sl = L["[ABBR] Shadowlands"],
		df = L["[ABBR] Dragonflight"],
		tww = L["[ABBR] The War Within"],
		mn = L["[ABBR] Midnight"],
	}
	local function desc(code, help)
		return code .. " = " .. help
	end
	local lines = {
		L["Set the type and order of button groups."],
		L["You can separate the groups with a comma."],
		desc("QUEST", L["Quest Items"]),
		desc("EQUIP", L["Equipments"]),
		desc("CUSTOM", L["Custom Items"]),
		desc("SLOT:1-19", L["Equipment Slots (Range)"]),
		desc("SLOT:2", L["Equipment Slots (Single)"]),
		desc("POTION", format("%s - %s", L["Potions"], L["All"])),
		desc("POTIONGN", format("%s %s", L["Potions"], tags.general)),
		desc("POTIONLEG", format("%s %s", L["Potions"], tags.leg)),
		desc("POTIONSL", format("%s %s", L["Potions"], tags.sl)),
		desc("POTIONDF", format("%s %s", L["Potions"], tags.df)),
		desc("POTIONTWW", format("%s %s", L["Potions"], tags.tww)),
		desc("POTIONMN", format("%s %s", L["Potions"], tags.mn)),
		desc("FLASK", format("%s - %s", L["Flasks"], L["All"])),
		desc("FLASKLEG", format("%s %s", L["Flasks"], tags.leg)),
		desc("FLASKSL", format("%s %s", L["Flasks"], tags.sl)),
		desc("FLASKDF", format("%s %s", L["Flasks"], tags.df)),
		desc("FLASKTWW", format("%s %s", L["Flasks"], tags.tww)),
		desc("FLASKMN", format("%s %s", L["Flasks"], tags.mn)),
		desc("RUNE", format("%s - %s", L["Runes"], L["All"])),
		desc("RUNETWW", format("%s %s", L["Runes"], tags.tww)),
		desc("RUNEMN", format("%s %s", L["Runes"], tags.mn)),
		desc("VANTUS", format("%s - %s", L["Vantus Runes"], L["All"])),
		desc("VANTUSTWW", format("%s %s", L["Vantus Runes"], tags.tww)),
		desc("VANTUSMN", format("%s %s", L["Vantus Runes"], tags.mn)),
		desc("FOOD", format("%s - %s", L["Crafted Food"], L["All"])),
		desc("FOODTWW", format("%s %s", L["Crafted Food"], tags.tww)),
		desc("FOODMN", format("%s %s", L["Crafted Food"], tags.mn)),
		desc("FOODVENDOR", format("%s - %s %s", L["Food"], L["Sold by vendor"], tags.mn)),
		desc("MAGEFOOD", format("%s - %s", L["Food"], L["Crafted by mage"])),
		desc("FISHING", format("%s - %s", L["Fishing"], L["All"])),
		desc("FISHINGTWW", format("%s %s", L["Fishing"], tags.tww)),
		desc("FISHINGMN", format("%s %s", L["Fishing"], tags.mn)),
		desc("BANNER", L["Banners"]),
		desc("UTILITY", L["Utilities"]),
		desc("OPENABLE", L["Openable Items"]),
		desc("PROF", format("%s - %s", L["Profession Items"], L["All"])),
		desc("PROFTWW", format("%s %s", L["Profession Items"], tags.tww)),
		desc("PROFMN", format("%s %s", L["Profession Items"], tags.mn)),
		desc("SEEDS", L["Seeds"]),
		desc("BIGDIG", L["Big Dig"]),
		desc("DELVE", L["Delves"]),
		desc("HOLIDAY", L["Holiday Reward Boxes"]),
	}
	return tconcat(lines, "\n")
end)()

-- ---------------------------------------------------------------------------
-- Widget factories
-- ---------------------------------------------------------------------------

local widgets = {}
local Refresh

local function Track(widget, disabledFn)
	widget.disabledFn = disabledFn
	tinsert(widgets, widget)
	return widget
end

	local function CreateCheckbox(row, get, set, disabledFn, left)
	local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
	if left then
		cb:SetPoint("LEFT", row, "LEFT", left, 0)
	else
		cb:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	end

	local widget = {
		refresh = function()
			cb:SetChecked(get())
		end,
		SetDisabled = function(_, disabled)
			cb:SetEnabled(not disabled)
			cb:SetAlpha(disabled and 0.4 or 1)
		end,
	}
	cb:SetScript("OnClick", function(self)
		set(self:GetChecked())
	end)
	widget.refresh()

	return Track(widget, disabledFn)
end

local function CreateSlider(row, get, set, min, max, step, decimals, disabledFn)
	local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
	slider:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	slider:SetSize(150, 16)
	slider:SetMinMaxValues(min, max)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)

	local widget = {
		refresh = function()
			slider.locked = true
			slider:SetValue(get())
			slider.locked = false
			slider.Text:SetText(format("%." .. (decimals or 0) .. "f", get()))
		end,
		SetDisabled = function(_, disabled)
			slider:SetEnabled(not disabled)
			slider:SetAlpha(disabled and 0.4 or 1)
		end,
	}
	slider:SetScript("OnValueChanged", function(self, value)
		if not self.locked then
			set(value)
			self.Text:SetText(format("%." .. (decimals or 0) .. "f", value))
		end
	end)
	widget.refresh()

	return Track(widget, disabledFn)
end

local function CreateEditBox(row, get, set, disabledFn, tooltip)
	local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	eb:SetSize(150, 22)
	eb:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	eb:SetAutoFocus(false)

	local widget = {
		refresh = function()
			if not eb:HasFocus() then
				eb:SetText(get() or "")
			end
		end,
		SetDisabled = function(_, disabled)
			eb:SetEnabled(not disabled)
			eb:SetAlpha(disabled and 0.4 or 1)
		end,
	}
	eb:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		set(self:GetText())
	end)
	eb:SetScript("OnEditFocusLost", function(self)
		if self:GetText() ~= get() then
			set(self:GetText())
		end
	end)

	if tooltip then
		eb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		eb:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	Track(widget, disabledFn)
	return widget
end

local function CreateDropdown(row, valueBuilder, get, set, disabledFn, left, noRefresh)
	local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
	if left then
		dd:SetPoint("LEFT", row, "LEFT", left, 0)
	else
		dd:SetPoint("RIGHT", row, "RIGHT", -14, 0)
	end

	-- Text + arrow only, matching the native UIDropDownMenu look. The template's
	-- own Left/Middle/Right chain draws a fixed 165px box that ignores
	-- dd:SetWidth, so hide it.
	dd.Left:Hide()
	dd.Middle:Hide()
	dd.Right:Hide()

	local text = dd.Text
	if text then
		text:SetFontObject(GameFontNormal)
		text:SetTextColor(1, 1, 1, 1)
	end

	dd.Button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
	dd.Button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
	dd.Button:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
	dd.Button:GetPushedTexture():SetVertexColor(0, 0, 0, 0.5)

	UIDropDownMenu_Initialize(dd, function(self, level)
		local values = valueBuilder() or {}
		local info = UIDropDownMenu_CreateInfo()
		for key, label in pairs(values) do
			info.text = label
			info.value = key
		info.func = function()
			local saved = rightScroll and rightScroll:GetVerticalScroll() or 0
			set(key)
			UIDropDownMenu_SetText(self, label)
			dd:SetWidth(max(dd.Text:GetUnboundedStringWidth() + 32, 120))
			if noRefresh then
				EIB:UpdateBar(currentBarID)
			else
				Refresh()
			end
			if rightScroll then
				C_Timer.After(0, function()
					rightScroll:SetVerticalScroll(saved)
				end)
			end
		end
			info.checked = get() == key
			UIDropDownMenu_AddButton(info, level)
		end
	end, "MENU")

	-- The template anchors the opened menu to its hidden "Left" texture, which
	-- floats ~81px below the control and reads as a detached tall black box.
	-- Anchor the menu under the control with a small gap so it reads as a
	-- separate dropdown list.
	UIDropDownMenu_SetAnchor(dd, 0, 6, "TOPLEFT", dd, "BOTTOMLEFT")

	local widget = {
		refresh = function()
			local values = valueBuilder() or {}
			local current = get()
			UIDropDownMenu_SetText(dd, values[current] or tostring(current or ""))

			-- The template's hidden Left/Middle/Right chain anchors the text far
			-- from the frame edges and UIDropDownMenu_MatchTextWidth adds double
			-- padding, so lay the collapsed control out manually to hug the text.
			dd:SetHeight(22)

			local text = dd.Text
			text:SetJustifyH("RIGHT")
			text:ClearAllPoints()
			text:SetPoint("LEFT", dd, "LEFT", 8, 0)
			text:SetPoint("RIGHT", dd, "RIGHT", -24, 0)

			local btn = dd.Button
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", dd, "TOPLEFT", 0, 0)
			btn:SetPoint("BOTTOMRIGHT", dd, "BOTTOMRIGHT", 0, 0)

			local arrow = btn:GetNormalTexture()
			if arrow then
				arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
				arrow:SetSize(14, 14)
				arrow:ClearAllPoints()
				arrow:SetPoint("RIGHT", btn, "RIGHT", -7, 0)
			end

			local hl = btn:GetHighlightTexture()
			if hl then
				hl:ClearAllPoints()
				hl:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
				hl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
			end

			local pushed = btn:GetPushedTexture()
			if pushed then
				pushed:ClearAllPoints()
				pushed:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
				pushed:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
			end

			dd:SetWidth(max(text:GetUnboundedStringWidth() + 32, 120))
		end,
		SetDisabled = function(_, disabled)
			dd:SetAlpha(disabled and 0.4 or 1)
		end,
	}
	widget.refresh()

	return Track(widget, disabledFn)
end

local function CreateColorButton(row, get, set, disabledFn)
	local swatch = CreateFrame("Button", nil, row)
	swatch:SetSize(24, 16)
	swatch:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	swatch:SetNormalTexture("Interface\\Buttons\\WHITE8X8")

	swatch:SetScript("OnClick", function()
		local r, g, b = get()
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r, g = g, b = b,
			swatchFunc = function()
				local nr, ng, nb = ColorPickerFrame:GetColorRGB()
				set(nr, ng, nb)
				swatch:GetNormalTexture():SetVertexColor(nr, ng, nb)
			end,
			cancelFunc = function()
				set(r, g, b)
				swatch:GetNormalTexture():SetVertexColor(r, g, b)
			end,
		})
	end)

	local widget = {
		refresh = function()
			local r, g, b = get()
			swatch:GetNormalTexture():SetVertexColor(r, g, b)
		end,
		SetDisabled = function(_, disabled)
			swatch:SetEnabled(not disabled)
			swatch:SetAlpha(disabled and 0.4 or 1)
		end,
	}
	widget.refresh()

	return Track(widget, disabledFn)
end

local function CreateButton(row, label, func, disabledFn)
	local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	btn:SetSize(110, 22)
	btn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	btn:SetText(label)
	btn:SetScript("OnClick", func)

	local widget = {
		SetDisabled = function(_, disabled)
			btn:SetEnabled(not disabled)
			btn:SetAlpha(disabled and 0.4 or 1)
		end,
	}

	return Track(widget, disabledFn)
end

local function CreateAddItemRow(row, getList, add, disabledFn, tooltip)
	local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	eb:SetSize(96, 22)
	eb:SetPoint("RIGHT", row, "RIGHT", -72, 0)
	eb:SetAutoFocus(false)
	eb:SetTextInsets(6, 6, 0, 0)

	local addBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	addBtn:SetSize(56, 22)
	addBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	addBtn:SetText(L["Add"])

	local function TryAdd()
		local itemID = tonumber(eb:GetText())
		if not itemID or itemID <= 0 then
			EIB:Print(L["The item ID is invalid."])
			eb:SetText("")
			eb:SetFocus()
			return
		end
		local instance = async.WithItemID(itemID, function(item)
			if not item or not item:GetItemName() or item:GetItemName() == "" then
				EIB:Print(L["The item ID is invalid."])
				return
			end
			if add(itemID) then
				eb:SetText("")
				eb:ClearFocus()
				Refresh()
			end
		end)
		if not instance then
			EIB:Print(L["The item ID is invalid."])
		end
	end

	addBtn:SetScript("OnClick", TryAdd)
	eb:SetScript("OnEnterPressed", function(self)
		TryAdd()
		self:ClearFocus()
	end)
	eb:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	if tooltip then
		eb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		eb:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	return Track({
		SetDisabled = function(_, disabled)
			eb:SetEnabled(not disabled)
			addBtn:SetEnabled(not disabled)
			eb:SetAlpha(disabled and 0.4 or 1)
			addBtn:SetAlpha(disabled and 0.4 or 1)
		end,
	}, disabledFn)
end

-- ---------------------------------------------------------------------------
-- Shared value builders
-- ---------------------------------------------------------------------------

local function FontValues()
	local defaultLabel = L["Default"]
	local result = { ["default"] = defaultLabel }
	local LSM = EIB:GetLSM()
	if LSM then
		local list = LSM:List("font") or {}
		for _, name in ipairs(list) do
			if name ~= defaultLabel then
				result[name] = name
			end
		end
	end
	return result
end

local outlineValues = {
	NONE = L["None"],
	OUTLINE = L["Outline"],
	THICKOUTLINE = L["Thick"],
	SHADOW = L["FONT_SHADOW"],
	SHADOWOUTLINE = L["FONT_SHADOW_OUTLINE"],
	SHADOWTHICKOUTLINE = L["FONT_SHADOW_THICK"],
	MONOCHROME = L["FONT_MONO"],
	MONOCHROMEOUTLINE = L["FONT_MONO_OUTLINE"],
	MONOCHROMETHICKOUTLINE = L["FONT_MONO_THICK"],
}

local anchorValues = {
	TOPLEFT = L["TOPLEFT"],
	TOPRIGHT = L["TOPRIGHT"],
	BOTTOMLEFT = L["BOTTOMLEFT"],
	BOTTOMRIGHT = L["BOTTOMRIGHT"],
}

local itemLabels = {}

local function GetItemLabel(itemID)
	local cached = itemLabels[itemID]
	if cached then
		return cached
	end

	local instance = async.WithItemID(itemID, function(item)
		if item and item:GetItemName() and item:GetItemName() ~= "" then
			itemLabels[itemID] = GetIconString(item:GetItemIcon(), 14, 18) .. item:GetItemName()
			Refresh()
		end
	end)
	if instance and instance:GetItemName() and instance:GetItemName() ~= "" then
		return itemLabels[itemID] or tostring(itemID)
	end

	return tostring(itemID)
end

local function CreateItemList(layout, parent, getList, selectedGet, selectedSet, deleteFn, disabledFn)
	local rowH = 24
	local maxRows = 10
	local titleH = 20
	local deleteH = 28

	local reserved = maxRows * rowH + titleH + deleteH

	local listFrame = CreateFrame("Frame", nil, parent)
	listFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, layout.y)
	listFrame:SetWidth(parent:GetWidth() - 20)
	listFrame:SetHeight(reserved)
	layout.y = layout.y - reserved

	local title = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -2)

	local rows = {}

	local deleteBtn = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
	deleteBtn:SetSize(120, deleteH - 4)
	deleteBtn:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", 2, 2)
	deleteBtn:SetText(L["Delete"])
	deleteBtn:SetScript("OnClick", function()
		if selectedGet() then
			deleteFn(selectedGet())
		end
	end)

	local self = {
		reserved = reserved,
		onResize = nil,
		GetCurrentHeight = function()
			return listFrame:GetHeight()
		end,
	}

	Track({
		refresh = function()
			local items = getList()
			local count = 0
			for _ in pairs(items) do
				count = count + 1
			end
			title:SetText(format(L["%d items"], count))

			local n = math.min(count, maxRows)
			while #rows < n do
				local e = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
				e:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 2, -(titleH + #rows * rowH))
				e:SetSize(listFrame:GetWidth() - 4, rowH)
				e:SetBackdrop({
					bgFile = "Interface\\Buttons\\WHITE8X8",
					edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
					edgeSize = 5,
					insets = { left = 1, right = 1, top = 1, bottom = 1 },
				})
				e:SetBackdropColor(0, 0, 0, 0.25)
				e:SetBackdropBorderColor(0, 0, 0, 0)
				e.name = e:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				e.name:SetPoint("LEFT", e, "LEFT", 6, 0)
				e.name:SetPoint("RIGHT", e, "RIGHT", -6, 0)
				e.name:SetJustifyH("LEFT")
				e:SetScript("OnClick", function(btn)
					selectedSet(btn.itemID)
					Refresh()
				end)
				tinsert(rows, e)
			end

			for i = n + 1, #rows do
				rows[i]:Hide()
			end

			local i = 0
			for key, value in pairs(items) do
				if i >= n then
					break
				end
				local itemID = tonumber(value)
				if not itemID then
					itemID = tonumber(key)
				end
				if itemID then
					i = i + 1
					local e = rows[i]
					e:Show()
					e.itemID = itemID
					e.name:SetText(GetItemLabel(itemID))
					if selectedGet() == itemID then
						e:SetBackdropColor(0.15, 0.45, 1, 0.55)
						e:SetBackdropBorderColor(1, 1, 1, 0.8)
					else
						e:SetBackdropColor(0, 0, 0, 0.25)
						e:SetBackdropBorderColor(0, 0, 0, 0)
					end
				end
			end

			listFrame:SetHeight(n * rowH + titleH + deleteH)
			if selectedGet() then
				deleteBtn:SetEnabled(true)
				deleteBtn:SetAlpha(1)
			else
				deleteBtn:SetEnabled(false)
				deleteBtn:SetAlpha(0.4)
			end
			if self.onResize then
				self.onResize()
			end
		end,
		SetDisabled = function(_, disabled)
			if disabled then
				for _, e in ipairs(rows) do
					e:SetEnabled(false)
				end
				deleteBtn:SetEnabled(false)
				deleteBtn:SetAlpha(0.4)
			else
				for _, e in ipairs(rows) do
					e:SetEnabled(true)
				end
			end
		end,
	}, disabledFn)

	return self
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local function NewLayout(parent, compact)
	local layout = { y = -6, parent = parent }

	function layout:Header(text)
		self.y = self.y - (compact and 4 or 8)
		local fs = parent:CreateFontString(nil, "OVERLAY", compact and "GameFontNormal" or "GameFontNormalLarge")
		fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, self.y)
		fs:SetText(text)
		self.y = self.y - (compact and 22 or 32)
		return fs
	end

	function layout:Row(label, controlBuilder, height, controlX)
		height = height or (compact and 24 or 28)
		local row = CreateFrame("Frame", nil, parent)
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, self.y)
		row:SetSize(parent:GetWidth() - 20, height)

		if label then
			local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			fs:SetPoint("LEFT", row, "LEFT", 4, 0)
			if controlX then
				fs:SetPoint("RIGHT", row, "LEFT", controlX - 8, 0)
			else
				fs:SetPoint("RIGHT", row, "RIGHT", -180, 0)
			end
			fs:SetText(label)
			fs:SetJustifyH("LEFT")
			fs:SetWordWrap(false)
		end

		if controlBuilder then
			controlBuilder(row)
		end

		self.y = self.y - height
	end

	function layout:Text(text, height)
		height = height or (compact and 40 or 60)
		local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, self.y)
		fs:SetWidth(parent:GetWidth() - 24)
		fs:SetText(text)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(true)
		fs:SetHeight(height)
		self.y = self.y - height
	end

	function layout:Space(height)
		self.y = self.y - (height or (compact and 4 or 8))
	end

	return layout
end

-- Thin horizontal divider line used to separate setting groups.
local function AddDivider(layout)
	local parent = layout.parent
	layout.y = layout.y - 8
	local divider = parent:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(0.35, 0.35, 0.35, 0.6)
	divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, layout.y)
	divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, layout.y)
	divider:SetHeight(1)
	layout.y = layout.y - 10
end

-- ---------------------------------------------------------------------------
-- Builders
-- ---------------------------------------------------------------------------

local function BuildFontGroup(layout, groupDB, disabledFn)
	layout:Row(L["Font"], function(row)
		CreateDropdown(
			row,
			FontValues,
			function()
				return groupDB().name
			end,
			function(value)
				groupDB().name = value
				EIB:UpdateBar(currentBarID)
			end,
			disabledFn,
			nil,
			true
		)
	end)
	layout:Row(L["Outline"], function(row)
		CreateDropdown(
			row,
			function()
				return outlineValues
			end,
			function()
				return groupDB().style
			end,
			function(value)
				groupDB().style = value
				EIB:UpdateBar(currentBarID)
			end,
			disabledFn,
			nil,
			true
		)
	end)
	layout:Row(L["Size"], function(row)
		CreateSlider(
			row,
			function()
				return groupDB().size
			end,
			function(value)
				groupDB().size = value
				EIB:UpdateBar(currentBarID)
			end,
			5,
			60,
			1,
			0,
			disabledFn
		)
	end)
	layout:Row(L["X-Offset"], function(row)
		CreateSlider(
			row,
			function()
				return groupDB().xOffset
			end,
			function(value)
				groupDB().xOffset = value
				EIB:UpdateBar(currentBarID)
			end,
			-100,
			100,
			1,
			0,
			disabledFn
		)
	end)
	layout:Row(L["Y-Offset"], function(row)
		CreateSlider(
			row,
			function()
				return groupDB().yOffset
			end,
			function(value)
				groupDB().yOffset = value
				EIB:UpdateBar(currentBarID)
			end,
			-100,
			100,
			1,
			0,
			disabledFn
		)
	end)
	layout:Row(L["Color"], function(row)
		CreateColorButton(
			row,
			function()
				return groupDB().color.r, groupDB().color.g, groupDB().color.b
			end,
			function(r, g, b)
				groupDB().color.r, groupDB().color.g, groupDB().color.b = r, g, b
				EIB:UpdateBar(currentBarID)
			end,
			disabledFn
		)
	end)
end

local function BuildBarSection(layout)
	local barDB = function()
		return GetDB()["bar" .. currentBarID]
	end
	local masterDisabled = function()
		return not GetDB().enable
	end
	local fadeDisabled = function()
		return masterDisabled() or not barDB().mouseOver
	end

	local titleFS = layout:Header(L["Bar"] .. " " .. currentBarID)
	Track({
		refresh = function()
			titleFS:SetText(L["Bar"] .. " " .. currentBarID)
		end,
	})

	layout:Row(L["Enable"], function(row)
		CreateCheckbox(
			row,
			function()
				return barDB().enable
			end,
			function(value)
				barDB().enable = value
				EIB:UpdateBar(currentBarID)
			end,
			masterDisabled
		)
	end)

	layout:Row(L["Button Groups"], function(row)
		CreateEditBox(
			row,
			function()
				return barDB().include
			end,
			function(value)
				barDB().include = value
				EIB:UpdateBar(currentBarID)
			end,
			masterDisabled,
			groupTooltip
		)
	end)
	layout:Row(L["Reset"], function(row)
		CreateButton(
			row,
			L["Reset"],
			function()
				EIB.DB.ResetBar(currentBarID)
				EIB:UpdateBar(currentBarID)
				Refresh()
			end,
			masterDisabled
		)
	end)

	AddDivider(layout)

	layout:Row(L["Mouse Over"], function(row)
		CreateCheckbox(
			row,
			function()
				return barDB().mouseOver
			end,
			function(value)
				barDB().mouseOver = value
				EIB:UpdateBar(currentBarID)
				Refresh()
			end,
			masterDisabled
		)
	end)
	layout:Row(L["Fade Time"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().fadeTime
			end,
			function(value)
				barDB().fadeTime = value
			end,
			0,
			2,
			0.01,
			2,
			fadeDisabled
		)
	end)
	layout:Row(L["Alpha Min"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().alphaMin
			end,
			function(value)
				barDB().alphaMin = value
			end,
			0,
			1,
			0.01,
			2,
			fadeDisabled
		)
	end)
	layout:Row(L["Alpha Max"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().alphaMax
			end,
			function(value)
				barDB().alphaMax = value
			end,
			0,
			1,
			0.01,
			2,
			masterDisabled
		)
	end)
	layout:Row(L["Tooltip"], function(row)
		CreateCheckbox(
			row,
			function()
				return barDB().tooltip
			end,
			function(value)
				barDB().tooltip = value
			end,
			masterDisabled
		)
	end)
	layout:Row(L["Visibility"], function(row)
		CreateEditBox(
			row,
			function()
				return barDB().visibility
			end,
			function(value)
				barDB().visibility = value
				EIB:UpdateBar(currentBarID)
			end,
			masterDisabled
		)
	end)

	AddDivider(layout)

	layout:Row(L["Bar Backdrop"], function(row)
		CreateCheckbox(
			row,
			function()
				return barDB().backdrop
			end,
			function(value)
				barDB().backdrop = value
				EIB:UpdateBar(currentBarID)
			end,
			masterDisabled
		)
	end)
	layout:Row(L["Anchor Point"], function(row)
		CreateDropdown(
			row,
			function()
				return anchorValues
			end,
			function()
				return barDB().anchor
			end,
			function(value)
				barDB().anchor = value
				EIB:UpdateBar(currentBarID)
			end,
			masterDisabled
		)
	end)
	layout:Row(L["Button Spacing"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().spacing
			end,
			function(value)
				barDB().spacing = value
				EIB:UpdateBar(currentBarID)
			end,
			1,
			30,
			1,
			0,
			masterDisabled
		)
	end)
	layout:Row(L["Snap Spacing"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().snapSpacing or barDB().spacing
			end,
			function(value)
				barDB().snapSpacing = value
			end,
			0,
			30,
			1,
			0,
			masterDisabled
		)
	end)
	layout:Row(L["Buttons"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().numButtons
			end,
			function(value)
				barDB().numButtons = value
				EIB:UpdateBar(currentBarID)
			end,
			1,
			12,
			1,
			0,
			masterDisabled
		)
	end)
	layout:Row(L["Button Width"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().buttonWidth
			end,
			function(value)
				barDB().buttonWidth = value
				EIB:UpdateBar(currentBarID)
			end,
			2,
			60,
			1,
			0,
			masterDisabled
		)
	end)
	layout:Row(L["Button Height"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().buttonHeight
			end,
			function(value)
				barDB().buttonHeight = value
				EIB:UpdateBar(currentBarID)
			end,
			2,
			60,
			1,
			0,
			masterDisabled
		)
	end)
	layout:Row(L["Buttons Per Row"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().buttonsPerRow
			end,
			function(value)
				barDB().buttonsPerRow = value
				EIB:UpdateBar(currentBarID)
			end,
			1,
			12,
			1,
			0,
			masterDisabled
		)
	end)

	AddDivider(layout)

	layout:Header(L["Crafting Quality Tier"])
	layout:Row(L["Size"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().qualityTier.size
			end,
			function(value)
				barDB().qualityTier.size = value
			end,
			5,
			60,
			1,
			0,
			masterDisabled
		)
	end)
	layout:Row(L["X-Offset"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().qualityTier.xOffset
			end,
			function(value)
				barDB().qualityTier.xOffset = value
			end,
			-100,
			100,
			1,
			0,
			masterDisabled
		)
	end)
	layout:Row(L["Y-Offset"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().qualityTier.yOffset
			end,
			function(value)
				barDB().qualityTier.yOffset = value
			end,
			-100,
			100,
			1,
			0,
			masterDisabled
		)
	end)

	AddDivider(layout)

	layout:Header(L["Counter"])
	layout:Text(L["Count Font Description"], 18)
	BuildFontGroup(layout, function()
		return barDB().countFont
	end, masterDisabled)

	AddDivider(layout)

	layout:Header(L["Key Binding"])
	layout:Text(L["Key Binding Font Description"], 18)
	BuildFontGroup(layout, function()
		return barDB().bindFont
	end, masterDisabled)

	layout:Space(6)
end

local function BuildAbout(layout)
	layout:Header(L["About"] .. " / " .. L["Credits"])
	layout:Text(format(L["This addon is a standalone extraction of the Extra Items Bar module from %s."], "ElvUI_WindTools (github.com/fang2hou/ElvUI_WindTools)"))
	layout:Text(format(L["Original author: %s"], "fang2hou"))
	layout:Text(format(L["Feature originally from %s"], "EUI (cadcamzy)"))
	layout:Text("This addon is used and modified with the author's permission. See NOTICE.txt.")
end

-- ---------------------------------------------------------------------------
-- Panel construction
-- ---------------------------------------------------------------------------

local function BuildGeneral(parent)
	local layout = NewLayout(parent, true)

	-- Top title: enlarged two steps (GameFontNormalLarge) + version
	local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, layout.y)
	title:SetText(L["Extra Items Bar"] .. "  v" .. (EIB.version or "?"))
	layout.y = layout.y - 32

	local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	measure:Hide()
	local maxLabelWidth = 0
	for _, label in ipairs({ L["Enable"], L["No Quantum Items"], L["Bar Style"] }) do
		measure:SetText(label)
		maxLabelWidth = math.max(maxLabelWidth, measure:GetUnboundedStringWidth())
	end
	local controlX = math.ceil(maxLabelWidth + 32)

	layout:Row(L["Enable"], function(row)
		CreateCheckbox(
			row,
			function()
				return GetDB().enable
			end,
			function(value)
				GetDB().enable = value
				EIB:ProfileUpdate()
				Refresh()
			end,
			nil,
			controlX
		)
	end, nil, controlX)

	layout:Space()
	layout:Row(L["No Quantum Items"], function(row)
		CreateCheckbox(
			row,
			function()
				return GetDB().noQuantumItems
			end,
			function(value)
				GetDB().noQuantumItems = value
				EIB:ProfileUpdate()
			end,
			function()
				return not GetDB().enable
			end,
			controlX
		)
	end, nil, controlX)

	layout:Space()
	layout:Row(L["Bar Style"], function(row)
		CreateDropdown(
			row,
			function()
				return {
					auto = L["Auto"],
					grid = L["Native"],
					flat = L["Flat"],
				}
			end,
			function()
				return GetDB().barStyle or "auto"
			end,
			function(value)
				GetDB().barStyle = value
				EIB:ApplyBarStyle()
			end,
			nil,
			controlX
		)

		-- Help icon: shows the auto-detect explanation on hover.
		-- Positioned right after the "Bar Style" label text (10px gap) so it
		-- never collides with the dropdown on the right.
		local measure = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		measure:SetText(L["Bar Style"])
		measure:Hide()
		local gap = 10
		local help = CreateFrame("Button", nil, row)
		help:SetSize(16, 16)
		help:SetPoint("LEFT", row, "LEFT", 4 + measure:GetUnboundedStringWidth() + gap, 0)
		help:SetNormalTexture("Interface\\FriendsFrame\\InformationIcon")
		help:SetHighlightTexture("Interface\\FriendsFrame\\InformationIcon-Highlight")
		help:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L["Automatically detect whether the action bars are skinned by a UI addon. If they are, the bars use a flat minimal style; otherwise the native grid look is kept."], nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		help:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end, nil, controlX)

	layout:Space(6)
	layout:Row(nil, function(row)
		local btn1 = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		btn1:SetSize(110, 22)
		btn1:SetPoint("LEFT", row, "LEFT", 4, 0)
		btn1:SetText(L["Unlock"])
		btn1:SetScript("OnClick", function()
			EIB:ToggleMoveMode()
		end)

		local btn2 = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		btn2:SetSize(110, 22)
		btn2:SetPoint("LEFT", row, "LEFT", 118, 0)
		btn2:SetText(L["Reset Positions"])
		btn2:SetScript("OnClick", function()
			EIB:ResetPosition()
		end)
	end)

	parent:SetHeight(math.abs(layout.y) + 20)
end

local function BuildCustomSection(parent)
	local layout = NewLayout(parent)

	layout:Header(L["Custom Items"])
	layout:Row(L["New Item ID"], function(row)
		CreateAddItemRow(
			row,
			function()
				return GetDB().customList
			end,
			function(itemID)
				for _, id in ipairs(GetDB().customList) do
					if id == itemID then
						EIB:Print(L["Item is already in the list."])
						return false
					end
				end
				tinsert(GetDB().customList, itemID)
				EIB:UpdateBars()
				return true
			end,
			function()
				return not GetDB().enable
			end,
			L["Enter an item ID and press Enter or click Add."]
		)
	end)
	local customList = CreateItemList(
		layout,
		parent,
		function()
			return GetDB().customList
		end,
		function()
			return customListSelected1
		end,
		function(value)
			customListSelected1 = value
		end,
		function(itemID)
			for i, id in ipairs(GetDB().customList) do
				if id == itemID then
					tremove(GetDB().customList, i)
					break
				end
			end
			customListSelected1 = nil
			EIB:UpdateBars()
			Refresh()
		end,
		function()
			return not GetDB().enable
		end
	)

	parent:SetHeight(math.abs(layout.y) + 20)
	local finalHeight = parent:GetHeight()
	customList.onResize = function()
		parent:SetHeight(finalHeight - customList.reserved + customList:GetCurrentHeight())
		UpdateRightPane()
	end
end

local function BuildBlacklistSection(parent)
	local layout = NewLayout(parent)

	layout:Header(L["Blacklist"])
	layout:Row(L["New Item ID"], function(row)
		CreateAddItemRow(
			row,
			function()
				return GetDB().blackList
			end,
			function(itemID)
				if GetDB().blackList[itemID] then
					EIB:Print(L["Item is already in the list."])
					return false
				end
				GetDB().blackList[itemID] = true
				EIB:UpdateBars()
				return true
			end,
			function()
				return not GetDB().enable
			end,
			L["Enter an item ID and press Enter or click Add."]
		)
	end)
	local blackList = CreateItemList(
		layout,
		parent,
		function()
			return GetDB().blackList
		end,
		function()
			return customListSelected2
		end,
		function(value)
			customListSelected2 = value
		end,
		function(itemID)
			GetDB().blackList[itemID] = nil
			customListSelected2 = nil
			EIB:UpdateBars()
			Refresh()
		end,
		function()
			return not GetDB().enable
		end
	)

	parent:SetHeight(math.abs(layout.y) + 20)
	local finalHeight = parent:GetHeight()
	blackList.onResize = function()
		parent:SetHeight(finalHeight - blackList.reserved + blackList:GetCurrentHeight())
		UpdateRightPane()
	end
end

local function CreateSelectButton(parent, text, mode, y)
	local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
	btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
	btn:SetSize(150, 26)
	btn:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 6,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btn.label:SetPoint("LEFT", btn, "LEFT", 8, 0)
	btn.label:SetText(text)
	btn.label:SetJustifyH("LEFT")

	btn:SetScript("OnClick", function()
		if type(mode) == "number" then
			currentBarID = mode
			showCustom = false
			showBlacklist = false
			showAbout = false
		elseif mode == "custom" then
			showCustom = true
			showBlacklist = false
			showAbout = false
		elseif mode == "blacklist" then
			showCustom = false
			showBlacklist = true
			showAbout = false
		else
			showCustom = false
			showBlacklist = false
			showAbout = true
		end
		UpdateRightPane()
		Refresh()
	end)

	Track({
		refresh = function()
			local selected = false
			if type(mode) == "number" then
				selected = not showCustom and not showBlacklist and not showAbout and currentBarID == mode
			elseif mode == "custom" then
				selected = showCustom
			elseif mode == "blacklist" then
				selected = showBlacklist
			else
				selected = showAbout
			end
			if selected then
				btn:SetBackdropColor(0.15, 0.45, 1, 0.7)
				btn:SetBackdropBorderColor(1, 1, 1, 0.9)
			else
				btn:SetBackdropColor(0, 0, 0, 0.25)
				btn:SetBackdropBorderColor(0, 0, 0, 0)
			end
			btn.label:SetTextColor(selected and 1 or 0.7, selected and 1 or 0.7, selected and 1 or 0.7, 1)
		end,
	})
end

local function BuildBarSelector(parent)
	parent.header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	parent.header:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -6)
	parent.header:SetText(L["Bars"])

	local y = -40
	for i = 1, 5 do
		CreateSelectButton(parent, L["Bar"] .. " " .. i, i, y)
		y = y - 30
	end
	CreateSelectButton(parent, L["Custom Items"], "custom", y)
	y = y - 30
	CreateSelectButton(parent, L["Blacklist"], "blacklist", y)
	y = y - 30
	CreateSelectButton(parent, L["About"], "about", y)
end

UpdateRightPane = function()
	if not barFrame or not aboutFrame or not customFrame or not blacklistFrame then
		return
	end

	local visible = barFrame
	if showCustom then
		visible = customFrame
	elseif showBlacklist then
		visible = blacklistFrame
	elseif showAbout then
		visible = aboutFrame
	end

	barFrame:SetShown(visible == barFrame)
	customFrame:SetShown(visible == customFrame)
	blacklistFrame:SetShown(visible == blacklistFrame)
	aboutFrame:SetShown(visible == aboutFrame)
	rightContent:SetHeight(visible:GetHeight())
	rightScroll:SetVerticalScroll(0)
end

Refresh = function()
	for _, widget in ipairs(widgets) do
		if widget.refresh then
			widget.refresh()
		end
		local disabled = widget.disabledFn and widget.disabledFn() or false
		if widget.SetDisabled then
			widget:SetDisabled(disabled)
		end
	end
end

function EIB:RegisterOptionsPanel()
	if self.optionsPanel then
		return
	end

	local panel = CreateFrame("Frame", "ExtraItemsBarOptionsPanel")
	panel.name = L["Extra Items Bar"]

	self.optionsPanel = panel
	panel:SetWidth(674)

	local general = CreateFrame("Frame", nil, panel)
	general:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	general:SetWidth(650)
	BuildGeneral(general)

	local split = CreateFrame("Frame", nil, panel)
	split:SetPoint("TOPLEFT", general, "BOTTOMLEFT", 0, 0)
	split:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

	local left = CreateFrame("Frame", nil, split)
	left:SetPoint("TOPLEFT", split, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", split, "BOTTOMLEFT", 0, 0)
	left:SetWidth(170)
	BuildBarSelector(left)

	rightScroll = CreateFrame("ScrollFrame", nil, split, "UIPanelScrollFrameTemplate")
	rightScroll:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
	rightScroll:SetPoint("BOTTOMRIGHT", split, "BOTTOMRIGHT", -20, 0)

	rightContent = CreateFrame("Frame", nil, rightScroll)
	rightContent:SetWidth(480)
	rightContent:SetPoint("TOPLEFT", rightScroll, "TOPLEFT", 0, 0)

	barFrame = CreateFrame("Frame", nil, rightContent)
	barFrame:SetPoint("TOPLEFT", rightContent, "TOPLEFT", 0, 0)
	barFrame:SetWidth(480)
	local barLayout = NewLayout(barFrame)
	BuildBarSection(barLayout)
	barFrame:SetHeight(math.abs(barLayout.y) + 20)

	customFrame = CreateFrame("Frame", nil, rightContent)
	customFrame:SetPoint("TOPLEFT", rightContent, "TOPLEFT", 0, 0)
	customFrame:SetWidth(480)
	BuildCustomSection(customFrame)
	customFrame:Hide()

	blacklistFrame = CreateFrame("Frame", nil, rightContent)
	blacklistFrame:SetPoint("TOPLEFT", rightContent, "TOPLEFT", 0, 0)
	blacklistFrame:SetWidth(480)
	BuildBlacklistSection(blacklistFrame)
	blacklistFrame:Hide()

	aboutFrame = CreateFrame("Frame", nil, rightContent)
	aboutFrame:SetPoint("TOPLEFT", rightContent, "TOPLEFT", 0, 0)
	aboutFrame:SetWidth(480)
	local aboutLayout = NewLayout(aboutFrame)
	BuildAbout(aboutLayout)
	aboutFrame:SetHeight(math.abs(aboutLayout.y) + 20)
	aboutFrame:Hide()

	rightScroll:SetScrollChild(rightContent)
	UpdateRightPane()

	panel:SetScript("OnShow", Refresh)

	if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
		local category = _G.Settings.RegisterCanvasLayoutCategory(panel, L["Extra Items Bar"])
		_G.Settings.RegisterAddOnCategory(category)
		self.optionsCategory = category
	elseif _G.InterfaceOptions_AddCategory then
		_G.InterfaceOptions_AddCategory(panel)
	end
end