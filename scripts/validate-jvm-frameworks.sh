#!/usr/bin/env bash
# TetraVim JVM framework config LSP (Spring Boot / Quarkus / MicroProfile)
# -- wiring smoke test.
#
# Asserts the framework language-server stack is connected end to end:
#   - util/jvm_frameworks exposes the path-resolver + readiness API
#   - lsp-spring-boot.lua declares spring-boot.nvim + the `properties` parser
#   - lsp-quarkus.lua declares quarkus.nvim + microprofile.nvim, dormant until
#     the Open VSX jars are fetched
#   - ftplugin/java.lua folds each module's java_extensions() into jdtls bundles
#   - tools-mason.lua ensures vscode-spring-boot-tools
#   - health.lua has the JVM Framework Config LSP section
#   - jvm_frameworks readiness flips with a fixture jar layout
#
# `vim.cmd('cquit 1')` on any failed assertion so exit status is trustworthy.

set -e

echo "=== TetraVim JVM framework config LSP smoke test ==="

echo "[1/4] Static: util/jvm_frameworks API + plugin/ftplugin/mason/health wiring..."
nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local fw = require('tetravim.util.jvm_frameworks')
  for _, fn in ipairs({ 'dir', 'java_cmd', 'quarkus_paths', 'microprofile_paths',
                        'quarkus_ready', 'spring_boot_ls_jar', 'spring_boot_ready' }) do
    assert(type(fw[fn]) == 'function', 'jvm_frameworks.' .. fn .. ' missing')
  end
  assert(type(fw.dir()) == 'string' and #fw.dir() > 0, 'jvm_frameworks.dir() empty')

  local sb = io.open('lua/tetravim/plugins/lsp-spring-boot.lua', 'r'):read('*a')
  assert(sb:match('JavaHello/spring%-boot%.nvim'), 'lsp-spring-boot.lua does not declare spring-boot.nvim')
  assert(sb:match('lsp_capabilities'), 'lsp-spring-boot.lua does not inject lsp_capabilities')
  assert(sb:match('\"properties\"'), 'lsp-spring-boot.lua does not ensure the treesitter properties parser')

  local q = io.open('lua/tetravim/plugins/lsp-quarkus.lua', 'r'):read('*a')
  assert(q:match('JavaHello/quarkus%.nvim'), 'lsp-quarkus.lua does not declare quarkus.nvim')
  assert(q:match('JavaHello/microprofile%.nvim'), 'lsp-quarkus.lua does not declare microprofile.nvim')
  assert(q:match('quarkus_paths') and q:match('microprofile_paths'), 'lsp-quarkus.lua does not gate on jvm_frameworks readiness')

  local java = io.open('ftplugin/java.lua', 'r'):read('*a')
  assert(java:match('java_extensions'), 'ftplugin/java.lua does not fold framework java_extensions() into bundles')
  assert(java:match('spring_boot') and java:match('microprofile') and java:match('quarkus'),
    'ftplugin/java.lua does not iterate the three framework modules')

  local mason = io.open('lua/tetravim/plugins/tools-mason.lua', 'r'):read('*a')
  assert(mason:match('vscode%-spring%-boot%-tools'), 'tools-mason.lua does not ensure vscode-spring-boot-tools')

  local hl = io.open('lua/tetravim/health.lua', 'r'):read('*a')
  assert(hl:match('JVM Framework Config LSP'), 'health.lua missing the JVM Framework Config LSP section')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: jvm_frameworks API + spring-boot / quarkus / jdtls / mason / health wiring verified')
end
" -c "qa!"

echo "[2/4] jvm_frameworks readiness is false with no jars present..."
TETRAVIM_JVM_LSP_DIR="$(mktemp -d)" nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local fw = require('tetravim.util.jvm_frameworks')
  assert(fw.dir() == vim.env.TETRAVIM_JVM_LSP_DIR, 'TETRAVIM_JVM_LSP_DIR override ignored')
  assert(fw.quarkus_paths() == nil, 'quarkus_paths() should be nil with an empty dir')
  assert(fw.microprofile_paths() == nil, 'microprofile_paths() should be nil with an empty dir')
  assert(fw.quarkus_ready() == false, 'quarkus_ready() should be false with an empty dir')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: readiness probes report not-installed when the jar dir is empty')
end
" -c "qa!"

echo "[3/4] jvm_frameworks readiness flips true against a fixture jar layout..."
FIX="$(mktemp -d)"
mkdir -p "$FIX/quarkus/server" "$FIX/quarkus/jars" "$FIX/microprofile/server" "$FIX/microprofile/jars"
: >"$FIX/quarkus/server/com.redhat.qute.ls-uber.jar"
: >"$FIX/quarkus/server/com.redhat.quarkus.ls.jar"
: >"$FIX/microprofile/server/org.eclipse.lsp4mp.ls-uber.jar"
TETRAVIM_JVM_LSP_DIR="$FIX" nvim -u init.lua --headless -c "lua
local ok, err = pcall(function()
  local fw = require('tetravim.util.jvm_frameworks')
  local qp = fw.quarkus_paths()
  local mp = fw.microprofile_paths()
  assert(type(qp) == 'table', 'quarkus_paths() nil despite fixture jars')
  assert(type(mp) == 'table', 'microprofile_paths() nil despite fixture jars')
  assert(qp.ls_path == vim.env.TETRAVIM_JVM_LSP_DIR .. '/quarkus/server', 'quarkus ls_path wrong: ' .. tostring(qp.ls_path))
  assert(mp.ls_path == vim.env.TETRAVIM_JVM_LSP_DIR .. '/microprofile/server', 'microprofile ls_path wrong: ' .. tostring(mp.ls_path))
  assert(fw.quarkus_ready() == true, 'quarkus_ready() false despite fixture jars')
end)
if not ok then
  io.stderr:write('FAIL: ' .. tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('OK: readiness probes + resolved paths track the fixture jar layout')
end
" -c "qa!"
rm -rf "$FIX"

echo "[4/4] fetch-jvm-lsp-jars.sh is present, executable and syntactically valid..."
test -x scripts/fetch-jvm-lsp-jars.sh || { echo "FAIL: scripts/fetch-jvm-lsp-jars.sh not executable"; exit 1; }
bash -n scripts/fetch-jvm-lsp-jars.sh || { echo "FAIL: scripts/fetch-jvm-lsp-jars.sh has a syntax error"; exit 1; }
echo "OK: scripts/fetch-jvm-lsp-jars.sh present + valid"

echo ""
echo "✔ JVM framework config LSP smoke test PASSED."
