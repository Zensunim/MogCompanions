-- Mounts.lua
-- Contains all mount summon logic and the full mount UI inside the Transmog wardrobe.
--
-- Summon priority (MogCompanionsSummon):
--   1. Exit vehicle (CanExitVehicle)
--   2. Dismount if already mounted
--   3. [Ground modifier] + swimming → aquatic mount
--   4. [Repair modifier] → repair/vendor mount
--   5. [Random modifier] → random mount
--   6. Flyable area, no [Ground modifier] → flying mount
--   7. Fallback → ground mount
--
-- UI sections:
--   • Flying/ground mount slot icons in CharacterPreview.RightSlots (InitMountSlots)
--   • Mounts tab in WardrobeCollection with model previews + scrollable lists (InitMountTab)
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

local MountListSearchBox, FilterDropdown, ShortcutSettings;

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
-- Flying/Ground: use per-outfit selection if set (> 1), otherwise random from category.
-- Aquatic/Repair: use global default if set (> 1), otherwise random from category.
-- Random: always random from all collected usable mounts.
function MogCompanionsSummonFlying()
	local outfitData = MogCompanions:GetActiveOutfitTable();
	if outfitData and outfitData.Flying and outfitData.Flying > 1 then
		C_MountJournal.SummonByID(outfitData.Flying);
	else
		local randomMount = MogCompanions:getRandomMount("flying");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	end
end

function MogCompanionsSummonGround()
	local outfitData = MogCompanions:GetActiveOutfitTable();
	if outfitData and outfitData.Ground and outfitData.Ground > 1 then
		C_MountJournal.SummonByID(outfitData.Ground);
	else
		local randomMount = MogCompanions:getRandomMount("ground");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
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

function MogCompanionsSummonRepair()
	if MogCompanionsCharacterSaved.Default.Repair <= 1 then
		local randomMount = MogCompanions:getRandomMount("repair");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	else
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved.Default.Repair);
	end
end

function MogCompanionsSummonRandom()
	local randomMount;
	if IsFlyableArea() then
		randomMount = MogCompanions:getRandomMount("flying");
	else
		randomMount = MogCompanions:getRandomMount("ground");
	end
	if randomMount then C_MountJournal.SummonByID(randomMount.id); end
end

-- Cache: spellID → mountID for all collected, usable mounts owned by this character.
-- nil means the cache has not been built yet (or was invalidated).
-- Rebuilt lazily on the next tryCloneTargetedMount call.
local mountCloneCache = nil;

local function buildMountCloneCache()
	mountCloneCache = {};
	local mountIDs = C_MountJournal.GetMountIDs();
	for _, mountID in ipairs(mountIDs) do
		local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID);
		if isCollected and isUsable and not shouldHideOnChar and spellID then
			mountCloneCache[spellID] = mountID;
		end
	end
end

-- Invalidate the cache when mount collection or usability changes.
local MountCloneCacheFrame = CreateFrame("Frame");
MountCloneCacheFrame:RegisterEvent("NEW_MOUNT_ADDED");
MountCloneCacheFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED");
MountCloneCacheFrame:SetScript("OnEvent", function() mountCloneCache = nil; end);

-- Returns the mount ID of the mount the target player is riding, if the local
-- player also has that mount collected and usable. Returns nil otherwise.
-- Used by MogCompanionsSummon when CloneTargetedMount is enabled.
local function tryCloneTargetedMount()
	if not MogCompanionsSaved.CloneTargetedMount then return nil; end
	if not UnitExists("target") then return nil; end
	if not UnitIsPlayer("target") then return nil; end

	if not mountCloneCache then
		buildMountCloneCache();
	end

	-- Scan the target's buffs (typically < 40) and do an O(1) cache lookup per entry.
	local i = 1;
	while true do
		local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HELPFUL");
		if not aura then break; end
		if aura.spellId and mountCloneCache[aura.spellId] then
			return mountCloneCache[aura.spellId];
		end
		i = i + 1;
	end

	return nil;
end

