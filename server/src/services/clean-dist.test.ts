import { expect, it } from 'vitest';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';

it('cleans only its fixed output directory in a disposable build copy', () => {
  const root = mkdtempSync(join(tmpdir(), 'litchi-clean-build-'));
  try {
    mkdirSync(join(root, 'scripts'));
    mkdirSync(join(root, 'dist'));
    writeFileSync(join(root, 'dist', 'retired-route.js'), 'obsolete');
    writeFileSync(join(root, 'keep.txt'), 'keep');
    copyFileSync(new URL('../../scripts/clean-dist.mjs', import.meta.url), join(root, 'scripts', 'clean-dist.mjs'));
    execFileSync(process.execPath, [join(root, 'scripts', 'clean-dist.mjs')], { cwd: tmpdir(), timeout: 5000 });
    expect(existsSync(join(root, 'dist'))).toBe(false);
    expect(existsSync(join(root, 'keep.txt'))).toBe(true);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
