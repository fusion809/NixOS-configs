#!/usr/bin/env bash
# Wrapper to workaround GLIBCXX mismatch in hyprctl on NixOS
# Auto-detects the latest GCC lib path available in the store
GCC_LIB=$(ls -d /nix/store/*-gcc-15.2.0-lib/lib 2>/dev/null | head -n 1)
if [ -z "$GCC_LIB" ]; then
    GCC_LIB=$(ls -d /nix/store/*-gcc-14.3.0-lib/lib 2>/dev/null | head -n 1)
fi

if [ -n "$GCC_LIB" ]; then
    export LD_LIBRARY_PATH="$GCC_LIB:$LD_LIBRARY_PATH"
fi

exec /run/current-system/sw/bin/hyprctl "$@"
