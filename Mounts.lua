-- Mounts.lua
-- Contains all mount summon logic and the full mount UI inside the Transmog wardrobe.
--
-- Summon priority (MogCompanionsSummon):
--   1. Exit vehicle (CanExitVehicle)
--   2. Dismount if already mounted
--   3. Control + swimming → aquatic mount
--   4. Shift → special/repair mount
--   5. Alt → alternative mount
--   6. Flyable area, no Control → flying mount
--   7. Fallback → ground mount
--
-- UI sections:
--   • Flying/ground mount slot icons in CharacterPreview.RightSlots (InitMountSlots)
--   • Mounts tab in WardrobeCollection with model previews + scrollable lists (InitMountTab)
--   • Setup reminder banner shown when no keybind or macro exists
--
-- SetSelectedFlyingMount / SetSelectedGroundMount are defined inside InitMountTab
-- (they close over local scroll-box references) and are forward-declared at file scope.
local _, addon = ...;
local ns = select(2, ...);
local MogCompanions = ns.MogCompanions;
local L = MogCompanionsLocales;

local MogCompanionsFrame;
local flyingMountFrame, flyingMountTexture, flyingMountBorder, flyingMountBorderTexture, flyingMountBorderHighlightTexture;
local groundMountFrame, groundMountTexture, groundMountBorder, groundMountBorderTexture, groundMountBorderHighlightTexture;

local FlyingMountPreview, GroundMountPreview;
local FlyingMountModel, GroundMountModel;

local FlyingMountListScrollBox, FlyingMountSelectionBehavior;

local GroundMountListScrollView, GroundMountListScrollBox, GroundMountListScrollBar, GroundMountSelectionBehavior;

local FlyingMountClear, GroundMountClear;
local SetSelectedFlyingMount, SetSelectedGroundMount;

local SetupReminderFrame;
local MountListSearchBox, FilterDropdown;

local CheckboxShowFlyingInGroundList;

MogCompanions.MountSearchString = "";

MogCompanionsSelectedMount = {}
MogCompanionsSelectedMount.Flying = {}
MogCompanionsSelectedMount.Ground = {}

-- Returns race-appropriate placeholder icons for the flying and ground mount slots.
-- Used when no mount has been selected (slot shows a desaturated icon).
local function getEmptyMountIcon()
	local _, raceName, raceID = UnitRace("Player");

	local emptyFlyingMountIcon = 0;
	local emptyGroundMountIcon = 0;

	if raceID == 1 then 	-- Human
		emptyFlyingMountIcon = 773274;
		emptyGroundMountIcon = 2143092;
	elseif raceID == 2 then -- Orc
		emptyFlyingMountIcon = 773276;
		emptyGroundMountIcon = 132224;
	elseif raceID == 3 then -- Dwarf
		emptyFlyingMountIcon = 294468;
		emptyGroundMountIcon = 132248;
	elseif raceID == 4 then -- Night Elf
		emptyFlyingMountIcon = 2020396;
		emptyGroundMountIcon = 132225;
	elseif raceID == 5 then -- Undead
		emptyFlyingMountIcon = 1321546;
		emptyGroundMountIcon = 132264;
	elseif raceID == 6 then -- Tauren
		emptyFlyingMountIcon = 773276;
		emptyGroundMountIcon = 132243;
	elseif raceID == 7 then -- Gnome
		emptyFlyingMountIcon = 132240;
		emptyGroundMountIcon = 132247;
	elseif raceID == 8 then -- Troll
		emptyFlyingMountIcon = 1321546;
		emptyGroundMountIcon = 132253;
	elseif raceID == 9 then -- Goblin
		emptyFlyingMountIcon = 6126218;
		emptyGroundMountIcon = 1408996;
	elseif raceID == 10 then -- Blood Elf
		emptyFlyingMountIcon = 132188;
		emptyGroundMountIcon = 132227;
	elseif raceID == 11 then -- Draenei
		emptyFlyingMountIcon = 132191;
		emptyGroundMountIcon = 132254; --132260
	elseif raceID == 22 then -- Worgen
		emptyFlyingMountIcon = 2020396;
		emptyGroundMountIcon = 132261;
	elseif raceID == 24 or raceID == 25 or raceID == 26 then -- Pandaren
		emptyFlyingMountIcon = 648627;
		emptyGroundMountIcon = 656344;
	elseif raceID == 27 then -- Nightborne
		emptyFlyingMountIcon = 132265;
		emptyGroundMountIcon = 1781067;
	elseif raceID == 29 then -- Void Elf
		emptyFlyingMountIcon = 464141;
		emptyGroundMountIcon = 1786404;
	elseif raceID == 30 then -- Lightforged Draenei
		emptyFlyingMountIcon = 1570763;
		emptyGroundMountIcon = 1713157;
	elseif raceID == 31 then -- Zandalari Troll
		emptyFlyingMountIcon = 1624590;
		emptyGroundMountIcon = 1869253;
	elseif raceID == 32 then -- Kul Tiran
		emptyFlyingMountIcon = 773275;
		emptyGroundMountIcon = 2238243;
	elseif raceID == 34 then -- Dark Iron Dwarf
		emptyFlyingMountIcon = 526578;
		emptyGroundMountIcon = 1992951;	
	elseif raceID == 35 then -- Vulpera
		emptyFlyingMountIcon = 1929247;
		emptyGroundMountIcon = 3045400;
	elseif raceID == 36 then -- Maghar Orc
		emptyFlyingMountIcon = 298596;
		emptyGroundMountIcon = 1937816;
	elseif raceID == 37 then -- Mechagnome
		emptyFlyingMountIcon = 2574427;
		emptyGroundMountIcon = 3041211;	
	elseif raceID == 52 or raceID == 70 then -- Dracthyr
		emptyFlyingMountIcon = 4622497;
		emptyGroundMountIcon = 4731151;
	elseif raceID == 84 or raceID == 85 then -- Earthen
		emptyFlyingMountIcon = 5306251;
		emptyGroundMountIcon = 5767167;
	else
		emptyFlyingMountIcon = 773274;
		emptyGroundMountIcon = 2143092;
	end		

	return emptyFlyingMountIcon, emptyGroundMountIcon;
end

-- ── Mount Summon Functions ──────────────────────────────────────────────────────
-- Priority: per-outfit mount → default specific mount → random from category.
-- All four helpers are called from MogCompanionsSummon based on conditions.
function MogCompanionsSummonFlying()
	if MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying > 1 then
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying);
	elseif MogCompanionsCharacterSaved.Default.Flying <= 1 then
		local randomMount = MogCompanions:getRandomMount("flying");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	else
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved.Default.Flying);
	end
