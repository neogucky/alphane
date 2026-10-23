import test from 'node:test';
import assert from 'node:assert/strict';
import { configureWebThemes, colourThemes } from '../scripts/configure-web.mjs';

test('native colour choices preserve configuration and remain idempotent', () => {
  const input = { plugins: ['existing'], servers: [{ address: 'https://example.invalid' }], menuLinks: [{ name: 'Home', url: '/' }], themes: [{ id: 'dark', name: 'Dark', default: true, extra: 'retain' }, { id: 'light', name: 'Light' }] };
  const before = structuredClone(input), output = configureWebThemes(input);
  assert.deepEqual(input, before);
  for (const key of ['plugins', 'servers', 'menuLinks']) assert.deepEqual(output[key], input[key]);
  assert.deepEqual(output.themes.slice(0, 3).map(({ id, name }) => ({ id, name })), colourThemes.map(({ id, name }) => ({ id, name })));
  assert.equal(output.themes[0].extra, 'retain');
  assert.equal(output.themes.find(theme => theme.id === 'light').name, 'Light');
  assert.deepEqual(output.themes.filter(theme => theme.default).map(theme => theme.id), ['dark']);
  assert.equal(new Set(output.themes.map(theme => theme.id)).size, output.themes.length);
  assert.deepEqual(configureWebThemes(output), output);
});
