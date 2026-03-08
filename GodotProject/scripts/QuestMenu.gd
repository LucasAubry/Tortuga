class_name QuestMenu
extends CanvasLayer

@onready var btn_q1 = $BurntMap/MarginContainer/VBox/QuestsList/Quest1/BtnQ1
@onready var btn_q2 = $BurntMap/MarginContainer/VBox/QuestsList/Quest2/BtnQ2
@onready var btn_q3 = $BurntMap/MarginContainer/VBox/QuestsList/Quest3/BtnQ3
@onready var close_btn = $BurntMap/MarginContainer/VBox/CloseBtn

func _ready():
	visible = false
	btn_q1.pressed.connect(_on_q1_pressed)
	btn_q2.pressed.connect(_on_q2_pressed)
	btn_q3.pressed.connect(_on_q3_pressed)
	close_btn.pressed.connect(hide_menu)

func _process(delta):
	if Input.is_action_just_pressed("act") and not visible:
		# Check if we can open
		if GameManager.parked_island != null:
			var island = GameManager.parked_island
			var type = island.ile_type
			# 0:CITY, 1:MERCHANT, 3:FISHERMAN are handled by QuestMenu
			if type == 0 or type == 1 or type == 3:
				show_menu()
	elif Input.is_action_just_pressed("act") and visible:
		# If user re-presses act, don't immediately toggle if they just clicked something, but okay we can close
		hide_menu()
		
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and visible:
		hide_menu()

func show_menu():
	visible = true
	get_tree().paused = true
	_update_title()

func hide_menu():
	visible = false
	get_tree().paused = false

func _update_title():
	var title_lbl = $BurntMap/MarginContainer/VBox/Title
	if GameManager.parked_island:
		var type = GameManager.parked_island.ile_type
		match type:
			0: title_lbl.text = "VILLE DE TORTUGA"
			1: title_lbl.text = "COMPTOIR MARCHAND"
			2: title_lbl.text = "CHANTIER NAVAL"
			3: title_lbl.text = "CABANE DU PÊCHEUR"

func _get_player() -> Ship:
	return _find_player_recursive(get_tree().get_root())

func _find_player_recursive(node: Node) -> Ship:
	if node is Ship and node.is_player: return node
	for child in node.get_children():
		var res = _find_player_recursive(child)
		if res: return res
	return null

func _on_q1_pressed():
	# Deliver 10 Wood -> 50 Gold
	var p = _get_player()
	if p and p.wood >= 10:
		p.wood -= 10
		p.gold += 50
		print("Quest 1 Complete!")

func _on_q2_pressed():
	# Buy 20 Ammo -> 200 Gold
	var p = _get_player()
	if p and p.gold >= 200:
		p.gold -= 200
		p.ammo += 20
		if p.ammo > p.max_ammo: p.ammo = p.max_ammo
		print("Bought Ammo!")

func _on_q3_pressed():
	# Repair Ship -> 50 Wood
	var p = _get_player()
	if p and p.wood >= 50 and p.hp < p.max_hp:
		p.wood -= 50
		p.hp = p.max_hp
		print("Ship Repaired!")