end

function MogCompanionsSummonGround()
	if MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground > 1 then
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground);
	elseif MogCompanionsCharacterSaved.Default.Ground <= 1 then
		local randomMount = MogCompanions:getRandomMount("ground");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	else
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved.Default.Ground);
	end
end

function MogCompanionsSummonAquatic()
	if MogCompanionsCharacterSaved.Default.Aquatic <= 1 then
		local randomMount = MogCompanions:getRandomMount("aquatic");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	else
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved.Default.Aquatic);
	end
end

function MogCompanionsSummonSpecial()
	if MogCompanionsCharacterSaved.Default.Special <= 1 then
		local randomMount = MogCompanions:getRandomMount("special");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	else
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved.Default.Special);
	end
end

function MogCompanionsSummonAlternative()
	if MogCompanionsCharacterSaved.Default.Alternative <= 1 then
		local randomMount = MogCompanions:getRandomMount("alternative");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	else
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved.Default.Alternative);
	end
end

-- Main mount/dismount entry point. Evaluates current state and modifier keys
-- to determine which category to summon, then calls the appropriate helper.
-- Also applies the per-outfit title after summoning via MogCompanions:UpdateTitle().
function MogCompanionsSummon()
	if CanExitVehicle() then

		VehicleExit();

	elseif IsMounted() then

		-- Dismount
		Dismount();

	elseif IsSwimming() and IsControlKeyDown() then

		-- Aquatic mount
		MogCompanionsSummonAquatic();

	elseif IsShiftKeyDown() then

		-- Repair bear, yak, or long boi
		MogCompanionsSummonSpecial();

	elseif IsAltKeyDown() then

		-- Alternative mount, whatever the player wants it to be
		MogCompanionsSummonAlternative();

	elseif IsFlyableArea() and not IsControlKeyDown() then

		-- Flyable
		MogCompanionsSummonFlying();

	else

		-- Ground or when control key is pressed
		MogCompanionsSummonGround();

	end

	MogCompanions:UpdateTitle();
end

