# Alphane for Jellyfin Web

A self-contained dark theme for Jellyfin Web, based on Alphane's Apple TV design: neutral charcoal surfaces, white selected controls, landscape artwork and clear focus outlines. **No accent** is the default, with white/grey progress and neutral state indicators. Optional **Aqua** and **Amber** modes add colour to progress and small state cues while retaining white focus controls. The theme targets Jellyfin **12.1** and covers modern navigation plus legacy library, detail, login, player and admin components.

This is a CSS theme, not a replacement player or a fork of Jellyfin Web. Continue Watching, Next Up, discovery, account permissions and metadata operations keep their existing behavior. The Apple TV app and other native clients are unaffected. The TV app's selected-item hero and randomized discovery rows are future application features, not part of this stylesheet.

## Files

- `src/`: shared tokens and styles grouped by component. Colour tokens follow `Alphane tvOS/Objects/AlphaneTheme.swift`.
- `dist/alphane.css`: reproducible stylesheet, including the existing Alphane logo. It has no external CSS imports, fonts or asset dependencies.
- `scripts/`: build, fictional-media preview, authenticated deployment and verified rollback.
- `tests/`: browser fixtures, optional real-server checks and deployment/rollback tests.
- `assets/`: branding and preview asset provenance.

## Build and preview

Use Node.js 22 or newer:

```sh
cd jellyfin-theme
npm ci
npm run build
npm test
npm run preview
```

Open `http://127.0.0.1:4179`. The preview uses fictional titles and artwork already checked into Alphane. It does not contact a media server. It demonstrates colours, cards, details, dialogs and player controls, rather than claiming to reproduce every Jellyfin page.

## Install

The simplest installation is to paste `dist/alphane.css` into **Dashboard → Branding → Custom CSS**. Replace the existing theme, including external `@import` rules, rather than stacking multiple themes. Use Jellyfin's Dark theme as the baseline, then refresh the browser. If a user has disabled server custom CSS in Display settings, enable it there.

For an installation with an automatic backup, set `ALPHANE_SERVER` and either:

- `ALPHANE_USERNAME` plus `ALPHANE_PASSWORD_FILE`, pointing to a local file containing the password; or
- `ALPHANE_API_KEY_FILE`, pointing to an application credential created through Jellyfin's admin interface.

`ALPHANE_PASSWORD` is also supported for ephemeral environment injection. Never put passwords or tokens in arguments, this repository, or CI logs. The account must be allowed to manage server branding.

```sh
npm run deploy
```

Deployment changes **only Custom CSS** using Jellyfin's normal configuration API. It preserves the current disclaimer and splash settings, backs up the previous branding configuration under ignored `.private/backups/`, and verifies the stored CSS. No container rebuild, restart, media changes or client JavaScript injection is needed. Username/password sessions are logged out afterward. Use HTTPS for remote administration.

The output names the backup file, and `.private/last-deployment.json` records the last operation. Keep these local files when moving the checkout. `ALPHANE_STATE_DIR` can point to a persistent private directory outside the repository.

```sh
npm run rollback -- /absolute/path/to/branding-backup.json
```

Rollback verifies the backup hash, restores its CSS and preserves other branding settings as they currently stand. Every operation first backs up the current CSS, so rollback can itself be reversed.

## Colour choices

The neutral design follows the default screenshots in README revision `854d54f` (2026-10-18). It uses the TV app's `#181A1D` background, `#282B30` surfaces, 80% white secondary text, white progress and neutral watched/favourite indicators. Colour does not carry state alone: filled watched/favourite glyphs and filter badges retain their native meaning. Error and warning colours remain semantic.

To expose the three presets in Jellyfin's native **Settings → Display → Theme** dropdown, generate an updated Web configuration:

```sh
node scripts/configure-web.mjs existing-config.json alphane-config.json
```

