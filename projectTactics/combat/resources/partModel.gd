@tool
extends Node3D

enum PartTypes {
	ARM,
	LEG,
	CHEST,
	CORE,
	HEAD
}

@export var type:PartTypes = PartTypes.ARM :
	get: return type;
	set(value):
		invertedVariant = false
		type = value

@export var sharedMaterial:Material : set = applyMaterial;

@export var updateChildren:bool = false : set = regenerateChildren;

@export var invertedVariant:bool = false :
	set(isInverting):
		if isInverting:
			if type in [PartTypes.ARM, PartTypes.LEG]:
				generateInverted()
				invertedVariant = true
		elif type in [PartTypes.ARM, PartTypes.LEG] and get_node_or_null("inverted") != null:
			get_node("inverted").queue_free()
		invertedVariant = false

@export var scaleModifier:float = 1.0

func regenerateChildren(_update):
	for child in self.get_children(): child.free();
	match type:
		PartTypes.ARM:
			self.name = "upperArmPivot"
			createChild(MeshInstance3D, "lowerArm",
				createChild(Node3D, "lowerArmPivot",
				createChild(MeshInstance3D, "upperArm"
			)))
			createChild(Node3D, "pivotCenter")
		PartTypes.LEG:
			self.name = "upperLegPivot"
			createChild(MeshInstance3D, "foot",
				createChild(Node3D, "footPivot",
				createChild(MeshInstance3D, "lowerLeg",
				createChild(Node3D, "lowerLegPivot",
				createChild(MeshInstance3D, "upperLeg"
			)))))
		PartTypes.CHEST:
			self.name = "chestPivot"
			createChild(MeshInstance3D, "chest")
			createChild(Node3D, "corePos")
			createChild(Node3D, "headPos")
			createChild(Node3D, "lArmPos")
			createChild(Node3D, "rArmPos")
			createChild(Node3D, "lLegPos")
			createChild(Node3D, "rLegPos")
		PartTypes.CORE:
			self.name = "corePivot"
			createChild(MeshInstance3D, "core")
		PartTypes.HEAD:
			self.name = "headPivot"
			createChild(MeshInstance3D, "head")

func generateInverted():
	if get_node_or_null("inverted") != null: get_node("inverted").free();
	var invertedVariant:MeshInstance3D = get_child(0).duplicate()
	self.add_child(invertedVariant)
	invertedVariant.set_owner(self)
	invertedVariant.name = "inverted"
	for child in getAllChildren(invertedVariant):
		child.set_owner(self)

func applyMaterial(newMat:Material):
	for child in getAllChildren(self):
		if child is MeshInstance3D:
			child.material_override = newMat

func getAABB():
	var meshes:Array[MeshInstance3D] = []
	for mesh in getAllChildren(self):
		if mesh is MeshInstance3D:
			meshes.append(mesh)
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
	return node.global_position - self.global_position

func getAllChildren(node=self):
	var nodes : Array = []

	for N in node.get_children():
		if N.get_child_count() > 0:
			nodes.append(N)
			nodes.append_array(getAllChildren(N))
		else:
			nodes.append(N)
	return nodes

func createChild(childType, childName, parent=self):
	var newChild = childType.new()
	parent.add_child(newChild)
	newChild.set_owner(self)
	newChild.position = Vector3()
	newChild.name = childName
	return newChild
