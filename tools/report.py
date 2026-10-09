#!/usr/bin/env python3
"""Generate the analytics block of README.md from reports/results.json.
Usage: python3 tools/run tests first, then: python3 tools/report.py"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = json.load(open(os.path.join(ROOT, "reports", "results.json")))
src, dist, cov = res["src"], res["dist"], res["coverage"]

total_lines = sum(m["lines"] for m in cov.values())
total_cov = sum(m["covered"] for m in cov.values())
pct = lambda a, b: f"{100.0 * a / b:.1f}%" if b else "n/a"
bundle = os.path.getsize(os.path.join(ROOT, "dist", "MaUI.lua")) / 1024

out = []
out.append("| Metric | Value |\n|---|---|")
out.append(f"| Checks (source modules) | **{src['passed']} passed**, {src['failed']} failed |")
out.append(f"| Checks (bundled `dist/MaUI.lua`) | **{dist['passed']} passed**, {dist['failed']} failed |")
out.append(f"| Test sections | {len(src['sections'])} |")
out.append(f"| Line coverage | **{pct(total_cov, total_lines)}** ({total_cov}/{total_lines} executable lines) |")
out.append(f"| Modules | {len(cov)} |")
out.append(f"| Bundle size | {bundle:.1f} KB |")
out.append("")
out.append("### Benchmarks (headless Roblox mock, not real client numbers)\n")
out.append("| Benchmark | Result |\n|---|---|")
for k, v in sorted(dist.get("metrics", {}).items()):
    unit = dist.get("metricUnits", {}).get(k, "")
    out.append(f"| `{k}` | {v} {unit} |")
out.append("")
out.append("### Coverage by module\n")
out.append("| Module | Covered | Lines |\n|---|---|---|")
for name, m in sorted(cov.items(), key=lambda kv: kv[0]):
    out.append(f"| `{name}` | {pct(m['covered'], m['lines'])} | {m['lines']} |")
block = "\n".join(out)

path = os.path.join(ROOT, "README.md")
text = open(path).read()
new, n = re.subn(r"(<!-- ANALYTICS:START -->).*?(<!-- ANALYTICS:END -->)",
                 lambda m: m.group(1) + "\n" + block + "\n" + m.group(2), text, flags=re.S)
if n == 0:
    sys.exit("README.md has no ANALYTICS markers")
open(path, "w").write(new)
print("README analytics updated")
