#!/usr/bin/env python3
import glob
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

# Archive extension pattern for stripping from versions
_ARCHIVE_RE = re.compile(
    r'\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$'
)

def get_local_versions():
    local_vers = {}
    for d in ["/var/lib/custom-packages", "/var/lib/book-packages"]:
        if os.path.isdir(d):
            for entry in os.scandir(d):
                if entry.is_file() and not entry.name.startswith("."):
                    try:
                        with open(entry.path, "r", errors="ignore") as f:
                            line = f.readline().strip()
                            if line:
                                local_vers[entry.name] = line
                    except Exception:
                        pass
    return local_vers

def get_broken_pkgs():
    """Return a set of package names whose inventory files have <=1 line or contain BUILD_FAILED."""
    broken = set()
    skip = {"COMMIT_EDITMSG", "HEAD", "config", "description", "ORIG_HEAD"}
    for d in ["/var/lib/book-packages", "/var/lib/custom-packages"]:
        if not os.path.isdir(d):
            continue
        try:
            for entry in os.scandir(d):
                if not entry.is_file() or entry.name.startswith(".") or entry.name in skip:
                    continue
                try:
                    with open(entry.path, "r", errors="ignore") as f:
                        content = f.read()
                    lines = [l for l in content.splitlines() if l.strip()]
                    if len(lines) <= 1 or "BUILD_FAILED" in content:
                        broken.add(entry.name)
                except Exception:
                    pass
        except Exception:
            pass
    return broken

def get_safe_lines(lines, ver_line_idx):
    prefix = lines[:ver_line_idx + 1]
    res = subprocess.run(["bash", "-n", "-c", "\n".join(prefix)], stderr=subprocess.DEVNULL)
    if res.returncode == 0:
        return prefix
    for idx in range(ver_line_idx + 1, min(len(lines), ver_line_idx + 6)):
        candidate = lines[:idx + 1]
        res = subprocess.run(["bash", "-n", "-c", "\n".join(candidate)], stderr=subprocess.DEVNULL)
        if res.returncode == 0:
            return candidate
    return prefix

