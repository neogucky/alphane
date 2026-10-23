# Branding assets

The build embeds `../../Resources/Branding/Alphane-symbol.png` from the Apple TV app as a CSS mask. It keeps the existing silhouette and renders it in the theme's text colour. No duplicate artwork, external font, CDN, or additional asset server is needed.

The preview uses the repository's existing fictional film artwork from `../../readme/preview_video_mocks/`. See that folder for asset provenance. Live screenshots and account information belong in ignored local test output, not here.

## Neutral design reference

The no-accent palette follows the fictional-media README screenshots at Alphane commit `854d54f` (2026-10-18), including `readme/color-schemes.png`, `home.png` and `video-ui.png`. Aqua and Amber use the tvOS preset colours `#6AD6CA` and `#E1B471`. Reference images remain on `main`; they are not duplicated or substituted on the theme branch.
