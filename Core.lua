-- Core.lua
-- Main addon frame, event handling, and transmog-panel title UI.
-- Owns: UpdateTitle, slash commands, the per-outfit title dropdown, keybind
-- reminder helpers, and the PLAYER_ENTERING_WORLD / TRANSMOGRIFY_OPEN event loop.
-- Summon logic lives in Mounts.lua. Mount slot + tab UI lives in Mounts.lua.
-- Hearthstone UI lives in Hearthstones.lua. Settings live in Settings.lua.
local addonName, addon = ...
local ns = select(2,...)
local MogCompanions = CreateFrame('Frame', 'MogCompanionsAddonFrame', UIParent)

ns.MogCompanions = MogCompanions;
local L = MogCompanionsLocales;

_G["BINDING_NAME_CLICK MCHearthButton:LeftButton"] = L["Use Hearthstone"] or "Use Hearthstone";

local playerName = UnitName("player");
local transmogs = {};
local loaded = false;
local firstLoad = true;

local TitleDropdown;

-- Applies the saved per-outfit title for the currently active outfit.
-- Called after mounting and after the player changes the title dropdown selection.
-- Title = 0 or nil: [Default Title] — do not change the title.
-- Title = -1: clear the title (show bare player name).
-- Title > 0: apply that specific title ID.
function MogCompanions:UpdateTitle()
	local outfitData = MogCompanions:GetActiveOutfitTable();
	if not outfitData then return; end

	local outfitTitle = outfitData.Title;
	if outfitTitle == nil or outfitTitle == 0 then
		return;
	end

	local SavedCurrentTitle;
	if outfitTitle > 0 then
		SavedCurrentTitle = outfitTitle;
	else
		SavedCurrentTitle = -1;
	end

	if GetCurrentTitle() ~= SavedCurrentTitle and (SavedCurrentTitle == -1 or IsTitleKnown(SavedCurrentTitle)) then
		SetCurrentTitle(SavedCurrentTitle);
	end
end

-- Called by Bindings.xml when the MogCompanions keybinding is pressed.
function MogCompanionsBindingClicked()
	MogCompanionsSummon();
end

-- Legacy entry point; no longer called by Bindings.xml (the binding is now a direct
-- CLICK MCHearthButton:LeftButton secure binding). Kept as a callable global for macros.
function MogCompanionsHearthstoneBindingClicked()
	MogCompanionsPrepareHearthstone();
end

-- ── Slash Commands ────────────────────────────────────────────────────────────
local function PrintSlashHelp()
	print("|cFF00CCFFMogCompanions commands:|r");
	print("|cFFFFFFFF/mcomp mount|r - "..L["Slash Help Mount"]);
	print("|cFFFFFFFF/mcomp options|r - "..L["Slash Help Options"]);
end

local function OpenSettingsToMogCompanions()
	if MogCompanionsSettingsCategoryID > 0 then
		Settings.OpenToCategory(MogCompanionsSettingsCategoryID);
	end
end

function MogCompanions:OpenSettings()
	OpenSettingsToMogCompanions();
end

SLASH_MOGCOMPANIONS1 = "/mcomp";
SlashCmdList["MOGCOMPANIONS"] = function(msg)
	local command = string.lower(string.match(msg or "", "^%s*(.-)%s*$"));

	if command == "" or command == "help" then
		PrintSlashHelp();
	elseif command == "mount" then
		MogCompanionsSummon();
	elseif command == "options" then
		OpenSettingsToMogCompanions();
	else
		PrintSlashHelp();
	end
end

SLASH_MOGCOMPANIONS_MOUNT1 = "/mcmt";
SlashCmdList["MOGCOMPANIONS_MOUNT"] = function()
	MogCompanionsSummon();
end

-- ── Transmog Title Dropdown UI ──────────────────────────────────────────────
local function OnSettingChanged(setting, value)
	MogCompanionsCharacterSaved[setting:GetVariable()] = value;
