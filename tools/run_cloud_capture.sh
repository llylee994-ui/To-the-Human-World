#!/bin/sh
# Official Linux UrhoXRuntime, real GLES software rendering without an X server.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${URHOX_RUNTIME:?Set absolute path to the verified official Linux UrhoXRuntime}"
: "${D3_CLOUD_OUTPUT:?Set absolute writable evidence directory}"
mkdir -p "$D3_CLOUD_OUTPUT/home/cache"
export HOME="$D3_CLOUD_OUTPUT/home"
export XDG_CACHE_HOME="$HOME/cache"
export MESA_SHADER_CACHE_DIR="$HOME/cache"
export LIBGL_ALWAYS_SOFTWARE=1 EGL_PLATFORM=surfaceless
export D3_CLOUD_CAPTURE="$D3_CLOUD_OUTPUT/baseline.png"
cd "$ROOT"
timeout 960 "$URHOX_RUNTIME" scripts/cloud_capture.lua \
  "-tapcode_dir=$ROOT" -skip_login -tool_mode -graphicssurfaceless -recompile_shader -nosound \
  -x 1170 -y 658 > "$D3_CLOUD_OUTPUT/baseline.log" 2>&1
