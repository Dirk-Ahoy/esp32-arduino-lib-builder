#/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE ARDUINO
#
echo "Updating ESP32 Arduino..."
if [ ! -d "$AR_COMPS/arduino" ]; then
	git clone $AR_REPO_URL "$AR_COMPS/arduino"
fi

# Ahoy: lokale Aenderungen (entfernte Komponenten) eines frueheren Laufs verwerfen
git -C "$AR_COMPS/arduino" reset --hard -q

if [ -z $AR_SOURCE_BRANCH ]; then
	if [ -n "$IDF_COMMIT" ]; then
		IDF_REF="$IDF_COMMIT"
	elif [ -n "$IDF_TAG" ]; then
		IDF_REF="$IDF_TAG"
	else
		IDF_REF="$IDF_BRANCH"
	fi
	set_ar_source_branch "git_branch_exists" "$AR_COMPS/arduino" "$IDF_REF"
fi

if [ "$AR_SOURCE_BRANCH" ]; then
	echo "AR_SOURCE_BRANCH='$AR_SOURCE_BRANCH'"
	git -C "$AR_COMPS/arduino" fetch --all && \
	git -C "$AR_COMPS/arduino" checkout -B "$AR_SOURCE_BRANCH" origin/"$AR_SOURCE_BRANCH" && \
	git -C "$AR_COMPS/arduino" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

# Ahoy: Arduino-Core auf festen Commit setzen (muss zum offiziellen Paket passen)
if [ -n "$AR_COMMIT" ]; then
	echo "AR_COMMIT='$AR_COMMIT'"
	git -C "$AR_COMPS/arduino" checkout -q "$AR_COMMIT"
	if [ $? -ne 0 ]; then exit 1; fi
fi

# Ahoy: nicht benoetigte Komponenten aus den Abhaengigkeitslisten entfernen
# (Arduino-Core und Lib-Builder-Hauptprojekt)
AHOY_YMLS="$AR_COMPS/arduino/idf_component.yml $AR_ROOT/main/idf_component.yml"
for comp in $AHOY_REMOVE_COMPONENTS; do
	found=0
	for yml in $AHOY_YMLS; do
		if grep -q "^  $comp:" "$yml"; then
			awk -v rm="$comp" '
				/^  [^ #][^:]*:/ { key=$1; sub(/:$/, "", key); skip=(key == rm) }
				/^[^ ]/ { skip=0 }
				!skip { print }
			' "$yml" > "$yml.tmp" && mv "$yml.tmp" "$yml"
			if grep -q "^  $comp:" "$yml"; then
				echo "ERROR: Komponente $comp konnte nicht aus $yml entfernt werden"
				exit 1
			fi
			echo "Komponente entfernt: $comp ($yml)"
			found=1
		fi
	done
	if [ $found -eq 0 ]; then
		echo "WARNUNG: Komponente $comp in keiner Abhaengigkeitsliste gefunden"
	fi
done
