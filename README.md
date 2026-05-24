# MogCompanions
Pair your companions (mounts, pets, hearthstones) with your transmog outfit for World of Warcraft

## Attribution
This addon is based off of a fork of MogMount by perrinthesmith.

Original project:
https://www.curseforge.com/wow/addons/mogmount

Original license:
Creative Commons Attribution 4.0 International Public License

This version includes modifications, maintenance updates, and additional functionality. It is not affiliated with, endorsed by, sponsored by, or maintained by the original author.

## AI Assistance Notice
Some modifications in this version were developed with assistance from AI coding tools. AI-generated suggestions were reviewed and edited before inclusion.

No third-party code is knowingly included beyond the work credited above and code otherwise permitted by applicable licenses. If you believe any part of this project improperly includes code or patterns from another project, please open an issue with details so it can be reviewed and corrected.

## Contributions
Simplified Chinese localization contributed by XingDVD.

## Version History

### 1.0
* Initial release
* Added `/mcomp` slash command
* Added Hearthstones tab support for selecting an owned Hearthstone toy per outfit.

### 1.1
* Consolidated mounts, hearthstones, and pets into a single Companions tab with dedicated sub-tabs.
* Added multi-selection support for mounts, hearthstones, and pets.
* Added companion pet support:
  * Assign pets to individual transmog outfits.
  * Use `/mcomp pet` to summon the outfit pet, or a random pet when no pet is selected.
  * Create a pet macro from the Companions shortcut menu.
* Added mount and pet preview controls for zooming, positioning, rotating, and resetting preview models.
* Added configurable macro modifiers for mounts, hearthstones, and pets.
* Added Clone targeted mount setting. When enabled, summoning a random mount while targeting a mounted player will summon the same mount if you own it.
* Renamed "Special Mount" to "Repair Mount" and "Alternative Mount" to "Random Mount" for clearer behavior.
* Improved selection cleanup so invalid, unowned, or unavailable selections are removed automatically.

### 1.2
* Added a MogMount to Mog Companions importer
* Added a warning dialog if both addons are enabled at the same time

### 1.3
* Added support for companion pet auto-summoning by outfit.
* Added per-outfit pet modes:
  * Selected Pets: summon from the pets assigned to the current outfit.
  * No Pet: automatically dismiss the active pet when using that outfit.
  * Random Pet: summon a random owned pet for that outfit.
  * Random Favorite Pet: summon a random favorite pet, with fallback to random if no favorites are available.
* Added pet auto-summon settings for outfit changes, login, and mount/dismount behavior.
* Bug fixes on various pet summoning behavior

### 1.4
* Added dynamic icon support to macros
* Added options to auto-dismiss pets in PvE/PvP
* Improved auto-summon on login to include zone changes, resurrection, and flight path landing

### 1.5
* Added per-outfit mount modes for Flying and Ground mounts:
  * Selected Mounts: summon from the mounts assigned to the current outfit.
  * Random Favorite Mount: summon a random favorite mount from the Mount Journal.
  * Random Passenger Mount: summon a random passenger-capable mount.
* Added Passenger Mount support:
  * Flying Passenger mode prefers passenger-capable flying mounts.
  * Ground Passenger mode prefers passenger-capable ground mounts.
  * Falls back to a regular mount when no matching passenger mount is available.
* Added `/mcomp mount [category]` slash command support.
* Added `/mcomp pet [category]` slash command support.
* Added Favorite and Passenger buttons above the Flying and Ground mount lists.
* Added Create Macro buttons to the Options panel.
* Added Clone targeted pet setting.
* Updated hearthstone toy list with missing hearthstones.
* Updated aquatic mount list with missing mounts.

### 1.5.1
* Added Simplified Chinese localization - Thank you XingDVD for the localization contribution.

### 1.5.2
* Added missing Simplified Chinese localization file
