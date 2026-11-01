/**
 * PageResult —— 分页返回体（嵌在 Result.data 里）
 * 对应后端 common/PageResult.java：{ total, pageNum, pageSize, list }
 */
export class PageResult<T> {
  /** 总条数 */
  total: number = 0;
  /** 当前页码，从 1 开始 */
  pageNum: number = 1;
  /** 每页条数 */
  pageSize: number = 10;
  /** 当前页数据 */
  list: T[] = [];

  /** 是否还有下一页（列表触底加载用） */
  hasMore(): boolean {
    return this.pageNum * this.pageSize < this.total;
  }
}
