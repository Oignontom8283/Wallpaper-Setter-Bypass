# Wallpaper Setter Bypass (WSB)

<img src="https://img.shields.io/badge/Target-Windows-green?style=flat" alt="Target Hardware"/> &nbsp; <img src="https://img.shields.io/github/v/release/Oignontom8283/eadkp?include_prereleases&style=flat&logo=github" alt="Version"/>


**Français** | [English](README.md)

Application PowerShell qui contourne l'interface native de Windows pour définir les fonds d'écran directement avec options avancées de mise à l'échelle et de style. Fonctionne sans privilèges administrateur.

![Illustration of WSB GUI](./assets/gui.png)

![Demo GIF Animation](./assets/demo.gif)


## Fonctionnalités

- [x] **Support Dual Méthode** : Choisir entre la Windows API native ou la manipulation du registre
- [x] **Mode GUI** : Interface graphique interactive pour une sélection facile du fond d'écran
- [x] **Mode CLI** : Interface en ligne de commande pour l'automatisation et les scripts
- [x] **Validation d'image** : Validation automatique pour détecter les fichiers image corrompus ou invalides
- [x] **Modes d'affichage** : Choisir entre Tiler (répétition) ou Plein écran
- [x] **Options d'étirement** : En mode plein écran, choisir entre centré ou étiré
- [x] **Support Multi-Moniteur** : Appliquer les fonds d'écran sur des/un moniteur(s) spécifique(s) ou étendre une seule image sur tous les écrans
- [x] **Aperçu d'image** : Aperçu en direct de l'image sélectionnée avant application
- [x] **Pas de Droits Admin** : Fonctionne sans privilèges administrateur en utilisant les méthodes basées sur le registre

## Formats d'image supportés

- JPG / JPEG
- PNG
- BMP
- GIF
- TIFF / TIF

## Configuration requise

- Windows 7 ou version ultérieure
- PowerShell 3.0 ou version ultérieure
- Aucun droit spécial requis

## Utilisation

### Mode GUI (Interactif)

Exécutez simplement le fichier launcher batch :

```cmd
launcher.bat
```

Ou exécutez directement le script PowerShell :

```powershell
.\wallpaper_setter.ps1
```

Cela ouvre une fenêtre où vous pouvez :

1. Cliquer sur **`Browse...`** pour sélectionner un fichier image
2. Voir l'aperçu de l'image sur le côté droit
3. Sélectionner le moniteur cible :
   - **Current (Actuel)** : Le moniteur où se trouve la fenêtre de l'application
   - **Primary (Principal)** : Le moniteur système principal
   - **DISPLAY#** : Moniteur spécifique par son nom matériel
   - **All (Tous)** : Appliquer la même image à tous les moniteurs
   - **Spanned (Étendue)** : Étendre une seule image sur tous les moniteurs connectés
4. Sélectionner le mode d'affichage :
   - **Tile (répéter)** : Répète l'image sur tout l'écran
   - **Full screen** : Affiche l'image en plein écran
