# Guide : Comment exporter depuis Blender pour Tortuga C++

Voici exactement ce que vous devrez faire une fois que vous aurez commencé à faire votre carte sur Blender.

## 1. La Règle d'Or dans Blender
**Ne fusionnez JAMAIS vos objets ./assets_explanation.txt* 
Si vous placez 50 palmiers, vos 50 palmiers doivent rester dans la liste des objets à droite (l'Outliner) comme `Palmier.001`, `Palmier.002`, etc. 
Ne sélectionnez pas tout pour faire `Ctrl+J` (Joindre), sinon vous perdez l'avantage de l'instanciation.
L'île de base (le gros bloc de sable/terre) sera elle, logiquement, un seul gros objet.

## 2. Le Script d'Exportation Blender (Python)
Blender fonctionne avec Python. Pour récupérer les coordonnées de tous vos objets d'un coup, on va utiliser un tout petit script dans Blender. 
Quand vous serez prêt, copiez-collez ça dans l'onglet **"Scripting"** en haut de Blender, et cliquez sur "Run" (Lecture) :

```python
import bpy
import json
import math

# Le dictionnaire qui va contenir tout notre niveau
level_data = {
    "world_terrain": "", # Le nom du mesh de l'ile globale 
    "objects": []
}

# On parcourt tous les objets de la scène
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        if "Terrain" in obj.name:
            level_data["world_terrain"] = obj.name + ".obj"
        else:
            # On récupère le nom de base sans les .001, .002
            base_name = obj.name.split('.')[0] + ".obj" 
            
            # Position
            x, y, z = obj.location
            # Rotation (convertie en degrés pour Raylib)
            rx, ry, rz = obj.rotation_euler
            
            level_data["objects"].append({
                "model": base_name,
                "pos": {"x": x, "y": z, "z": -y}, # On adapte les axes Z/Y de Blender vers Raylib
                "rot": {"x": math.degrees(rx), "y": math.degrees(rz), "z": math.degrees(-ry)},
                "scale": obj.scale[0] # On suppose que l'échelle est uniforme
            })

# Sauvegarde dans un fichier JSON
with open('/Chemin/Vers/Tortuga/assets/mon_niveau.json', 'w') as f:
    json.dump(level_data, f, indent=4)
    
print("Export réussi !")
```

## 3. Ce que vous devrez Exporter (.OBJ)
1. Sélectionnez **seulement** votre énorme terrain de base, et faites : `File -> Export -> Wavefront (.obj)`. Cochez bien "Selection Only". Nommez-le `Terrain.obj`.
2. Sélectionnez **une seule fois** la maison du marchand (le modèle original), et exportez-le en `MaisonMarchand.obj`.
3. Faites pareil pour chaque type d'objet (1 seul palmier, 1 seule maison, 1 seul port).
4. Mettez tout ça dans le dossier `assets/` du jeu.

## 4. Ce qu'on fera ensemble en C++ (La prochaine étape)
Quand vous aurez vos `.obj` et votre fichier texte `.json` contenant les 500 positions :
- Dites-le moi !
- J'écrirai avec vous en C++ la fonction `LoadLevel("assets/mon_niveau.json")` qui va lire votre fichier, charger les modèles en RAM intelligemment, et les afficher là où vous les avez placés dans Blender !
