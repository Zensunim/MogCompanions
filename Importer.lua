local _, addon = ...;
local ns = select(2, ...);
local MogCompanions = ns.MogCompanions;
local L = MogCompanionsLocales;

local PANEL_BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = {
		left = 11,
		right = 11,
		top = 12,
		bottom = 11,
	},
};

local function IsAddonLoadedForCharacter(addonName)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(addonName);
	elseif IsAddOnLoaded then
		return IsAddOnLoaded(addonName);
	end

	return false;
end

local function DisableAddonForCurrentCharacter(addonName)
	local playerName = UnitName("player");

	if C_AddOns and C_AddOns.DisableAddOn then
		C_AddOns.DisableAddOn(addonName, playerName);
	elseif DisableAddOn then
		DisableAddOn(addonName, playerName);
	end

	if C_AddOns and C_AddOns.SaveAddOns then
		C_AddOns.SaveAddOns();
	elseif SaveAddOns then
		SaveAddOns();
	end
end

local function ReloadUIFromClick()
	if C_UI and C_UI.Reload then
		C_UI.Reload();
	else
		ReloadUI();
	end
end

local function AddUniqueValue(pool, value)
	if type(pool) ~= "table" or value == nil or value == "" then
		return false;
	end

	for i = 1, #pool do
		if pool[i] == value then
			return false;
		end
	end

	table.insert(pool, value);
	return true;
end

local function IsValidModifierValue(value)
	return type(value) == "number" and value >= 1 and value <= 3;
end

local function EnsureDestinationSavedVariables()
	if MogCompanionsSaved == nil then
		MogCompanionsSaved = {};
	end

	if MogCompanionsCharacterSaved == nil then
		MogCompanionsCharacterSaved = {};
	end

	if MogCompanionsCharacterSaved.Default == nil then
		MogCompanionsCharacterSaved.Default = {};
	end
end

