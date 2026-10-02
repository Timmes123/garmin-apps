#!/usr/bin/env bash
# Baut eine App für ein Gerät: ./build.sh aufgussplan [fr965]
set -e
app="${1:?App-Ordner angeben}"
device="${2:-fr965}"
cd "$(dirname "$0")"
sdk="$(cat "$APPDATA/Garmin/ConnectIQ/current-sdk.cfg" | tr -d '\r')"
java="$(ls -d "/c/Program Files/Eclipse Adoptium"/jdk-*/bin | tail -1)/java"
mkdir -p "$app/bin"
# Persönlicher GitHub-Token (nicht im Repo) wird als Ressource eingebaut; ohne Datei bleibt er leer
token="$(cat .keys/github_token.txt 2>/dev/null | tr -d '
 ' || true)"
printf '<resources><strings><string id="GithubToken">%s</string></strings></resources>
' "$token" > "$app/resources/token.xml"
"$java" -Xms1g -Dfile.encoding=UTF-8 -jar "$sdk/bin/monkeybrains.jar" \
  -o "$app/bin/$app.prg" -f "$app/monkey.jungle" -y .keys/developer_key.der -d "$device" -w "${@:3}"
