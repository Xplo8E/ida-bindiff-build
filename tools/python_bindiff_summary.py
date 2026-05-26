#!/usr/bin/env python3
import argparse
import csv
import os
from pathlib import Path

from bindiff import BinDiff
from binexport import ProgramBinExport


def split_imports(functions):
    imports = [function for function in functions if function.is_import()]
    normal = [function for function in functions if not function.is_import()]
    return normal, imports


def function_row(function):
    return {
        "address": f"0x{function.addr:x}",
        "name": function.name,
        "blocks": len(function.blocks),
        "parents": len(function.parents),
        "children": len(function.children),
        "import": function.is_import(),
    }


def main():
    parser = argparse.ArgumentParser(
        description="Run/load BinDiff through python-bindiff and summarize function-level results."
    )
    parser.add_argument("primary", help="Primary .BinExport file")
    parser.add_argument("secondary", help="Secondary .BinExport file")
    parser.add_argument("--bindiff-dir", help="Directory containing the bindiff executable")
    parser.add_argument("--result", default="python-bindiff-out/python_api.BinDiff")
    parser.add_argument("--csv", default="python-bindiff-out/python_api_summary.csv")
    parser.add_argument("--force", action="store_true", help="Re-run BinDiff even if result exists")
    args = parser.parse_args()

    if args.bindiff_dir:
        os.environ["BINDIFF_PATH"] = args.bindiff_dir

    result = Path(args.result)
    result.parent.mkdir(parents=True, exist_ok=True)
    csv_path = Path(args.csv)
    csv_path.parent.mkdir(parents=True, exist_ok=True)

    primary = ProgramBinExport(args.primary)
    secondary = ProgramBinExport(args.secondary)
    diff = BinDiff.from_binexport_files(primary, secondary, result.as_posix(), override=args.force)
    if diff is None:
        raise SystemExit("BinDiff failed")

    primary_unmatched = diff.primary_unmatched_function()
    secondary_unmatched = diff.secondary_unmatched_function()
    primary_unmatched_normal, primary_unmatched_imports = split_imports(primary_unmatched)
    secondary_unmatched_normal, secondary_unmatched_imports = split_imports(secondary_unmatched)

    function_similarity_changes = []
    for function1, function2, match in diff.iter_function_matches():
        if match.similarity < 1.0:
            function_similarity_changes.append(
                {
                    "similarity": match.similarity,
                    "confidence": match.confidence,
                    "algorithm": match.algorithm.name,
                    "primary_address": f"0x{match.address1:x}",
                    "primary_name": match.name1,
                    "secondary_address": f"0x{match.address2:x}",
                    "secondary_name": match.name2,
                    "primary_blocks": len(function1.blocks),
                    "secondary_blocks": len(function2.blocks),
                    "primary_children": len(function1.children),
                    "secondary_children": len(function2.children),
                }
            )
    function_similarity_changes.sort(key=lambda row: (row["similarity"], -row["confidence"]))

    print(f"primary:   {primary.name} {primary.architecture} funcs={len(primary)}")
    print(f"secondary: {secondary.name} {secondary.architecture} funcs={len(secondary)}")
    print(f"similarity={diff.similarity:.6f} confidence={diff.confidence:.6f}")
    print(
        "matched="
        f"{len(diff.function_matches)} function_similarity_lt_1={len(function_similarity_changes)}"
    )
    print(
        "unmatched_primary="
        f"{len(primary_unmatched)} normal={len(primary_unmatched_normal)} imports={len(primary_unmatched_imports)}"
    )
    print(
        "unmatched_secondary="
        f"{len(secondary_unmatched)} normal={len(secondary_unmatched_normal)} imports={len(secondary_unmatched_imports)}"
    )
    print(f"result={result}")

    with csv_path.open("w", newline="") as output:
        writer = csv.DictWriter(
            output,
            fieldnames=[
                "kind",
                "similarity",
                "confidence",
                "algorithm",
                "primary_address",
                "primary_name",
                "secondary_address",
                "secondary_name",
                "primary_blocks",
                "secondary_blocks",
                "primary_children",
                "secondary_children",
                "address",
                "name",
                "blocks",
                "parents",
                "children",
                "import",
            ],
        )
        writer.writeheader()
        for row in function_similarity_changes:
            writer.writerow({"kind": "function_similarity_lt_1", **row})
        for function in primary_unmatched:
            writer.writerow({"kind": "primary_unmatched", **function_row(function)})
        for function in secondary_unmatched:
            writer.writerow({"kind": "secondary_unmatched", **function_row(function)})

    print(f"csv={csv_path}")


if __name__ == "__main__":
    main()
