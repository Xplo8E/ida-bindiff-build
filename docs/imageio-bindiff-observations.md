# ImageIO BinDiff / BinExport Observations

Date: 2026-05-26

## Goal

Understand how to use BinExport, BinDiff, `python-binexport`, and `python-bindiff`
against two ImageIO versions, and explain why IDA showed changed matched
functions while an initial Python run reported zero changed matches.

## Key Artifacts

IDA databases:

```text
/Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO.i64
/Users/vinay/research/imageio-frameworks/26.5/ImageIO/ImageIO.i64
```

Correct saved BinExports:

```text
/Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO-26_4_2.BinExport
/Users/vinay/research/imageio-frameworks/26.5/ImageIO/ImageIO_26_5.BinExport
```

Existing IDA/BinDiff result:

```text
/Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO_vs_ImageIO.BinDiff
```

Fresh experiment outputs:

```text
/Users/vinay/tmp/BinDiff-for-ida/idb-export-experiment/ImageIO_26_4_2_from_idb.BinExport
/Users/vinay/tmp/BinDiff-for-ida/idb-export-experiment/ImageIO_26_5_from_idb.BinExport
/Users/vinay/tmp/BinDiff-for-ida/idb-export-experiment/ImageIO_26_4_2_from_idb_vs_ImageIO_26_5_from_idb.BinDiff
/Users/vinay/tmp/BinDiff-for-ida/idb-export-experiment/ImageIO_26_4_2_from_idb_vs_ImageIO_26_5_from_idb.results
```

## Initial Mismatch

The first Python run used these two files:

```text
/Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO.BinExport
/Users/vinay/research/imageio-frameworks/26.5/ImageIO/ImageIO.BinExport
```

That pair produced:

```text
matched=20554
function_similarity_lt_1=0
unmatched_primary=76
unmatched_secondary=76
```

This did not match IDA, where changed matched functions were visible.

The reason: the `26.4.2/ImageIO.BinExport` file was not the same primary
program used by the IDA `.BinDiff` result. It had the same shape as the 26.5
export:

```text
26.4.2/ImageIO.BinExport: total=20630 normal=19359 imports=1271
26.5/ImageIO.BinExport:   total=20630 normal=19359 imports=1271
```

Because both inputs had the same function layout, BinDiff reported all matched
functions with function similarity `1.0`.

## Correct Primary Export

The correct 26.4.2 primary export is:

```text
/Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO-26_4_2.BinExport
```

Its metadata:

```text
total=20609
normal=19341
imports=1268
callgraph_nodes=15731
callgraph_edges=69873
```

The correct 26.5 secondary export is:

```text
/Users/vinay/research/imageio-frameworks/26.5/ImageIO/ImageIO_26_5.BinExport
```

Its metadata:

```text
total=20630
normal=19359
imports=1271
callgraph_nodes=15746
callgraph_edges=69905
```

These counts match the `.BinDiff` file metadata:

```text
file1: normal=19341 library=1268 calls=160575 basicblocks=450419 instructions=2973790
file2: normal=19359 library=1271 calls=160631 basicblocks=450690 instructions=2975505
```

## Existing IDA Result

Querying the existing `.BinDiff` directly:

```bash
sqlite3 /Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO_vs_ImageIO.BinDiff \
"select count(*), sum(similarity < 1.0), min(similarity), max(similarity) from function;"
```

Result:

```text
20529|56|0.132248983433828|1.0
```

So the IDA result contains:

```text
matched functions: 20529
changed matched functions: 56
min similarity: 0.132248983433828
max similarity: 1.0
```

Example changed row from IDA:

```text
0.679481438474051  0.970687769248644  0x1863d19cc  _OUTLINED_FUNCTION_0_25  0x1863dda50  _OUTLINED_FUNCTION_0_25
```

This row was found in the existing `.BinDiff` database.

## Python Libraries

Installed locally in:

```text
/Users/vinay/tmp/BinDiff-for-ida/.venv-python-bindiff
```

Packages:

```text
python-binexport
python-bindiff
```

`python-binexport` loads `.BinExport` files and exposes:

```text
ProgramBinExport
functions
function names
imports
basic blocks
instructions
callgraph
address references
data references
string references
```

`python-bindiff` loads a `.BinDiff` result together with the exact primary and
secondary `.BinExport` files and exposes:

```text
matched functions
unmatched primary functions
unmatched secondary functions
basic block matches
instruction matches
similarity
confidence
matching algorithm
```

Important rule:

```text
python-bindiff must be given the exact BinExport pair used to create the .BinDiff.
```

If the `.BinExport` files do not match the `.BinDiff`, Python can still load
data, but the result will not correspond to what IDA shows.

## Fresh IDB Export Experiment

Exporter script:

