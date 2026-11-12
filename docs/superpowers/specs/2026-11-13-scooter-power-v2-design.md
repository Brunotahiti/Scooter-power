# Scooter Power — spécification de la version 2

Date : 2026-11-13. Complète `2026-11-12-scooter-power-design.md`.

Cinq fonctions indépendantes, livrées dans cet ordre, un commit chacune.

## 1. Mesures 0–50 et 0–80 km/h

`SprintTimer` dans `ScooterCore`, alimenté par les vitesses GPS valides
pendant l'enregistrement.

- **Armé** dès qu'une vitesse est sous 1 km/h.
- **Départ** quand la vitesse repasse à 1 km/h ou plus. L'instant de départ
  est interpolé linéairement entre le dernier point à l'arrêt et le premier
  point en mouvement.
- **Passage** à 50 puis à 80 km/h : instant interpolé linéairement entre les
  deux points qui encadrent le seuil.
- **Annulé** si la vitesse retombe de plus de 3 km/h sous le maximum atteint
  pendant la mesure, si deux points sont séparés de plus de 3 s, si la
  mesure dépasse 60 s, ou à la mise en pause. Un 0–50 déjà obtenu reste
  acquis même si le 0–80 est annulé.
- Un temps inférieur à 1,5 s est rejeté (saut GPS).
- Sorties : dernier et meilleur temps pour chaque seuil, mesure en cours et
  temps écoulé.

Affichage : une carte fine « 0–50 km/h » / « 0–80 km/h » avec le meilleur
temps du trajet, ou le chrono qui tourne pendant une mesure. Les meilleurs
temps figurent dans le résumé et l'historique.

Limite : le GPS fournit un point par seconde ; malgré l'interpolation, la
précision est de l'ordre de 0,2 s.

## 2. Vraie inclinaison en virage

- `MotionSample` gagne `rotationRate` (rad/s, repère du téléphone).
- Vitesse de lacet : projection de `rotationRate` sur la gravité unitaire
  (positive en virage à droite).
- Inclinaison physique : `atan(vitesse × lacet / g)`.
- Mélange selon la vitesse GPS : mesure par gravité seule sous 10 km/h,
  mesure physique seule au-dessus de 25 km/h, interpolation linéaire entre
  les deux. Sans vitesse GPS depuis plus de 5 s : gravité seule.
- Lissage, bornes et maxima inchangés.
- Le texte d'avertissement de la carte Inclinaison est retiré.

Risque : le signe ne peut être confirmé que sur la route.

## 3. Historique des trajets

- SwiftData, modèle `TripRecord` : date de départ, statistiques du résumé,
  meilleurs 0–50 / 0–80, tracé encodé en JSON.
- Sauvegarde automatique à la fin de chaque trajet.
- Le tracé est réduit à 2 000 points au plus (`RouteSimplifier`, pas
  régulier, premier et dernier points conservés).
- Bouton d'historique dans l'en-tête quand aucun trajet n'est en cours.
- Liste triée du plus récent au plus ancien, suppression par glissement,
  état vide explicite.
- Détail : carte du tracé et chiffres du résumé.

## 4. Mode paysage

- Orientations acceptées : portrait, paysage gauche, paysage droite.
- En paysage (classe de taille verticale compacte) : compteur agrandi à
  gauche ; à droite quatre tuiles (vitesse maximale, distance, accélération,
  inclinaison) puis Pause et Démarrer / Terminer.
- Carte et Photo restent réservées au portrait.
- La calibration est prise dans la position de départ, quelle qu'elle soit.

## 5. Activité en direct et Dynamic Island

- `TripActivityAttributes` dans `ScooterCore`, compilé seulement sur iOS.
- Nouvelle cible `ScooterPowerWidgets` (extension WidgetKit), identifiant
  `com.brunotahiti.ScooterPower.Widgets`.
- Écran verrouillé : vitesse, distance, durée, état de pause.
- Dynamic Island : vitesse en vue compacte et minimale ; vitesse, durée et
  distance en vue étendue.
- Démarrée au début du trajet, mise à jour au plus une fois par seconde,
  terminée à la fin du trajet. Sans effet si les activités sont désactivées.

## Vérification

Les points 1 et 2 et `RouteSimplifier` sont testés (`swift test`). Le reste
n'est contrôlé qu'en syntaxe sous Linux, et la structure du projet Xcode par
script.
