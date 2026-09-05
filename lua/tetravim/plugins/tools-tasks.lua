-- TetraVim Generic Task Runner -- IntelliJ IDEA "Run Anything" / Run Configurations parity
--
-- The curated JVM (<leader>j build/run) and DevOps (<leader>o) suites stay the
-- house runners for Maven/Gradle/Terraform/etc. overseer fills the gap IDEA's
-- "Run Anything" popup covers: arbitrary shell commands, VS Code `tasks.json`,
-- npm/pnpm/yarn scripts, and a persistent task list window with live output.
-- It also registers itself as a nvim-dap pre-launch task provider (`dap = true`
-- below), so a `preLaunchTask` in a debug config actually runs. The neotest
-- runner is left alone -- tools-test.lua owns `neotest.setup()` and wiring the
-- overseer consumer from here would clobber that adapter config.
--
-- Keymap namespace: <leader>r ("run/tasks") -- unused elsewhere in the distro
-- (only <leader>cr / <leader>cR exist, under the code group).

return {
  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerRun",
      "OverseerToggle",
      "OverseerOpen",
      "OverseerClose",
      "OverseerBuild",
      "OverseerInfo",
      "OverseerQuickAction",
      "OverseerTaskAction",
      "OverseerClearCache",
    },
    keys = {
      { "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run Task (pick template)" },
      { "<leader>rt", "<cmd>OverseerToggle<cr>", desc = "Toggle Task List" },
      { "<leader>ra", "<cmd>OverseerQuickAction<cr>", desc = "Task Quick Action" },
      { "<leader>rb", "<cmd>OverseerBuild<cr>", desc = "Build a New Task" },
      { "<leader>ri", "<cmd>OverseerInfo<cr>", desc = "Overseer Info / Diagnostics" },
      {
        "<leader>rl",
        function()
          -- Re-run the most recent task without re-picking a template.
          local overseer = require("overseer")
          local tasks = overseer.list_tasks({ recent_first = true })
          if vim.tbl_isempty(tasks) then
            require("tetravim.util.ui").notify_warn("No previous task to re-run -- start one with <leader>rr")
            return
          end
          overseer.run_action(tasks[1], "restart")
        end,
        desc = "Re-run Last Task",
      },
    },
    opts = {
      strategy = "terminal",
      templates = { "builtin" },
      task_list = {
        direction = "bottom",
        min_height = 10,
        max_height = 18,
        default_detail = 1,
      },
      -- Persist the task list layout preference but never auto-start a task.
      dap = true,
    },
    config = function(_, opts)
      require("overseer").setup(opts)
    end,
  },
}