local function ImportMogMountSettingsInternal()
	if MogCompanions == nil or MogCompanions.CreateEmptyOutfit == nil then
		return false, "MogMount Import Failed";
	end

	if type(MogMountSaved) ~= "table" and type(MogMountCharacterSaved) ~= "table" then
		return false, "MogMount Import No Data";
	end

	EnsureDestinationSavedVariables();

	local importedAnything = false;

	-- Default mounts
	if type(MogMountSaved) == "table" and type(MogMountSaved.Default) == "table" then
		local aquaticValue = MogMountSaved.Default.Aquatic;
		if type(aquaticValue) == "number" then
			local dest = MogCompanionsCharacterSaved.Default.Aquatic;
			if dest == nil or dest == 0 or dest == 1 then
				MogCompanionsCharacterSaved.Default.Aquatic = aquaticValue;
				importedAnything = true;
			end
		end

		local specialValue = MogMountSaved.Default.Special;
		if type(specialValue) == "number" then
			local dest = MogCompanionsCharacterSaved.Default.Repair;
			if dest == nil or dest == 0 or dest == 1 then
				MogCompanionsCharacterSaved.Default.Repair = specialValue;
				importedAnything = true;
			end
		end
	end

	-- Per-outfit settings
	if type(MogMountCharacterSaved) == "table" then
		for key, sourceOutfit in pairs(MogMountCharacterSaved) do
			local outfitID = string.match(key, "^Outfit(%d+)$");

			if outfitID ~= nil and type(sourceOutfit) == "table" then
				outfitID = tonumber(outfitID);
				MogCompanions:CreateEmptyOutfit(outfitID);

				local destinationOutfit = MogCompanionsCharacterSaved["Outfit" .. outfitID];

				-- Flying
				if type(sourceOutfit.Flying) == "number" and sourceOutfit.Flying > 1 then
					if type(destinationOutfit.FlyingMounts) ~= "table" then
						destinationOutfit.FlyingMounts = {};
					end
					if AddUniqueValue(destinationOutfit.FlyingMounts, sourceOutfit.Flying) then
						importedAnything = true;
					end
					local dest = destinationOutfit.Flying;
					if dest == nil or dest == 0 or dest == 1 then
						destinationOutfit.Flying = sourceOutfit.Flying;
						importedAnything = true;
					end
				end

				-- Ground
				if type(sourceOutfit.Ground) == "number" and sourceOutfit.Ground > 1 then
					if type(destinationOutfit.GroundMounts) ~= "table" then
						destinationOutfit.GroundMounts = {};
					end
					if AddUniqueValue(destinationOutfit.GroundMounts, sourceOutfit.Ground) then
						importedAnything = true;
					end
					local dest = destinationOutfit.Ground;
					if dest == nil or dest == 0 or dest == 1 then
						destinationOutfit.Ground = sourceOutfit.Ground;
						importedAnything = true;
					end
				end

				-- Hearthstone
				if type(sourceOutfit.Hearthstone) == "number" and sourceOutfit.Hearthstone > 1 then
					if type(destinationOutfit.Hearthstones) ~= "table" then
						destinationOutfit.Hearthstones = {};
					end
					if AddUniqueValue(destinationOutfit.Hearthstones, sourceOutfit.Hearthstone) then
						importedAnything = true;
					end
					local dest = destinationOutfit.Hearthstone;
					if dest == nil or dest == 0 or dest == 1 then
						destinationOutfit.Hearthstone = sourceOutfit.Hearthstone;
						importedAnything = true;
					end
				end

				-- Pet
				if type(sourceOutfit.Pet) == "string" and sourceOutfit.Pet ~= "" then
					if type(destinationOutfit.Pets) ~= "table" then
						destinationOutfit.Pets = {};
					end
					if AddUniqueValue(destinationOutfit.Pets, sourceOutfit.Pet) then
						importedAnything = true;
					end
					local dest = destinationOutfit.Pet;
					if dest == nil or dest == "" then
						destinationOutfit.Pet = sourceOutfit.Pet;
						importedAnything = true;
					end
				end

				-- Title
				if type(sourceOutfit.Title) == "number" then
					local dest = destinationOutfit.Title;
					if dest == nil or dest == 0 then
						destinationOutfit.Title = sourceOutfit.Title;
						importedAnything = true;
					end
				end
			end
		end
	end

	-- Mount modifiers
	if type(MogMountSaved) == "table" and type(MogMountSaved.MountMods) == "table" then
		local sourceMods = MogMountSaved.MountMods;
		local sourceGroundValid = IsValidModifierValue(sourceMods.Ground);
		local sourceSpecialValid = IsValidModifierValue(sourceMods.Special);

		if sourceGroundValid and sourceSpecialValid and sourceMods.Ground ~= sourceMods.Special then
			if MogCompanionsSaved.MountMods == nil then
				MogCompanionsSaved.MountMods = {};
			end
			MogCompanionsSaved.MountMods.Ground = sourceMods.Ground;
			MogCompanionsSaved.MountMods.Repair = sourceMods.Special;
			importedAnything = true;

			-- Keep Random a valid unused modifier value
			local currentRandom = MogCompanionsSaved.MountMods.Random;
			if currentRandom == sourceMods.Ground or currentRandom == sourceMods.Special then
				for i = 1, 3 do
					if i ~= sourceMods.Ground and i ~= sourceMods.Special then
						MogCompanionsSaved.MountMods.Random = i;
						break;
					end
				end
			end
		end
	end

	-- Hearthstone modifiers
	if type(MogMountSaved) == "table" and type(MogMountSaved.HearthstoneMods) == "table" then
		local sourceMods = MogMountSaved.HearthstoneMods;
		local sourceGarrisonValid = IsValidModifierValue(sourceMods.Garrison);
		local sourceDalaranValid = IsValidModifierValue(sourceMods.Dalaran);
		local sourceTeleportHomeValid = IsValidModifierValue(sourceMods.TeleportHome);
		local sourceNoDuplicates = sourceMods.Garrison ~= sourceMods.Dalaran
			and sourceMods.Garrison ~= sourceMods.TeleportHome
			and sourceMods.Dalaran ~= sourceMods.TeleportHome;

		if sourceGarrisonValid and sourceDalaranValid and sourceTeleportHomeValid and sourceNoDuplicates then
			if MogCompanionsSaved.HearthstoneMods == nil then
				MogCompanionsSaved.HearthstoneMods = {};
			end
			MogCompanionsSaved.HearthstoneMods.Garrison = sourceMods.Garrison;
			MogCompanionsSaved.HearthstoneMods.Dalaran = sourceMods.Dalaran;
			MogCompanionsSaved.HearthstoneMods.TeleportHome = sourceMods.TeleportHome;
			importedAnything = true;
		end
	end

	if not importedAnything then
		return false, "MogMount Import No Data";
	end

	return true;