-- Returns true if the modifier key configured for modType is currently held.
-- modType: "Ground" | "Repair" | "Random"
-- Reads MogCompanionsSaved.MountMods: 1=CTRL, 2=SHIFT, 3=ALT.
-- Falls back to legacy hardcoded keys if MountMods is not yet initialised.
local function GetMountModKey(modType)
	local mods = {};
	mods[1] = IsControlKeyDown();
	mods[2] = IsShiftKeyDown();
	mods[3] = IsAltKeyDown();

	if MogCompanionsSaved and MogCompanionsSaved.MountMods then
		if modType == "Repair" then
			return mods[MogCompanionsSaved.MountMods.Repair] or false;
		elseif modType == "Ground" then
			return mods[MogCompanionsSaved.MountMods.Ground] or false;
		elseif modType == "Random" then
			return mods[MogCompanionsSaved.MountMods.Random] or false;
		end
	else
		-- Fallback: legacy hardcoded behaviour (CTRL=Ground, SHIFT=Repair, ALT=Random)
		if modType == "Repair" then return IsShiftKeyDown(); end
		if modType == "Ground" then return IsControlKeyDown(); end
		if modType == "Random" then return IsAltKeyDown(); end
	end

	return false;
end

-- Main mount/dismount entry point. Evaluates current state and modifier keys
-- to determine which category to summon, then calls the appropriate helper.
-- Also applies the per-outfit title after summoning via MogCompanions:UpdateTitle().
function MogCompanionsSummon()
	if CanExitVehicle() then
		VehicleExit();
	elseif IsMounted() then
		Dismount();
	elseif IsSwimming() and GetMountModKey("Ground") then
		-- Aquatic mount: Ground modifier + swimming
		MogCompanionsSummonAquatic();
	elseif GetMountModKey("Repair") then
		-- Repair bear, yak, or long boi
		MogCompanionsSummonRepair();
	elseif GetMountModKey("Random") then
		-- Random mount from all collected usable mounts
		MogCompanionsSummonRandom();
	else
		-- Flyable or ground. Try cloning the targeted player's mount first;
		-- a successful clone ignores the "allow flying in ground" setting entirely.
		local cloneID = tryCloneTargetedMount();
		if cloneID then
			C_MountJournal.SummonByID(cloneID);
		elseif IsFlyableArea() and not GetMountModKey("Ground") then
			-- Flyable
			MogCompanionsSummonFlying();
		else
			-- Ground or when Ground modifier is pressed
			MogCompanionsSummonGround();
		end
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

	local _, _, icon = C_MountJournal.GetMountInfoByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);

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

	local _, _, icon = C_MountJournal.GetMountInfoByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);

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
			MogCompanions:OpenCompanionsTab("Mounts");
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
			MogCompanions:OpenCompanionsTab("Mounts");
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
-- on any action bar slot. Retained as a compatibility helper for setup state checks.
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
		if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground then
			scrollToIndex = scrollToCount;
		end
		GroundMountDataProvider:Insert(mount);
	end
	
	GroundMountListScrollView:SetDataProvider(GroundMountDataProvider);
	GroundMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);
end

local function CreateShortcuts(f, topOffset)
	ShortcutSettings = MogCompanions:CreateCompanionsShortcutMenu(f, "ShortcutSettings");
	ShortcutSettings:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -50 + (topOffset or 0));
end

local function GetConfiguredMountMacroConditionLabel(mountID)
	if mountID == nil or mountID <= 1 then
		return nil;
	end

	local mountName = C_MountJournal.GetMountInfoByID(mountID);
	if mountName ~= nil and mountName ~= "" then
		return mountName;
	end

	return nil;
end

