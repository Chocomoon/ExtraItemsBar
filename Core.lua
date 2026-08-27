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
EIB.DefaultFont = "Montserrat"

EIB.TexCoords = { 0.08, 0.92, 0.08, 0.92 }

---Small helpers (replaces WindTools Functions that were only needed here)
function EIB:SetFont(text, db)
	if not text or not text.GetFont or not db then
		return
	end

	local fontName, fontHeight = text:GetFont()
	local font
	if db.name then
		local LSM = self:GetLSM()
		if LSM then
			font = LSM:Fetch("font", db.name)
		end
	end

	text:SetFont(font or fontName or STANDARD_TEXT_FONT, db.size or fontHeight or 12, db.style or "NONE")
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

-- Slash commands
SLASH_EXTRAITEMSBAR1 = "/extraitemsbar"
SLASH_EXTRAITEMSBAR2 = "/eib"

SlashCmdList["EXTRAITEMSBAR"] = function(input)
	input = strlower(strtrim(input))

	if input == "unlock" then
		EIB:ToggleMoveMode()
	elseif input == "reset" then
		EIB:ResetPosition()
	elseif input == "help" then
		EIB:PrintHelp()
	elseif input == "" then
		EIB:OpenOptions()
	else
		EIB:PrintHelp()
	end
end

function EIB:PrintHelp()
	EIB:Print(EIB.L["SLASH_OPEN"] or "/eib - open options")
	EIB:Print(EIB.L["SLASH_UNLOCK"] or "/eib unlock - toggle drag mode")
	EIB:Print(EIB.L["SLASH_RESET"] or "/eib reset - reset bar positions")
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

		EIB:Initialize()
		EIB:OpenOptionsLater()
	elseif event == "PLAYER_LOGIN" and not EIB.optionsPanel then
		EIB:RegisterOptionsPanel()
		-- All addons are loaded by now, so auto style detection is accurate.
		EIB:ApplyBarStyle()
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
