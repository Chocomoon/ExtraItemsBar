-- Extra Items Bar - self-implemented drag & unlock mover system.
-- Replaces ElvUI's E:CreateMover. Positions are saved to EIB_DB (per character).
-- See NOTICE.txt for attribution.

local EIB = _G.EIB

local _G = _G
local pairs = pairs
local tinsert = tinsert
local tremove = tremove

local CreateFrame = CreateFrame

EIB.Move = {}
EIB.Move.movers = {}
EIB.Move.moveMode = false

local function GetSavedPosition(key)
	local position = EIB.db and EIB.db.profile.position
	return position and position[key] or nil
end

---Create a draggable mover for an anchor frame.
---@param anchor Frame the frame to be made draggable
---@param key string unique key for saving position
---@param text string display text on the mover handle
---@param defaultPoint string
---@param relativeTo Frame
---@param relativePoint string
---@param xOfs number
---@param yOfs number
function EIB.Move:CreateMover(anchor, key, text, defaultPoint, relativeTo, relativePoint, xOfs, yOfs)
	local saved = GetSavedPosition(key)

	anchor:SetMovable(true)
	anchor:ClearAllPoints()
	if saved then
		local relative = saved.relativeTo and _G[saved.relativeTo] or _G.UIParent
		anchor:SetPoint(saved.point, relative, saved.relativePoint, saved.xOfs, saved.yOfs)
	else
		anchor:SetPoint(defaultPoint, relativeTo or _G.UIParent, relativePoint or defaultPoint, xOfs or 0, yOfs or 0)
	end

	-- Transparent drag handle shown on top only in move mode
	local handle = CreateFrame("Button", key .. "Handle", anchor, "BackdropTemplate")
	handle:SetAllPoints(anchor)
	handle:SetFrameStrata("TOOLTIP")
	handle:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
		bgColor = { 0.1, 0.1, 0.1, 0.5 },
		edgeColor = { 1, 1, 0, 0.9 },
	})
	handle:EnableMouse(false)
	handle:SetScript("OnMouseDown", function()
		anchor:StartMoving()
	end)
	handle:SetScript("OnMouseUp", function()
		anchor:StopMovingOrSizing()
		local point, relativeTo, relativePoint, xOfs, yOfs = anchor:GetPoint()
		local position = EIB.db.profile.position or {}
		EIB.db.profile.position = position
		position[key] = {
			point = point,
			relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
			relativePoint = relativePoint,
			xOfs = xOfs,
			yOfs = yOfs,
		}
	end)

	if not handle.text then
		local textLabel = handle:CreateFontString(nil, "OVERLAY")
		textLabel:SetFontObject(_G.GameFontNormal)
		textLabel:SetPoint("CENTER", handle, "CENTER", 0, 0)
		textLabel:SetText(text)
		textLabel:SetTextColor(1, 1, 0)
		handle.text = textLabel
	else
		handle.text:SetText(text)
	end

	handle.anchor = anchor
	handle:Hide()

	local defaults = {
		defaultPoint = defaultPoint,
		relativeTo = relativeTo,
		relativePoint = relativePoint,
		xOfs = xOfs,
		yOfs = yOfs,
	}

	-- Replace any existing mover with the same key (re-creation on re-enable)
	for index, existing in pairs(self.movers) do
		if existing.key == key then
			existing.handle:SetParent(anchor)
			existing.handle:SetAllPoints(anchor)
			existing.anchor = anchor
			existing.defaults = defaults
			tinsert(self.movers, tremove(self.movers, index))
			if self.moveMode then
				handle:EnableMouse(true)
				handle:Show()
			else
				handle:EnableMouse(false)
				handle:Hide()
			end
			return anchor
		end
	end

	tinsert(self.movers, { key = key, anchor = anchor, handle = handle, defaults = defaults })

	if self.moveMode then
		handle:EnableMouse(true)
		handle:Show()
	end

	return anchor
end

---Toggle drag mode for all movers.
function EIB.Move:ToggleMoveMode()
	self.moveMode = not self.moveMode

	for _, mover in pairs(self.movers) do
		if self.moveMode then
			mover.handle:EnableMouse(true)
			mover.handle:Show()
		else
			mover.handle:EnableMouse(false)
			mover.handle:Hide()
		end
	end

	EIB:Print(self.moveMode and "Drag mode enabled. Drag the yellow frames and click again to lock." or "Drag mode disabled.")
end

---Reset all saved mover positions back to their defaults.
function EIB.Move:ResetPosition()
	if EIB.db.profile.position then
		EIB.db.profile.position = nil
	end

	for _, mover in pairs(self.movers) do
		local defaults = mover.defaults
		if mover.anchor then
			mover.anchor:ClearAllPoints()
			if defaults then
				mover.anchor:SetPoint(
					defaults.defaultPoint,
					defaults.relativeTo or _G.UIParent,
					defaults.relativePoint or defaults.defaultPoint,
					defaults.xOfs or 0,
					defaults.yOfs or 0
				)
			else
				mover.anchor:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
			end
		end
	end

	EIB:Print("Positions reset.")
end

---Remove all movers (cleanup on profile disable).
function EIB.Move:RemoveAll()
	for _, mover in pairs(self.movers) do
		if mover.handle then
			mover.handle:Hide()
		end
	end
	self.movers = {}
end