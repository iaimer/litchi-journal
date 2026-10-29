import { afterAll, beforeEach, expect, it, vi } from 'vitest';
import { mkdirSync, rmSync, symlinkSync, readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { execFileSync } from 'node:child_process';
const fixture = await vi.hoisted(async () => {
  const {mkdtempSync} = await import('node:fs');
  const {tmpdir} = await import('node:os');
  const {join} = await import('node:path');
  return {root:mkdtempSync(join(tmpdir(),'litchi-safe-read-'))};
});
vi.mock('../config/index.js', () => ({default:{vaultPath:fixture.root}}));
vi.mock('fs', async original => ({...await original<typeof import('fs')>(),readFileSync:vi.fn()}));
import {DiaryNotFoundError, getDiaryPath, readDiary} from './vault.js';
const date = new Date('2024-08-12T12:00:00+08:00');
const path = getDiaryPath(date);
beforeEach(async () => {
  vi.mocked(readFileSync).mockImplementation((await vi.importActual<typeof import('fs')>('fs')).readFileSync);
  rmSync(path,{force:true,recursive:true});
  mkdirSync(dirname(path),{recursive:true});
});
afterAll(() => rmSync(fixture.root,{recursive:true,force:true}));
it('reads normal content and distinguishes absence', () => {
  expect(() => readDiary(date)).toThrow(DiaryNotFoundError);
  writeFileSync(path,'完整日记'); expect(readDiary(date)).toBe('完整日记');
});
it.each(['EACCES','EIO'])('preserves %s', code => {
  writeFileSync(path,'完整日记');
  const error=Object.assign(new Error('read failed'),{code});
  vi.mocked(readFileSync).mockImplementation(() => {throw error;});
  expect(() => readDiary(date)).toThrow(error);
});
it('rejects an external link, a broken link, a directory and a FIFO', () => {
  symlinkSync('/etc/hosts',path); expect(() => readDiary(date)).toThrow(); rmSync(path);
  symlinkSync(join(fixture.root,'missing'),path); expect(() => readDiary(date)).toThrow('日记路径不可用'); rmSync(path);
  mkdirSync(path); expect(() => readDiary(date)).toThrow(); rmSync(path,{recursive:true});
  execFileSync('mkfifo',[path]); expect(() => readDiary(date)).toThrow('日记路径不安全');
});

it('rejects missing diary under an external parent link instead of returning 404', () => {
 const parent=dirname(path); rmSync(parent,{recursive:true,force:true});
 symlinkSync('/etc',parent);
 try {expect(() => readDiary(date)).toThrow('日记目录不安全');}
 finally {rmSync(parent);}
});

it('rejects a broken Vault root link', () => {
 rmSync(fixture.root,{recursive:true,force:true});
 symlinkSync(fixture.root+'-missing',fixture.root);
 try {expect(() => readDiary(date)).toThrow('日记根目录不可用');}
 finally {rmSync(fixture.root); mkdirSync(fixture.root);}
});
