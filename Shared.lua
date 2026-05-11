local _, addon = ...;
local ns = select(2,...);
local MogMount = ns.MogMount;

local playerName = UnitName("player");



function MogMountSortAlphabetical(a, b)

	return a.name:lower() < b.name:lower();

end



function MogMount:hasValue(table, value)

	for i, v in ipairs(table) do
		if v == value then
			return true;
		end
	end

	return false;

end



function MogMount:GetCollectedMounts()

	local collectedMounts = {};
	local mountIDs = C_MountJournal.GetMountIDs();

	for _, mountID in ipairs(mountIDs) do
		local name, _, _, _, isUsable, _, _, _, _, shouldHideOnChar, isCollected, mountID_, _ = C_MountJournal.GetMountInfoByID(mountID);
		if isCollected and not shouldHideOnChar then
			table.insert(collectedMounts, mountID_);
		end
	end

	return collectedMounts;

end



function MogMount:sortMounts(mountsRaw)

	local mounts = {};

	for i = 1, #mountsRaw do

		name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(mountsRaw[i]);
		creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountsRaw[i]);
		
		local temp = {};
		temp["name"] = name;
		temp["icon"] = icon;
		temp["nameAndIcon"] = "|T"..icon..":18|t "..name;
		temp["id"] = mountID;
		temp["model"] = creatureDisplayInfoID;
		temp["mountTypeID"] = mountTypeID;
		
		if isCollected and not shouldHideOnChar and isUsable then
			table.insert(mounts, temp);
		end

	end

	table.sort(mounts, MogMountSortAlphabetical);

	return mounts;

end



function MogMount:listSearchString(name)

	if MogMount.MountSearchString == "" or MogMount.MountSearchString == nil or string.len(MogMount.MountSearchString) < 1 then
		return true;
	elseif string.len(MogMount.MountSearchString) >= 1 and string.find(name:lower(), MogMount.MountSearchString:lower()) then
		return true;
	else
		return false;
	end

end



function MogMount:getSortedFlyingMounts()

	local mountsRaw = MogMount:sortMounts(C_MountJournal.GetCollectedDragonridingMounts());
	local mounts = {};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if MogMount:listSearchString(mount.name) then
			table.insert(mounts, mount);
		end
	end 

	return mounts;

end



function MogMount:getSortedGroundMounts()

	local mountsRaw = MogMount:sortMounts(MogMount:GetCollectedMounts());
	local mounts = {};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if (mount.mountTypeID == 230 or MogMountSaved.ShowFlyingInGround) and MogMount:listSearchString(mount.name) then
			table.insert(mounts, mount);
		end
	end

	return mounts;

end



function MogMount:getSortedAquaticMounts()

	local mountsRaw = MogMount:sortMounts(MogMount:GetCollectedMounts());
	local mounts = {};
	local aquaticTypeIDs = {231, 232, 254, 407, 436};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if MogMount:hasValue(aquaticTypeIDs, mount.mountTypeID) then
			table.insert(mounts, mount);
		end
	end

	return mounts;

end



function MogMount:getSortedSpecialMounts()

	local mountsRaw = MogMount:sortMounts(MogMount:GetCollectedMounts());
	local mounts = {};
	local specialMountIDs = {460, 280, 284, 273, 274, 1039, 2237};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if MogMount:hasValue(specialMountIDs, mount.id) then
			table.insert(mounts, mount);
		end
	end

	return mounts;

end



function MogMount:getSortedAlternativeMounts()

	local mountsRaw = MogMount:sortMounts(MogMount:GetCollectedMounts());
	local mounts = {};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		table.insert(mounts, mount);
	end

	return mounts;

end



