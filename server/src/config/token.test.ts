import { expect, it } from 'vitest';
import { validateApiToken } from './token.js';
it.each([undefined,null,42,'','   ','REPLACE_WITH_A_RANDOM_TOKEN',' REPLACE_WITH_A_RANDOM_TOKEN ','x'.repeat(31)])('rejects invalid token without exposing it', value => {
 expect(() => validateApiToken(value)).toThrow('API Token 至少需要32个字符，且不能使用示例占位符');
});
it('normalizes surrounding whitespace on a valid token', () => {
 expect(validateApiToken('  '+'x'.repeat(32)+'  ')).toBe('x'.repeat(32));
});
