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
# Kraken Tentacle Customization
var kraken_tentacle_parts = {
	"TentacleV1": true,
	"TentacleV2": false,
	"TentacleV3": false,
	"TentacleV4": false,
	"TentacleV5": false,
	"Spine": false,
	"ArmorV1": false,
	"ArmorV2": false,
	"TipSpike": false,
	"SpikesBack1": false,
	"SpikesBack2": false,
	"SpikesSides": false,
	"SpikesFront1": false,
	"SpikesFront2": false,
	"Thorns": false
}
