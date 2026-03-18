
一个结合 perspective 与 projectile 部分理念的 Emacs 工作区插件。

特性：
  - 每个 workspace 运行在独立 frame 中
  - 每个 workspace 绑定一个工作目录，创建后不可变更
  - eon-workspace-create 从已知项目列表选择（按 recent 文件 MRU 排序）：已打开则切换，未打开则创建
  - 可以在 workspace 中打开非工作目录的文件
  - 每个 workspace 维护私有 buffer 列表（基于 window-buffer-change-functions
    自动追踪 frame 中显示过的 buffer），eon-workspace-switch-to-buffer
    仅在该列表中切换
  - eon-workspace-buffer-isolation-mode（global minor mode）启用后，
    通过 frame 的 buffer-predicate 与 read-buffer-function 两层机制，
    做到 workspace 间 buffer 列表互相隔离。同一文件被多个 workspace
    打开时仍是同一 buffer，可同时归属多个 workspace 的私有列表
  - eon-workspace-find-file 通过 fd 列出 ROOT 下文件，ivy 补全选择
    （支持 ivy-occur 等 ivy-read 能力），
    遵守 .gitignore，并叠加 ROOT/.eon.yaml 中
    ignore-patterns: 配置的额外过滤模式
  - 提供清理命令，清理当前 workspace 中非工作目录文件对应的 buffer，
    临时 buffer（无文件关联、名字以空格或 * 开头）不处理

.eon.yaml 示例（放在 workspace 根目录）：

  ignore-patterns:
    - "*.log"
    - "dist"
  action:
    default: compile
    compile: |
      echo "building..."
    test: |
      pytest -v

主要命令：
  M-x eon-workspace-create          创建或切换到 workspace（已知项目列表）
  M-x eon-workspace-find-file       在当前 workspace 打开文件
  M-x eon-workspace-open             从任意 workspace 选择文件打开（不切换工作区）
  M-x eon-workspace-rg              在当前 workspace ROOT 中用 rg 搜索
  M-x eon-workspace-switch-to-buffer 在 workspace 私有 buffer 列表中切换（Marginalia + C-k kill）
  M-x eon-workspace-cleanup         清理非工作目录的文件 buffer
  M-x eon-workspace-kill            删除 workspace 并关闭其 frame
  M-x eon-workspace-list            列出所有 workspace
  M-x eon-workspace-add-project     手工把目录加入已知项目列表
  M-x eon-workspace-remove-project  从已知项目列表中移除
  M-x eon-workspace-init-config     在当前 workspace 根目录创建 .eon.yaml
  M-x eon-workspace-config           用 customize 风格界面编辑 .eon.yaml
  M-x eon-workspace-compile          执行 compile 命令（向后兼容，推荐 action.compile）
  M-x eon-workspace-action            从 .eon.yaml 中选择并执行 action
  M-x eon-workspace-action-default    执行默认 action
  M-x eon-workspace-format            格式化 .eon.yaml 中 exec 块（eon-workspace-format.el）
