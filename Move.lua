-- Extra Items Bar - self-implemented drag & unlock mover system.
-- Replaces ElvUI's E:CreateMover. Positions are saved to EIB_DB (account-wide, shared by all characters).
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
EIB.Move.dragAnchor = nil
EIB.Move.grabX = 0
EIB.Move.grabY = 0
EIB.Move.appliedPaths = {} -- track which path each bar used: NORMALIZED / LEGACY / LEGACY_MIGRATED / DEFAULT

local function GetSavedPosition(key)
	local position = EIB.db and EIB.db.profile.position
	return position and position[key] or nil
end

---Measure an anchor frame's current position as normalized UIParent fractions.
---The fractions are resolution/UI-scale independent, so the same saved layout
---renders consistently across characters. Returns nil if the frame or UIParent
---is not ready to be measured.
---@param anchor Frame
---@return table|nil
local function NormalizeSavedPosition(anchor)
	local uw, uh = _G.UIParent:GetWidth(), _G.UIParent:GetHeight()
	local left, bottom = anchor:GetLeft(), anchor:GetBottom()
	if not uw or not uh or uw <= 0 or uh <= 0 or not left or not bottom then
		return nil
	end
	return {
		point = "BOTTOMLEFT",
		relativeTo = "UIParent",
		relativePoint = "BOTTOMLEFT",
		xOfs = left / uw,
		yOfs = bottom / uh,
		normalized = true,
	}
end

---Apply a saved position to an anchor frame. New entries are stored as
---normalized UIParent fractions; legacy entries are kept as-is visually but
---converted to the normalized format and written back (auto migration).
---Returns a string indicating which code path was taken (for debug logging).
---@param anchor Frame
---@param key string
---@param saved table
---@return string path
local function ApplySavedPosition(anchor, key, saved)
	local uw, uh = _G.UIParent:GetWidth(), _G.UIParent:GetHeight()

	if saved.normalized and uw and uh and uw > 0 and uh > 0 then
		anchor:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", saved.xOfs * uw, saved.yOfs * uh)
		return "NORMALIZED"
	end

	local relative = saved.relativeTo and _G[saved.relativeTo] or _G.UIParent
	anchor:SetPoint(saved.point, relative, saved.relativePoint, saved.xOfs, saved.yOfs)

	local normalized = NormalizeSavedPosition(anchor)
	if normalized then
		local position = EIB.db.profile.position or {}
		EIB.db.profile.position = position
		position[key] = normalized
		anchor:ClearAllPoints()
		anchor:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", normalized.xOfs * uw, normalized.yOfs * uh)
		return "LEGACY_MIGRATED"
	end

	return "LEGACY"
end

local snapThreshold = 10

---Cursor position in UI units relative to UIParent's bottom-left corner.
---@return number x
---@return number y
local function GetCursorUIPosition()
	local scale = _G.UIParent:GetEffectiveScale()
	local x, y = GetCursorPosition()
	return x / scale, y / scale
end

---Snap an anchor's desired bottom-left corner to nearby visible bar edges so
---bars can be aligned/stacked easily. Snapping uses each mover's actual bar
---frame (anchor.bar) rather than the anchor, so the snap gap is measured
---between visible bars even when the anchor area is larger than the bar.
---The gap applied for side-by-side/stacked placements comes from the dragged
---bar's snapSpacing (falls back to its button spacing). Holding Ctrl
---temporarily disables snapping.
---@param anchor Frame
---@param x number
---@param y number
---@return number snappedX
---@return number snappedY
local function SnapXY(anchor, x, y)
	if IsControlKeyDown() then
		return x, y
	end

	local bar = anchor.bar or anchor
	local w, h = bar:GetWidth(), bar:GetHeight()
	if not w or not h or w <= 0 or h <= 0 then
		return x, y
	end

	local barDB = bar.id and EIB:GetItemDB()["bar" .. bar.id]
	local gap = barDB and (barDB.snapSpacing or barDB.spacing) or 0

	-- The bar's fixed offset within its anchor (constant while dragging)
	local bx = (bar:GetLeft() or 0) - (anchor:GetLeft() or 0)
	local by = (bar:GetBottom() or 0) - (anchor:GetBottom() or 0)

	local ownLeft = x + bx
	local ownBottom = y + by

	local bestX, bestY, bestDX, bestDY = ownLeft, ownBottom, snapThreshold, snapThreshold
	for _, mover in pairs(EIB.Move.movers) do
		local other = mover.anchor
		local otherBar = other and (other.bar or other)
		if otherBar and otherBar ~= bar then
			local ol, ob, oright, ot = otherBar:GetLeft(), otherBar:GetBottom(), otherBar:GetRight(), otherBar:GetTop()
			if ol and ob then
				local xs = { ol, oright + gap, ol - w - gap, oright - w }
				for i = 1, 4 do
					local dx = math.abs(xs[i] - ownLeft)
					if dx < bestDX then
						bestDX = dx
						bestX = xs[i]
					end
				end
				local ys = { ob, ot + gap, ob - h - gap, ot - h }
				for i = 1, 4 do
					local dy = math.abs(ys[i] - ownBottom)
					if dy < bestDY then
						bestDY = dy
						bestY = ys[i]
					end
				end
			end
		end
	end
	return bestX - bx, bestY - by
end

