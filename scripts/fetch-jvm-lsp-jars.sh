#!/usr/bin/env bash
# TetraVim: fetch the Quarkus / MicroProfile language-server jars
#
# lsp4mp + the Qute LS ship only inside Red Hat's `vscode-quarkus` and
# `vscode-microprofile` extensions -- there is no Mason package. This script
# downloads those `.vsix` bundles from Open VSX and unpacks the server + JDT
# extension jars into
#
#     ${TETRAVIM_JVM_LSP_DIR:-$HOME/.local/share/nvim/tetravim/jvm-lsp}/
#         quarkus/{server,jars}/
#         microprofile/{server,jars}/
#
# which is exactly the layout `lua/tetravim/util/jvm_frameworks.lua` resolves
# and `lsp-quarkus.lua` feeds to quarkus.nvim / microprofile.nvim.
#
# Best-effort: a download or tooling failure prints a warning and exits 0 so
# it never blocks a bootstrap run. It is idempotent -- an up-to-date install
# is skipped unless `--force` is passed.
#
# Usage:
#   bash scripts/fetch-jvm-lsp-jars.sh [--force]
#
# Env overrides:
#   TETRAVIM_JVM_LSP_DIR         target directory (default above)
#   TETRAVIM_QUARKUS_VERSION     pin the vscode-quarkus version
#   TETRAVIM_MICROPROFILE_VERSION pin the vscode-microprofile version

set -uo pipefail

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

DIR="${TETRAVIM_JVM_LSP_DIR:-$HOME/.local/share/nvim/tetravim/jvm-lsp}"
QUARKUS_VERSION="${TETRAVIM_QUARKUS_VERSION:-latest}"
MICROPROFILE_VERSION="${TETRAVIM_MICROPROFILE_VERSION:-latest}"

log() { printf '[fetch-jvm-lsp-jars] %s\n' "$*"; }
warn() { printf '[fetch-jvm-lsp-jars] WARNING: %s\n' "$*" >&2; }

for bin in curl unzip; do
	if ! command -v "$bin" >/dev/null 2>&1; then
		warn "'$bin' not found on \$PATH -- cannot fetch Quarkus/MicroProfile jars. Skipping."
		exit 0
	fi
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# resolve_download <namespace> <name> <version>  -> prints "<resolved_version> <url>"
resolve_download() {
	local ns="$1" name="$2" ver="$3" meta
	meta="$(curl -fsSL "https://open-vsx.org/api/${ns}/${name}/${ver}" 2>/dev/null)" || return 1
	local url rver
	url="$(printf '%s' "$meta" | sed -n 's/.*"download"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
	rver="$(printf '%s' "$meta" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
	[ -n "$url" ] || return 1
	printf '%s %s\n' "${rver:-$ver}" "$url"
}

# fetch_extension <slug> <namespace> <name> <version>
fetch_extension() {
	local slug="$1" ns="$2" name="$3" ver="$4"
	local dest="$DIR/$slug"
	local stamp="$dest/.version"

	local resolved url rver
	resolved="$(resolve_download "$ns" "$name" "$ver")" || {
		warn "could not resolve $ns.$name ($ver) on Open VSX -- skipping."
		return 1
	}
	rver="${resolved%% *}"
	url="${resolved#* }"

	if [ "$FORCE" -eq 0 ] && [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$rver" ]; then
		log "$slug: already at $rver -- skipping (use --force to re-download)."
		return 0
	fi

	log "$slug: downloading $name $rver ..."
	local vsix="$TMP/$slug.vsix"
	curl -fsSL -o "$vsix" "$url" || {
		warn "download failed for $url -- skipping $slug."
		return 1
	}

	local unpack="$TMP/$slug"
	rm -rf "$unpack"
	unzip -qq "$vsix" 'extension/server/*' 'extension/jars/*' -d "$unpack" || {
		warn "unzip failed for $slug -- skipping."
		return 1
	}

	if [ ! -d "$unpack/extension/server" ]; then
		warn "$slug: no extension/server/ in the vsix -- skipping."
		return 1
	fi

	rm -rf "$dest"
	mkdir -p "$dest"
	mv "$unpack/extension/server" "$dest/server"
	[ -d "$unpack/extension/jars" ] && mv "$unpack/extension/jars" "$dest/jars" || mkdir -p "$dest/jars"
	printf '%s\n' "$rver" >"$stamp"
	log "$slug: installed $rver -> $dest"
	return 0
}

mkdir -p "$DIR"

RC=0
fetch_extension quarkus redhat vscode-quarkus "$QUARKUS_VERSION" || RC=1
fetch_extension microprofile redhat vscode-microprofile "$MICROPROFILE_VERSION" || RC=1

if [ "$RC" -eq 0 ]; then
	log "Done. Quarkus / MicroProfile language servers are ready under $DIR."
	log "Verify with:  nvim +'checkhealth tetravim'"
else
	warn "One or more bundles were not installed (see warnings above). Quarkus/MicroProfile"
	warn "completion stays disabled until this succeeds; the rest of TetraVim is unaffected."
fi
exit 0
