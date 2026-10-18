import { test, expect } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { root } from '../scripts/build.mjs';
import { expectArtworkRing } from './helpers/selection.mjs';

const server = process.env.ALPHANE_SERVER;
test.describe('Jellyfin integration', () => {
  test.skip(!server || !process.env.ALPHANE_USERNAME || !process.env.ALPHANE_PASSWORD, 'Optional: supply a server and test account.');
  test.beforeEach(async ({ page }) => {
    if (process.env.ALPHANE_PREVIEW === '1') {
      const css = await readFile(path.join(root, 'dist/alphane.css'), 'utf8');
      await page.route(/\/Branding\/Css(?:\.css)?(?:\?|$)/i, route => route.fulfill({ contentType: 'text/css', body: css }));
      await page.route(/\/Branding\/Configuration(?:\?|$)/i, async route => {
        const response = await route.fetch(), json = await response.json();
        json[Object.hasOwn(json, 'CustomCss') ? 'CustomCss' : 'customCss'] = css;
        await route.fulfill({ response, json });
      });
    }
    await page.goto(server.replace(/\/$/, '') + '/web/');
    const manual = page.getByRole('button', { name: 'Manual Login', exact: true });
    await expect.poll(async () => await manual.isVisible() || await page.locator('#txtManualName').isVisible()).toBeTruthy();
    if (await manual.isVisible()) await manual.click();
    // Do not expose a fill call's arguments in a failed test's error log.
    try {
      await page.locator('#txtManualName').fill(process.env.ALPHANE_USERNAME);
      await page.locator('#txtManualPassword').fill(process.env.ALPHANE_PASSWORD);
      await page.locator('#txtManualPassword').press('Enter');
    } catch { throw new Error('The integration test account could not sign in.'); }
    await page.waitForURL('**/#/home');
    await expect.poll(() => page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--alphane-background').trim())).toBe('#181a1d');
  });
  test.afterEach(async ({ page }) => {
    // Log out only this test browser's session. Native clients are unaffected.
    await page.evaluate(async () => { if (window.ApiClient?.logout) await window.ApiClient.logout(); }).catch(() => {});
  });
  test('home fills its viewport and horizontal carousels still move', async ({ page }, testInfo) => {
    await page.locator('.homePage .cardImageContainer').first().waitFor();
    const geometry = await page.evaluate(() => {
      const home = document.querySelector('.homePage').getBoundingClientRect();
      const header = document.querySelector('header.MuiAppBar-root')?.getBoundingClientRect();
      return { width: document.documentElement.scrollWidth, viewport: innerWidth, bottom: home.bottom, height: innerHeight, top: home.top, headerBottom: header?.bottom };
    });
    expect(geometry.width).toBeLessThanOrEqual(geometry.viewport + 1);
    expect(Math.abs(geometry.bottom - geometry.height)).toBeLessThan(3);
    if (geometry.headerBottom) expect(geometry.top).toBeGreaterThanOrEqual(geometry.headerBottom - 2);
    const row = page.locator('.homePage .NextUp');
    if (await row.count()) {
      const first = row.locator('.card').first(); await first.scrollIntoViewIfNeeded();
      const before = await first.boundingBox();
      const right = row.locator('.emby-scrollbuttons .emby-scrollbutton-right, .emby-scrollbutton-right').first();
      if (await right.isVisible() && await right.isEnabled()) {
        await right.click(); await expect.poll(async () => (await first.boundingBox())?.x).not.toBe(before.x);
      }
    }
    await page.screenshot({ path: testInfo.outputPath('home.png') });
  });
  test('header uses text labels and padded highlights without overflowing', async ({ page }, testInfo) => {
    const header = page.locator('header.MuiAppBar-root');
    await page.locator('.homePage .cardImageContainer').first().waitFor();
    const brand = header.locator('a[href="#/"]');
    await expect(brand.locator('.MuiButton-startIcon')).toBeHidden();
    if (!testInfo.project.use.isMobile) {
      for (const width of [1440, 1200, 1024]) {
        await page.setViewportSize({ width, height: 1000 });
        const movies = header.locator('a[href*="/movies?"]');
        await expect(movies).toBeVisible();
        await expect(movies.locator('.MuiButton-startIcon')).toBeHidden();
        await expect(movies).toHaveCSS('padding-left', width < 1200 ? '12px' : '24px');
        const before = await movies.boundingBox(); await movies.hover();
        await expect(movies).toHaveCSS('background-color', 'rgba(255, 255, 255, 0.094)');
        expect(await movies.boundingBox()).toEqual(before);
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBeTruthy();
        const search = await header.locator('a[href="#/search"]').boundingBox();
        const lastLink = await header.locator('a.MuiButton-root').last().boundingBox();
        expect(lastLink.x + lastLink.width).toBeLessThanOrEqual(search.x);
      }
      await page.keyboard.press('Tab'); await brand.focus();
      await expect(brand).toHaveCSS('background-color', 'rgb(243, 244, 246)');
      await expect(brand).toHaveCSS('color', 'rgb(24, 26, 29)');
    }
    await expect(header.locator('a[href="#/search"]')).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBeTruthy();
    await page.screenshot({ path: testInfo.outputPath('header.png') });
  });
  test('artwork selection stays visible at carousel edges', async ({ page }, testInfo) => {
    const card = page.locator('.homePage .NextUp .card').first();
    await card.waitFor(); await card.scrollIntoViewIfNeeded();
    const artwork = card.locator('.cardScalable'), before = await artwork.boundingBox();
    const pointer = await page.evaluate(() => matchMedia('(hover: hover) and (pointer: fine)').matches);
    if (pointer) {
      await card.hover();
      await expectArtworkRing(page, artwork, testInfo, 'live-hover');
      expect(await artwork.boundingBox()).toEqual(before);
    }
    await page.mouse.move(0, 0); await page.keyboard.press('Tab');
    await card.locator('.cardImageContainer').focus();
    await expectArtworkRing(page, artwork, testInfo, 'live-keyboard');
    const after = await artwork.boundingBox();
    expect(after.width).toBe(before.width); expect(after.height).toBe(before.height);
    const action = card.locator('.cardOverlayButton').last();
    await action.focus(); await expect(action).toHaveCSS('outline-style', 'solid');
    await action.click({ trial: true });
    await page.screenshot({ path: testInfo.outputPath('selection.png') });
  });
  test('series details and metadata/image menus remain available', async ({ page }, testInfo) => {
    const link = page.locator('.homePage .card[data-type="Series"] a.textActionButton').first();
    await link.scrollIntoViewIfNeeded(); const href = await link.getAttribute('href');
    await page.goto(server.replace(/\/$/, '') + '/web/' + href);
    const more = page.locator('.detailPagePrimaryContainer .btnMoreCommands, .detailPagePrimaryContainer .btnMore, .detailPage .btnMoreCommands').first();
    await more.waitFor(); await expect(more).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBeTruthy();
    await more.click();
    await expect(page.getByText('Identify', { exact: true }).last()).toBeVisible();
    await expect(page.getByText('Edit images', { exact: true }).last()).toBeVisible();
    await page.getByText('Edit metadata', { exact: true }).last().click();
    const dialog = page.locator('[role="dialog"],.dialog').filter({ has: page.getByText('Edit metadata', { exact: true }) }).last();
    await expect(dialog).toBeVisible();
    await expect(page.locator('.dialog input').first()).toBeVisible();
    await page.screenshot({ path: testInfo.outputPath('metadata-dialog.png') });
    // Close without saving any metadata.
    await page.keyboard.press('Escape');
  });
  test('library artwork is borderless and watch progress matches the TV cards', async ({ page }, testInfo) => {
    const library = page.locator('.homePage .MyMedia .cardImageContainer.coveredImage').first();
    await expect(library).toHaveCSS('border-top-width', '0px');
    await expect(library).toHaveCSS('border-top-left-radius', '12px');
    await expect(library).toHaveCSS('background-clip', 'padding-box');
    await expect(library).toHaveCSS('background-size', '108% auto');
    await page.keyboard.press('Tab'); await library.focus();
    await expectArtworkRing(page, library.locator('..'), testInfo, 'library-focus');
    await page.screenshot({ path: testInfo.outputPath('library-frames.png') });

    const card = page.locator('.homePage .ContinueWatching .card:has(.itemProgressBarForeground)').first();
    const fill = card.locator('.itemProgressBarForeground');
    await fill.scrollIntoViewIfNeeded();
    const track = fill.locator('..');
    const artwork = card.locator('.cardImageContainer');
    await expect(fill).toHaveCSS('background-color', 'rgb(106, 214, 202)');
    await expect(track).toHaveCSS('background-color', 'rgba(106, 214, 202, 0.2)');
    const image = await artwork.boundingBox(), bar = await track.boundingBox();
    expect(bar.height).toBe(6);
    expect(bar.x - image.x).toBeCloseTo(5, 1);
    expect(image.x + image.width - bar.x - bar.width).toBeCloseTo(5, 1);
    expect(image.y + image.height - bar.y - bar.height).toBeCloseTo(5, 1);
    const percentage = await fill.evaluate(element => parseFloat(element.style.width));
    expect((await fill.boundingBox()).width / bar.width).toBeCloseTo(percentage / 100, 2);
    if (await page.evaluate(() => matchMedia('(hover: hover) and (pointer: fine)').matches)) {
      await card.hover();
      await expect(card.locator('.cardOverlayContainer')).toHaveCSS('background-image', 'none');
    }
    await page.screenshot({ path: testInfo.outputPath('watch-progress.png') });
  });
  test('library navigation and the admin dashboard remain reachable', async ({ page }) => {
    const movies = page.locator('header a[href*="/movies?"]').first();
    if (await movies.isVisible()) await movies.click();
    else await page.goto(server.replace(/\/$/, '') + '/web/#/dashboard');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBeTruthy();
    await page.goto(server.replace(/\/$/, '') + '/web/#/dashboard');
    await expect(page.locator('main').getByText('Server version', { exact: true }).filter({ visible: true })).toBeVisible();
  });
  test('movie toolbar separates actions and reflects active filters and menus', async ({ page }, testInfo) => {
    const movieLink = page.locator('header a[href*="/movies?"]').first();
    const library = page.locator('.homePage .MyMedia .card').filter({ hasText: /^Movies$/ }).first();
    await library.waitFor();
    const href = await movieLink.count() ? await movieLink.getAttribute('href') : '#/movies?topParentId=' + await library.getAttribute('data-id');
    await page.goto(server.replace(/\/$/, '') + '/web/' + href);
    const toolbar = page.locator('.MuiToolbar-root').filter({ has: page.locator('button[title="Filter"]') });
    await expect(toolbar).toBeVisible();
    const buttons = toolbar.locator('.MuiButtonGroup-grouped').filter({ visible: true });
    expect(await buttons.count()).toBeGreaterThanOrEqual(3);
    const boxes = [];
    for (const button of await buttons.all()) {
      const box = await button.boundingBox(); boxes.push(box);
      expect(box.width).toBeGreaterThanOrEqual(44); expect(box.height).toBeGreaterThanOrEqual(44);
      for (const side of ['top', 'right', 'bottom', 'left']) await expect(button).toHaveCSS(`border-${side}-width`, '0px');
      await expect(button).toHaveCSS('border-top-left-radius', '999px');
      await expect(button).toHaveCSS('border-top-right-radius', '999px');
    }
    for (let i = 1; i < boxes.length; i++) expect(boxes[i].x - boxes[i-1].x - boxes[i-1].width).toBeGreaterThanOrEqual(6);
    const filter = toolbar.locator('button[title="Filter"]');
    await page.mouse.move(0, 0);
    await expect(filter).toHaveCSS('background-color', 'rgba(0, 0, 0, 0)');
    await page.keyboard.press('Tab'); await filter.focus();
    await expect(filter).toHaveCSS('background-color', 'rgb(243, 244, 246)');
    await expect(filter).toHaveCSS('color', 'rgb(24, 26, 29)');
    await filter.click();
    const popover = page.locator('#filter-popover');
    await expect(popover).toBeVisible();
    await expect(filter).toHaveCSS('background-color', 'rgb(243, 244, 246)');
    await popover.getByRole('button', { name: 'Filters', exact: true }).click();
    const unplayed = popover.getByRole('checkbox', { name: 'Unplayed', exact: true });
    await expect(unplayed).toBeVisible();
    const initial = await unplayed.isChecked();
    const dismiss = async () => { await popover.locator('.MuiBackdrop-root').click({ position: { x: 2, y: 2 } }); await expect(popover).toBeHidden(); };
    try {
      // Jellyfin updates these values through router state, after the click returns.
      await unplayed.click(); await expect(unplayed).toBeChecked();
      await dismiss(); await page.mouse.move(0, 0);
      await expect(filter).toHaveCSS('background-color', 'rgb(243, 244, 246)');
      await expect(filter).toHaveCSS('color', 'rgb(24, 26, 29)');
      await page.screenshot({ path: testInfo.outputPath('movies-active-filter.png') });
    } finally {
      if (!await popover.isVisible()) await filter.click();
      if (await unplayed.isChecked() !== initial) { await unplayed.click(); await expect(unplayed).toBeChecked({ checked: initial }); }
      await dismiss();
    }
    await page.mouse.move(0, 0); await filter.blur();
    await expect(filter).toHaveCSS('background-color', 'rgba(0, 0, 0, 0)');
    const section = toolbar.getByRole('button', { name: 'Movies', exact: true });
    await section.click();
    const selected = page.getByRole('menuitem', { name: 'Movies', exact: true });
    await expect(selected).toBeVisible();
    await expect(selected).toHaveCSS('background-color', 'rgb(243, 244, 246)');
    await expect(selected).toHaveCSS('color', 'rgb(24, 26, 29)');
    await expect(selected).toHaveCSS('border-radius', '999px');
    await page.keyboard.press('Escape');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBeTruthy();
  });
});
