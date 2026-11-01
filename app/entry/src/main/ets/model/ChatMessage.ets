/**
 * ChatCardCell —— 结构化卡片里的一格「标签 + 值」
 *
 * label 存的是**英文码值**（time / place / count / hours / reward / expect），
 * 中文由页面用 `$r` 映射 —— 与工程里「状态码走英文、文案走 resources」的约定一致，
 * 也让 D 阶段后端返回同样的码值时前端零改动。
 */
export class ChatCardCell {
  label: string = '';
  value: string = '';

  static fromJson(json: ChatCardCell): ChatCardCell {
    const item: ChatCardCell = new ChatCardCell();
    item.label = json.label ?? '';
    item.value = json.value ?? '';
    return item;
  }

  static fromJsonList(list: ChatCardCell[]): ChatCardCell[] {
    const out: ChatCardCell[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(ChatCardCell.fromJson(list[i]));
    }
    return out;
  }
}

/**
 * ChatCardRow —— 结构化卡片里的一行。
 * 一行可放 1~2 格：设计稿里「时间 / 地点」各占一行，「人数 10 人　时长 2h」是一行两格，
 * 所以行与格必须分开建模，不能拍平成「字段数组」。
 */
export class ChatCardRow {
  cells: ChatCardCell[] = [];

  static fromJson(json: ChatCardRow): ChatCardRow {
    const item: ChatCardRow = new ChatCardRow();
    item.cells = ChatCardCell.fromJsonList(json.cells);
    return item;
  }

  static fromJsonList(list: ChatCardRow[]): ChatCardRow[] {
    const out: ChatCardRow[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(ChatCardRow.fromJson(list[i]));
    }
    return out;
  }
}

/**
 * ChatCard —— 智能体回复里的「结构化卡片」
 *
 * 这是「任务型智能体」与聊天机器人的分水岭：
 *   小鸿不只是回一句话，而是回一张能点、能回填表单的卡片。
 *   草稿卡 → 一键填入发布表单；推荐卡 → 点进活动/求助详情。
 */
export class ChatCard {
  /** ChatCardType 的码值：activity / help / text */
  cardType: string = '';
  /** 目标对象 id。草稿卡为 0，推荐卡为真实 id */
  targetId: number = 0;
  title: string = '';
  subtitle: string = '';
  /** 右上角角标文案，如「草稿」「推荐 · 匹配度 92%」 */
  tag: string = '';
  /** 是否是可回填表单的草稿（草稿卡才渲染「去修改 / 一键发布」两个按钮） */
  isDraft: boolean = false;
  /** 草稿卡的结构化字段（推荐卡为空） */
  rows: ChatCardRow[] = [];

  static fromJson(json: ChatCard): ChatCard {
    const item: ChatCard = new ChatCard();
    item.cardType = json.cardType ?? '';
    item.targetId = json.targetId ?? 0;
    item.title = json.title ?? '';
    item.subtitle = json.subtitle ?? '';
    item.tag = json.tag ?? '';
    item.isDraft = json.isDraft ?? false;
    item.rows = ChatCardRow.fromJsonList(json.rows);
    return item;
  }

  static fromJsonList(list: ChatCard[]): ChatCard[] {
    const out: ChatCard[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(ChatCard.fromJson(list[i]));
    }
    return out;
  }
}

/**
 * ChatMessage —— 智能体会话消息（对应表 chat_message）
 * role: 'user' = 我说的（橙底右对齐）/ 'assistant' = 小鸿说的（白底左对齐）
 */
export class ChatMessage {
  id: number = 0;
  sessionId: string = '';
  userId: number = 0;
  /** 'user' | 'assistant' */
  role: string = '';
  content: string = '';
  /** 该轮触发的工具名，如 'create_activity_draft'（仅供测试/调试显示为「已调用：xxx」） */
  toolName: string = '';
  createTime: string = '';

  /** 前端态：小鸿正在思考（显示「小鸿正在思考…」气泡） */
  loading: boolean = false;
  /** 结构化卡片 */
  cards: ChatCard[] = [];

  static fromJson(json: ChatMessage): ChatMessage {
    const item: ChatMessage = new ChatMessage();
    item.id = json.id ?? 0;
    item.sessionId = json.sessionId ?? '';
    item.userId = json.userId ?? 0;
    item.role = json.role ?? '';
    item.content = json.content ?? '';
    item.toolName = json.toolName ?? '';
    item.createTime = json.createTime ?? '';
    item.loading = json.loading ?? false;
    item.cards = ChatCard.fromJsonList(json.cards);
    return item;
  }

  static fromJsonList(list: ChatMessage[]): ChatMessage[] {
    const out: ChatMessage[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(ChatMessage.fromJson(list[i]));
    }
    return out;
  }

  /** 本地造一条用户消息（发消息时立即上屏） */
  static localUserMessage(content: string): ChatMessage {
    const item: ChatMessage = new ChatMessage();
    item.role = 'user';
    item.content = content;
    return item;
  }

  /** 本地造一条「思考中」占位（请求返回前显示） */
  static localLoadingMessage(): ChatMessage {
    const item: ChatMessage = new ChatMessage();
    item.role = 'assistant';
    item.content = '';
    item.loading = true;
    return item;
  }

  /**
   * 本地造一条小鸿回复。
   * 只给 Mock 阶段用 —— 真实回复是从 `/api/chat` 的 JSON 经 `fromJson` 得到的，
   * 两条路径产出的都是同一个 `ChatMessage`，所以页面代码不用区分。
   */
  static localAssistantMessage(content: string, cards: ChatCard[]): ChatMessage {
    const item: ChatMessage = new ChatMessage();
    item.role = 'assistant';
    item.content = content;
    item.cards = cards;
    return item;
  }

  isUser(): boolean {
    return this.role === 'user';
  }
}
