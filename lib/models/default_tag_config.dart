import 'tag_config.dart';

/// Flutter 端内置标签配置。
///
/// 与服务端默认标签表保持一致，用于远程标签配置暂不可用时的只读兜底。
class DefaultTagConfig {
  DefaultTagConfig._();

  static const value = TagConfig(
    domains: [
      TagDomain(
        id: 'parenting-interact',
        name: '亲子',
        description: '共同经历和关系互动',
        order: 0,
        topics: [
          TagTopic(
            id: 'parenting-interact-play',
            name: '陪伴互动',
            description: '一起活动、游戏和日常共处',
            order: 0,
          ),
          TagTopic(
            id: 'parenting-interact-talk',
            name: '亲子沟通',
            description: '双方交流、商量和对话',
            order: 1,
          ),
          TagTopic(
            id: 'parenting-interact-bond',
            name: '关系连接',
            description: '亲密感、冲突与修复',
            order: 2,
          ),
        ],
      ),
      TagDomain(
        id: 'parenting-care',
        name: '育儿',
        description: '照护、教育和成长判断',
        order: 1,
        topics: [
          TagTopic(
            id: 'parenting-care-education',
            name: '教育引导',
            description: '学习习惯、规则与价值观培养',
            order: 0,
          ),
          TagTopic(
            id: 'parenting-care-health',
            name: '健康照护',
            description: '疾病、饮食、睡眠、就医和身体照护',
            order: 1,
          ),
          TagTopic(
            id: 'parenting-care-emotion',
            name: '情绪管理',
            description: '情绪识别和调节',
            order: 2,
          ),
          TagTopic(
            id: 'parenting-care-expression',
            name: '表达能力',
            description: '说话、沟通能力和语言发展',
            order: 3,
          ),
          TagTopic(
            id: 'parenting-care-growth',
            name: '成长观察',
            description: '阶段变化、新技能出现',
            order: 4,
          ),
          TagTopic(
            id: 'parenting-care-explore',
            name: '自主探索',
            description: '自信、独立和主动探索',
            order: 5,
          ),
        ],
      ),
      TagDomain(
        id: 'work',
        name: '工作',
        description: '职业任务和职场活动',
        order: 2,
        topics: [
          TagTopic(
            id: 'work-task',
            name: '任务执行',
            description: '具体任务完成',
            order: 0,
          ),
          TagTopic(
            id: 'work-collab',
            name: '沟通协作',
            description: '团队沟通与协作',
            order: 1,
          ),
          TagTopic(
            id: 'work-problem',
            name: '问题解决',
            description: '工作中遇到的问题和解决方案',
            order: 2,
          ),
          TagTopic(
            id: 'work-decision',
            name: '决策能力',
            description: '工作中的决策过程',
            order: 3,
          ),
          TagTopic(
            id: 'work-efficiency',
            name: '效率管理',
            description: '工作效率提升和管理',
            order: 4,
          ),
          TagTopic(
            id: 'work-study',
            name: '专业学习',
            description: '标准方法、行业文献、职业培训',
            order: 5,
          ),
        ],
      ),
      TagDomain(
        id: 'study',
        name: '学习',
        description: '掌握知识或练习技能',
        order: 3,
        topics: [
          TagTopic(
            id: 'study-understand',
            name: '理解能力',
            description: '对新知识的理解和掌握',
            order: 0,
          ),
          TagTopic(
            id: 'study-memory',
            name: '记忆能力',
            description: '记忆和复习',
            order: 1,
          ),
          TagTopic(
            id: 'study-focus',
            name: '专注力',
            description: '专注和学习状态',
            order: 2,
          ),
          TagTopic(
            id: 'study-transfer',
            name: '学习迁移',
            description: '知识应用和举一反三',
            order: 3,
          ),
        ],
      ),
      TagDomain(
        id: 'reading',
        name: '阅读',
        description: '书籍、文章阅读和观点思考',
        order: 4,
        topics: [
          TagTopic(
            id: 'reading-extract',
            name: '信息提取',
            description: '从阅读中提取关键信息',
            order: 0,
          ),
          TagTopic(
            id: 'reading-depth',
            name: '理解深度',
            description: '对内容的深入理解',
            order: 1,
          ),
          TagTopic(
            id: 'reading-critique',
            name: '批判思维',
            description: '批判性思考和分析',
            order: 2,
          ),
        ],
      ),
      TagDomain(
        id: 'tech',
        name: '技术',
        description: '开发、配置、系统研究和调试',
        order: 5,
        topics: [
          TagTopic(
            id: 'tech-system',
            name: '系统理解',
            description: '对技术系统的理解',
            order: 0,
          ),
          TagTopic(
            id: 'tech-debug',
            name: '调试能力',
            description: '调试和排错',
            order: 1,
          ),
          TagTopic(
            id: 'tech-arch',
            name: '架构理解',
            description: '架构设计理解',
            order: 2,
          ),
          TagTopic(
            id: 'tech-impl',
            name: '实现能力',
            description: '技术实现和编码',
            order: 3,
          ),
        ],
      ),
      TagDomain(
        id: 'life',
        name: '生活',
        description: '个人生活日常',
        order: 6,
        topics: [
          TagTopic(
            id: 'life-health',
            name: '健康管理',
            description: '运动、饮食、作息等健康管理',
            order: 0,
          ),
          TagTopic(
            id: 'life-finance',
            name: '财务管理',
            description: '收入和支出管理',
            order: 1,
          ),
          TagTopic(
            id: 'life-organize',
            name: '生活整理',
            description: '生活事务整理和规划',
            order: 2,
          ),
          TagTopic(
            id: 'life-interest',
            name: '兴趣探索',
            description: '非商品爱好、活动和创作',
            order: 3,
          ),
          TagTopic(
            id: 'life-consume',
            name: '消费选择',
            description: '商品发现、比较、体验和购买',
            order: 4,
          ),
          TagTopic(
            id: 'life-feeling',
            name: '情绪感受',
            description: '私人心情和情绪',
            order: 5,
          ),
          TagTopic(
            id: 'life-relation',
            name: '人际关系',
            description: '非亲子、非工作的关系互动',
            order: 6,
          ),
          TagTopic(
            id: 'life-daily',
            name: '日常记录',
            description: '没有明确场景的日常记录',
            order: 7,
          ),
        ],
      ),
    ],
    methods: [
      TagMethod(
        id: 'reflect',
        name: '反思',
        description: '对自身行为和思考的回顾',
        order: 0,
      ),
      TagMethod(
        id: 'methodology',
        name: '方法论',
        description: '系统化的方法和流程',
        order: 1,
      ),
      TagMethod(
        id: 'problem-analysis',
        name: '问题分析',
        description: '分析问题原因和解决方案',
        order: 2,
      ),
      TagMethod(id: 'remember', name: '回忆', description: '对过去经历的回忆', order: 3),
    ],
  );
}
