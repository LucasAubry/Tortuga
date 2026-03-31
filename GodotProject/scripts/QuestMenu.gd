class_name QuestMenu
extends CanvasLayer

@onready var btn_q1 = $BurntMap/MarginContainer/VBox/QuestsList/Quest1/BtnQ1
@onready var btn_q2 = $BurntMap/MarginContainer/VBox/QuestsList/Quest2/BtnQ2
@onready var btn_q3 = $BurntMap/MarginContainer/VBox/QuestsList/Quest3/BtnQ3
@onready var close_btn = $BurntMap/CloseBtn

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_q1.pressed.connect(_on_q1_pressed)
	btn_q2.pressed.connect(_on_q2_pressed)
	btn_q3.pressed.connect(_on_q3_pressed)
	close_btn.pressed.connect(hide_menu)

func _process(delta):
	if not visible and GameManager.state == GameManager.GameState.TOWN_MENU:
		show_menu()
	
	# Closing handled by buttons or Esc
		
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and visible:
		hide_menu()

func show_menu():
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_title()

func hide_menu():
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Should we set it to CAPTURED if playing?
	if GameManager.state == GameManager.GameState.TOWN_MENU:
		GameManager.state = GameManager.GameState.PLAYING

func _update_title():
	var title_lbl = $BurntMap/MarginContainer/VBox/Title
	
	# Default Texts
	btn_q1.text = "Livrer 10 Bois -> 50 Or"
	btn_q2.text = "Acheter 20 Boulets -> 200 Or"
	btn_q3.text = "Réparer Navire -> 50 Bois"

	if GameManager.parked_island:
		var type = GameManager.parked_island.ile_type
		match type:
			0: title_lbl.text = "VILLE DE TORTUGA"
			1: title_lbl.text = "COMPTOIR MARCHAND"
			2: title_lbl.text = "CHANTIER NAVAL"
			3: 
				title_lbl.text = "CABANE DU PÊCHEUR"
				btn_q1.text = "Vendre 1 Poisson -> 20 Or"
				btn_q2.text = "Acheter 20 Boulets -> 150 Or" 
				btn_q3.text = "Réparer Navire -> 50 Or"

func _get_player() -> Ship:
	return _find_player_recursive(get_tree().get_root())

func _find_player_recursive(node: Node) -> Ship:
	if node is Ship and node.is_player: return node
	for child in node.get_children():
		var res = _find_player_recursive(child)
		if res: return res
	return null

func _on_q1_pressed():
	var p = _get_player()
	if not p: return

	# Spécificité Pêcheur
	if GameManager.parked_island and GameManager.parked_island.ile_type == 3:
		if p.remove_from_inventory("Poisson"):
			p.gold += 20
			print("Poisson vendu !")
			return

	# Deliver 10 Wood -> 50 Gold (Generic)
	if p.wood >= 10:
		p.wood -= 10
		p.gold += 50
		print("Quest 1 Complete!")

func _on_q2_pressed():
	var p = _get_player()
	if not p: return

	# Spécificité Pêcheur : Acheter boulets
	if GameManager.parked_island and GameManager.parked_island.ile_type == 3:
		if p.gold >= 150:
			p.gold -= 150
			p.ammo += 20
			if p.ammo > p.max_ammo: p.ammo = p.max_ammo
			print("Bought Ammo from Fisherman!")
			return

	# Buy 20 Ammo -> 200 Gold (Generic)
	if p.gold >= 200:
		p.gold -= 200
		p.ammo += 20
		if p.ammo > p.max_ammo: p.ammo = p.max_ammo
		print("Bought Ammo!")

func _on_q3_pressed():
	var p = _get_player()
	if not p: return

	# Spécificité Pêcheur : Réparation contre Or
	if GameManager.parked_island and GameManager.parked_island.ile_type == 3:
		if p.gold >= 50 and p.hp < p.max_hp:
			p.gold -= 50
			p.hp = p.max_hp
			print("Ship Repaired by Fisherman!")
			return

	# Repair Ship -> 50 Wood (Generic)
	if p.wood >= 50 and p.hp < p.max_hp:
		p.wood -= 50
		p.hp = p.max_hp
		print("Ship Repaired!")
