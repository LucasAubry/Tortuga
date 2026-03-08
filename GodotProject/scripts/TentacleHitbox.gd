## Script attaché au PhysicalHitbox (StaticBody3D) de la tentacule.
## Il délègue les dégâts au nœud racine KrakenTentacle.gd
extends StaticBody3D

func take_damage(amount: float, attacker = null):
	var parent = get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(amount, attacker)
