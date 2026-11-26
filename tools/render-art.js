// Renders tools/cassette-art.html into the asset catalog.
// Run from the repository root:  node tools/render-art.js
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const root = path.resolve(__dirname, '..');
  const page = 'file://' + path.join(root, 'tools/cassette-art.html');
  const out = path.join(root, 'TapeDeck/Assets.xcassets');
  const browser = await chromium.launch();
  for (const [layer, w, h, file] of [
    ['front', 1500, 945, 'CassetteFront.imageset/cassette-front.png'],
    ['hub', 480, 480, 'ReelHub.imageset/reel-hub.png'],
  ]) {
    const tab = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    await tab.goto(page + '?layer=' + layer);
    await tab.screenshot({ path: path.join(out, file), omitBackground: true });
    await tab.close();
  }
  await browser.close();
})();
