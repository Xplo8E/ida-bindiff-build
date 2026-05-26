# BinDiff for IDA 9.3

This repository builds the Google BinDiff and BinExport IDA plugins against the
IDA Pro 9.3 SDK.

The local build script pins the upstream repositories to the commits used by the
workflow:

```text
google/bindiff   1c908013e111ca9a36a3e0a182bab13f963f9658
google/binexport bdb8c4430549e69d4a9a7531c59b197f3a0757e6
HexRaysSA/ida-sdk v9.3.0-release
```

## Local Build

Prerequisites:

```text
cmake
ninja
git
python3
IDA Professional 9.3 installed at /Applications/IDA Professional 9.3.app
```

Build only:

```bash
scripts/build_ida93_plugins.sh --reset-sources
```

Build from a clean CMake directory:

```bash
scripts/build_ida93_plugins.sh --reset-sources --clean
```

Build and install into the IDA 9.3 app bundle:

```bash
scripts/build_ida93_plugins.sh --reset-sources --install
```

Build, install, and force the per-user IDA plugin links to point at the freshly
built IDA 9.3 plugins:

```bash
scripts/build_ida93_plugins.sh --reset-sources --install --user-links
```

`--reset-sources` intentionally discards local edits inside the checked-out
upstream source trees before applying this repository's BinExport patch. Use it
for the normal BinDiff/BinExport plugin build.

The user-link step is useful if the official BinDiff DMG created older plugin
symlinks under `~/.idapro/plugins`. Those older binaries can fail in IDA 9.3
with errors like:

```text
symbol not found in flat namespace '_get_frame'
symbol not found in flat namespace '_get_enum_name2'
```

## Outputs

The normal local build writes:

```text
build/ida93/ida/bindiff8_ida64.dylib
build/ida93/_deps/binexport-build/ida/binexport12_ida64.dylib
build/ida93/bindiff
build/ida93/tools/bindiff_launcher_macos
build/ida93/tools/bindiff_config_setup
```

When installed into the default IDA app bundle:

```text
/Applications/IDA Professional 9.3.app/Contents/MacOS/plugins/bindiff8_ida64.dylib
/Applications/IDA Professional 9.3.app/Contents/MacOS/plugins/binexport12_ida64.dylib
```

## Headless Usage

Export a `.BinExport` from an IDB:

```bash
cd "/Applications/IDA Professional 9.3.app/Contents/MacOS"
./idat -A \
  -S'/Users/vinay/tmp/BinDiff-for-ida/tools/binexport_ida.py /tmp/primary.BinExport' \
  /path/to/primary.i64
```

Run BinDiff on two `.BinExport` files:

```bash
build/ida93/bindiff \
  --primary=/tmp/primary.BinExport \
  --secondary=/tmp/secondary.BinExport \
  --output_dir=/tmp/bindiff-out \
  --output_format=bin,log
```

This produces a `.BinDiff` SQLite result and a text `.results` report.
