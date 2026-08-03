import re

with open('shell/user/21-lfs.sh', 'r') as f:
    lines = f.readlines()

def extract_func(func_name, lines):
    start = -1
    end = -1
    brace_count = 0
    in_func = False
    func_lines = []
    
    for i, line in enumerate(lines):
        if line is None:
            continue
        if not in_func:
            if re.match(r'^(function )?' + func_name + r'(_gpt)? *\(\) *\{', line) or (f"function {func_name} {{" in line) or (f"{func_name}() {{" in line):
                start = i
                in_func = True
                brace_count += line.count('{') - line.count('}')
                func_lines.append(line)
                if brace_count == 0:
                    end = i
                    break
        else:
            brace_count += line.count('{') - line.count('}')
            func_lines.append(line)
            if brace_count <= 0:
                end = i
                break
                
    if start != -1 and end != -1:
        # Mark lines for deletion
        for i in range(start, end + 1):
            lines[i] = None
        return "".join(func_lines)
    return ""

def write_funcs(filename, funcs):
    content = "#!/usr/bin/env bash\n\n"
    for func in funcs:
        res = extract_func(func, lines)
        if res:
            content += res + "\n"
    
    if content != "#!/usr/bin/env bash\n\n":
        with open(f'shell/user/{filename}', 'w') as f:
            f.write(content)

# lfs-libs.sh
write_funcs('lfs-libs.sh', [
    'rm_old_libs_gpt', 'rm_old_libs', 'ls_old_libs_gpt', 'ls_old_libs',
    'ls_orphaned_files_gpt', 'ls_orphaned_files', 'which_pkg_owns_gpt',
    'which_pkg_owns', 'prune_pkg_inventory_gpt', 'prune_pkg_inventory'
])

# lfs-kerns.sh
with open('shell/user/lfs-kerns.sh', 'w') as f:
    f.write("#!/usr/bin/env bash\n\n# rm_old_kerns is invoked via alias, placeholder here if needed\n")

# lfs-share.sh
write_funcs('lfs-share.sh', ['rm_old_docs_gpt', 'rm_old_docs'])

# lfs-autoremove.sh
write_funcs('lfs-autoremove.sh', ['lfs_autoremove_gpt', 'lfs_autoremove'])

# lfs-autobuild-func.sh
write_funcs('lfs-autobuild-func.sh', ['lfs_autobuild'])

# lfs-update.sh
write_funcs('lfs-update.sh', [
    'lfs_get_upstream_version', 'lfs_get_remote_packages', 
    'lfs_rebuild_missing_inventories', 'lfs_get_local_packages',
    'lfs_pkg_dump', 'lfs_map_bin_to_pkg', 'lfs_strip',
    'lfs_check_custom_updates', 'lfs_update'
])

# Now write back the modified 21-lfs.sh
with open('shell/user/21-lfs.sh.new', 'w') as f:
    for line in lines:
        if line is not None:
            f.write(line)

