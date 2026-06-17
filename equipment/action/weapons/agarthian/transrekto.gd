extends "res://equipment/action/weapons/long_rifle.gd"

func _init() -> void:
	icon = icon.duplicate()
	icon.region.position = Vector2(0, 448)
	title = "transrekto"
	description = "A directed energy weapon way ahead of its time. It is hatched from an egg and fed with canisters of singlet oxygen that produce a laser beam. A swivelling mirror allows it to automatically compensate atmospheric effects and target motion. Used by Agarthians to for hit jobs without leaving residues or fragments in the body. Wait... Was this that killed JFK?!"
	slot = SLOT.SECO
