import { ChatCard } from './ChatMessage';

/**
 * AgentReply —— 小鸿的「一句回复模板」（U 阶段 Mock 专用）
 *
 * 为什么要有这个类：小鸿是**任务型**智能体，回复不是一段固定文案，
 * 而是「一句话 + 0~N 张结构化卡片」。把「触发词 / 文案 / 卡片」打包成一条模板，
 * 匹配逻辑（`matches`）就能和业务解耦 —— D 阶段整张表换成 `/api/chat` 的返回即可。
 *
 * 【匹配口径】
 *   keywords 是**逗号分隔**的词表，用户那句话里命中任意一个词就算命中（`indexOf`）。
 *   刻意不做分词、不做打分：Mock 阶段只要「看起来像懂了」，
 *   真智能体在 D 阶段接大模型，这层匹配会整体删掉，不值得为它写复杂算法。
 */
export class AgentReply {
  /** 触发词，如 '活动,发起,发布,策划'；留空 = 兜底模板（永远匹配） */
  keywords: string = '';
  /** 小鸿说的话 */
  content: string = '';
  /** 随话带出的卡片（草稿卡 / 推荐卡） */
  cards: ChatCard[] = [];

  static fromJson(json: AgentReply): AgentReply {
    const item: AgentReply = new AgentReply();
    item.keywords = json.keywords ?? '';
    item.content = json.content ?? '';
    item.cards = ChatCard.fromJsonList(json.cards);
    return item;
  }

  static fromJsonList(list: AgentReply[]): AgentReply[] {
    const out: AgentReply[] = [];
    if (!list) {
      return out;
    }
    for (let i = 0; i < list.length; i++) {
      out.push(AgentReply.fromJson(list[i]));
    }
    return out;
  }

  /** 兜底模板（keywords 为空）永远匹配；否则要求词表里至少命中一个 */
  matches(text: string): boolean {
    if (this.keywords === '') {
      return true;
    }
    const words: string[] = this.keywords.split(',');
    for (let i = 0; i < words.length; i++) {
      const w: string = words[i];
      if (w !== '' && text.indexOf(w) >= 0) {
        return true;
      }
    }
    return false;
  }
}
