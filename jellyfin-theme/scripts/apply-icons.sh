#!/bin/sh
# Apply static branding to the official image's current web assets. No fixed
# hashed filenames and no copied web-app fork: container updates keep working.
apply_icons() {
    web=/jellyfin/jellyfin-web
    assets=/config/alphane-branding/icons
    [ -d "$web" ] && [ -f "$assets/icon.ico" ] || return 1
    mkdir -p "$web/alphane-icons" || return 1
    cp -R "$assets/." "$web/alphane-icons/" || return 1
    for file in "$web"/favicon*.ico; do
        [ ! -f "$file" ] || cp "$assets/icon.ico" "$file" || return 1
    done
    for file in "$web"/touchicon*.png; do
        case "$file" in *touchicon144*) size=144;; *) size=180;; esac
        [ ! -f "$file" ] || cp "$assets/icon-$size.png" "$file" || return 1
    done
    for size in 72 114 144 512; do
        [ ! -d "$web/favicons" ] || cp "$assets/icon-$size.png" "$web/favicons/touchicon$size.png" || return 1
    done
    if [ -f "$web/index.html" ]; then
        sed -E 's@href="favicon[^\"]*\.ico([?][^\"]*)?"@href="alphane-icons/icon.ico?v=2"@g;s@href="touchicon[^\"]*\.png([?][^\"]*)?"@href="alphane-icons/icon-180.png?v=1"@g;s@(alphane-icons/icon\.(ico|svg))\?v=[^\"]*@\1?v=2@g' "$web/index.html" > "$web/index.alphane-next.html" || return 1
        if ! grep -q 'alphane-icons/icon.svg' "$web/index.alphane-next.html"; then
            sed 's@</head>@<link rel="icon" type="image/svg+xml" href="alphane-icons/icon.svg?v=2"></head>@' "$web/index.alphane-next.html" > "$web/index.alphane-svg.html" || return 1
            mv -f "$web/index.alphane-svg.html" "$web/index.alphane-next.html" || return 1
        fi
        mv -f "$web/index.alphane-next.html" "$web/index.html" || return 1
    fi
}
if ! apply_icons; then
    echo 'Alphane: icon branding could not be applied; continuing with the server defaults.' >&2
fi
[ "${1:-}" != '--assets-only' ] || exit 0
# Preserve the official image's original entrypoint and all supplied arguments.
exec /jellyfin/jellyfin "$@"
