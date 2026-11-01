/**
 * EntryFormAbility —— 桌面卡片 FormExtensionAbility（Form Kit）
 *
 * 职责：卡片被添加 / 定时刷新时，把 FormStore 里的快照推给卡片。
 * 不发网络请求（卡片进程没有登录态），数据新鲜度由主进程负责 ——
 * 每次首页拉取 home-summary 成功都会覆盖写快照（见 HomeService.fetch）。
 *
 * 刷新时机：
 *   · 添加到桌面（onAddForm）—— 先回默认数据让卡片立即可见，再异步刷快照
 *   · 定时刷新（updateDuration = 1 → 每 30 分钟，见 form_config.json）
 *   · scheduledUpdateTime 每日 07:30 补一次早间刷新
 */
import { Want } from '@kit.AbilityKit';
import { formBindingData, formInfo, formProvider, FormExtensionAbility } from '@kit.FormKit';
import { FormStore, FormSnapshot } from '../common/FormStore';

export default class EntryFormAbility extends FormExtensionAbility {
  /** 添加卡片：返回默认数据占位，快照异步跟上 */
  onAddForm(want: Want): formBindingData.FormBindingData {
    let formId: string = '';
    if (want.parameters) {
      formId = want.parameters[formInfo.FormParam.IDENTITY_KEY] as string;
    }
    this.refresh(formId);
    return formBindingData.createFormBindingData(FormSnapshot.empty());
  }

  /** 定时刷新回调 */
  onUpdateForm(formId: string): void {
    this.refresh(formId);
  }

  /** 读快照 → updateForm（失败静默：卡片保持上一次内容） */
  private async refresh(formId: string): Promise<void> {
    if (formId === '') {
      return;
    }
    try {
      const snap: FormSnapshot = await FormStore.load(this.context);
      const data: formBindingData.FormBindingData = formBindingData.createFormBindingData(snap);
      await formProvider.updateForm(formId, data);
    } catch (err) {
      // 刷不动就保持现状
    }
  }
}