def evaluate_package(script_path, local_vers):
    pkg_dir = os.path.dirname(script_path)
    pkg_basename = os.path.basename(pkg_dir)

    try:
        with open(script_path, "r", errors="ignore") as f:
            content = f.read()
    except Exception:
        return pkg_basename, "none", "FAILED", pkg_basename

    m_name = re.search(r"(?m)^[ \t]*(?:export[ \t]+)?[a-zA-Z_]*name=([^\n]+)", content)
    if m_name:
        raw_name = m_name.group(1).strip().strip('"').strip("'")
        pkg_name = pkg_basename if "$" in raw_name else raw_name
    else:
        pkg_name = pkg_basename

    local_ver = local_vers.get(pkg_name, local_vers.get(pkg_basename, "none"))
    if local_ver == "none":
        return pkg_name, "none", "NONE", pkg_basename

    lines = content.splitlines()
    ver_line_idx = -1
    var_name = "version"

    exclude_pattern = re.compile(r"_(major|minor|micro|patch|dir|url|repo|min|max|code|hash|sha|md5)=", re.IGNORECASE)
    match_pattern1 = re.compile(r"^[ \t]*(?:export[ \t]+)?(version|VERSION|pkgver|PKGVER|pkg_ver|PKG_VER|VER)=([^\n]+)")
    match_pattern2 = re.compile(r"^[ \t]*(?:export[ \t]+)?([a-zA-Z0-9_]*(?:version|VERSION|pkgver|PKGVER|pkg_ver|VER))=([^\n]+)")

    for i, line in enumerate(lines):
        if exclude_pattern.search(line):
            continue
        m = match_pattern1.match(line)
        if m:
            var_name = m.group(1)
            ver_line_idx = i

    if ver_line_idx == -1:
        for i, line in enumerate(lines):
            if exclude_pattern.search(line):
                continue
            m = match_pattern2.match(line)
            if m:
                var_name = m.group(1)
                ver_line_idx = i

    remote_ver = ""
    if ver_line_idx != -1:
        val_part = lines[ver_line_idx].split("=", 1)[1].strip().strip('"').strip("'")
        if "$" not in val_part and "`" not in val_part and val_part:
            remote_ver = val_part
        else:
            safe_lines = get_safe_lines(lines, ver_line_idx)
            snippet = (
                "set +e\n"
                "export PATH=/opt/texlive/2025/bin/x86_64-linux:$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin\n"
                "export LFP=${LFP:-$HOME/lfs_packaging}\n"
                f"export INST_VER={repr(local_ver)}\n"
                "[ -f ~/lfs_packaging/shared-funcs.sh ] && source ~/lfs_packaging/shared-funcs.sh\n"
                "pkgver() {\n"
                "    local target=\"$1\"\n"
                "    if [[ \"$target\" == \"$name\" && -n \"$INST_VER\" && \"$INST_VER\" != \"none\" ]]; then\n"
                "        echo \"$INST_VER\"\n"
                "        return 0\n"
                "    fi\n"
                "    if [[ -f \"/var/lib/custom-packages/$target\" ]]; then\n"
                "        head -n \"${2:-1}\" \"/var/lib/custom-packages/$target\" | tail -n 1\n"
                "        return 0\n"
                "    elif [[ -f \"/var/lib/book-packages/$target\" ]]; then\n"
                "        head -n \"${2:-1}\" \"/var/lib/book-packages/$target\" | tail -n 1\n"
                "        return 0\n"
                "    fi\n"
                "    return 1\n"
                "}\n"
                "curl() {\n"
                "    local args=()\n"
                "    while [[ $# -gt 0 ]]; do\n"
                "        if [[ \"$1\" == \"--connect-timeout\" ]]; then\n"
                "            args+=(\"--connect-timeout\" \"5\")\n"
                "            shift 2\n"
                "        elif [[ \"$1\" == \"--max-time\" ]]; then\n"
                "            args+=(\"--max-time\" \"8\")\n"
                "            shift 2\n"
                "        else\n"
                "            args+=(\"$1\")\n"
                "            shift\n"
                "        fi\n"
                "    done\n"
                "    command curl \"${args[@]}\"\n"
                "}\n"
                f"name={repr(pkg_basename)}\n"
                f"_name={repr(pkg_basename)}\n"
                f"NAME={repr(pkg_basename)}\n"
                "exec 3>&1 1>/dev/null 2>/dev/null\n"
                + "\n".join(safe_lines) + "\n"
                + f'echo "VER_RESULT:${var_name}" >&3\n'
            )
            for attempt in range(3):
                try:
                    proc = subprocess.run(
                        ["bash", "-c", snippet],
                        cwd=pkg_dir,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL,
                        text=True,
                        timeout=25
                    )
                    for out_line in proc.stdout.splitlines():
                        if out_line.startswith("VER_RESULT:"):
                            res = out_line[11:].strip()
                            if res and "429" not in res and "error" not in res.lower():
                                remote_ver = res
                                break
                    if remote_ver:
                        break
                    time.sleep(0.5 * (attempt + 1))
                except Exception:
                    time.sleep(0.5)

    if not remote_ver and "git clone" in content:
        m_git = re.findall(r"git clone\s+(?:--\S+\s+)*(https?://\S+|git@\S+)", content)
        if m_git:
            repo_url = m_git[-1]
            for attempt in range(3):
                try:
                    proc = subprocess.run(
                        ["git", "ls-remote", repo_url, "HEAD"],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL,
                        text=True,
                        timeout=15
                    )
                    if proc.returncode == 0 and proc.stdout:
                        remote_ver = proc.stdout.split()[0].strip()
                        break
                    time.sleep(1.0 * (attempt + 1))
                except Exception:
                    time.sleep(0.5)

    if not remote_ver:
        remote_ver = "FAILED"

    return pkg_name, local_ver, remote_ver, pkg_basename


def _strip_archive(v):
    return _ARCHIVE_RE.sub("", v).strip()


def _is_newer(remote, local):
    """Return True if remote is strictly newer than local using sort -V semantics."""
    if remote == local:
        return False
    r = remote.replace("-", ".")
    l = local.replace("-", ".")
    if r == l:
        return False
    # Git hashes: any difference = new commit
    if re.match(r'^[0-9a-f]{7,40}$', remote) and re.match(r'^[0-9a-f]{7,40}$', local):
        return True
    try:
        result = subprocess.run(
            ["sort", "-V"],
            input=f"{l}\n{r}\n",
            capture_output=True, text=True
        )
        winner = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else r
        return winner == r and r != l
    except Exception:
        return False


