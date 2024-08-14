extends Node

@export var priorScene: String = ""

var selectedUnit: Object

var inActiveCombat: bool

func passUnitInfo(item):
	selectedUnit = item