function MogMount:getRandomMount(type)

	local mounts = {}

	if type == "flying" then
		mounts = MogMount:getSortedFlyingMounts();
	elseif type == "ground" then
		mounts = MogMount:getSortedGroundMounts();
	elseif type == "aquatic" then
		mounts = MogMount:getSortedAquaticMounts();
	elseif type == "special" then
		mounts = MogMount:getSortedSpecialMounts();
	elseif type == "alternative" then
		mounts = MogMount:getSortedAlternativeMounts();		
	else
		mounts = MogMount:getSortedFlyingMounts();
	end
	
	if #mounts == 0 then
		return nil;
	end

	local rand = math.random(1, #mounts);

	return mounts[rand];

end



MogMount.EmptyHearthstoneIcon = 134414;
MogMount.HearthstoneToyItemIDs = {
    64488,  -- The Innkeeper's Daughter
    93672,  -- Dark Portal
    142542, -- Tome of Town Portal
    162973, -- Greatfather Winter's Hearthstone
    163045, -- Headless Horseman's Hearthstone
    165669, -- Lunar Elder's Hearthstone
    165670, -- Peddlefeet's Lovely Hearthstone
    165802, -- Noble Gardener's Hearthstone
    166746, -- Fire Eater's Hearthstone
    166747, -- Brewfest Reveler's Hearthstone
    168907, -- Holographic Digitalization Hearthstone
    172179, -- Eternal Traveler's Hearthstone
    180290, -- Night Fae Hearthstone
    182773, -- Necrolord Hearthstone
    183716, -- Venthyr Sinstone
    184353, -- Kyrian Hearthstone
    188952, -- Dominated Hearthstone
    190196, -- Enlightened Hearthstone
    190237, -- Broker Translocation Matrix
    193588, -- Timewalker's Hearthstone
    200630, -- Ohn'ir Windsage's Hearthstone
    206195, -- Path of the Naaru
    208704, -- Deepdweller's Earthen Hearthstone
    209035, -- Hearthstone of the Flame
    210455, -- Draenic Hologem
    212337, -- Stone of the Hearth
    228940, -- Notorious Thread's Hearthstone
    235016, -- Redeployment Module
    236687, -- Explosive Hearthstone
    245970, -- P.O.S.T. Master's Express Hearthstone
    246565, -- Cosmic Hearthstone
    257736, -- Lightcalled Hearthstone
    263489, -- Naaru's Enfold
    263933, -- Preyseeker's Hearthstone
    265100, -- Corewarden's Hearthstone
};



function MogMount:listHearthstoneSearchString(name)

	if MogMount.HearthstoneSearchString == "" or MogMount.HearthstoneSearchString == nil or string.len(MogMount.HearthstoneSearchString) < 1 then
		return true;
	elseif string.len(MogMount.HearthstoneSearchString) >= 1 and string.find(name:lower(), MogMount.HearthstoneSearchString:lower()) then
		return true;
	else
		return false;
	end

end



function MogMount:IsHearthstoneToyCollected(itemID)

	if itemID == nil or itemID <= 1 then
		return false;
	end

	if PlayerHasToy then
		return PlayerHasToy(itemID);
	end

	return false;

end



function MogMount:GetHearthstoneToyInfo(itemID)
	if itemID == nil or itemID <= 1 then
		return nil;
	end

	local toyName;
	local icon;

	if C_ToyBox and C_ToyBox.GetToyInfo then
		local _, name, toyIcon = C_ToyBox.GetToyInfo(itemID);
		toyName = name;
		icon = toyIcon;
	end

	if toyName == nil then
		local itemName, _, _, _, _, _, _, _, _, itemIcon;

		if C_Item and C_Item.GetItemInfo then
			itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID);
		else
			itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID);
		end

		toyName = itemName;
		icon = itemIcon;
	end

	if toyName == nil then
		if C_Item and C_Item.RequestLoadItemDataByID then
			C_Item.RequestLoadItemDataByID(itemID);
		end
		return nil;
	end

	local toy = {};
	toy.name = toyName;
	toy.icon = icon or MogMount.EmptyHearthstoneIcon;
	toy.nameAndIcon = "|T"..toy.icon..":18|t "..toyName;
	toy.id = itemID;

	return toy;
end
 
function MogMount:getSortedHearthstoneToys(ignoreSearch)

	local toys = {};

	for i = 1, #MogMount.HearthstoneToyItemIDs do
		local itemID = MogMount.HearthstoneToyItemIDs[i];

		if MogMount:IsHearthstoneToyCollected(itemID) then
			local toy = MogMount:GetHearthstoneToyInfo(itemID);

			if toy ~= nil and (ignoreSearch or MogMount:listHearthstoneSearchString(toy.name)) then
				table.insert(toys, toy);
			end
		end
	end

	table.sort(toys, MogMountSortAlphabetical);

	return toys;

end



function MogMount:getRandomHearthstoneToy()

	local toys = MogMount:getSortedHearthstoneToys(true);

	if #toys == 0 then
		return nil;
	end

	local rand = math.random(1, #toys);

	return toys[rand];

end



local function CreateDisplayTitle(titleID)

	local title, _ = GetTitleName(titleID);
	local displayTitle = "";

	if titleID == 0 then
		return playerName;
	end

	if title:sub(-1) == " " then
		displayTitle = title..playerName;
	else
		displayTitle = playerName.." "..title;
	end

	return displayTitle;

end



function MogMount:getSortedTitles()

	local titlesRaw = {}
	local count = 1;

	for i = 1, GetNumTitles() do
		if IsTitleKnown(i) then
			titlesRaw[count] = {};
			titlesRaw[count].id = i;
			titlesRaw[count].name = CreateDisplayTitle(i);
			count = count + 1;				
		end
	end

	table.sort(titlesRaw, MogMountSortAlphabetical)

	return titlesRaw;
end



function MogMount:UpdateSelectMountDetails(type, id)

	name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(id);
	creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(id);
			
	MogMountSelectedMount[type].name = name;
	MogMountSelectedMount[type].spellID = name;
	MogMountSelectedMount[type].icon = icon;
	MogMountSelectedMount[type].id = mountID;
	MogMountSelectedMount[type].display = creatureDisplayInfoID;
	MogMountSelectedMount[type].type = mountTypeID;

end



function MogMount:CreateEmptyOutfit(id)

	if MogMountCharacterSaved ~= nil and MogMountCharacterSaved["Outfit"..id] == nil then
		MogMountCharacterSaved["Outfit"..id] = {};
		MogMountCharacterSaved["Outfit"..id].Flying = 1;
		MogMountCharacterSaved["Outfit"..id].Ground = 1;
		MogMountCharacterSaved["Outfit"..id].Hearthstone = 1;
		MogMountCharacterSaved["Outfit"..id].Title = 0;
	elseif MogMountCharacterSaved ~= nil and MogMountCharacterSaved["Outfit"..id].Hearthstone == nil then
		MogMountCharacterSaved["Outfit"..id].Hearthstone = 1;
	end

end
