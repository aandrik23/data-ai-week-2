import argparse
from pathlib import Path
import sys
import pandas as pd

DEFAULT_FILES = ["customers.csv", "billing.csv", "support_tickets.csv", "usage.csv"]

def clean_one_csv(src: Path, dst: Path) -> dict:
    # Read everything as text so we don't accidentally coerce values for customers.csv, billing.csv and support_tickets.csv files.
    # 'utf-8-sig' handles files that start with a BOM; if that still fails, we try latin-1.
    try:
        df = pd.read_csv(
            src,
            dtype=str,
            keep_default_na=True,
            na_values=["", " ", "NA", "N/A", "na", "n/a", "null", "NULL", "NaN"],
            encoding="utf-8-sig"
        )
    except UnicodeDecodeError:
        df = pd.read_csv(
            src,
            dtype=str,
            keep_default_na=True,
            na_values=["", " ", "NA", "N/A", "na", "n/a", "null", "NULL", "NaN"],
            encoding="latin-1"
        )

    original_rows = len(df)

    # Trim whitespace from all string cells.
    df = df.applymap(lambda x: x.strip() if isinstance(x, str) else x)

    # After trimming, convert empty strings to pandas NA so dropna can see them.
    df = df.replace({"": pd.NA})

    # Drop any row that has at least one missing value in any column.
    cleaned_df = df.dropna(how="any")
    cleaned_rows = len(cleaned_df)
    dropped_rows = original_rows - cleaned_rows

    # Ensure output directory exists.
    dst.parent.mkdir(parents=True, exist_ok=True)

    # Write cleaned file with the same columns and order.
    cleaned_df.to_csv(dst, index=False, encoding="utf-8")

    return {
        "file": src.name,
        "input_rows": original_rows,
        "output_rows": cleaned_rows,
        "dropped_rows": dropped_rows,
        "output_path": str(dst)
    }

def clean_usage_csv(src:Path,dst: Path) -> dict:
    # Clean usage.csv file by filling empty cells with the median of the column
    try:
        df= pd.read_csv(
            src,
            dtype=str,
            keep_default_na=True,
            na_values=["", " ", "NA", "N/A", "na", "n/a", "null", "NULL", "NaN"],
            encoding="utf-8-sig"
        )

    except UnicodeDecodeError:
        df = pd.read_csv(
            src,
            dtype=str,
            keep_default_na=True,
            na_values=[""," ", "NA", "N/A", "na", "n/a", "null", "NULL", "NaN"],
            encoding="latin-1"
        )
    
    # Convert to numeric for median calculation
    df["data_usage_gb"] = pd.to_numeric(df["data_usage_gb"], errors='coerce')

    original_missing = df["data_usage_gb"].isna().sum()
    median_value = df["data_usage_gb"].median()

    df["data_usage_gb"]= df["data_usage_gb"].fillna(median_value)
    cleaned_missing = df["data_usage_gb"].isna().sum()

    dst.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(dst, index=False, encoding="utf-8")

    return {
    "file": src.name,
    "filled_cells": original_missing - cleaned_missing,
    "median_value": median_value,
    "output_path": str(dst)
}

def main(argv=None):
    parser = argparse.ArgumentParser(description="Clean CSV files.")
    parser.add_argument("--files", nargs="*", default=DEFAULT_FILES,
                        help="List of CSV filenames to clean (default: customers.csv billing.csv support_tickets.csv).")
    parser.add_argument("--input-dir", default=".",
                        help="Directory containing the input CSV files (default: current directory).")
    parser.add_argument("--output-dir", default=None,
                        help="Directory to write cleaned CSVs (default: same as input-dir).")
    args = parser.parse_args(argv)

    input_dir = Path(args.input_dir).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve() if args.output_dir else input_dir

    summaries = []
    for fname in args.files:
        src = input_dir / fname
        if not src.exists():
            print(f"[skip] {src} not found.", file=sys.stderr)
            continue
        dst = output_dir / (src.stem + "_cleaned.csv")
        if fname == "usage.csv":
            stats = clean_usage_csv(src, dst)
            print(f"[ok] {stats['file']}: filled {stats['filled_cells']} empty cells "
                  f"with median={stats['median_value']} -> {stats['output_path']}")
        else:
            stats = clean_one_csv(src, dst)
            print(f"[ok] {stats['file']}: {stats['input_rows']} -> {stats['output_rows']} "
                  f"(dropped {stats['dropped_rows']}) -> {stats['output_path']}")

if __name__ == "__main__":
    raise SystemExit(main())
