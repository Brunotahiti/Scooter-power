# Notes pour la validation Apple

À coller dans App Store Connect → Informations pour la validation de l'app →
Notes. Rédigées en anglais, langue de l'équipe de validation.

```
Scooter Power is a ride dashboard for scooters. The phone is mounted on the
handlebar and the app shows GPS speed, distance, acceleration and lean angle
during a ride. No account or login is required.

HOW TO TEST
1. Launch the app and accept the one-time safety notice.
2. Tap "Démarrer le trajet" (Start trip) and allow Location and Motion access.
3. Move with the device (walking is enough): speed, distance and duration
   update. Tilt the device to see the lean gauge move.
4. Lock the screen: the Live Activity shows speed, distance and duration.
5. Tap "Terminer le trajet" (End trip) to see the summary. The trip is saved
   and listed under the clock icon at the top of the screen.

BACKGROUND LOCATION
The app declares the "location" background mode and requests When In Use
authorization only. Location updates start when the user taps Start trip and
stop when the user ends the trip. They continue in the background so that a
ride is recorded without gaps while the screen is locked, which is the normal
situation on a handlebar mount. The blue location indicator is shown and the
Live Activity makes the ongoing recording visible. Location is never used
when no trip is being recorded.

DATA
All measurements stay on the device (SwiftData). Nothing is sent to any
server; the app has no backend, no analytics and no advertising. Photos taken
with the camera button are saved to the user's photo library only.

SAFETY
A safety notice is shown at first launch. Starting and ending a trip are the
only actions needed, and both are meant to be done while stopped.

0-50 / 0-80 km/h TIMES
These are computed automatically from GPS speed whenever the vehicle leaves a
standstill. They need a real vehicle and cannot be reproduced on foot.
```

## Coordonnées à renseigner

Nom, téléphone et adresse e-mail d'une personne joignable pendant la
validation : champs obligatoires dans App Store Connect.
