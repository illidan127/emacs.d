Provides a dedicated tab-bar workspace for agent-shell buffers.
Toggle with `agent-shell-workspace-toggle' to switch between your
regular work and an "Agents" tab with a managed layout.

Features:
- Dedicated tab-bar tab with buffer isolation
- Compact sidebar showing agent status with icons
- Tiling support for viewing 2-4 agents side-by-side
- Agent management (kill, restart, rename, mode-set)
- Non-agent buffers auto-redirect to your editing tab

Usage:
  (require 'agent-shell-workspace)
  (define-key agent-shell-command-map (kbd "w") 'agent-shell-workspace-toggle)

Sidebar keybindings:
  RET   - Focus agent in main area
  a     - Add agent to tiled view
  x     - Remove agent from tiled view
  t     - Un-tile back to single focus
  R     - Rename agent buffer
  c     - Create new agent
  k     - Kill agent at point
  r     - Restart agent at point
  d     - Delete all killed buffers
  m     - Set session mode
  M     - Cycle session mode
  C-c C-c - Interrupt agent
  q     - Close sidebar

Acknowledgements:
Status detection logic adapted from agent-shell-manager.el by Jethro Kuan.
