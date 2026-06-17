import { Router } from 'express';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import config from '../config/index.js';

const router = Router();

const TAG_FILE = join(config.vaultPath, '.litchi-journal', 'tag-system.json');
const TEMPLATE_DIR = join(config.vaultPath, '_Templates');
const TEMPLATE_FILE = join(TEMPLATE_DIR, '标签规范.md');
const GENERATED_START = '<!-- litchi-journal-tag-config:start -->';
const GENERATED_END = '<!-- litchi-journal-tag-config:end -->';

const DEFAULT_TAG_CONFIG = {
  domains: [
    { id: 'parenting-interact', name: '亲子', description: '共同经历和关系互动', order: 0, topics: [
      { id: 'parenting-interact-play', name: '陪伴互动', description: '一起活动、游戏和日常共处', order: 0 },
      { id: 'parenting-interact-talk', name: '亲子沟通', description: '双方交流、商量和对话', order: 1 },
      { id: 'parenting-interact-bond', name: '关系连接', description: '亲密感、冲突与修复', order: 2 },
    ]},
    { id: 'parenting-care', name: '育儿', description: '照护、教育和成长判断', order: 1, topics: [
      { id: 'parenting-care-education', name: '教育引导', description: '学习习惯、规则与价值观培养', order: 0 },
      { id: 'parenting-care-health', name: '健康照护', description: '疾病、饮食、睡眠、就医和身体照护', order: 1 },
      { id: 'parenting-care-emotion', name: '情绪管理', description: '情绪识别和调节', order: 2 },
      { id: 'parenting-care-expression', name: '表达能力', description: '说话、沟通能力和语言发展', order: 3 },
      { id: 'parenting-care-growth', name: '成长观察', description: '阶段变化、新技能出现', order: 4 },
      { id: 'parenting-care-explore', name: '自主探索', description: '自信、独立和主动探索', order: 5 },
    ]},
    { id: 'work', name: '工作', description: '职业任务和职场活动', order: 2, topics: [
      { id: 'work-task', name: '任务执行', description: '具体任务完成', order: 0 },
      { id: 'work-collab', name: '沟通协作', description: '团队沟通与协作', order: 1 },
      { id: 'work-problem', name: '问题解决', description: '工作中遇到的问题和解决方案', order: 2 },
      { id: 'work-decision', name: '决策能力', description: '工作中的决策过程', order: 3 },
      { id: 'work-efficiency', name: '效率管理', description: '工作效率提升和管理', order: 4 },
      { id: 'work-study', name: '专业学习', description: '标准方法、行业文献、职业培训', order: 5 },
    ]},
    { id: 'study', name: '学习', description: '掌握知识或练习技能', order: 3, topics: [
      { id: 'study-understand', name: '理解能力', description: '对新知识的理解和掌握', order: 0 },
      { id: 'study-memory', name: '记忆能力', description: '记忆和复习', order: 1 },
      { id: 'study-focus', name: '专注力', description: '专注和学习状态', order: 2 },
      { id: 'study-transfer', name: '学习迁移', description: '知识应用和举一反三', order: 3 },
    ]},
    { id: 'reading', name: '阅读', description: '书籍、文章阅读和观点思考', order: 4, topics: [
      { id: 'reading-extract', name: '信息提取', description: '从阅读中提取关键信息', order: 0 },
      { id: 'reading-depth', name: '理解深度', description: '对内容的深入理解', order: 1 },
      { id: 'reading-critique', name: '批判思维', description: '批判性思考和分析', order: 2 },
    ]},
    { id: 'tech', name: '技术', description: '开发、配置、系统研究和调试', order: 5, topics: [
      { id: 'tech-system', name: '系统理解', description: '对技术系统的理解', order: 0 },
      { id: 'tech-debug', name: '调试能力', description: '调试和排错', order: 1 },
      { id: 'tech-arch', name: '架构理解', description: '架构设计理解', order: 2 },
      { id: 'tech-impl', name: '实现能力', description: '技术实现和编码', order: 3 },
    ]},
    { id: 'life', name: '生活', description: '个人生活日常', order: 6, topics: [
      { id: 'life-health', name: '健康管理', description: '运动、饮食、作息等健康管理', order: 0 },
      { id: 'life-finance', name: '财务管理', description: '收入和支出管理', order: 1 },
      { id: 'life-organize', name: '生活整理', description: '生活事务整理和规划', order: 2 },
      { id: 'life-interest', name: '兴趣探索', description: '非商品爱好、活动和创作', order: 3 },
      { id: 'life-consume', name: '消费选择', description: '商品发现、比较、体验和购买', order: 4 },
      { id: 'life-feeling', name: '情绪感受', description: '私人心情和情绪', order: 5 },
      { id: 'life-relation', name: '人际关系', description: '非亲子、非工作的关系互动', order: 6 },
      { id: 'life-daily', name: '日常记录', description: '没有明确场景的日常记录', order: 7 },
    ]},
  ],
  methods: [
    { id: 'reflect', name: '反思', description: '对自身行为和思考的回顾', order: 0 },
    { id: 'methodology', name: '方法论', description: '系统化的方法和流程', order: 1 },
    { id: 'problem-analysis', name: '问题分析', description: '分析问题原因和解决方案', order: 2 },
    { id: 'remember', name: '回忆', description: '对过去经历的回忆', order: 3 },
  ],
};