-- ── Mount Slot UI (CharacterPreview) ─────────────────────────────────────────
-- Creates the flying and ground mount slot icons beside the outfit preview.
-- reset=true builds the frames (first call only); subsequent calls just refresh icons.
-- Hooks OnEnter/OnLeave/OnMouseDown on the slot borders each time (reset=true only).
-- Do NOT call during combat — creates and reparents frames.
function MogCompanions:InitMountSlots(reset)
	if reset then

		local point, relativeTo, relativePoint, xOfs, yOfs = TransmogFrame.CharacterPreview.RightSlots:GetPoint();
		TransmogFrame.CharacterPreview.RightSlots:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs + 80);

		MogCompanionsFrame = CreateFrame("Frame", "MogCompanionsFrame", TransmogFrame.CharacterPreview.RightSlots);
		MogCompanionsFrame:SetFrameStrata("MEDIUM");
		MogCompanionsFrame:SetSize(44, 120);

		local point, relativeTo, relativePoint, xOfs, yOfs = TransmogFrame.CharacterPreview.RightSlots:GetPoint();
		MogCompanionsFrame:SetPoint("TOPLEFT", TransmogFrame.CharacterPreview.RightSlots, "BOTTOMLEFT", xOfs + 35, yOfs - 124);
		
		-- Flying Mount Frame

		flyingMountFrame = CreateFrame("Frame", "FlyingMountFrame", MogCompanionsFrame);
		flyingMountFrame:SetFrameStrata("MEDIUM");
		flyingMountFrame:SetSize(44, 44);

		local point, relativeTo, relativePoint, xOfs, yOfs = MogCompanionsFrame:GetPoint();
		flyingMountFrame:SetPoint("TOPLEFT", MogCompanionsFrame, "TOPLEFT", 0, 0);
		flyingMountFrame:Show();

		flyingMountTexture = flyingMountFrame:CreateTexture(nil,"BACKGROUND");

		-- Flying Mount Border

		local borderSize = 59;
		local borderOffset = 7;

		local appearanceSlotInfo, illusionSlotInfo = C_TransmogOutfitInfo.GetAllSlotLocationInfo();

		flyingMountBorder = CreateFrame("Frame", "FlyingMountBorder", flyingMountFrame);
		flyingMountBorder:SetFrameStrata("HIGH");
		flyingMountBorder:SetSize(borderSize, borderSize);

		flyingMountBorderTexture = flyingMountBorder:CreateTexture(nil,"BACKGROUND");
		flyingMountBorderTexture:SetAtlas("transmog-gearSlot-default");
		flyingMountBorderTexture:SetAllPoints(flyingMountBorder);
		flyingMountBorder.texture = flyingMountBorderTexture;

		local point, relativeTo, relativePoint, xOfs, yOfs = flyingMountFrame:GetPoint();
		flyingMountBorder:SetPoint("TOPLEFT", flyingMountFrame, "TOPLEFT", borderOffset * -1, borderOffset);
		flyingMountBorder:Show();

		-- Flying Mount Border Highlight

		flyingMountBorderHighlight = CreateFrame("Frame", "FlyingMountBorderHighlight", flyingMountFrame);
		flyingMountBorderHighlight:SetFrameStrata("HIGH");
		flyingMountBorderHighlight:SetSize(borderSize, borderSize);
		
		flyingMountBorderHighlightTexture = flyingMountBorderHighlight:CreateTexture(nil,"BACKGROUND");
		flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		flyingMountBorderHighlightTexture:SetAllPoints(flyingMountBorderHighlight);
		flyingMountBorderHighlightTexture:SetBlendMode("ADD");
		flyingMountBorderHighlight.texture = flyingMountBorderHighlightTexture;
		
		local point, relativeTo, relativePoint, xOfs, yOfs = flyingMountFrame:GetPoint();
		flyingMountBorderHighlight:SetPoint("TOPLEFT", flyingMountFrame, "TOPLEFT", borderOffset * -1, borderOffset);
		flyingMountBorderHighlight:Hide();

		FlyingMountClear = CreateFrame("Button", "FlyingMountClearButton", flyingMountBorder, "UIResetButtonTemplate");
		FlyingMountClear:SetPoint("CENTER", flyingMountBorder, "TOPRIGHT", -8, -8);

		FlyingMountClear:SetScript("OnEnter", function()
			GameTooltip:SetOwner(FlyingMountClear, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["Item Slot Flying Mount Clear Tooltip"]);
			GameTooltip:Show();
			FlyingMountClear:Show();
		end)

		FlyingMountClear:SetScript("OnLeave", function()
			FlyingMountClear:Hide();
			GameTooltip:Hide();
		end)

		FlyingMountClear:SetScript("OnClick", function()
			SetSelectedFlyingMount(1);
			FlyingMountModel:SetDisplayInfo(0);
			FlyingMountModel:SetAlpha(1);
			FlyingMountClear:Hide();
			ClearSelectedFlyingMount(); 				
		end)				

		-- Ground Mount Frame

		groundMountFrame = CreateFrame("Frame", "GroundMountFrame", MogCompanionsFrame)
		groundMountFrame:SetFrameStrata("MEDIUM");
		groundMountFrame:SetSize(44, 44);

		local point, relativeTo, relativePoint, xOfs, yOfs = MogCompanionsFrame:GetPoint();
		groundMountFrame:SetPoint("TOPLEFT", MogCompanionsFrame, "TOPLEFT", 0, -64);
		groundMountFrame:Show();

		groundMountTexture = groundMountFrame:CreateTexture(nil,"BACKGROUND");

		-- Ground Mount Border

		groundMountBorder = CreateFrame("Frame", "GroundMountBorder", groundMountFrame);
		groundMountBorder:SetFrameStrata("HIGH");
		groundMountBorder:SetSize(borderSize, borderSize);

		groundMountBorderTexture = groundMountBorder:CreateTexture(nil,"BACKGROUND");
		groundMountBorderTexture:SetAtlas("transmog-gearSlot-default");
		groundMountBorderTexture:SetAllPoints(groundMountBorder);
		groundMountBorder.texture = groundMountBorderTexture;

		local point, relativeTo, relativePoint, xOfs, yOfs = groundMountFrame:GetPoint();
		groundMountBorder:SetPoint("TOPLEFT", groundMountFrame, "TOPLEFT", borderOffset * -1, borderOffset);
		groundMountBorder:Show();

		-- Ground Mount Border Highlight

		groundMountBorderHighlight = CreateFrame("Frame", "GroundMountBorderHighlight", groundMountFrame);
		groundMountBorderHighlight:SetFrameStrata("HIGH");
		groundMountBorderHighlight:SetSize(borderSize, borderSize);
		groundMountBorderHighlightTexture = groundMountBorderHighlight:CreateTexture(nil,"BACKGROUND");
		groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		groundMountBorderHighlightTexture:SetAllPoints(groundMountBorderHighlight);
		groundMountBorderHighlightTexture:SetBlendMode("ADD");
		groundMountBorderHighlight.texture = groundMountBorderHighlightTexture;
		
		local point, relativeTo, relativePoint, xOfs, yOfs = groundMountFrame:GetPoint();
		groundMountBorderHighlight:SetPoint("TOPLEFT", groundMountFrame, "TOPLEFT", borderOffset * -1, borderOffset);
		groundMountBorderHighlight:Hide();

		GroundMountClear = CreateFrame("Button", "GroundMountClearButton", groundMountBorder, "UIResetButtonTemplate");
		GroundMountClear:SetPoint("CENTER", groundMountBorder, "TOPRIGHT", -8, -8);

		GroundMountClear:SetScript("OnEnter", function()
			GameTooltip:SetOwner(GroundMountClear, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["Item Slot Ground Mount Clear Tooltip"]);
			GameTooltip:Show();
			GroundMountClear:Show();
		end)

		GroundMountClear:SetScript("OnLeave", function()
			GroundMountClear:Hide();
			GameTooltip:Hide();
		end)

		GroundMountClear:SetScript("OnClick", function()
			SetSelectedGroundMount(1);
			GroundMountModel:SetDisplayInfo(0);
			GroundMountModel:SetAlpha(0);
			GroundMountClear:Hide();
			ClearSelectedGroundMount();			
		end)	

	end

	local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);
	local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);

	MogCompanions:UpdateSelectMountDetails("Flying", MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);

	if MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying == 1 then
		local flyingIcon, _ = getEmptyMountIcon();
		flyingMountTexture:SetTexture(flyingIcon);
		flyingMountTexture:SetDesaturated(true);
		flyingMountTexture:SetVertexColor(0.63,0.63,0.63);
		flyingMountBorderTexture:SetAtlas("transmog-gearSlot-default");
		flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	else
		flyingMountTexture:SetTexture(icon);
		flyingMountTexture:SetDesaturated(false);
		flyingMountTexture:SetVertexColor(1,1,1);
		flyingMountBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
		flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
	end
	
	flyingMountTexture:SetAllPoints(flyingMountFrame);
	flyingMountFrame.texture = flyingMountTexture;

	-- Ground mount slot icon

	local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);
	local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);

	MogCompanions:UpdateSelectMountDetails("Ground", MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);

	if MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground == 1 then
		local _, groundIcon = getEmptyMountIcon();
		groundMountTexture:SetTexture(groundIcon);
		groundMountTexture:SetDesaturated(true);
		groundMountTexture:SetVertexColor(0.63,0.63,0.63);
		groundMountBorderTexture:SetAtlas("transmog-gearSlot-default");
		groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	else
		groundMountTexture:SetTexture(icon);
		groundMountTexture:SetDesaturated(false);
		groundMountTexture:SetVertexColor(1,1,1);
		groundMountBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
		groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
	end

	groundMountTexture:SetAllPoints(groundMountFrame);
	groundMountFrame.texture = groundMountTexture;

	if reset then

		flyingMountBorder:HookScript("OnEnter", function()
			GameTooltip:SetOwner(flyingMountBorder, "ANCHOR_RIGHT");
			if MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying > 1 then
				GameTooltip:AddLine(MogCompanionsSelectedMount.Flying.name);
				GameTooltip:AddLine("|cFFFFFFFF"..L["Item Slot Flying Mount Title"].."|r");
				FlyingMountClear:Show();				
			else
				GameTooltip:SetText(L["Item Slot Flying Mount Title"]);
			end
			GameTooltip:Show();
			flyingMountBorderHighlight:Show();
		end)

		flyingMountBorder:HookScript("OnLeave", function()
			GameTooltip:Hide();
			flyingMountBorderHighlight:Hide();
			FlyingMountClear:Hide();
		end)

		flyingMountBorder:SetScript("OnMouseDown", function (self, button)
			TransmogFrame.WardrobeCollection:SetTab(TransmogFrame.WardrobeCollection.mountsTabID);
		 	PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
		end)

		groundMountBorder:HookScript("OnEnter", function()
			GameTooltip:SetOwner(groundMountBorder, "ANCHOR_RIGHT")
			if MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground > 1 then
				GameTooltip:AddLine(MogCompanionsSelectedMount.Ground.name);
				GameTooltip:AddLine("|cFFFFFFFF"..L["Item Slot Ground Mount Title"].."|r");
				GroundMountClear:Show();
			else
				GameTooltip:AddLine(L["Item Slot Ground Mount Title"]);
			end
			GameTooltip:Show();
			groundMountBorderHighlight:Show();
		end)

		groundMountBorder:HookScript("OnLeave", function()
			GameTooltip:Hide();
			groundMountBorderHighlight:Hide();
			GroundMountClear:Hide();
		end)

		groundMountBorder:SetScript("OnMouseDown", function (self, button)
			TransmogFrame.WardrobeCollection:SetTab(TransmogFrame.WardrobeCollection.mountsTabID);
			PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
		end)

	end