```text
/Users/vinay/tmp/BinDiff-for-ida/tools/binexport_ida.py
```

26.4.2 export command:

```bash
cd "/Applications/IDA Professional 9.3.app/Contents/MacOS"
./idat -A \
  -S'/Users/vinay/tmp/BinDiff-for-ida/tools/binexport_ida.py /Users/vinay/tmp/BinDiff-for-ida/idb-export-experiment/ImageIO_26_4_2_from_idb.BinExport' \
  /Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO.i64
```

26.5 export command:

```bash
cd "/Applications/IDA Professional 9.3.app/Contents/MacOS"
./idat -A \
  -S'/Users/vinay/tmp/BinDiff-for-ida/tools/binexport_ida.py /Users/vinay/tmp/BinDiff-for-ida/idb-export-experiment/ImageIO_26_5_from_idb.BinExport' \
  /Users/vinay/research/imageio-frameworks/26.5/ImageIO/ImageIO.i64
```

Note: this required running outside the sandbox. If IDA GUI has the database
open, headless IDA may fail to open/export it. Closing IDA fixed the 26.5 run.

Fresh export metadata:

```text
26.4.2: total=20609 normal=19341 imports=1268 callgraph_nodes=15731 callgraph_edges=69873
26.5:   total=20630 normal=19359 imports=1271 callgraph_nodes=15746 callgraph_edges=69905
```

Fresh diff command:

```bash
build/ida93/bindiff \
  --primary=idb-export-experiment/ImageIO_26_4_2_from_idb.BinExport \
  --secondary=idb-export-experiment/ImageIO_26_5_from_idb.BinExport \
  --output_dir=idb-export-experiment \
  --output_format=bin,log
```

Fresh diff output:

```text
primary:   ImageIO_26_4_2_from_idb: 20609 functions, 160575 calls
secondary: ImageIO_26_5_from_idb: 20630 functions, 160631 calls
matched: 20529 of 20609/20630
Similarity: 98.9772%
Confidence: 99.0599%
```

Fresh `.BinDiff` query:

```text
matched=20529
similarity_lt_1=56
min_similarity=0.132248983433828
max_similarity=1.0
```

This matches the existing IDA result.

## Helper Scripts Added

### `tools/binexport_ida.py`

Headless IDA script that waits for auto-analysis and calls:

```text
BinExportBinary(output_path)
```

Use it with:

```bash
idat -A -S'/path/to/binexport_ida.py /path/to/output.BinExport' /path/to/input.i64
```

### `tools/python_bindiff_summary.py`

Uses `python-binexport` and `python-bindiff`.

Requires:

```text
primary .BinExport
secondary .BinExport
.BinDiff result
```

Useful when the BinExport pair exactly matches the `.BinDiff`.

Example:

```bash
.venv-python-bindiff/bin/python tools/python_bindiff_summary.py \
  --bindiff-dir /Users/vinay/tmp/BinDiff-for-ida/build/ida93 \
  --result /Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO_vs_ImageIO.BinDiff \
  --csv python-bindiff-out/python_exact_ida_pair.csv \
  /Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO-26_4_2.BinExport \
  /Users/vinay/research/imageio-frameworks/26.5/ImageIO/ImageIO_26_5.BinExport
```

Expected output:

```text
primary:   ImageIO ARM-64 funcs=20609
secondary: ImageIO ARM-64 funcs=20630
similarity=0.990000 confidence=0.991000
matched=20529 function_similarity_lt_1=56
unmatched_primary=80 normal=5 imports=75
unmatched_secondary=101 normal=23 imports=78
```

### `tools/bindiff_sqlite_summary.py`

Reads a `.BinDiff` SQLite database directly.

Does not require `.BinExport` files.

Best for extracting exactly what IDA shows when the matching `.BinExport` pair
is missing or uncertain.

Example:

```bash
python3 tools/bindiff_sqlite_summary.py \
  --csv python-bindiff-out/ida_existing_changed.csv \
  /Users/vinay/research/imageio-frameworks/26.4.2/ImageIO/ImageIO_vs_ImageIO.BinDiff
```

## Final Takeaways

1. `.BinExport` inputs are useful for fresh, reproducible headless diffs.
2. `.BinDiff` is the authoritative artifact for what IDA is currently showing.
3. `python-bindiff` needs the exact `.BinExport` pair used to create the `.BinDiff`.
4. If Python reports zero changed matches while IDA shows changed matches, first check whether the `.BinExport` files match the `.BinDiff` metadata.
5. The correct ImageIO 26.4.2 export has `19341` normal functions, not `19359`.
6. Fresh IDB export plus fresh BinDiff reproduces the IDA result: `20529` matched functions and `56` function matches with similarity below `1.0`.
