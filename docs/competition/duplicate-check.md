# MoonEDN 选题与查重记录

日期：2026-11-09。比赛使用 builder 固定九月规则；实际执行 osc2026-guide Project Research Guide 的 moon search → MoonCakes 详情 → GitHub 源码/测试流程。原始命令输出保存在本地独立 research-20261109 证据目录，不随包发布。

## 需求与候选比较

需求依据是成熟跨生态方案和规范，并非声称采访过用户或参赛者有相关经历。评分依次为广度、需求、复用、低重合风险、深度、验证、可完成性、维护性（1–5）；硬失败优先。

|领域/候选|依据及完整任务|评分|门禁|
|---|---|---|---|
|编译优化/e-graph|egg：表达式与等式→等价类饱和→提取低成本表达式|5/5/5/1/5/5/4/4|bobzhang/egg 与 CAIMEOX/moon_egg 直接重合，淘汰|
|关系查询/Datalog|Soufflé：事实和递归规则→不动点连接→派生关系|5/5/5/1/5/5/4/4|haol-05/moondatalog 直接重合，淘汰|
|编辑器底层/rope|Ropey：Unicode 文本与编辑→树更新及索引→新文档|5/5/5/1/4/5/5/4|Teddy-Yangjiale/rope、text_document 直接相邻，淘汰|
|数据交换/EDN|edn-format/edn：扩展值与文本流→有界解析、无损变换→EDN/类型化 JSON|5/4/5/4/4/5/5/4|通过记录范围内检查，最高通过候选|

## 检索范围与限制

所有 moon search 使用 --limit 100：egraph/e-graph/equality/saturation/rewrite/optimizer/egg；datalog/souffle/logic/relational/inference；rope/text buffer/piece table/text editor/crdt/persistent；EDN 使用 edn/clojure/extensible data notation/parse_edn/read_edn/clojure data/cirru/tagged literal/serialization/notation。广义查询遇到 100 条上限，不能据此推断全站不存在。另有 preliminary exploration 淘汰 SSA、register allocation、Jsonnet、DBF 等已有直接方案，未当作可交付候选。

GitHub search/repositories 和 search/code 均 per_page=100；精确 EDN/clojure/规范词/read_edn/parse_edn/TaggedLiteral/EdnValue/edn-format 及 README 反查已留存。仓库 edn 只有 Cirru；宽泛 EDN code 返回 1728、只审查第一页100条，非穷尽检索。精确行为与规范检索为0不构成独占证明。公开 MoonCakes 文档、awesome-moonbit 尝试的状态保留在证据，未以访问失败当作无结果。

永久注册表完整载入后按能力筛选，读取匹配指纹：MoonDocopt（help grammar）、MoonFluent（FTL AST）、MoonOT（optimal transport，非文本 OT）、MoonEarley（token CFG森林）、MoonWeave（纺织），以及已有 egraph/Datalog 外部记录。MoonBench/MoonContract/MoonRecur/MoonShard 永久保留，与本题核心无重合。未使用或改名旧项目。

## 相邻能力矩阵

|项目与检查证据|输入/模型/核心输出|分类与处理|
|---|---|---|
|[tiye/cirru-edn@0.2.3](https://mooncakes.io/docs/tiye/cirru-edn)，[源码](https://github.com/Cirru/cirru-edn.mbt) dbbb6fa87450d2e06479f0bdf757a3a3e5adb965；README、src/edn.mbt、lib.mbt、edn_test.mbt|Cirru 语法树→Calcit Edn；Number(Double)、Tuple、Record、Atom；Cirru formatter|高度相邻数据交换。不是 edn-format 标准括号语法；无列表/向量区分、字符、精确数值/普通 tagged pair。沿用会改变其现有语法与公共类型。独立标准实现优于破坏这些契约；未复制代码|
|[bobzhang/egg](https://github.com/bobzhang/egg)，egraph.mbt、rewrite_test.mbt|union/find、rebuild congruence、规则饱和、提取|直接成熟替代，放弃优化器方向|
|[haol-05/moondatalog](https://github.com/haol-05/moondatalog)，engine.mbt、engine_test.mbt|关系规则、不动点执行、分层否定|直接替代，放弃查询方向|
|[Teddy-Yangjiale/Rope-Moonbit](https://github.com/Teddy-Yangjiale/Rope-Moonbit)，src/rope.mbt、rope_test.mbt|Unicode 树索引、插入删除、切片、行访问|直接替代，放弃文本缓冲方向|

查看邻居源码/测试不等于执行它们的测试，也不把下载量当成熟性的唯一证明。原始元数据记录版本、维护时间和树 SHA。

## 三个交付工作流与客观标准

1. 应用/构建配置：EDN 配置→有界读取与类型化 path 查询/事务编辑→确定性 EDN；验证类型保留、失败不修改输入。
2. 跨语言数据管线：EDN 多值流→逐值读取/标签保留/精确整数十进制→可逆 tagged JSON；与 edn_format 0.7.5 的独立值语义对照。
3. 开发者工具：含复杂键/集合的数据→诊断、排版、遍历统计→可读文件与确定性报告；验证 map/set 次序无关、list/vector 序列相等、边界错误和资源限制。

最小完整核心：EDN 值模型、解析器、打印器、结构工具、可逆 JSON 及三个可运行集成。明确不做 Clojure 求值/宏、数据库客户端、网络传输、Cirru 或通用 schema。不是以行数或提交数代替功能价值。只有已记录范围内未发现成熟的标准 EDN 直接替代；不声称全球唯一或官方通过。发布前再次反查。

## 发布前复核（2026-11-09）

以 `moon search` 对 edn、clojure、data notation 各取最多 100 项，并对 GitHub 仓库检索 `edn language:MoonBit`、`"EDN" "MoonBit"` 与 `"tagged JSON" language:MoonBit`，复核结果仍以 Cirru/cirru-edn.mbt 为最接近项目，其语法与值契约差异如上。检索项可能命中 README 或描述中的无关用语，已经逐项按主要能力判断。复核是有界公开查询，不能证明未索引、私有或未来项目不存在。
