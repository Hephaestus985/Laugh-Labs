extends RefCounted
## [Lab Arcade] OpenRPG's always-loaded helpers (autoloads) sleep while other games
## and the launcher run, and wake up when OpenRPG starts. The launcher calls park().

const AUTOLOADS := ["Camera", "CombatEvents", "FieldEvents", "Gameboard", "GamepieceRegistry",
	"Music", "Player", "Transition", "Dialogic"]


static func park(tree: SceneTree) -> void:
	set_awake(tree, false)


static func set_awake(tree: SceneTree, awake: bool) -> void:
	for n in AUTOLOADS:
		var node := tree.root.get_node_or_null(n)
		if node:
			node.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	var cam := tree.root.get_node_or_null("Camera") as Camera2D
	if cam:
		cam.enabled = awake
	var cover := tree.root.get_node_or_null("Transition") as CanvasLayer
	if cover:
		cover.visible = awake
