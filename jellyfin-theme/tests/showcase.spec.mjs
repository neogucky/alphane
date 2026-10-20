import { test, expect } from '@playwright/test';
import { expectArtworkRing } from './helpers/selection.mjs';

test.beforeEach(async ({ page }) => { await page.goto('/'); });
test('cards scroll within their rows, not the whole page', async ({ page }) => {
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
  const row = page.locator('.itemsContainer');
  await expect(row.locator('.card')).toHaveCount(4);
  const first = row.locator('.cardImageContainer').first();
  await first.focus();
  await expect(first).toBeFocused();
});
test('library actions have separate complete hit areas and invert on selection', async ({ page }, testInfo) => {
  const toolbar = page.getByTestId('library-toolbar');
  const buttons = toolbar.locator('.MuiButtonGroup-grouped').filter({ visible: true });
  const boxes = [];
  for (const button of await buttons.all()) {
    const box = await button.boundingBox(); boxes.push(box);
    expect(box.width).toBeGreaterThanOrEqual(44); expect(box.height).toBeGreaterThanOrEqual(44);
    for (const side of ['top', 'right', 'bottom', 'left']) await expect(button).toHaveCSS(`border-${side}-width`, '0px');
    await expect(button).toHaveCSS('border-top-left-radius', '999px');
    await expect(button).toHaveCSS('border-top-right-radius', '999px');
  }
  for (let i = 1; i < boxes.length; i++) expect(boxes[i].x - boxes[i-1].x - boxes[i-1].width).toBeGreaterThanOrEqual(6);
  const filter = toolbar.getByRole('button', { name: 'Filter', exact: true });
  await expect(filter).toHaveCSS('background-color', 'rgba(0, 0, 0, 0)');
  await expect(filter).toHaveCSS('color', 'rgb(255, 255, 255)');
  const before = await filter.boundingBox();
  await page.keyboard.press('Tab'); await filter.focus();
  await expect(filter).toHaveCSS('background-color', 'rgb(255, 255, 255)');
  await expect(filter).toHaveCSS('color', 'rgb(24, 26, 29)');
  expect(await filter.boundingBox()).toEqual(before);
  await filter.blur(); await filter.evaluate(button => button.setAttribute('aria-pressed', 'true'));
  await expect(filter).toHaveCSS('background-color', 'rgba(255, 255, 255, 0.8)');
  await expect(filter.locator('svg')).toHaveCSS('color', 'rgb(24, 26, 29)');
  if (await page.evaluate(() => matchMedia('(hover: hover) and (pointer: fine)').matches)) {
    await filter.hover(); await expect(filter).toHaveCSS('background-color', 'rgb(255, 255, 255)');
    await page.mouse.move(0, 0); await expect(filter).toHaveCSS('background-color', 'rgba(255, 255, 255, 0.8)');
  }
  if (!testInfo.project.use.isMobile) await expect(toolbar.getByRole('button', { name: 'Previous', exact: true })).toBeDisabled();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
});
test('primary actions brighten on focus and hover, including inside the app bar', async ({ page }) => {
  const primary = page.locator('.MuiAppBar-root .MuiButton-containedPrimary').first();
  await primary.evaluate(button => button.parentElement.insertAdjacentHTML('afterend', '<button class="MuiButton-root MuiButton-containedPrimary" id="primary-action">Create</button>'));
  for (const button of [page.locator('#primary-action'), page.getByRole('button', { name: 'Save changes', exact: true }), page.getByRole('button', { name: 'Resume', exact: true })]) {
    await page.mouse.move(0, 0); await button.blur();
    await button.scrollIntoViewIfNeeded();
    await expect(button).toHaveCSS('background-color', 'rgba(255, 255, 255, 0.8)');
    const before = await button.boundingBox();
    await page.keyboard.press('Tab'); await button.focus();
    await expect(button).toHaveCSS('background-color', 'rgb(255, 255, 255)');
    await expect(button).toHaveCSS('color', 'rgb(24, 26, 29)');
    await button.blur();
    if (await page.evaluate(() => matchMedia('(hover: hover) and (pointer: fine)').matches)) {
      await button.hover(); await expect(button).toHaveCSS('background-color', 'rgb(255, 255, 255)');
      await page.mouse.move(0, 0); await expect(button).toHaveCSS('background-color', 'rgba(255, 255, 255, 0.8)');
    }
    const after = await button.boundingBox();
    expect({ width: after.width, height: after.height }).toEqual({ width: before.width, height: before.height });
  }
});
test('the header symbol follows the server name and inverts with it', async ({ page }) => {
  const brand = page.locator('.MuiAppBar-root a[href="#/"]');
  expect(await brand.evaluate(element => { const style = getComputedStyle(element, '::before'); return style.width === '24px' && style.height === '26px' && style.maskImage.includes('data:image/png;base64,'); })).toBeTruthy();
  await page.keyboard.press('Tab'); await brand.focus();
  await expect(brand).toHaveCSS('background-color', 'rgb(255, 255, 255)');
  expect(await brand.evaluate(element => getComputedStyle(element, '::before').backgroundColor)).toBe('rgb(24, 26, 29)');
});
test('selection frames the full artwork without moving it or blocking actions', async ({ page }, testInfo) => {
  const card = page.locator('.card').first(), artwork = card.locator('.cardScalable');
  const before = await artwork.boundingBox();
  const pointer = await page.evaluate(() => matchMedia('(hover: hover) and (pointer: fine)').matches);
  if (pointer) {
    await card.hover();
    await expectArtworkRing(page, artwork, testInfo, 'hover');
    expect(await artwork.boundingBox()).toEqual(before);
  }
  await page.mouse.move(0, 0); await page.keyboard.press('Tab');
  await card.locator('.cardImageContainer').focus();
  await expectArtworkRing(page, artwork, testInfo, 'keyboard');
  expect(await artwork.boundingBox()).toEqual(before);
  const action = card.getByRole('button', { name: 'More for Chalk up!' });
  await action.focus(); await expect(action).toHaveCSS('outline-style', 'solid');
  // trial checks hit testing without invoking any playback or menu action.
  await action.click({ trial: true });
  await action.blur();
  await card.evaluate(element => element.classList.add('show-focus'));
  await expectArtworkRing(page, artwork, testInfo, 'remote-control-focus');
  expect(await artwork.boundingBox()).toEqual(before);
});
test('identification and metadata dialogs remain accessible', async ({ page }) => {
  await expect(page.getByRole('button', { name: 'Identify', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Edit images', exact: true })).toBeVisible();
  await page.evaluate(() => document.getElementById('metadata').showModal());
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.getByRole('dialog').getByRole('textbox').fill('Edited title');
  await expect(page.getByRole('dialog').getByRole('button', { name: 'Save', exact: true })).toBeVisible();
  await page.getByRole('dialog').getByRole('button', { name: 'Cancel', exact: true }).click();
  await expect(page.getByRole('dialog')).not.toBeVisible();
});
test('neutral progress matches the TV cards and essential player controls remain visible', async ({ page }) => {
  const track = page.locator('.itemProgressBar').first(), fill = track.locator('.itemProgressBarForeground');
  await expect(fill).toHaveCSS('background-color', 'rgb(255, 255, 255)');
  await expect(track).toHaveCSS('background-color', 'rgba(255, 255, 255, 0.2)');
  await expect(track).toHaveCSS('height', '6px');
  const image = await page.locator('.cardImageContainer').first().boundingBox(), bar = await track.boundingBox();
  expect(bar.x - image.x).toBeCloseTo(5, 1); expect(image.y + image.height - bar.y - bar.height).toBeCloseTo(5, 1);
  // Keep Jellyfin's data-driven widths, including no progress and completion.
  for (const progress of [0, 60, 100]) {
    await fill.evaluate((element, progress) => element.style.width = `${progress}%`, progress);
    expect((await fill.boundingBox()).width / bar.width).toBeCloseTo(progress / 100, 2);
  }
  await fill.evaluate(element => element.style.width = '60%');
  await expect(page.getByRole('button', { name: 'Pause', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Audio', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Subtitles', exact: true })).toBeVisible();
});

test('player header fades into the picture without a horizontal divider', async ({ page }, testInfo) => {
  await page.evaluate(() => document.body.insertAdjacentHTML('afterbegin', `
    <header id="empty-player-appbar" class="MuiAppBar-root"></header>
    <section id="player-header-preview" style="height:180px;position:relative;background:rgb(90,140,190)">
      <div class="skinHeader skinHeader-withBackground osdHeader" style="height:90px;position:absolute;inset:0 0 auto;background:linear-gradient(rgba(16,16,16,.75),transparent)"></div>
    </section>`));
  const header = page.locator('#player-header-preview .osdHeader');
  await expect(header).toHaveCSS('border-bottom-width', '0px');
  await expect(page.locator('#empty-player-appbar')).toHaveCSS('height', '0px');
  // Library navigation keeps its divider; only the playback overlays lose it.
  await expect(page.locator('header.MuiAppBar-root').filter({ has: page.locator('.MuiToolbar-root') }).first()).toHaveCSS('border-bottom-width', '1px');
  const screenshot = await page.locator('#player-header-preview').screenshot({ scale: 'css' });
  await testInfo.attach('player-header', { body: screenshot, contentType: 'image/png' });
  const edgeDifference = await page.evaluate(async base64 => {
    const image = new Image(); image.src = 'data:image/png;base64,' + base64; await image.decode();
    const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
    const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
    const pixels = context.getImageData(Math.floor(image.width / 2), 89, 1, 2).data;
    return Math.max(...[0, 1, 2].map(channel => Math.abs(pixels[channel] - pixels[channel + 4])));
  }, screenshot.toString('base64'));
  expect(edgeDifference, 'no visible seam at the bottom of the fading header').toBeLessThanOrEqual(3);
});
test('colour modes update progress and state cues while focus stays white', async ({ page }) => {
  const fill = page.locator('.itemProgressBarForeground').first();
  const before = await fill.boundingBox();
  await page.evaluate(() => {
    const sample = document.createElement('div');
    sample.innerHTML = '<span class="playedIndicator">✓</span><span class="ratingbutton-icon-withrating">♥</span>';
    document.body.append(sample);
  });
  const modes = [
    ['blueradiance', 'rgb(106, 214, 202)', 'rgba(106, 214, 202, 0.2)'],
    ['purplehaze', 'rgb(225, 180, 113)', 'rgba(225, 180, 113, 0.2)'],
    ['dark', 'rgb(255, 255, 255)', 'rgba(255, 255, 255, 0.2)']
  ];
  for (const [id, colour, track] of modes) {
    await page.getByRole('combobox', { name: 'Colour scheme' }).selectOption(id);
    await expect(fill).toHaveCSS('background-color', colour);
    await expect(page.locator('.itemProgressBar').first()).toHaveCSS('background-color', track);
    await expect(page.locator('.progress-preview')).toHaveCSS('background-color', colour);
    await expect(page.locator('.playedIndicator')).toHaveCSS('background-color', colour);
    await expect(page.locator('.ratingbutton-icon-withrating')).toHaveCSS('color', colour);
    const after = await fill.boundingBox();
    expect(after.width).toBe(before.width); expect(after.height).toBe(before.height);
    const filter = page.getByRole('button', { name: 'Filter', exact: true });
    await page.keyboard.press('Tab'); await filter.focus();
    await expect(filter).toHaveCSS('background-color', 'rgb(255, 255, 255)');
    await expect(filter).toHaveCSS('color', 'rgb(24, 26, 29)');
  }
});
test('reduced-motion preference removes card transitions', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('.cardScalable').first()).toHaveCSS('transition-duration', '0s');
});
test('stylesheet parses without dropped selectors or third-party requests', async ({ page }, testInfo) => {
  const issues = await page.evaluate(() => {
    const sheet = [...document.styleSheets].find(sheet => sheet.href?.includes('alphane.css'));
    const css = [...sheet.cssRules].map(rule => rule.cssText).join('\n');
    return { tokens: getComputedStyle(document.documentElement).getPropertyValue('--alphane-background').trim(), rules: sheet.cssRules.length, importRule: css.includes('@import') };
  });
  expect(issues.tokens).toBe('#181a1d');expect(issues.rules).toBeGreaterThan(80);expect(issues.importRule).toBeFalsy();
  await page.screenshot({ path: testInfo.outputPath('showcase.png'), fullPage: true });
});
