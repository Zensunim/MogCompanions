-- Pets.lua
-- Placeholder pets tab inside the Companions wardrobe sub-interface.
-- Creates an empty scrollable list and standard UI chrome (search box, section title).
-- No pet logic is implemented yet; the data provider stays empty.
local _, addon = ...;
local ns = select(2, ...);
local MogCompanions = ns.MogCompanions;
local L = MogCompanionsLocales;

local PetsFrame;

-- Idempotent: returns early if PetsFrame already exists.
-- Creates the Pets placeholder page parented directly to the given frame.
-- Contains: search box, section title, scrollable empty list + scrollbar.
-- No C_PetJournal calls; data provider stays empty until pet logic is added.
function MogCompanions:CreatePetsFrame(parent)
	if PetsFrame ~= nil then
		return PetsFrame;
	end

	if parent == nil then
		return nil;
	end

	PetsFrame = CreateFrame("Frame", "MogCompanionsPetsFrame", parent);
	PetsFrame:SetAllPoints(parent);
	PetsFrame:Hide();

	-- Search box (matching Mounts and Hearthstones tab position)
	local PetsSearchBox = CreateFrame("EditBox", "MogCompanionsPetsSearchBox", PetsFrame, "TransmogSearchBoxTemplate");
	PetsSearchBox:SetPoint("TOPRIGHT", PetsFrame, "TOPRIGHT", -174, -50);
	if PetsSearchBox.searchIcon ~= nil then
		local iconPos, iconParent, iconParentPos, iconX, iconY = PetsSearchBox.searchIcon:GetPoint();
		PetsSearchBox.searchIcon:SetPoint(iconPos, iconParent, iconParentPos, iconX, iconY + 1);
	end

	-- Section title (matching Hearthstones tab style)
	local PetsSlotTitle = PetsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
	PetsSlotTitle:SetJustifyH("LEFT");
	PetsSlotTitle:SetPoint("TOPLEFT", PetsFrame, "TOPLEFT", 24, -76);
	PetsSlotTitle:SetText(L["Pets Tab Title"]);

	local PetsSlotTitleDivider = PetsFrame:CreateTexture();
	PetsSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
	PetsSlotTitleDivider:SetAlpha(0.1);
	PetsSlotTitleDivider:SetPoint("TOPLEFT", PetsSlotTitle, "BOTTOMLEFT", 0, -2);

	-- List container (full-width, no preview panel; 42 px bottom margin for sub-tab bar)
	local PetsList = CreateFrame("Frame", "MogCompanionsPetsListFrame", PetsFrame);
	PetsList:SetPoint("TOPLEFT", PetsFrame, "TOPLEFT", 24, -113);
	PetsList:SetPoint("BOTTOMRIGHT", PetsFrame, "BOTTOMRIGHT", -8, 42);
	PetsList:SetFrameStrata("HIGH");

	local PetsListBackground = PetsList:CreateTexture(nil, "OVERLAY");
	PetsListBackground:SetAtlas("transmog-situations-containerbg", true);
	PetsListBackground:SetAllPoints(true);

	-- ScrollBox
	local PetsScrollBox = CreateFrame("Frame", "MogCompanionsPetsScrollBox", PetsList, "WowScrollBoxList");
	PetsScrollBox:SetPoint("TOPLEFT", PetsList, "TOPLEFT", 12, -2);
	PetsScrollBox:SetPoint("BOTTOMRIGHT", PetsList, "BOTTOMRIGHT", -40, 4);

	-- ScrollBar
	local PetsScrollBar = CreateFrame("EventFrame", nil, PetsList, "MinimalScrollBar");
	PetsScrollBar:SetPoint("TOPLEFT", PetsScrollBox, "TOPRIGHT", 10, -6);
	PetsScrollBar:SetPoint("BOTTOMLEFT", PetsScrollBox, "BOTTOMRIGHT", 10, 6);
	PetsScrollBar:SetHideIfUnscrollable(true);

	-- Empty data provider and scroll view (no pet logic yet)
	local PetsDataProvider = CreateDataProvider();
	local PetsScrollView = CreateScrollBoxListLinearView();
	PetsScrollView:SetElementInitializer("MogCompanionsListButtonTemplate", function(button, data) end);
	PetsScrollView:SetElementExtent(22);
	ScrollUtil.InitScrollBoxListWithScrollBar(PetsScrollBox, PetsScrollBar, PetsScrollView);
	PetsScrollView:SetDataProvider(PetsDataProvider);

	return PetsFrame;
end