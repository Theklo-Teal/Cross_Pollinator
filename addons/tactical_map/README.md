By default, the plugin uses assets in its "Assets" plugin folder. To change the location edit «settings.ini».
The actions of characters are also picked from the folder specified in the «settings.ini». The actions of the default location are always loaded, but may be overriden at the given location.

When using the plugin, the first thing you do is add a "TacNav" node to your scene. It groups maps together and makes navigation from map-to-map possible.
Having multiple maps lets you have areas of the world that are modular, altering them doesn't interfer with others, or avoid calculating a lot of empty grid cells, if there's long narrow corridor between two rooms, for example.
Maps can also have different heights (layers), so you could make platforms or different floors to a building, for example.

After you add TacMap nodes as children of TacNav, when you click on them, the plugin panel comes up so you can select an asset and clicking on the map will set that asset.
Tool help will appear depending on which asset type or tool are selected. To add Characters you go to the "Other Tab". There you may select between adding a spawner of the player characters, or NPCs.

The plugin provides the class "TacEntity" which only defines interaction rules, like if an entity is clicked on, it triggers signals.
"TacCharacter" extends "TacEntity" to also provide a finite state machine, where "CharaActions" are states, but doesn't really do much on its own.
You are meant to extend TacCharacter, or add it to a character scene, to define how it relates with maps, what actions can do and add behaviors (AI).
The only default CharaActions are «idle.gd» and «walk.gd». You may create new scripts with the same names to override the behavior of these. Any other action needs to be define externally.
The base "TacEntity" can be extended to an simpler kind of object, like a prop the player may click on, or static characters that don't need actions.
Do not add TacEntity derived classes directly to a map. Use the spawners in the plugin panel for that.

You should extend the "TacEntitySpawner" class, to define how different characters are added to maps. Then tell the directory to your spawner classes in «settings.ini».
By default there are no spawner definitions, only the base class as template. To spawn player characters, you might want to set a value to «TacEntitySpawner.unique_to_tacnav», ensuring that adding such spawner to the map relocates an existing one instead.
