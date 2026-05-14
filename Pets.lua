-- Pets.lua
-- Companion pet slot + pets tab UI for the wardrobe Companions panel.
-- This module only handles selection and preview UI; summoning behavior remains separate.
local _, addon = ...;
local ns = select(2, ...);
local MogCompanions = ns.MogCompanions;
local L = MogCompanionsLocales;

local PET_EMPTY_ICON = 656575;
local PET_RANDOM_ICON = 1669485;
local PET_NO_PET_ICON = 618980;
local PET_RANDOM_FAVORITE_ICON = 6013777;

local PetsFrame;
local PetFrame;
local PetTexture;
local PetBorder;
local PetBorderTexture;
local PetBorderHighlight;
local PetBorderHighlightTexture;
local PetClear;

local PetPreview;
local PetModel;
local PetPreviewControls;

local PetsSearchBox;
local PetsDataProvider;
local PetsScrollView;
local PetsListScrollBox;
local PetsSlotTitle;
local PetShowSelectedButton;
local PetNoResultsText;
local PetsInitScheduled = false;
local RefreshPetList;
local PetDetailsCache = {};
local LastClickedPetID;
local ShowOnlySelectedPets = false;
local PetModeButtons = {};

MogCompanions.PetSearchString = "";

local function GetViewedOutfitID()
	if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID then
		return C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
	end

	return nil;
end

local function GetOutfitTable(outfitID)
	if outfitID == nil or MogCompanionsCharacterSaved == nil then
		return nil;
	end

	MogCompanions:CreateEmptyOutfit(outfitID);

	return MogCompanionsCharacterSaved["Outfit"..outfitID];
end

local function GetNormalizedPetMode(outfit)
	if type(outfit) ~= "table" then
		return "Selected";
	end

	local mode = outfit.PetMode;
	if mode == "None" or mode == "Random" or mode == "Favorite" or mode == "Selected" then
		return mode;
	end

	return "Selected";
end

local function UpdatePetModeButtonHighlights(outfit)
	local mode = GetNormalizedPetMode(outfit);

	for key, button in pairs(PetModeButtons) do
		local selected = mode == key;
		if button.selectedBorder ~= nil then
			button.selectedBorder:SetShown(selected);
		end

		if selected then
			button:SetAlpha(1);
			button:LockHighlight();
		else
			button:SetAlpha(0.9);
			button:UnlockHighlight();
		end
	end
end

local function GetPetDataByGUID(petID)
	if petID == nil or petID == "" then
		return nil;
	end

	if PetDetailsCache[petID] ~= nil then
		return PetDetailsCache[petID];
	end

	if not MogCompanions:IsPetSummonableOwned(petID) then
		return nil;
	end

	local info = MogCompanions:GetPetInfoSafe(petID);
	if info == nil or info.name == nil or info.icon == nil then
		return nil;
	end

	local displayName;
	if info.customName ~= nil and info.customName ~= "" then
		displayName = info.customName .. " (" .. info.name .. ")";
	else
		displayName = info.name;
	end

	PetDetailsCache[petID] = {
		id = petID,
		name = displayName,
		customName = info.customName,
		speciesName = info.name,
		icon = info.icon,
		displayID = info.displayID,
		speciesID = info.speciesID,
	};

	return PetDetailsCache[petID];
end

local function IsValidPetSelection(petID)
	return type(petID) == "string"
		and petID ~= ""
		and MogCompanions:IsPetSummonableOwned(petID);
end

local function ValidatePetSelection(_, petID)
	return IsValidPetSelection(petID);
end

local function GetValidPetSelectionValues(outfit)
	return MogCompanions:GetValidSelectionPoolValues(outfit, "Pets", ValidatePetSelection);
end