function ensureDir(path: string) {
  const dir = dirname(path);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
}

function loadTagConfig(): unknown {
  if (!existsSync(TAG_FILE)) return null;
  return JSON.parse(readFileSync(TAG_FILE, 'utf-8'));
}

function generateTemplate(config: {
  domains: Array<{ name: string; description?: string; topics: Array<{ name: string; description?: string }> }>;
  methods: Array<{ name: string; description?: string }>;
}): string {
  const lines: string[] = [
    GENERATED_START,
    '## 当前标签配置',
    '',
    '由 Litchi Journal 标签管理系统自动生成。此区块之外的人工规范会被保留。',
    '',
    '输出必须包含：润色正文 + 1个领域标签 + 1个对应主题标签 + 0-1个方法标签。',
    '',
    '### 领域与主题',
    '',
  ];

  for (const domain of config.domains) {
    lines.push(`- **#${domain.name}**${domain.description ? `：${domain.description}` : ''}`);
    for (const topic of domain.topics) {
      lines.push(`  - #${topic.name}${topic.description ? `：${topic.description}` : ''}`);
    }
    lines.push('');
  }

  lines.push('### 方法');
  lines.push('');
  for (const method of config.methods) {
    lines.push(`- **#${method.name}**${method.description ? `：${method.description}` : ''}`);
  }
  lines.push('');

  lines.push('## 判定顺序');
  lines.push('');
  lines.push('1. 先判断记录所属的人生场景，再选择主题。动作词不能反过来决定领域。');
  lines.push('2. 只从当前标签表中选择，不创建新标签。');
  lines.push('3. 领域优先看人生场景，主题必须从所选领域下面选择。');
  lines.push('4. 如果多个领域都可能成立，优先选择最能解释记录重要性的场景。');
  lines.push('5. 方法标签只在内容明显包含对应处理方式时添加。');
  lines.push('6. 缺少明确场景证据时，选择说明最接近日常、生活或兜底含义的领域和主题。');
  lines.push('');
  lines.push(GENERATED_END);

  return lines.join('\n');
}

function updateTemplateFile(generated: string) {
  ensureDir(TEMPLATE_FILE);
  if (!existsSync(TEMPLATE_FILE)) {
    writeFileSync(TEMPLATE_FILE, `# 标签规范\n\n${generated}\n`, 'utf-8');
    return;
  }

  const existing = readFileSync(TEMPLATE_FILE, 'utf-8');
  const start = existing.indexOf(GENERATED_START);
  const end = existing.indexOf(GENERATED_END);
  if (start >= 0 && end > start) {
    const before = existing.slice(0, start).trimEnd();
    const after = existing.slice(end + GENERATED_END.length).trimStart();
    writeFileSync(TEMPLATE_FILE, `${before}\n\n${generated}\n\n${after}`.trimEnd() + '\n', 'utf-8');
    return;
  }

  writeFileSync(TEMPLATE_FILE, `${existing.trimEnd()}\n\n${generated}\n`, 'utf-8');
}

function validateConfig(config: { domains: unknown; methods: unknown }): string | null {
  if (!Array.isArray(config.domains)) return 'domains 必须是数组';
  if (!Array.isArray(config.methods)) return 'methods 必须是数组';
  if (config.domains.length === 0) return '至少保留 1 个领域';
  if (config.domains.reduce((s: number, d: { topics?: unknown }) => s + (Array.isArray(d.topics) ? d.topics.length : 0), 0) === 0) {
    return '至少保留 1 个主题';
  }

  const seen = new Set<string>();
  const validateName = (name: unknown, label: string): string | null => {
    if (!name || typeof name !== 'string' || !name.trim()) return `${label}名称为空`;
    const normalized = name.trim();
    if (normalized.startsWith('#')) return `${label}「${normalized}」不能以 # 开头`;
    if (seen.has(normalized)) return `标签「${normalized}」重复`;
    seen.add(normalized);
    return null;
  };

  for (const domain of config.domains) {
    const domainNameError = validateName(domain.name, '领域');
    if (domainNameError) return domainNameError;
    if (!Array.isArray(domain.topics)) return `领域 ${domain.name} 的 topics 不是数组`;
    if (domain.topics.length === 0) return `领域 ${domain.name} 至少保留 1 个主题`;
    for (const topic of domain.topics) {
      const topicNameError = validateName(topic.name, '主题');
      if (topicNameError) return topicNameError;
    }
  }
  for (const method of config.methods) {
    const methodNameError = validateName(method.name, '方法');
    if (methodNameError) return methodNameError;
  }
  return null;
}

router.get('/tags', async (_req, res) => {
  try {
    const existing = loadTagConfig();
    if (existing) return res.json(existing);
    ensureDir(TAG_FILE);
    writeFileSync(TAG_FILE, JSON.stringify(DEFAULT_TAG_CONFIG, null, 2), 'utf-8');
    res.json(DEFAULT_TAG_CONFIG);
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.put('/tags', async (req, res) => {
  try {
    const config = req.body;
    const validationError = validateConfig(config);
    if (validationError) return res.status(400).json({ error: validationError });

    ensureDir(TAG_FILE);
    writeFileSync(TAG_FILE, JSON.stringify(config, null, 2), 'utf-8');

    const template = generateTemplate(config);
    updateTemplateFile(template);

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

export default router;
