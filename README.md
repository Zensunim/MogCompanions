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
* Added a warning message if both addons are enabled at the same time
