-- Extra Items Bar - Blizzard "Interface Options" panel.
-- Replaces the ElvUI options tree of the original module. Option set mirrors
-- ElvUI_WindTools Options/Item.lua (extraItemsBar section). See NOTICE.txt.

local EIB = _G.EIB
local L = EIB.L
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

local function CreateCheckbox(row, get, set, disabledFn)
	local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("RIGHT", row, "RIGHT", -8, 0)

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

local function CreateDropdown(row, valueBuilder, get, set, disabledFn)
	local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
	dd:SetPoint("RIGHT", row, "RIGHT", -14, 3)
	dd:SetWidth(160)

	UIDropDownMenu_Initialize(dd, function(self, level)
		local values = valueBuilder() or {}
		local info = UIDropDownMenu_CreateInfo()
		for key, label in pairs(values) do
			info.text = label
			info.value = key
			info.func = function()
				set(key)
				UIDropDownMenu_SetText(self, label)
				Refresh()
			end
			info.checked = get() == key
			UIDropDownMenu_AddButton(info, level)
		end
	end, "MENU")

	local widget = {
		refresh = function()
			local values = valueBuilder() or {}
			local current = get()
			UIDropDownMenu_SetText(dd, values[current] or tostring(current or ""))
		end,
		SetDisabled = function(_, disabled)
			dd:SetAlpha(disabled and 0.4 or 1)
		end,
	}
	widget.refresh()

	return Track(widget, disabledFn)
end

local swatchFunc
local function CreateColorButton(row, get, set, disabledFn)
	local swatch = CreateFrame("Button", nil, row)
	swatch:SetSize(24, 16)
	swatch:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	swatch:SetNormalTexture("Interface\\Buttons\\WHITE8X8")

	swatch:SetScript("OnClick", function()
		local r, g, b = get()
		swatchFunc = function()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			set(nr, ng, nb)
			swatch:GetNormalTexture():SetVertexColor(nr, ng, nb)
		end
		ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		ColorPickerFrame.func = swatchFunc
		ColorPickerFrame.cancelFunc = function()
			set(r, g, b)
			swatch:GetNormalTexture():SetVertexColor(r, g, b)
		end
		ColorPickerFrame:SetColorRGB(r, g, b)
		ColorPickerFrame:Show()
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

-- ---------------------------------------------------------------------------
-- Shared value builders
-- ---------------------------------------------------------------------------

local function FontValues()
	local LSM = EIB:GetLSM()
	if LSM then
		local list = LSM:List("font") or {}
		local result = {}
		for _, name in ipairs(list) do
			result[name] = name
		end
		return result
	end
	return {}
end

local outlineValues = {
	NONE = L["None"],
	OUTLINE = L["Outline"],
	THICKOUTLINE = L["Thick"],
	SHADOW = "Shadow",
	SHADOWOUTLINE = "Shadow Outline",
	SHADOWTHICKOUTLINE = "Shadow Thick",
	MONOCHROME = "Mono",
	MONOCHROMEOUTLINE = "Mono Outline",
	MONOCHROMETHICKOUTLINE = "Mono Thick",
}

local anchorValues = {
	TOPLEFT = L["TOPLEFT"],
	TOPRIGHT = L["TOPRIGHT"],
	BOTTOMLEFT = L["BOTTOMLEFT"],
	BOTTOMRIGHT = L["BOTTOMRIGHT"],
}

local function CustomListValues(listFn)
	return function()
		local result = {}
		for key, value in pairs(listFn()) do
			async.WithItemID(tonumber(value) or value, function(item)
				local name = item:GetItemName() or L["Unknown"]
				local tex = item:GetItemIcon()
				result[key] = GetIconString(tex, 14, 18) .. name
			end)
		end
		return result
	end
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local function NewLayout(parent)
	local layout = { y = -6 }

	function layout:Header(text)
		self.y = self.y - 8
		local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, self.y)
		fs:SetText(text)
		self.y = self.y - 32
	end

	function layout:Row(label, controlBuilder, height)
		height = height or 28
		local row = CreateFrame("Frame", nil, parent)
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, self.y)
		row:SetSize(parent:GetWidth() - 20, height)

		if label then
			local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			fs:SetPoint("LEFT", row, "LEFT", 4, 0)
			fs:SetPoint("RIGHT", row, "RIGHT", -180, 0)
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
		height = height or 60
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
		self.y = self.y - (height or 8)
	end

	return layout
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
			end,
			disabledFn
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
			end,
			disabledFn
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
			end,
			disabledFn
		)
	end)
end

