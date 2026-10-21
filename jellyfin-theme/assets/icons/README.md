# Library favicon

These generated assets are the Library member of the shared Alphane icon family: charcoal tile, ivory clapperboard/play symbol, matching the Home, Remote PC, Downloads, Sniffer and Groomer icons. The family source/build tools live in the media workspace's `branding/` directory.

The theme's `scripts/apply-icons.sh` is installed at `/config/alphane-branding/start-jellyfin.sh`, alongside these assets under `icons/`. Compose invokes the script as the container entrypoint; it updates the current image's web icons, then executes the official `/jellyfin/jellyfin` entrypoint with all original arguments. Branding failure leaves server startup intact. Run the script with `--assets-only` to update the live web assets without restarting Jellyfin.

This is independent of the Custom CSS deployment and does not change the Apple TV app or Jellyfin metadata. Browser asset backups are retained in the media workspace under `_bak/app-icons-20261020/`. Remove the custom Compose entrypoint to return to the official startup behavior.

Browser favicon artwork fills a 60×60 area of its 64×64 canvas, with a half-pixel inset at 16px to preserve strokes. The SVG, ICO and 16/32/48/64px PNGs share these bounds; touch/PWA PNGs use separate padded artwork. The installer updates existing favicon URL queries to revision 2 on repeat runs, so browsers fetch the enlarged icons.
