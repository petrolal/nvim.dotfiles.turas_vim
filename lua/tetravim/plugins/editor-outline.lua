-- TetraVim Symbol Outline Panel -- IntelliJ IDEA "Structure" tool window parity
--
-- dropbar.nvim (ui-breadcrumbs.lua) gives the winbar breadcrumb; snacks'
-- <leader>ss is a transient fuzzy symbol picker. Neither is a docked,
-- always-visible tree of the current file's classes / methods / fields that
-- you navigate with the cursor -- that's what IDEA's Structure view is, and
-- what this adds. Backed purely by LSP document symbols.

return {
  {
    "hedyhli/outline.nvim",
    cmd = { "Outline", "OutlineOpen" },
    keys = {
      { "<leader>cs", "<cmd>Outline<cr>", desc = "Symbols Outline (Structure)" },
    },
    opts = {
      outline_window = {
        position = "right",
        width = 25,
        auto_close = false,
        show_numbers = false,
        show_relative_numbers = false,
      },
      symbol_folding = {
        autofold_depth = 1,
        auto_unfold = { hovered = true },
      },
      preview_window = {
        auto_preview = false,
      },
      symbols = {
        -- Hide noise-tier symbols so the tree reads like IDEA's Structure
        -- view: types, functions, fields, constants -- not every string
        -- literal or array.
        filter = {
          "String",
          "Variable",
          "Constant",
          "Object",
          "Array",
          "Boolean",
          "Number",
          "Null",
          "Package",
          exclude = true,
        },
      },
    },
  },
}