local function BuildBarSection(layout, barID)
	local barDB = function()
		return GetDB()["bar" .. barID]
	end
	local masterDisabled = function()
		return not GetDB().enable
	end
	local fadeDisabled = function()
		return masterDisabled() or not barDB().mouseOver
	end

	layout:Header(L["Bar"] .. " " .. barID)

	layout:Row(L["Enable"], function(row)
		CreateCheckbox(
			row,
			function()
				return barDB().enable
			end,
			function(value)
				barDB().enable = value
				EIB:UpdateBar(barID)
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
				EIB:UpdateBar(barID)
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
				EIB.DB.ResetBar(barID)
				EIB:UpdateBar(barID)
				Refresh()
			end,
			masterDisabled
		)
	end)

	layout:Space()

	layout:Row(L["Mouse Over"], function(row)
		CreateCheckbox(
			row,
			function()
				return barDB().mouseOver
			end,
			function(value)
				barDB().mouseOver = value
				EIB:UpdateBar(barID)
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
				EIB:UpdateBar(barID)
			end,
			masterDisabled
		)
	end)

	layout:Row(L["Bar Backdrop"], function(row)
		CreateCheckbox(
			row,
			function()
				return barDB().backdrop
			end,
			function(value)
				barDB().backdrop = value
				EIB:UpdateBar(barID)
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
				EIB:UpdateBar(barID)
			end,
			masterDisabled
		)
	end)
	layout:Row(L["Backdrop Spacing"], function(row)
		CreateSlider(
			row,
			function()
				return barDB().backdropSpacing
			end,
			function(value)
				barDB().backdropSpacing = value
				EIB:UpdateBar(barID)
			end,
			1,
			30,
			1,
			0,
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
				EIB:UpdateBar(barID)
			end,
			1,
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
				EIB:UpdateBar(barID)
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
				EIB:UpdateBar(barID)
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
				EIB:UpdateBar(barID)
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
				EIB:UpdateBar(barID)
			end,
			1,
			12,
			1,
			0,
			masterDisabled
		)
	end)

	layout:Space()

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

	layout:Space()

	layout:Header(L["Counter"])
	BuildFontGroup(layout, function()
		return barDB().countFont
	end, masterDisabled)

	layout:Header(L["Key Binding"])
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

	layout:Row(L["Unlock"], function(row)
		CreateButton(row, L["Unlock"], function()
			EIB:ToggleMoveMode()
		end)
	end)
	layout:Row(L["Reset Positions"], function(row)
		CreateButton(row, L["Reset Positions"], function()
			EIB:ResetPosition()
		end)
	end)
end

-- ---------------------------------------------------------------------------
-- Panel construction
-- ---------------------------------------------------------------------------

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

	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 0)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(650)
	content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)

	local layout = NewLayout(content)

	layout:Header(L["Extra Items Bar"])
	layout:Text(L["Add a bar to contain quest items and usable equipment."])
	layout:Space()

	layout:Row(L["Enable"], function(row)
		CreateCheckbox(
			row,
			function()
				return GetDB().enable
			end,
			function(value)
				GetDB().enable = value
				EIB:ProfileUpdate()
			end
		)
	end)

	layout:Space()
	layout:Header(L["Custom Items"])
	layout:Row(L["New Item ID"], function(row)
		CreateEditBox(
			row,
			function()
				return ""
			end,
			function(value)
				local itemID = tonumber(value)
				if itemID and async.WithItemID(itemID) then
					tinsert(GetDB().customList, itemID)
					EIB:UpdateBars()
				else
					EIB:Print(L["The item ID is invalid."])
				end
			end,
			function()
				return not GetDB().enable
			end
		)
	end)
	layout:Row(L["List"], function(row)
		CreateDropdown(
			row,
			CustomListValues(function()
				return GetDB().customList
			end),
			function()
				return customListSelected1
			end,
			function(value)
				customListSelected1 = value
			end,
			function()
				return not GetDB().enable
			end
		)
	end)
	layout:Row(L["Delete"], function(row)
		CreateButton(
			row,
			L["Delete"],
			function()
				if customListSelected1 then
					tremove(GetDB().customList, customListSelected1)
					customListSelected1 = nil
					EIB:UpdateBars()
					Refresh()
				end
			end,
			function()
				return not GetDB().enable
			end
		)
	end)

	layout:Space()
	layout:Header(L["Blacklist"])
	layout:Row(L["New Item ID"], function(row)
		CreateEditBox(
			row,
			function()
				return ""
			end,
			function(value)
				local itemID = tonumber(value)
				if itemID and async.WithItemID(itemID) then
					GetDB().blackList[itemID] = true
					EIB:UpdateBars()
				else
					EIB:Print(L["The item ID is invalid."])
				end
			end,
			function()
				return not GetDB().enable
			end
		)
	end)
	layout:Row(L["List"], function(row)
		CreateDropdown(
			row,
			CustomListValues(function()
				return GetDB().blackList
			end),
			function()
				return customListSelected2
			end,
			function(value)
				customListSelected2 = value
			end,
			function()
				return not GetDB().enable
			end
		)
	end)
	layout:Row(L["Delete"], function(row)
		CreateButton(
			row,
			L["Delete"],
			function()
				if customListSelected2 then
					GetDB().blackList[customListSelected2] = nil
					customListSelected2 = nil
					EIB:UpdateBars()
					Refresh()
				end
			end,
			function()
				return not GetDB().enable
			end
		)
	end)
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
			end
		)
	end)

	for barID = 1, 5 do
		BuildBarSection(layout, barID)
	end

	BuildAbout(layout)

	content:SetHeight(math.abs(layout.y) + 20)
	scroll:SetScrollChild(content)

	panel:SetScript("OnShow", Refresh)

	if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
		local category = _G.Settings.RegisterCanvasLayoutCategory(panel, L["Extra Items Bar"])
		_G.Settings.RegisterAddOnCategory(category)
		self.optionsCategory = category
	elseif _G.InterfaceOptions_AddCategory then
		_G.InterfaceOptions_AddCategory(panel)
	end
end