def classify(pkg_name, local_ver, remote_ver, broken_pkgs, verbose):
    """Return (label, local_ver, remote_ver) or None if package should be skipped."""
    local_ver = _strip_archive(local_ver).strip()
    remote_ver = _strip_archive(remote_ver).strip()

    # Abbreviate git hashes
    if len(local_ver) == 40:
        local_ver = local_ver[:7]
    if len(remote_ver) == 40:
        remote_ver = remote_ver[:7]

    if pkg_name in broken_pkgs:
        label = "[FILES MISSING]"
    elif "FAILED" in remote_ver:
        label = "[FAILED]"
    elif "MISSING" in remote_ver:
        label = "[MISSING]"
    elif local_ver == "none":
        label = "[UPDATE]"
    elif local_ver == remote_ver:
        label = ""
    elif _is_newer(remote_ver, local_ver):
        label = "[UPDATE]"
    else:
        label = ""

    if not verbose:
        if not label:
            return None
        if local_ver == remote_ver and "[MISSING]" not in label and "[FAILED]" not in label:
            return None

    return label, local_ver, remote_ver


def main():
    verbose = "--verbose" in sys.argv or "-v" in sys.argv

    packaging_dir = os.path.expanduser("~/lfs_packaging")
    scripts = sorted(glob.glob(os.path.join(packaging_dir, "*/build.sh")))
    local_vers = get_local_versions()
    broken_pkgs = get_broken_pkgs()

    # Only track packages currently recorded in the inventory directories
    eligible_scripts = []
    for s in scripts:
        pkg_basename = os.path.basename(os.path.dirname(s))
        if pkg_basename in local_vers:
            eligible_scripts.append(s)
            continue
        try:
            with open(s, "r", errors="ignore") as f:
                for _ in range(60):
                    line = f.readline()
                    if not line:
                        break
                    m = re.match(r"^[ \t]*(?:export[ \t]+)?(?:pkg_?name|name|PKG_?NAME)=([^\n]+)", line)
                    if m:
                        raw = m.group(1).strip().strip('"').strip("'")
                        if raw in local_vers:
                            eligible_scripts.append(s)
                            break
        except Exception:
            pass

    total = len(eligible_scripts)
    print(f"TOTAL:{total}", flush=True)

    rows = []  # (pkg_name, local_ver, remote_ver, label)

    # 16 workers: most time is network I/O so more threads reduces wall time
    with ThreadPoolExecutor(max_workers=16) as executor:
        futures = {executor.submit(evaluate_package, s, local_vers): s for s in eligible_scripts}
        for future in as_completed(futures):
            try:
                pkg_name, local_ver, remote_ver, pkg_basename = future.result()
                print(f"PROGRESS:{pkg_basename}", flush=True)
                if local_ver == "none":
                    continue
                result = classify(pkg_name, local_ver, remote_ver, broken_pkgs, verbose)
                if result is not None:
                    label, lv, rv = result
                    rows.append((pkg_name, lv, rv, label))
                    # Keep backward-compat RESULT line for lfs-update.sh consumers
                    print(f"RESULT:{pkg_name} {lv} {rv}", flush=True)
            except Exception:
                pass

    # Emit pre-formatted table — sorted alphabetically, all in Python, no bash forks needed
    rows.sort(key=lambda r: r[0].lower())
    if rows:
        sep = "-" * 80
        print("TABLE_START", flush=True)
        print(sep, flush=True)
        print(f"{'Package':<30} | {'Local':<15} | {'Remote':<15}", flush=True)
        print(flush=True)
        print(sep, flush=True)
        for pkg_name, lv, rv, label in rows:
            print(f"{pkg_name:<30} | {lv:<15} | {rv:<15} {label}", flush=True)
        print(flush=True)
        print("TABLE_END", flush=True)
    else:
        print("TABLE_EMPTY", flush=True)


if __name__ == "__main__":
    main()
