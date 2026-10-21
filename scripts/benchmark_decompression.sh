#!/usr/bin/env bash
set -euo pipefail

mkdir -p benchmarks
OUT="benchmarks/decompression_results.csv"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "file,method,threads,run,seconds,integrity" > "$OUT"

for input in data/subset_R*.fastq.gz; do
    name=$(basename "$input" .fastq.gz)
    gzip -dc "$input" > "$TMP/reference.fastq"

    for method in gzip pigz; do
        for run in 1 2 3; do
            if [[ "$method" == "gzip" ]]; then
                cmd=(gzip -dc "$input")
                threads=1
            else
                cmd=(pigz -dc -p 2 "$input")
                threads=2
            fi

            start=$(date +%s%N)
            "${cmd[@]}" > "$TMP/output.fastq"
            end=$(date +%s%N)

            seconds=$(awk -v s="$start" -v e="$end" \
                'BEGIN {printf "%.6f", (e-s)/1000000000}')

            if cmp -s "$TMP/reference.fastq" "$TMP/output.fastq"; then
                integrity=PASS
            else
                integrity=FAIL
                exit 1
            fi

            echo "$name,$method,$threads,$run,$seconds,$integrity" >> "$OUT"
        done
    done
done

echo "Saved: $OUT"
column -s, -t < "$OUT"
