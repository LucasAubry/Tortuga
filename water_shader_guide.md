# Guide : Créer un Océan Réaliste et Animé dans Raylib (Shader)

Pour avoir une eau magnifique (qui ondule, avec des reflets et de la transparence) sans tuer les performances de votre ordinateur, vous ne pouvez pas utiliser des millions de petits cubes ou de modèles 3D qui bougent. 

Le secret des jeux vidéos modernes pour l'eau s'appelle un **Shader**.

## Qu'est-ce qu'un Shader ?
C'est un minuscule programme qui ne tourne pas sur le processeur (CPU) de votre ordinateur, mais directement sur la **Carte Graphique (GPU)**. La carte graphique est capable de dessiner des vagues et des reflets sur des millions de pixels simultanément et instantanément.

## Comment l'intégrer dans Tortuga (Raylib) ?

### Étape 1 : Créer le fichier Shader (.fs)
Il faut créer un nouveau fichier texte dans votre dossier `assets/` appelé `water.fs` (fs = fragment shader). Il contient un code mathématique écrit en langage GLSL (OpenGL Shading Language) qui calcule les ondulations. 
Voici un exemple classique pour faire bouger des vagues :

```glsl
#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
out vec4 finalColor;

uniform float uTime; // Le temps qui passe, envoyé par le C++

void main()
{
    // Calcul de l'ondulation basée sur le sinus et le temps
    vec2 uv = fragTexCoord;
    uv.x += sin(uv.y * 10.0 + uTime) * 0.05;
    uv.y += cos(uv.x * 10.0 + uTime) * 0.05;
    
    // Couleur de base de l'océan
    vec4 baseColor = vec4(0.0, 0.4, 0.8, 0.8); // Bleu avec un peu de transparence
    
    // On ajoute un effet d'écume blanche sur le sommet des vagues
    float foam = (sin(uv.x * 20.0) * cos(uv.y * 20.0)) * 0.1;
    baseColor.xyz += foam;

    finalColor = baseColor;
}
```

### Étape 2 : L'appeler dans votre code C++ (Game.cpp)
Raylib a des fonctions toutes prêtes pour ça !
Dans `Game.hpp` vous déclarez un shader :
```cpp
Shader waterShader;
int timeLoc; // Pour envoyer le temps au shader
```

Dans `Game::Init()` vous le chargez :
```cpp
// On charge le fichier qu'on vient de créer
waterShader = LoadShader(0, "assets/water.fs"); 
// On dit à Raylib où la variable "uTime" se trouve dans le petit programme
timeLoc = GetShaderLocation(waterShader, "uTime");
```

Dans `Game::Draw()`, vous l'appliquez au moment de dessiner la mer :
```cpp
// 1. On calcule le temps passé depuis le début du jeu
float time = GetTime();

// 2. On envoie ce temps à la carte graphique
SetShaderValue(waterShader, timeLoc, &time, SHADER_UNIFORM_FLOAT);

// 3. On "allume" le shader
BeginShaderMode(waterShader);

// 4. On dessine un énorme plan Plat
// La carte graphique va automatiquement tordre l'image pour lui donner un effet de vague !
DrawPlane({0, 0, 0}, {80000, 80000}, WHITE);

// 5. On "éteint" le shader pour que le reste du jeu (les bateaux) ne soit pas tordu
EndShaderMode();
```

## L'avantage ultime ⚡
- **Zéro baisse de FPS** : L'algorithme (`sin` et `cos`) fonctionne au niveau du pixel sur le GPU. 
- **Magie Visuelle** : Vous pouvez modifier le fichier `water.fs` pendant que le jeu tourne pour changer la couleur ou la force des vagues, la mer s'adaptera instantanément avec une eau qui bouge incroyablement bien !

Dites-le moi quand vous serez prêt(e) à attaquer la beauté de l'océan, et nous écrirons un shader d'eau époustouflant avec des calques de brillance et des textures animées !
