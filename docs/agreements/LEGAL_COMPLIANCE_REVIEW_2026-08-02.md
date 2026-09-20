# Master Dance 合同法律与产品合规核对

**核对日期：** 2026 年 8 月 2 日
**对象：** `MASTER_DANCE_STUDENT_AGREEMENT_MD-2026.08-LR1`
**结论级别：** 内部风险核对，不是加州执业律师法律意见

## 一句话结论

新合同已经修正目前能明确识别的主要冲突，但**现在仍不能作为正式合同上线或签署**。最关键的发布阻断是：尚未确认并证明 Master Dance 是否已完成 California Dance Studio Surety Bond；同时 App 还必须实现逐课价格确认、可下载合同副本、非电子签署选择、独立隐私政策，以及与 24 小时请假规则一致的数据逻辑。

## 1. 发布阻断项

### 1.1 舞蹈教室保证金尚未核实

California Civil Code § 1812.64 原则上要求舞蹈教室维持保证金，金额为上一财年加州舞蹈业务收入的 25%，且不得低于 25,000 美元，并向 Secretary of State 备案。§ 1812.67(a) 对每名学员未来服务预收少于 50 美元且每 30 日不超过一次的工作室提供狭窄豁免；Master Dance 的整学期预收模式看来很可能不符合该豁免。

§ 1812.67(b) 的另一豁免只适用于仅教授 ballet、modern、jazz、tap 给 21 岁以下学员，同时总价低于 500 美元且全部课程在四个月内提供等特定条件。Master Dance 有中国舞、成人课程及超过该限额的学期安排，从现有事实看也不宜依赖该豁免。

