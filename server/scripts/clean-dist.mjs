import { rmSync } from 'node:fs';

// 仅清理本服务的编译输出，避免已删除源码的产物残留。
rmSync(new URL('../dist/', import.meta.url), { recursive: true, force: true });
