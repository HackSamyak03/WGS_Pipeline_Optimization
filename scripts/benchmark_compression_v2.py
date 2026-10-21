import csv
import gzip
import subprocess
import time
from pathlib import Path

root = Path.home() / "wgs-optimization"
data = root / "data"
results = root / "benchmarks" / "compression_results_v2.csv"
results.parent.mkdir(exist_ok=True)

rows = []

for source in sorted(data.glob("subset_R*.fastq.gz")):
    name = source.name.removesuffix(".fastq.gz")

    # Decompress once outside the timed region.
    with gzip.open(source, "rb") as f:
        raw = f.read()

    raw_path = results.parent / f"{name}.benchmark_input.fastq"
    raw_path.write_bytes(raw)

    for method, threads in [("gzip", 1), ("pigz", 2)]:
        for run in range(1, 4):
            output = results.parent / f"{name}_{method}_{run}.gz"
            command = (
                ["gzip", "-n", "-c", str(raw_path)]
                if method == "gzip"
                else ["pigz", "-n", "-p", str(threads), "-c", str(raw_path)]
            )

            start = time.perf_counter()
            with output.open("wb") as out:
                subprocess.run(command, stdout=out, check=True)
            elapsed = time.perf_counter() - start

            # Verify byte-for-byte equivalence after decompression.
            with gzip.open(output, "rb") as f:
                valid = f.read() == raw

            if not valid:
                raise RuntimeError(f"Integrity check failed: {output}")

            rows.append({
                "file": name,
                "method": method,
                "threads": threads,
                "run": run,
                "seconds": round(elapsed, 6),
                "input_bytes": len(raw),
                "output_bytes": output.stat().st_size,
                "integrity": "PASS",
            })

    raw_path.unlink()

with results.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

print(f"Saved: {results}")
for row in rows:
    print(row)
