"""Génère les catalogues de traduction (français → anglais) et vérifie que
chaque texte utilisé par le code y figure."""
import json, sys
sys.path.insert(0, sys.path[0])
from l10n_keys import keys

EN = {
 "%@ %@ max": "%@ %@ max",
 "%@ mètres par seconde carrée, %@": "%@ metres per second squared, %@",
 "%@ secondes": "%@ seconds",
 "%@ · ancien %@": "%@ · previous %@",
 "%@, %@, ancien record %@": "%@, %@, previous record %@",
 "%@, record %@": "%@, record %@",
 "%@, record %@, battu pendant ce trajet": "%@, record %@, beaten on this trip",
 "30 dernières secondes": "Last 30 seconds",
 "Accélération": "Acceleration",
 "Accélération forte": "Hard acceleration",
 "Alerte de vitesse": "Speed alert",
 "Alerter au-dessus d'un seuil": "Alert above a limit",
 "Altitude": "Altitude",
 "Annuler": "Cancel",
 "Appareil photo indisponible": "Camera unavailable",
 "Arrivée": "Finish",
 "Assistance": "Support",
 "Aucun temps mesuré pour l'instant.": "No time recorded yet.",
 "Aucun trajet": "No trips",
 "Avantage au trajet A.": "Trip A is better.",
 "Avantage au trajet B.": "Trip B is better.",
 "Carte": "Map",
 "Comparer": "Compare",
 "Distance": "Distance",
 "Données d'illustration": "Sample data",
 "Droit": "Upright",
 "Droite": "Right",
 "Durée de roulage": "Moving time",
 "Durée totale": "Total time",
 "Démarrer": "Start",
 "Démarrer le trajet": "Start trip",
 "Départ": "Start",
 "En pause": "Paused",
 "Enregistrement": "Recording",
 "Exporter le tracé (GPX)": "Export route (GPX)",
 "Fermer": "Close",
 "Fixez solidement le téléphone au guidon avant de partir.": "Mount the phone firmly on the handlebar before setting off.",
 "Freinage": "Braking",
 "Freinage fort": "Hard braking",
 "GPS": "GPS",
 "Gardez les yeux sur la route. Les mesures sont indicatives et ne remplacent pas le compteur du véhicule.": "Keep your eyes on the road. Readings are indicative and do not replace the vehicle's speedometer.",
 "Gauche": "Left",
 "Historique": "History",
 "Historique des trajets": "Trip history",
 "Incl. droite": "Lean right",
 "Incl. gauche": "Lean left",
 "Inclinaison": "Lean angle",
 "Inclinaison droite": "Lean right",
 "Inclinaison gauche": "Lean left",
 "Inclinaison max.": "Max lean",
 "Inclinaison max. droite": "Max lean right",
 "Inclinaison max. gauche": "Max lean left",
 "J'ai compris": "I understand",
 "Kilomètres": "Kilometres",
 "Le compteur passe au rouge et le téléphone vibre quand le seuil est dépassé. L'alerte ne fonctionne que lorsque l'app est à l'écran.": "The speedometer turns red and the phone vibrates when the limit is exceeded. The alert only works while the app is on screen.",
 "Ouvre les records": "Opens your records",
 "Date": "Date",
 "Accélération modérée": "Moderate acceleration",
 "Freinage modéré": "Moderate braking",
 "Pic : %@": "Peak: %@",
 "Précision : %@": "Accuracy: %@",
 "Recherche du signal": "Searching for signal",
 "Accélération (m/s²)": "Acceleration (m/s²)",
 "Temps": "Time",
 "Les temps d'accélération restent mesurés en km/h.": "Acceleration times are still measured in km/h.",
 "Meilleur chiffre de la ligne. Distance et durées ne sont pas classées.": "Best figure on each line. Distance and times are not ranked.",
 "Mesure en cours": "Timing in progress",
 "Mettre en pause": "Pause",
 "Miles": "Miles",
 "Ne manipulez jamais l'application en roulant. Démarrez et terminez le trajet à l'arrêt.": "Never operate the app while riding. Start and end the trip while stopped.",
 "Nouveau trajet": "New trip",
 "OK": "OK",
 "Ouvrir Réglages": "Open Settings",
 "Partage impossible": "Unable to share",
 "Partager": "Share",
 "Partager l'image du résumé": "Share summary image",
 "Photo": "Photo",
 "Pic": "Peak",
 "Pic d'accélération": "Peak acceleration",
 "Plus d'options": "More options",
 "Politique de confidentialité": "Privacy policy",
 "Position": "Position",
 "Position refusée · Ouvrir Réglages": "Location denied · Open Settings",
 "Poussée d'accélération": "Acceleration thrust",
 "Progression du record": "Record progression",
 "Prêt à partir": "Ready to ride",
 "Recalibrer l'inclinaison": "Recalibrate lean angle",
 "Record battu": "New record",
 "Records": "Records",
 "Reprendre": "Resume",
 "Respectez le code de la route. Les mesures d'accélération sont réservées aux lieux où elles sont autorisées et sans danger.": "Obey traffic laws. Acceleration timing is only for places where it is legal and safe.",
 "Roulez en sécurité": "Ride safely",
 "Réglages": "Settings",
 "Résumé du trajet": "Trip summary",
 "Scooter Power a besoin de votre position pour mesurer le trajet.": "Scooter Power needs your location to measure the trip.",
 "Seuil : %@ %@": "Limit: %@ %@",
 "Signal GPS faible": "Weak GPS signal",
 "Stable": "Steady",
 "Temps d'accélération": "Acceleration times",
 "Terminer": "End",
 "Terminer le trajet": "End trip",
 "Terminer le trajet ?": "End trip?",
 "Tracé indisponible pour ce trajet.": "No route available for this trip.",
 "Trajet A": "Trip A",
 "Trajet A : %@. Trajet B : %@.": "Trip A: %@. Trip B: %@.",
 "Trajet B": "Trip B",
 "Trajet en cours": "Trip in progress",
 "Trajet terminé": "Trip ended",
 "Unités": "Units",
 "Vers la droite": "To the right",
 "Vers la gauche": "To the left",
 "Version": "Version",
 "Vitesse actuelle": "Current speed",
 "Vitesse max": "Top speed",
 "Vitesse maximale": "Top speed",
 "Vitesse moyenne": "Average speed",
 "Vos trajets terminés apparaîtront ici.": "Your finished trips will appear here.",
 "inconnue": "unknown",
 "À propos": "About",
 "Égalité.": "Tie.",
 # extension
 "%@ droite": "%@ right",
 "%@ gauche": "%@ left",
 "Durée": "Time",
}