项目与 Dropbox 中没有找到已备案保证金证明。正式版不能虚写“已保税/已担保”。负责人应让加州执业律师或保险经纪确认适用性；如适用，办理并保存 SFSB-406、SFSB-406D 和备案凭证。California Secretary of State 当前确实列有这两份 Dance Studio 表格。[加州舞蹈教室合同法规](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?article=&chapter=&division=3.&lawCode=CIV&part=4.&title=2.4.)、[Secretary of State 保证金表格](https://www.sos.ca.gov/business-programs/special-filings/forms)

### 1.2 每次报名必须形成具体书面课程合同

§§ 1812.52 与 1812.54 要求书面合同、签署时交付副本，并在签署前逐项写明不同课程的小时单价；不能只在第一次注册时签一份没有课程和价格的通用协议。

App 需要在每次新报名、续报或换课前生成“课程报名确认单”，至少包含实际课次、每次时长、每次单价、折算小时单价、总价、预计开课日期、注册费和其他服务。购买方确认后，该版本与通用协议共同构成课程合同。[California Civil Code §§ 1812.52–1812.54](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?article=&chapter=&division=3.&lawCode=CIV&part=4.&title=2.4.)

### 1.3 App 必须提供可保留副本和非电子路径

California UETA 规定双方必须同意使用电子方式，且电子记录不能阻止收件人保存或打印。联邦 E-SIGN 还要求预先说明纸质选择、撤回同意、适用记录范围、联系方式更新、纸质副本费用和软硬件要求。

因此 App 不能只让家长在一个临时页面滚动后签字。签署后应立即允许下载 PDF、保存到“文件”或发送邮箱；同时必须提供联系教务改用纸质方式的路径。[California Civil Code § 1633.5](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1633.5)、[California Civil Code § 1633.8](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1633.8)、[15 U.S.C. § 7001](https://uscode.house.gov/view.xhtml?req=%28title%3A15+section%3A7001%28c%29+edition%3Aprelim%29)

### 1.4 独立隐私政策尚未完成

CalOPPA 要求收集加州消费者个人信息的商业在线服务醒目提供隐私政策，并披露资料类别、共享对象、更正流程、政策变更方式、生效日期和跟踪事项。合同中的隐私段落不能替代完整隐私政策。[California Business and Professions Code § 22575](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=22575)

家长端只允许成年人登录，是降低 COPPA 风险的正确方向，但系统实际存有儿童姓名、生日、照片、成长记录和签到资料。应明确禁止儿童直接注册、限制第三方 SDK、禁止儿童数据用于定向广告，并对不满 13 岁儿童资料的收集路径进行专门审查。FTC 2025 年最终规则还加强了第三方披露同意和数据保留限制。[FTC COPPA 2025 最终规则说明](https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-finalizes-changes-childrens-privacy-rule-limiting-companies-ability-monetize-kids-data)、[FTC COPPA FAQ](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions)

## 2. 已在本合同中修正的冲突

| 原做法或旧文字 | 风险 | 本稿处理 |
| --- | --- | --- |
| 原则上不退款 | 与随时书面取消、按比例退款、10 日内退款及不得收取消费冲突 | 明确保留法定退款；补课、顺延和余额只能由购买方自愿选择 |
| 学期末所有课时一律清零 | 可能错误消灭法定退款或学校未履行服务的权利 | 只让普通补课资格失效，并明确法定权利优先 |
| 避免写极端情形 | § 1812.57 强制要求身故或残障条款 | 使用尊重的“身故或残障”措辞，完整保留退款权 |
| 3.5% 同时用于信用卡和借记卡 | 易违反卡组织规则或构成误导 | 仅限合格信用卡，提前显示，不超过实际允许成本或网络上限；借记/预付卡不收 |
| “最终解释权归佳美舞蹈所有” | 单方改写合同、限制消费者权利的风险很高 | 删除；改为善意解释且法律优先 |
| 广泛全部免责 | California Civil Code § 1668 及判例不允许免除欺诈、违法、故意行为和重大过失 | 仅限清楚说明的普通疏忽与活动风险，明确列出不可免责事项 |
| 媒体授权与注册捆绑 | 同意不够自由，儿童隐私风险高 | 公开宣传授权独立、可拒绝、不得预选 |
| App 直接弹合同并签名 | 电子同意与副本交付不完整 | 增加独立电子记录说明、纸质选择和副本要求 |

法定取消、退款、小时单价、身故或残障、保证金和合同无效后果均来自 California Civil Code §§ 1812.50–1812.69；不合规合同可能无效，受害购买方还可能主张三倍实际损害及律师费。[加州舞蹈教室合同法规](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?article=&chapter=&division=3.&lawCode=CIV&part=4.&title=2.4.)

责任豁免方面，California Civil Code § 1668 禁止通过合同免除欺诈、故意伤害或违法责任；娱乐活动中的普通疏忽豁免必须清楚明确，且不能覆盖重大过失。[California Civil Code § 1668](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1668.)、[California Supreme Court: City of Santa Barbara v. Superior Court](https://www.courts.ca.gov/opinions/revpub/B176810.PDF)

信用卡附加费还应遵守支付机构合同。California Attorney General 说明：若消费者可以用其他方式避免费用，信用卡手续费通常不属于强制隐藏费用，但价格不得误导；Mastercard 还要求附加费不超过商户实际信用卡受理成本和适用上限，并在交易与收据中披露。[California AG 隐藏费用说明](https://oag.ca.gov/hiddenfees)、[California AG 信用卡附加费说明](https://oag.ca.gov/consumers/general/credit-card-surcharges)、[Mastercard 商户附加费规则](https://www.mastercard.us/en-us/business/overview/support/merchant-surcharge-rules.html)

## 3. App 与数据库必须同步修正

1. **请假时限：** 当前政策来源采用至少提前 24 小时；现有 App/Supabase 仍有 12 小时限制。发布合同前必须统一为 24 小时，并保留教务可事后录入的权限。
2. **合同副本：** iOS “合同与收据”中提供已签合同正文、签名、版本、时间与可下载 PDF；同时可发送至帐号邮箱。
3. **逐课确认：** 每次 enrollment 前生成课程确认版本，不允许只靠总协议。
4. **取消入口：** iOS 与 macOS 都要保存取消请求的内容和时间戳；教务必须能导出。
5. **合同版本：** 旧签名、旧正文和正文校验值不可覆盖；实质更新只影响未来交易并触发重新签署。
6. **媒体同意：** 与必签合同分开保存，默认不同意，允许面向未来撤回。
7. **监控：** 仅在公共或教学区域使用视频并设置告示；洗手间、更衣和其他隐私空间禁止摄像。涉及机密谈话的音频录制需要各方同意。[California Penal Code § 632](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=PEN&sectionNum=632)
8. **广告与儿童数据：** 首页商业广告不得基于儿童档案、课程、生日、照片或行为做个性化定向。

## 4. 需要负责人最终确认的业务值

以下不阻止本次起草，但律师终审前应转为明确内部政策：

- 8 月 1 日至次年 7 月 31 日是否就是注册年度的永久定义。
- 注册费所含舞蹈服的对象、每年件数、尺寸与补发规则。
- 不足 24 小时但开课前请假的补课审批标准。
- 重大疾病证明的最少资料、顺延期限与最多顺延次数。
- “已经报满适龄全部课程”的判断方式和每学期最多 3 次顺延的操作流程。
- 成人组课的按期/按次价差；成人私课的改期窗口。
- 每门课的真实小时单价、其他商品与服务定价。

## 5. 最终判断

**合同文字本身：** 已经避免目前看得到的明显法律冲突，并且比旧制度更接近可执行的加州舞蹈教室合同结构。

**当前整体状态：** 尚未达到“可以直接发布”的程度。保证金是硬阻断；逐课确认、电子副本和隐私政策是产品阻断；24 小时规则同步是数据一致性阻断。

**建议发布顺序：** 先由加州执业律师确认保证金与责任豁免，再办理或核实保证金；随后完成隐私政策及 App 流程；用一门真实课程生成完整课程确认单做端到端测试；最后把版本从 `LR1` 改为正式签署版本并发布。未经这一步，不应把本稿上传为家长必须签署的正式协议。
