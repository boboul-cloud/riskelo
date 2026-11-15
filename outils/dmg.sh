#!/bin/zsh
#
# dmg.sh — Riskelo pour Mac, dans un DMG, hors App Store.
#
# En clair : construit la version Mac du jeu tel qu'il est dans ce dossier, et
# la range dans un fichier .dmg qu'on ouvre et dont on glisse l'application
# dans « Applications ». Rien ne part chez Apple, rien n'est créé sur le
# compte développeur.
#
#     zsh outils/dmg.sh
#
# Le DMG sort dans build/dmg/.
#
# Trois choix, et leurs raisons.
#
# Une signature locale, et non celle d'Apple. Distribuer à d'autres demande un
# certificat « Developer ID » et un passage chez Apple (la notarisation) : ce
# sont des gestes sur le compte, et ils reviennent à Robert. Signée sur ce Mac,
# l'application s'y ouvre sans rien demander ; ailleurs, macOS la retient la
# première fois — Réglages Système › Confidentialité et sécurité › « Ouvrir
# quand même ».
#
# Une identité à part, « Riskelo DMG » (com.oulhen.riskelo.dmg). Sous le même
# identifiant que l'App Store, elle aurait remplacé sa copie dans
# Applications, et partagé ses parties enregistrées — une version en avance
# qui écrit dans les sauvegardes d'une version en vente.
#
# Ni Game Center ni liens d'invitation automatiques : ces deux droits exigent
# un profil délivré par Apple, et un Mac refuse d'ouvrir une application qui
# les réclame sans lui. Le jeu à deux, le jeu au loin et le code d'invitation
# tapé à la main marchent. Les packs achetés, eux, restent fermés : ils se
# reconnaissent par l'App Store, qu'une application installée à la main ne
# voit pas.

set -euo pipefail

racine=${0:A:h:h}
cd "$racine"

sortie="$racine/build/dmg"
derive="$sortie/derive"
scene="$sortie/scene"
nom="Riskelo DMG"
identifiant="com.oulhen.riskelo.dmg"
version=$(grep -m1 'MARKETING_VERSION' project.yml | sed -E 's/.*"([^"]+)".*/\1/')
dmg="$sortie/Riskelo-DMG-$version-$(date +%Y-%m-%d).dmg"

echo "› Projet régénéré depuis project.yml"
xcodegen generate --quiet

echo "› Construction pour Mac (Apple et Intel), sans signature"
rm -rf "$derive" "$scene"
xcodebuild -project Riskelo.xcodeproj -scheme Riskelo -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$derive" \
    CODE_SIGNING_ALLOWED=NO build -quiet

app_construite="$derive/Build/Products/Release/Riskelo.app"
mkdir -p "$scene"
app="$scene/$nom.app"
cp -R "$app_construite" "$app"

echo "› Identité à part : $nom ($identifiant)"
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $identifiant" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $nom" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $nom" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleName string $nom" "$plist"

echo "› Signature locale, avec le bac à sable et le réseau seulement"
droits="$sortie/droits.plist"
cat > "$droits" <<'FIN'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
</dict>
</plist>
FIN
codesign --force --deep --sign - --entitlements "$droits" --timestamp=none "$app"
codesign --verify --deep --strict "$app"

echo "› Le DMG"
ln -s /Applications "$scene/Applications"
rm -f "$dmg"
hdiutil create -volname "$nom" -srcfolder "$scene" -ov -format UDZO "$dmg" -quiet

echo
echo "Prêt : $dmg"
