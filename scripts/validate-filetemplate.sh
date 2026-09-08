#!/usr/bin/env bash
# TetraVim "New File from Template" (IDEA-style New) -- behavioral smoke test
#
# Mirrors validate-extract.sh's pattern: `vim.cmd('cquit 1')` on assertion
# failure so pass/fail is trustworthy. No external process is required -- the
# whole feature is pure Lua + filesystem.
#
# Exercises the real engine end to end against real files:
#   - JVM package derivation from a Maven/Gradle src layout
#   - dotted-FQN name field expanded into nested directories
#   - ${cursor} marker stripped, position reported
#   - overwrite guard
#   - fixed_name templates (Dockerfile)
#   - user templates loaded from stdpath("config")/templates and ${NAME} expanded
#   - <leader>fn / :TetraVimNewFile wiring present in core/keymaps.lua
#   - :checkhealth section present
#   - BufNewFile skeleton prompt fills an empty buffer / skips non-empty ones

set -e

echo "=== TetraVim New File from Template smoke test ==="

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

mkdir -p "$FIXTURE_DIR/src/main/java/com/example"
mkdir -p "$FIXTURE_DIR/src/main/kotlin"
touch "$FIXTURE_DIR/pom.xml"

echo "[1/6] Static: module shape + keymap/command/health wiring..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local ft = require('tetravim.util.filetemplate')
  assert(type(ft.new_file) == 'function', 'new_file missing')
  assert(type(ft.scaffold) == 'function', 'scaffold missing')
  assert(type(ft.render) == 'function', 'render missing')
  assert(type(ft.derive_package) == 'function', 'derive_package missing')
  assert(type(ft.load_user_templates) == 'function', 'load_user_templates missing')
  assert(ft.builtin_count() >= 30, 'expected >= 30 built-in templates, got ' .. ft.builtin_count())
  for _, id in ipairs({ 'java.class', 'java.interface', 'java.enum', 'java.record', 'kt.class', 'scala.case-class', 'web.html', 'web.xhtml' }) do
    assert(ft.builtin[id], 'missing built-in: ' .. id)
  end

  local km = io.open('lua/tetravim/core/keymaps.lua', 'r'):read('*a')
  assert(km:match('filetemplate'), 'core/keymaps.lua does not dispatch into filetemplate')
  assert(km:match('TetraVimNewFile'), 'core/keymaps.lua missing :TetraVimNewFile command')
  assert(km:match('<leader>fn'), 'core/keymaps.lua missing <leader>fn keymap')

  local hl = io.open('lua/tetravim/health.lua', 'r'):read('*a')
  assert(hl:match('New File from Template'), 'health.lua missing the File Template section')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: module shape, catalogue size, keymap/command/health wiring verified')
end
" -c "qa!"

echo "[2/6] Behavioral: Java class scaffolded with package derived from the src layout, \${cursor} stripped..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local ft = require('tetravim.util.filetemplate')
  local dir = '$FIXTURE_DIR/src/main/java/com/example'
  local path, row, col = ft.scaffold(ft.builtin['java.class'], 'PaymentService', dir, '$FIXTURE_DIR')
  assert(path == dir .. '/PaymentService.java', 'unexpected path: ' .. tostring(path))
  assert(type(row) == 'number' and type(col) == 'number', 'cursor position not reported')
  local body = table.concat(vim.fn.readfile(path), '\n')
  assert(body:match('package com%.example;'), 'derived package missing, got:\n' .. body)
  assert(body:match('public class PaymentService {'), 'class declaration missing, got:\n' .. body)
  assert(not body:match('%\${cursor}'), '\${cursor} marker was not stripped')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: Java class written with correct package + name, cursor marker stripped')
end
" -c "qa!"

echo "[3/6] Behavioral: dotted FQN in the name field expands into nested dirs; Kotlin package has no semicolon..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local ft = require('tetravim.util.filetemplate')
  local dir = '$FIXTURE_DIR/src/main/kotlin'
  local path = ft.scaffold(ft.builtin['kt.data'], 'com.acme.billing.Invoice', dir, '$FIXTURE_DIR')
  assert(path == dir .. '/com/acme/billing/Invoice.kt', 'FQN not expanded to nested path: ' .. tostring(path))
  local body = table.concat(vim.fn.readfile(path), '\n')
  assert(body:match('package com%.acme%.billing\n'), 'kotlin package line missing/wrong, got:\n' .. body)
  assert(not body:match('package com%.acme%.billing;'), 'kotlin package must not end with a semicolon')
  assert(body:match('data class Invoice%('), 'data class declaration missing, got:\n' .. body)
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: dotted FQN expanded to nested directories, Kotlin package rendered correctly')
end
" -c "qa!"

