# Scooter Power

Application iPhone qui affiche en direct le tableau de bord d'un trajet en
scooter, à partir des capteurs du téléphone fixé au guidon : vitesse GPS,
vitesse maximale et moyenne, distance, altitude, durées, poussée
d'accélération, inclinaison, temps 0–50 et 0–80 km/h.

Chaque trajet terminé est conservé dans l'historique avec son tracé ; deux
trajets peuvent être comparés côte à côte, les records personnels sont
suivis dans le temps, et un trajet se partage en image ou en fichier GPX.
L'app est disponible en français et en anglais, en kilomètres ou en miles,
avec une alerte de vitesse réglable. Le
trajet en cours s'affiche aussi sur l'écran verrouillé et dans la Dynamic
Island, et l'app passe en compteur plein écran quand le téléphone est en
paysage.

## Prérequis

- Xcode 16 ou plus récent
- iOS 17 ou plus récent
- Un iPhone réel pour les capteurs. Dans le simulateur, l'app passe en mode
  démo et affiche « Données d'illustration ».

## Lancer l'app

1. Ouvrir `ScooterPower.xcodeproj`.
2. Choisir son équipe dans l'onglet *Signing & Capabilities* des **deux**
   cibles : *ScooterPower* et *ScooterPowerWidgetsExtension*.
3. Si l'identifiant de bundle de l'app est modifié, celui de l'extension doit
   rester préfixé par lui : `<identifiant de l'app>.Widgets`.
4. Sélectionner le schéma *ScooterPower* et lancer sur un iPhone.

> **État de vérification.** La logique (`ScooterCore`) est couverte par des
> tests qui passent. L'interface et le projet Xcode sont écrits sans Xcode :
> chaque nouveauté peut demander quelques retouches à la première
> compilation.

## Utilisation

1. Fixer le téléphone au guidon, écran face au pilote, en portrait.
2. Scooter droit et à l'arrêt, toucher **Démarrer le trajet**. La position
   du téléphone à cet instant sert de zéro pour l'inclinaison et définit
   l'avant du scooter.
3. Si le téléphone a bougé dans son support : menu **•••** puis
   **Recalibrer l'inclinaison**, scooter droit.
4. **Terminer le trajet** affiche le résumé et enregistre le trajet.
   L'historique s'ouvre par l'icône d'horloge, visible quand aucun trajet
   n'est en cours.
5. En paysage, démarrer le trajet dans la position où le téléphone restera.

## Ce que mesurent les capteurs

- **Vitesse, distance, altitude** : GPS. Les points dont la précision
  dépasse 50 m sont ignorés ; sans point valide depuis 5 s, la vitesse
  affiche `--`.
- **Durée de roulage** : temps passé au-dessus de 3 km/h.
- **Accélération** : accéléromètre projeté sur l'axe de marche, corrigé par
  la dérivée de la vitesse GPS. « Forte » à partir de ±2,5 m/s².
- **Temps d'accélération** : départs arrêtés 0–30, 0–50 et 0–80 km/h (le
  chrono s'arme à l'arrêt) et reprises lancées 50–90 et 50–100 km/h (le chrono
  part quand 50 km/h est franchi en accélérant). Une mesure s'annule si la
  vitesse retombe. Le GPS ne donnant qu'un point
  par seconde, les passages sont interpolés : précision d'environ 0,2 s.
- **Inclinaison** : sous 10 km/h, direction de la gravité par rapport à la
  calibration. Au-dessus de 25 km/h, physique du virage : vitesse GPS ×
  vitesse de lacet du gyroscope ÷ gravité. Entre les deux, un mélange.

## Structure

```
ScooterCore/      package Swift : calculs, machine à états, formatage (testé)
ScooterPower/         app : capteurs, view model, vues SwiftUI, historique
ScooterPowerWidgets/  extension : activité en direct et Dynamic Island
Config/           fichiers Info.plist des deux cibles
docs/superpowers/ spécification et plan d'implémentation
```

## Traductions

Le français est la langue source ; les textes français servent de clés. Après
avoir ajouté ou modifié un texte dans le code, ajouter sa traduction anglaise
dans `tools/make_catalogs.py`, puis régénérer les catalogues :

```bash
python3 tools/make_catalogs.py .
```

Le script échoue si un texte du code n'a pas de traduction.

## Tests

```bash
cd ScooterCore
swift test
```

`ScooterCore` n'importe que Foundation : les tests tournent sous macOS comme
sous Linux.
