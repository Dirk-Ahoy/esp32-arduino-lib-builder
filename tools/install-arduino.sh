#/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE ARDUINO
#
echo "Updating ESP32 Arduino..."
if [ ! -d "$AR_COMPS/arduino" ]; then
	git clone $AR_REPO_URL "$AR_COMPS/arduino"
fi

git -C "$AR_COMPS/arduino" reset --hard -q || exit 1

if [ -n "$AR_COMMIT" ]; then
    echo "Fetching Arduino commit: $AR_COMMIT"
    git -C "$AR_COMPS/arduino" fetch origin "$AR_COMMIT" || exit 1
    git -C "$AR_COMPS/arduino" checkout --detach -q "$AR_COMMIT" || exit 1
else
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
fi

# Remove the same unused components as the previous Ahoy build.
for comp in $AHOY_REMOVE_COMPONENTS; do
    for yml in "$AR_COMPS/arduino/idf_component.yml" "$AR_ROOT/main/idf_component.yml"; do
        if grep -Fq "  $comp:" "$yml"; then
            awk -v rm="$comp" '
                /^  [^ #][^:]*:/ { key=$1; sub(/:$/, "", key); skip=(key == rm) }
                /^[^ ]/ { skip=0 }
                !skip { print }
            ' "$yml" > "$yml.tmp" && mv "$yml.tmp" "$yml" || exit 1
            if grep -Fq "  $comp:" "$yml"; then exit 1; fi
            echo "Component removed: $comp ($yml)"
        fi
    done
done
