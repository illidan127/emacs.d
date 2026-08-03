
Pie 是一个 Emacs AI agent，通过 shell-maker 提供交互界面，
直接调用 Pi coding agent SDK，不依赖 ACP 协议。

配置:

  (require 'pie)
  (setq pie-api-key "sk-ant-...")        ; 必填：API 密钥
  (setq pie-api-base-url "https://...")  ; 必填：API 端点
  (setq pie-model "anthropic/claude-sonnet-4-5")  ; 可选，有默认值

  M-x pie-start

依赖:
  - shell-maker (Emacs 包)
  - Node.js ≥ 22.19.0 + tsx
  - @earendil-works/pi-coding-agent (npm 包)

详见 docs/design.md 中的架构文档。
