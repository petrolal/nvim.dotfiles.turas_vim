-- TetraVim Undo History Visualiser -- IntelliJ IDEA "Local History" parity
--
-- IDEA's Local History keeps a timeline of every edit independent of VCS.
-- Neovim's persistent undo already stores the full undo *tree* on disk
-- (undofile); undotree draws it as a navigable timeline with per-state diffs
-- and time-travel, which is the same recovery workflow.
--
-- Persistent undo itself is configured in core/options.lua -- this spec only
-- adds the viewer. Pure Vimscript plugin, no external dependency.

return {
  {
    "mbbill/undotree",
    cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeFocus" },
    keys = {
      { "<leader>uu", "<cmd>UndotreeToggle<cr>", desc = "Toggle Undo History" },
    },
    init = function()
      vim.g.undotree_WindowLayout = 2
      vim.g.undotree_SplitWidth = 34
      vim.g.undotree_DiffpanelHeight = 12
      vim.g.undotree_SetFocusWhenToggle = 1
      vim.g.undotree_ShortIndicators = 1
    end,
  },
}
