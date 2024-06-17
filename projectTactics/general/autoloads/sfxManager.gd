extends Node

const MIN_VOLUME:float = -20.0

func connectAllButtons():
	var allNodes:Array = getAllChildren(get_tree().root)
	for curNode in allNodes:
		if curNode is Button:
			if !curNode.is_connected("button_up", playClick):
				curNode.button_up.connect(playClick)

func playClick():
	$click.play()

func playCloseMenu():
	$closeMenu.play(0.2)

func getAllChildren(node):
	var nodes:Array = []

	for N in node.get_children():
		if N.get_child_count() > 0:
			nodes.append(N)
			nodes.append_array(getAllChildren(N))
		else:
			nodes.append(N)
	return nodes

func changeVolume(newVolume:float):
	if newVolume <= MIN_VOLUME: newVolume = -80;
	$click.volume_db = newVolume
	$closeMenu.volume_db = newVolume
