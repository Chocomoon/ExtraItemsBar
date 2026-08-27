-- Extra Items Bar - core module.
-- Standalone extraction of the "Extra Items Bar" module from ElvUI_WindTools
-- (fang2hou). ElvUI/WindTools framework calls have been replaced with native
-- equivalents. See NOTICE.txt for attribution.

local EIB = _G.EIB ---@type ExtraItemsBar
local EB = EIB
local L = EIB.L

local async = EIB.Async

local _G = _G
local ceil = ceil
local format = format
local ipairs = ipairs
local pairs = pairs
local sort = sort
local strmatch = strmatch
local strsplit = strsplit
local tinsert = tinsert
local tonumber = tonumber
local unpack = unpack
local wipe = wipe

local CooldownFrame_Set = CooldownFrame_Set
local CreateAtlasMarkup = CreateAtlasMarkup
local CreateFrame = CreateFrame
local GameTooltip = _G.GameTooltip
local GetBindingKey = GetBindingKey
local GetInventoryItemCooldown = GetInventoryItemCooldown
local GetInventoryItemID = GetInventoryItemID
local GetQuestLogSpecialItemCooldown = GetQuestLogSpecialItemCooldown
local GetQuestLogSpecialItemInfo = GetQuestLogSpecialItemInfo
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver

local C_AddOns_IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local C_Item_GetItemCooldown = C_Item.GetItemCooldown
local C_Item_GetItemCount = C_Item.GetItemCount
local C_Item_GetItemInfoInstant = C_Item.GetItemInfoInstant
local C_Item_IsItemInRange = C_Item.IsItemInRange
local C_Item_IsUsableItem = C_Item.IsUsableItem
local C_Texture_GetAtlasInfo = C_Texture.GetAtlasInfo
local C_QuestLog_GetDistanceSqToQuest = C_QuestLog.GetDistanceSqToQuest
local C_QuestLog_GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries
local C_QuestLog_GetQuestIDForLogIndex = C_QuestLog.GetQuestIDForLogIndex
local C_Timer_After = C_Timer.After
local C_Timer_NewTicker = C_Timer.NewTicker
local C_TradeSkillUI_GetItemReagentQualityInfo = C_TradeSkillUI.GetItemReagentQualityInfo

local GRID_MASK_SCALE = 1

local gridAtlasInfo
local function GetGridAtlasInfo()
	if not gridAtlasInfo then
		local frame = C_Texture_GetAtlasInfo("UI-HUD-ActionBar-IconFrame")
		local mask = C_Texture_GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Mask")
		gridAtlasInfo = frame and mask and { frame = frame, mask = mask } or false
	end
	return gridAtlasInfo
end

local questItemList = {}
local function UpdateQuestItemList()
	wipe(questItemList)

	for questLogIndex = 1, C_QuestLog_GetNumQuestLogEntries() do
		local link = GetQuestLogSpecialItemInfo(questLogIndex)
		if link then
			local questID = C_QuestLog_GetQuestIDForLogIndex(questLogIndex)
			local distance = questID and C_QuestLog_GetDistanceSqToQuest(questID)
			local itemID = C_Item_GetItemInfoInstant(link)
			tinsert(questItemList, { questLogIndex = questLogIndex, itemID = itemID, distance = distance or 1e8 })
		end
	end

	sort(questItemList, function(a, b)
		return a.distance < b.distance
	end)
end

local forceUsableItems = {
	[193634] = true, -- 茂發種子
	[206448] = true, --『夢境裂斧』菲拉雷斯
}

local equipmentList = {}
local function UpdateEquipmentList()
	wipe(equipmentList)
	for slotID = 1, 18 do
		local itemID = GetInventoryItemID("player", slotID)
		if itemID and (C_Item_IsUsableItem(itemID) or forceUsableItems[itemID]) then
			tinsert(equipmentList, slotID)
		end
	end
end

local function ParseSlotFilter(slotStr)
	if not slotStr or slotStr == "" then
		return nil
	end

	local allowedSlots = {}

	if strmatch(slotStr, "^(%d+)-(%d+)$") then
		local startSlot, endSlot = strmatch(slotStr, "^(%d+)-(%d+)$")
		startSlot, endSlot = tonumber(startSlot), tonumber(endSlot)
		if startSlot and endSlot and startSlot <= endSlot then
			for slotID = startSlot, endSlot do
				if slotID >= 1 and slotID <= 18 then
					allowedSlots[slotID] = true
				end
			end
		end
	elseif strmatch(slotStr, "^%d+$") then
		local slotID = tonumber(slotStr)
		if slotID and slotID >= 1 and slotID <= 18 then
			allowedSlots[slotID] = true
		end
	end

	return allowedSlots
end

