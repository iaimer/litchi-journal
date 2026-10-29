import { randomUUID } from 'node:crypto';
import { closeSync, existsSync, fsyncSync, mkdirSync, openSync, renameSync, statSync, unlinkSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

/** 替换前失败保留旧文件，替换后的目录同步不改变已提交结果。 */
export function writeAtomicFile(path: string, content: string): void {
  const directory = dirname(path);
  mkdirSync(directory, { recursive: true });
  const temporary = `${path}.${randomUUID()}.tmp`;
  let descriptor: number | undefined;
  try {
    descriptor = openSync(temporary, 'wx', existsSync(path) ? statSync(path).mode & 0o777 : 0o600);
    writeFileSync(descriptor, content, 'utf8');
    fsyncSync(descriptor);
    closeSync(descriptor);
    descriptor = undefined;
    renameSync(temporary, path);
  } finally {
    try {
      if (descriptor !== undefined) closeSync(descriptor);
    } finally {
      if (existsSync(temporary)) unlinkSync(temporary);
    }
  }
  try {
    const fd = openSync(directory, 'r');
    try { fsyncSync(fd); } finally { closeSync(fd); }
  } catch {
    // 文件已提交；部分文件系统不支持目录同步。
  }
}
