extends Node

@export var priorScene: String = ""

var selectedUnit: Object

func passUnitInfo(item):
	print(type_string(typeof(item)))
	selectedUnit = item
