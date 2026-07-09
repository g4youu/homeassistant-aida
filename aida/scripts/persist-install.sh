#!/usr/bin/with-contenv bashio
# persist-install — install packages that survive add-on restarts.
#   persist-install apk <pkg...>   persist-install pip <pkg...>
#   persist-install list           persist-install remove <apk|pip> <pkg>

set -e
CONFIG="/data/persistent-packages.json"

init() { [ -f "$CONFIG" ] || echo '{"apk_packages":[],"pip_packages":[]}' > "$CONFIG"; }

case "${1:-help}" in
    apk)
        init; shift
        [ $# -eq 0 ] && { echo "No packages."; exit 1; }
        apk add --no-cache "$@" || exit 1
        for p in "$@"; do
            jq -e ".apk_packages|index(\"$p\")" "$CONFIG" >/dev/null 2>&1 || \
                { jq ".apk_packages+=[\"$p\"]" "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"; }
        done
        echo "Installed and will persist: $*"
        ;;
    pip)
        init; shift
        [ $# -eq 0 ] && { echo "No packages."; exit 1; }
        pip3 install --break-system-packages --no-cache-dir "$@" || exit 1
        for p in "$@"; do
            jq -e ".pip_packages|index(\"$p\")" "$CONFIG" >/dev/null 2>&1 || \
                { jq ".pip_packages+=[\"$p\"]" "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"; }
        done
        echo "Installed and will persist: $*"
        ;;
    list)
        init
        echo "APK:"; jq -r '.apk_packages[]? | "  - \(.)"' "$CONFIG"
        echo "pip:"; jq -r '.pip_packages[]? | "  - \(.)"' "$CONFIG"
        ;;
    remove)
        init
        jq "del(.${2}_packages[]|select(.==\"$3\"))" "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
        echo "Removed '$3' from persistence (still installed until restart)."
        ;;
    *)
        echo "Usage: persist-install <apk|pip> <pkg...> | list | remove <apk|pip> <pkg>"
        ;;
esac
