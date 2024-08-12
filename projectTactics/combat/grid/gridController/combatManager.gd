extends Node

# A flag to determine whether the player is in combat mode
var in_combat = false

@onready var player_combat_controller = $"../HexGrid"

func combatInitiate():
	in_combat = true
	player_combat_controller.block_placement = true  # Disable unit placement from inventory
	print("Combat initiated. Unit selection from inventory disabled.")

func _handle_unit_click(selected_unit):
	if in_combat:
		# Handle unit selection logic when in combat
		if DataPasser.selectedUnit == selected_unit:
			print("Unit already selected.")
			return
		else:
			print("Switching to selected unit:", selected_unit.name)
			DataPasser.passUnitInfo(selected_unit)
			player_combat_controller.unit_to_place = selected_unit
			player_combat_controller.placing_unit = false
			player_combat_controller.unit_name_label.text = "Unit: " + selected_unit.name
	else:
		# If not in combat, allow the usual unit selection/placement
		player_combat_controller.unitPlacer()
