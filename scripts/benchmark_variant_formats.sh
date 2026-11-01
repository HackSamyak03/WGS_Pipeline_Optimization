#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BAM="results/alignment/chr22_pipeline_bwa3_sort1.bam"
REF="data/reference/chr22.GRCh38.fa"
BASE="benchmarks/variant_calling/run_20261101_092712/raw.vcf"

OUTDIR="benchmarks/variant_calling/format_benchmark"
RESULTS="$OUTDIR/format_benchmark_results.csv"

mkdir -p "$OUTDIR"

for cmd in bcftools sha256sum; do
    command -v "$cmd" >/dev/null || {
        echo "ERROR: $cmd is missing."
        exit 1
    }
done

[[ -x /usr/bin/time && -f "$BAM" && -f "$REF" && -f "$BASE" ]] || {
    echo "ERROR: Required tool or input file is missing."
    exit 1
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

BASE_HASH=$(bcftools view -H "$BASE" | sha256sum | awk '{print $1}')
BASE_COUNT=$(bcftools view -H "$BASE" | wc -l)

echo "Baseline records: $BASE_COUNT"
echo "Baseline hash: $BASE_HASH"

echo "config,repeat,elapsed_seconds,user_seconds,system_seconds,cpu_percent,max_rss_kb,exit_status,records,records_sha256,output_bytes" > "$RESULTS"

export BAM REF WORK_DIR

for config in A B C D E; do
    for repeat in 1 2 3; do

        OUT="$WORK_DIR/${config}_${repeat}"
        METRIC="$WORK_DIR/metric_${config}_${repeat}.txt"
        export OUT

        echo
        echo "Running configuration $config, repetition $repeat..."

        case "$config" in
            A)
                FORMAT="Uncompressed VCF"
                /usr/bin/time -f '%e,%U,%S,%P,%M,%x' -o "$METRIC" \
                    bash -o pipefail -c '
                    bcftools mpileup -f "$REF" -Ou "$BAM" 2>/dev/null |
                    bcftools call -mv -Ov -o "$OUT"
                    '
                ;;
            B)
                FORMAT="Compressed VCF default threads"
                /usr/bin/time -f '%e,%U,%S,%P,%M,%x' -o "$METRIC" \
                    bash -o pipefail -c '
                    bcftools mpileup -f "$REF" -Ou "$BAM" 2>/dev/null |
                    bcftools call -mv -Oz -o "$OUT"
                    '
                ;;
            C)
                FORMAT="Compressed VCF 2 threads"
                /usr/bin/time -f '%e,%U,%S,%P,%M,%x' -o "$METRIC" \
                    bash -o pipefail -c '
                    bcftools mpileup -f "$REF" -Ou "$BAM" 2>/dev/null |
                    bcftools call -mv --threads 2 -Oz -o "$OUT"
                    '
                ;;
            D)
                FORMAT="Compressed BCF default threads"
                /usr/bin/time -f '%e,%U,%S,%P,%M,%x' -o "$METRIC" \
                    bash -o pipefail -c '
                    bcftools mpileup -f "$REF" -Ou "$BAM" 2>/dev/null |
                    bcftools call -mv -Ob -o "$OUT"
                    '
                ;;
            E)
                FORMAT="Compressed BCF 2 threads"
                /usr/bin/time -f '%e,%U,%S,%P,%M,%x' -o "$METRIC" \
                    bash -o pipefail -c '
                    bcftools mpileup -f "$REF" -Ou "$BAM" 2>/dev/null |
                    bcftools call -mv --threads 2 -Ob -o "$OUT"
                    '
                ;;
        esac

        read -r ELAPSED USER_TIME SYSTEM_TIME CPU RSS EXIT_STATUS < <(
            tr ',' ' ' < "$METRIC"
        )

        # Validate output and compare actual variant records with baseline.
        bcftools view -Ov "$OUT" >/dev/null

        COUNT=$(bcftools view -H "$OUT" | wc -l)
        HASH=$(bcftools view -H "$OUT" | sha256sum | awk '{print $1}')
        SIZE=$(stat -c '%s' "$OUT")

        if [[ "$COUNT" -ne "$BASE_COUNT" || "$HASH" != "$BASE_HASH" ]]; then
            echo "ERROR: Output differs from baseline in configuration $config."
            exit 1
        fi

        echo "$config,$repeat,$ELAPSED,$USER_TIME,$SYSTEM_TIME,$CPU,$RSS,$EXIT_STATUS,$COUNT,$HASH,$SIZE" >> "$RESULTS"

        echo "Format: $FORMAT"
        echo "Runtime: $ELAPSED seconds"
        echo "Peak memory: $RSS KB"
        echo "Records: $COUNT"
        echo "Record equivalence: PASS"

        rm -f "$OUT"
    done
done

echo
echo "===== ALL 15 BENCHMARK RUNS COMPLETED ====="
cat "$RESULTS"

echo
echo "Results saved to: $RESULTS"