INFO = {
 "CFBundleDisplayName": ("Scooter Power", "Scooter Power"),
 "NSLocationWhenInUseUsageDescription": (
   "Scooter Power utilise votre position pour mesurer la vitesse, la distance et tracer votre trajet.",
   "Scooter Power uses your location to measure speed and distance and to record your route."),
 "NSMotionUsageDescription": (
   "Scooter Power utilise les capteurs de mouvement pour mesurer l'accélération et l'inclinaison.",
   "Scooter Power uses motion sensors to measure acceleration and lean angle."),
 "NSCameraUsageDescription": (
   "Scooter Power utilise l'appareil photo pour prendre des photos pendant le trajet.",
   "Scooter Power uses the camera to take photos during a trip."),
 "NSPhotoLibraryAddUsageDescription": (
   "Scooter Power enregistre vos photos de trajet dans votre photothèque.",
   "Scooter Power saves your trip photos to your photo library."),
}

def catalog(entries):
    strings = {}
    for key in sorted(entries):
        strings[key] = {"localizations": {"en": {"stringUnit": {"state": "translated", "value": entries[key]}}}}
    return {"sourceLanguage": "fr", "strings": strings, "version": "1.0"}

def write(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")

root = sys.argv[1]
problems = []
for folder in ("ScooterPower", "ScooterPowerWidgets"):
    used = keys(root + "/" + folder)
    missing = sorted(k for k in used if k not in EN)
    if missing:
        problems.append((folder, missing))
    entries = {k: EN[k] for k in used if k in EN}
    for key, value in entries.items():
        assert key.count("%@") == value.count("%@"), ("nombre de paramètres", key)
    write(f"{root}/{folder}/Localizable.xcstrings", catalog(entries))
    print(folder, len(entries), "textes traduits")

info = {"sourceLanguage": "fr", "version": "1.0", "strings": {}}
for key, (fr, en) in INFO.items():
    info["strings"][key] = {"extractionState": "manual", "localizations": {
        "fr": {"stringUnit": {"state": "translated", "value": fr}},
        "en": {"stringUnit": {"state": "translated", "value": en}}}}
write(f"{root}/ScooterPower/InfoPlist.xcstrings", info)
write(f"{root}/ScooterPowerWidgets/InfoPlist.xcstrings", {"sourceLanguage": "fr", "version": "1.0", "strings": {
    "CFBundleDisplayName": info["strings"]["CFBundleDisplayName"]}})

unused = sorted(k for k in EN if k not in keys(root + "/ScooterPower") and k not in keys(root + "/ScooterPowerWidgets"))
if unused: print("traductions inutilisées :", unused)
if problems:
    for folder, missing in problems: print("NON TRADUIT dans", folder, ":", missing)
    sys.exit(1)
print("OK : chaque texte du code a sa traduction")