Keep the input for rollback, then install the output as Jellyfin Web's `config.json`. In Docker, bind-mount the file read-only at `/jellyfin/jellyfin-web/config.json`, as described in Jellyfin's [Web configuration documentation](https://jellyfin.org/docs/general/clients/web-config/). This configuration step is separate from the CSS-only deployment command. The configurator preserves plugins, servers, menu links, extra theme fields and other theme options. It refuses to overwrite the input or an existing output.

| Display choice | Native theme ID | Progress / state colour |
| --- | --- | --- |
| Alphane - No accent (default) | `dark` | White |
| Alphane - Aqua | `blueradiance` | `#6AD6CA` |
| Alphane - Amber | `purplehaze` | `#E1B471` |

These existing IDs keep Jellyfin's bundled React and legacy theme modules compatible. The CSS responds to Jellyfin's native `data-theme` attribute; no custom theme module or injected JavaScript is installed. Under Alphane's server CSS, the other built-in choices use the neutral palette.

Select a colour choice and press **Save**. Jellyfin stores its app theme for that user in the current browser/device; it survives refreshes but does not synchronize with the tvOS preference or other browsers. **Server Dashboard theme** is a separate native setting and offers the same choices. A configuration-only installation keeps the existing CSS, so install both pieces together. Browser-only Custom CSS can also override `--alphane-accent`, `--alphane-accent-channel` and `--alphane-accent-track` for a custom colour.

## Browser checks

```sh
npx playwright install --with-deps chromium webkit
npm run test:browser
```

The checked-in fixtures cover Chromium desktop, a touch phone viewport and WebKit, including page overflow, keyboard focus, editable dialogs, essential player controls, reduced motion and stylesheet parsing. Card selection checks inspect rendered pixels along all four artwork edges with layered overlays and clipped carousels, and verify that action buttons remain clickable. Local Windows runs can use the installed Edge automatically; `ALPHANE_BROWSER_PATH` overrides the Chromium executable.

For optional real-server checks, supply `ALPHANE_SERVER`, `ALPHANE_USERNAME` and an ephemeral `ALPHANE_PASSWORD`. Set `ALPHANE_PREVIEW=1` to replace branding responses only in that browser session; this mode does not save server settings. The live checks navigate without playing media, editing metadata, changing watched state, or disconnecting other clients.

```sh
npx playwright test tests/live.spec.mjs --project=desktop --project=phone
```

Live screenshots can contain private library information and are written only to ignored `test-results-live/`. Traces are disabled to avoid capturing credentials. Public CI uses only the fictional fixtures and does not need a server or credentials.

## Compatibility and design boundaries

The theme uses Jellyfin's public palette variables, stable component classes and MUI utility classes; it avoids generated `css-*` selectors. A scoped 12.1 adjustment removes the obsolete legacy Home tab offset underneath the modern app bar. Custom carousels clip to their own viewport while retaining Jellyfin's transform-based scrolling. Native hidden/disabled states and admin actions remain intact.

Watch-progress cards use the TV app's 6px capsule, 5px artwork inset and subdued track. The colour follows the selected mode; Jellyfin's foreground retains its actual watched percentage. The installed library artwork has square cream frames embedded in the images; the scoped `MyMedia .coveredImage` rule crops those frames and keeps the shortcuts borderless, with the shared white selection ring on hover or keyboard focus. Adapt that crop if replacing the library artwork with a different style.

Library toolbar actions have separate rounded hit areas and no joined divider borders. Inactive controls show white text or icons; active controls use 80% white pills, while hover and keyboard focus use full white. Active-filter badges, selected menu items and horizontal segmented controls use the same treatment. Primary actions also brighten from 80% to full white, including actions inside the app bar. Native disabled states remain dimmed. The header shows the bundled Alphane symbol beside the server name and inverts it with the label when highlighted.

This is intentionally a dark theme. Check desktop, phone, login, details, search, metadata/image dialogs and player controls after Jellyfin updates. CSS selectors are not a versioned extension API, so updates may need small compatibility changes. If there is a regression, restore the previous CSS before investigating.

Seek previews keep a dark surface and white timestamps in every colour mode. Chapter images preserve their aspect ratio; desktop trickplay previews scale the whole sprite viewport by 1.25 so Jellyfin's tile coordinates stay intact. The theme cannot create missing frames: enable trickplay image extraction in the relevant library and allow Jellyfin's generation task to finish. Until then, the native chapter/time fallback remains readable.

`src/login.css` styles Jellyfin's native profile picker and manual sign-in within one responsive panel, with the original Alphane mark, larger profile tiles and a clear distinction between the primary sign-in action and recovery/Quick Connect controls. The splash backdrop is suppressed only while the login page is visible. Native form visibility, Remember Me, account selection and the server's login disclaimer remain intact; login does not require a separate web-client fork. `remote-access/check-login-design.cjs` in the media workspace checks desktop/phone layouts and native panel switching without submitting credentials.

Legacy action menus and Identify/metadata dialogs keep the current screen visible through a transparent wrapper with an 8px backdrop blur and Jellyfin's native dimming. The dialog surface stays opaque for readable controls. Browsers without backdrop-filter support retain the visible background without blur.

Optional navigation back to an external landing page can use Jellyfin Web's supported `menuLinks` configuration. An example is in `assets/web-config.example.json`; merge it into your existing web configuration and retain other settings. CSS does not create fake interactive links or hide administration controls.

References: [Custom CSS](https://jellyfin.org/docs/general/clients/css-customization/), [web configuration and menu links](https://jellyfin.org/docs/general/clients/web-config/).
