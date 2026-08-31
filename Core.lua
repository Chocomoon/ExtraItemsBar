-- Extra Items Bar - standalone extraction from ElvUI_WindTools (fang2hou)
-- Derived from Modules/Item/ExtraItemBar.lua. See NOTICE.txt for attribution.

local addonName, addon = ...

---@class ExtraItemsBar
local EIB = {
	name = addonName,
	version = C_AddOns.GetAddOnMetadata(addonName, "Version"),
}

EIB.L = {}
EIB.db = nil
EIB.dbDefault = {}

addon[1] = EIB

_G.ExtraItemsBar = EIB
_G.EIB = EIB

local _G = _G
local format = format
local pairs = pairs
local strlower = strlower
local tinsert = tinsert

local InCombatLockdown = InCombatLockdown

-- LSM optional support (resolved lazily)
EIB.LSM = nil

function EIB:GetLSM()
	if self.LSM then
		return self.LSM
	end

	local LSM
	if _G.LibStub then
		LSM = _G.LibStub("LibSharedMedia-3.0", true)
	end

	self.LSM = LSM or false
	return self.LSM
end

function EIB:GetItemDB()
	return EIB.db.profile.extraItemsBar
end

EIB.UseKeyDown = C_CVar.GetCVarBool("ActionButtonUseKeyDown")

-- Default font for new profiles: use LSM "Montserrat" if present, else game default
EIB.DefaultFont = "default"

EIB.TexCoords = { 0.08, 0.92, 0.08, 0.92 }

-- Valid font outline flags for FontInstance:SetFont; anything else is treated as "no outline"
local VALID_FONT_STYLES = {
	OUTLINE = true,
	THICKOUTLINE = true,
	MONOCHROME = true,
	SHADOW = true,
	SHADOWOUTLINE = true,
	MONOCHROMEOUTLINE = true,
	MONOCHROMETHICKOUTLINE = true,
	THICKMONOCHROME = true,
}

---Small helpers (replaces WindTools Functions that were only needed here)
function EIB:SetFont(text, db, atlas)
	if not text or not text.GetFont or not db then
		return
	end

	local fontName, fontHeight = text:GetFont()
	local font
	if db.name and db.name ~= "default" then
		local LSM = self:GetLSM()
		if LSM then
			font = LSM:Fetch("font", db.name)
		end
	elseif db.name == "default" then
		font = STANDARD_TEXT_FONT
	end

	local style = db.style
	if not (style and VALID_FONT_STYLES[style]) then
		style = nil
	end

	local size = db.size or fontHeight or 12
	local justifyHBefore = text.GetJustifyH and text:GetJustifyH()
	if atlas then
		-- Quality tier uses FontTemplate so ElvUI keeps its glyph font in sync;
		-- the atlas (star) icon size is baked into the text via CreateAtlasMarkup,
		-- not driven by the font size, so this only affects the glyph font.
		if text.FontTemplate then
			text:FontTemplate(font or fontName or STANDARD_TEXT_FONT, size, style)
		else
			text:SetFont(font or fontName or STANDARD_TEXT_FONT, size, style)
		end
	else
		-- Bind / count text: use native SetFont and never register into ElvUI's
		-- global font-update table, so ElvUI re-skinning cannot clobber it.
		text:SetFont(font or fontName or STANDARD_TEXT_FONT, size, style)
	end
	if text.SetJustifyH and text.GetJustifyH and justifyHBefore and justifyHBefore ~= text:GetJustifyH() then
		text:SetJustifyH(justifyHBefore)
	end
end

function EIB:SetFontColor(text, db)
	if not text or not text.GetFont or not db then
		return
	end

	text:SetTextColor(db.r, db.g, db.b, db.a)
end

---Run a callback out of combat, deferring to PLAYER_REGEN_ENABLED if needed.
---(replaces WindTools F.TaskManager:OutOfCombat)
function EIB:OutOfCombat(callback, ...)
	local args = { ... }
	if InCombatLockdown() then
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		frame:SetScript("OnEvent", function(self)
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			callback(unpack(args))
		end)
	else
		callback(unpack(args))
	end
