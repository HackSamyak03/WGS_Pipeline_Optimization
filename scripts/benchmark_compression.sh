#!/usr/bin/env bash
set -euo pipefail

mkdir -p benchmarks logs
OUT="benchmarks/compression_results.csv"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "file,method,threads,run,seconds,input_bytes,output_bytes,integrity" > "$OUT"

for input in data/subset_R*.fastq.gz; do
    name="$(basename "$input" .fastq.gz)"
    gzip -dc "$input" > "$TMP/$name.fastq"
    input_bytes=$(stat -c%s "$TMP/$name.fastq")

    for method in gzip pigz; do
        for run in 1 2 3; do
            output="$TMP/${name}_${method}_${run}.gz"

            if [[ "$method" == "gzip" ]]; then
                threads=1
                start=$(date +%s%N)
                gzip -c "$TMP/$name.fastq" > "$output"
                end=$(date +%s%N)
            else
                threads=2
                start=$(date +%s%N)
                pigz -p "$threads" -c "$TMP/$name.fastq" > "$output"
                end=$(date +%s%N)
            fi

            seconds=$(awk -v s="$start" -v e="$end" \
                'BEGIN {printf "%.6f", (e-s)/1000000000}')
            output_bytes=$(stat -c%s "$output")
            gzip -t "$output"

            # Verify decompressed output matches the original FASTQ.
            if gzip -dc "$output" | cmp -s - "$TMP/$name.fastq"; then
                integrity="PASS"
            else
                integrity="FAIL"
                echo "Integrity check failed: $input ($method, run $run)" >&2
                exit 1
            fi

            echo "$name,$method,$threads,$run,$seconds,$input_bytes,$output_bytes,$integrity" >> "$OUT"
        done
    done
done

echo "Benchmark complete: $OUT"