end

local function ImportMogMountSettings()
	local ok, success, failureKey = pcall(ImportMogMountSettingsInternal);

	if not ok then
		return false, "MogMount Import Failed";
	end

	return success, failureKey;
end

local function CreateChoiceCard(parent, choice)
	local card = CreateFrame("Frame", nil, parent, "BackdropTemplate");
	card:SetSize(220, 360);
	card:SetBackdrop(PANEL_BACKDROP);
	card:SetBackdropColor(0.93, 0.87, 0.75, 0.98);
	card:SetBackdropBorderColor(0.45, 0.32, 0.18, 1);

	local titleBackground = card:CreateTexture(nil, "ARTWORK");
	titleBackground:SetSize(186, 42);
	titleBackground:SetPoint("TOP", card, "TOP", 0, -24);
	titleBackground:SetColorTexture(0.38, 0.17, 0.07, 0.24);

	local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	title:SetPoint("CENTER", titleBackground, "CENTER", 0, 0);
	title:SetWidth(192);
	title:SetJustifyH("CENTER");
	title:SetJustifyV("MIDDLE");
	title:SetText(choice.title);

	local artFrame = CreateFrame("Frame", nil, card, "BackdropTemplate");
	artFrame:SetSize(124, 124);
	artFrame:SetPoint("TOP", titleBackground, "BOTTOM", 0, -18);
	artFrame:SetBackdrop(PANEL_BACKDROP);
	artFrame:SetBackdropColor(0.26, 0.20, 0.12, 0.9);
	artFrame:SetBackdropBorderColor(0.45, 0.32, 0.18, 0.9);

	local artBackground = artFrame:CreateTexture(nil, "BACKGROUND");
	artBackground:SetPoint("TOPLEFT", artFrame, "TOPLEFT", 12, -12);
	artBackground:SetPoint("BOTTOMRIGHT", artFrame, "BOTTOMRIGHT", -12, 12);
	artBackground:SetColorTexture(0.11, 0.08, 0.05, 0.75);

	local icon = artFrame:CreateTexture(nil, "ARTWORK");
	icon:SetSize(72, 72);
	icon:SetPoint("CENTER");
	icon:SetTexture(choice.iconTexture);
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	if choice.desaturate then
		icon:SetDesaturated(true);
	end
	if choice.iconVertexColor ~= nil then
		icon:SetVertexColor(choice.iconVertexColor[1], choice.iconVertexColor[2], choice.iconVertexColor[3], 1);
		else
		icon:SetVertexColor(1, 1, 1, 1);
	end

	local description = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	description:SetPoint("TOP", artFrame, "BOTTOM", 0, -18);
	description:SetWidth(196);
	description:SetJustifyH("CENTER");
	description:SetJustifyV("TOP");
	description:SetText(choice.description);

	local button = CreateFrame("Button", nil, card, "UIPanelButtonTemplate");
	button:SetSize(176, 30);
	button:SetPoint("BOTTOM", card, "BOTTOM", 0, 26);
	button:SetText(choice.buttonText);
	button:SetScript("OnClick", choice.onClick);

	card.Button = button;
	return card;
end

local choices = {
	{
		key = "UseMogMount",
		title = L["Use MogMount"],
		description = L["Disable MogCompanions Description"],
		buttonText = L["Use MogMount"],
		iconTexture = "Interface\\ICONS\\inv_blacksmith_leystonehoofplates_blue",
		iconVertexColor = {1, 0.92, 0.72},
		onClick = function()
			print(L["MogCompanions Disabled"]);
			DisableAddonForCurrentCharacter("MogCompanions");
			ReloadUIFromClick();
		end,
	},
	{
		key = "TransferMogMount",
		title = L["Transfer MogMount"],
		description = L["Transfer MogMount Description"],
		buttonText = L["Transfer MogMount Button"],
		iconTexture = "Interface\\ICONS\\misc_arrowright",
		iconVertexColor = {1, 0.92, 0.72},
		onClick = function()
			local success, failureKey = ImportMogMountSettings();

			if success then
				print(L["MogMount Import Complete"]);
			elseif failureKey == "MogMount Import No Data" then
				print(L["MogMount Import No Data"]);
			else
				print(L[failureKey or "MogMount Import Failed"]);
			end

			DisableAddonForCurrentCharacter("MogMount");
			ReloadUIFromClick();
		end,
	},
	{
		key = "UseMogCompanions",
		title = L["Use MogCompanions"],
		description = L["Disable MogMount Description"],
		buttonText = L["Use MogCompanions"],
		iconTexture = "Interface\\ICONS\\inv_cosmicdragonmount",
		iconVertexColor = {1, 0.92, 0.72},
		onClick = function()
			print(L["MogMount Disabled"]);
			DisableAddonForCurrentCharacter("MogMount");
			ReloadUIFromClick();
		end,
	},
};