end

-- Selection-changed callback for the flying mount ScrollBox.
-- Toggles highlight lock on list rows to show/hide the selection state.
local function OnFlyingMountSelectionChanged(self, data, selected)
	local button = FlyingMountListScrollBox:FindFrame(data);
	local children = {FlyingMountListScrollBox.ScrollTarget:GetChildren()};

	for i, child in ipairs(children) do
		child.isSelected = false
		child:UnlockHighlight();
	end
	if button ~= nil then
		if button.isSelected then
			button.isSelected = false
			button:UnlockHighlight();
		else
			button.isSelected = true
			button:LockHighlight();
		end
	end
end

-- Selection-changed callback for the ground mount ScrollBox.
local function OnGroundMountSelectionChanged(self, data, selected)
	local button = GroundMountListScrollBox:FindFrame(data);
	local children = {GroundMountListScrollBox.ScrollTarget:GetChildren()};

	for i, child in ipairs(children) do
		child.isSelected = false;
		child:UnlockHighlight();
	end

	if button ~= nil then
		if button.isSelected then
			button.isSelected = false;
			button:UnlockHighlight();
		else
			button.isSelected = true;
			button:LockHighlight();
		end
	end
end

-- Returns true if the player has neither a MogCompanions keybind nor a MogCompanions macro
-- on any action bar slot. Used to decide whether to show the setup reminder banner.
function MissingKeybindOrMacro()
	local key1, key2 = '', '';
	key1, key2 = GetBindingKey("Mount/Dismount");

	local missingKeys = false;
	local missingMacro = true;

	if (not key1 or key1 == '') and (not key2 or key2 == '') then
		missingKeys = true;
	end

	for i = 1, 180 do
		if HasAction(i) then
			local actionType, actionId, macroIndex = GetActionInfo(i);
			if actionType == 'macro' then
				local currentMacroName, _, _ = GetMacroInfo(actionId);
				if currentMacroName == "MogComp Mount" then
					missingMacro = false;
				end
			end
  		end
	end

	return missingMacro and missingKeys;
end

-- ── Mount Tab UI Helpers ────────────────────────────────────────────────────────
local function ToggleGroundMountIncludeFlying()
	-- CheckboxShowFlyingInGroundList:IsSelected()
end

local function FilterIsChecked(filter)
	return MogCompanionsSaved.ShowFlyingInGround;
end

local function FilterSetChecked(filter)
	if FilterIsChecked(filter) then
		MogCompanionsSaved.ShowFlyingInGround = false;
	else
		MogCompanionsSaved.ShowFlyingInGround = true;
	end
	local mounts = MogCompanions:getSortedGroundMounts();

	local scrollToCount = 0;
	local scrollToIndex = 0;

	local GroundMountDataProvider = CreateDataProvider();

	for i = 1, #mounts do
		local mount = mounts[i];
		scrollToCount = scrollToCount + 1;
		if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground then
			scrollToIndex = scrollToCount;
		end
		GroundMountDataProvider:Insert(mount);
	end
	
	GroundMountListScrollView:SetDataProvider(GroundMountDataProvider);
	GroundMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);
end

-- Shows/hides the setup reminder banner based on whether the player has a MogCompanions keybind or macro set up.
-- Called on load and after the player drops the macro onto an action bar.
local function ToggleReminder()
	if MissingKeybindOrMacro() then
		SetupReminderFrame:Show();
	else
		SetupReminderFrame:Hide();
	end
	ShortcutSettings:Show();
	MountListSearchBox:Show();
	FilterDropdown:Show();
end

-- Creates the "MogComp Mount" macro (or edits the existing one) and puts it on the cursor
-- for the player to drag to an action bar. Registers a one-shot event to detect the drop.
local function CreateMacroButton(Parent)
	local macroId = false;

	for i = 1, 120 do
		if C_Macro.GetMacroName(i) == "MogComp Mount" then
			macroId = i;
		end
	end

	if not macroId then
		macroId = CreateMacro("MogComp Mount", 1769015, "/mcomp mount", nil);
	end

	MogCompanionsSaved["MacroID"] = macroId;
	PickupMacro(macroId);

	GameTooltip:SetOwner(Parent, "ANCHOR_CURSOR_RIGHT");
	GameTooltip:AddLine(L["Drop Macro Tooltip"], 1, 1, 1);
	GameTooltip:Show();

	local MacroDropEventFrame = CreateFrame("EventFrame")
	MacroDropEventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

	MacroDropEventFrame:SetScript("OnEvent", function(self, event, slot)
		if slot then
			local actionType, id, subType = GetActionInfo(slot)
			if actionType == "macro" then
				ToggleReminder();
				MacroDropEventFrame:UnregisterAllEvents();
				MacroDropEventFrame = nil;
			end
		end
	end)
end

-- Creates the gear dropdown (ShortcutSettings) with Settings / Keybinds / Macro buttons.
local function CreateShortcuts(f)
	local ShortcutSettings = CreateFrame("DropdownButton", "ShortcutSettings", f, "DamageMeterSettingsDropdownButtonTemplate");
	ShortcutSettings:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -50);
	ShortcutSettings:SetPoint("CENTER");
	ShortcutSettings:SetupMenu(function(dropdown, rootDescription)
		rootDescription:CreateTitle("MogCompanions");
		rootDescription:CreateButton(L["Open Settings"], function() MogCompanions:OpenSettings() end);
		rootDescription:CreateButton(L["Open Keybinds"], function() MogCompanions:OpenKeybinds() end);
		rootDescription:CreateButton(L["Create Macro"], function() CreateMacroButton(ShortcutSettings) end);
	end)
	ShortcutSettings:Hide()
end