echo "[4/6] Behavioral: overwrite guard + fixed_name (Dockerfile) template..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local ft = require('tetravim.util.filetemplate')
  local dp = ft.scaffold(ft.builtin['devops.dockerfile'], 'Dockerfile', '$FIXTURE_DIR', '$FIXTURE_DIR')
  assert(dp == '$FIXTURE_DIR/Dockerfile', 'Dockerfile path wrong: ' .. tostring(dp))
  assert(table.concat(vim.fn.readfile(dp), '\n'):match('^FROM '), 'Dockerfile body missing FROM')

  local again, e = ft.scaffold(ft.builtin['devops.dockerfile'], 'Dockerfile', '$FIXTURE_DIR', '$FIXTURE_DIR')
  assert(again == nil and e == 'exists', 'overwrite guard did not fire, got: ' .. tostring(again) .. ' / ' .. tostring(e))
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: fixed_name template honoured, existing file not overwritten')
end
" -c "qa!"

echo "[5/6] Behavioral: user template dir is read and \${NAME} placeholders expanded..."
USER_TPL_DIR="$FIXTURE_DIR/nvim-config/templates"
mkdir -p "$USER_TPL_DIR"
cat > "$USER_TPL_DIR/Aggregate.java" <<'TPL'
<!-- tetravim: label=DDD_Aggregate langs=java -->
package ${PACKAGE};

public final class ${NAME} {
    private ${NAME}() {}
}
TPL
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local ft = require('tetravim.util.filetemplate')
  ft.user_dir = function() return '$USER_TPL_DIR' end

  local loaded = ft.load_user_templates()
  local tpl = loaded['user.Aggregate.java']
  assert(tpl, 'user template not discovered; keys: ' .. vim.inspect(vim.tbl_keys(loaded)))
  assert(tpl.label == 'DDD Aggregate', 'directive label not parsed, got: ' .. tostring(tpl.label))
  assert(tpl.ext == 'java', 'user template ext wrong: ' .. tostring(tpl.ext))

  local dir = '$FIXTURE_DIR/src/main/java/com/example'
  local content = ft.render(tpl, { name = 'Order', package = ft.derive_package(dir) })
  assert(content:match('package com%.example;'), 'user template ${PACKAGE} not expanded, got:\n' .. content)
  assert(content:match('public final class Order {'), 'user template ${NAME} not expanded, got:\n' .. content)
  assert(content:match('private Order%(%) {}'), 'second ${NAME} occurrence not expanded, got:\n' .. content)
  assert(not content:match('tetravim:'), 'directive line leaked into rendered output')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: user templates loaded from the config templates dir, directive parsed, placeholders expanded')
end
" -c "qa!"

echo "[6/6] Behavioral: BufNewFile skeleton prompt fills an empty buffer with the picked template..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local ft = require('tetravim.util.filetemplate')
  assert(type(ft.offer_skeleton) == 'function', 'offer_skeleton missing')
  assert(type(ft.setup_new_file_prompt) == 'function', 'setup_new_file_prompt missing')

  -- exact-ext match wins over language-tag match
  assert(ft.skeletons_for('css', '', 'main')[1].id == 'web.css', 'skeletons_for ordering wrong')
  assert(#ft.skeletons_for('bin', '', 'x') == 0, 'unknown type should match nothing')

  vim.ui.select = function(items, _, cb) cb(items[2]) end  -- items[1] == '(no template)'
  -- A real new-file buffer (never written to disk), exactly as BufNewFile sees it.
  vim.cmd.edit(vim.fn.fnameescape('$FIXTURE_DIR/src/main/java/com/example/Gizmo.java'))
  vim.bo.filetype = 'java'
  ft.offer_skeleton(vim.api.nvim_get_current_buf())
  local body = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  assert(body:match('package com%.example;'), 'skeleton package not derived, got:\n' .. body)
  assert(body:match('Gizmo'), 'skeleton did not use the file name, got:\n' .. body)

  -- non-empty buffer is never touched
  local seen = false
  vim.ui.select = function(_, _, cb) seen = true cb(nil) end
  vim.cmd.edit(vim.fn.fnameescape('$FIXTURE_DIR/src/main/java/com/example/Filled.java'))
  vim.bo.filetype = 'java'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '// mine' })
  ft.offer_skeleton(vim.api.nvim_get_current_buf())
  assert(seen == false, 'skeleton prompt fired for a non-empty buffer')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: BufNewFile skeleton prompt fills empty buffers and skips non-empty / unknown ones')
end
" -c "qa!"

echo ""
echo "✔ New File from Template smoke test PASSED."
