-- Settings.lua
-- Registers all MogCompanions user options with the Retail Settings API.
-- Adds a "MogCompanions" category to the game's Settings panel with:
--   • Default mounts (aquatic, special/repair)
-- Flying and ground mounts are chosen per-outfit in the wardrobe UI; no global default.
-- Alternative mount always selects a random mount from all collected usable mounts.
-- All user-facing strings come from Locales/enUS.lua via MogCompanionsLocales.
-- MogCompanionsSettingsCategoryID is a global used by Core.lua to open the panel.
local _, addon = ...;
local ns = select(2,...);
local MogCompanions = ns.MogCompanions;
local MogCompanionsSettings = CreateFrame('Frame', 'MogCompanionsSettingsFrame', UIParent);
local L = MogCompanionsLocales;

local settingsLoaded = false;

MogCompanionsSettingsCategoryID = 0;

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

local function GetOptionsSpecialMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogCompanions:getSortedSpecialMounts();

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

-- Registers all MogCompanions settings and creates the Settings panel layout.
-- Called once from PLAYER_ENTERING_WORLD after saved variables are loaded.
local function InitSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory("MogCompanions");

	MogCompanionsSettingsCategoryID = category:GetID();
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Default Section Title"], ''));

	local key1, key2 = GetBindingKey("Mount/Dismount");

	-- Default aquatic mount

	local variable = "DefaultAquatic";
	local defaultValue = 0;
	local name = L["Settings Aquatic Mount"];
	local tooltip = nil;
	if key1 or key2 then
		tooltip = WrapTextInColorCode(L["Settings Aquatic Mount Keybind Reminder"], "00999999");
	end
	local variableKey = "Aquatic";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsAquaticMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- Default special mount

	local variable = "DefaultSpecial";
	local defaultValue = 0;
	local name = L["Settings Special Mount"];
	local tooltip = nil;
	if key1 or key2 then
		tooltip = WrapTextInColorCode(L["Settings Special Mount Keybind Reminder"], "00999999");
	end
	local variableKey = "Special";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
   	Settings.CreateDropdown(category, setting, GetOptionsSpecialMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- Random ground: allow flying mounts

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Random Section Title"], ''));

	local variable = "RandomGroundAllowFlying";
	local defaultValue = true;
	local name = L["Settings Random Ground Allow Flying"];
	local tooltip = L["Settings Random Ground Allow Flying Tooltip"];
	local variableKey = "RandomGroundAllowFlying";
	local variableTable = MogCompanionsSaved;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateCheckbox(category, setting, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

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
