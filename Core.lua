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

_G["BINDING_NAME_MOGCOMPANIONS_MOUNT_DISMOUNT"] = L["Binding Mount/Dismount"] or "Mount/Dismount";
_G["BINDING_NAME_CLICK MCHearthButton:LeftButton"] = L["Use Hearthstone"] or "Use Hearthstone";

local playerName = UnitName("player");
local transmogs = {};
local loaded = false;
local firstLoad = true;
local lastPetAutoSummonChangeKey;
local macroUpdateQueuedAfterCombat = false;

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
	print("|cFFFFFFFF/mcomp mount|r - "..L["Slash Help Mount Base"]);
	print("|cFFFFFFFF/mcomp mount [flying/ground/aquatic/repair/random/favorite/passenger]|r - "..L["Slash Help Mount"]);
	print("|cFFFFFFFF/mcomp pet|r - "..L["Slash Help Pet Base"]);
	print("|cFFFFFFFF/mcomp pet [random/favorite/dismiss]|r - "..L["Slash Help Pet"]);
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

-- Updates only already-existing macros for the active outfit.
-- The second argument (true) means "update existing only" — it will NOT create a new
-- macro if the user has never made one. Auto-update on login or outfit change should
-- never silently create macros the user did not request.
local function UpdateExistingMacrosForActiveOutfit()
	MogCompanions:CreateMountMacro(nil, true);
	MogCompanions:CreatePetMacro(nil, true);
end

-- Returns true if the modifier key configured for the pet macro action is held.
-- modType: "Random" | "Favorite" | "Dismiss"
-- Reads MogCompanionsSaved.PetMods: 1=CTRL, 2=SHIFT, 3=ALT.
-- Falls back to the default pet macro mapping if PetMods is not initialised yet.
local function GetPetModKey(modType)
	local mods = {};
	mods[1] = IsControlKeyDown();
	mods[2] = IsShiftKeyDown();
	mods[3] = IsAltKeyDown();

	if MogCompanionsSaved and MogCompanionsSaved.PetMods then
		if modType == "Random" then
			return mods[MogCompanionsSaved.PetMods.Random] or false;
		elseif modType == "Favorite" then
			return mods[MogCompanionsSaved.PetMods.Favorite] or false;
		elseif modType == "Dismiss" then
			return mods[MogCompanionsSaved.PetMods.Dismiss] or false;
		end
	else
		if modType == "Random" then return IsControlKeyDown(); end
		if modType == "Favorite" then return IsShiftKeyDown(); end
		if modType == "Dismiss" then return IsAltKeyDown(); end
	end

	return false;
end

-- Dismisses the currently summoned companion pet by summoning it a second time.
-- SummonPetByGUID toggles: calling it with the already-active GUID dismisses the pet.
-- This avoids a separate C_PetJournal.DismissPet call that doesn't exist in all API versions.
function MogCompanions:DismissPet()
	local petJournal = C_PetJournal;
	if petJournal == nil or petJournal.SummonPetByGUID == nil or petJournal.GetSummonedPetGUID == nil then
		return;
	end

	local activePetGUID = petJournal.GetSummonedPetGUID();
	if activePetGUID ~= nil and activePetGUID ~= "" then
		petJournal.SummonPetByGUID(activePetGUID);
	end
end

-- Ignores the active outfit's pet mode and summons a fully random pet.
-- Called when the user presses the Random modifier key — bypasses per-outfit selection
-- so the modifier always guarantees randomness regardless of how the outfit is configured.
function MogCompanions:SummonRandomPet()
	local petJournal = C_PetJournal;
	if petJournal == nil or petJournal.SummonPetByGUID == nil or petJournal.GetSummonedPetGUID == nil then
		return;
	end

	local activePetGUID = petJournal.GetSummonedPetGUID();
	local randomPetGUID = MogCompanions:getRandomPet(activePetGUID);
	if randomPetGUID ~= nil and randomPetGUID ~= "" then
		petJournal.SummonPetByGUID(randomPetGUID);
	end
end