-- Builds the setup-reminder banner with a warning icon, explanatory text,
-- and buttons to create the macro or open keybindings.
-- SetupReminderFrame is a global (used by ToggleReminder) and stored at file scope.
function CreateSetupReminder(f)
	SetupReminderFrame = CreateFrame("Frame", "MogCompanionsSetupReminderFrame", f);
	SetupReminderFrame:SetAllPoints(f);
	SetupReminderFrame:SetParent(f);

	local SetupReminderIcon = SetupReminderFrame:CreateTexture(nil,"BACKGROUND");
	SetupReminderIcon:SetAtlas("transmog-icon-warning");
	SetupReminderIcon:SetSize(20,20);
	SetupReminderIcon:SetPoint("TOPLEFT", 24, -24);	

	local SetupReminderText = SetupReminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	SetupReminderText:SetJustifyH("LEFT");
	SetupReminderText:SetPoint("TOPLEFT", 48, -28);
	SetupReminderText:SetText("|cFFE36F1B"..L["Setup Reminder"].."|r");

	local characterWidth = 8;
	local buttonPadding = 12;

	local CreateMacroButtonFrame = CreateFrame("Button", "CreateMacroButtonFrame", SetupReminderFrame, "UIPanelButtonTemplate");
	CreateMacroButtonFrame:SetPoint("TOPRIGHT", SetupReminderFrame, "TOPRIGHT", -26, -22);
	local length = string.len(L["Create Macro"]);
	CreateMacroButtonFrame:SetSize(length * characterWidth + buttonPadding, 22);
	CreateMacroButtonFrame:SetText(L["Create Macro"]);

	local OpenKeybindingsButton = CreateFrame("Button", "MogCompanionsOpenKeybindingsButton", SetupReminderFrame, "UIPanelButtonTemplate");
	OpenKeybindingsButton:SetPoint("TOPRIGHT", SetupReminderFrame, "TOPRIGHT", (-1 * length * characterWidth) - buttonPadding - 26 - 8, -22);
	length = string.len(L["Open Keybinds"]);
	OpenKeybindingsButton:SetSize(length * characterWidth + buttonPadding, 22);
	OpenKeybindingsButton:SetText(L["Open Keybinds"]);

	OpenKeybindingsButton:SetScript("OnClick", function()
		MogCompanions:OpenKeybinds();
	end)	

	CreateMacroButtonFrame:SetScript("OnMouseDown", function()
		CreateMacroButton(CreateMacroButtonFrame);
	end)
end