---Per-frame drag update: move the anchor to the cursor and snap to nearby bars.
local function DragUpdate()
	local anchor = EIB.Move.dragAnchor
	if not anchor then
		return
	end
	local cx, cy = GetCursorUIPosition()
	local x, y = SnapXY(anchor, cx - EIB.Move.grabX, cy - EIB.Move.grabY)
	anchor:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", x, y)
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
	local path
	if saved then
		path = ApplySavedPosition(anchor, key, saved)
	else
		anchor:SetPoint(defaultPoint, relativeTo or _G.UIParent, relativePoint or defaultPoint, xOfs or 0, yOfs or 0)
		path = "DEFAULT"
	end

	self.appliedPaths[key] = path

	-- Transparent drag handle shown on top only in move mode
	-- Handle frame is 16px larger than anchor (8px each side) so that
	-- its edgeSize=16 backdrop border inner edge aligns with anchor edges.
	local handle = CreateFrame("Button", key .. "Handle", UIParent, "BackdropTemplate")
	handle:ClearAllPoints()
	handle:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
	handle:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2, -2)
	handle:SetFrameStrata("TOOLTIP")
	handle:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
		edgeColor = { 1, 1, 0, 0.9 },
	})
	handle:EnableMouse(false)
	handle:SetScript("OnMouseDown", function()
		if EIB.Move.dragAnchor or InCombatLockdown() then
			return
		end
		local cx, cy = GetCursorUIPosition()
		EIB.Move.grabX = cx - (anchor:GetLeft() or 0)
		EIB.Move.grabY = cy - (anchor:GetBottom() or 0)
		EIB.Move.dragAnchor = anchor
		handle:SetScript("OnUpdate", DragUpdate)
	end)
	handle:SetScript("OnMouseUp", function()
		if EIB.Move.dragAnchor ~= anchor then
			return
		end
		EIB.Move.dragAnchor = nil
		handle:SetScript("OnUpdate", nil)
		local saved = NormalizeSavedPosition(anchor)
		if not saved then
			local point, relativeTo, relativePoint, xOfs, yOfs = anchor:GetPoint()
			saved = {
				point = point,
				relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
				relativePoint = relativePoint,
				xOfs = xOfs,
				yOfs = yOfs,
			}
		end
		local position = EIB.db.profile.position or {}
		EIB.db.profile.position = position
		position[key] = saved
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
			existing.handle:ClearAllPoints()
			existing.handle:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
			existing.handle:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2, -2)
			existing.anchor = anchor
			existing.defaults = defaults
			tinsert(self.movers, tremove(self.movers, index))
			-- Clean up the unused new handle (existing handle is reused instead)
			handle:Hide()
			handle:SetScript("OnUpdate", nil)
			handle:SetScript("OnMouseDown", nil)
			handle:SetScript("OnMouseUp", nil)
			if self.moveMode then
				existing.handle:EnableMouse(true)
				existing.handle:Show()
			else
				existing.handle:EnableMouse(false)
				existing.handle:Hide()
			end
			return anchor
		end
	end

	tinsert(self.movers, { key = key, anchor = anchor, handle = handle, defaults = defaults })

	-- Deferred application: if UIParent is not yet ready, re-apply on PLAYER_ENTERING_WORLD
	if saved and saved.normalized then
		local uw, uh = _G.UIParent:GetWidth(), _G.UIParent:GetHeight()
		if not uw or not uh or uw <= 0 or uh <= 0 then
			local frame = CreateFrame("Frame")
			frame:RegisterEvent("PLAYER_ENTERING_WORLD")
			frame:SetScript("OnEvent", function(self)
				self:UnregisterEvent("PLAYER_ENTERING_WORLD")
				self:SetScript("OnEvent", nil)
				local s = GetSavedPosition(key)
				if s then
					ApplySavedPosition(anchor, key, s)
				end
			end)
		end
	end

	if self.moveMode then
		handle:EnableMouse(true)
		handle:Show()
	end

	return anchor
end

---Toggle drag mode for all movers.
function EIB.Move:ToggleMoveMode()
	self.moveMode = not self.moveMode

	if self.moveMode then
		for _, mover in pairs(self.movers) do
			local id = tonumber((mover.key or ""):match("WTExtraItemsBar(%d+)Mover"))
			if id then
				self:RefreshMover(id)
			end
			mover.handle:EnableMouse(true)
			mover.handle:Show()
		end
	else
		for _, mover in pairs(self.movers) do
			mover.handle:EnableMouse(false)
			mover.handle:Hide()
		end
	end

	EIB:Print(self.moveMode and (EIB.L["DRAG_MODE_ENABLED"] or "Drag mode enabled.") or (EIB.L["DRAG_MODE_DISABLED"] or "Drag mode disabled."))
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

	EIB:Print(EIB.L["POSITIONS_RESET"] or "Positions reset.")
end

---Refresh a mover's drag handle to match its anchor's current size.
---@param id number bar ID
function EIB.Move:RefreshMover(id)
	local key = "WTExtraItemsBar" .. id .. "Mover"
	for _, mover in pairs(self.movers) do
		if mover.key == key then
			local anchor = mover.anchor
			mover.handle:ClearAllPoints()
			mover.handle:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
			mover.handle:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2, -2)
			return
		end
	end
end

---Remove all movers (cleanup on profile disable).
function EIB.Move:RemoveAll()
	self.dragAnchor = nil
	for _, mover in pairs(self.movers) do
		if mover.handle then
			mover.handle:SetScript("OnUpdate", nil)
			mover.handle:Hide()
		end
	end
	self.movers = {}
end