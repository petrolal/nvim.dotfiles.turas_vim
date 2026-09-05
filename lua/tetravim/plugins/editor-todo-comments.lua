-- TetraVim TODO / FIXME Scanner -- IntelliJ IDEA "TODO" tool window parity
--
-- Highlights TODO / FIXME / HACK / BUG / NOTE / PERF / WARN keywords in
-- comments, adds ]t / [t motion between them, and feeds a project-wide list
-- into the pickers and trouble.nvim panel the distro already loads.
--
-- Requires ripgrep for the project search (already a hard dependency of the
-- snacks pickers). Degrades to highlight-only if `rg` is missing.

return {
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next TODO Comment",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Prev TODO Comment",
      },
      {
        "<leader>xt",
        function()
          -- Prefer the trouble.nvim panel (already loaded) for a dockable
          -- list; fall back to the quickfix-backed command otherwise.
          if pcall(require, "trouble") then
            vim.cmd("Trouble todo toggle")
          else
            vim.cmd("TodoQuickFix")
          end
        end,
        desc = "TODO List (Trouble)",
      },
      {
        "<leader>st",
        function()
          if pcall(require, "snacks") then
            require("snacks").picker.todo_comments()
          else
            vim.cmd("TodoTelescope")
          end
        end,
        desc = "Search TODOs",
      },
    },
    opts = {
      signs = true,
      highlight = {
        -- Match keywords only in real comments, and only when followed by a
        -- colon or a bracketed author -- so prose that merely contains the
        -- word "note" is left alone.
        comments_only = true,
        keyword = "wide",
        pattern = [[.*<(KEYWORDS)\s*:]],
      },
      search = {
        command = "rg",
        pattern = [[\b(KEYWORDS):]],
      },
    },
  },
}