-- ── Mounts Tab UI (WardrobeCollection) ────────────────────────────────────────
-- Creates the full Mounts tab inside WardrobeCollection on first call (idempotent).
-- Contains: flying/ground model preview frames, scrollable mount lists, search box,
-- filter dropdown (show flying in ground list), setup reminder, gear menu.
-- SetSelectedFlyingMount and SetSelectedGroundMount are defined here as closures
-- over the local scroll-box and data-provider references.
function MogCompanions:InitMountTab()
	if not TransmogFrame.WardrobeCollection.mountsTabID then

		function TransmogFrame.WardrobeCollection:UpdateTabs()
			self.TabHeaders:SetTabShown(self.itemsTabID, true);
			self.TabHeaders:SetTabShown(self.setsTabID, true);
			self.TabHeaders:SetTabShown(self.custmSetsTabID, true);
			self.TabHeaders:SetTabShown(self.situationsTabID, true);
			self.TabHeaders:SetTabShown(self.mountsTabID, true);
			self.TabHeaders:SetTabShown(self.hearthstonesTabID, true);
		end

		-- Layout scale factor (6/7 ≈ 0.857) that maps the 360-unit preview design coords to the wardrobe tab's actual rendered dimensions.
		local s = 0.85714285714;

		local x, y = 360 * s, 360 * s;
		local inset = 12;
		local scale = 1;
		local columns, rows = 3, 4;
		local left, top = 18, 64;
		local spacing = 10;
		local count = 0;

		default = {};
		default.id = 1;
		default.name = "Default";
		default.icon = 1769016;
		default.model = 0;		

		local f = CreateFrame("Frame", "MountsFrame", TransmogFrame.WardrobeCollection.TabContent);
		f:SetAllPoints(true);
		f:SetFrameStrata("HIGH");
		f:Hide();

		-- Mount tab controls: filter dropdown, search box, setup reminder, and gear menu

		FilterDropdown = CreateFrame("DropdownButton", nil, f, "WowStyle1FilterDropdownTemplate");
		FilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -60, -50);
		FilterDropdown:SetWidth(104);		
		FilterDropdown.resizeToText = false;
		FilterDropdown:SetupMenu(function(dropdown, rootDescription)
			CheckboxShowFlyingInGroundList = rootDescription:CreateCheckbox(L["Show Flying In Ground Toggle"], FilterIsChecked, FilterSetChecked);
		end)

		---		

		MountListSearchBox = CreateFrame("EditBox", "MountListSearchBox", f, "TransmogSearchBoxTemplate");
		MountListSearchBox:SetPoint("TOPRIGHT", -174, -50); --- -32, -444

		local iconPostion, iconParent, iconParentPostion, iconX, iconY = MountListSearchBox.searchIcon:GetPoint();
		MountListSearchBox.searchIcon:SetPoint(iconPostion, iconParent, iconParentPostion, iconX, iconY + 1);

		-- Setup reminder banner and shortcut gear menu

		CreateSetupReminder(f);
		CreateShortcuts(f);

		ToggleReminder();

		-- Flying and ground section title labels

		local FlyingSlotTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
		FlyingSlotTitle:SetJustifyH("LEFT");
		FlyingSlotTitle:SetPoint("TOPLEFT", 24, -76);
		FlyingSlotTitle:SetText(L["Mount Tab Flying Section Title"]);

		local FlyingSlotTitleDivider = f:CreateTexture();
		FlyingSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
		FlyingSlotTitleDivider:SetAlpha(0.1);
		FlyingSlotTitleDivider:SetPoint("TOPLEFT", FlyingSlotTitle, "BOTTOMLEFT", 0, -2);

		local GroundSlotTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
		GroundSlotTitle:SetJustifyH("LEFT");
		GroundSlotTitle:SetPoint("TOPLEFT", 24, -444);
		GroundSlotTitle:SetText(L["Mount Tab Ground Section Title"]);

		local GroundSlotTitleDivider = f:CreateTexture();
		GroundSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
		GroundSlotTitleDivider:SetAlpha(0.1);
		GroundSlotTitleDivider:SetPoint("TOPLEFT", GroundSlotTitle, "BOTTOMLEFT", 0, -2);

		-- Load display info for the flying and ground model previews

		local flyingModelID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying);
		local groundModelID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground);

		-- Flying mount model preview frame and list

		FlyingMountPreview = CreateFrame("Frame", "MountTabFlyingPreview", f);
		FlyingMountPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 24 * s, -114 * s);
		FlyingMountPreview:SetFrameStrata("HIGH");
		FlyingMountPreview:SetSize(x, y);
		FlyingMountPreview:SetParent(f);

		local FlyingMountPreviewBackground = FlyingMountPreview:CreateTexture(nil, "BACKGROUND");
		FlyingMountPreviewBackground:SetAtlas("professions-recipe-background");
		FlyingMountPreviewBackground:SetPoint("CENTER", FlyingMountPreview, "CENTER", 0, 0);
		FlyingMountPreviewBackground:SetSize(x - inset, y - inset);
		FlyingMountPreviewBackground:SetAlpha(1);
		FlyingMountPreviewBackground:SetVertexColor(0,0,0);

		FlyingMountModel = CreateFrame("PlayerModel", "MountTabFlyingModel", FlyingMountPreview);
		FlyingMountModel:SetPoint("CENTER", FlyingMountPreview, "CENTER", 0, 0);
		FlyingMountModel:SetSize(x - inset, y - inset);		
		FlyingMountModel:SetPortraitZoom(0);
		if flyingModelID ~= nil and flyingModelID > 0 then
			FlyingMountModel:SetDisplayInfo(flyingModelID);
			FlyingMountModel:SetAlpha(1);
		end
		-- FlyingMountModel:SetPosition(-0.2, -0.1, -0.1)
		FlyingMountModel:SetFacing(-5.5);

		local FlyingMountPreviewBorder = FlyingMountPreview:CreateTexture(nil, "OVERLAY");
		FlyingMountPreviewBorder:SetAtlas("transmog-itemCard-default", true);
		FlyingMountPreviewBorder:SetPoint("CENTER", FlyingMountPreview, "CENTER", 0, 0);
		FlyingMountPreviewBorder:SetSize(x, y);

		local _, _, _, xx, yy = FlyingMountPreview:GetPoint();
		local ww, hh = FlyingMountPreview:GetSize();
		local fw, fh = f:GetSize();
		local ii = 5;
		local gap = 16 * s;
		local r = 8;

		FlyingMountList = CreateFrame("Frame", "FlyingMountList", f);
		FlyingMountList:SetPoint("TOPLEFT", f, "TOPLEFT", xx + gap + x, yy - ii);
		FlyingMountList:SetFrameStrata("HIGH");
		FlyingMountList:SetSize(fw - (xx + ww + gap + xx + r), y - (ii * 2));
		FlyingMountList:SetParent(f);

		-- Flying mount scroll box and list controls

		FlyingMountListScrollBox = CreateFrame("Frame", "FlyingMountListScrollBox", FlyingMountList, "WowScrollBoxList");
		local z, zz = FlyingMountList:GetSize() ;
		FlyingMountListScrollBox:SetSize(z - 40, zz - 4);
		FlyingMountListScrollBox:SetPoint("TOPLEFT", FlyingMountList, "TOPLEFT", 12, -2);

		local FlyingMountListScrollBar = CreateFrame("EventFrame", nil, FlyingMountList, "MinimalScrollBar");
		FlyingMountListScrollBar:SetPoint("TOPLEFT", FlyingMountListScrollBox, "TOPRIGHT", 10, -6);
		FlyingMountListScrollBar:SetPoint("BOTTOMLEFT", FlyingMountListScrollBox, "BOTTOMRIGHT", 10, 6);

		FlyingMountListScrollBar:SetHideIfUnscrollable(true);
		local FlyingMountDataProvider = CreateDataProvider();
		local FlyingMountListScrollView = CreateScrollBoxListLinearView();
		FlyingMountSelectionBehavior = ScrollUtil.AddSelectionBehavior(FlyingMountListScrollBox, SelectionBehaviorFlags.Intrusive);

		FlyingMountSelectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, OnFlyingMountSelectionChanged, self);

		function SetSelectedFlyingMount(value)
			local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(value);
			local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(value);

			MogCompanions:UpdateSelectMountDetails("Flying", value);

			if value == 1 then
				local flyingIcon, _ = getEmptyMountIcon();
				flyingMountTexture:SetTexture(flyingIcon);
				flyingMountTexture:SetDesaturated(true);
				flyingMountTexture:SetVertexColor(0.63,0.63,0.63);
				flyingMountBorderTexture:SetAtlas("transmog-gearSlot-default");
				flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
			else
				flyingMountTexture:SetTexture(icon);
				flyingMountTexture:SetDesaturated(false);
				flyingMountTexture:SetVertexColor(1,1,1);
				flyingMountBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
				flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
			end

			flyingMountFrame.texture = flyingMountTexture;

			MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying = value;
			PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);

		end	

		local function FlyingMountListInitializer(button, data)
			local isSelected = FlyingMountSelectionBehavior:IsElementDataSelected(data);

			if data.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying then
				isSelected = true;
			end

			button.Name:SetText("|T"..data.icon..":18|t "..data.name);
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
			button.MountID = data.id;

			if isSelected then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end

			button:SetScript("OnEnter", function()
				if FlyingMountModel:GetDisplayInfo() ~= data.model and data.model ~= nil then
					FlyingMountModel:SetDisplayInfo(data.model);
				end
				FlyingMountModel:SetAlpha(1);
			end)

			button:SetScript("OnLeave", function()
					local SavedFlyingMoundID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);
					FlyingMountModel:SetDisplayInfo(SavedFlyingMoundID);
				end
				if SavedFlyingMoundID == nil then
					FlyingMountModel:SetAlpha(0);
				end
			end)

			button:SetScript("OnClick", function()
				FlyingMountSelectionBehavior:Select(button);
				SetSelectedFlyingMount(data.id);
					local SavedFlyingMoundID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);
				FlyingMountModel:SetAlpha(1);	
			end)

		end

		FlyingMountListScrollView:SetElementInitializer("MogCompanionsListButtonTemplate", FlyingMountListInitializer);

		local mounts = MogCompanions:getSortedFlyingMounts();

		local scrollToCount = 0;
		local scrollToIndex = 0;

		for i = 1, #mounts do
			local mount = mounts[i];
			scrollToCount = scrollToCount + 1;
			if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying then
				scrollToIndex = scrollToCount;
			end
			FlyingMountDataProvider:Insert(mount);
		end
		
		FlyingMountListScrollView:SetElementExtent(22);
		ScrollUtil.InitScrollBoxListWithScrollBar(FlyingMountListScrollBox, FlyingMountListScrollBar, FlyingMountListScrollView);
		FlyingMountListScrollView:SetDataProvider(FlyingMountDataProvider);

		FlyingMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);

		-- Flying mount list background overlay; ground mount section follows

		local FlyingMountListBackground = FlyingMountList:CreateTexture(nil, "OVERLAY");
		FlyingMountListBackground:SetAtlas("transmog-situations-containerbg", true);
		FlyingMountListBackground:SetAllPoints(true);

		GroundMountPreview = CreateFrame("Frame", "MountTabGroundPreview", f);
		GroundMountPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 24 * s, -564 * s);
		GroundMountPreview:SetFrameStrata("HIGH");
		GroundMountPreview:SetSize(x, y);
		GroundMountPreview:SetParent(f);

		local GroundMountPreviewBackground = GroundMountPreview:CreateTexture(nil, "BACKGROUND");
		GroundMountPreviewBackground:SetAtlas("professions-recipe-background");
		GroundMountPreviewBackground:SetPoint("CENTER", GroundMountPreview, "CENTER", 0, 0);
		GroundMountPreviewBackground:SetSize(x - inset, y - inset);
		GroundMountPreviewBackground:SetAlpha(1);
		GroundMountPreviewBackground:SetVertexColor(0,0,0);

		GroundMountModel = CreateFrame("PlayerModel", "MountTabGroundModel", GroundMountPreview);
		GroundMountModel:SetPoint("CENTER", GroundMountPreview, "CENTER", 0, 0);
		GroundMountModel:SetSize(x - inset, y - inset);
		GroundMountModel:SetPortraitZoom(0);
		if groundModelID ~= nil and groundModelID > 0 then
	   		GroundMountModel:SetDisplayInfo(groundModelID);
	   		GroundMountModel:SetAlpha(1);
	   	end
		GroundMountModel:SetPosition(-0.2, -0.1, -0.1);
		GroundMountModel:SetFacing(-5.5);

		local GroundMountPreviewBorder = GroundMountPreview:CreateTexture(nil, "OVERLAY");
		GroundMountPreviewBorder:SetAtlas("transmog-itemCard-default", true);
		GroundMountPreviewBorder:SetPoint("CENTER", GroundMountPreview, "CENTER", 0, 0);
		GroundMountPreviewBorder:SetSize(x, y);

		local _, _, _, xx, yy = GroundMountPreview:GetPoint();
		local ww, hh = GroundMountPreview:GetSize();

		GroundMountList = CreateFrame("Frame", "MountTabGroundList", f);
		GroundMountList:SetPoint("TOPLEFT", f, "TOPLEFT", xx + gap + x, yy - ii);
		GroundMountList:SetFrameStrata("HIGH");
		GroundMountList:SetSize(fw - (xx + ww + gap + xx + r), y - (ii * 2));
		GroundMountList:SetParent(f);

		local GroundMountListBackground = GroundMountList:CreateTexture(nil, "BACKGROUND");
		GroundMountListBackground:SetAtlas("transmog-situations-containerbg", true);
		GroundMountListBackground:SetAllPoints(true);

		-- Ground mount scroll box and list controls

		GroundMountListScrollBox = CreateFrame("Frame", "GroundMountListScrollBox", GroundMountList, "WowScrollBoxList");
		local z, zz = GroundMountList:GetSize();
		GroundMountListScrollBox:SetSize(z - 40, zz - 4);
		GroundMountListScrollBox:SetPoint("TOPLEFT", GroundMountList, "TOPLEFT", 12, -2);

		local GroundMountListScrollBar = CreateFrame("EventFrame", nil, GroundMountList, "MinimalScrollBar");
		GroundMountListScrollBar:SetPoint("TOPLEFT", GroundMountListScrollBox, "TOPRIGHT", 10, -6);
		GroundMountListScrollBar:SetPoint("BOTTOMLEFT", GroundMountListScrollBox, "BOTTOMRIGHT", 10, 6);

		GroundMountListScrollBar:SetHideIfUnscrollable(true);
		local GroundMountDataProvider = CreateDataProvider();
		GroundMountListScrollView = CreateScrollBoxListLinearView();
		GroundMountSelectionBehavior = ScrollUtil.AddSelectionBehavior(GroundMountListScrollBox, SelectionBehaviorFlags.Intrusive);

		GroundMountSelectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, OnGroundMountSelectionChanged, self);

		function SetSelectedGroundMount(value)
			local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(value);
			local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(value);

			MogCompanions:UpdateSelectMountDetails("Ground", value);

			if value == 1 then
				local _, groundIcon = getEmptyMountIcon();
				groundMountTexture:SetTexture(groundIcon);
				groundMountTexture:SetDesaturated(true);
				groundMountTexture:SetVertexColor(0.63,0.63,0.63);
				groundMountBorderTexture:SetAtlas("transmog-gearSlot-default");
				groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
			else
				groundMountTexture:SetTexture(icon);
				groundMountTexture:SetDesaturated(false);
				groundMountTexture:SetVertexColor(1,1,1);
				groundMountBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
				groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
			end

			groundMountFrame.texture = groundMountTexture;

			MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground = value;
			PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);

		end	

		local function GroundMountListInitializer(button, data)
			local isSelected = GroundMountSelectionBehavior:IsElementDataSelected(data);

			if data.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground then
				isSelected = true;
			end

			button.Name:SetText("|T"..data.icon..":18|t "..data.name);
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
			button.MountID = data.id;

			if isSelected then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end

			button:SetScript("OnEnter", function()
				if GroundMountModel:GetDisplayInfo() ~= data.model and data.model ~= nil then
					GroundMountModel:SetDisplayInfo(data.model);
				end
				GroundMountModel:SetAlpha(1);
			end)

			button:SetScript("OnLeave", function()
					local SavedGroundMoundID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);
					GroundMountModel:SetDisplayInfo(SavedGroundMoundID);
					GroundMountModel:SetAlpha(1);
				end
				if SavedGroundMoundID == nil then
					GroundMountModel:SetAlpha(0);
				end
			end)

			button:SetScript("OnClick", function()
				GroundMountSelectionBehavior:Select(button);
				SetSelectedGroundMount(data.id);
					local SavedGroundMoundID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);
				GroundMountModel:SetAlpha(1);				
			end)

		end

		GroundMountListScrollView:SetElementInitializer("MogCompanionsListButtonTemplate", GroundMountListInitializer);

		local mounts = MogCompanions:getSortedGroundMounts();

		local scrollToCount = 0;
		local scrollToIndex = 0;

		for i = 1, #mounts do
			local mount = mounts[i];
			scrollToCount = scrollToCount + 1;
			if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground then
				scrollToIndex = scrollToCount;
			end
			GroundMountDataProvider:Insert(mount);
		end
		
		GroundMountListScrollView:SetElementExtent(22);
		ScrollUtil.InitScrollBoxListWithScrollBar(GroundMountListScrollBox, GroundMountListScrollBar, GroundMountListScrollView);
		GroundMountListScrollView:SetDataProvider(GroundMountDataProvider);

		GroundMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);

		-- Search box OnTextChanged: re-filter both flying and ground mount lists

		MountListSearchBox:SetScript("OnTextChanged", function(self)
			if SearchBoxTemplate_OnTextChanged ~= nil then
				SearchBoxTemplate_OnTextChanged(self);
			end

			MogCompanions.MountSearchString = MountListSearchBox:GetText();

			local mounts = MogCompanions:getSortedFlyingMounts();

			local scrollToCount = 0;
			local scrollToIndex = 0;

			FlyingMountDataProvider = CreateDataProvider();

			for i = 1, #mounts do
				local mount = mounts[i];
				scrollToCount = scrollToCount + 1;
				if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying then
					scrollToIndex = scrollToCount;
				end	
				FlyingMountDataProvider:Insert(mount);
			end
			
			FlyingMountListScrollView:SetElementExtent(22);
			ScrollUtil.InitScrollBoxListWithScrollBar(FlyingMountListScrollBox, FlyingMountListScrollBar, FlyingMountListScrollView);
			FlyingMountListScrollView:SetDataProvider(FlyingMountDataProvider);

			FlyingMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);

			-- Refresh ground mount list with updated search filter

			local mounts = MogCompanions:getSortedGroundMounts();

			local scrollToCount = 0;
			local scrollToIndex = 0;

			GroundMountDataProvider = CreateDataProvider();

			for i = 1, #mounts do
				local mount = mounts[i];
				scrollToCount = scrollToCount + 1;
				if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground then
					scrollToIndex = scrollToCount;
				end
				GroundMountDataProvider:Insert(mount);
			end
			
			GroundMountListScrollView:SetElementExtent(22);
			ScrollUtil.InitScrollBoxListWithScrollBar(GroundMountListScrollBox, GroundMountListScrollBar, GroundMountListScrollView);
			GroundMountListScrollView:SetDataProvider(GroundMountDataProvider);

			GroundMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);

		end)

		--		

		local HearthstonesFrame = nil;

		if MogCompanions.CreateHearthstonesFrame ~= nil then
			HearthstonesFrame = MogCompanions:CreateHearthstonesFrame(TransmogFrame.WardrobeCollection, MountsFrame);
		end

		TransmogFrame.WardrobeCollection.mountsTabID = TransmogFrame.WardrobeCollection:AddNamedTab(L["Mount Tab Title"], MountsFrame);

		if HearthstonesFrame ~= nil then
			TransmogFrame.WardrobeCollection.hearthstonesTabID = TransmogFrame.WardrobeCollection:AddNamedTab(L["Hearthstone Tab Title"], HearthstonesFrame);
		end

		TransmogFrame.WardrobeCollection:UpdateTabs();
	end

	ToggleReminder();
