extends Node

enum GameState { MENU, CUSTOMIZE, PLAYING, DEAD, TOWN_MENU, SETTINGS, FULL_MAP, UPGRADE_MENU, SHIPWRIGHT_MENU }
enum QuestType { MERCHANT, MILITARY, DIPLOMATIC, FISHING }
enum FishingState { INACTIVE, WAITING_FOR_BITE, QTE, RESULT }

var state: GameState = GameState.MENU
var master_volume: float = 1.0
var sound_enabled: bool = true

var parked_island: Node = null

func _ready():
    pass