end

-- Saves the chosen title for the currently viewed outfit and immediately applies it.
-- value: title ID (0 = [Default Title] / do not change, -1 = bare player name).
local function SetSelectedTitle(value)
	TitleDropdown:SetDefaultText(MogCompanions:CreateDisplayTitle(value));
	MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Title = value;
	
	MogCompanions:UpdateTitle();
end

-- Creates the title DropdownButton inside TransmogFrame.CharacterPreview and
-- populates it with all known titles. Also repositions the model scene control frame
-- to make room for the dropdown. Only called once (on first outfit view, reset=true).
local function GetTitles()
	TitleDropdown = CreateFrame("DropdownButton", nil, TransmogFrame.CharacterPreview, "WowStyle1DropdownTemplate");

	local function GeneratorFunctionTitles(dropdown, rootDescription)
		rootDescription:CreateButton(L["Default Title"], SetSelectedTitle, 0);
		rootDescription:CreateButton(playerName, SetSelectedTitle, -1);

		local titlesRaw = {};
		local count = 1;

		for i = 1, GetNumTitles() do
			if IsTitleKnown(i) then
				titlesRaw[count] = {};
				titlesRaw[count].id = i;
				titlesRaw[count].name = MogCompanions:CreateDisplayTitle(i);
				count = count + 1;				
			end
		end

		table.sort(titlesRaw, MogCompanionsSortAlphabetical);

		for i = 1, #titlesRaw do
			rootDescription:CreateButton(titlesRaw[i].name, SetSelectedTitle, titlesRaw[i].id);
		end

		local extent = 20;
		local maxCharacters = 20;
		local maxScrollExtent = extent * maxCharacters;
		rootDescription:SetScrollMode(maxScrollExtent);

	end

	TransmogFrame.CharacterPreview.ModelScene.ControlFrame:SetPoint("TOP", 0, -64);

	TitleDropdown:SetDefaultText(MogCompanions:CreateDisplayTitle(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Title));

	TitleDropdown:SetWidth(240);
	TitleDropdown:SetPoint("TOP", TransmogFrame.CharacterPreview, "TOP", 0, -27);
	TitleDropdown:SetFrameStrata("MEDIUM");
	TitleDropdown:SetFrameLevel(200);
	TitleDropdown.Text:SetJustifyH("CENTER");

	TitleDropdown:SetupMenu(GeneratorFunctionTitles);

	TitleDropdown:SetScript("OnEnter", function()
		GameTooltip:SetOwner(TitleDropdown, "ANCHOR_RIGHT");
		GameTooltip:AddLine(L["Character Title Tooltip Header"], 1, 1, 1);
		local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
		local outfitData = MogCompanionsCharacterSaved and outfitID and MogCompanionsCharacterSaved["Outfit"..outfitID];
		local titleVal = outfitData and outfitData.Title;
		if titleVal == nil or titleVal == 0 then
			GameTooltip:AddLine(L["Character Title Tooltip Unset"], 1, 0.82, 0, true);
		else
			GameTooltip:AddLine(L["Character Title Tooltip Set"], 1, 0.82, 0, true);
		end
		GameTooltip:Show();
	end)

	TitleDropdown:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end)
end

-- Opens the game's Keybindings panel and expands the MogCompanions section.
-- Walks the Settings panel child frames to find and toggle the MogCompanions row.
-- May break if Blizzard changes the Settings panel's internal frame hierarchy.
local function OpenKeybindingsToMogCompanions()
	Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, "MogCompanions");
	local children = {SettingsPanel.Container.SettingsList.ScrollBox.ScrollTarget:GetChildren()}
	
	for i, child in ipairs(children) do
		local children2 = {child:GetChildren()};
		for j, child2 in ipairs(children2) do
			if (child2.Text ~= nil) then
				if child2.Text:GetText() == "MogCompanions" then
					local initializer = child:GetElementData();
					local data = initializer.data;
					data.expanded = not data.expanded;
					child:SetHeight(child:CalculateHeight());
					child:OnExpandedChanged(data.expanded);
				end
			end
		end
	end
