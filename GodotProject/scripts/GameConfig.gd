extends Node

# Global wind state (Default, used if get_wind_at not called)
var wind_direction: Vector2 = Vector2(1, 0).normalized() 
var wind_speed: float = 1.0

# Noise for global wind zones
var wind_angle_noise = FastNoiseLite.new()
var wind_speed_noise = FastNoiseLite.new()

func _ready():
	wind_angle_noise.seed = 1234
	wind_angle_noise.frequency = 0.00005 # Extremely massive zones (changes very slowly)
	wind_speed_noise.seed = 5678
	wind_speed_noise.frequency = 0.0001

func get_wind_at(pos: Vector3) -> Dictionary:
	# Add completely dynamic variation based on running time
	var time_offset_angle = Time.get_ticks_msec() * 0.0001
	var time_offset_speed = Time.get_ticks_msec() * 0.0002
	
	# Use polar 3D noise mapping for smooth transitions spanning time and space
	var angle_val = wind_angle_noise.get_noise_3d(pos.x, pos.z, time_offset_angle)
	var angle = angle_val * PI * 2.0 # -PI to PI
	
	var dir = Vector2(cos(angle), sin(angle)).normalized()
	
	# Speed ranges from 0.4 to 2.0 based on noise 
	var raw_speed = (wind_speed_noise.get_noise_3d(pos.x, pos.z, time_offset_speed) + 1.0) * 0.5 * 2.0
	var speed = clamp(raw_speed, 0.4, 2.0)
	
	return {"direction": dir, "speed": speed}

# Initial ship stats from C++ (Base values)
# Economy
const StartingGold = 10000000

# Repair and upgrades
const RepairCost = 100
const UpgradeSpeedGold = 100
const UpgradeSpeedWood = 50
const UpgradeFireRateGold = 150
const UpgradeFireRateWood = 30

# Quests
const QuestMerchantCost = 30
const QuestMerchantReward = 150
const QuestMilitaryCost = 150
const QuestMilitaryReward = 250
const QuestDiplomaticCost = 20
const QuestDiplomaticReward = 100

# Resources (Batch of 50)
const SellBatchWoodGold = 20
const SellBatchWaterGold = 20
const SellBatchFoodGold = 20

# Resources (Single scale)
const SellSingleFoodGold = 10
const SellSingleWoodGold = 15

# Wind Dynamics
const BaseWindStrengthMultiplier = 0.2
const MaxWindStrengthMultiplier = 1.0

# Ship Base Speeds (Max Speed)
const SloopSpeed = 35.0
const BrigantineSpeed = 45.0
const GalleonSpeed = 55.0

# Ship Base Health (Max HP)
const SloopHP = 150.0
const BrigantineHP = 200.0
const GalleonHP = 300.0

# Ship Base Cooldowns
const SloopCooldown = 1.0
const BrigantineCooldown = 1.5
const GalleonCooldown = 2.0
# ─────────────────────────────────────────────
# KRAKEN — CONFIGURATION FACILE À MODIFIER
# ─────────────────────────────────────────────

# Progression
var kraken_xp: float = 0.0
var kraken_level: int = 1
var kraken_skill_points: int = 50

# ── BONUS ARMURES (VIE en plus par tentacule) ──
const ARMOR_V1_HP_BONUS = 2       # Mesh: "écailles dorsale"
const ARMOR_V2_HP_BONUS = 3       # Mesh: "armure dorsale"
const ARMOR_V3_HP_BONUS = 5       # Mesh: "armure longue dorsale"

# ── BONUS PIQUES (DÉGÂTS en plus par attaque) ──
const SPIKE_TipSpike_DMG = 10.0       # Mesh: "dart"
const SPIKE_SpikesBack1_DMG = 10.0    # Mesh: "pique dorsale"
const SPIKE_SpikesBack2_DMG = 10.0    # Mesh: "double pique dorsale"
const SPIKE_SpikesSides_DMG = 15.0    # Mesh: "pique latérale"
const SPIKE_SpikesFront1_DMG = 15.0   # Mesh: "pique intérieur"
const SPIKE_SpikesFront2_DMG = 20.0   # Mesh: "double pique intérieur"
const SPIKE_Thorns_DMG = 25.0         # Mesh: "pique profond"

# ── XP par niveau (formule) ──
const KRAKEN_XP_BASE = 100.0
const KRAKEN_XP_MULTIPLIER = 1.5

# Kraken Tentacle Customization (Current Visibility/Selection)
var kraken_tentacle_parts = {
	"TentacleV1": true,
	"TentacleV2": false,
	"TentacleV3": false,
	"TentacleV4": false,
	"TentacleV5": false,
	"Spine": false,
	"ArmorV1": false,
	"ArmorV2": false,
	"ArmorV3": false,
	"TipSpike": false,
	"SpikesBack1": false,
	"SpikesBack2": false,
	"SpikesSides": false,
	"SpikesFront1": false,
	"SpikesFront2": false,
	"Thorns": false
}

# Kraken Skill Tree (Unlocked Status)
var kraken_unlocked_skills = {
	"TentacleV1": true,
	"TentacleV2": false,
	"TentacleV3": false,
	"TentacleV4": false,
	"TentacleV5": false,
	"ArmorV1": false,
	"ArmorV2": false,
	"ArmorV3": false,
	"TipSpike": false,
	"SpikesBack1": false,
	"SpikesBack2": false,
	"SpikesSides": false,
	"SpikesFront1": false,
	"SpikesFront2": false,
	"Thorns": false
}

func get_kraken_xp_for_level(lvl: int) -> float:
	return lvl * KRAKEN_XP_BASE * KRAKEN_XP_MULTIPLIER

func add_kraken_xp(amount: float):
	kraken_xp += amount
	while kraken_xp >= get_kraken_xp_for_level(kraken_level):
		kraken_xp -= get_kraken_xp_for_level(kraken_level)
		kraken_level += 1
		kraken_skill_points += 1
		print("Kraken Leveled Up! Level: ", kraken_level)

# Retourne le bonus total de dégâts des piques actives
func get_kraken_spike_damage_bonus() -> float:
	var total = 0.0
	var config = kraken_tentacle_parts
	if config.get("TipSpike", false): total += SPIKE_TipSpike_DMG
	if config.get("SpikesBack1", false): total += SPIKE_SpikesBack1_DMG
	if config.get("SpikesBack2", false): total += SPIKE_SpikesBack2_DMG
	if config.get("SpikesSides", false): total += SPIKE_SpikesSides_DMG
	if config.get("SpikesFront1", false): total += SPIKE_SpikesFront1_DMG
	if config.get("SpikesFront2", false): total += SPIKE_SpikesFront2_DMG
	if config.get("Thorns", false): total += SPIKE_Thorns_DMG
	return total

# Retourne le bonus total de PV des armures actives
func get_kraken_armor_hp_bonus() -> int:
	var total = 0
	if kraken_tentacle_parts.get("ArmorV1", false): total += ARMOR_V1_HP_BONUS
	if kraken_tentacle_parts.get("ArmorV2", false): total += ARMOR_V2_HP_BONUS
	if kraken_tentacle_parts.get("ArmorV3", false): total += ARMOR_V3_HP_BONUS
	return total
