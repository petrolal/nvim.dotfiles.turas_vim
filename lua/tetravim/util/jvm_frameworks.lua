-- TetraVim JVM framework language-server path resolver
--
-- Spring Boot, Quarkus and MicroProfile ship their editor intelligence as
-- VS Code extensions, not as plain LSP servers:
--
--   * Spring Boot LS  -> Mason package `vscode-spring-boot-tools`
--                        (`application.{properties,yml}` completion,
--                        `@ConfigurationProperties` metadata, bean navigation)
--   * Quarkus / lsp4mp -> Red Hat `vscode-quarkus` + `vscode-microprofile`
--                        `.vsix` bundles -- NOT in Mason. `scripts/
--                        fetch-jvm-lsp-jars.sh` downloads them from Open VSX
--                        into `$TETRAVIM_JVM_LSP_DIR` (default
--                        `stdpath("data")/tetravim/jvm-lsp`) laid out as:
--
--                          <dir>/quarkus/server/com.redhat.qute.ls-uber.jar
--                          <dir>/quarkus/server/com.redhat.quarkus.ls.jar
--                          <dir>/quarkus/jars/*.jar        (JDT extensions)
--                          <dir>/microprofile/server/org.eclipse.lsp4mp.ls-uber.jar
--                          <dir>/microprofile/jars/*.jar   (JDT extensions)
--
-- This module resolves those paths and reports readiness so the plugin specs
-- (`lsp-spring-boot.lua`, `lsp-quarkus.lua`), `ftplugin/java.lua` (jdtls
-- `bundles`) and `:checkhealth tetravim` can all degrade gracefully when the
-- tooling is not installed.

local M = {}

--- Base directory the Quarkus / MicroProfile jars are unpacked into.
---@return string
function M.dir()
  local override = vim.env.TETRAVIM_JVM_LSP_DIR
  if override and override ~= "" then
    return vim.fn.expand(override)
  end
  return vim.fn.stdpath("data") .. "/tetravim/jvm-lsp"
end

--- Absolute `java` binary from the distro's JDK 21 discovery, or nil to let the
--- plugin fall back to `$JAVA_HOME/bin/java` / `java` on `$PATH`.
---@return string|nil
function M.java_cmd()
  local ok, jvm = pcall(require, "tetravim.util.jvm")
  if not ok or type(jvm.find_java21_home) ~= "function" then
    return nil
  end
  local home = jvm.find_java21_home()
  if not home or home == "" then
    return nil
  end
  local bin = home .. "/bin/java"
  if vim.fn.executable(bin) == 1 then
    return bin
  end
  return nil
end

local function readable(path)
  return vim.fn.filereadable(path) == 1
end

--- Paths to feed `require("quarkus").setup{}`.
--- Returns nil when the `vscode-quarkus` jars have not been fetched.
---@return { ls_path: string, jdt_extensions_path: string, microprofile_ext_path: string }|nil
function M.quarkus_paths()
  local server = M.dir() .. "/quarkus/server"
  if not readable(server .. "/com.redhat.qute.ls-uber.jar") then
    return nil
  end
  if not readable(server .. "/com.redhat.quarkus.ls.jar") then
    return nil
  end
  return {
    ls_path = server,
    jdt_extensions_path = M.dir() .. "/quarkus/jars",
    microprofile_ext_path = server,
  }
end

--- Paths to feed `require("microprofile").setup{}`.
--- Returns nil when the `vscode-microprofile` jars have not been fetched.
---@return { ls_path: string, jdt_extensions_path: string }|nil
function M.microprofile_paths()
  local server = M.dir() .. "/microprofile/server"
  if not readable(server .. "/org.eclipse.lsp4mp.ls-uber.jar") then
    return nil
  end
  return {
    ls_path = server,
    jdt_extensions_path = M.dir() .. "/microprofile/jars",
  }
end

--- The Quarkus stack needs BOTH bundles: lsp4mp is the property-completion
--- engine and `com.redhat.quarkus.ls.jar` layers the `quarkus.*` namespace on
--- top of it.
---@return boolean
function M.quarkus_ready()
  return M.quarkus_paths() ~= nil and M.microprofile_paths() ~= nil
end

--- Locate the Spring Boot language-server jar installed by Mason.
---@return string|nil
function M.spring_boot_ls_jar()
  local candidates = {
    vim.fn.expand("~/.local/share/nvim/mason/share/vscode-spring-boot-tools/language-server.jar"),
  }
  local pkg = vim.fn.expand("~/.local/share/nvim/mason/packages/vscode-spring-boot-tools")
  if vim.fn.isdirectory(pkg) == 1 then
    for _, hit in ipairs(vim.fn.glob(pkg .. "/**/spring-boot-language-server*.jar", true, true)) do
      table.insert(candidates, hit)
    end
    for _, hit in ipairs(vim.fn.glob(pkg .. "/**/language-server.jar", true, true)) do
      table.insert(candidates, hit)
    end
  end
  for _, path in ipairs(candidates) do
    if readable(path) then
      return path
    end
  end
  return nil
end

---@return boolean
function M.spring_boot_ready()
  return M.spring_boot_ls_jar() ~= nil
end

return M
