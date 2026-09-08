#!/usr/bin/env bash
# TetraVim Autocompletion / IntelliSense -- wiring smoke test
#
# Asserts the completion stack is actually connected end to end:
#   - util/lsp_capabilities advertises cmp's extended completion item support
#   - lsp-core.lua threads that capabilities table into every server (0.11 "*"
#     config) and the lspconfig fallback path
#   - ftplugin/java.lua (jdtls) and lsp-scala.lua (metals) inject the same table
#   - nvim-cmp is configured with an LSP source + a snippet expander, not the
#     old empty stub
#   - :checkhealth has an IntelliSense section
#
# `vim.cmd('cquit 1')` on any failed assertion so exit status is trustworthy.

set -e

echo "=== TetraVim Autocompletion / IntelliSense smoke test ==="

echo "[1/4] Static: capabilities helper + every server-start path injects it..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local caps = require('tetravim.util.lsp_capabilities')
  assert(type(caps.make) == 'function', 'lsp_capabilities.make missing')
  local c = caps.make()
  local item = c.textDocument.completion.completionItem
  assert(item.snippetSupport == true, 'snippetSupport not advertised')
  assert(type(item.resolveSupport) == 'table', 'resolveSupport not advertised')
  assert(c.textDocument.foldingRange and c.textDocument.foldingRange.lineFoldingOnly, 'foldingRange hint missing')
  -- fresh table per call
  assert(caps.make() ~= caps.make(), 'make() must not hand out one shared table')

  local core = io.open('lua/tetravim/plugins/lsp-core.lua', 'r'):read('*a')
  assert(core:match('lsp_capabilities'), 'lsp-core.lua does not use lsp_capabilities')
  assert(core:match('vim%.lsp%.config%(\"%*\"'), 'lsp-core.lua missing the \"*\" wildcard capabilities config')
  assert(core:match('capabilities'), 'lsp-core.lua fallback path missing capabilities')

  local java = io.open('ftplugin/java.lua', 'r'):read('*a')
  assert(java:match('lsp_capabilities'), 'ftplugin/java.lua (jdtls) does not inject lsp_capabilities')

  local scala = io.open('lua/tetravim/plugins/lsp-scala.lua', 'r'):read('*a')
  assert(scala:match('lsp_capabilities'), 'lsp-scala.lua (metals) does not inject lsp_capabilities')

  local hl = io.open('lua/tetravim/health.lua', 'r'):read('*a')
  assert(hl:match('Autocompletion / IntelliSense'), 'health.lua missing the IntelliSense section')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: capabilities helper + lsp-core / jdtls / metals / health wiring verified')
end
" -c "qa!"

echo "[2/4] nvim-cmp loads and is configured with an LSP source + snippet expander..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  require('lazy').load({ plugins = { 'LuaSnip', 'nvim-cmp' } })
  local cmp = require('cmp')
  assert(pcall(require, 'cmp_nvim_lsp'), 'cmp-nvim-lsp not resolvable after load')
  assert(pcall(require, 'luasnip'), 'luasnip not resolvable after load')
  local cfg = cmp.get_config()
  assert(type(cfg.snippet) == 'table' and type(cfg.snippet.expand) == 'function', 'no snippet expander wired')
  local names = {}
  for _, s in ipairs(cfg.sources or {}) do names[s.name] = true end
  assert(names.nvim_lsp, 'nvim_lsp source missing from cmp config')
  assert(names.luasnip, 'luasnip source missing from cmp config')
  assert(names.path and names.buffer, 'path/buffer sources missing from cmp config')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: nvim-cmp configured with nvim_lsp + luasnip + path + buffer and a snippet expander')
end
" -c "qa!"

echo "[3/4] completeopt is menuone,noselect so nothing is auto-accepted..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  require('lazy').load({ plugins = { 'nvim-cmp' } })
  local co = vim.opt.completeopt:get()
  assert(vim.tbl_contains(co, 'noselect'), 'completeopt missing noselect, got: ' .. vim.inspect(co))
  assert(vim.tbl_contains(co, 'menuone'), 'completeopt missing menuone, got: ' .. vim.inspect(co))
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: completeopt = menu,menuone,noselect')
end
" -c "qa!"

echo "[4/4] a server routed through lsp-core actually carries the cmp capabilities..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  require('lazy').load({ plugins = { 'nvim-cmp', 'nvim-lspconfig' } })
  -- lua_ls goes through lsp-core's opts.servers loop; after config() it should
  -- resolve with the shared capabilities merged in via the '*' config.
  local resolved = vim.lsp.config.lua_ls
  assert(type(resolved) == 'table', 'vim.lsp.config.lua_ls did not resolve')
  local item = resolved.capabilities
    and resolved.capabilities.textDocument
    and resolved.capabilities.textDocument.completion
    and resolved.capabilities.textDocument.completion.completionItem
  assert(item and item.snippetSupport == true, 'lua_ls not started with cmp completion capabilities')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: lua_ls resolves with cmp-nvim-lsp completion capabilities')
end
" -c "qa!"

echo ""
echo "✔ Autocompletion / IntelliSense smoke test PASSED."
