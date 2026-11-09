# MoonEDN

MoonEDN 是一个用 MoonBit 实现的 EDN 值读写与结构工具库，用于配置文件、Clojure/Datomic 系统之间的数据交换，以及编辑器和开发工具中的格式化、查询与修改。

模块：`jqlssg/moonedn@0.1.0`。核心不依赖第三方包，不访问文件、网络或环境变量。格式依据是 [edn-format/edn](https://github.com/edn-format/edn)，实际兼容边界见下文；它不执行 Clojure 代码。

## 用户与完整工作流

| 使用者 | 输入与处理 | 输出与可运行入口 |
| --- | --- | --- |
| 应用和配置工具开发者 | 读取嵌套配置，通过类型化路径检查旧值，再事务修改端口和功能列表 | 新配置及保持原样的输入，`examples/config` |
| 数据交换服务开发者 | 读取包含大整数、精确十进制和复杂键的 EDN，编码为 tagged JSON，再解码 | 保留 EDN 类型与数字精度的数据，`examples/interchange` |
| 编辑器、构建和日志工具开发者 | 逐个读取事件，解析应用 tag，统计和格式化；对错误输入生成行列诊断 | 格式化内容、结构统计与诊断，`examples/tooling` |

## 安装与环境

要求 `moonc >= 0.10.16`。本版固定验证工具链为 `moonc v0.10.16+b1a0e846e`、`moon 0.1.20261016`。四种目标为 `wasm-gc`、`wasm`、`js` 和 `native`；JS 运行需要 Node.js，native 需要 C 编译器。默认目标是 wasm-gc。CI 在 Linux 上分别检查、构建、测试和运行三个示例。

在已有 MoonBit 工程的 `moon.mod` 中加入精确依赖：

```moonbit
import {
  "jqlssg/moonedn@0.1.0",
}
```

然后执行 `moon update`。消费包的 `moon.pkg`：

```moonbit
import {
  "jqlssg/moonedn" @edn,
}

pkgtype(kind: "executable")
```

`main.mbt`：

```moonbit
fn main raise {
  let config = @edn.read("{:host \"localhost\" :port 8080}")
  let next = @edn.transact(config, [
    @edn.Replace([@edn.Key(@edn.Keyword("port"))], @edn.Integer("9090")),
  ])
  println(@edn.write(next))
}
```

运行 `moon run .`，输出：

```text
{:host "localhost" :port 9090}
```

## 从源码运行

```sh
git clone https://github.com/jqlssg/moonedn.git
cd moonedn
moon check --deny-warn
moon build --deny-warn
moon test --deny-warn
moon run examples/config --deny-warn
moon run examples/interchange --deny-warn
moon run examples/tooling --deny-warn
```

换目标时添加 `--target wasm`、`--target js` 或 `--target native`。三个示例的输入均为自有内存数据，含结果断言，无外部服务依赖。

## 核心 API

| 入口 | 行为 |
| --- | --- |
| `read` / `read_all` | 恰好一个值 / 多个顶层值；空输入在前者报错 |
| `Reader::new` / `read_next` | 源字符串上的逐值读取；`None` 表示结束，EDN nil 是 `Some(Nil)` |
| `Reader::next_token` | 带起止位置的低层词法接口，供编辑器使用；同一 reader 不混用 token 与 value 读取 |
| `write` / `pretty` | 紧凑输出 / 可配置宽度和缩进的格式化 |
| `equivalent` | 数字类别精度敏感，序列按元素比较，map/set 忽略次序 |
| `to_tagged_json` / `from_tagged_json` | 保留所有 EDN 类型、任意 map 键和数字字面量的 JSON DOM 传输 |
| `to_plain_json` / `from_plain_json` | 明确受限的普通 JSON 投影，拒绝不能安全表示的类型 |
| `lookup` / `require_at` / `contains_path` | 类型化路径查询；结果数组脱离输入 |
| `transact` | 带前置条件的替换、map 赋值、序列插入和删除；失败不产生部分修改 |
| `transform` / `resolve_tag` | 对脱离输入的树做后序变换 / 在解析后显式处理应用 tag |
| `clone_value` / `validate_value` | 复制及校验手工构造值，包括重复键、有限浮点与循环深度 |
| `inspect_value` / `diagnose` | 结构统计 / 可供编辑器消费的定位诊断 |

所有公开签名和类型见 [pkg.generated.mbti](pkg.generated.mbti)。所有操作通过 `EdnError` 的 `Syntax(offset,message)`、`Limit(message)`、`Invalid(message)`、`PathError(message)` 报错；这些都是可捕获错误。

### 值模型和精度

`Value` 显式区分 nil、布尔、整数、大整数、浮点、精确十进制、字符串、字符、符号、关键字、list、vector、map、set 和 tagged value。整数、大整数、十进制存为字符串，避免 JS/Double 中间舍入。

- `Integer("1")` 是有符号 64 位整数；`BigInteger("1")` 对应 `1N`；`Decimal("1.00")` 对应 `1.00M`。手工构造整数必须是规范化十进制数字，不能放 `+1` 或 `01`。
- `1`、`1N`、`1.0`、`1M` 属于不同类型/精度，不互作相同键。`1.0M` 与 `1.00M` 数值相等，十进制比较不展开巨大指数。
- list/vector 类型在读写中保留，但按 EDN 序列规则可以等价。map 的键可以是任意值，包括序列和 map。
- 数组公开可变，不提供持久不可变对象。查询、事务和变换的返回值在数组层级脱离输入；调用期间不要并发修改输入。手工构造的循环值会因深度预算被拒绝。

### 格式化和确定性

```moonbit
let ordered = @edn.write(@edn.read("{:b 2 :a 1}"), canonical=true)
// {:a 1 :b 2}
let formatted = @edn.pretty(value, layout={width: 40, indent: 2})
```

默认 writer 保持 map/set 的存储次序，`canonical=true` 按序列化文本排序。它用于确定性展示，不是跨实现、跨数字写法的规范哈希：`1.0M` 和 `1.00M` 仍保留各自字面量。pretty 的宽度是软上限，长字符串不会拆开；注释、原始空白不保留。

### JSON 互通

Tagged JSON v1 采用 `[kind,payload]`，nil 为 `["nil"]`，tagged 为 `["tagged",name,child]`。所有数字载荷用字符串；map 载荷是键值对数组，list/vector 有不同 kind。该格式是本库定义的传输格式，不能当作普通 JSON 的领域模型。

```moonbit
let value = @edn.read("{:amount 12.3400M :id 12345678901234567890N}")
let transport = @edn.to_tagged_json(value)
let restored = @edn.from_tagged_json(transport)
```

普通 JSON 仅支持 nil、布尔、字符串、有限浮点、安全整数、list/vector 和字符串键 map；list/vector 投影为数组，导入为 vector。所有数字的绝对值限制在 `9007199254740991` 内，JSON DOM 按 binary64 解释。默认拒绝关键词键，只有 `keyword_keys=true` 才投影为无冒号字符串，并检查与已有字符串键碰撞。字符、符号、set、tag、大整数和精确十进制直接报错，不静默转字符串。要完整保真请使用 tagged JSON。

### 类型化路径和事务

路径由 `Index(Int)`、`Key(Value)`、`TaggedValue` 构成，支持复杂 map 键，无字符串路径转义歧义。`lookup` 找不到键/索引返回 `None`，路径类型不适用则报 `PathError`。

```moonbit
let port = @edn.require_at(config, [@edn.Key(@edn.Keyword("port"))])
let next = @edn.transact(config, [
  @edn.Check([@edn.Key(@edn.Keyword("port"))], @edn.Integer("8080")),
  @edn.Replace([@edn.Key(@edn.Keyword("port"))], @edn.Integer("9090")),
  @edn.Put([], @edn.Keyword("enabled"), @edn.Bool(true)),
])
```

`Replace` 要求目标存在；`Put` 对 map 新增或更新键；`Insert` 允许在序列末尾插入；`Remove` 要求键/索引存在且不能删除根或单独删除 tag 的载荷。所有编辑按顺序作用于一个副本，最后重新校验约束；任意步骤失败均不修改调用者输入。

## 资源和安全边界

默认 `Limits`：输入/累计文本/输出上限 1,000,000 个 UTF-16 单元，最大深度 128（根为 0），工作预算 100,000，单 token 65,536，单容器 10,000。深度可配置范围为 1..256。token 读取按 Unicode scalar 计数；手工值的文本校验按 UTF-16 单元计数。

`nodes` 同时约束解析节点、discard 和去重比较等工作量，不仅是最终树大小。任意类型键的比较/去重采用有工作预算的线性或二次扫描；大集合可能先耗尽工作预算。高层操作中的输入验证、变换和输出验证分别有同一组预算，不是跨阶段的单个总计数。所有限制是操作/文档级，不是进程内存配额。

`Reader` 拥有完整源字符串，逐个产出值，并不实现文件/网络分块流。多次 `read_next` 共用文档工作预算，读取错误后 reader 失效，须重新创建。位置、列和 token span 是 Unicode scalar 索引，不是 UTF-8 字节或 UTF-16 偏移；行列从 1 开始，CRLF 算一次换行。

解析不调用应用 tag handler，不求值；`#_` 中也不执行回调。`resolve_tag` 是解析后的显式操作。库限制自己的遍历，不能限制任意调用者回调的运行时间或分配。

## 兼容范围与非目标

支持 EDN 基础值、注释、逗号空白、discard、未知 tag 的结构保存，以及字符串 Unicode 转义和代理对。`#uuid` 校验 36 字符形式并按小写规范值比较。`#inst` 使用完整 RFC3339 日期时间，支持精确任意长度小数秒和时区归一化；年份范围 0001..9999，拒绝闰秒和未知偏移 `-00:00`，不支持日期缩写。它不会把不同时间瞬间仅按字符串比较。

非 ASCII 名称采用非空白、非控制的宽松字符策略，未实现 Unicode 字母类别表；tag 首字符在 ASCII 范围必须为字母，非 ASCII 范围排除数字。它不是符号的 Unicode 类别规范校验器。浮点数按 binary64 舍入，拒绝非有限值，可能发生下溢；不支持 NaN/Infinity 数值扩展。

不支持 Clojure 宏、求值、ratio、十六进制/基数整数、namespaced maps、自动解析关键词、regex、quote、对象身份/引用、schema、格式注释保留或领域 tag 的自动含义。未知 tag 使用结构等价，领域等价需应用先显式规范化。

## 测试与复现

```sh
moon info
moon fmt
moon fmt --check
moon check --deny-warn
moon build --deny-warn
moon test --deny-warn
```

测试包含标准合法/畸形输入、Unicode、精度与时区、复杂键/重复元素、reader 失败状态、全部资源预算、JSON 碰撞、脱离输入的事务/变换，以及三个真实工作流。另有 200 个由独立 `edn_format 0.7.5` 得出的比较样本和 2,000 组生成树往返；这不代表已经证明所有 EDN 实现行为相同。

独立参考样本由自有生成器产生，不复制上游测试：

```sh
python -m pip install -r tools/requirements-oracle.txt
python tools/generate_differential.py --check
```

生成器需要固定工具链的 `moon` 在 PATH 中；不传 `--check` 会重新生成测试文件。核心测试不需要 Python。CI 用四目标矩阵执行检查、构建、测试和全部示例，并在 wasm-gc job 中重新核对独立样本。

## 源码结构与来源

`number.mbt`/`symbol.mbt` 处理标量；`reader.mbt`/`lexer.mbt`/`parser.mbt` 读取；`equivalence.mbt`/`validation.mbt` 管理语义约束；`writer.mbt`/`pretty.mbt` 输出；`tagged_json.mbt`/`plain_json.mbt` 互通；`path.mbt`/`edit.mbt`/`transform.mbt` 操作结构；`tags.mbt`/`inspect.mbt` 处理内建 tag 和诊断。

项目采用 [MIT 许可证](LICENSE)。实现为原创 MoonBit 代码，遵循公开 EDN 规范；Python `edn_format` 仅作独立测试参考，采用 Apache-2.0，不随核心模块分发。[NOTICE](NOTICE) 记录参考边界；[查重记录](docs/competition/duplicate-check.md) 保留检索范围、相邻实现、独立建设理由和局限，不宣称绝对唯一。

本项目使用 AI 辅助设计、实现、测试、修复和文档。公开提交与自动验证提供可复查记录；不将自动测试等同于人工审核或赛事主办方验收。