function MogCompanions:CreateMountMacro(parent)
	if InCombatLockdown and InCombatLockdown() then
		print(L["Macro Combat Error"]);
		return nil;
	end

	local macroId = false;
	for i = 1, 120 do
		if C_Macro.GetMacroName(i) == "MogComp Mount" then
			macroId = i;
		end
	end

	local outfitData = MogCompanions:GetActiveOutfitTable();
	local mountMods = MogCompanionsSaved and MogCompanionsSaved.MountMods or {};
	local modTokens = { "ctrl", "shift", "alt" };
	local groundToken = modTokens[mountMods.Ground or 1] or "ctrl";
	local repairToken = modTokens[mountMods.Repair or 2] or "shift";
	local tooltipParts = {};

	local aquaticName = GetConfiguredMountMacroConditionLabel(MogCompanionsCharacterSaved and MogCompanionsCharacterSaved.Default and MogCompanionsCharacterSaved.Default.Aquatic);
	if aquaticName ~= nil then
		table.insert(tooltipParts, "[swimming,mod:"..groundToken.."]"..aquaticName);
	end

	local repairName = GetConfiguredMountMacroConditionLabel(MogCompanionsCharacterSaved and MogCompanionsCharacterSaved.Default and MogCompanionsCharacterSaved.Default.Repair);
	if repairName ~= nil then
		table.insert(tooltipParts, "[mod:"..repairToken.."]"..repairName);
	end

	local flyingName = nil;
	local groundName = nil;
	if outfitData ~= nil then
		flyingName = GetConfiguredMountMacroConditionLabel(outfitData.Flying);
		groundName = GetConfiguredMountMacroConditionLabel(outfitData.Ground);
	end

	if flyingName ~= nil then
		table.insert(tooltipParts, "[flyable,nomod:"..groundToken.."]"..flyingName);
	end
	if groundName ~= nil then
		table.insert(tooltipParts, groundName);
	end

	local macroBody = "#showtooltip";
	if #tooltipParts > 0 then
		macroBody = macroBody.." "..table.concat(tooltipParts, ";")..";";
	end
	macroBody = macroBody.."\n/run MogCompanionsSummon();";

	if not macroId then
		macroId = CreateMacro("MogComp Mount", 6841475, macroBody, nil);
	else
		EditMacro(macroId, "MogComp Mount", 6841475, macroBody, nil);
	end

	if MogCompanionsSaved ~= nil then
		MogCompanionsSaved.MacroID = macroId;
	end

	if parent ~= nil then
		PickupMacro(macroId);
		GameTooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT");
		GameTooltip:AddLine(L["Drop Macro Tooltip"], 1, 1, 1);
		GameTooltip:Show();
	end

	return macroId;
end

