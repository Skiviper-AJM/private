extends Resource
class_name Fish

# Enumerators
enum SizeCategories {
	SMALL,
	MEDIUM,
	LARGE,
	MASSIVE
}

enum ItemTypes {
	ALL,
	PART,
	UNIT,
	FISH
}

enum Rarities {
	COMMON,
	UNCOMMON,
	RARE,
	EXOTIC,
	LEGENDARY,
	MYTHIC
}

var itemType : ItemTypes = ItemTypes.FISH

# Fish trait variables
@export_category("General")
@export var name:String = ""
@export var cost:int = 0
@export var model : Mesh
@export var rarity:Rarities = Rarities.COMMON

@export_subgroup("Flavour Text")
@export_multiline var description : String = " "

@export_category("Behaviour")
@export var chance:float = 1.0
@export var captureTime:float = 1

@export_subgroup("Weight")
@export var minWeight:float = 0.0 :
	get: return minWeight;
	set(newWeight):
		minWeight = newWeight
		if minWeight > maxWeight: maxWeight = minWeight;
@export var maxWeight:float = 0.0

@export_subgroup("Movement")
@export var size:int = 1
@export var speed:float = 1.0
@export var predictability:float = 1.0

var weight:float
var sizeCategory:SizeCategories
var descriptiveName:String

# Adjust fish traits to create size variations
func spawn():
	# Update weight
	weight = randf_range(minWeight, maxWeight)
	var weightVariation:float = maxWeight - minWeight
	# Update name to include weight category prefix
	descriptiveName = name
	if weight < minWeight + weightVariation * 0.25:
		sizeCategory = SizeCategories.SMALL
		descriptiveName = "Small " + name
	elif weight < minWeight + weightVariation * 0.6:
		sizeCategory = SizeCategories.MEDIUM
	elif weight < minWeight + weightVariation * 0.9:
		sizeCategory = SizeCategories.LARGE
		descriptiveName = "Large " + name
	elif weight < minWeight + weightVariation * 0.91:
		sizeCategory = SizeCategories.MASSIVE
		descriptiveName = "Massive " + name
	descriptiveName += " (" + str(round(weight * 10.0) /10.0) + "kg)"
