// 使用 NODE_PATH 指向包含 sharp 的现有工具环境，无需增加 App 依赖。
const sharp = require('sharp');
const fs = require('node:fs/promises');
const master = 'docs/design-reference/brand-c-master.png';

async function cleanExteriorShadow() {
  const { data: pixels, info } = await sharp(master).ensureAlpha().raw()
    .toBuffer({ resolveWithObject: true });
  const cleaned = Buffer.from(pixels);
  // 保留实体轮廓周围 2px 抗锯齿，清除更远的低透明阴影斑点。
  for (let y = 0; y < info.height; y++) {
    for (let x = 0; x < info.width; x++) {
      const offset = (y * info.width + x) * 4;
      if (pixels[offset + 3] === 0 || pixels[offset + 3] >= 128) continue;
      if (nearSolidPixel(pixels, info, x, y)) continue;
      cleaned.fill(0, offset, offset + 4);
    }
  }
  const encoded = await sharp(cleaned, { raw: info }).png().toBuffer();
  await fs.writeFile(master, encoded);
}

function nearSolidPixel(pixels, info, x, y) {
  for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) {
      if (dx * dx + dy * dy > 4) continue;
      const px = x + dx, py = y + dy;
      if (px < 0 || py < 0 || px >= info.width || py >= info.height) continue;
      if (pixels[(py * info.width + px) * 4 + 3] >= 128) return true;
    }
  }
  return false;
}

async function square(size, artworkWidth, transparent = false) {
  const artwork = await sharp(master).resize({ width: artworkWidth }).png().toBuffer();
  return sharp({ create: { width: size, height: size, channels: 4,
    background: transparent ? '#00000000' : '#FAFAFA' } })
    .composite([{ input: artwork, gravity: 'centre' }]);
}

async function derive() {
  await cleanExteriorShadow();
  for (const target of ['assets/icon/app-icon.png', 'assets/icon/brand-splash-reference.png',
    'assets/icon/brand-splash-dark.png', 'docs/design-reference/splash.png']) {
    await fs.copyFile(master, target);
  }
  await (await square(1024, 850)).removeAlpha().png().toFile('docs/design-reference/icon.png');
  await fs.copyFile('docs/design-reference/icon.png', 'assets/icon/app-launcher.png');
  const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
  for (const [density, scale] of Object.entries(densities)) {
    const dir = `android/app/src/main/res/mipmap-${density}`;
    await (await square(Math.round(48 * scale), Math.round(40 * scale)))
      .removeAlpha().png().toFile(`${dir}/ic_launcher.png`);
    for (const name of ['ic_launcher_foreground', 'ic_launcher_foreground_bitmap']) {
      await (await square(Math.round(108 * scale), Math.round(54 * scale), true))
        .png().toFile(`${dir}/${name}.png`);
    }
  }
}
derive().catch(error => { console.error(error); process.exitCode = 1; });
