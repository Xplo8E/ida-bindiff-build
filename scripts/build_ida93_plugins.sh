#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BINDIFF_REF="${BINDIFF_REF:-1c908013e111ca9a36a3e0a182bab13f963f9658}"
BINEXPORT_REF="${BINEXPORT_REF:-bdb8c4430549e69d4a9a7531c59b197f3a0757e6}"
IDASDK_REF="${IDASDK_REF:-v9.3.0-release}"

BINDIFF_DIR="${BINDIFF_DIR:-$ROOT/bindiff}"
BINEXPORT_DIR="${BINEXPORT_DIR:-$ROOT/binexport}"
IDASDK_DIR="${IDASDK_DIR:-$ROOT/idasdk93}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build/ida93}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
IDA_APP="${IDA_APP:-/Applications/IDA Professional 9.3.app}"
INSTALL=0
INSTALL_USER_LINKS=0
CLEAN=0
RESET_SOURCES=0

ARCH="${ARCH:-}"
if [[ -z "$ARCH" && "$(uname -s)" == "Darwin" ]]; then
  ARCH="$(uname -m)"
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Build BinDiff/BinExport IDA plugins against IDA SDK 9.3.

Options:
  --install              Copy built IDA plugins into the IDA 9.3 app bundle.
  --user-links           Also point ~/.idapro/plugins/*64.dylib at the built 9.3 plugins.
                         Existing files/symlinks are moved to .bak.<timestamp>.
  --ida-app PATH         IDA app path. Default: $IDA_APP
  --arch ARCH            CMAKE_OSX_ARCHITECTURES on macOS. Default: current machine arch.
  --clean                Remove the build directory before configuring.
  --reset-sources        Reset checked-out upstream source trees to the pinned refs.
                         Use this for a vanilla plugin build without local experiments.
  -h, --help             Show this help.

Environment overrides:
  BINDIFF_REF, BINEXPORT_REF, IDASDK_REF
  BINDIFF_DIR, BINEXPORT_DIR, IDASDK_DIR, BUILD_DIR, BUILD_TYPE, IDA_APP, ARCH
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      INSTALL=1
      ;;
    --user-links)
      INSTALL_USER_LINKS=1
      ;;
    --ida-app)
      IDA_APP="$2"
      shift
      ;;
    --arch)
      ARCH="$2"
      shift
      ;;
    --clean)
      CLEAN=1
      ;;
    --reset-sources)
      RESET_SOURCES=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

checkout_repo() {
  local url="$1"
  local dir="$2"
  local ref="$3"

  if [[ ! -d "$dir/.git" ]]; then
    git clone "$url" "$dir"
  fi

  git -C "$dir" fetch --tags origin
  git -C "$dir" checkout "$ref"
  if [[ "$RESET_SOURCES" == "1" ]]; then
    git -C "$dir" reset --hard "$ref"
  fi
}

apply_binexport_patch() {
  local patch="$ROOT/patches/binexport-$BINEXPORT_REF.patch"

  if [[ -f "$patch" ]]; then
    if git -C "$BINEXPORT_DIR" apply --check "$patch" >/dev/null 2>&1; then
      git -C "$BINEXPORT_DIR" apply "$patch"
    else
      echo "BinExport source patch is already applied or not applicable: $patch"
    fi
  fi

  python3 - "$BINEXPORT_DIR/cmake/BinExportDeps.cmake" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = "find_package(Boost 1.83 REQUIRED)"
new = """if(EXISTS "${BOOST_ROOT}/boost/version.hpp")
  set(Boost_FOUND TRUE)
  set(Boost_INCLUDE_DIR "${BOOST_ROOT}")
else()
  find_package(Boost 1.83 REQUIRED)
endif()"""

if new not in text:
    if old not in text:
        raise SystemExit(f"Could not find Boost find_package block in {path}")
    path.write_text(text.replace(old, new))
PY
}

install_plugin() {
  local source="$1"
  local dest_dir="$2"
  local name
  name="$(basename "$source")"

  mkdir -p "$dest_dir"
  cp "$source" "$dest_dir/$name"
  echo "Installed $dest_dir/$name"
}

replace_user_link() {
  local name="$1"
  local target="$2"
  local dir="$HOME/.idapro/plugins"
  local path="$dir/$name"
  local stamp
  stamp="$(date +%Y%m%d_%H%M%S)"

  mkdir -p "$dir"
  if [[ -e "$path" || -L "$path" ]]; then
    if [[ "$(readlink "$path" 2>/dev/null || true)" != "$target" ]]; then
      mv "$path" "$path.bak.$stamp"
    fi
  fi
  ln -sfn "$target" "$path"
  echo "Linked $path -> $target"
}

require_cmd git
require_cmd cmake
require_cmd ninja
require_cmd python3

checkout_repo https://github.com/google/bindiff "$BINDIFF_DIR" "$BINDIFF_REF"
checkout_repo https://github.com/google/binexport "$BINEXPORT_DIR" "$BINEXPORT_REF"
checkout_repo https://github.com/HexRaysSA/ida-sdk "$IDASDK_DIR" "$IDASDK_REF"

apply_binexport_patch

if [[ "$CLEAN" == "1" ]]; then
  rm -rf "$BUILD_DIR"
fi

cmake_args=(
  -S "$BINDIFF_DIR"
  -B "$BUILD_DIR"
  -G Ninja
  "-DCMAKE_BUILD_TYPE=$BUILD_TYPE"
  "-DCMAKE_INSTALL_PREFIX=$BUILD_DIR"
  "-DBINDIFF_BINEXPORT_DIR=$BINEXPORT_DIR"
  "-DIdaSdk_ROOT_DIR=$IDASDK_DIR/src"
  "-DBoost_INCLUDE_DIR=$BINEXPORT_DIR/boost_parts"
  "-DBoost_LIBRARY_DIRS=$BINEXPORT_DIR/boost_parts"
)

if [[ "$(uname -s)" == "Darwin" && -n "$ARCH" ]]; then
  cmake_args+=("-DCMAKE_OSX_ARCHITECTURES=$ARCH")
fi

cmake "${cmake_args[@]}"
cmake --build "$BUILD_DIR" --config "$BUILD_TYPE"
cmake --build "$BUILD_DIR" --target binexport12_ida64.dylib --config "$BUILD_TYPE"

bindiff_plugin="$BUILD_DIR/ida/bindiff8_ida64.dylib"
binexport_plugin="$BUILD_DIR/_deps/binexport-build/ida/binexport12_ida64.dylib"

echo
echo "Built plugins:"
echo "  $bindiff_plugin"
echo "  $binexport_plugin"

if [[ "$INSTALL" == "1" ]]; then
  ida_plugins="$IDA_APP/Contents/MacOS/plugins"
  install_plugin "$bindiff_plugin" "$ida_plugins"
  install_plugin "$binexport_plugin" "$ida_plugins"

  if [[ "$INSTALL_USER_LINKS" == "1" ]]; then
    replace_user_link bindiff8_ida64.dylib "$ida_plugins/bindiff8_ida64.dylib"
    replace_user_link binexport12_ida64.dylib "$ida_plugins/binexport12_ida64.dylib"
  fi
fi