local function GetValidPetSelection(outfit, preferLast, preferredPetID)
	if outfit == nil then
		return "";
	end

	if IsValidPetSelection(preferredPetID) then
		return preferredPetID;
	end

	local validSelections = GetValidPetSelectionValues(outfit);
	if #validSelections == 0 then
		return "";
	end

	if preferLast then
		return validSelections[#validSelections];
	end

	return validSelections[1];
end

local function SyncLegacyPetSelection(outfit)
	if outfit == nil then
		return "";
	end

	local petID = GetValidPetSelection(outfit, false);
	outfit.Pet = petID;
	return petID;
end

local function GetValidPetDataSelections(outfit)
	local validSelections = GetValidPetSelectionValues(outfit);
	local pets = {};

	for i = 1, #validSelections do
		local pet = GetPetDataByGUID(validSelections[i]);
		if pet ~= nil then
			table.insert(pets, pet);
		end
	end

	table.sort(pets, MogCompanionsSortAlphabetical);

	return pets;
end

local function PetMatchesSearch(pet)
	local searchString = MogCompanions.PetSearchString;
	if searchString == nil or searchString == "" then
		return true;
	end

	local lowered = searchString:lower();
	local displayName = pet ~= nil and pet.name or "";
	local speciesName = pet ~= nil and pet.speciesName or "";

	return string.find(displayName:lower(), lowered, 1, true) ~= nil
		or string.find(speciesName:lower(), lowered, 1, true) ~= nil;
end

local function GetFilteredNormalPets()
	local pets = MogCompanions:GetSortedPets();
	local filtered = {};

	for i = 1, #pets do
		if IsValidPetSelection(pets[i].id) then
			table.insert(filtered, pets[i]);
		end
	end

	return filtered;
end

local function GetFilteredSelectedPets(outfit)
	local pets = GetValidPetDataSelections(outfit);
	local filtered = {};

	for i = 1, #pets do
		if PetMatchesSearch(pets[i]) then
			table.insert(filtered, pets[i]);
		end
	end

	return filtered;
end

local function SetPetsSectionTitle(outfit)
	if PetsSlotTitle == nil then
		return;
	end
	if type(outfit) ~= "table" then
		outfit = nil;
	end
	local mode = GetNormalizedPetMode(outfit);
	if mode == "None" then
		PetsSlotTitle:SetText(L["Pets Tab Section Title"].." ("..(L["No Pet"] or "No Pet")..")");
	elseif mode == "Random" then
		PetsSlotTitle:SetText(L["Pets Tab Section Title"].." ("..(L["Random Pet"] or "Random Pet")..")");
	elseif mode == "Favorite" then
		PetsSlotTitle:SetText(L["Pets Tab Section Title"].." ("..(L["Random Favorite Pet"] or "Random Favorite Pet")..")");
	else
		local count = type(outfit) == "table" and #GetValidPetSelectionValues(outfit) or 0;
		if count > 0 then
			PetsSlotTitle:SetText(L["Pets Tab Section Title"].." "..string.format(L["Selected Count Format"], count));
		else
			PetsSlotTitle:SetText(L["Pets Tab Section Title"]);
		end
	end
end

local function GetPetTooltipLines(outfit)
	if not outfit then return {}, 0; end
	local mode = GetNormalizedPetMode(outfit);
	if mode == "None" then
		return {L["No Pet Tooltip"] or "No pet will be summoned for this outfit."}, 0;
	elseif mode == "Random" then
		return {L["Random Pet Tooltip"] or "A random owned summonable pet will be summoned for this outfit."}, 0;
	elseif mode == "Favorite" then
		return {L["Random Favorite Pet Tooltip"] or "A random owned favorite summonable pet will be summoned for this outfit."}, 0;
	end
	local pets = GetValidPetDataSelections(outfit);
	local tooltipLines = {};
	if #pets > 0 then
		table.insert(tooltipLines, string.format(L["Random From Selected Pets"], #pets));
		for i = 1, math.min(3, #pets) do
			table.insert(tooltipLines, "|T"..pets[i].icon..":18|t "..pets[i].name);
		end
		if #pets > 3 then
			table.insert(tooltipLines, string.format(L["More Selected Pets"], #pets - 3));
		end
	end
	return tooltipLines, #pets;
end

local function GetSelectedPet(outfitID)
	local outfit = GetOutfitTable(outfitID);
	local petID = GetValidPetSelection(outfit, false);

	if petID == nil or petID == "" then
		return nil;
	end

	return GetPetDataByGUID(petID);
end

local function EnsurePetModel()
	if PetPreview == nil then
		return nil;
	end

	if PetModel == nil then
		PetModel = CreateFrame("PlayerModel", "MogCompanionsPetModel", PetPreview);
		PetModel:SetPoint("TOPLEFT", PetPreview, "TOPLEFT", 12, -12);
		PetModel:SetPoint("BOTTOMRIGHT", PetPreview, "BOTTOMRIGHT", -12, 12);
		PetModel:SetPortraitZoom(0);
		PetModel:SetFacing(0.35);
		PetModel:SetAlpha(0);
		PetPreviewControls = MogCompanions:AttachPreviewModelControls(PetPreview, PetModel, {
			zoom = 1,
			minZoom = 0.4,
			maxZoom = 3.0,
			facing = 0.35,
			x = 0,
			y = 0,
			z = 0,
			buttonOffsetY = -8,
			controlNamePrefix = "MogCompanionsPetPreview",
		});
	end

	return PetModel;
end

local function UpdatePetPreview(pet)
	if type(pet) ~= "table" then
		pet = GetPetDataByGUID(pet);
	elseif pet.displayID == nil and pet.id ~= nil then
		pet = GetPetDataByGUID(pet.id);
	end

	if pet ~= nil and pet.displayID ~= nil and pet.displayID > 0 then
		local petModel = EnsurePetModel();
		if petModel == nil then
			return;
		end

		petModel:SetDisplayInfo(pet.displayID);
		if PetPreviewControls ~= nil then
			PetPreviewControls.reset();
		end
		petModel:SetAlpha(1);
	elseif PetModel ~= nil then
		PetModel:SetDisplayInfo(0);
		if PetPreviewControls ~= nil then
			PetPreviewControls.reset();
		end
		PetModel:SetAlpha(0);
	end
end

local function UpdatePetSlot()
	if PetFrame == nil or PetTexture == nil then
		return;
	end
	local outfit = GetOutfitTable(GetViewedOutfitID());
	local mode = GetNormalizedPetMode(outfit);
	if mode == "None" then
		PetTexture:SetTexture(PET_NO_PET_ICON);
		PetTexture:SetDesaturated(false);
		PetTexture:SetVertexColor(1, 1, 1);
		PetBorderTexture:SetAtlas("transmog-gearSlot-default");
		PetBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		PetTexture:SetAllPoints(PetFrame);
		PetFrame.texture = PetTexture;
		SetPetsSectionTitle(outfit);
		UpdatePetModeButtonHighlights(outfit);
		UpdatePetPreview(nil);
		return;
	elseif mode == "Random" then
		PetTexture:SetTexture(PET_RANDOM_ICON);
		PetTexture:SetDesaturated(false);
		PetTexture:SetVertexColor(1, 1, 1);
		PetBorderTexture:SetAtlas("transmog-gearSlot-default");
		PetBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		PetTexture:SetAllPoints(PetFrame);
		PetFrame.texture = PetTexture;
		SetPetsSectionTitle(outfit);
		UpdatePetModeButtonHighlights(outfit);
		UpdatePetPreview(nil);
		return;
	elseif mode == "Favorite" then
		PetTexture:SetTexture(PET_RANDOM_FAVORITE_ICON);
		PetTexture:SetDesaturated(false);
		PetTexture:SetVertexColor(1, 1, 1);
		PetBorderTexture:SetAtlas("transmog-gearSlot-default");
		PetBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		PetTexture:SetAllPoints(PetFrame);
		PetFrame.texture = PetTexture;
		SetPetsSectionTitle(outfit);
		UpdatePetModeButtonHighlights(outfit);
		UpdatePetPreview(nil);
		return;
	end
	local petID = SyncLegacyPetSelection(outfit);
	local pet = GetPetDataByGUID(petID);
	if pet ~= nil then
		PetTexture:SetTexture(pet.icon);
		PetTexture:SetDesaturated(false);
		PetTexture:SetVertexColor(1, 1, 1);
		PetBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
		PetBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
	else
		PetTexture:SetTexture(PET_EMPTY_ICON);
		PetTexture:SetDesaturated(true);
		PetTexture:SetVertexColor(0.63, 0.63, 0.63);
		PetBorderTexture:SetAtlas("transmog-gearSlot-default");
		PetBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	end
	PetTexture:SetAllPoints(PetFrame);
	PetFrame.texture = PetTexture;
	SetPetsSectionTitle(outfit);
	UpdatePetModeButtonHighlights(outfit);
	UpdatePetPreview(GetValidPetSelection(outfit, false, LastClickedPetID));
end

RefreshPetList = function(scrollToSelection)
	if PetsScrollView == nil then
		return;
	end

	local outfit = GetOutfitTable(GetViewedOutfitID());
	if outfit ~= nil then
		MogCompanions:PruneInvalidSelectionPool(outfit, "Pets", ValidatePetSelection);
		SyncLegacyPetSelection(outfit);
	end

	local selectedCount = #GetValidPetSelectionValues(outfit);
	if selectedCount <= 0 then
		ShowOnlySelectedPets = false;
	end

	local pets;
	if ShowOnlySelectedPets then
		pets = GetFilteredSelectedPets(outfit);
	else
		pets = GetFilteredNormalPets();
	end

	local selectedPetID = GetValidPetSelection(outfit, false);

	PetsDataProvider = CreateDataProvider(pets);
	PetsScrollView:SetDataProvider(PetsDataProvider);

	if scrollToSelection and PetsListScrollBox ~= nil and selectedPetID ~= nil and selectedPetID ~= "" then
		for i = 1, #pets do
			if pets[i].id == selectedPetID then
				PetsListScrollBox:ScrollToElementDataIndex(i);
				break;
			end
		end
	end

	SetPetsSectionTitle(outfit);
	MogCompanions:UpdateShowSelectedButton(PetShowSelectedButton, ShowOnlySelectedPets, selectedCount);
	MogCompanions:UpdateNoResultsText(PetNoResultsText, PetsSearchBox, #pets);
end

local function SetSelectedPet(petID)
	local outfit = GetOutfitTable(GetViewedOutfitID());
	if outfit == nil then
		return;
	end
	if petID == nil then
		petID = "";
	end
	if petID ~= "" and not IsValidPetSelection(petID) then
		return;
	end
	LastClickedPetID = petID;
	-- Any click on a pet row switches to Selected mode and clears other modes
	outfit.PetMode = "Selected";
	if petID == "" then
		MogCompanions:ClearSelectionPool(outfit, "Pets");
	else
		MogCompanions:ToggleSelectionPoolValue(outfit, "Pets", petID);
	end
	SyncLegacyPetSelection(outfit);
	UpdatePetSlot();
	UpdatePetPreview(GetValidPetSelection(outfit, false, LastClickedPetID));
	RefreshPetList(false);
	if PlaySound ~= nil and SOUNDKIT ~= nil and SOUNDKIT.UI_TRANSMOG_ITEM_CLICK ~= nil then
		PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
	end
end

local function ClearSelectedPet()
	ShowOnlySelectedPets = false;
	LastClickedPetID = nil;
	local outfit = GetOutfitTable(GetViewedOutfitID());
	if outfit then
		outfit.PetMode = "Selected";
	end
	SetSelectedPet("");
	if PetClear ~= nil then
		PetClear:Hide();
	end
end

local function EnsureOutfitPetSaved()
	if MogCompanionsCharacterSaved == nil or C_TransmogOutfitInfo == nil or C_TransmogOutfitInfo.GetOutfitsInfo == nil then
		return;
	end

	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo();

	if outfits == nil then
		return;
	end

	for i = 1, #outfits do
		MogCompanions:CreateEmptyOutfit(outfits[i].outfitID);
	end

	local viewedOutfitID = GetViewedOutfitID();
	if viewedOutfitID ~= nil then
		MogCompanions:CreateEmptyOutfit(viewedOutfitID);
	end
	end

local function CreatePetSlot()
	if PetFrame ~= nil or _G.MogCompanionsFrame == nil then
		return;
	end

	local borderSize = 59;
	local borderOffset = 7;

	PetFrame = CreateFrame("Frame", "MogCompanionsPetFrame", _G.MogCompanionsFrame);
	PetFrame:SetFrameStrata("MEDIUM");
	PetFrame:SetSize(44, 44);
	PetFrame:SetPoint("TOPLEFT", _G.MogCompanionsFrame, "TOPLEFT", 0, MogCompanions.TransmogSlotOffsets.Pet);
	PetFrame:Show();

	PetTexture = PetFrame:CreateTexture(nil, "BACKGROUND");

	PetBorder = CreateFrame("Frame", "MogCompanionsPetBorder", PetFrame);
	PetBorder:SetFrameStrata("HIGH");
	PetBorder:SetSize(borderSize, borderSize);
	PetBorder:SetPoint("TOPLEFT", PetFrame, "TOPLEFT", borderOffset * -1, borderOffset);
	PetBorder:Show();

	PetBorderTexture = PetBorder:CreateTexture(nil, "BACKGROUND");
	PetBorderTexture:SetAtlas("transmog-gearSlot-default");
	PetBorderTexture:SetAllPoints(PetBorder);
	PetBorder.texture = PetBorderTexture;

	PetBorderHighlight = CreateFrame("Frame", "MogCompanionsPetBorderHighlight", PetFrame);
	PetBorderHighlight:SetFrameStrata("HIGH");
	PetBorderHighlight:SetSize(borderSize, borderSize);
	PetBorderHighlight:SetPoint("TOPLEFT", PetFrame, "TOPLEFT", borderOffset * -1, borderOffset);
	PetBorderHighlight:Hide();

	PetBorderHighlightTexture = PetBorderHighlight:CreateTexture(nil, "BACKGROUND");
	PetBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	PetBorderHighlightTexture:SetAllPoints(PetBorderHighlight);
	PetBorderHighlightTexture:SetBlendMode("ADD");
	PetBorderHighlight.texture = PetBorderHighlightTexture;

	PetClear = CreateFrame("Button", "MogCompanionsPetClearButton", PetBorder, "UIResetButtonTemplate");
	PetClear:SetPoint("CENTER", PetBorder, "TOPRIGHT", -8, -8);
	PetClear:Hide();
	PetClear:SetScript("OnEnter", function()
		GameTooltip:SetOwner(PetClear, "ANCHOR_RIGHT");
		GameTooltip:SetText(L["Item Slot Pet Clear Tooltip"]);
		GameTooltip:Show();
		PetClear:Show();
	end)
	PetClear:SetScript("OnLeave", function()
		PetClear:Hide();
		GameTooltip:Hide();
	end)
	PetClear:SetScript("OnClick", function()
		ClearSelectedPet();
	end)

	PetBorder:HookScript("OnEnter", function()
		GameTooltip:SetOwner(PetBorder, "ANCHOR_RIGHT");

		local outfit = GetOutfitTable(GetViewedOutfitID());
		local mode = GetNormalizedPetMode(outfit);
		local tooltipLines, count = GetPetTooltipLines(outfit);

		if #tooltipLines > 0 then
			GameTooltip:AddLine(L["Item Slot Pet Title"]);
			if mode == "None" then
				GameTooltip:AddLine(L["No Pet"] or "No Pet", 1, 0.82, 0);
			elseif mode == "Random" then
				GameTooltip:AddLine(L["Random Pet"] or "Random Pet", 1, 0.82, 0);
			elseif mode == "Favorite" then
				GameTooltip:AddLine(L["Random Favorite Pet"] or "Random Favorite Pet", 1, 0.82, 0);
			end
			for i = 1, #tooltipLines do
				GameTooltip:AddLine(tooltipLines[i], 1, 1, 1, true);
			end
			if count > 0 or mode ~= "Selected" then
				PetClear:Show();
			end
		else
			GameTooltip:SetText(L["Item Slot Pet Title"]);
		end
		GameTooltip:Show();
		PetBorderHighlight:Show();
	end)

	PetBorder:HookScript("OnLeave", function()
		GameTooltip:Hide();
		PetBorderHighlight:Hide();
		PetClear:Hide();
	end)

	PetBorder:SetScript("OnMouseDown", function()
		MogCompanions:OpenCompanionsTab("Pets");
		PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
	end)

	UpdatePetSlot();
	end

function MogCompanions:CreatePetMacro(parent, options)
	if InCombatLockdown and InCombatLockdown() then
		print(L["Macro Combat Error"]);
		return nil;
	end

	local updateExistingOnly = options == true or (type(options) == "table" and options.updateExistingOnly == true);
	local macroId = MogCompanions:FindMacroByExactName("MComp Pets");
	if updateExistingOnly and macroId == nil then
		return nil;
	end

	local macroIcon = 656575;
	local outfitData = MogCompanions:GetActiveOutfitTable();
	local selectedPet = outfitData and GetPetDataByGUID(SyncLegacyPetSelection(outfitData));
	if MogCompanionsSaved ~= nil and MogCompanionsSaved.DynamicPetMacroIcon == true and selectedPet ~= nil then
		macroIcon = selectedPet.icon or 656575;
	end

	local macroBody = "#mcomp:pet\n/mcomp pet";
	if macroId == nil then
		macroId = CreateMacro("MComp Pets", macroIcon, macroBody, nil);
	else
		EditMacro(macroId, "MComp Pets", macroIcon, macroBody, nil);
	end

	if parent ~= nil then
		PickupMacro(macroId);
		GameTooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT");
		GameTooltip:AddLine(L["Drop Pet Macro Tooltip"], 1, 1, 1);
		GameTooltip:Show();
	end

	return macroId;
end

-- Creates the pets tab page: preview model on the left and scrollable pet list on the right.
-- Idempotent: reparents the existing frame if needed and refreshes the list contents.
function MogCompanions:CreatePetsFrame(parent)
	if parent == nil then
		return nil;
	end
	if PetsFrame ~= nil then
		if PetsFrame:GetParent() ~= parent then
			PetsFrame:SetParent(parent);
			PetsFrame:ClearAllPoints();
			PetsFrame:SetAllPoints(parent);
		end
		return PetsFrame;
	end
	PetsFrame = CreateFrame("Frame", "MogCompanionsPetsFrame", parent);
	PetsFrame:SetAllPoints(parent);
	PetsFrame:Hide();
	local topOffset = 26;
	local listRightInset = 28;
	local previewWidth = 308;
	local previewInset = 12;
	local PetsShortcuts = MogCompanions:CreateCompanionsShortcutMenu(PetsFrame, "MogCompanionsPetsShortcuts");
	PetsShortcuts:SetPoint("TOPRIGHT", PetsFrame, "TOPRIGHT", -26, -50 + topOffset);

	-- Search box aligned directly beside the gear shortcut button.
	PetsSearchBox = CreateFrame("EditBox", "MogCompanionsPetsSearchBox", PetsFrame, "TransmogSearchBoxTemplate");
	PetsSearchBox:SetPoint("TOPRIGHT", PetsShortcuts, "TOPLEFT", -8, 0);
	if PetsSearchBox.searchIcon ~= nil then
		local iconPos, iconParent, iconParentPos, iconX, iconY = PetsSearchBox.searchIcon:GetPoint();
		PetsSearchBox.searchIcon:SetPoint(iconPos, iconParent, iconParentPos, iconX, iconY + 1);
	end
	PetsSearchBox:SetScript("OnTextChanged", function(self)
		if SearchBoxTemplate_OnTextChanged ~= nil then
			SearchBoxTemplate_OnTextChanged(self);
		end
		MogCompanions.PetSearchString = self:GetText() or "";
		RefreshPetList(true);
	end)

	-- Section title (matching the Mounts tab layout style)
	PetsSlotTitle = PetsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
	PetsSlotTitle:SetJustifyH("LEFT");
	PetsSlotTitle:SetPoint("TOPLEFT", PetsFrame, "TOPLEFT", 24, -76 + topOffset);
	PetsSlotTitle:SetText(L["Pets Tab Section Title"]);

	local PetsSlotTitleDivider = PetsFrame:CreateTexture();
	PetsSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
	PetsSlotTitleDivider:SetAlpha(0.1);
	PetsSlotTitleDivider:SetPoint("TOPLEFT", PetsSlotTitle, "BOTTOMLEFT", 0, -2);

	PetPreview = CreateFrame("Frame", "MogCompanionsPetPreview", PetsFrame);
	PetPreview:SetPoint("TOPLEFT", PetsFrame, "TOPLEFT", 24, -113 + topOffset);
	PetPreview:SetPoint("BOTTOMLEFT", PetsFrame, "BOTTOMLEFT", 24, 42);
	PetPreview:SetWidth(previewWidth);
	PetPreview:SetFrameStrata("HIGH");

	local PetsPreviewBackground = PetPreview:CreateTexture(nil, "BACKGROUND");
	PetsPreviewBackground:SetAtlas("professions-recipe-background");
	PetsPreviewBackground:SetPoint("TOPLEFT", PetPreview, "TOPLEFT", 6, -6);
	PetsPreviewBackground:SetPoint("BOTTOMRIGHT", PetPreview, "BOTTOMRIGHT", -6, 6);
	PetsPreviewBackground:SetAlpha(1);
	PetsPreviewBackground:SetVertexColor(0, 0, 0);

	local PetsPreviewBorder = PetPreview:CreateTexture(nil, "OVERLAY");
	PetsPreviewBorder:SetAtlas("transmog-itemCard-default", true);
	PetsPreviewBorder:SetAllPoints(PetPreview);

	-- List container (right side; 42 px bottom margin for the sub-tab bar)
	local PetsList = CreateFrame("Frame", "MogCompanionsPetsListFrame", PetsFrame);
	PetsList:SetPoint("TOPLEFT", PetPreview, "TOPRIGHT", 16, 0);
	PetsList:SetPoint("BOTTOMRIGHT", PetsFrame, "BOTTOMRIGHT", -listRightInset, 42);
	PetsList:SetFrameStrata("HIGH");

	-- Pet mode buttons sit above the list contents (inside the list panel, not header UI).
	local modeButtonWidth = 30;
	local modeButtonHeight = 30;
	local modeSpacing = 6;
	PetModeButtons = {};
	local modeDefs = {
		{ key = "None", label = L["No Pet"] or "No Pet", icon = PET_NO_PET_ICON, tooltip = L["No Pet Tooltip"] or "No pet will be summoned for this outfit.", iconInset = 0 },
		{ key = "Random", label = L["Random Pet"] or "Random Pet", icon = PET_RANDOM_ICON, tooltip = L["Random Pet Tooltip"] or "A random owned summonable pet will be summoned for this outfit.", iconInset = 0 },
		{ key = "Favorite", label = L["Random Favorite Pet"] or "Random Favorite Pet", icon = PET_RANDOM_FAVORITE_ICON, tooltip = L["Random Favorite Pet Tooltip"] or "A random owned favorite summonable pet will be summoned for this outfit.", iconInset = -2 },
	};
	for i, def in ipairs(modeDefs) do
		local btn = CreateFrame("Button", nil, PetsFrame, "UIPanelButtonTemplate");
		btn:SetSize(modeButtonWidth, modeButtonHeight);
		btn:SetPoint("BOTTOMLEFT", PetsList, "TOPLEFT", 12 + (i-1) * (modeButtonWidth + modeSpacing), 6);
		btn:SetFrameStrata("HIGH");
		btn:SetFrameLevel(PetsList:GetFrameLevel() + 5);
		btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
		btn.icon = btn:CreateTexture(nil, "ARTWORK");
		btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", def.iconInset, def.iconInset * -1);
		btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", def.iconInset * -1, def.iconInset);
		btn.icon:SetTexture(def.icon);
		btn.selectedBorder = btn:CreateTexture(nil, "OVERLAY");
		btn.selectedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
		btn.selectedBorder:SetBlendMode("ADD");
		btn.selectedBorder:SetAlpha(0.9);
		btn.selectedBorder:SetSize(modeButtonWidth + 18, modeButtonHeight + 18);
		btn.selectedBorder:SetPoint("CENTER", btn, "CENTER", 0, 0);
		btn.selectedBorder:Hide();
		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(def.label);
			if def.tooltip ~= nil and def.tooltip ~= "" then
				GameTooltip:AddLine(def.tooltip, 1, 1, 1, true);
			end
			GameTooltip:Show();
		end)
		btn:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end)
		btn:SetScript("OnClick", function()
			local outfit = GetOutfitTable(GetViewedOutfitID());
			if outfit then
				outfit.PetMode = def.key;
				MogCompanions:ClearSelectionPool(outfit, "Pets");
				LastClickedPetID = nil;
				UpdatePetSlot();
				RefreshPetList(false);
			end
		end)
		PetModeButtons[def.key] = btn;
	end

	UpdatePetModeButtonHighlights(GetOutfitTable(GetViewedOutfitID()));

	PetShowSelectedButton = CreateFrame("Button", nil, PetsFrame, "UIPanelButtonTemplate");
	PetShowSelectedButton:SetSize(110, 22);
	PetShowSelectedButton:SetPoint("BOTTOMRIGHT", PetsList, "TOPRIGHT", 0, 4);
	PetShowSelectedButton:SetText(L["Show Selected"]);
	PetShowSelectedButton:Hide();
	PetShowSelectedButton:SetScript("OnClick", function()
		ShowOnlySelectedPets = not ShowOnlySelectedPets;
		RefreshPetList(false);
	end);

	local PetsListBackground = PetsList:CreateTexture(nil, "OVERLAY");
	PetsListBackground:SetAtlas("transmog-situations-containerbg", true);
	PetsListBackground:SetAllPoints(true);

	PetNoResultsText = PetsList:CreateFontString(nil, "OVERLAY", "GameFontDisable");
	PetNoResultsText:SetPoint("CENTER", PetsList, "CENTER", 0, 0);
	PetNoResultsText:SetText(L["No Items Match Search"]);
	PetNoResultsText:Hide();

	-- ScrollBox
	PetsListScrollBox = CreateFrame("Frame", "MogCompanionsPetsScrollBox", PetsList, "WowScrollBoxList");
	PetsListScrollBox:SetPoint("TOPLEFT", PetsList, "TOPLEFT", 12, -2);
	PetsListScrollBox:SetPoint("BOTTOMRIGHT", PetsList, "BOTTOMRIGHT", -40, 4);

	-- ScrollBar
	local PetsScrollBar = CreateFrame("EventFrame", nil, PetsList, "MinimalScrollBar");
	PetsScrollBar:SetPoint("TOPLEFT", PetsListScrollBox, "TOPRIGHT", 10, -6);
	PetsScrollBar:SetPoint("BOTTOMLEFT", PetsListScrollBox, "BOTTOMRIGHT", 10, 6);
	PetsScrollBar:SetHideIfUnscrollable(true);

	PetsDataProvider = CreateDataProvider();
	PetsScrollView = CreateScrollBoxListLinearView();
	PetsScrollView:SetElementInitializer("MogCompanionsMultiSelectListButtonTemplate", function(button, data)
		local outfit = GetOutfitTable(GetViewedOutfitID());
		local isSelected = outfit ~= nil and MogCompanions:IsInSelectionPool(outfit, "Pets", data.id);
		button.Name:SetText("|T"..data.icon..":18|t "..data.name);
		button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
		if button.CheckboxCheck ~= nil then
			button.CheckboxCheck:SetShown(isSelected);
		end
		if isSelected then
			button:LockHighlight();
		else
			button:UnlockHighlight();
		end
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:AddLine(data.name);
			GameTooltip:AddLine("|cFFFFFFFF"..L["Item Slot Pet Title"].."|r");
			GameTooltip:Show();
			UpdatePetPreview(data);
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide();
			local viewedOutfit = GetOutfitTable(GetViewedOutfitID());
			UpdatePetPreview(GetValidPetSelection(viewedOutfit, false, LastClickedPetID));
		end)
		button:SetScript("OnClick", function()
			SetSelectedPet(data.id);
		end)
	end);
	PetsScrollView:SetElementExtent(22);
	ScrollUtil.InitScrollBoxListWithScrollBar(PetsListScrollBox, PetsScrollBar, PetsScrollView);
	PetsScrollView:SetDataProvider(PetsDataProvider);
	return PetsFrame;
end

local function InitializePets()
	if TransmogFrame == nil or TransmogFrame.WardrobeCollection == nil then
		return;
	end

	EnsureOutfitPetSaved();
	CreatePetSlot();

	UpdatePetSlot();

	if PetsFrame ~= nil and PetsFrame:IsShown() then
		UpdatePetPreview(GetSelectedPet(GetViewedOutfitID()));
		RefreshPetList(true);
	end
end

local function ScheduleInitializePets()
	if PetsInitScheduled then
		return;
	end

	PetsInitScheduled = true;

	C_Timer.After(0.25, InitializePets);
	C_Timer.After(0.75, function()
		InitializePets();
		PetsInitScheduled = false;
	end);
end

local PetEventFrame = CreateFrame("Frame");
PetEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
PetEventFrame:RegisterEvent("PET_JOURNAL_LIST_UPDATE");
PetEventFrame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_CHANGED");
PetEventFrame:RegisterEvent("TRANSMOG_DISPLAYED_OUTFIT_CHANGED");

local function IsTransmogShown()
	return TransmogFrame ~= nil and TransmogFrame:IsShown();
end

PetEventFrame:SetScript("OnEvent", function(self, event)
	EnsureOutfitPetSaved();

	if event == "PLAYER_ENTERING_WORLD" then
		return;
	end

	if event == "PET_JOURNAL_LIST_UPDATE" then
		PetDetailsCache = {};
		MogCompanions:InvalidateSortedPetsCache();

		if not IsTransmogShown() then
			return;
		end

		UpdatePetSlot();

		if PetsFrame ~= nil and PetsFrame:IsShown() then
			UpdatePetPreview(GetSelectedPet(GetViewedOutfitID()));
			RefreshPetList(false);
		end

		return;
	end

	if event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" or event == "TRANSMOG_DISPLAYED_OUTFIT_CHANGED" then
		ShowOnlySelectedPets = false;
	end

	if not IsTransmogShown() then
		return;
	end

	ScheduleInitializePets();
	UpdatePetSlot();

	if PetsFrame ~= nil and PetsFrame:IsShown() then
		UpdatePetPreview(GetSelectedPet(GetViewedOutfitID()));
		RefreshPetList(false);
	end
end)

local function HookTransmogFrame()
	if TransmogFrame ~= nil then
		TransmogFrame:HookScript("OnShow", function()
			ScheduleInitializePets();
		end)
		ScheduleInitializePets();
	else
		C_Timer.After(1, HookTransmogFrame);
	end
end

HookTransmogFrame();

function MogCompanions:ShowPetsPage()
	if PetsFrame == nil then
		if _G.MogCompanionsCompanionsFrame ~= nil then
			MogCompanions:CreatePetsFrame(_G.MogCompanionsCompanionsFrame);
		end
	end

	if PetsFrame ~= nil then
		PetsFrame:Show();
	end

	UpdatePetPreview(GetSelectedPet(GetViewedOutfitID()));
	RefreshPetList(true);
end

function MogCompanions:HidePetsPage()
	if PetsFrame ~= nil then
		PetsFrame:Hide();
	end
end

-- When the player hovers over the MComp Pets macro on an action bar, append a
-- line describing what the macro will do based on the active outfit's pet mode.
-- We use TooltipDataProcessor.AddTooltipPostCall so the line is added after
-- Blizzard has already populated the rest of the macro tooltip.
do
	local macroTooltipType = type(Enum) == "table"
		and type(Enum.TooltipDataType) == "table"
		and Enum.TooltipDataType.Macro;

	if macroTooltipType
		and type(TooltipDataProcessor) == "table"
		and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
	then
		TooltipDataProcessor.AddTooltipPostCall(macroTooltipType, function(tooltip)
			-- Sanity-check the tooltip object before using it.
			if not tooltip or type(tooltip.AddLine) ~= "function" then return end;

			-- The tooltip's infoList holds one entry per action button that
			-- triggered the tooltip. We only care about the first entry.
			local infoList = tooltip.infoList;
			local firstEntry = type(infoList) == "table" and infoList[1];
			if not firstEntry then return end;

			-- Confirm this is actually a macro tooltip, not some other type.
			local data = firstEntry.tooltipData;
			if not data or data.type ~= macroTooltipType then return end;

			-- getterArgs[1] is the action bar slot number.
			local args = firstEntry.getterArgs;
			local actionSlot = type(args) == "table" and args[1];
			if not actionSlot then return end;

			-- Resolve the action slot to a macro index.
			if type(GetActionInfo) ~= "function" then return end;
			local actionType, macroIndex = GetActionInfo(actionSlot);
			if actionType ~= "macro" or not macroIndex then return end;

			-- Only handle macros created by MogCompanions (identified by the
			-- #mcomp:pet marker at the start of the body).
			if type(GetMacroBody) ~= "function" then return end;
			local body = GetMacroBody(macroIndex);
			if type(body) ~= "string" or body:sub(1, 10) ~= "#mcomp:pet" then return end;

			-- Pick a label that matches what /mcomp pet will actually do.
			local outfit = MogCompanions:GetActiveOutfitTable();
			local mode = GetNormalizedPetMode(outfit);

			local label;
			if mode == "None" then
				-- "No Pet" mode dismisses the current companion.
				label = L["Pet Macro Tooltip None"];
			elseif mode == "Favorite" then
				-- "Favorite" mode summons a random favorite pet.
				label = L["Pet Macro Tooltip Favorite"];
			elseif mode == "Selected" then
				-- Show the specific pet's name, or fall back to random if the
				-- outfit has no valid pet assigned.
				local pet = outfit and GetPetDataByGUID(SyncLegacyPetSelection(outfit));
				label = (pet and pet.name) or L["Pet Macro Tooltip Random"];
			else
				-- "Random" mode and any unrecognised mode summon a random pet.
				label = L["Pet Macro Tooltip Random"];
			end

			tooltip:AddLine(label, 1, 1, 1);

			if type(tooltip.Show) == "function" then
				tooltip:Show();
			end
		end);
	end
end