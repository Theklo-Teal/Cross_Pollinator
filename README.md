# Cross Pollinator

For Paracortical Initiative, 2025, Diogo "Saliko" Duarte

Other projects:
- [Bluesky for news on any progress I've done](https://bsky.app/profile/diogo-duarte.bsky.social)
- [Itchi.io for my most stable playable projects](https://diogo-duarte.itch.io/)
- [The Github for source codes and portfolio](https://github.com/Theklo-Teal)
- [Ko-fi is where I'll accept donations](https://ko-fi.com/paracortical)

Read "CREDITS.txt" for information on third-party assets, in folders containing them.

![Logo](XPoll_logo.png)
![Video of a character navigating and interacting](media/Character_Walking.webm)



## Description
A Tactical Turn-Based game made in the [Godot Engine](https://github.com/godotengine/godot) with some dungeon crawling RPG elements. Think like [XCOM](https://en.wikipedia.org/wiki/XCOM), [Phoenix Point](https://phoenixpoint.info/) or [Phantom Doctrine](https://store.steampowered.com/app/559100/Phantom_Doctrine/).

The story is about a secret government organization investigating an occult sect in extensive underground facilities.

As part of an independent expedition to verify rumours of an extensive secret tunnel network, the player will find all kinds of strange machinery, wild science labs, derelict industry and even ancient ruins as they reveal the source all paranormal activity.

Some basic concepts of the story take inspiration from the secret experiments in the [STALKER series](https://www.stalker-game.com/en), but also there are references to things in other fiction set in the underground, like [Metro 2033](https://en.wikipedia.org/wiki/Metro_2033) and [Half-Life](https://en.wikipedia.org/wiki/Half-Life_(video_game)).

## The story
The government is generically referred as The Warehouse, collecting highly advanced mysterious artifacts who they found to have been made by a secret society of Agartha, but can't find them, nor are their motivations clear. This takes the concept of the [SCP Foundation](https://scp-wiki.wikidot.com/) or in stories like [Control](https://www.remedygames.com/games/control).

Much like TV shows like [Fringe](https://www.imdb.com/title/tt1119644), the paranormal can all be sourced to the same entity, the activity of Agarthians, which they try erase from history, much of it is even manufactured to distort the narrative. Extraterrestrial encounters, ghost manifestations, numbers stations, teleportation, Ley Lines, antigravity, telepathy, which ones of these are true stories is something for the player to reveal.

## Current Highlight Features

### Tactical Map Level Editor
Allows to compose walls and floors for grid navigation which automatically generated.

It's possible to have platforms or floors at different heights.

Different maps can be stitched together to compose bigger levels in a modular fashion.

Trigger zones can be set to execute functions like constraining NPC patrol, or triggering traps or other events.

### Character abilities
Characters can have different personalities and different ways to engage with a threat. Their approaches vary based on a Markov Chain coupled to Utility AI. They will traverse different obstacles or do it differently depending on this.

A creative and extensive list of abilities is available, some unique to some characters based on promotion rank, others can be equipped to different characters.

Abilities can be collected and managed in an inventory system.

### Scenario Director
A state machine determinates the actions of the player and NPCs. It can be extended to define different game rules, switching between turn-based combat and exploratory RPG, for example.

### Quest System
Interactive entities, like doors that can be locked or unlocked, machines that can be started or sabotaged, are all controlled by a quest management script.

Extending it allows to register different events according to bitfield flags of defined conditions. Both the Scenario Director and Characters can respond to these events.

Interactions can be chained together, defining quests or tasks and goals.

## Planned features

- Level Editor can automatically pick assets based on auto-tilling.
- Vertical combat between maps at different heights.
- Interrogation sequences.
- Hazards that make different maps require different characters or equipment to traverse.
