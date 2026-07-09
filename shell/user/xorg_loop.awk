        BEGIN {
            in_as_root = 0
            in_md5 = 0
            in_vm_script = 1
            in_root_block = 0
            as_root_content = ""
            host_cmds = ""
            vm_cmds = ""
            in_wget = 0
        }
        /^as_root\(\)/ { in_as_root = 1; as_root_content = $0; next }
        /^bash -e/ { next }
        /^exit/ { next }
        /^cat > .*\.md5 << "EOF"/ { 
            in_md5 = 1; 
            # Do NOT add the md5 block to host_cmds when METAPACKAGE_TARGET filtering
            # is active — we write only the target tarball, so md5sum would fail on
            # a full-list md5 file. The file is written unconditionally here so that
            # md5sum -c can run, but the wget call has already been suppressed.
            host_cmds = host_cmds "\n" $0; 
            next 
        }
        /^# __BEGIN_ROOT__/ { 
            if (in_vm_script && !in_root_block) {
                vm_cmds = vm_cmds "\nas_root bash << \x27ROOTEOF\x27\n"; 
                in_root_block = 1
            }
            next 
        }
        /^# __BEGIN_USER__/ || /^# __END_ROOT__/ || /^# __END_USER__/ { 
            if (in_vm_script && in_root_block) {
                vm_cmds = vm_cmds "\nROOTEOF\n"
                in_root_block = 0
            }
            next 
        }
        /^[[:space:]]*(for package in|while read)/ {
            in_vm_script = 1
            # Rewrite the loop to only iterate over the target package when
            # METAPACKAGE_TARGET is set, rather than the full md5 list.
            if ($0 ~ /for package in.*grep/) {
                vm_cmds = vm_cmds "\n    for package in $(if [ -n \"${METAPACKAGE_TARGET}\" ]; then ls ${METAPACKAGE_TARGET}-*.tar.?z* 2>/dev/null | head -1; else grep -h -v '^#' ../*-7.md5 2>/dev/null | awk '{print $2}'; fi)"
                next
            }
        }
        {
            if (in_as_root) {
                as_root_content = as_root_content "\n" $0
                if ($0 ~ /export -f as_root/) in_as_root = 0
                next
            }
            if (in_md5) {
                host_cmds = host_cmds "\n" $0
                if ($0 ~ /^EOF$/) in_md5 = 0
                next
            }
            
            line = $0;
            # Fix relative paths to md5 files robustly - ONLY for .md5 files
            gsub(/\/sources\/archives\/\.\.\/|\.\.\/([a-z0-9.-]+\.md5)/, "/sources/archives/&", line);
            if (line ~ /^mkdir [^-]|^mkdir [^ -]/) sub(/^mkdir /, "mkdir -p ", line);
            
            if (in_vm_script) {
                if (line ~ /^[[:space:]]*(packagedir|file|pkg|name|package)=/) { 
                    vm_cmds = vm_cmds "\n    " line;

                    if (line ~ /packagedir=/) {
                        vm_cmds = vm_cmds "\n    PKGNAME=$(echo \x24{package} | sed -E \x22s/[-_][0-9].*//\x22)";
                        vm_cmds = vm_cmds "\n    PKGVER=$(echo \x24{package} | sed \x22s/^\x24{PKGNAME}-//; s/^\x24{PKGNAME}_//; s/\\.tar\\..*//\x22)";
                        vm_cmds = vm_cmds "\n    touch /tmp/build_start_\x24{PKGNAME}";
                        vm_cmds = vm_cmds "\n    echo \x22\x24{PKGVER}\x22 | sudo tee \x22/var/lib/book-packages/\x24{PKGNAME}\x22 > /dev/null";
                    }
                    next;
                }
                # Pass function definitions through verbatim (e.g. do_build() { make; })
                if (line ~ /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/) {
                    vm_cmds = vm_cmds "\n    " line;
                    next;
                }
                if (line ~ /make.*install|ninja.*install|pip3.*install/) {
                    vm_cmds = vm_cmds "\n    echo \"[LFS-AUTOBUILD] Recording full inventory for ${PKGNAME}...\"";
                    vm_cmds = vm_cmds "\n    DDIR=\"/tmp/destdir_${PKGNAME}\"";
                    vm_cmds = vm_cmds "\n    sudo rm -rf \"$DDIR\" && mkdir -p \"$DDIR\"";
                    
                    if (line ~ /make.*install/) {
                        cmd = line; sub(/DESTDIR=[^ ]+ /, "", cmd); sub(/ --root=[^ ]+ /, "", cmd);
                        gsub(/ *([|][|]|&&|;).*$/, "", cmd);
                        vm_cmds = vm_cmds "\n    " cmd " DESTDIR=\"$DDIR\" || true";
                    } else if (line ~ /ninja.*install/) {
                        cmd = line; sub(/DESTDIR=[^ ]+ /, "", cmd);
                        gsub(/ *([|][|]|&&|;).*$/, "", cmd);
                        vm_cmds = vm_cmds "\n    DESTDIR=\"$DDIR\" " cmd " || true";
                    } else if (line ~ /pip3.*install/) {
                        cmd = line; sub(/--root=[^ ]+ /, "", cmd);
                        gsub(/ *([|][|]|&&|;).*$/, "", cmd);
                        vm_cmds = vm_cmds "\n    " cmd " --root=\"$DDIR\" --ignore-installed --no-deps || true";
                    }
                    
                    cmd = line; 
                    if (cmd ~ /pip3.*install/ && cmd !~ /ignore-installed/) {
                        sub(/pip3[[:space:]]+install/, "pip3 install --ignore-installed", cmd);
                    }
                    # Only strip trailing operators if not followed by a closing brace (function definition end)
                    if (!(cmd ~ /;[[:space:]]*}/)) {
                        gsub(/ *([|][|]|&&|;).*$/, "", cmd);
                    } else {
                        gsub(/ *([|][|]|&&).*$/, "", cmd);
                    }
                    vm_cmds = vm_cmds "\n    " cmd;
                    vm_cmds = vm_cmds "\n    if [ -d \"$DDIR\" ] && [ \"$(ls -A \"$DDIR\" 2>/dev/null)\" ]; then";
                    vm_cmds = vm_cmds "\n        find \"$DDIR\" -mindepth 1 -printf \"/%P\\n\" | sudo tee -a \"/var/lib/book-packages/${PKGNAME}\" > /dev/null";
                    vm_cmds = vm_cmds "\n    fi";

                    if (line ~ /DESTDIR=/ || line ~ /--root=/) {
                        split(line, parts, "DESTDIR=");
                        if (length(parts) < 2) split(line, parts, "--root=");
                        if (length(parts) >= 2) {
                            split(parts[2], val_parts, " ");
                            destdir = val_parts[1];
                            gsub(/^["\x27]|["\x27]$|[&|;]+$/, "", destdir);
                            if (destdir != "") {
                                vm_cmds = vm_cmds "\n    if [ -d \"" destdir "\" ]; then"
                                vm_cmds = vm_cmds "\n        find \"" destdir "\" -mindepth 1 -printf \"/%P\\n\" | sudo tee -a \"/var/lib/book-packages/${PKGNAME}\" > /dev/null"
                                vm_cmds = vm_cmds "\n    fi"
                            }
                        }
                    }
                    vm_cmds = vm_cmds "\n    sudo mkdir -p /var/lib/book-packages && echo \"\x24{PKGVER}\" | sudo tee \"/var/lib/book-packages/\x24{PKGNAME}\" > /dev/null";
                    vm_cmds = vm_cmds "\n    find /usr /bin /sbin /lib /lib64 /etc /opt -xdev -newer /tmp/build_start_\x24{PKGNAME} 2>/dev/null | sudo tee -a \"/var/lib/book-packages/\x24{PKGNAME}\" > /dev/null";
                    # Clean duplicate version lines and orphaned paths: Keep the version header at line 1, sort the rest uniquely
                    vm_cmds = vm_cmds "\n    (echo \"\x24{PKGVER}\"; tail -n +2 \"/var/lib/book-packages/\x24{PKGNAME}\" 2>/dev/null | grep -v -E \"^[0-9]+(\\.[0-9]+)+$|^[[:space:]]*$\" | sort -u) | sudo tee \"/var/lib/book-packages/\x24{PKGNAME}\" > /dev/null";
                    vm_cmds = vm_cmds "\n    sudo rm -rf \"$DDIR\"";
                    next;
                }
                # Intercept do_install wrapper calls used by xorg-lib loop
                if (line ~ /^[[:space:]]*do_install[[:space:]]*$/) {
                    vm_cmds = vm_cmds "\n    echo \"[LFS-AUTOBUILD] Recording full inventory for ${PKGNAME}...\"";
                    vm_cmds = vm_cmds "\n    DDIR=\"/tmp/destdir_${PKGNAME}\"";
                    vm_cmds = vm_cmds "\n    sudo rm -rf \"$DDIR\" && mkdir -p \"$DDIR\"";
                    vm_cmds = vm_cmds "\n    do_install";
                    vm_cmds = vm_cmds "\n    sudo rm -f \"/tmp/pkg_${PKGNAME}\"";
                    vm_cmds = vm_cmds "\n    if [ -d \"$DDIR\" ] && [ \"$(ls -A \"$DDIR\" 2>/dev/null)\" ]; then";
                    vm_cmds = vm_cmds "\n        find \"$DDIR\" -mindepth 1 -printf \"/%P\\n\" | sudo tee -a \"/tmp/pkg_${PKGNAME}\" > /dev/null";
                    vm_cmds = vm_cmds "\n    fi";
                    vm_cmds = vm_cmds "\n    find /usr /bin /sbin /lib /lib64 /etc /opt -xdev -newer /tmp/build_start_\x24{PKGNAME} 2>/dev/null | sudo tee -a \"/tmp/pkg_\x24{PKGNAME}\" > /dev/null";
                    # Clean duplicate version lines and orphaned paths: Keep the version header at line 1, sort the rest uniquely
                    vm_cmds = vm_cmds "\n    (echo \"\x24{PKGVER}\"; cat \"/tmp/pkg_\x24{PKGNAME}\" 2>/dev/null | grep -v -E \"^[0-9]+(\\.[0-9]+)+$|^[[:space:]]*$\" | sort -u) | sudo tee \"/var/lib/book-packages/\x24{PKGNAME}\" > /dev/null";
                    vm_cmds = vm_cmds "\n    sudo rm -rf \"$DDIR\"";
                    next;
                }
                
                # Diagnostic suppression
                if (line ~ /^[[:space:]]*(grep|cat|tail|ls)[[:space:]].*\.log/) {
                    vm_cmds = vm_cmds "\n    " line " 2>/dev/null || true";
                    next;
                }
                
                # Test suite suppression
                if (line ~ /(make[[:space:]].*(check|test|tests|jstest|jit-test|all-headless)|ninja[[:space:]]+(test|check)|spawn.*make|\<expect\>|tester|su.*tester|(^|[[:space:]])testdir([[:space:]]|$)|test_summary|cd[[:space:]]+t$|tests\/run\.sh)/) {
                    next;
                }
                
                # Intercept wget to filter by METAPACKAGE_TARGET
                if (line ~ /wget -i- -c/) {
                    gsub(/wget -i- -c/, "grep -E \"^${METAPACKAGE_TARGET:-.}\" | wget -i- -c", line);
                    gsub(/www\.x\.org\/pub/, "xorg.freedesktop.org/archive", line);
                    vm_cmds = vm_cmds "\n    " line;
                    next;
                }
                
                # Intercept md5sum to prevent script failure on single package builds
                if (line ~ /md5sum -c/) {
                    vm_cmds = vm_cmds "\n    " line " 2>/dev/null || true";
                    next;
                }
                
                vm_cmds = vm_cmds "\n    " line;
                next;
            } else {
                # Host diagnostic suppression
                if (line ~ /^[[:space:]]*(grep|cat|tail|ls)[[:space:]].*\.log/) {
                    host_cmds = host_cmds "\n" line " 2>/dev/null || true";
                } else {
                    # Fix awk $2 escaping in for loops (e.g. for package in $(... awk '{print $2}'))
                    # Use [$] to avoid AWK warning about escape sequence \$
                    gsub(/[$]2/, "\\$2", line);
                    if (line ~ /wget -i- -c/) {
                        in_wget = 1;
                        if (line !~ /\\$/) in_wget = 0;
                    } else if (in_wget) {
                        if (line !~ /\\$/) in_wget = 0;
                    } else if (line ~ /md5sum -c/) {
                        # Skip md5sum check — it would fail when only one target file
                        # was downloaded instead of the full bundle.
                    } else {
                        host_cmds = host_cmds "\n" line
                    }
                }
                next;
            }
        }
        END {
            sub(/^\n/, "", host_cmds)
            print "cd /sources/archives"
            print "as_root() {"
            print "  if [ ${EUID:-$(id -u)} = 0 ]; then"
            print "    [ $# -gt 0 ] && \"$@\" || :"
            print "  elif [ -x /usr/bin/sudo ]; then"
            print "    sudo \"$@\""
            print "  else"
            print "    su -c \"$*\""
            print "  fi"
            print "}"
            print "export -f as_root"
            print host_cmds
            print "cat > build-xorg.sh << \x27XORGEOF\x27"
            print "#!/bin/bash"
            print "set -e"
            print ""
            print "as_root() {"
            print "  if [ ${EUID:-$(id -u)} = 0 ]; then"
            print "    [ $# -gt 0 ] && \"$@\" || :"
            print "  elif [ -x /usr/bin/sudo ]; then"
            print "    sudo \"$@\""
            print "  else"
            print "    su -c \"$*\""
            print "  fi"
            print "}"
            print "export -f as_root"
            print vm_cmds
            print "XORGEOF"
            print "bash build-xorg.sh"
        }
