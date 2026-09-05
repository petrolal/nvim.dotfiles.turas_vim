-- TetraVim Project-Wide Find & Replace -- IntelliJ IDEA "Replace in Path" parity
--
-- The snacks pickers cover "Find in Path" (grep) but have no interactive
-- replace. grug-far gives the editable results buffer IDEA's Replace in Path
-- dialog provides: live match list, per-line/per-file toggles, regex + flags,
-- path/glob scoping, and an atomic apply. Backed by ripgrep (already a hard
-- dependency of the snacks pickers).
--
-- Keymap namespace: <leader>s ("search") -- sr / sR are unused there.

return {
  {
    "MagicDuck/grug-far.nvim",
    cmd = { "GrugFar", "GrugFarWithin" },
    keys = {
      {
        "<leader>sr",
        function()
          require("grug-far").open()
        end,
        desc = "Search & Replace (Project)",
      },
      {
        "<leader>sR",
        function()
          -- Pre-seed the search with the word/selection under the cursor.
          require("grug-far").open({
            prefills = { search = vim.fn.expand("<cword>") },
          })
        end,
        mode = { "n" },
        desc = "Search & Replace Word Under Cursor",
      },
      {
        "<leader>sr",
        function()
          require("grug-far").with_visual_selection()
        end,
        mode = { "x" },
        desc = "Search & Replace Selection",
      },
      {
        "<leader>sF",
        function()
          -- Scope the replace to the current file only.
          require("grug-far").open({
            prefills = { paths = vim.fn.expand("%") },
          })
        end,
        desc = "Search & Replace (Current File)",
      },
    },
    opts = {
      headerMaxWidth = 80,
      -- Keep the split on the right so it sits where the outline / help
      -- splits do rather than shoving the editor down.
      windowCreationCommand = "botright vsplit",
    },
  },
}
