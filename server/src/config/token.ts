/** 配置校验不回显输入，避免启动错误泄漏凭据。 */
export function validateApiToken(value: unknown): string {
  const token = typeof value === 'string' ? value.trim() : '';
  if (token.length < 32 || token === 'REPLACE_WITH_A_RANDOM_TOKEN' || /\s/.test(token)) {
    throw new Error('API Token 至少需要32个字符，且不能使用示例占位符');
  }
  return token;
}
