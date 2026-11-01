#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BAM="results/alignment/chr22_pipeline_bwa3_sort1.bam"
REF="data/reference/chr22.GRCh38.fa"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
OUTDIR="benchmarks/variant_calling/run_${RUN_ID}"

for cmd in bcftools samtools sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: $cmd is not installed."
        exit 1
    }
done

if [[ ! -f "$BAM" || ! -f "$REF" ]]; then
    echo "ERROR: Input BAM or reference FASTA is missing."
    exit 1
fi

mkdir -p "$OUTDIR"

export BAM REF OUTDIR

echo "Starting variant-calling benchmark..."
echo "Output directory: $OUTDIR"

# Record software versions
{
    bcftools --version | head -n 1
    samtools --version | head -n 1
} > "$OUTDIR/software_versions.txt"

# Record input checksums
sha256sum "$BAM" "$REF" > "$OUTDIR/input_checksums.sha256"

# Run variant calling and filtering under one resource measurement
/usr/bin/time -v -o "$OUTDIR/resource_usage.txt" bash -c '
set -Eeuo pipefail

bcftools mpileup \
    -f "$REF" \
    -Ou "$BAM" \
    2>"$OUTDIR/mpileup.log" |
bcftools call -mv -Ov \
    -o "$OUTDIR/raw.vcf" \
    2>"$OUTDIR/call.log"

bcftools filter \
    -i "INFO/DP>=5 && QUAL>=20" \
    -Ov \
    -o "$OUTDIR/filtered.vcf" \
    "$OUTDIR/raw.vcf"
'

# Validate VCF files
bcftools view -Ov "$OUTDIR/raw.vcf" >/dev/null
bcftools view -Ov "$OUTDIR/filtered.vcf" >/dev/null

# Count candidate records
RAW_COUNT=$(bcftools view -H "$OUTDIR/raw.vcf" | wc -l)
FILTERED_COUNT=$(bcftools view -H "$OUTDIR/filtered.vcf" | wc -l)

# Generate variant statistics
bcftools stats "$OUTDIR/raw.vcf" > "$OUTDIR/raw_stats.txt"
bcftools stats "$OUTDIR/filtered.vcf" > "$OUTDIR/filtered_stats.txt"

# Save benchmark summary
cat > "$OUTDIR/summary.txt" <<SUMMARY
Variant Calling Benchmark
=========================

Input BAM: $BAM
Reference: $REF

BCFtools version: $(bcftools --version | head -n 1)
SAMtools version: $(samtools --version | head -n 1)

Raw candidate records: $RAW_COUNT
Filtered candidate records: $FILTERED_COUNT

Filter:
INFO/DP >= 5 && QUAL >= 20

VCF validation: PASSED

Resource measurements:
See resource_usage.txt

Input checksums:
See input_checksums.sha256

Interpretation:
These are exploratory candidate calls from a pilot
dataset aligned only to chromosome 22.
They are not validated true variants.
SUMMARY

echo
echo "===== BENCHMARK COMPLETED ====="
cat "$OUTDIR/summary.txt"
echo
echo "Detailed resource measurements: $OUTDIR/resource_usage.txt"
echo "All outputs saved in: $OUTDIR"
