import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  // Jellyfin 12.2's slider/OSD markup and native positioning rules. No playback
  // requests are needed to check caption contrast and inline sprite offsets.
  await page.addStyleTag({ content: `
    .sliderBubble{align-items:center;background:#282828;color:#fff;display:flex;justify-content:center;position:absolute;transform:translate(-50%,-120%);z-index:1}
    .sliderBubbleText{margin:0;padding:.5em .75em}
    .chapterThumbContainer{position:relative;flex-grow:1}
    .chapterThumb{height:20vh;min-width:20vh}
    .chapterThumbTextContainer{position:absolute;bottom:0;left:0;right:0;padding:.25em .5em}
    .chapterThumbText{color:#fff;margin:0;padding:.25em 0;white-space:nowrap}
  ` });
  await page.evaluate(() => {
    document.querySelector('main').innerHTML = `<section class="videoOsdBottom" style="height:420px;position:relative">
      <div class="sliderBubble" style="left:50%;top:360px"><h1 class="sliderBubbleText">12:34</h1></div>
    </section>`;
  });
});

test('timestamp-only seek bubbles remain readable in every colour mode', async ({ page }) => {
  const bubble = page.locator('.sliderBubble');
  for (const mode of ['dark', 'blueradiance', 'purplehaze']) {
    await page.evaluate(mode => document.documentElement.dataset.theme = mode, mode);
    await expect(bubble).toHaveCSS('background-color', 'rgb(24, 26, 29)');
    await expect(bubble.locator('.sliderBubbleText')).toHaveCSS('color', 'rgb(255, 255, 255)');
    const box = await bubble.boundingBox();
    expect(box.width).toBeLessThan(140);
    expect(box.x).toBeGreaterThanOrEqual(0);
    expect(box.x + box.width).toBeLessThanOrEqual(await page.evaluate(() => innerWidth));
  }
});

test('larger seek previews preserve image proportions and sprite tile positions', async ({ page }, testInfo) => {
  const bubble = page.locator('.sliderBubble');
  await bubble.evaluate(element => {
    // Two distinct tiles make an incorrect crop/scale visible in rendered pixels.
    const canvas = document.createElement('canvas'); canvas.width = 640; canvas.height = 180;
    const context = canvas.getContext('2d');
    context.fillStyle = '#207040'; context.fillRect(0, 0, 320, 180);
    context.fillStyle = '#3050a0'; context.fillRect(320, 0, 320, 180);
    element.innerHTML = `<div class="chapterThumbContainer" style="overflow:hidden">
      <div class="chapterThumbWrapper" style="overflow:hidden;width:320px;height:180px;background-position:0px 0px"></div>
      <div class="chapterThumbTextContainer"><h2 class="chapterThumbText">12:34</h2></div></div>`;
    element.querySelector('.chapterThumbWrapper').style.backgroundImage = `url(${canvas.toDataURL()})`;
  });
  const sprite = bubble.locator('.chapterThumbWrapper');
  const box = await sprite.boundingBox();
  const width = await page.evaluate(() => innerWidth);
  expect(box.width).toBeCloseTo(width >= 800 ? 400 : 320);
  expect(box.width / box.height).toBeCloseTo(16 / 9);
  expect(box.x).toBeGreaterThanOrEqual(0);
  expect(box.x + box.width).toBeLessThanOrEqual(width);
  for (const [offset, colour] of [[0, [32, 112, 64]], [-320, [48, 80, 160]]]) {
    await sprite.evaluate((element, offset) => element.style.backgroundPositionX = `${offset}px`, offset);
    const screenshot = await bubble.screenshot({ scale: 'css' });
    const pixel = await page.evaluate(async base64 => {
      const image = new Image(); image.src = `data:image/png;base64,${base64}`; await image.decode();
      const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
      return [...context.getImageData(image.width / 2, image.height / 4, 1, 1).data].slice(0, 3);
    }, screenshot.toString('base64'));
    expect(pixel).toEqual(colour);
    await testInfo.attach(`seek-tile-${offset}`, { body: screenshot, contentType: 'image/png' });
  }
  await bubble.evaluate(element => element.innerHTML = '<div class="chapterThumbContainer"><img class="chapterThumb" src="/art/chalk-up.png"><div class="chapterThumbTextContainer"><h2 class="chapterThumbText">12:34</h2></div></div>');
  const image = bubble.locator('img');
  await image.evaluate(element => element.decode());
  const dimensions = await image.evaluate(element => ({ width: element.clientWidth, height: element.clientHeight, ratio: element.naturalWidth / element.naturalHeight }));
  expect(dimensions.width / dimensions.height).toBeCloseTo(dimensions.ratio, 1);
  expect(dimensions.width).toBeGreaterThanOrEqual(280);
  expect(dimensions.width).toBeLessThanOrEqual(width - 48);
});