local GetConflictFrame;

local function TryShowConflictFrame()
	local frame = GetConflictFrame();

	if frame:IsShown() then
		return;
	end

	if not IsAddonLoadedForCharacter("MogMount") or not IsAddonLoadedForCharacter("MogCompanions") then
		return;
	end

	if InCombatLockdown ~= nil and InCombatLockdown() then
		frame.pendingCombatShow = true;
		frame:RegisterEvent("PLAYER_REGEN_ENABLED");
		return;
	end

	frame.pendingCombatShow = nil;
	frame:UnregisterEvent("PLAYER_REGEN_ENABLED");
	frame:Show();
end

function MogCompanions:ShowConflictResolver()
	TryShowConflictFrame();
end

GetConflictFrame = function()
	local frame = _G.MogCompanionsConflictFrame;

	if frame ~= nil and frame.importerInitialized then
		return frame;
	end

	if frame == nil then
		frame = CreateFrame("Frame", "MogCompanionsConflictFrame", UIParent);
	end

	frame:SetAllPoints(UIParent);
	frame:SetFrameStrata("FULLSCREEN_DIALOG");
	frame:SetToplevel(true);
	frame:EnableMouse(true);
	frame:Hide();

	if frame.Overlay == nil then
		local overlay = frame:CreateTexture(nil, "BACKGROUND");
		overlay:SetAllPoints(frame);
		overlay:SetColorTexture(0, 0, 0, 0.72);
		frame.Overlay = overlay;
	end

	if frame.Panel == nil then
		local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate");
		panel:SetSize(760, 520);
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 10);
		panel:SetBackdrop(PANEL_BACKDROP);
		panel:SetBackdropColor(0.95, 0.89, 0.77, 0.98);
		panel:SetBackdropBorderColor(0.46, 0.31, 0.15, 1);
		frame.Panel = panel;

		local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton");
		closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6);
		closeButton:SetScript("OnClick", function()
			frame:Hide();
		end);
		panel.CloseButton = closeButton;

		local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
		title:SetPoint("TOP", panel, "TOP", 0, -32);
		title:SetWidth(660);
		title:SetJustifyH("CENTER");
		title:SetText(L["MogMount Conflict Prompt"]);
		panel.Title = title;

		local body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
		body:SetPoint("TOP", title, "BOTTOM", 0, -14);
		body:SetWidth(650);
		body:SetJustifyH("CENTER");
		body:SetJustifyV("TOP");
		body:SetText(L["MogMount Conflict Body"]);
		panel.Body = body;

		panel.Cards = {};
		for index, choice in ipairs(choices) do
			local card = CreateChoiceCard(panel, choice);
			if index == 1 then
				card:SetPoint("TOPLEFT", panel, "TOPLEFT", 34, -126);
			else
				card:SetPoint("LEFT", panel.Cards[index - 1], "RIGHT", 24, 0);
			end
			panel.Cards[index] = card;
		end
	end

	frame.importerInitialized = true;
	frame:RegisterEvent("PLAYER_ENTERING_WORLD");
	frame:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_ENTERING_WORLD" then
			C_Timer.After(0.5, TryShowConflictFrame);
		elseif event == "PLAYER_REGEN_ENABLED" then
			if not self.pendingCombatShow then
				return;
			end

			TryShowConflictFrame();
		end
	end);

	return frame;
end

local conflictFrame = GetConflictFrame();

if IsLoggedIn ~= nil and IsLoggedIn() then
	C_Timer.After(0.5, TryShowConflictFrame);
end