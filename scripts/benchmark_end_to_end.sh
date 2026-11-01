#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/wgs-optimization"
cd "$ROOT"

REF="data/reference/chr22.GRCh38.fa"
R1="data/subset_R1.fastq.gz"
R2="data/subset_R2.fastq.gz"

RUN_DIR="benchmarks/end_to_end/run_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RUN_DIR"

CSV="$RUN_DIR/results.csv"

echo "config,repeat,bwa_threads,sort_threads,wall_time,max_rss_kb,records,variant_hash,bam_bytes,vcf_bytes" > "$CSV"

run_one() {
    local config="$1"
    local repeat="$2"
    local bwa_threads="$3"
    local sort_threads=1

    local prefix="$RUN_DIR/${config}_repeat${repeat}"
    local bam="${prefix}.bam"
    local vcf="${prefix}.vcf.gz"
    local metrics="${prefix}.time.txt"

    echo "===== Running $config repetition $repeat ====="

    export REF R1 R2 bam vcf bwa_threads sort_threads prefix

    /usr/bin/time -v -o "$metrics" bash -c '
        set -o pipefail

        bwa mem -K 10000000 -t "$bwa_threads" "$REF" "$R1" "$R2" \
            2>"${prefix}.bwa.log" |
        samtools sort -@ "$sort_threads" -o "$bam" - \
            2>"${prefix}.sort.log"

        bcftools mpileup -f "$REF" -Ou "$bam" \
            2>"${prefix}.mpileup.log" |
        bcftools call -mv -Oz -o "$vcf" \
            2>"${prefix}.call.log"
    '

    samtools quickcheck "$bam"
    bcftools view -Ov "$vcf" >/dev/null

    local wall_time
    wall_time=$(awk -F ': ' '/Elapsed \(wall clock\)/ {print $2}' "$metrics")

    local max_rss
    max_rss=$(awk '/Maximum resident set size/ {print $6}' "$metrics")

    local records
    records=$(bcftools view -H "$vcf" | wc -l)

    local hash
    hash=$(bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t[%GT]\n' "$vcf" |
        sha256sum | awk '{print $1}')

    local bam_bytes
    bam_bytes=$(stat -c %s "$bam")

    local vcf_bytes
    vcf_bytes=$(stat -c %s "$vcf")

    echo "$config,$repeat,$bwa_threads,$sort_threads,$wall_time,$max_rss,$records,$hash,$bam_bytes,$vcf_bytes" >> "$CSV"

    echo "Completed: $config repetition $repeat"
    echo "Wall time: $wall_time | Peak RSS: $max_rss KB"
    echo "Variant records: $records"
}

# Alternate configurations to reduce simple order bias.
run_one baseline 1 1
run_one optimized 1 3
run_one baseline 2 1
run_one optimized 2 3

echo
echo "===== BENCHMARK COMPLETE ====="
echo "Results: $CSV"
cat "$CSV"
