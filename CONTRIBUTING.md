# 参与开发

请先在 issue 中附上最小 EDN 输入、预期行为、依据和工具链版本。不要附上私人配置或凭据。

修改格式语义时，提供 EDN 规范依据和可独立检查的回归案例；新增公共 API 后运行 `moon info`、`moon fmt` 并审阅 `pkg.generated.mbti`。

提交前运行 `moon fmt --check`、`moon check --deny-warn`、`moon build --deny-warn`、`moon test --deny-warn`，并在适用的四个目标中运行三个示例。更新独立样本需使用 `tools/requirements-oracle.txt` 的固定参考版本，不能通过修改预期掩盖实现问题。

代码和自有测试以 MIT 许可证提交。第三方源代码、样例或数据必须说明来源与授权。不得加入身份凭据或私人联系资料。
