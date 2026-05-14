-- Settings.lua
-- Registers all MogCompanions user options with the Retail Settings API.
-- Adds a "MogCompanions" category to the game's Settings panel with:
--   • Default mounts (aquatic, repair/vendor)
-- Flying and ground mounts are chosen per-outfit in the wardrobe UI; no global default.
-- The Random mount summons a random mount from all collected usable mounts.
-- All user-facing strings come from Locales/enUS.lua via MogCompanionsLocales.
-- MogCompanionsSettingsCategoryID is a global used by Core.lua to open the panel.
local _, addon = ...;
local ns = select(2,...);
local MogCompanions = ns.MogCompanions;
local MogCompanionsSettings = CreateFrame('Frame', 'MogCompanionsSettingsFrame', UIParent);
local L = MogCompanionsLocales;

local settingsLoaded = false;
local SETTINGS_PREFIX = "MogCompanions";

MogCompanionsSettingsCategoryID = 0;

local function CreateSettingIdentifier(name)
	return SETTINGS_PREFIX .. name;
end

-- ── Default Mount Dropdown Data Providers ───────────────────────────────────
-- Each GetOptionsXxx function returns a Settings control data container used by
-- Settings.CreateDropdown. Entry 0 = "Random".
local function GetOptionsAquaticMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogCompanions:getSortedAquaticMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

local function GetOptionsRepairMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogCompanions:getSortedRepairMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

-- Stub; actual persistence is handled by the Settings API variable binding.
-- Extend this function if side-effects are needed when any setting changes.
local function OnSettingChanged()
	-- No side-effects needed; the Settings API variable binding handles persistence.
end

local function OnPetSettingChanged()
	MogCompanions:CreatePetMacro();
end

-- ── Modifier Key Helpers ─────────────────────────────────────────────────────
-- Returns the display label (e.g. "CTRL") for a modifier index (1=CTRL,2=SHIFT,3=ALT).
local function modKeyToLabel(key)
	local labels = { L["Settings CTRL"], L["Settings SHIFT"], L["Settings ALT"] };
	return labels[key] or "?";
end

-- Returns a lookup table (value→true) for the given array.
local function arrayToMap(array)
	local map = {};
	for _, item in ipairs(array) do
		map[item] = true;
	end
	return map;
end

