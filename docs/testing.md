# 验证方法

基础测试使用手写规范案例，覆盖合法输入、坏输入、边界和资源限制。`integration_test.mbt` 使用外部包视角调用公开 API，三个 examples 有真实结果断言。

`tools/generate_differential.py` 用固定随机种子构造 200 个自有 EDN 文本，通过独立 Python `edn_format==0.7.5` 获得预期值，然后生成 MoonBit 测试。比较共同支持的基础值和容器，不把该参考实现的 ratio、namespaced maps 或宽松校验当成标准。复杂 tag、精确大整数和 Unicode 字符通过另外的规范案例检验。

`properties_wbtest.mbt` 中另有 2,000 组包含整数、大整数、精确十进制、浮点和补充平面字符的嵌套值，执行 EDN 往返、tagged JSON 往返和空事务不变性。它们补充独立预期，不替代它。

验收新增用例先证明旧实现的具体问题，再保留正确性回归；已修复公开 equality 校验绕过、手工字符代理码点及普通 JSON 数值投影不对称问题。没有性能提升或覆盖率百分比声明。

CI 固定发布工具链并运行 wasm-gc、wasm、js、native 的 check/build/test 和三个示例。每次源代码变化需以同一提交重新验证；旧 CI 不证明新提交通过。发布后在独立无凭据且无旧依赖缓存的消费者验证精确版本。
