-- Settings.lua
-- Registers all MogCompanions user options with the Retail Settings API.
-- Adds a "MogCompanions" category to the game's Settings panel with:
--   • Default mounts (flying, ground, aquatic, special/repair, alternative)
--   • Per-outfit overrides: character title, flying mount, ground mount
-- All user-facing strings come from Locales/enUS.lua via MogCompanionsLocales.
-- MogCompanionsSettingsCategoryID is a global used by Core.lua to open the panel.
local _, addon = ...;
local ns = select(2,...);
local MogCompanions = ns.MogCompanions;
local MogCompanionsSettings = CreateFrame('Frame', 'MogCompanionsSettingsFrame', UIParent);
local L = MogCompanionsLocales;

local playerName = UnitName("player");
local settingsLoaded = false;
local transmogs = {};

MogCompanionsSettingsCategoryID = 0;

-- ── Default Mount Dropdown Data Providers ───────────────────────────────────
-- Each GetOptionsXxx function returns a Settings control data container used by
-- Settings.CreateDropdown. Entry 0 = "Random" for default mounts;
-- entry 1 = "Default" for per-outfit overrides.
local function GetOptionsFlyingMount()
	local container = Settings.CreateControlTextContainer();

	container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

	local mounts = MogCompanions:getSortedFlyingMounts()

	for i = 1, #mounts do
		local mount = mounts[i];
		container:Add(mount.id, mount.nameAndIcon);
		if mount.id == MogCompanionsCharacterSaved.Default.Flying then
			defaultValue = i;
		end
	end

	return container:GetData();
end

local function GetOptionsGroundMount()
	local container = Settings.CreateControlTextContainer();

	container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

	local mounts = MogCompanions:getSortedGroundMounts();

	for i = 1, #mounts do
		local mount = mounts[i];
		container:Add(mount.id, mount.nameAndIcon);
		if mount.id == MogCompanionsCharacterSaved.Default.Ground then
			defaultValue = i;
		end
	end

	return container:GetData();
end

local function GetOptionsAquaticMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogCompanions:getSortedAquaticMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
			if mount.id == MogCompanionsCharacterSaved.Default.Aquatic then
				defaultValue = i;
			end
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
			if mount.id == MogCompanionsCharacterSaved.Default.Special then
				defaultValue = i;
			end
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

local function GetOptionsAlternativeMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogCompanions:getSortedAlternativeMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
			if mount.id == MogCompanionsCharacterSaved.Default.Alternative then
				defaultValue = i;
			end
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

-- Stub; actual persistence is handled by the Settings API variable binding.
-- Extend this function if side-effects are needed when any setting changes.
local function OnSettingChanged()
	--
end