-- Summons a random favorite pet when the Favorite modifier key is held.
-- Falls back to any random pet if the player has no favorites, so the modifier
-- never silently fails — the player always gets a pet even without favorites set.
function MogCompanions:SummonRandomFavoritePet()
	local petJournal = C_PetJournal;
	if petJournal == nil or petJournal.SummonPetByGUID == nil or petJournal.GetSummonedPetGUID == nil then
		return;
	end

	local activePetGUID = petJournal.GetSummonedPetGUID();

	local randomPetGUID = MogCompanions:getRandomPet(activePetGUID, true);
	if randomPetGUID == nil or randomPetGUID == "" then
		randomPetGUID = MogCompanions:getRandomPet(activePetGUID, false);
	end

	if randomPetGUID ~= nil and randomPetGUID ~= "" then
		petJournal.SummonPetByGUID(randomPetGUID);
	end
end

-- Normalizes the PetMode field from saved variables into a known-good string.
-- Treats missing, nil, or unrecognized values as "Selected" (the safest default),
-- so stale saved data from older versions never causes unhandled nil paths downstream.
local function GetNormalizedPetMode(outfitData)
	if type(outfitData) ~= "table" then
		return "Selected";
	end

	local mode = outfitData.PetMode;
	if mode == "None" or mode == "Random" or mode == "Favorite" or mode == "Selected" then
		return mode;
	end

	return "Selected";
end

-- Returns the pet mode that would be used if the pet macro were activated right
-- now, applying the same modifier-key priority as HandlePetAction:
--   Dismiss modifier  =>  "None"
--   Favorite modifier =>  "Favorite"
--   Random modifier   =>  "Random"
--   (no modifier)     =>  the outfit's configured PetMode
function MogCompanions:GetEffectivePetMode(outfitData)
	if GetPetModKey("Dismiss") then
		return "None";
	elseif GetPetModKey("Favorite") then
		return "Favorite";
	elseif GetPetModKey("Random") then
		return "Random";
	end
	return GetNormalizedPetMode(outfitData);
end