end

-- Debug helpers

function EIB:DebugEnabled()
	return EIB.db and EIB.db.profile and EIB.db.profile.debug
end

function EIB:DebugPrint(...)
	if self:DebugEnabled() then
		print(format("|cff5385ed%s Debug|r:", EIB.name), ...)
	end
end

local function SerializeSaved(pos)
	if not pos then
		return "nil"
	end
	if pos.normalized then
		return format("{norm x=%.4f y=%.4f}", pos.xOfs or 0, pos.yOfs or 0)
	end
	return format("{%s %s->%s %.1f,%.1f}", pos.point or "?", pos.relativeTo or "?", pos.relativePoint or "?", pos.xOfs or 0, pos.yOfs or 0)
end

function EIB:SaveSnapshot()
	local posData = EIB.db.profile.position
	if not posData then
		return
	end
	local snap = {}
	for i = 1, 5 do
		local key = "WTExtraItemsBar" .. i .. "Mover"
		if posData[key] then
			snap[key] = posData[key]
		end
	end
	if next(snap) then
		EIB.db.profile.debugSnapshot = snap
	end
end

function EIB:DumpPositions(label)
	if not self:DebugEnabled() then
		return
	end

	local uw, uh = _G.UIParent:GetWidth(), _G.UIParent:GetHeight()
	local scale = _G.UIParent:GetEffectiveScale()
	self:DebugPrint(format("=== %s (v%s) ===", label, self.version or "?"))
	self:DebugPrint(format("UIParent: %dx%d (scale %.2f)", uw or 0, uh or 0, scale))

	-- Output pre-reload snapshot if available
	local snap = EIB.db.profile.debugSnapshot
	if snap then
		self:DebugPrint("--- before reload ---")
		for i = 1, 5 do
			local key = "WTExtraItemsBar" .. i .. "Mover"
			if snap[key] then
				self:DebugPrint(format("  saved[%s] = %s", key, SerializeSaved(snap[key])))
			end
		end
		EIB.db.profile.debugSnapshot = nil
	end

	-- Output current state
	self:DebugPrint("--- after reload ---")
	local posData = EIB.db.profile.position
	if posData then
		for i = 1, 5 do
			local key = "WTExtraItemsBar" .. i .. "Mover"
			if posData[key] then
				self:DebugPrint(format("  saved[%s] = %s", key, SerializeSaved(posData[key])))
			end
		end
	else
		self:DebugPrint("  position data: nil (no bars moved yet)")
	end

	for i = 1, 5 do
		local bar = self.bars and self.bars[i]
		if bar then
			local left, bottom = bar:GetLeft(), bar:GetBottom()
			local w, h = bar:GetWidth(), bar:GetHeight()
			local key = "WTExtraItemsBar" .. i .. "Mover"
			local saved = posData and posData[key]
			local path = self.Move and self.Move.appliedPaths and self.Move.appliedPaths[key] or "?"
			self:DebugPrint(format("  Bar%d: saved=%s path=%s actual=(%.1f,%.1f) size=(%.0fx%.0f)",
				i, SerializeSaved(saved), path, left or 0, bottom or 0, w, h))
		else
			self:DebugPrint(format("  Bar%d: (not created)", i))
		end
	end
end

-- Slash commands
SLASH_EXTRAITEMSBAR1 = "/extraitemsbar"
SLASH_EXTRAITEMSBAR2 = "/eib"

SlashCmdList["EXTRAITEMSBAR"] = function(input)
	input = strlower(strtrim(input))

	if input == "unlock" then
		EIB:ToggleMoveMode()
	elseif input == "reset" then
		EIB:ResetPosition()
	elseif input == "debug" then
		if not EIB.db or not EIB.db.profile then
			EIB:Print(EIB.L["DEBUG_DB_NOT_READY"])
			return
		end
		EIB.db.profile.debug = not EIB.db.profile.debug
		if EIB.db.profile.debug then
			EIB:Print(EIB.L["DEBUG_ENABLED"])
			EIB:SaveSnapshot()
		else
			EIB:Print(EIB.L["DEBUG_DISABLED"])
			EIB.db.profile.debugSnapshot = nil
		end
	elseif input == "dump" then
		EIB:DumpPositions("DUMP")
	elseif input == "help" then
		EIB:PrintHelp()
	elseif input == "" then
		EIB:OpenOptions()
	else
		EIB:PrintHelp()
	end
