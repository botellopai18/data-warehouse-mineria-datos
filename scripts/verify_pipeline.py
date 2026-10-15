#!/usr/bin/env python3
"""Reproduce the tutorial on a fresh, isolated SQL Server; retain real evidence.

Requires Python 3.10+ and Docker. No Python packages or host SQL tools needed.
The container has no published ports, mounts the project read-only, and is
removed afterwards. Only this run's uniquely named container is removed.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import time
import uuid

from prepare_sources import prepare_sources, validate_sources

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718"


def run(command: list[str], *, input_text: str | None = None, timeout: int = 300):
    return subprocess.run(command, input=input_text, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=timeout, check=False)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/latest")
    parser.add_argument("--image", default=IMAGE, help="Official SQL Server image; default is pinned by digest")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # Replace this tool's previous outputs only. A failed rerun must not leave
    # earlier successful result files looking like results of the new run.
    owned_outputs = ["summary.json", "server_version.txt", "server_diagnostics.txt"] + [
        name + ".txt" for name in (
            "01_initial_load", "02_before_after", "03_tutorial_silver_diagnostics",
            "04_tutorial_gold_checks", "05_reload_and_rollback", "06_existing_database_guard",
            "07_empty_table_rejected", "08_final_acceptance", "09_documented_reload")]
    for name in owned_outputs:
        (output / name).unlink(missing_ok=True)
    container = "dwh-verify-" + uuid.uuid4().hex[:12]
    summary = {"status": "running", "started_at_utc": datetime.now(timezone.utc).isoformat(),
               "image": args.image, "steps": []}
    created = False
    staging = None
    try:
        summary["sources"] = validate_sources()
        staging = tempfile.TemporaryDirectory(prefix="dwh-verify-sources-")
        os.chmod(staging.name, 0o755)  # SQL Server runs as a non-root UID on Linux.
        summary["staged_sources"] = prepare_sources(Path(staging.name))
        # Fingerprint the actual SQL, runner, manifests, and docs used by this run.
        paths = sorted(p for folder in ("scripts", "tests", "docs")
                       for p in (ROOT / folder).rglob("*")
                       if p.is_file() and p.suffix in (".sql", ".py", ".json", ".md")
                       and "evidence" not in p.parts)
        paths += [ROOT / "README.md"]
        summary["reviewed_files_sha256"] = {
            p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
        git = run(["git", "-C", str(ROOT), "rev-parse", "HEAD"])
        summary["base_commit"] = git.stdout.strip() if git.returncode == 0 else None
        print("PASS source files: SHA-256, headers, row widths and six counts", flush=True)
        with tempfile.TemporaryDirectory(prefix="dwh-verify-auth-") as temp:
            env_file = Path(temp) / "server.env"
            password = "Dwh!9" + secrets.token_hex(24)
            env_file.write_text("ACCEPT_EULA=Y\nMSSQL_PID=Developer\nMSSQL_SA_PASSWORD=" + password
                                + "\nSQLCMDPASSWORD=" + password + "\n")
            os.chmod(env_file, 0o600)
            start = run(["docker", "run", "--detach", "--platform", "linux/amd64",
                         "--name", container, "--env-file", str(env_file),
                         "--mount", f"type=bind,source={ROOT},target=/workspace,readonly",
                         "--mount", f"type=bind,source={staging.name},target=/sources,readonly",
                         "--workdir", "/workspace", args.image], timeout=900)
            if start.returncode:
                raise RuntimeError("Cannot start SQL Server: " + start.stdout)
            created = True
        # SQLCMDPASSWORD is passed through the disposable container environment,
        # never through command arguments or committed evidence.
        sqlcmd = ["docker", "exec", "-i", container, "/opt/mssql-tools18/bin/sqlcmd",
                  "-S", "localhost", "-U", "sa", "-C", "-b", "-r", "1", "-l", "5"]
        deadline = time.monotonic() + 240
        while True:
            ready = run(sqlcmd + ["-Q", "SET NOCOUNT ON; SELECT @@VERSION;"], timeout=15)
            if ready.returncode == 0:
                (output / "server_version.txt").write_text(ready.stdout)
                break
            if time.monotonic() > deadline:
                raise RuntimeError("SQL Server did not become ready: " + ready.stdout)
            time.sleep(2)
        print("SQL Server ready; running the warehouse stages", flush=True)

        def step(name: str, *, file: str | None = None, query: str | None = None,
                 expected_error: str | None = None, database: str = "DataWarehouse"):
            command = sqlcmd + ["-d", database, "-v", "DataRoot=/sources", "-w", "240"]
            if file:
                command += ["-i", file]
            else:
                command += ["-Q", query or ""]
            result = run(command, timeout=300)
            (output / (name + ".txt")).write_text(result.stdout)
            success = (result.returncode != 0 and expected_error in result.stdout
                       if expected_error else result.returncode == 0)
            summary["steps"].append({"name": name, "passed": success, "exit_code": result.returncode,
                                     "expected_error": expected_error})
            print(("PASS " if success else "FAIL ") + name, flush=True)
            if not success:
                raise RuntimeError(f"{name}: unexpected SQL result; see {name}.txt\n" + result.stdout[-4000:])

        step("01_initial_load", file="scripts/run_all.sql", database="master")
        step("02_before_after", file="tests/profile_data.sql")
        step("03_tutorial_silver_diagnostics", file="tests/quality_checks_silver.sql")
        step("04_tutorial_gold_checks", file="tests/quality_checks_gold.sql")
        step("05_reload_and_rollback", file="tests/reload_and_failures.sql")
        step("06_existing_database_guard", file="scripts/run_all.sql", database="master",
             expected_error="DataWarehouse already exists")
        # A transaction intentionally removes sales. sqlcmd exits on the failing
        # assertion; disconnect rolls back the uncommitted transaction.
        rejection = run(sqlcmd + ["-d", "DataWarehouse", "-v", "DataRoot=/sources"],
                        input_text="BEGIN TRANSACTION;\nTRUNCATE TABLE silver.crm_sales_details;\nGO\n"
                                   ":r tests/assert_warehouse.sql\n")
        (output / "07_empty_table_rejected.txt").write_text(rejection.stdout)
        rejected = rejection.returncode != 0 and "FAIL warehouse: missing" in rejection.stdout
        summary["steps"].append({"name": "07_empty_table_rejected", "passed": rejected,
                                 "exit_code": rejection.returncode, "expected_error": "FAIL warehouse: missing"})
        if not rejected:
            raise RuntimeError("Quality gate failed to reject empty sales table")
        print("PASS 07_empty_table_rejected", flush=True)
        step("08_final_acceptance", file="tests/assert_warehouse.sql")
        step("09_documented_reload", file="scripts/reload.sql")
        summary["status"] = "passed"
        return 0
    except Exception as error:
        summary["status"] = "failed"
        summary["error"] = str(error)
        print(str(error), flush=True)
        if created:
            logs = run(["docker", "logs", container])
            (output / "server_diagnostics.txt").write_text(logs.stdout)
        return 1
    finally:
        if created:
            cleanup = run(["docker", "rm", "--force", container])
            summary["container_removed"] = cleanup.returncode == 0
        if staging:
            staging.cleanup()
        summary["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
        summary["evidence_sha256"] = {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.glob("*.txt"))}
        (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
