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
---@param anchor Frame
---@param key string
---@param saved table
local function ApplySavedPosition(anchor, key, saved)
	local uw, uh = _G.UIParent:GetWidth(), _G.UIParent:GetHeight()

	if saved.normalized and uw and uh then
		anchor:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", saved.xOfs * uw, saved.yOfs * uh)
		return
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
	end
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

---Snap an anchor's desired bottom-left corner to nearby bar edges so bars can
---be aligned/stacked easily. Holding Ctrl temporarily disables snapping.
---@param anchor Frame
---@param x number
---@param y number
---@return number snappedX
---@return number snappedY
local function SnapXY(anchor, x, y)
	if IsControlKeyDown() then
		return x, y
	end

	local w, h = anchor:GetWidth(), anchor:GetHeight()
	if not w or not h or w <= 0 or h <= 0 then
		return x, y
	end

	local bestX, bestY, bestDX, bestDY = x, y, snapThreshold, snapThreshold
	for _, mover in pairs(EIB.Move.movers) do
		local other = mover.anchor
		if other and other ~= anchor then
			local ol, ob, oright, ot = other:GetLeft(), other:GetBottom(), other:GetRight(), other:GetTop()
			if ol and ob then
				local xs = { ol, oright, ol - w, oright - w }
				for i = 1, 4 do
					local dx = math.abs(xs[i] - x)
					if dx < bestDX then
						bestDX = dx
						bestX = xs[i]
					end
				end
				local ys = { ob, ot, ob - h, ot - h }
				for i = 1, 4 do
					local dy = math.abs(ys[i] - y)
					if dy < bestDY then
						bestDY = dy
						bestY = ys[i]
					end
				end
			end
		end
	end
	return bestX, bestY
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
	if saved then
		ApplySavedPosition(anchor, key, saved)
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
		if EIB.Move.dragAnchor then
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
	self.dragAnchor = nil
	for _, mover in pairs(self.movers) do
		if mover.handle then
			mover.handle:SetScript("OnUpdate", nil)
			mover.handle:Hide()
		end
	end
	self.movers = {}
end