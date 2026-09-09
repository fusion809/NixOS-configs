#!/usr/bin/env python3
import glob
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

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

def get_safe_lines(lines, ver_line_idx):
    # Take lines up to and including the version assignment line
    prefix = lines[:ver_line_idx + 1]
    res = subprocess.run(["bash", "-n", "-c", "\n".join(prefix)], stderr=subprocess.DEVNULL)
    if res.returncode == 0:
        return prefix
    # If syntax is not yet complete (e.g. unclosed block), minimally scan forward
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

    lines = content.splitlines()
    ver_line_idx = -1
    var_name = "version"

    # Find the LAST assignment of version (tail -n 1), ignoring suffixes like _major, _dir, etc.
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
                "[ -f ~/lfs_packaging/shared-funcs.sh ] && source ~/lfs_packaging/shared-funcs.sh\n"
                "pkgver() {\n"
                "    local target=\"$1\"\n"
                "    if [[ -f \"/var/lib/custom-packages/$target\" ]]; then\n"
                "        head -n \"${2:-1}\" \"/var/lib/custom-packages/$target\" | tail -n 1\n"
                "        return 0\n"
                "    elif [[ -f \"/var/lib/book-packages/$target\" ]]; then\n"
                "        head -n \"${2:-1}\" \"/var/lib/book-packages/$target\" | tail -n 1\n"
                "        return 0\n"
                "    fi\n"
                "    find /var/lib/custom-packages /var/lib/book-packages -maxdepth 1 -type f -name \"$target\" -exec head -n \"${2:-1}\" {} + 2>/dev/null | tail -n 1\n"
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

def main():
    packaging_dir = os.path.expanduser("~/lfs_packaging")
    scripts = sorted(glob.glob(os.path.join(packaging_dir, "*/build.sh")))
    total = len(scripts)
    print(f"TOTAL:{total}", flush=True)

    local_vers = get_local_versions()

    # Use 8 workers to prevent triggering GitHub HTTP 429 rate limiting
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(evaluate_package, s, local_vers): s for s in scripts}
        for future in as_completed(futures):
            try:
                pkg_name, local_ver, remote_ver, pkg_basename = future.result()
                print(f"PROGRESS:{pkg_basename}", flush=True)
                print(f"RESULT:{pkg_name} {local_ver} {remote_ver}", flush=True)
            except Exception:
                pass

if __name__ == "__main__":
    main()
