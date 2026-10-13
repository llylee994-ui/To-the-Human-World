#!/bin/sh
# Verified official Linux Runtime only. No download/install or login is performed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${URHOX_RUNTIME:?Set absolute path to the verified official UrhoXRuntime}"
: "${D3_CLOUD_OUTPUT:?Set a writable runtime log/cache directory outside the source tree}"
mkdir -p "$D3_CLOUD_OUTPUT/home/cache"
export HOME="$D3_CLOUD_OUTPUT/home" XDG_CACHE_HOME="$D3_CLOUD_OUTPUT/home/cache" MESA_SHADER_CACHE_DIR="$D3_CLOUD_OUTPUT/home/cache"
export LIBGL_ALWAYS_SOFTWARE=1 EGL_PLATFORM=surfaceless
cd "$ROOT"
exec "$URHOX_RUNTIME" scripts/main.lua "-tapcode_dir=$ROOT" -skip_login -tool_mode -graphicssurfaceless -recompile_shader -nosound \
 -x "${D3_WIDTH:-1170}" -y "${D3_HEIGHT:-658}" > "$D3_CLOUD_OUTPUT/runtime.log" 2>&1
