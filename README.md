# WGS Pipeline Optimization

## Overview
This project investigates practical performance optimizations for
Whole Genome Sequencing (WGS) data processing on a resource-constrained
computer using Linux on Windows (WSL2).

The initial experiments evaluate compression, decompression, quality
control, and read alignment using BWA and SAMtools.

## Environment
- Operating system: Ubuntu on WSL2
- Host memory: 8 GB RAM
- Available CPU threads: 4
- Pilot data: 100,000 paired-end read pairs
- Read length: 151 bp
- Candidate reference: GRCh38 chromosome 22
- Tools: BWA, SAMtools, FastQC, gzip, pigz, SeqKit

## Preliminary Results

### Compression
The initial compression experiment compared gzip with pigz using
two pigz threads. The measured combined runtime was approximately
11.90 seconds for gzip and 3.68 seconds for pigz.

This corresponds to an observed speedup of approximately 3.24x
for this pilot workload.

### Decompression
The initial combined decompression runtime was approximately
0.75 seconds for gzip and 0.51 seconds for pigz, an observed
speedup of approximately 1.47x.

### BWA Alignment and Sorting
The complete BWA alignment and SAMtools sorting pipeline was
benchmarked with one and two BWA threads.

| BWA threads | Run 1 (s) | Run 2 (s) | Mean runtime (s) |
|---|---:|---:|---:|
| 1 | 156.26 | 158.00 | 157.13 |
| 2 | 93.85 | 95.36 | 94.61 |

The observed mean runtime reduction with two BWA threads was
approximately 39.8%, corresponding to a speedup of approximately
1.66x.

Mean peak resident memory was approximately 280 MiB for one thread
and 420 MiB for two threads.

Both repeated pipeline outputs passed `samtools quickcheck`.

## Important Limitations
- These are small pilot experiments, not whole-genome benchmarks.
- The 100,000 read pairs were aligned against chromosome 22 only.
- The exact original reference build for the source FASTQ files has
  not been established; GRCh38 is a candidate reference for this test.
- Only two alignment runs per thread configuration are currently
  available.
- Runtime and memory measurements can vary with system load and cache
  state.
- Results should not be generalized to full WGS workloads without
  larger-scale testing.

## Repository Structure
- `scripts/`: benchmark scripts
- `benchmarks/`: CSV benchmark results
- `results/`: quality-control reports and notes
- `data/`: local input data and reference files (not intended for Git)

## Reproducibility
Review the scripts and CSV files before reproducing the experiments.
Required tools include BWA, SAMtools, FastQC, gzip, pigz, and SeqKit.

## Next Steps
- Repeat and extend the benchmark runs.
- Evaluate safe pipeline-level parallelism.
- Measure CPU, memory, and I/O bottlenecks.
- Test larger datasets within available hardware limits.
- Document exact tool versions and reference provenance.