local UpdateAfterCombat = {
	[1] = false,
	[2] = false,
	[3] = false,
	[4] = false,
	[5] = false,
}

-- Replacements for E.UIFrameFadeIn/UIFrameFadeOut
local fadeFrames = {}
local function UIFrameFade(frame, time, startAlpha, endAlpha)
	if not frame then
		return
	end

	if fadeFrames[frame] then
		fadeFrames[frame]:SetScript("OnUpdate", nil)
		fadeFrames[frame] = nil
	end

	frame:SetAlpha(startAlpha)

	if not time or time <= 0 then
		frame:SetAlpha(endAlpha)
		return
	end

	local startTime = GetTime()
	fadeFrames[frame] = frame
	frame:SetScript("OnUpdate", function()
		local progress = (GetTime() - startTime) / time
		if progress >= 1 then
			frame:SetAlpha(endAlpha)
			frame:SetScript("OnUpdate", nil)
			fadeFrames[frame] = nil
		else
			frame:SetAlpha(startAlpha + (endAlpha - startAlpha) * progress)
		end
	end)
end

local function UIFrameFadeIn(frame, time, startAlpha, endAlpha)
	UIFrameFade(frame, time, startAlpha, endAlpha)
end

local function UIFrameFadeOut(frame, time, startAlpha, endAlpha)
	UIFrameFade(frame, time, startAlpha, endAlpha)
end

-- Replacement for E.ActionBars:FixKeybindText
local function FixKeybindText(key)
	if not key or key == "" then
		return ""
	end

	key = key:gsub("SHIFT%-", "S-")
	key = key:gsub("ALT%-", "A-")
	key = key:gsub("CTRL%-", "C-")
	key = key:gsub("MOUSEWHEELUP", "MWU")
	key = key:gsub("MOUSEWHEELDOWN", "MWD")
	key = key:gsub("BUTTON1", "LMB")
	key = key:gsub("BUTTON2", "RMB")
	key = key:gsub("BUTTON3", "MMB")
	key = key:gsub("BUTTON", "M")

	return key
end

function EB:GetBindingKeyText(key)
	local keybind = GetBindingKey(key)

	if not keybind or keybind == "" then
		return ""
	end

	return FixKeybindText(keybind)
end

-- ---------------------------------------------------------------------------
-- Bar styles
-- "grid" keeps the native action bar look, "flat" is a minimal style that
-- blends in with UIs that skin the action bars (ElvUI, NDui, EllesmereUI, ...).
-- ---------------------------------------------------------------------------

-- Known addons that replace/skin the native action bars.
EIB.SkinAddons = {
	"ElvUI",
	"EllesmereUI",
	"EllesmereUIActionBars",
	"NDui",
	"KkthnxUI",
	"ToxiUI",
}

local styleConfig = {
	grid = {
		button = {
			backdrop = {
				bgFile = "Interface\\Buttons\\WHITE8X8",
				tile = false,
				edgeSize = 0,
			},
			bgColor = { 0, 0, 0, 0 },
			borderColor = { 0.6, 0.6, 0.6, 1 },
			highlightColor = { 0.9, 0.9, 0.9, 0.25 },
			pushedColor = { 0, 0, 0, 0.6 },
		},
		bar = {
			backdrop = {
				bgFile = "Interface\\Buttons\\WHITE8X8",
				tile = false,
				edgeSize = 0,
			},
			bgColor = { 0, 0, 0, 0.8 },
			bgColorTransparent = { 0, 0, 0, 0 },
			borderColor = { 0.6, 0.6, 0.6, 1 },
		},
	},
	flat = {
		button = {
			backdrop = {
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				tile = false,
				edgeSize = 1,
				insets = { left = 1, right = 1, top = 1, bottom = 1 },
			},
			bgColor = { 0, 0, 0, 0.35 },
			borderColor = { 0, 0, 0, 1 },
			highlightColor = { 1, 1, 1, 0.15 },
			pushedColor = { 0, 0, 0, 0.5 },
		},
		bar = {
			backdrop = {
				bgFile = "Interface\\Buttons\\WHITE8X8",
				tile = false,
				edgeSize = 0,
			},
			bgColor = { 0, 0, 0, 0.8 },
			bgColorTransparent = { 0, 0, 0, 0 },
			borderColor = { 0, 0, 0, 1 },
		},
	},
}

---Resolve the effective bar style. "auto" keeps the native grid look when the
---action bars are untouched and switches to the flat style when a UI addon
---skins them; a manual "grid"/"flat" choice always wins.
function EIB:GetBarStyle()
	local style = self:GetItemDB().barStyle or "auto"
	if style ~= "auto" then
		return style
	end

	for i = 1, #EIB.SkinAddons do
		if C_AddOns_IsAddOnLoaded(EIB.SkinAddons[i]) then
			return "flat"
		end
	end

	return "grid"
