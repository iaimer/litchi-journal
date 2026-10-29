import { afterAll, beforeEach, expect, it, vi } from 'vitest';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
vi.mock('node:fs', async original => {
 const fs = await original<typeof import('node:fs')>();
 return {...fs, writeFileSync:vi.fn(fs.writeFileSync), fsyncSync:vi.fn(fs.fsyncSync), renameSync:vi.fn(fs.renameSync)};
});
import * as fs from 'node:fs';
import { writeAtomicFile } from './atomic-file.js';
const root=mkdtempSync(join(tmpdir(),'litchi-atomic-'));
const path=join(root,'config.json');
beforeEach(() => {vi.clearAllMocks(); writeFileSync(path,'old');});
afterAll(() => rmSync(root,{recursive:true,force:true}));
it.each(['write','sync','rename'])('preserves old bytes and cleans temporary on %s failure', stage => {
 const fail = () => {throw new Error('injected failure');};
 if(stage==='write') vi.mocked(fs.writeFileSync).mockImplementationOnce(fail);
 if(stage==='sync') vi.mocked(fs.fsyncSync).mockImplementationOnce(fail);
 if(stage==='rename') vi.mocked(fs.renameSync).mockImplementationOnce(fail);
 expect(() => writeAtomicFile(path,'new')).toThrow('injected failure');
 expect(readFileSync(path,'utf8')).toBe('old');
 expect(readdirSync(root)).toEqual(['config.json']);
});
it('does not report failure after committed replacement when directory sync fails', () => {
 const sync=fs.fsyncSync;
 vi.mocked(sync).mockImplementationOnce(() => {}).mockImplementationOnce(() => {throw new Error('directory sync');});
 expect(() => writeAtomicFile(path,'new')).not.toThrow();
 expect(readFileSync(path,'utf8')).toBe('new');
});
