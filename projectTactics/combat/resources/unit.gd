extends Resource
class_name Unit

enum ItemTypes {
	ALL,
	PART,
	UNIT,
	FISH
}

var itemType : ItemTypes = ItemTypes.UNIT

@export_category("General")
@export var name:String = ""
@export var cost:int = 0

@export_subgroup("Flavour Text")
@export_multiline var description : String = " "

@export_category("Parts")
@export var head:Part
@export var chest:Part
@export var arm:Part
@export var core:Part
@export var leg:Part

var damage : int = 0
var armorRating : int = 0
var speedRating : int = 0
var range : int = 0
var splash : int = 0