-- ── Mounts Tab UI (WardrobeCollection) ────────────────────────────────────────
-- Creates the full Mounts tab inside WardrobeCollection on first call (idempotent).
-- Contains: flying/ground model preview frames, scrollable mount lists, search box,
-- and filter dropdown (show flying in ground list).
-- SetSelectedFlyingMount and SetSelectedGroundMount are defined here as closures
-- over the local scroll-box and data-provider references.
function MogCompanions:InitMountTab()
	local collection = TransmogFrame and TransmogFrame.WardrobeCollection;
	if collection == nil or collection.TabContent == nil or collection.AddNamedTab == nil then
		return;
	end

	if not collection.companionsTabID then

		function TransmogFrame.WardrobeCollection:UpdateTabs()
			if self.TabHeaders then
				if self.itemsTabID then self.TabHeaders:SetTabShown(self.itemsTabID, true); end
				if self.setsTabID then self.TabHeaders:SetTabShown(self.setsTabID, true); end
				if self.custmSetsTabID then self.TabHeaders:SetTabShown(self.custmSetsTabID, true); end
				if self.situationsTabID then self.TabHeaders:SetTabShown(self.situationsTabID, true); end
				if self.companionsTabID then self.TabHeaders:SetTabShown(self.companionsTabID, true); end
			end
		end

		-- Layout scale factor (6/7 ≈ 0.857) that maps the 360-unit preview design coords to the wardrobe tab's actual rendered dimensions.
		local s = 0.85714285714;
		local topOffset = 26;

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

		local CompanionsFrame = CreateFrame("Frame", "MogCompanionsCompanionsFrame", collection.TabContent);
		CompanionsFrame:SetAllPoints(true);
		CompanionsFrame:SetFrameStrata("HIGH");
		CompanionsFrame:Hide();

		local f = CreateFrame("Frame", "MountsFrame", CompanionsFrame);
		f:SetAllPoints(true);
		f:SetFrameStrata("HIGH");
		f:Hide();

		-- Mount tab controls: gear dropdown, filter dropdown, and search box

		CreateShortcuts(f, topOffset);

		FilterDropdown = CreateFrame("DropdownButton", nil, f, "WowStyle1FilterDropdownTemplate");
		FilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -60, -50 + topOffset);
		FilterDropdown:SetWidth(104);		
		FilterDropdown.resizeToText = false;
		FilterDropdown:SetupMenu(function(dropdown, rootDescription)
				rootDescription:CreateCheckbox(L["Show Flying In Ground Toggle"], FilterIsChecked, FilterSetChecked);
		end)

		---		

		MountListSearchBox = CreateFrame("EditBox", "MountListSearchBox", f, "TransmogSearchBoxTemplate");
		MountListSearchBox:SetPoint("TOPRIGHT", -174, -50 + topOffset); --- -32, -444

		local iconPostion, iconParent, iconParentPostion, iconX, iconY = MountListSearchBox.searchIcon:GetPoint();
		MountListSearchBox.searchIcon:SetPoint(iconPostion, iconParent, iconParentPostion, iconX, iconY + 1);

		-- Flying and ground section title labels

		local FlyingSlotTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
		FlyingSlotTitle:SetJustifyH("LEFT");
		FlyingSlotTitle:SetPoint("TOPLEFT", 24, -76 + topOffset);
		FlyingSlotTitle:SetText(L["Mount Tab Flying Section Title"]);

		local FlyingSlotTitleDivider = f:CreateTexture();
		FlyingSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
		FlyingSlotTitleDivider:SetAlpha(0.1);
		FlyingSlotTitleDivider:SetPoint("TOPLEFT", FlyingSlotTitle, "BOTTOMLEFT", 0, -2);

		local GroundSlotTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
		GroundSlotTitle:SetJustifyH("LEFT");
		GroundSlotTitle:SetPoint("TOPLEFT", 24, -444 + topOffset);
		GroundSlotTitle:SetText(L["Mount Tab Ground Section Title"]);

		local GroundSlotTitleDivider = f:CreateTexture();
		GroundSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
		GroundSlotTitleDivider:SetAlpha(0.1);
		GroundSlotTitleDivider:SetPoint("TOPLEFT", GroundSlotTitle, "BOTTOMLEFT", 0, -2);

		-- Load display info for the flying and ground model previews

		local flyingModelID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);
		local groundModelID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);

		-- Flying mount model preview frame and list

		FlyingMountPreview = CreateFrame("Frame", "MountTabFlyingPreview", f);
		FlyingMountPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 24 * s, (-114 + topOffset) * s);
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
			local _, _, icon = C_MountJournal.GetMountInfoByID(value);

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

			if data.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying then
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

				if SavedFlyingMoundID ~= nil and SavedFlyingMoundID > 0 then
					FlyingMountModel:SetDisplayInfo(SavedFlyingMoundID);
					FlyingMountModel:SetAlpha(1);
				else
					FlyingMountModel:SetDisplayInfo(0);
					FlyingMountModel:SetAlpha(0);
				end
			end)
			button:SetScript("OnClick", function()
				FlyingMountSelectionBehavior:Select(button);
				SetSelectedFlyingMount(data.id);
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
			if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying then
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
		GroundMountPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 24 * s, (-564 + topOffset) * s);
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
			local _, _, icon = C_MountJournal.GetMountInfoByID(value);

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

			if data.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground then
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

				if SavedGroundMoundID ~= nil and SavedGroundMoundID > 0 then
					GroundMountModel:SetDisplayInfo(SavedGroundMoundID);
					GroundMountModel:SetAlpha(1);
				else
					GroundMountModel:SetDisplayInfo(0);
					GroundMountModel:SetAlpha(0);
				end
			end)
			button:SetScript("OnClick", function()
				GroundMountSelectionBehavior:Select(button);
				SetSelectedGroundMount(data.id);
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
			if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground then
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
				if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying then
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
				if mount.id == MogCompanionsCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground then
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

		if MogCompanions.CreateHearthstonesFrame ~= nil then
			MogCompanions:CreateHearthstonesFrame(CompanionsFrame);
		end

		if MogCompanions.CreatePetsFrame ~= nil then
			MogCompanions:CreatePetsFrame(CompanionsFrame);
		end

		-- Companions sub-tab buttons (Mounts, Hearthstones, Pets) at bottom of container.
		-- numTabs and Tabs are assigned manually; PanelTemplates_SetNumTabs is NOT used
		-- because it calls AnchorTabs internally, which would fight our manual anchors.

		local mountsTab = CreateFrame("Button", "MogCompanionsCompanionsTab1", CompanionsFrame, "PanelTabButtonTemplate", 1);
		mountsTab:SetID(1);
		mountsTab:SetText(L["Mount Tab Title"]);
		PanelTemplates_TabResize(mountsTab, 0);
		mountsTab:SetPoint("BOTTOMLEFT", CompanionsFrame, "BOTTOMLEFT", 16, 2);
		mountsTab:SetScript("OnClick", function(self)
			MogCompanions:OpenCompanionsSubTab(self:GetID());
		end);

		local hearthstonesTab = CreateFrame("Button", "MogCompanionsCompanionsTab2", CompanionsFrame, "PanelTabButtonTemplate", 2);
		hearthstonesTab:SetID(2);
		hearthstonesTab:SetText(L["Hearthstone Tab Title"]);
		PanelTemplates_TabResize(hearthstonesTab, 0);
		hearthstonesTab:SetPoint("LEFT", mountsTab, "RIGHT", 3, 0);
		hearthstonesTab:SetScript("OnClick", function(self)
			MogCompanions:OpenCompanionsSubTab(self:GetID());
		end);

		local petsTab = CreateFrame("Button", "MogCompanionsCompanionsTab3", CompanionsFrame, "PanelTabButtonTemplate", 3);
		petsTab:SetID(3);
		petsTab:SetText(L["Pets Tab Title"]);
		PanelTemplates_TabResize(petsTab, 0);
		petsTab:SetPoint("LEFT", hearthstonesTab, "RIGHT", 3, 0);
		petsTab:SetScript("OnClick", function(self)
			MogCompanions:OpenCompanionsSubTab(self:GetID());
		end);

		CompanionsFrame.numTabs = 3;
		CompanionsFrame.Tabs = { mountsTab, hearthstonesTab, petsTab };

		collection.companionsTabID = collection:AddNamedTab(L["Companions Tab Title"], CompanionsFrame);
		collection:UpdateTabs();

		MogCompanions:OpenCompanionsSubTab(1);
	end

end

-- Shows a specific Companions sub-tab (1=Mounts, 2=Hearthstones, 3=Pets) and updates
-- the PanelTab selection state. PanelTemplates_SetTab calls PanelTemplates_UpdateTabs
-- internally; do not call it again here.
function MogCompanions:OpenCompanionsSubTab(tabIndex)
	local companionsFrame = _G.MogCompanionsCompanionsFrame;
	if companionsFrame == nil then return; end

	if tabIndex ~= 1 and tabIndex ~= 2 and tabIndex ~= 3 then
		tabIndex = 1;
	end

	if _G.MountsFrame then
		_G.MountsFrame:SetShown(tabIndex == 1);
	end
	if _G.MogCompanionsHearthstonesPage then
		_G.MogCompanionsHearthstonesPage:SetShown(tabIndex == 2);
	end
	if _G.MogCompanionsPetsFrame then
		_G.MogCompanionsPetsFrame:SetShown(tabIndex == 3);
	end

	PanelTemplates_SetTab(companionsFrame, tabIndex);
end

-- Opens the Companions top-level tab and navigates to the given sub-tab by name
-- ("Mounts", "Hearthstones", or "Pets"). Builds the tab UI via InitMountTab if it
-- has not been built yet. Safe to call before the wardrobe has been opened.
function MogCompanions:OpenCompanionsTab(subTabName)
	if TransmogFrame == nil or TransmogFrame.WardrobeCollection == nil then return; end
	local collection = TransmogFrame.WardrobeCollection;

	if collection.companionsTabID == nil then
		MogCompanions:InitMountTab();
	end

	if collection.companionsTabID == nil then return; end

	if collection.SetTab then
		collection:SetTab(collection.companionsTabID);
	end

	local subTabIndex = 1;
	if subTabName == "Hearthstones" then
		subTabIndex = 2;
	elseif subTabName == "Pets" then
		subTabIndex = 3;
	end

	MogCompanions:OpenCompanionsSubTab(subTabIndex);
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
