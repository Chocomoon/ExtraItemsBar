-- Extra Items Bar - profile defaults & SavedVariables.
-- Defaults ported from ElvUI_WindTools Settings/Profile.lua (fang2hou).
-- See NOTICE.txt for attribution.

local EIB = _G.EIB

local function fontDB()
	return {
		name = EIB.DefaultFont,
		size = 12,
		style = "OUTLINE",
		xOffset = 0,
		yOffset = 0,
		color = { r = 1, g = 1, b = 1 },
	}
end

local function barDefaults()
	return {
		enable = true,
		mouseOver = false,
		globalFade = false,
		visibility = "[petbattle]hide;show",
		fadeTime = 0.3,
		alphaMin = 0,
		alphaMax = 1,
		numButtons = 12,
		backdrop = true,
		buttonWidth = 30,
		buttonHeight = 30,
		buttonsPerRow = 12,
		anchor = "TOPLEFT",
		spacing = 2,
		snapSpacing = 2,
		tooltip = true,
		qualityTier = {
			size = 14,
			xOffset = 0,
			yOffset = 0,
		},
		countFont = fontDB(),
		bindFont = fontDB(),
		include = "QUEST,BANNER,EQUIP,PROFMN,HOLIDAY,OPENABLE,DELVE",
	}
end

EIB.dbDefault = {
	extraItemsBar = {
		enable = true,
		noQuantumItems = false,
		barStyle = "auto",
		customList = {},
		blackList = {
			[183040] = true, -- Frosted Mindbender's Loop
			[193757] = true, -- Crystalline Clutchshell
			[200563] = true, -- Primordial Tortoiseshell
			[219381] = true, -- Weaver of Fates
			[237494] = true, -- Holy Codex
			[237495] = true, -- Malicious Excerpts
			[242664] = true, -- Durable Informant Collection Device
			[245964] = true, -- Durable Informant Collection Device
			[245965] = true, -- Durable Informant Collection Device
			[245966] = true, -- Durable Informant Collection Device
			[248583] = true, -- Drum of Renewed Bonds
		},
		bar1 = barDefaults(),
		bar2 = (function()
			local db = barDefaults()
			db.include = "POTIONMN,FLASKMN,VANTUSMN,UTILITY"
			return db
		end)(),
		bar3 = (function()
			local db = barDefaults()
			db.include = "MAGEFOOD,FOODVENDOR,FOODMN,RUNEMN,CUSTOM"
			return db
		end)(),
		bar4 = (function()
			local db = barDefaults()
			db.enable = false
			db.include = "CUSTOM"
			return db
		end)(),
		bar5 = (function()
			local db = barDefaults()
			db.enable = false
			db.include = "CUSTOM"
			return db
		end)(),
	},
}

EIB.DB = {
	---Reset a single bar's settings to defaults
	ResetBar = function(id)
		EIB.db.profile.extraItemsBar["bar" .. id] = barDefaults()
	end,
	---Reset all settings to defaults
	ResetAll = function()
		EIB.db.profile.extraItemsBar = EIB.dbDefault.extraItemsBar
	end,
}
