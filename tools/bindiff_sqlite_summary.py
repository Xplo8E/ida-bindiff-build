#!/usr/bin/env python3
import argparse
import csv
import sqlite3
from pathlib import Path


def query_all(connection, sql, args=()):
    connection.row_factory = sqlite3.Row
    return connection.execute(sql, args).fetchall()


def main():
    parser = argparse.ArgumentParser(
        description="Summarize a BinDiff .BinDiff SQLite result without requiring matching .BinExport files."
    )
    parser.add_argument("bindiff", help="Existing .BinDiff result file")
    parser.add_argument("--csv", default="python-bindiff-out/bindiff_sqlite_changed.csv")
    parser.add_argument("--limit", type=int, default=0, help="Print only first N changed rows; 0 prints all")
    args = parser.parse_args()

    bindiff_path = Path(args.bindiff)
    csv_path = Path(args.csv)
    csv_path.parent.mkdir(parents=True, exist_ok=True)

    connection = sqlite3.connect(bindiff_path)

    files = query_all(connection, "select * from file order by id")
    stats = query_all(
        connection,
        """
        select
          count(*) as matched,
          min(similarity) as min_similarity,
          max(similarity) as max_similarity,
          sum(case when similarity < 1.0 then 1 else 0 end) as changed
        from function
        """,
    )[0]

    changed = query_all(
        connection,
        """
        select
          f.similarity,
          f.confidence,
          f.flags,
          printf('0x%x', f.address1) as primary_address,
          f.name1 as primary_name,
          printf('0x%x', f.address2) as secondary_address,
          f.name2 as secondary_name,
          coalesce(a.name, f.algorithm) as algorithm,
          f.basicblocks,
          f.edges,
          f.instructions
        from function f
        left join functionalgorithm a on a.id = f.algorithm
        where f.similarity < 1.0
        order by f.similarity asc, f.confidence desc, f.address1 asc
        """,
    )

    print(f"bindiff={bindiff_path}")
    for row in files:
        print(
            "file{0}: name={1} hash={2} normal={3} library={4} calls={5} "
            "basicblocks={6} instructions={7}".format(
                row["id"],
                row["filename"],
                row["hash"],
                row["functions"],
                row["libfunctions"],
                row["calls"],
                row["basicblocks"],
                row["instructions"],
            )
        )
    print(
        "matched={matched} similarity_lt_1={changed} min_similarity={min_similarity} "
        "max_similarity={max_similarity}".format(**dict(stats))
    )

    with csv_path.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=changed[0].keys() if changed else [])
        if changed:
            writer.writeheader()
            for row in changed:
                writer.writerow(dict(row))

    print(f"csv={csv_path}")
    rows_to_print = changed if args.limit == 0 else changed[: args.limit]
    for row in rows_to_print:
        print(
            "{similarity:.6f}\t{confidence:.6f}\t{primary_address}\t{primary_name}\t"
            "{secondary_address}\t{secondary_name}\t{algorithm}".format(**dict(row))
        )


if __name__ == "__main__":
    main()
