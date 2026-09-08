-- TetraVim WhichKey Keybinding Helper Integration (Story 8.4, Story 10.1, Story 12.3, Story 20.1, Story 21.2, Story 23.2, Story 24.2 & Story 34.1)

return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      opts.preset = "helix"
      -- The "helix" preset caps the popup at height.max = 0.75 and
      -- width.max = 60. With this many top-level leader groups, that cap
      -- is too small: on an 80x24 terminal, the list overflows and later
      -- groups (e.g. "windows", "buffer") get silently cut off below the
      -- fold instead of scrolling into view, making them look like they
      -- vanished. Raise both caps so the whole group list fits on-screen
      -- while keeping the preset's bottom-right, rounded-border layout.
      opts.win = {
        height = { min = 4, max = 0.9 },
        width = { min = 30, max = 80 },
      }
      opts.spec = opts.spec or {}
      vim.list_extend(opts.spec, {
        { "<leader>c", group = "code/lsp", icon = "󰅍 " },
        { "<leader>f", group = "file/find", icon = "󰈞 " },
        { "<leader>s", group = "search", icon = "󰍉 " },
        { "<leader>b", group = "buffer", icon = "󰓩 " },
        { "<leader>w", group = "windows", icon = "󰖲 " },
        { "<leader>l", group = "lazy/mason/lsp", icon = "󰒓 " },
        { "<leader>g", group = "git control", icon = "󰊢 " },
        { "<leader>gh", group = "git hunks", icon = "󰊢 " },
        -- <leader>gc children (gco/gcq/gch/gcH/gcf) are global. The <leader>gx
        -- / <leader>gX conflict-pick groups are registered buffer-locally for
        -- diffview buffers only -- see lua/tetravim/plugins/tools-diffview.lua.
        { "<leader>gc", group = "conflict/compare", icon = " " },
        { "<leader>gr", group = "git review", icon = "󰊢 " },
        { "<leader>o", group = "devops/infra", icon = "󱁢 " },
        { "<leader>d", group = "debug/dap", icon = "󰃤 " },
        { "<leader>D", group = "database", icon = "󰆼 " },
        { "<leader>H", group = "http", icon = "󰖟 " },
        { "<leader>G", group = "grpc/proto", icon = "󱅥 " },
        { "<leader>t", group = "test runner", icon = "󰙨 " },
        { "<leader>x", group = "quality/security", icon = "󰒃 " },
        { "<leader>xd", group = "diagnostics", icon = "󰒡 " },
        { "<leader>xl", group = "lint", icon = "󰉢 " },
        { "<leader>xs", group = "sonar", icon = "󰒃 " },
        { "<leader>xv", group = "cve/vulns", icon = "󰒃 " },
        { "<leader>u", group = "ui/toggles", icon = "󰔡 " },
        { "<leader>r", group = "run/tasks", icon = "󱓞 " },
        { "<leader>m", group = "marks/bookmarks", icon = "󰃀 " },
        { "<leader>q", group = "quit/session", icon = "󰗼 " },
      })

      -- Category ordering for the <leader>c ("code/lsp") popup. which-key v3
      -- rejects a user-supplied `order` field on a mapping spec (it is an
      -- internal Node attribute), so the flat keymap list is instead clustered
      -- into visual blocks -- Actions / Refactor / Docs / Format / Diagnostics
      -- / CodeLens / Navigate -- by a custom sorter injected into `opts.sort`
      -- below. These entries only attach a per-key `desc` + category icon; the
      -- keymaps themselves stay defined where they are (core/keymaps.lua,
      -- editor-outline.lua, editor-docgen.lua, util/extract.lua).
      vim.list_extend(opts.spec, {
        -- Actions --------------------------------------------------------
        { "<leader>ca", desc = "Code Action", icon = "󰌵 " },
        { "<leader>cA", desc = "Source Action", icon = "󰌵 " },
        { "<leader>co", desc = "Organize Imports", icon = "󰗧 " },
        -- Refactor -----------------------------------------------------
        { "<leader>cr", desc = "Rename Symbol", icon = "󰑕 " },
        { "<leader>cR", desc = "Rename File", icon = "󰑕 " },
        -- Docs -------------------------------------------------------
        { "<leader>cg", desc = "Generate Doc (function)", icon = "󰈙 " },
        { "<leader>cG", desc = "Generate Doc (class/type)", icon = "󰈙 " },
        -- Format ---------------------------------------------------
        { "<leader>cf", desc = "Format", icon = "󰉢 " },
        { "<leader>cF", desc = "Format Injected Langs", icon = "󰉢 " },
        -- Diagnostics ------------------------------------------------
        { "<leader>cd", desc = "Line Diagnostics", icon = "󰒡 " },
        -- CodeLens -------------------------------------------------
        { "<leader>cc", desc = "Run Codelens", icon = "󰊕 " },
        { "<leader>cC", desc = "Refresh & Display Codelens", icon = "󰊕 " },
        -- Navigate / Info ------------------------------------------
        { "<leader>cs", desc = "Symbols Outline (Structure)", icon = "󰙅 " },
        { "<leader>cl", desc = "Lsp Info", icon = "󰋽 " },
      })

      -- Rank map (keyed by the final key after <leader>c) that drives the
      -- category clustering. Buffer-local Java/Kotlin extraction keys
      -- (<leader>ce/cm/cv/ci) get Refactor-band ranks here too so they order
      -- sensibly within the "local" cluster; <leader>cc is Run Codelens
      -- globally / Extract Constant buffer-locally -- same key, one rank.
      -- stylua: ignore
      local c_rank = {
        a = 10, A = 11, o = 12,                          -- Actions
        r = 20, R = 21, e = 22, m = 23, v = 24, i = 25,  -- Refactor
        g = 30, G = 31,                                  -- Docs
        f = 40, F = 41,                                  -- Format
        d = 50,                                          -- Diagnostics
        c = 60, C = 61,                                  -- CodeLens
        s = 70, l = 71,                                  -- Navigate / Info
      }
      -- Custom which-key sorter: returns a category rank for the direct
      -- children of the <leader>c group and a constant (0) for every other
      -- key, so it is a no-op tie in all other popups and leaves their sort
      -- untouched. Slotted after "local"/"group" so buffer-local keys still
      -- float first and subgroups (<leader>cj*, <leader>cn*) still sink last.
      local function c_category(item)
        local p = item.parent
        if not p or p.key ~= "c" then
          return 0
        end
        local gp = p.parent -- the <leader> node
        if not gp or not gp.parent or gp.parent.parent ~= nil then
          return 0
        end
        return c_rank[item.key] or 900
      end
      opts.sort = { "local", "order", "group", c_category, "alphanum", "mod" }

      -- Per-language <leader>c* subgroups (Maven/Gradle, Terraform,
      -- Ansible, Docker (<leader>cD to avoid the global <leader>cd
      -- Line Diagnostics keymap), Helm...). These are registered with buffer = true,
      -- so which-key only surfaces them while the current buffer's
      -- filetype actually owns matching buffer-local keymaps -- see
      -- lua/tetravim/core/lang-keymaps.lua.
      vim.list_extend(opts.spec, require("tetravim.core.lang-keymaps").whichkey_spec())

      -- DevOps & Infrastructure Tooling Suite (<leader>o)
      vim.list_extend(opts.spec, {
        { "<leader>ot", group = "terraform/opentofu", icon = "󱁢 " },
        { "<leader>oc", group = "cloudformation/sam", icon = "󰅟 " },
        { "<leader>oy", group = "ansible", icon = "󰚰 " },
        { "<leader>od", group = "docker", icon = "󰡨 " },
        { "<leader>ok", group = "helm/k8s", icon = "󱃾 " },
      })

      local jvm = require("tetravim.util.jvm")
      vim.list_extend(opts.spec, jvm.whichkey_spec())
      return opts
    end,
  },
}