end

function EIB:PrintHelp()
	EIB:Print(EIB.L["SLASH_OPEN"])
	EIB:Print(EIB.L["SLASH_UNLOCK"])
	EIB:Print(EIB.L["SLASH_RESET"])
	EIB:Print(EIB.L["SLASH_DEBUG"])
	EIB:Print(EIB.L["SLASH_DUMP"])
end

function EIB:Print(...)
	print(format("|cff5385ed%s|r: %s", EIB.name, strjoin(" ", ...)))
end

-- SavedVariables load + addon initialization
EIB.eventFrame = CreateFrame("Frame", "ExtraItemsBarEventFrame")
EIB.eventFrame:RegisterEvent("ADDON_LOADED")
EIB.eventFrame:SetScript("OnEvent", function(_, event, addonLoaded)
	if event == "ADDON_LOADED" and addonLoaded == EIB.name then
		if not EIB_DB and XEB_DB then
			EIB_DB = XEB_DB
		end
		if not EIB_DB then
			EIB_DB = {}
		end

		EIB.db = EIB_DB
		if not EIB.db.profile then
			EIB.db.profile = {}
		end

		EIB:MergeDefaults(EIB.db.profile, EIB.dbDefault)

		-- One-time migration: the default button spacing was reduced from 3 to 2,
		-- so bring existing bars saved with the old default down to the new one.
		for _, bar in pairs(EIB:GetItemDB()) do
			if type(bar) == "table" and bar.spacing == 3 then
				bar.spacing = 2
			end
		end

		-- One-time migration: the default font was previously hardcoded to
		-- "Montserrat"; switch bars that still use it to the new "default"
		-- (game default font) sentinel.
		for _, bar in pairs(EIB:GetItemDB()) do
			if type(bar) == "table" then
				if bar.countFont and bar.countFont.name == "Montserrat" then
					bar.countFont.name = "default"
				end
				if bar.bindFont and bar.bindFont.name == "Montserrat" then
					bar.bindFont.name = "default"
				end
			end
		end

		EIB:Initialize()
		EIB:OpenOptionsLater()
	elseif event == "PLAYER_LOGIN" then
		if not EIB.optionsPanel then
			EIB:RegisterOptionsPanel()
			-- All addons are loaded by now, so auto style detection is accurate.
			EIB:ApplyBarStyle()
			-- Bindings are fully loaded by PLAYER_LOGIN; refresh keybind text so
			-- it is correct on the first frame (GetBindingKey may be empty at ADDON_LOADED).
			EIB:UpdateBinding()
		end
	end
end)
EIB.eventFrame:RegisterEvent("PLAYER_LOGIN")

function EIB:OpenOptionsLater()
	self:RegisterOptionsPanel()
end

function EIB:ToggleMoveMode()
	if not self.Move then
		return
	end

	self.Move:ToggleMoveMode()
end

function EIB:ResetPosition()
	if not self.Move then
		return
	end

	self.db.profile.debugSnapshot = nil
	self.Move:ResetPosition()
end

function EIB:OpenOptions()
	local panel = self.optionsPanel
	if not panel then
		return
	end

	if _G.Settings and _G.Settings.OpenToCategory and self.optionsCategory then
		_G.Settings.OpenToCategory(self.optionsCategory:GetID())
	elseif _G.InterfaceOptionsFrame_OpenToCategory then
		_G.InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

-- Defaults merging (simple recursive)
function EIB:MergeDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			self:MergeDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

function EIB:GetLocale()
	return GetLocale()
end

-- Hook for the ported module to call after options are registered
EIB.initialized = false
EIB.bars = {}