end

-- Resets the flying mount list selection and scrolls back to the top.
-- Called after the player clears the flying mount slot.
function ClearSelectedFlyingMount()
	FlyingMountModel:SetAlpha(0);

	local children = {FlyingMountListScrollBox.ScrollTarget:GetChildren()};

	for i, child in ipairs(children) do
		child.isSelected = false;
		child:UnlockHighlight();
	end

	FlyingMountListScrollBox:ScrollToElementDataIndex(1);
end

-- Resets the ground mount list selection and scrolls back to the top.
-- Called after the player clears the ground mount slot.
function ClearSelectedGroundMount()
	GroundMountModel:SetAlpha(0);

	local children = {GroundMountListScrollBox.ScrollTarget:GetChildren()};

	for i, child in ipairs(children) do
		child.isSelected = false;
		child:UnlockHighlight();
	end

	GroundMountListScrollBox:ScrollToElementDataIndex(1);
end

-- Re-selects and scrolls to the currently saved flying and ground mounts in both lists.
-- Called from Core.lua after VIEWED_TRANSMOG_OUTFIT_CHANGED to sync the UI
-- with the newly viewed outfit's saved mount selections.
function UpdateSelectedMountRow()
    if TransmogFrame == nil
        or TransmogFrame.WardrobeCollection == nil
        or not TransmogFrame:IsShown()
        or FlyingMountListScrollBox == nil
        or FlyingMountSelectionBehavior == nil
        or GroundMountListScrollBox == nil
        or GroundMountSelectionBehavior == nil then
        return;
    end

	if FlyingMountListScrollBox then
		ClearSelectedFlyingMount();
		local mounts = MogCompanions:getSortedFlyingMounts();

		for i = 1, #mounts do
			local mount = mounts[i];
			if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying then
				FlyingMountListScrollBox:ScrollToElementDataIndex(i);
				local children = {FlyingMountListScrollBox.ScrollTarget:GetChildren()};
				for j, child in ipairs(children) do
					if child.MountID == mount.id then
						if child.GetElementData ~= nil and child:GetElementData() ~= nil then
							FlyingMountSelectionBehavior:Select(child);
						end
						if mount.model ~= nil then
							FlyingMountModel:SetDisplayInfo(mount.model);
							FlyingMountModel:SetAlpha(1);
						end
					else
						child.isSelected = false;
						child:UnlockHighlight();
			   		end
				end				
			end
		end

	end

	if GroundMountListScrollBox then
		ClearSelectedGroundMount();
		local mounts = MogCompanions:getSortedGroundMounts();

		for i = 1, #mounts do
			local mount = mounts[i];
			if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground then
				GroundMountListScrollBox:ScrollToElementDataIndex(i);
				local children = {GroundMountListScrollBox.ScrollTarget:GetChildren()};
				for j, child in ipairs(children) do
					if child.MountID == mount.id then
						if child.GetElementData ~= nil and child:GetElementData() ~= nil then
							GroundMountSelectionBehavior:Select(child);
						end
						if mount.model ~= nil then
							GroundMountModel:SetDisplayInfo(mount.model);
							GroundMountModel:SetAlpha(1);
						end
					else
						child.isSelected = false;
						child:UnlockHighlight();						
			   		end
				end				
			end
		end

	end
end
