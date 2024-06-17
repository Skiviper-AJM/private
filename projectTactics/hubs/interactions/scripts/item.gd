@tool
extends Node

var interactionType : String = "item"
@export_category("Item Data")
@export_enum("Part", "Misc") var itemType : int = 0 :
	set(value):
		itemType = value
		notify_property_list_changed()
		refreshItem()
@export var part : Part : 
	set(value):
		part = value
		part.partUpdated.connect(refreshItem)
		refreshItem()
@export var misc : int

@export var refresh : bool = false :
	set = refreshItem

var meshes:Array[MeshInstance3D] = []

func _validate_property(property: Dictionary):
	if property.name == "part" and itemType != 0:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "misc" and itemType != 1:
		property.usage = PROPERTY_USAGE_NO_EDITOR

func refreshItem(_refreshValue = false):
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	for child in self.get_children(): child.queue_free();
	meshes.clear()
	if itemType == 0:
		if part != null:
			if part.model != null:
				var newModel = part.model.instantiate()
				self.add_child(newModel)
				if newModel.get_node_or_null("inverted") != null:
					if newModel.invertedVariant: newModel.get_child(0).free();
					else: newModel.get_child(1).free();
				newModel.position = Vector3()
				for mesh in getAllChildren(newModel):
					if mesh is MeshInstance3D and mesh.mesh != null:
						var newMeshCollision:CollisionShape3D = CollisionShape3D.new()
						self.add_child(newMeshCollision)
						newMeshCollision.set_owner(self)
						newMeshCollision.shape = mesh.mesh.create_trimesh_shape()
						newMeshCollision.global_transform = mesh.global_transform
						meshes.append(mesh)
				self.name = part.name

func getAllChildren(node):
	var nodes : Array = []

	for N in node.get_children():
		if N.get_child_count() > 0:
			nodes.append(N)
			nodes.append_array(getAllChildren(N))
		else:
			nodes.append(N)
	return nodes

func setOverlay(overlay:Material):
	for child in self.get_children(true):
		if child is MeshInstance3D:
			child.material_overlay = overlay

func getAABB():
	if len(meshes) == 0: return AABB();
	
	var posA:Vector3 = meshes[0].get_aabb().position + localPosition(meshes[0])
	var posB:Vector3 = posA + meshes[0].get_aabb().size
	
	for mesh in meshes:
		var meshPosA:Vector3 = mesh.get_aabb().position + localPosition(mesh)
		posA.x = min(posA.x, meshPosA.x)
		posA.y = min(posA.y, meshPosA.y)
		posA.z = min(posA.z, meshPosA.z)
	
	return AABB(posA, posB - posA)

func localPosition(node):
	return (node.global_position - self.global_position) / self.scale
