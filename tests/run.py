#!/usr/bin/env python3
"""Headless test runner for MaUI (LuaJIT via lupa + a Roblox API mock).

    python3 build.py && python3 tests/run.py            # both passes
    python3 tests/run.py --target src --only 05         # one pass, one spec (prefix match)

Pass 1 ("src")  runs every spec against the individual source modules and records line coverage.
Pass 2 ("dist") runs the same specs against the shipped bundle dist/MaUI.lua.
Writes reports/results.json (consumed by tools/report.py). Exit code 1 if anything fails.
Requires: pip install lupa
"""
import argparse
import json
import re
import sys
import time
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "tests"
SRC = ROOT / "src"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def run_pass(target: str, only: str | None, verbose: bool) -> dict:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('io.stdout:setvbuf("no")')
    # watchdog: an infinite loop prints its stack instead of hanging forever
    lua.execute(
        """
        local deadline = os.clock() + 120
        debug.sethook(function()
            if os.clock() > deadline then
                io.stderr:write(debug.traceback("TIMEOUT (infinite loop?)", 2), "\\n")
                os.exit(2)
            end
        end, "", 100000)
        """
    )
    g = lua.globals()
    g.TARGET = target
    g.COVERAGE = target == "src"
    g.DIST_SOURCE = read(ROOT / "dist" / "MaUI.lua")

    def src_read(name):
        path = SRC / (name + ".lua")
        return read(path) if path.exists() else None

    g.SRC_READ = src_read
    lua.execute(read(TESTS / "mock_roblox.lua"))
    for extra in sorted((TESTS / "mock_extras").glob("*.lua")):  # per-feature additions to the mock
        lua.execute(read(extra))
    lua.execute("T = (function() " + read(TESTS / "framework.lua") + " end)()")
    lua.execute("H = (function() " + read(TESTS / "helpers.lua") + " end)()")
    if target == "src":
        lua.execute("H.enableCoverage()")

    specs = sorted((TESTS / "specs").glob("*.lua"))
    if only:
        specs = [s for s in specs if s.name.startswith(only)]
    started = time.time()
    for spec in specs:
        g.SPEC_NAME = spec.name
        g.SPEC_SOURCE = read(spec)
        lua.execute(
            """
            local chunk, err = loadstring(SPEC_SOURCE, "=" .. SPEC_NAME)
            if not chunk then
                T.section(SPEC_NAME); T.check("spec compiles", false, err)
            else
                local ok, failure = xpcall(chunk, debug.traceback)
                if not ok then
                    T.section(SPEC_NAME .. " (crashed)"); T.check("spec ran to the end", false, failure)
                end
            end
            pcall(H.destroyAll)
            M.queue = {} -- timers of a finished spec must not leak into the next one
            if #M.threadErrors > 0 then
                T.section(SPEC_NAME .. " (background threads)")
                for _, e in ipairs(M.threadErrors) do T.check("no error in a background thread", false, e) end
                M.threadErrors = {}
            end
            """
        )
    elapsed = time.time() - started

    coverage = {}
    if target == "src":
        hits = lua.eval("M.coverage")
        for key in hits:
            name = str(key)[1:]
            if not name.endswith(".lua"):
                continue
            coverage[name[:-4]] = sorted(int(line) for line in hits[key])

    report = json.loads(lua.eval("T.toJson()"))
    report["target"] = target
    report["seconds"] = round(elapsed, 2)
    report["coverageLines"] = coverage
    return report


CODE_LINE = re.compile(r"\S")


def executable_lines(text: str) -> set[int]:
    """Heuristic: non-blank lines that are not comments or pure block closers."""
    lines = set()
    in_block = False
    for number, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if in_block:
            if "]]" in stripped:
                in_block = False
            continue
        if stripped.startswith("--[[") and "]]" not in stripped:
            in_block = True
            continue
        if not stripped or stripped.startswith("--"):
            continue
        if re.fullmatch(r"(end|else|\)|\}|\},?|end\)|end,|end\)\)|\)\)|\]\])[,;]?", stripped):
            continue
        lines.add(number)
    return lines


def coverage_table(report: dict) -> dict:
    table = {}
    for path in sorted(SRC.rglob("*.lua")):
        name = path.relative_to(SRC).with_suffix("").as_posix()
        code = executable_lines(read(path))
        hit = {line for line in report["coverageLines"].get(name, []) if line in code}
        table[name] = {"lines": len(code), "covered": len(hit), "missed": sorted(code - hit)}
    return table


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=["src", "dist"], help="run a single pass")
    parser.add_argument("--only", help="spec file prefix, e.g. 05")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--missed", action="store_true", help="print uncovered lines per module")
    args = parser.parse_args()

    passes = [args.target] if args.target else ["src", "dist"]
    results = {}
    failed = 0
    for target in passes:
        print(f"\n=== {target} ===")
        report = run_pass(target, args.only, args.verbose)
        results[target] = report
        for section in report["sections"]:
            mark = "ok " if section["failed"] == 0 else "FAIL"
            print(f"  [{mark}] {section['name']}: {section['passed']} passed")
            for failure in section["failures"]:
                print(f"         - {failure}")
        print(f"  {report['passed']} passed, {report['failed']} failed in {report['seconds']}s")
        failed += report["failed"]

    if "src" in results:
        table = coverage_table(results["src"])
        results["coverage"] = table
        total = sum(v["lines"] for v in table.values())
        covered = sum(v["covered"] for v in table.values())
        print(f"\ncoverage (src): {covered}/{total} executable lines = {100 * covered / max(total, 1):.1f}%")
        if args.missed:
            for name, row in table.items():
                if row["missed"]:
                    print(f"  {name}: {row['missed']}")
        for report in results.values():
            if isinstance(report, dict):
                report.pop("coverageLines", None)

    (ROOT / "reports").mkdir(exist_ok=True)
    (ROOT / "reports" / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
