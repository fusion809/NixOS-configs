#!/bin/zsh

set -u

logfile="$HOME/logs/updates.log"
logdir="$HOME/logs"

mkdir -p "$logdir"

timestamp=$(date '+%Y%m%d_%H%M%S')
runlog="$logdir/updatec.log.$timestamp"

exec > >(tee -a "$runlog") 2>&1

echo "===== Update check started: $(date '+%F %T %Z') ====="
echo "Run log: $runlog"

# Prevent overlapping instances of this service script.
exec 9>"$logdir/updates_check_and_run.lock"
if ! flock -n 9; then
    echo "Another updates_check_and_run.sh instance is running; skipping."
    exit 0
fi

if [[ ! -f $logfile ]]; then
    echo "ERROR: Update log not found: $logfile"
    exit 1
fi

# The update report has already compared local and upstream versions. Trust
# its actionable labels instead of repeating each package's upstream lookup.
pkgs_updates=()
while IFS= read -r pkg; do
    [[ -n $pkg ]] && pkgs_updates+=("$pkg")
done < <(
    awk '/\[UPDATE\]|\[FILES MISSING\]/ { print $1 }' "$logfile"
)

if (( ${#pkgs_updates[@]} == 0 )); then
    echo "No packages need updating."
    exit 0
fi
pkgs=("${pkgs_updates[@]}")

printf 'Packages needing attention:'
printf ' %s' "${pkgs[@]}"
printf '\n'

# Check whether the autobuild script is already running.
autobuild_running=false

for proc in /proc/[0-9]*; do
    [[ -r $proc/cmdline ]] || continue
    pid=${proc##*/}

    # Exclude this script and its parent processes.
    [[ $pid == "$$" || $pid == "$PPID" ]] && continue

    cmdline=$(cat "$proc/cmdline" 2>/dev/null | tr '\0' '\n' 2>/dev/null || :)

    if grep -Fxq -- "$HOME/.lfs_autobuild.sh" <<< "$cmdline" ||
       grep -Fxq -- "$HOME/lfs-scripts/.lfs_autobuild.sh" <<< "$cmdline"; then
        autobuild_running=true
        echo "Autobuild process found: PID $pid"
        break
    fi
done

if [[ $autobuild_running == true ]]; then
    echo ".lfs_autobuild.sh is running; skipping updatec."
    exit 0
fi

# Prevent concurrent updatec runs that honour this lock.
exec 8>"$logdir/updatec.lock"
if ! flock -n 8; then
    echo "Another updater holds updatec.lock; skipping."
    exit 0
fi

# Check for an updatec command already running, including manually
# launched instances that do not use the lock above.
while IFS= read -r pid; do
    [[ -r /proc/$pid/cmdline ]] || continue

    cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' 2>/dev/null || :)

    if [[ $cmdline == *"zsh -ic updatec"* ]]; then
        echo "Existing updatec process found (PID $pid); skipping."
        exit 0
    fi
done < <(pgrep -x zsh || true)

echo "===== Starting updatec: $(date '+%F %T %Z') ====="

if zsh -ic 'updatec'; then
    status=0
    echo "===== updatec completed successfully ====="
else
    status=$?
    echo "===== ERROR: updatec exited with status $status ====="
fi

echo "Finished: $(date '+%F %T %Z')"
echo "Exit status: $status"

exit "$status"
