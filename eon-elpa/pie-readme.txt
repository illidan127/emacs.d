
Pie 是一个 Emacs AI agent，直接调用 Pi coding agent SDK。
不再依赖 shell-maker——使用自建的 pie-mode 作为 UI 层。

配置:

  (require 'pie)
  (setq pie-api-key "sk-ant-...")        ; 必填：API 密钥
  (setq pie-model "anthropic/claude-sonnet-4-5")  ; 可选，有默认值（预置 provider）

  M-x pie-start

依赖:
  - Node.js ≥ 22.19.0 + tsx
  - @earendil-works/pi-coding-agent (npm 包)

详见 docs/design.md 中的架构文档。