5. En mode plein écran, cocher les options souhaitées :
   - **Stretch to fill (Étirer l'image)** : Étire l'image pour remplir tout l'écran (sinon elle sera ajustée en conservant les proportions)
6. Cocher les autres options :
   - **Use Registry method (Manipulation du registre)** : Utiliser la manipulation du registre au lieu de l'API Windows native (essayer ceci si la méthode par défaut échoue)
7. Cliquer sur **`Apply`** pour définir le fond d'écran
8. Cliquer sur **`Exit`** pour fermer sans appliquer les modifications

### Mode CLI (Ligne de commande)

Utilisez la syntaxe suivante pour l'utilisation en ligne de commande :

```powershell
.\wallpaper_setter.ps1 -Path "C:\chemin\vers\image.jpg" [Options]
```

#### Options :
- `-Path <chemin>` (obligatoire) : Chemin complet du fichier image
- `-DisplayMode <mode>` : Mode d'affichage : 'tile' (répétition) ou 'fullscreen' (plein écran, défaut)
- `-Monitor <moniteur>` : Moniteur cible : 'primary', 'all', ou index (ex: '0', '1'). Par défaut 'primary'.
- `-Stretch` : Étirer l'image pour remplir l'écran (mode plein écran uniquement)
- `-Spanned` : Appliquer l'image étendue sur tous les moniteurs
- `-UseRegistryMethod` : Utiliser la méthode de manipulation du registre au lieu de l'API native
- `-Help` : Afficher le message d'aide

<br>
Note : La méthode Registre (qui désactive l'option de sélection du moniteur) applique le fond d'écran globalement sur tous les écrans en utilisant les routines de redimensionnement Windows héritées.
<br>

#### Exemples :

Appliquer sur le moniteur principal :
```powershell
.\wallpaper_setter.ps1 -Path "C:\chemin\vers\image.jpg"
```

Appliquer sur un moniteur spécifique (ex: moniteur 1) :
```powershell
.\wallpaper_setter.ps1 -Path "C:\chemin\vers\image.jpg" -Monitor 1
```

Appliquer une image étendue sur tous les moniteurs :
```powershell
.\wallpaper_setter.ps1 -Path "C:\chemin\vers\image.jpg" -Spanned
```

Appliquer une image en mode plein écran centré :

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MonUtilisateur\Images\image.jpg" -DisplayMode fullscreen
```

Appliquer une image en mode plein écran étiré :

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MonUtilisateur\Images\image.jpg" -DisplayMode fullscreen -Stretch
```

Appliquer une image en mode Tiler (répétition) :

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MonUtilisateur\Images\image.jpg" -DisplayMode tile
```

Appliquer une image en utilisant la méthode Registre :

```powershell
.\wallpaper_setter.ps1 -Path "C:\Users\MonUtilisateur\Images\image.jpg" -UseRegistryMethod
```

Afficher l'aide :

```powershell
.\wallpaper_setter.ps1 -Help
```

## Comment ça fonctionne

WSB contourne l'interface graphique Windows standard en modifiant directement la configuration du fond d'écran :

1. **Mode GUI** : Lance une fenêtre interactive utilisant Windows Forms pour sélectionner et configurer les paramètres du fond d'écran
2. **Modes d'affichage** :
   - **Tiler** : Répète l'image sur tout l'écran (WallpaperStyle=1, TileWallpaper=1)
   - **Plein écran centré** : Affiche l'image ajustée sans répétition (WallpaperStyle=6, TileWallpaper=0)
   - **Plein écran étiré** : Affiche l'image étirée pour remplir l'écran (WallpaperStyle=2, TileWallpaper=0)
3. **Approche Dual Méthode** :
   - **Méthode par défaut** : Utilise l'interface COM `IDesktopWallpaper` pour définir le fond d'écran par moniteur, avec repli sur `SystemParametersInfo` en cas d'échec
   - **Méthode Registre** : Manipule directement les paramètres du registre Windows :
     - `Wallpaper` : Chemin vers l'image de fond d'écran
     - `WallpaperStyle` : 1 pour tiler, 2 pour étirer, 6 pour ajusté
     - `TileWallpaper` : 1 pour tiler, 0 pour non-tiler
4. **Stratégie de Repli** : Si la méthode par défaut échoue en mode GUI, propose automatiquement d'essayer la méthode Registre
5. **Actualisation du Bureau** : Déclenche l'affichage immédiat du fond d'écran sans nécessiter un redémarrage du système

## Dépannage

**Erreur de politique d'exécution PowerShell ?**

Si vous voyez "Le fichier ne peut pas être chargé car l'exécution de scripts est désactivée", utilisez le fichier launcher batch à la place :

```cmd
launcher.bat
```

Cela contourne les restrictions de politique d'exécution. Alternativement, activez l'exécution de scripts :

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

**L'image n'est pas appliquée ?**

- Vérifiez que le chemin du fichier image est correct
- Assurez-vous que le fichier image est dans un format supporté et non corrompu
- Essayez d'utiliser le flag `-UseRegistryMethod` si la méthode par défaut ne fonctionne pas
- Assurez-vous que le Registre Windows est accessible (non restreint par les stratégies de groupe)

**La méthode Registre est lente ou ne fonctionne pas ?**

La méthode registre peut prendre un moment pour actualiser le fond d'écran. Si cela ne s'applique pas immédiatement :

- Attendez quelques secondes et le fond d'écran devrait se mettre à jour
- Essayez d'appliquer à nouveau — parfois la méthode registre nécessite plusieurs tentatives pour prendre effet
- Utilisez le fichier launcher batch si la politique d'exécution empêche le script PowerShell de s'exécuter

**L'aperçu ne se charge pas ?**

L'aperçu peut ne pas se charger pour les formats non supportés. Vous pouvez toujours appliquer le fond d'écran en utilisant le chemin du fichier image.

## Notes

- L'application stocke le chemin du fond d'écran dans votre registre utilisateur
- Les chemins réseau (chemins UNC) sont supportés pour les fichiers image
- Les fichiers image sont validés avant traitement pour détecter les corruptions

## Licence

Ce projet est distribué sous la **Licence LGPL v3 (GNU Lesser General Public License v3)**. Consultez le fichier [LICENSE](LICENSE) pour plus de détails.

## Contributions

Les contributions, améliorations et pull requests sont acceptées avec plaisir et grandement appréciées ! N'hésitez pas à :

- Signaler des problèmes
- Soumettre des pull requests avec des améliorations
- Suggérer de nouvelles fonctionnalités
- etc

Merci pour l'aide !