-- Registers all MogCompanions settings and creates the Settings panel layout.
-- Called once from PLAYER_ENTERING_WORLD. Reads all current outfit info at that point
-- to build per-outfit title and mount dropdowns for each transmog outfit.
local function InitSettings()
	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo();

	for i = 1, #outfits do
		local outfitsInfo = C_TransmogOutfitInfo.GetOutfitInfo(outfits[i].outfitID);
		table.insert(transmogs, outfitsInfo.name);
	end

	local category, layout = Settings.RegisterVerticalLayoutCategory("MogCompanions");

	MogCompanionsSettingsCategoryID = category:GetID();
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Default Section Title"], ''));
   
	local key1, key2 = GetBindingKey("Mount/Dismount");

	--

	local variable = "DefaultFlying";
	local defaultValue = 1;
	local name = L["Settings Flying Mount"];
	local tooltip = L["Settings Flying Mount Tooltip"];
	local variableKey = "Flying";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsFlyingMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	--

	local variable = "DefaultGround";
	local defaultValue = 1;
	local name = L["Settings Ground Mount"];
	local tooltip = false;
	if key1 or key2 then
		tooltip = L["Settings Ground Mount Tooltip"].."\n\n"..WrapTextInColorCode(L["Settings Ground Mount Keybind Reminder"], "00999999");
	else
		tooltip = L["Settings Ground Mount Tooltip"];
	end

	local variableKey = "Ground";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsGroundMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	--

	local variable = "DefaultAquatic";
	local defaultValue = 1;
	local name = L["Settings Aquatic Mount"];
	local tooltip = false;
	if key1 or key2 then
		tooltip = WrapTextInColorCode(L["Settings Aquatic Mount Keybind Reminder"], "00999999");
	end
	local variableKey = "Aquatic";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsAquaticMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	--

	local variable = "DefaultSpecial";
	local defaultValue = 1;
	local name = L["Settings Special Mount"];
	local tooltip = false;
	if key1 or key2 then
		tooltip = WrapTextInColorCode(L["Settings Special Mount Keybind Reminder"], "00999999");
	end
	local variableKey = "Special";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
   	Settings.CreateDropdown(category, setting, GetOptionsSpecialMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	--

	local variable = "DefaultAlternative";
	local defaultValue = 1;
	local name = L["Settings Alternative Mount"];
	local tooltip = L["Settings Alternative Mount Tooltip"];
	if key1 or key2 then
		tooltip = L["Settings Alternative Mount Tooltip"].."\n\n"..WrapTextInColorCode(L["Settings Alternative Mount Keybind Reminder"], "00999999");
	else
		tooltip = L["Settings Alternative Mount Tooltip"];
	end
	local variableKey = "Alternative";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
   	Settings.CreateDropdown(category, setting, GetOptionsAlternativeMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);		

	--

	local settingsTransmogContainer = CreateFromMixins(SettingsExpandableSectionMixin);

	for t = 1, #C_TransmogOutfitInfo.GetOutfitsInfo() do

		local outfitInfo = C_TransmogOutfitInfo.GetOutfitsInfo()[t];
	
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(outfitInfo.name, ''));

		local variable = "Title"..outfitInfo.outfitID;
		local defaultValue = 1;
		local name = L["Settings Character Title"];
		local tooltip = L["Settings Character Title Tooltip"];
		local variableKey = "Title";
		local variableTable = MogCompanionsCharacterSaved["Outfit"..outfitInfo.outfitID];

		local function GetOptionsTitleSettings()
			local container = Settings.CreateControlTextContainer();
			local titles = MogCompanions:getSortedTitles();

			container:Add(0, playerName);

			for i = 1, #titles do
				local title = titles[i];
				container:Add(title.id, title.name);
				if title.id == MogCompanionsCharacterSaved["Outfit"..outfitInfo.outfitID].Title then
					defaultValue = i;
				end
			end

			return container:GetData();

		end

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
		Settings.CreateDropdown(category, setting, GetOptionsTitleSettings, tooltip);
		setting:SetValueChangedCallback(OnSettingChanged);

		--

		local variable = "Flying"..outfitInfo.outfitID;
		local defaultValue = 1;
		local name = L["Settings Flying Mount"];
		local tooltip = false; --"This is a tooltip for the dropdown.";
		local variableKey = "Flying";
		local variableTable = MogCompanionsCharacterSaved["Outfit"..outfitInfo.outfitID];

		local function GetOptionsFlyingMountSettings()
			local container = Settings.CreateControlTextContainer();
			local mounts = MogCompanions:getSortedFlyingMounts();

			container:Add(1, "|T136243:18|t "..L["Settings Default Selection Label"]);

			for i = 1, #mounts do
				local mount = mounts[i];
				container:Add(mount.id, mount.nameAndIcon);
				if mount.id == MogCompanionsCharacterSaved["Outfit"..outfitInfo.outfitID].Flying then
					defaultValue = i;
				end
			end

			return container:GetData();

		end

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue, 240, 640);
		local dropdownTest = Settings.CreateDropdown(category, setting, GetOptionsFlyingMountSettings, tooltip);
		setting:SetValueChangedCallback(OnSettingChanged);

		---

		local variable = "Ground"..outfitInfo.outfitID;
		local defaultValue = 1;
		local name = L["Settings Ground Mount"];
		local tooltip = false;
		local variableKey = "Ground";
		local variableTable = MogCompanionsCharacterSaved["Outfit"..outfitInfo.outfitID];

		local function GetOptionsGroundMountSettings()
			local container = Settings.CreateControlTextContainer();
			local mounts = MogCompanions:getSortedGroundMounts();

			container:Add(1, "|T136243:18|t "..L["Settings Default Selection Label"]);

			for i = 1, #mounts do
				local mount = mounts[i];
				container:Add(mount.id, mount.nameAndIcon);
				if mount.id == MogCompanionsCharacterSaved["Outfit"..outfitInfo.outfitID].Ground then
					defaultValue = i;
				end
			end

			return container:GetData();

		end

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
		Settings.CreateDropdown(category, setting, GetOptionsGroundMountSettings, tooltip);
		setting:SetValueChangedCallback(OnSettingChanged);

	end

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