-- User-triggered pet summon (macro / keybind, no modifier held).
-- Respects the active outfit's PetMode: None dismisses, Random/Favorite pick randomly,
-- Selected picks a random pet from the outfit's assigned pool.
-- Unlike SummonAssignedOutfitPet, this is NOT idempotent — it always re-rolls
-- so pressing the macro again cycles to a different pet.
function MogCompanions:SummonPet()
	local petJournal = C_PetJournal;
	if petJournal == nil or petJournal.SummonPetByGUID == nil or petJournal.GetSummonedPetGUID == nil then
		return;
	end

	local outfitData = MogCompanions:GetActiveOutfitTable();
	local petMode = GetNormalizedPetMode(outfitData);

	if petMode == "None" then
		MogCompanions:DismissPet();
		return;
	elseif petMode == "Random" then
		local activePetGUID = petJournal.GetSummonedPetGUID();
		local randomPetGUID = MogCompanions:getRandomPet(activePetGUID, false);
		if randomPetGUID ~= nil and randomPetGUID ~= "" then
			petJournal.SummonPetByGUID(randomPetGUID);
		end
		return;
	elseif petMode == "Favorite" then
		local activePetGUID = petJournal.GetSummonedPetGUID();
		local randomFavoritePetGUID = MogCompanions:getRandomPet(activePetGUID, true);
		if randomFavoritePetGUID ~= nil and randomFavoritePetGUID ~= "" then
			petJournal.SummonPetByGUID(randomFavoritePetGUID);
			return;
		end

		-- Fall back to random if no valid favorite pet is available.
		local randomPetGUID = MogCompanions:getRandomPet(activePetGUID, false);
		if randomPetGUID ~= nil and randomPetGUID ~= "" then
			petJournal.SummonPetByGUID(randomPetGUID);
		end
		return;
	end

	local function IsValidOwnedPetGUID(petGUID)
		if type(petGUID) ~= "string" or petGUID == "" then
			return false;
		end

		return MogCompanions:IsPetSummonableOwned(petGUID);
	end

	local activePetGUID = petJournal.GetSummonedPetGUID();
	local activePetGUIDKey = activePetGUID ~= nil and tostring(activePetGUID) or "";
	local selectedPetGUIDs = {};

	if outfitData ~= nil then
		selectedPetGUIDs = MogCompanions:GetValidSelectionPoolValues(outfitData, "Pets", function(_, petID)
			return IsValidOwnedPetGUID(petID);
		end);
	end

	if #selectedPetGUIDs > 0 then
		local summonPool = {};

		for i = 1, #selectedPetGUIDs do
			local candidatePetGUID = selectedPetGUIDs[i];
			if type(candidatePetGUID) == "string" and candidatePetGUID ~= "" then
				if activePetGUIDKey == "" or candidatePetGUID ~= activePetGUIDKey then
					table.insert(summonPool, candidatePetGUID);
				end
			end
		end

		if #summonPool == 0 then
			return;
		end

		local selectedPetGUID = summonPool[math.random(1, #summonPool)];
		local currentPetGUID = petJournal.GetSummonedPetGUID();
		local currentPetGUIDKey = currentPetGUID ~= nil and tostring(currentPetGUID) or activePetGUIDKey;
		if selectedPetGUID ~= nil and selectedPetGUID ~= "" and selectedPetGUID ~= currentPetGUIDKey and IsValidOwnedPetGUID(selectedPetGUID) then
			petJournal.SummonPetByGUID(selectedPetGUID);
			return;
		end
	end

	local randomPetGUID = MogCompanions:getRandomPet(activePetGUID);
	if randomPetGUID ~= nil and randomPetGUID ~= "" then
		petJournal.SummonPetByGUID(randomPetGUID);
	end
end

-- Auto-summon the outfit's assigned pet on login, mount, or outfit change.
-- Unlike SummonPet (user-triggered), this is idempotent: if the correct pet is already
-- summoned it does nothing. forceRandom re-rolls even when the current pet is valid,
-- which is used when the outfit changes so the pet visually matches the new outfit.
-- options.reason controls which setting gate is checked (PetSummonOnChange, etc.).
function MogCompanions:SummonAssignedOutfitPet(options)
	options = options or {};
	local forceRandom = options.forceRandom == true;

	if InCombatLockdown and InCombatLockdown() then
		return false;
	end

	local petJournal = C_PetJournal;
	if petJournal == nil or petJournal.SummonPetByGUID == nil or petJournal.GetSummonedPetGUID == nil then
		return false;
	end

	local function IsValidOwnedPetGUID(petGUID)
		if type(petGUID) ~= "string" or petGUID == "" then
			return false;
		end

		return MogCompanions:IsPetSummonableOwned(petGUID);
	end

	local outfitData = MogCompanions:GetActiveOutfitTable();
	if outfitData == nil then
		return false;
	end

	local petMode = GetNormalizedPetMode(outfitData);
	local activePetGUID = petJournal.GetSummonedPetGUID();

	if petMode == "None" then
		-- Only dismiss on outfit change. On mount/login, leave manually summoned pets alone.
		if options.reason == "PetSummonOnChange" then
			MogCompanions:DismissPet();
		end
		return true;
	elseif petMode == "Random" then
		if not forceRandom and IsValidOwnedPetGUID(activePetGUID) then
			return true;
		end

		local randomPetGUID = MogCompanions:getRandomPet(activePetGUID, false);
		if randomPetGUID ~= nil and randomPetGUID ~= "" and IsValidOwnedPetGUID(randomPetGUID) then
			petJournal.SummonPetByGUID(randomPetGUID);
			return true;
		end

		return false;
	elseif petMode == "Favorite" then
		local hasFavoritePet = MogCompanions:HasFavoritePet();

		if not forceRandom then
			if hasFavoritePet then
				if IsValidOwnedPetGUID(activePetGUID) and MogCompanions:IsFavoritePet(activePetGUID) then
					return true;
				end
			else
				-- No favorites exist, so Favorite mode has fallen back to Random mode.
				-- Random mode is satisfied by any valid currently summoned pet.
				if IsValidOwnedPetGUID(activePetGUID) then
					return true;
				end
			end
		end

		local randomFavoritePetGUID = MogCompanions:getRandomPet(activePetGUID, true);
		if randomFavoritePetGUID ~= nil and randomFavoritePetGUID ~= "" and IsValidOwnedPetGUID(randomFavoritePetGUID) then
			petJournal.SummonPetByGUID(randomFavoritePetGUID);
			return true;
		end

		-- Fall back to random if no valid favorite pet is available.
		local randomPetGUID = MogCompanions:getRandomPet(activePetGUID, false);
		if randomPetGUID ~= nil and randomPetGUID ~= "" and IsValidOwnedPetGUID(randomPetGUID) then
			petJournal.SummonPetByGUID(randomPetGUID);
			return true;
		end

		return false;
	end

	local selectedPetGUIDs = MogCompanions:GetValidSelectionPoolValues(outfitData, "Pets", function(_, petID)
		return IsValidOwnedPetGUID(petID);
	end);

	-- Auto-summon only from this outfit's assigned pet pool.
	if #selectedPetGUIDs == 0 then
		return true;
	end

	local activePetGUIDKey = activePetGUID ~= nil and tostring(activePetGUID) or "";

	-- If the current pet is already one of the valid assigned pets, do nothing (idempotent).
	if activePetGUIDKey ~= "" then
		for i = 1, #selectedPetGUIDs do
			if selectedPetGUIDs[i] == activePetGUIDKey then
				return true;
			end
		end
	end

	-- Summon a random pet from the valid assigned outfit pet pool.
	local selectedPetGUID = selectedPetGUIDs[math.random(1, #selectedPetGUIDs)];
	if selectedPetGUID ~= nil and selectedPetGUID ~= "" and IsValidOwnedPetGUID(selectedPetGUID) then
		petJournal.SummonPetByGUID(selectedPetGUID);
		return true;
	end

	return false;
end

-- Returns true if the player is currently inside an instance type that is
-- configured to dismiss/suppress pets (PvE or PvP).
function MogCompanions:ShouldDismissPetForCurrentInstance()
	if MogCompanionsSaved == nil then return false; end
	if IsInInstance == nil then return false; end
	local inInstance, instanceType = IsInInstance();
	if not inInstance then return false; end
	if (instanceType == "raid" or instanceType == "party" or instanceType == "scenario") and MogCompanionsSaved.PetDismissInPvE then
		return true;
	end
	if (instanceType == "pvp" or instanceType == "arena") and MogCompanionsSaved.PetDismissInPvP then
		return true;
	end
	return false;
end

-- Dispatches an auto-summon for the given setting trigger (PetSummonOnMount,
-- PetSummonOnLogin, PetSummonOnChange). Bails early if the corresponding setting
-- is off or if the current instance type suppresses pets.
-- For PetSummonOnChange, lastPetAutoSummonChangeKey deduplicates rapid outfit-change
-- events so the same outfit+mode combination never fires twice in a row.
function MogCompanions:HandleAutoPetSummon(settingKey)
	if type(settingKey) ~= "string" or settingKey == "" then
		return;
	end

	if MogCompanionsSaved == nil or MogCompanionsSaved[settingKey] ~= true then
		return;
	end

	if MogCompanions:ShouldDismissPetForCurrentInstance() then
		return;
	end

	local outfitData = MogCompanions:GetActiveOutfitTable();
	if outfitData == nil then
		return;
	end

	local petMode = GetNormalizedPetMode(outfitData);

	if settingKey == "PetSummonOnChange" then
		local activeOutfitID = MogCompanions:GetSafeActiveOutfitID();

		if activeOutfitID ~= nil then
			local autoKey = tostring(activeOutfitID) .. ":" .. petMode;

			if lastPetAutoSummonChangeKey == autoKey then
				return;
			end

			local forceReroll = (petMode == "Random" or petMode == "Favorite");
			local handled = MogCompanions:SummonAssignedOutfitPet({
				reason = settingKey,
				forceRandom = forceReroll,
			});

			if handled then
				lastPetAutoSummonChangeKey = autoKey;
			end

			return;
		end
	end

	MogCompanions:SummonAssignedOutfitPet({
		reason = settingKey,
		forceRandom = false,
	});
end

-- Cache: lowercase name → pet GUID for all owned summonable pets.
-- Indexes both species name and custom name for matching.
-- nil means not built yet (or was invalidated).
local petCloneCache = nil;

local function buildPetCloneCache()
	petCloneCache = {};
	if C_PetJournal == nil or C_PetJournal.GetOwnedPetIDs == nil then
		return;
	end

	local petsRaw = C_PetJournal.GetOwnedPetIDs();
	for i = 1, #petsRaw do
		local petID = petsRaw[i];
		if MogCompanions:IsPetSummonableOwned(petID) then
			local info = MogCompanions:GetPetInfoSafe(petID);
			if info ~= nil and info.name ~= nil then
				local speciesKey = info.name:lower();
				if petCloneCache[speciesKey] == nil then
					petCloneCache[speciesKey] = petID;
				end
				if info.customName ~= nil and info.customName ~= "" then
					local customKey = info.customName:lower();
					if petCloneCache[customKey] == nil then
						petCloneCache[customKey] = petID;
					end
				end
			end
		end
	end
end

-- Invalidate the cache when pet collection changes.
local PetCloneCacheFrame = CreateFrame("Frame");
PetCloneCacheFrame:RegisterEvent("PET_JOURNAL_LIST_UPDATE");
PetCloneCacheFrame:SetScript("OnEvent", function() petCloneCache = nil; end);

-- Returns the pet GUID of a companion pet the target unit matches, if the local
-- player also has that pet owned and summonable. Returns nil otherwise.
-- Only called from HandlePetAction (macro/keybind press), never from auto-summon.
local function tryCloneTargetedPet()
	if not MogCompanionsSaved or not MogCompanionsSaved.CloneTargetedPet then return nil; end
	if not UnitExists("target") then return nil; end

	if not petCloneCache then
		buildPetCloneCache();
	end

	local targetName = UnitName("target");
	if targetName then
		local guid = petCloneCache[targetName:lower()];
		if guid then return guid; end
	end

	return nil;
end

-- Top-level user-facing pet action (macro / keybind).
-- Priority: clone target pet first (so /click always mirrors what you're targeting),
-- then modifier keys (Dismiss > Favorite > Random), then the outfit's configured mode.
-- This priority must mirror GetEffectivePetMode's logic.
function MogCompanions:HandlePetAction()
	local cloneGUID = tryCloneTargetedPet();
	if cloneGUID then
		if C_PetJournal and C_PetJournal.SummonPetByGUID then
			C_PetJournal.SummonPetByGUID(cloneGUID);
		end
		return;
	end

	if GetPetModKey("Dismiss") then
		MogCompanions:DismissPet();
	elseif GetPetModKey("Favorite") then
		MogCompanions:SummonRandomFavoritePet();
	elseif GetPetModKey("Random") then
		MogCompanions:SummonRandomPet();
	else
		MogCompanions:SummonPet();
	end
end

SLASH_MOGCOMPANIONS1 = "/mcomp";
SlashCmdList["MOGCOMPANIONS"] = function(msg)
	local trimmed = string.lower(string.match(msg or "", "^%s*(.-)%s*$"));
	local cmd = string.match(trimmed, "^(%S+)") or "";
	-- Strip optional square brackets so "/mcomp mount [flying]" works like "/mcomp mount flying".
	local sub = string.gsub(string.match(trimmed, "^%S+%s+(%S+)") or "", "[%[%]]", "");

	if cmd == "" or cmd == "help" then
		if MogCompanions.ShowConflictResolver ~= nil then
			MogCompanions:ShowConflictResolver();
		end
		PrintSlashHelp();
	elseif cmd == "mount" then
		if sub == "flying" then
			MogCompanionsSummonFlying();
		elseif sub == "ground" then
			MogCompanionsSummonGround();
		elseif sub == "repair" then
			MogCompanionsSummonRepair();
		elseif sub == "aquatic" then
			MogCompanionsSummonAquatic();
		elseif sub == "random" then
			MogCompanionsSummonRandom();
		elseif sub == "favorite" then
			MogCompanionsSummonFavoriteMount();
		elseif sub == "passenger" then
			MogCompanionsSummonPassenger();
		else
			MogCompanionsSummon();
		end
	elseif cmd == "pet" then
		if sub == "random" then
			MogCompanions:SummonRandomPet();
		elseif sub == "favorite" then
			MogCompanions:SummonRandomFavoritePet();
		elseif sub == "dismiss" then
			MogCompanions:DismissPet();
		else
			MogCompanions:HandlePetAction();
		end
	elseif cmd == "options" then
		OpenSettingsToMogCompanions();
	else
		if MogCompanions.ShowConflictResolver ~= nil then
			MogCompanions:ShowConflictResolver();
		end
		PrintSlashHelp();
	end
end

SLASH_MOGCOMPANIONS_MOUNT1 = "/mcmt";
SlashCmdList["MOGCOMPANIONS_MOUNT"] = function()
	MogCompanionsSummon();
end

-- ── Transmog Title Dropdown UI ──────────────────────────────────────────────
-- Persists a per-character Settings API value to MogCompanionsCharacterSaved.
-- The Settings API binds to the variable table directly; this callback exists so
-- any future side-effects (e.g. UI refresh) can be added without changing each
-- individual setting registration.
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

-- Shared gear dropdown used by the Mounts, Hearthstones, and Pets tabs.
-- The caller owns positioning; this helper only creates the button and standard menu.
function MogCompanions:CreateCompanionsShortcutMenu(parent, frameName)
	local dropdown = CreateFrame("DropdownButton", frameName, parent, "DamageMeterSettingsDropdownButtonTemplate");
	dropdown:SetupMenu(function(_, rootDescription)
		rootDescription:CreateTitle("MogCompanions");
		rootDescription:CreateButton(L["Open Settings"], function() MogCompanions:OpenSettings() end);
		rootDescription:CreateButton(L["Open Keybinds"], function() MogCompanions:OpenKeybinds() end);
		rootDescription:CreateDivider();
		rootDescription:CreateButton(L["Create Mount Macro"], function() MogCompanions:CreateMountMacro(dropdown) end);
		rootDescription:CreateButton(L["Create Pet Macro"], function() MogCompanions:CreatePetMacro(dropdown) end);
		rootDescription:CreateButton(L["Create Hearthstone Macro"], function() MogCompanions:CreateHearthstoneMacro(dropdown) end);
	end);

	return dropdown;
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
	if event == "PLAYER_ENTERING_WORLD" then
		if not loaded then
			lastPetAutoSummonChangeKey = nil;

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
			if MogCompanionsSaved.CloneTargetedPet == nil then
				MogCompanionsSaved.CloneTargetedPet = false;
			end
			if MogCompanionsSaved.DynamicMountMacroIcon == nil then
				MogCompanionsSaved.DynamicMountMacroIcon = false;
			end
			if MogCompanionsSaved.DynamicPetMacroIcon == nil then
				MogCompanionsSaved.DynamicPetMacroIcon = false;
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

			if MogCompanionsSaved.PetDismissInPvE == nil then
				MogCompanionsSaved.PetDismissInPvE = false;
			end

			if MogCompanionsSaved.PetDismissInPvP == nil then
				MogCompanionsSaved.PetDismissInPvP = false;
			end

			loaded = true;

			C_Timer.After(0.1, function()
				if MogCompanionsSaved.DynamicMountMacroIcon or MogCompanionsSaved.DynamicPetMacroIcon then
					UpdateExistingMacrosForActiveOutfit();
				end
				if MogCompanionsSaved.PetSummonOnLogin then
					MogCompanions:HandleAutoPetSummon("PetSummonOnLogin");
				end
			end);

		else
			-- Zone/instance change after initial load.
			if MogCompanions:ShouldDismissPetForCurrentInstance() then
				C_Timer.After(0.5, function()
					MogCompanions:DismissPet();
				end);
			else
				C_Timer.After(0.5, function()
					MogCompanions:HandleAutoPetSummon("PetSummonOnLogin");
				end);
			end
		end
	end

	if event == "PLAYER_ALIVE" then
		if loaded then
			C_Timer.After(0.5, function()
				MogCompanions:HandleAutoPetSummon("PetSummonOnLogin");
			end);
		end
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

	if event == "TRANSMOG_DISPLAYED_OUTFIT_CHANGED" then
		C_Timer.After(0.1, function()
			MogCompanions:HandleAutoPetSummon("PetSummonOnChange");
			if InCombatLockdown and InCombatLockdown() then
				macroUpdateQueuedAfterCombat = true;
				return;
			end

			UpdateExistingMacrosForActiveOutfit();
		end);
	end

	if event == "PLAYER_REGEN_ENABLED" then
		if macroUpdateQueuedAfterCombat then
			macroUpdateQueuedAfterCombat = false;
			UpdateExistingMacrosForActiveOutfit();
		end
	end

	if event == "TRANSMOGRIFY_OPEN" then
		C_Timer.After(0.1, function()
			MogCompanions:InitMountTab();
		end)
	end
end

MogCompanions:RegisterEvent("ADDON_LOADED")
MogCompanions:RegisterEvent("PLAYER_ENTERING_WORLD")
MogCompanions:RegisterEvent("PLAYER_ALIVE")
MogCompanions:RegisterEvent("TRANSMOGRIFY_OPEN")
MogCompanions:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_CHANGED")
MogCompanions:RegisterEvent("TRANSMOG_DISPLAYED_OUTFIT_CHANGED")
MogCompanions:RegisterEvent("PLAYER_REGEN_ENABLED")

MogCompanions:SetScript("OnEvent", MogCompanions.OnEvent)