-- Registers all MogCompanions settings and creates the Settings panel layout.
-- Called once from PLAYER_ENTERING_WORLD after saved variables are loaded.
local function InitSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory("MogCompanions");

	MogCompanionsSettingsCategoryID = category:GetID();

	-- ── Saved-variable migrations (nested tables not handled by Settings API) ──

	if MogCompanionsSaved.MountMods == nil then
		MogCompanionsSaved.MountMods = {};
	end
	if MogCompanionsSaved.MountMods.FlyingOrGround == nil then
		MogCompanionsSaved.MountMods.FlyingOrGround = 1;  -- display-only (always Click)
	end
	if MogCompanionsSaved.MountMods.Ground == nil then
		MogCompanionsSaved.MountMods.Ground = 1;       -- CTRL forces ground
	end
	if MogCompanionsSaved.MountMods.Repair == nil then
		MogCompanionsSaved.MountMods.Repair = 2;      -- SHIFT summons repair mount
	end
	if MogCompanionsSaved.MountMods.Random == nil then
		MogCompanionsSaved.MountMods.Random = 3;  -- ALT summons random mount
	end

	if MogCompanionsSaved.HearthstoneMods == nil then
		MogCompanionsSaved.HearthstoneMods = {};
	end
	if MogCompanionsSaved.HearthstoneMods.Selected == nil then
		MogCompanionsSaved.HearthstoneMods.Selected = 1;       -- display-only (always Click)
	end
	if MogCompanionsSaved.HearthstoneMods.Garrison == nil then
		MogCompanionsSaved.HearthstoneMods.Garrison = 1;      -- CTRL
	end
	if MogCompanionsSaved.HearthstoneMods.Dalaran == nil then
		MogCompanionsSaved.HearthstoneMods.Dalaran = 2;       -- SHIFT
	end
	if MogCompanionsSaved.HearthstoneMods.TeleportHome == nil then
		MogCompanionsSaved.HearthstoneMods.TeleportHome = 3;  -- ALT (reserved)
	end

	if MogCompanionsSaved.PetMods == nil then
		MogCompanionsSaved.PetMods = {};
	end
	if MogCompanionsSaved.PetMods.Selected == nil then
		MogCompanionsSaved.PetMods.Selected = 1;       -- display-only (always Click)
	end
	if MogCompanionsSaved.PetMods.Random == nil then
		MogCompanionsSaved.PetMods.Random = 1;         -- CTRL summons a random pet
	end
	if MogCompanionsSaved.PetMods.Favorite == nil then
		MogCompanionsSaved.PetMods.Favorite = 2;       -- SHIFT summons a random favorite pet
	end
	if MogCompanionsSaved.PetMods.Dismiss == nil then
		MogCompanionsSaved.PetMods.Dismiss = 3;        -- ALT dismisses the active pet
	end

	if MogCompanionsSaved.PetSummonOnChange == nil then
		MogCompanionsSaved.PetSummonOnChange = true;
	end

	if MogCompanionsSaved.PetSummonOnMount == nil then
		MogCompanionsSaved.PetSummonOnMount = true;
	end

	if MogCompanionsSaved.PetSummonOnLogin == nil then
		MogCompanionsSaved.PetSummonOnLogin = true;
	end

	-- ────────────────────────────────────────────────────────────────────────────

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Default Section Title"], ''));

	local key1, key2 = GetBindingKey("MOGCOMPANIONS_MOUNT_DISMOUNT");

	-- Default aquatic mount

	local variable = CreateSettingIdentifier("DefaultAquatic");
	local defaultValue = 0;
	local name = L["Settings Aquatic Mount"];
	local tooltip = nil;
	if key1 or key2 then
		local reminder = L["Settings Aquatic Mount Keybind Reminder"];
		reminder = reminder:gsub("%[KEY]", "[" .. modKeyToLabel(MogCompanionsSaved.MountMods.Ground) .. "]");
		tooltip = WrapTextInColorCode(reminder, "00999999");
	end
	local variableKey = "Aquatic";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsAquaticMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- Default repair mount

	local variable = CreateSettingIdentifier("DefaultRepair");
	local defaultValue = 0;
	local name = L["Settings Repair Mount"];
	local tooltip = nil;
	if key1 or key2 then
		local reminder = L["Settings Repair Mount Keybind Reminder"];
		reminder = reminder:gsub("%[KEY]", "[" .. modKeyToLabel(MogCompanionsSaved.MountMods.Repair) .. "]");
		tooltip = WrapTextInColorCode(reminder, "00999999");
	end
	local variableKey = "Repair";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
   	Settings.CreateDropdown(category, setting, GetOptionsRepairMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- Random ground: allow flying mounts

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Random Section Title"], ''));

	local variable = CreateSettingIdentifier("RandomGroundAllowFlying");
	local defaultValue = true;
	local name = L["Settings Random Ground Allow Flying"];
	local tooltip = L["Settings Random Ground Allow Flying Tooltip"];
	local variableKey = "RandomGroundAllowFlying";
	local variableTable = MogCompanionsSaved;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateCheckbox(category, setting, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- Clone targeted mount

	local variable = CreateSettingIdentifier("CloneTargetedMount");
	local defaultValue = false;
	local name = L["Settings Clone Targeted Mount"];
	local tooltip = L["Settings Clone Targeted Mount Tooltip"];
	local variableKey = "CloneTargetedMount";
	local variableTable = MogCompanionsSaved;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateCheckbox(category, setting, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- ── Mount Macro Modifier Keys ────────────────────────────────────────────────

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Mount Macro Title"], ''));

	local function GetOptionsMountMods()
		local container = Settings.CreateControlTextContainer();
		container:Add(1, L["Settings CTRL Key"]);
		container:Add(2, L["Settings SHIFT Key"]);
		container:Add(3, L["Settings ALT Key"]);
		return container:GetData();
	end

	local function GetOptionsMountModsClick()
		local container = Settings.CreateControlTextContainer();
		container:Add(1, L["Settings Click"]);
		return container:GetData();
	end

	local MountModDropdowns = {};

	-- Mutual-exclusion callback: when one dropdown changes, push the old value
	-- to whichever other dropdown currently holds the same value.
	local function OnMountModSettingChanged(setting, value)
		local otherValues = {};
		for i = 1, #MountModDropdowns do
			if setting ~= MountModDropdowns[i] then
				otherValues[i] = MountModDropdowns[i]:GetValue();
			else
				otherValues[i] = false;
			end
		end

		local valMap = arrayToMap(otherValues);
		local missing = 0;
		for i = 1, 3 do
			if not valMap[i] then
				missing = i;
			end
		end

		for i = 1, #otherValues do
			if otherValues[i] ~= false and otherValues[i] == value then
				MountModDropdowns[i]:SetValue(missing);
			end
		end
	end

	local variable = CreateSettingIdentifier("MountMacroModFlyingOrGround");
	local defaultValue = 1;
	local name = L["Settings Summon Flying Mount"];
	local variableKey = "FlyingOrGround";
	local variableTable = MogCompanionsSaved.MountMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	local initializer = Settings.CreateDropdown(category, setting, GetOptionsMountModsClick, false);
	setting:SetValueChangedCallback(OnMountModSettingChanged);
	-- Disable: Flying is always the "no modifier" case; not configurable.
	local function DisableDropdown(frame)
		frame.Control.Dropdown:SetEnabled(false);
	end
	hooksecurefunc(initializer, "InitFrame", function(self, frame) DisableDropdown(frame); end);

	local variable = CreateSettingIdentifier("MountMacroModGround");
	local defaultValue = 1;
	local name = L["Settings Summon Ground Mount"];
	local variableKey = "Ground";
	local variableTable = MogCompanionsSaved.MountMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsMountMods, false);
	setting:SetValueChangedCallback(OnMountModSettingChanged);
	tinsert(MountModDropdowns, setting);

	local variable = CreateSettingIdentifier("MountMacroModRepair");
	local defaultValue = 2;
	local name = L["Settings Summon Repair Mount"];
	local variableKey = "Repair";
	local variableTable = MogCompanionsSaved.MountMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsMountMods, false);
	setting:SetValueChangedCallback(OnMountModSettingChanged);
	tinsert(MountModDropdowns, setting);

	local variable = CreateSettingIdentifier("MountMacroModRandom");
	local defaultValue = 3;
	local name = L["Settings Summon Random Mount"];
	local variableKey = "Random";
	local variableTable = MogCompanionsSaved.MountMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsMountMods, false);
	setting:SetValueChangedCallback(OnMountModSettingChanged);
	tinsert(MountModDropdowns, setting);

	-- ── Hearthstone Macro Modifier Keys ──────────────────────────────────────────

	local HearthstoneModDropdowns = {};

	-- Same mutual-exclusion logic as mount mods.
	local function OnHearthstoneModSettingChanged(setting, value)
		local otherValues = {};
		for i = 1, #HearthstoneModDropdowns do
			if setting ~= HearthstoneModDropdowns[i] then
				otherValues[i] = HearthstoneModDropdowns[i]:GetValue();
			else
				otherValues[i] = false;
			end
		end

		local valMap = arrayToMap(otherValues);
		local missing = 0;
		for i = 1, 3 do
			if not valMap[i] then
				missing = i;
			end
		end

		for i = 1, #otherValues do
			if otherValues[i] ~= false and otherValues[i] == value then
				HearthstoneModDropdowns[i]:SetValue(missing);
			end
		end
	end

	local function GetOptionsHearthstoneMods()
		local container = Settings.CreateControlTextContainer();
		container:Add(1, L["Settings CTRL Key"]);
		container:Add(2, L["Settings SHIFT Key"]);
		container:Add(3, L["Settings ALT Key"]);
		return container:GetData();
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Hearthstone Macro Title"], ''));

	local variable = CreateSettingIdentifier("HearthstoneModSelected");
	local defaultValue = 1;
	local name = L["Settings Use Selected Hearthstone"];
	local variableKey = "Selected";
	local variableTable = MogCompanionsSaved.HearthstoneMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	local initializer = Settings.CreateDropdown(category, setting, GetOptionsMountModsClick, false);
	setting:SetValueChangedCallback(OnHearthstoneModSettingChanged);
	-- Disable: "Click (no modifier)" is always for the selected hearthstone.
	hooksecurefunc(initializer, "InitFrame", function(self, frame) DisableDropdown(frame); end);

	local variable = CreateSettingIdentifier("HearthstoneModGarrison");
	local defaultValue = 1;
	local name = L["Settings Use Garrison Hearthstone"];
	local variableKey = "Garrison";
	local variableTable = MogCompanionsSaved.HearthstoneMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsHearthstoneMods, false);
	setting:SetValueChangedCallback(OnHearthstoneModSettingChanged);
	tinsert(HearthstoneModDropdowns, setting);

	local variable = CreateSettingIdentifier("HearthstoneModDalaran");
	local defaultValue = 2;
	local name = L["Settings Use Dalaran Hearthstone"];
	local variableKey = "Dalaran";
	local variableTable = MogCompanionsSaved.HearthstoneMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsHearthstoneMods, false);
	setting:SetValueChangedCallback(OnHearthstoneModSettingChanged);
	tinsert(HearthstoneModDropdowns, setting);

	local variable = CreateSettingIdentifier("HearthstoneModTeleportHome");
	local defaultValue = 3;
	local name = L["Settings Teleport Home"];
	local variableKey = "TeleportHome";
	local variableTable = MogCompanionsSaved.HearthstoneMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsHearthstoneMods, false);
	setting:SetValueChangedCallback(OnHearthstoneModSettingChanged);
	tinsert(HearthstoneModDropdowns, setting);

	-- ── Pet Macro Modifier Keys ──────────────────────────────────────────────────

	local PetModDropdowns = {};

	local function OnPetModSettingChanged(setting, value)
		local otherValues = {};
		for i = 1, #PetModDropdowns do
			if setting ~= PetModDropdowns[i] then
				otherValues[i] = PetModDropdowns[i]:GetValue();
			else
				otherValues[i] = false;
			end
		end

		local valMap = arrayToMap(otherValues);
		local missing = 0;
		for i = 1, 3 do
			if not valMap[i] then
				missing = i;
			end
		end

		for i = 1, #otherValues do
			if otherValues[i] ~= false and otherValues[i] == value then
				PetModDropdowns[i]:SetValue(missing);
			end
		end

		OnPetSettingChanged();
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Pet Macro Title"], ''));

	local variable = CreateSettingIdentifier("PetModSelected");
	local defaultValue = 1;
	local name = L["Settings Summon Selected Pet"];
	local variableKey = "Selected";
	local variableTable = MogCompanionsSaved.PetMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	local initializer = Settings.CreateDropdown(category, setting, GetOptionsMountModsClick, false);
	setting:SetValueChangedCallback(OnPetModSettingChanged);
	-- Disable: click without a modifier always uses the selected/random pet action.
	hooksecurefunc(initializer, "InitFrame", function(self, frame) DisableDropdown(frame); end);

	local variable = CreateSettingIdentifier("PetModRandom");
	local defaultValue = 1;
	local name = L["Settings Summon Random Pet"];
	local variableKey = "Random";
	local variableTable = MogCompanionsSaved.PetMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsHearthstoneMods, false);
	setting:SetValueChangedCallback(OnPetModSettingChanged);
	tinsert(PetModDropdowns, setting);

	local variable = CreateSettingIdentifier("PetModFavorite");
	local defaultValue = 2;
	local name = L["Settings Summon Random Favorite Pet"];
	local variableKey = "Favorite";
	local variableTable = MogCompanionsSaved.PetMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsHearthstoneMods, false);
	setting:SetValueChangedCallback(OnPetModSettingChanged);
	tinsert(PetModDropdowns, setting);

	local variable = CreateSettingIdentifier("PetModDismiss");
	local defaultValue = 3;
	local name = L["Settings Dismiss Pet"];
	local variableKey = "Dismiss";
	local variableTable = MogCompanionsSaved.PetMods;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsHearthstoneMods, false);
	setting:SetValueChangedCallback(OnPetModSettingChanged);
	tinsert(PetModDropdowns, setting);

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Pet Auto Summon Title"], ''));

	local variable = CreateSettingIdentifier("PetSummonOnChange");
	local defaultValue = true;
	local name = L["Settings Summon Pet On Outfit Change"];
	local tooltip = L["Settings Summon Pet On Outfit Change Tooltip"];
	local variableKey = "PetSummonOnChange";
	local variableTable = MogCompanionsSaved;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateCheckbox(category, setting, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	local variable = CreateSettingIdentifier("PetSummonOnMount");
	local defaultValue = true;
	local name = L["Settings Summon Pet On Mount"];
	local tooltip = L["Settings Summon Pet On Mount Tooltip"];
	local variableKey = "PetSummonOnMount";
	local variableTable = MogCompanionsSaved;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateCheckbox(category, setting, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	local variable = CreateSettingIdentifier("PetSummonOnLogin");
	local defaultValue = true;
	local name = L["Settings Summon Pet On Login"];
	local tooltip = L["Settings Summon Pet On Login Tooltip"];
	local variableKey = "PetSummonOnLogin";
	local variableTable = MogCompanionsSaved;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateCheckbox(category, setting, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- ────────────────────────────────────────────────────────────────────────────

	Settings.RegisterAddOnCategory(category);
end

-- ── Settings Frame Event Handler ──────────────────────────────────────────
-- Waits for PLAYER_ENTERING_WORLD so that saved variables are loaded
-- before InitSettings tries to read MogCompanionsCharacterSaved.
function MogCompanionsSettings:OnEvent(event, addOnName)
	if event == "PLAYER_ENTERING_WORLD" and not settingsLoaded then

		settingsLoaded = true;

		InitSettings();

	end
end

MogCompanionsSettings:RegisterEvent("ADDON_LOADED");
MogCompanionsSettings:RegisterEvent("PLAYER_ENTERING_WORLD");

MogCompanionsSettings:SetScript("OnEvent", MogCompanionsSettings.OnEvent);
