import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// Keep IDs backed by Jellyfin's bundled legacy and React theme modules.
export const colourThemes = [
  { id: 'dark', name: 'Alphane - No accent', color: '#181a1d', default: true },
  { id: 'blueradiance', name: 'Alphane - Aqua', color: '#181a1d' },
  { id: 'purplehaze', name: 'Alphane - Amber', color: '#181a1d' }
];

export function configureWebThemes(configuration) {
  if (!configuration || typeof configuration !== 'object' || Array.isArray(configuration)) throw new Error('Expected a Jellyfin Web configuration object.');
  const previous = configuration.themes ?? [];
  if (!Array.isArray(previous)) throw new Error('Expected a themes array.');
  const ids = new Set(colourThemes.map(theme => theme.id));
  return {
    ...configuration,
    themes: [
      ...colourThemes.map(theme => ({ ...previous.find(item => item.id === theme.id), default: false, ...theme })),
      ...previous.filter(theme => !ids.has(theme.id)).map(theme => ({ ...theme, default: false }))
    ]
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output] = process.argv.slice(2);
  if (!input || !output || path.resolve(input) === path.resolve(output)) throw new Error('Usage: node scripts/configure-web.mjs existing-config.json new-config.json (keep the original for rollback).');
  const configured = configureWebThemes(JSON.parse(await readFile(input, 'utf8')));
  await writeFile(output, JSON.stringify(configured, null, 2) + '\n', { flag: 'wx' });
  console.log('Saved native Alphane colour choices to ' + output);
}