end

-- Replacement for E.ActionBars:StyleButton
function EIB:StyleButton(button)
	local cfg = styleConfig[EIB:GetBarStyle()].button
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	local highlight = button:GetHighlightTexture()
	highlight:SetBlendMode("ADD")
	highlight:SetVertexColor(unpack(cfg.highlightColor))

	button:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
	local pushed = button:GetPushedTexture()
	pushed:SetVertexColor(unpack(cfg.pushedColor))
end

-- Apply the current bar style to an existing button backdrop without touching
-- the border color, which is driven by item data (see SetUpButton).
function EIB:StyleButtonBackdrop(button)
	local style = EIB:GetBarStyle()
	local cfg = styleConfig[style].button
	button:SetBackdrop(cfg.backdrop)
	button:SetBackdropColor(unpack(cfg.bgColor))

	local iconInset = style == "grid" and 2 or 1

	if style == "grid" then
		local info = GetGridAtlasInfo()
		local frame = button.frameTexture
		if not frame then
			frame = button:CreateTexture(nil, "OVERLAY", nil, 1)
			button.frameTexture = frame
		end
		if info then
			local scale = button:GetWidth() / 45
			frame:SetAtlas("UI-HUD-ActionBar-IconFrame")
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", button, "TOPLEFT")
			frame:SetSize(info.frame.width * scale, info.frame.height * scale)
			frame:Show()
		else
			frame:Hide()
		end
		EIB:ApplyIconMask(button)
	else
		if button.frameTexture then
			button.frameTexture:Hide()
		end
		EIB:ApplyIconMask(button)
	end

	if button.tex then
		button.tex:ClearAllPoints()
		button.tex:SetPoint("TOPLEFT", button, "TOPLEFT", iconInset, -iconInset)
		button.tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -iconInset, iconInset)
	end

	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetVertexColor(unpack(cfg.highlightColor))
	end

	local pushed = button:GetPushedTexture()
	if pushed then
		pushed:SetVertexColor(unpack(cfg.pushedColor))
	end
end

-- Round the icon corners of a grid button using the native IconFrame mask.
function EIB:ApplyIconMask(button)
	if not button.tex then
		return
	end

	if EIB:GetBarStyle() == "grid" then
		local info = GetGridAtlasInfo()
		if not info then
			return
		end
		if not button.iconMask then
			button.iconMask = button:CreateMaskTexture(nil, "OVERLAY", nil)
		end
		local scale = button:GetWidth() / 45 * GRID_MASK_SCALE
		local mask = button.iconMask
		mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
		mask:ClearAllPoints()
		mask:SetPoint("CENTER", button.tex, "CENTER")
		mask:SetSize(info.mask.width * scale, info.mask.height * scale)
		if not button.maskApplied then
			button.tex:AddMaskTexture(mask)
			button.maskApplied = true
		end
	elseif button.maskApplied then
		button.tex:RemoveMaskTexture(button.iconMask)
		button.maskApplied = false
	end
end

-- Apply the current bar style to a backdrop frame (bar or custom frame).
function EIB:StyleBackdrop(backdrop, style)
	local cfg = styleConfig[EIB:GetBarStyle()].bar
	backdrop:SetBackdrop(cfg.backdrop)
	backdrop:SetBackdropColor(unpack(style == "Transparent" and cfg.bgColorTransparent or cfg.bgColor))
	backdrop:SetBackdropBorderColor(unpack(cfg.borderColor))
end

-- Replacement for E:CreateBackdrop
function EIB:CreateBackdrop(frame, style)
	if frame.backdrop then
		return frame.backdrop
	end

	local backdrop = CreateFrame("Frame", frame:GetName() .. "Backdrop", frame, "BackdropTemplate")
	backdrop:SetAllPoints(frame)
	backdrop:SetFrameStrata("BACKGROUND")
	backdrop:SetFrameLevel(frame:GetFrameLevel() - 1)
	EIB:StyleBackdrop(backdrop, style)

	frame.backdrop = backdrop
	return backdrop
end