end

function MogCompanions:OpenKeybinds()
	OpenKeybindingsToMogCompanions();
end

-- Called on VIEWED_TRANSMOG_OUTFIT_CHANGED to refresh the title dropdown.
-- reset=true on the very first outfit view; rebuilds the dropdown from scratch (GetTitles).
-- reset=false on subsequent outfit changes; updates the label and regenerates the menu.
local function InitTitles(reset)
	if not reset then

		TitleDropdown:SetDefaultText(MogCompanions:CreateDisplayTitle(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Title));

		TitleDropdown:GenerateMenu();

	else

		GetTitles();

	end
end

-- ── Addon Event Handler ──────────────────────────────────────────────────────
-- PLAYER_ENTERING_WORLD (once): initializes MogCompanionsCharacterSaved and MogCompanionsSaved
--   with defaults if they don't exist, and migrates any missing fields.
-- VIEWED_TRANSMOG_OUTFIT_CHANGED: refreshes mount slots and title dropdown for the
--   newly viewed outfit. firstLoad=true triggers full UI construction.
-- TRANSMOGRIFY_OPEN: defers mount tab creation by 0.1 s to allow Blizzard UI to settle.
function MogCompanions:OnEvent(event, addOnName)
	if event == "PLAYER_ENTERING_WORLD" and not loaded then
		if MogCompanionsCharacterSaved == nil then
			MogCompanionsCharacterSaved = {};
		end

		if MogCompanionsCharacterSaved.Default == nil then
			MogCompanionsCharacterSaved.Default = {};
		end

		if MogCompanionsCharacterSaved.Default.Aquatic == nil then
			MogCompanionsCharacterSaved.Default.Aquatic = 0;
		end

		if MogCompanionsCharacterSaved.Default.Repair == nil then
			MogCompanionsCharacterSaved.Default.Repair = 0;
		end

		for t = 1, #C_TransmogOutfitInfo.GetOutfitsInfo() do
			local outfitInfo = C_TransmogOutfitInfo.GetOutfitsInfo()[t];	
			MogCompanions:CreateEmptyOutfit(outfitInfo.outfitID);
		end		

		if MogCompanionsSaved == nil then
			MogCompanionsSaved = {};
			MogCompanionsSaved['MacroID'] = 0;
			MogCompanionsSaved.ShowFlyingInGround = true;
			MogCompanionsSaved.RandomGroundAllowFlying = true;
		end

		if MogCompanionsSaved.ShowFlyingInGround == nil then
			MogCompanionsSaved.ShowFlyingInGround = true;
		end

		if MogCompanionsSaved.RandomGroundAllowFlying == nil then
			MogCompanionsSaved.RandomGroundAllowFlying = true;
		end

		if MogCompanionsSaved.CloneTargetedMount == nil then
			MogCompanionsSaved.CloneTargetedMount = false;
		end

		loaded = true;
	
	end

	if event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" then
		MogCompanions:CreateEmptyOutfit(C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID());
		MogCompanions:InitMountSlots(firstLoad);
		InitTitles(firstLoad);

		C_Timer.After(0.1, function()
			if UpdateSelectedMountRow ~= nil then
				UpdateSelectedMountRow();
    		end
		end)

		firstLoad = false;
	end		

	if event == "TRANSMOGRIFY_OPEN" then
		C_Timer.After(0.1, function()
			MogCompanions:InitMountTab();
		end)
	end
end

MogCompanions:RegisterEvent("ADDON_LOADED")
MogCompanions:RegisterEvent("PLAYER_ENTERING_WORLD")
MogCompanions:RegisterEvent("TRANSMOGRIFY_OPEN")
MogCompanions:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_CHANGED")

MogCompanions:SetScript("OnEvent", MogCompanions.OnEvent)
