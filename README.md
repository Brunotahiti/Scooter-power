# Scooter Power

Application iPhone qui affiche en direct le tableau de bord d'un trajet en
scooter, à partir des capteurs du téléphone fixé au guidon : vitesse GPS,
vitesse maximale et moyenne, distance, altitude, durées, poussée
d'accélération et inclinaison.

## Prérequis

- Xcode 16 ou plus récent
- iOS 17 ou plus récent
- Un iPhone réel pour les capteurs. Dans le simulateur, l'app passe en mode
  démo et affiche « Données d'illustration ».

## Lancer l'app

1. Ouvrir `ScooterPower.xcodeproj`.
2. Dans la cible *ScooterPower*, onglet *Signing & Capabilities*, choisir son
   équipe. L'identifiant de bundle est `com.brunotahiti.ScooterPower`.
3. Lancer sur un iPhone.

> **État de vérification.** La logique (`ScooterCore`) est couverte par des
> tests qui passent. L'app elle-même a été écrite sans Xcode : elle n'a été
> ni compilée ni lancée par son auteur. La première compilation peut
> demander quelques retouches.

## Utilisation

1. Fixer le téléphone au guidon, écran face au pilote, en portrait.
2. Scooter droit et à l'arrêt, toucher **Démarrer le trajet**. La position
   du téléphone à cet instant sert de zéro pour l'inclinaison et définit
   l'avant du scooter.
3. Si le téléphone a bougé dans son support : menu **•••** puis
   **Recalibrer l'inclinaison**, scooter droit.
4. **Terminer le trajet** affiche le résumé. Les trajets ne sont pas
   sauvegardés.

## Ce que mesurent les capteurs

- **Vitesse, distance, altitude** : GPS. Les points dont la précision
  dépasse 50 m sont ignorés ; sans point valide depuis 5 s, la vitesse
  affiche `--`.
- **Durée de roulage** : temps passé au-dessus de 3 km/h.
- **Accélération** : accéléromètre projeté sur l'axe de marche, corrigé par
  la dérivée de la vitesse GPS. « Forte » à partir de ±2,5 m/s².
- **Inclinaison** : direction de la gravité par rapport à la calibration.
  En virage, la force centrifuge maintient la gravité apparente dans l'axe
  du scooter : **l'angle affiché est inférieur à l'inclinaison réelle**.
  La mesure est fiable à l'arrêt et à basse vitesse.

## Structure

```
ScooterCore/      package Swift : calculs, machine à états, formatage (testé)
ScooterPower/     app : capteurs, view model, vues SwiftUI
Config/           Info.plist (mode d'arrière-plan « location »)
docs/superpowers/ spécification et plan d'implémentation
```

## Tests

```bash
cd ScooterCore
swift test
```

`ScooterCore` n'importe que Foundation : les tests tournent sous macOS comme
sous Linux.