function EB:CreateButton(name, barDB)
	local button = CreateFrame("Button", name, _G.UIParent, "SecureActionButtonTemplate, BackdropTemplate") --[[@as Button]]
	button:SetSize(barDB.buttonWidth, barDB.buttonHeight)
	button:SetClampedToScreen(true)
	button:SetAttribute("type", "item")
	button:EnableMouse(true)
	button:RegisterForClicks(EIB.UseKeyDown and "AnyDown" or "AnyUp")

	EIB:StyleButtonBackdrop(button)
	button:SetBackdropBorderColor(unpack(styleConfig[EIB:GetBarStyle()].button.borderColor))

	local tex = button:CreateTexture(nil, "OVERLAY", nil)
	local iconInset = EIB:GetBarStyle() == "grid" and 2 or 1
	tex:SetPoint("TOPLEFT", button, "TOPLEFT", iconInset, -iconInset)
	tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -iconInset, iconInset)
	tex:SetTexCoord(EIB.TexCoords[1], EIB.TexCoords[2], EIB.TexCoords[3], EIB.TexCoords[4])

	local qualityTier = button:CreateFontString(nil, "OVERLAY")
	qualityTier:SetTextColor(1, 1, 1, 1)
	qualityTier:SetPoint("TOPLEFT", button, "TOPLEFT")
	qualityTier:SetJustifyH("CENTER")
	EIB:SetFont(qualityTier, {
		size = barDB.qualityTier.size,
		style = "OUTLINE",
	})

	local count = button:CreateFontString(nil, "OVERLAY")
	count:SetTextColor(1, 1, 1, 1)
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
	count:SetJustifyH("CENTER")
	EIB:SetFont(count, barDB.countFont)

	local bind = button:CreateFontString(nil, "OVERLAY")
	bind:SetTextColor(0.6, 0.6, 0.6)
	bind:SetPoint("TOPRIGHT", button, "TOPRIGHT")
	bind:SetJustifyH("CENTER")
	EIB:SetFont(bind, barDB.bindFont)

	local cooldown = CreateFrame("Cooldown", name .. "Cooldown", button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(button)

	button.tex = tex
	EIB:ApplyIconMask(button)
	button.qualityTier = qualityTier
	button.count = count
	button.bind = bind
	button.cooldown = cooldown

	button.SetTier = function(_, itemIDOrLink)
		local qualityInfo = C_TradeSkillUI_GetItemReagentQualityInfo(itemIDOrLink)

		if not qualityInfo or not qualityInfo.icon or qualityInfo.icon == "" then
			button.qualityTier:SetText("")
			button.qualityTier:Hide()
		else
			button.qualityTier:SetText(CreateAtlasMarkup(qualityInfo.icon))
			button.qualityTier:Show()
		end
	end

	EIB:StyleButton(button)

	return button
end

function EB:SetUpButton(button, itemData, slotID, waitGroup)
	button.itemName = nil
	button.itemID = nil
	button.spellName = nil
	button.slotID = nil
	button.countText = nil
	button.setupToken = (button.setupToken or 0) + 1
	local setupToken = button.setupToken

	if itemData then
		button.itemID = itemData.itemID
		button.countText = C_Item_GetItemCount(itemData.itemID, nil, true)
		button.questLogIndex = itemData.questLogIndex
		button:SetBackdropBorderColor(unpack(styleConfig[EIB:GetBarStyle()].button.borderColor))

		waitGroup.count = waitGroup.count + 1
		async.WithItemID(itemData.itemID, function(item)
			if not item or button.setupToken ~= setupToken then
				waitGroup.count = waitGroup.count - 1
				return
			end
			button.itemName = item:GetItemName()
			button.tex:SetTexture(item:GetItemIcon())
			button:SetTier(itemData.itemID)
			waitGroup.count = waitGroup.count - 1
		end)
	elseif slotID then
		button.slotID = slotID

		waitGroup.count = waitGroup.count + 1
		async.WithItemSlotID(slotID, function(item)
			if not item or button.setupToken ~= setupToken then
				waitGroup.count = waitGroup.count - 1
				return
			end
			button.itemName = item:GetItemName()
			button.tex:SetTexture(item:GetItemIcon())

			local color = item:GetItemQualityColor()

			if color then
				button:SetBackdropBorderColor(color.r, color.g, color.b)
			end

			button:SetTier(item:GetItemID())

			waitGroup.count = waitGroup.count - 1
		end)
	end

	-- Count
	if button.countText and button.countText > 1 then
		button.count:SetText(button.countText)
	else
		button.count:SetText()
	end

	-- OnUpdate
	local OnUpdateFunction
	if button.itemID then
		OnUpdateFunction = function(_)
			local start, duration, enable
			if button.questLogIndex and button.questLogIndex > 0 then
				start, duration, enable = GetQuestLogSpecialItemCooldown(button.questLogIndex)
			else
				start, duration, enable = C_Item_GetItemCooldown(button.itemID)
			end
			CooldownFrame_Set(button.cooldown, start, duration, enable)
			local now = GetTime()
			if not button.lastRangeCheck or now - button.lastRangeCheck > 0.3 then
				button.lastRangeCheck = now
				if duration and duration > 0 and enable and enable == 0 then
					button.tex:SetVertexColor(0.4, 0.4, 0.4)
				elseif not InCombatLockdown() and C_Item_IsItemInRange(button.itemID, "target") == false then
					button.tex:SetVertexColor(1, 0, 0)
				else
					button.tex:SetVertexColor(1, 1, 1)
				end
			end
		end
	elseif button.slotID then
		OnUpdateFunction = function(_)
			local start, duration, enable = GetInventoryItemCooldown("player", button.slotID)
			CooldownFrame_Set(button.cooldown, start, duration, enable)
		end
	end
	button:SetScript("OnUpdate", OnUpdateFunction)

	-- Tooltips
	button:SetScript("OnEnter", function(_)
		local bar = button:GetParent()
		local barDB = EB:GetItemDB()["bar" .. bar.id]
		if not bar or not barDB then
			return
		end

		if barDB.mouseOver then
			local alphaCurrent = bar:GetAlpha()
			UIFrameFadeIn(
				bar,
				barDB.fadeTime * (barDB.alphaMax - alphaCurrent) / (barDB.alphaMax - barDB.alphaMin),
				alphaCurrent,
				barDB.alphaMax
			)
		end

		if barDB.tooltip then
			GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT", 0, -2)
			GameTooltip:ClearLines()

			if button.slotID then
				GameTooltip:SetInventoryItem("player", button.slotID)
			else
				GameTooltip:SetItemByID(button.itemID)
			end

			GameTooltip:Show()
		end
	end)

	button:SetScript("OnLeave", function(_)
		local bar = button:GetParent()
		local barDB = EB:GetItemDB()["bar" .. bar.id]
		if not bar or not barDB then
			return
		end

		if barDB.mouseOver then
			local alphaCurrent = bar:GetAlpha()
			UIFrameFadeOut(
				bar,
				barDB.fadeTime * (alphaCurrent - barDB.alphaMin) / (barDB.alphaMax - barDB.alphaMin),
				alphaCurrent,
				barDB.alphaMin
			)
		end

		GameTooltip:Hide()
	end)

	-- Attributes
	if not InCombatLockdown() then
		button:Show()
		button:SetAttribute("type", "macro")

		local macroText
		if button.slotID then
			macroText = "/use " .. button.slotID
		elseif button.itemID then
			macroText = "/use item:" .. button.itemID
			if button.itemID == 172347 then
				macroText = macroText .. "\n/use 5"
			end
		end

		if macroText then
			button:SetAttribute("macrotext", macroText)
		end
	end
end

function EB:UpdateButtonSize(button, barDB)
	button:SetSize(barDB.buttonWidth, barDB.buttonHeight)
	local left, right, top, bottom = unpack(EIB.TexCoords)

	if barDB.buttonWidth > barDB.buttonHeight then
		local offset = (bottom - top) * (1 - barDB.buttonHeight / barDB.buttonWidth) / 2
		top = top + offset
		bottom = bottom - offset
	elseif barDB.buttonWidth < barDB.buttonHeight then
		local offset = (right - left) * (1 - barDB.buttonWidth / barDB.buttonHeight) / 2
		left = left + offset
		right = right - offset
	end

	button.tex:SetTexCoord(left, right, top, bottom)

	EIB:StyleButtonBackdrop(button)
end

function EB:PLAYER_REGEN_ENABLED()
	for i = 1, 5 do
		if UpdateAfterCombat[i] then
			self:UpdateBar(i)
			UpdateAfterCombat[i] = false
		end
	end
end

function EB:UpdateBarTextOnCombat(i)
	for k = 1, 12 do
		local button = self.bars[i].buttons[k]
		if button.itemID and button:IsShown() then
			button.countText = C_Item_GetItemCount(button.itemID, nil, true)
			if button.countText and button.countText > 1 then
				button.count:SetText(button.countText)
			else
				button.count:SetText()
			end
		end
	end
end

function EB:CreateBar(id)
	local barDB = self:GetItemDB()["bar" .. id]
	if not barDB then
		return
	end

	-- Calculate initial size from config (max buttons, buttonsPerRow, spacing)
	local spacing = barDB.spacing
	local maxButtons = barDB.numButtons
	local numRows = ceil(maxButtons / barDB.buttonsPerRow)
	local numCols = maxButtons > barDB.buttonsPerRow and barDB.buttonsPerRow or maxButtons
	local initWidth = numCols * barDB.buttonWidth + (numCols - 1) * spacing
	local initHeight = numRows * barDB.buttonHeight + (numRows - 1) * spacing

	-- Bar (also the mover frame)
	local bar = CreateFrame("Frame", "WTExtraItemsBar" .. id, _G.UIParent, "SecureHandlerStateTemplate")
	bar.id = id
	bar:SetClampedToScreen(true)
	bar:SetSize(initWidth, initHeight)
	EIB.Move:CreateMover(
		bar,
		"WTExtraItemsBar" .. id .. "Mover",
		L["Extra Items Bar"] .. " " .. id,
		"BOTTOMLEFT",
		_G.WorldFrame,
		"LEFT",
		5,
		(id - 1) * 45
	)

	EIB:CreateBackdrop(bar, "Transparent")
	bar:SetFrameStrata("LOW")

	-- Buttons
	bar.buttons = {}
	for i = 1, 12 do
		bar.buttons[i] = self:CreateButton(bar:GetName() .. "Button" .. i, barDB)
		bar.buttons[i]:SetParent(bar)
		if i == 1 then
			bar.buttons[i]:SetPoint("LEFT", bar, "LEFT", 5, 0)
		else
			bar.buttons[i]:SetPoint("LEFT", bar.buttons[i - 1], "RIGHT", 5, 0)
		end
	end

	bar:SetScript("OnEnter", function(_)
		if not barDB then
			return
		end

		if barDB.mouseOver and barDB.alphaMax and barDB.alphaMin then
			local alphaCurrent = bar:GetAlpha()
			UIFrameFadeIn(
				bar,
				barDB.fadeTime * (barDB.alphaMax - alphaCurrent) / (barDB.alphaMax - barDB.alphaMin),
				alphaCurrent,
				barDB.alphaMax
			)
		end
	end)

	bar:SetScript("OnLeave", function(_)
		if not barDB then
			return
		end

		if barDB.mouseOver and barDB.alphaMax and barDB.alphaMin then
			local alphaCurrent = bar:GetAlpha()
			UIFrameFadeOut(
				bar,
				barDB.fadeTime * (alphaCurrent - barDB.alphaMin) / (barDB.alphaMax - barDB.alphaMin),
				alphaCurrent,
				barDB.alphaMin
			)
		end
	end)

	self.bars[id] = bar
end

function EB:ValidateItem(itemID)
	if not itemID then
		return false
	end

	if self:GetItemDB().blackList[itemID] then
		return false
	end

	if self.StateCheckList[itemID] and not self:GetState(self.StateCheckList[itemID]) then
		return false
	end

	local count = C_Item_GetItemCount(itemID)
	local countThreshold = self.CountThreshold[itemID] or 1
	if not count or count < countThreshold then
		return false
	end

	return true
end

function EB:UpdateBar(id)
	local bar = self.bars[id]
	local barDB = self:GetItemDB()["bar" .. id]
	if not bar or not barDB then
		return
	end

	if bar.waitGroup and bar.waitGroup.ticker then
		bar.waitGroup.ticker:Cancel()
	end

	bar.waitGroup = { count = 0 }

	if InCombatLockdown() then
		self:UpdateBarTextOnCombat(id)
		UpdateAfterCombat[id] = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end

	if not self:GetItemDB().enable or not barDB.enable then
		for i = 1, #bar.buttons do
			bar.buttons[i]:Hide()
		end
		EIB.Move:RefreshMover(id)
		if bar.register then
			UnregisterStateDriver(bar, "visibility")
			bar.register = false
			bar.registeredVisibility = nil
		end
		bar:Hide()
		return
	end

	local buttonID = 1

	bar:Show()

	local function addNormalButton(itemID)
		if self:ValidateItem(itemID) and buttonID <= barDB.numButtons and buttonID <= #bar.buttons then
			self:SetUpButton(bar.buttons[buttonID], { itemID = itemID }, nil, bar.waitGroup)
			self:UpdateButtonSize(bar.buttons[buttonID], barDB)
			buttonID = buttonID + 1
		end
	end

	local function addSlotButton(slotID)
		local itemID = GetInventoryItemID("player", slotID)
		if self:ValidateItem(itemID) and buttonID <= barDB.numButtons and buttonID <= #bar.buttons then
			self:SetUpButton(bar.buttons[buttonID], nil, slotID, bar.waitGroup)
			self:UpdateButtonSize(bar.buttons[buttonID], barDB)
			buttonID = buttonID + 1
		end
	end

	local function addNormalButtons(list)
		for _, itemID in pairs(list) do
			addNormalButton(itemID)
		end
	end

	for _, module in ipairs({ strsplit("[, ]", barDB.include) }) do
		if buttonID <= barDB.numButtons then
			if self.ModuleList[module] then
				addNormalButtons(self.ModuleList[module])
			elseif module == "QUEST" then -- Quest Items
				for _, data in ipairs(questItemList) do
					addNormalButton(data.itemID)
				end
			elseif module == "EQUIP" then -- Equipments
				for _, slotID in pairs(equipmentList) do
					addSlotButton(slotID)
				end
			elseif strmatch(module, "^SLOT:") then -- Equipments filtered by slot ID
				local slotFilter = strmatch(module, "^SLOT:(.+)$")
				local allowedSlots = ParseSlotFilter(slotFilter)
				if allowedSlots then
					for _, slotID in pairs(equipmentList) do
						if allowedSlots[slotID] then
							addSlotButton(slotID)
						end
					end
				end
			elseif module == "CUSTOM" then -- Custom Items
				addNormalButtons(self:GetItemDB().customList)
			end
		end
	end

	local spacing = barDB.spacing

	-- Fixed bar size based on max buttons (numButtons), not actual button count
	local maxButtons = barDB.numButtons
	local numRows = ceil(maxButtons / barDB.buttonsPerRow)
	local numCols = maxButtons > barDB.buttonsPerRow and barDB.buttonsPerRow or maxButtons
	local newBarWidth = numCols * barDB.buttonWidth + (numCols - 1) * spacing
	local newBarHeight = numRows * barDB.buttonHeight + (numRows - 1) * spacing
	bar:SetSize(newBarWidth, newBarHeight)
	EIB.Move:RefreshMover(id)

	-- Hide buttons not in use
	if buttonID == 1 then
		for hideButtonID = 1, 12 do
			bar.buttons[hideButtonID]:Hide()
		end
	else
		if buttonID <= 12 then
			for hideButtonID = buttonID, 12 do
				bar.buttons[hideButtonID]:Hide()
			end
		end
	end

	for i = 1, buttonID - 1 do
		-- Reposition icons
		local anchor = barDB.anchor
		local button = bar.buttons[i]

		button:ClearAllPoints()

		if i == 1 then
			if anchor == "TOPLEFT" then
				button:SetPoint(anchor, bar, anchor, 0, 0)
			elseif anchor == "TOPRIGHT" then
				button:SetPoint(anchor, bar, anchor, 0, 0)
			elseif anchor == "BOTTOMLEFT" then
				button:SetPoint(anchor, bar, anchor, 0, 0)
			elseif anchor == "BOTTOMRIGHT" then
				button:SetPoint(anchor, bar, anchor, 0, 0)
			end
		elseif i <= barDB.buttonsPerRow then
			local nearest = bar.buttons[i - 1]
			if anchor == "TOPLEFT" or anchor == "BOTTOMLEFT" then
				button:SetPoint("LEFT", nearest, "RIGHT", spacing, 0)
			else
				button:SetPoint("RIGHT", nearest, "LEFT", -spacing, 0)
			end
		else
			local nearest = bar.buttons[i - barDB.buttonsPerRow]
			if anchor == "TOPLEFT" or anchor == "TOPRIGHT" then
				button:SetPoint("TOP", nearest, "BOTTOM", 0, -spacing)
			else
				button:SetPoint("BOTTOM", nearest, "TOP", 0, spacing)
			end
		end

		EIB:SetFont(button.qualityTier, {
			size = barDB.qualityTier.size,
			style = "OUTLINE",
		})

		EIB:SetFont(button.count, barDB.countFont)
		EIB:SetFont(button.bind, barDB.bindFont)

		EIB:SetFontColor(button.count, barDB.countFont.color)
		EIB:SetFontColor(button.bind, barDB.bindFont.color)

		button.qualityTier:ClearAllPoints()
		button.qualityTier:SetPoint("TOPLEFT", button, "TOPLEFT", barDB.qualityTier.xOffset, barDB.qualityTier.yOffset)

		button.count:ClearAllPoints()
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", barDB.countFont.xOffset, barDB.countFont.yOffset)

		button.bind:ClearAllPoints()
		button.bind:SetPoint("TOPRIGHT", button, "TOPRIGHT", barDB.bindFont.xOffset, barDB.bindFont.yOffset)
	end

	if bar.registeredVisibility ~= barDB.visibility and bar.register then
		UnregisterStateDriver(bar, "visibility")
		bar.register = false
		bar.registeredVisibility = nil
	end

	if not bar.register then
		RegisterStateDriver(bar, "visibility", barDB.visibility)
		bar.register = true
		bar.registeredVisibility = barDB.visibility
	end

	-- Toggle backdrop
	if barDB.backdrop then
		bar.backdrop:Show()
	else
		bar.backdrop:Hide()
	end

	bar.waitGroup.ticker = C_Timer_NewTicker(0.1, function()
		if bar.waitGroup.count == 0 then
			if bar.waitGroup.ticker then
				bar.waitGroup.ticker:Cancel()
			end
			bar.alphaMin = barDB.alphaMin
			bar.alphaMax = barDB.alphaMax

			bar:SetAlpha(barDB.mouseOver and barDB.alphaMin or barDB.alphaMax)

			bar.waitGroup = nil
		end
	end)
end

function EB:UpdateBars()
	self:UpdateState(EB.STATE.IN_DELVE)
	for i = 1, 5 do
		self:UpdateBar(i)
	end
end

-- Coalesce chatty event-driven rebuilds (bag/zone changes fire in bursts)
-- into a single UpdateBars pass per ~0.15s window.
function EB:ScheduleUpdateBars()
	if self.updatePending then
		return
	end
	self.updatePending = true
	C_Timer_After(0.15, function()
		self.updatePending = false
		self:UpdateBars()
	end)
end

do
	local lastUpdateTime = 0
	function EB:UNIT_INVENTORY_CHANGED()
		local now = GetTime()
		if now - lastUpdateTime < 0.25 then
			return
		end
		lastUpdateTime = now
		UpdateQuestItemList()
		UpdateEquipmentList()

		self:UpdateBars()
	end
end

function EB:UpdateQuestItem()
	UpdateQuestItemList()
	self:UpdateBars()
end

function EB:UpdateEquipmentItem()
	UpdateEquipmentList()
	self:UpdateBars()
end

do
	local InUpdating = false
	function EB:ITEM_LOCKED()
		if InUpdating then
			return
		end

		InUpdating = true
		C_Timer_After(1, function()
			UpdateEquipmentList()
			self:UpdateBars()
			InUpdating = false
		end)
	end
end

function EB:CreateAll()
	self.bars = {}

	for i = 1, 5 do
		self:CreateBar(i)
	end
end

function EB:ApplyBarStyle()
	if not self.bars then
		return
	end

	for i = 1, 5 do
		local bar = self.bars[i]
		if bar then
			if bar.backdrop then
				EIB:StyleBackdrop(bar.backdrop, "Transparent")
			end

			for j = 1, 12 do
				local button = bar.buttons[j]
				if button then
					EIB:StyleButtonBackdrop(button)
				end
			end
		end
	end

	if self.initialized then
		self:UpdateBars()
	end
end

function EB:UpdateBinding()
	if not self.bars or not self.bars[1] then
		return
	end

	for i = 1, 5 do
		for j = 1, 12 do
			local button = self.bars[i].buttons[j]
			if button then
				local bindingName = format("CLICK WTExtraItemsBar%dButton%d:LeftButton", i, j)
				button.bind:SetText(self:GetBindingKeyText(bindingName))
			end
		end
	end
end

function EB:Initialize()
	if not self:GetItemDB().enable or self.initialized then
		return
	end

	if not self.bars or not self.bars[1] then
		self:CreateAll()
	end
	UpdateQuestItemList()
	UpdateEquipmentList()
	self:UpdateState(EB.STATE.QUANTUM_ITEM_ALLOWED)
	self:UpdateBars()
	self:UpdateBinding()

	self:RegisterEvent("BAG_UPDATE_DELAYED", "ScheduleUpdateBars")
	self:RegisterEvent("ITEM_LOCKED")
	self:RegisterEvent("PLAYER_ALIVE", "ScheduleUpdateBars")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "UpdateEquipmentItem")
	self:RegisterEvent("PLAYER_UNGHOST", "ScheduleUpdateBars")
	self:RegisterEvent("QUEST_ACCEPTED", "UpdateQuestItem")
	self:RegisterEvent("QUEST_LOG_UPDATE", "UpdateQuestItem")
	self:RegisterEvent("QUEST_TURNED_IN", "UpdateQuestItem")
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", "UpdateQuestItem")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("UPDATE_BINDINGS", "UpdateBinding")
	self:RegisterEvent("ZONE_CHANGED", "ScheduleUpdateBars")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ScheduleUpdateBars")

	self.initialized = true
end

function EB:ProfileUpdate()
	self:Initialize()

	if self:GetItemDB().enable then
		UpdateQuestItemList()
		UpdateEquipmentList()
		self:UpdateState(EB.STATE.QUANTUM_ITEM_ALLOWED)
	elseif self.initialized then
		self:UnregisterEvent("BAG_UPDATE_DELAYED")
		self:UnregisterEvent("PLAYER_ALIVE")
		self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
		self:UnregisterEvent("PLAYER_UNGHOST")
		self:UnregisterEvent("QUEST_ACCEPTED")
		self:UnregisterEvent("QUEST_LOG_UPDATE")
		self:UnregisterEvent("QUEST_TURNED_IN")
		self:UnregisterEvent("QUEST_WATCH_LIST_CHANGED")
		self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
		self:UnregisterEvent("UPDATE_BINDINGS")
		self:UnregisterEvent("ZONE_CHANGED")
		self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
		self.initialized = false
	end

	self:UpdateBars()
end

EIB.Initialize = EB.Initialize
EIB.ProfileUpdate = EB.ProfileUpdate
EIB.ApplyBarStyle = EB.ApplyBarStyle