# Show the timestamp of the update run
# Arguments:
# The format to show the timestamp in. %r is the default and corresponds to the 
# The update run you want (optional); 1 (default) corresponds to the latest 
# update run. 
function latestUpdatesRun {
	if [[ -n $2 ]]; then
		filename=$(ls "$HOME/.cache/updates."* | tail -n $2 | head -n 1)
	else
		filename=$(ls "$HOME/.cache/updates."* | tail -n 1)
	fi
	timestamp="${filename##*.}"
	if ! [[ -n $1 ]]; then
		echo $timestamp
	else
		date -d "@${timestamp}" +"$1"
	fi
}

# Show updateLog
# Arguments:
# The number of the log to show. 1 is the default and corresponds to the latest 
# update log file. 2 is the second most recent log file and so far.
function updateLog {
	if ( [[ -n $1 ]] && [[ "$1" != "1" ]] ); then
		latestUpdateLog=$(ls $HOME/.cache/updates.* | tail -n $1 | head -n 1)
	else
		latestUpdateLog=$(ls $HOME/.cache/updates.* | tail -n 1)
	fi
	latestUpdatesRun "%r" $1
	if [[ ( -z "$1" || "$1" == "1" ) ]] && pgrep -f "shell/hyprland/updates" > /dev/null; then
		pid=$(pgrep -f "shell/hyprland/updates" | head -n 1)
		tail -n +1 -f ${pid:+--pid=$pid} "$latestUpdateLog"
	else
		cat "$latestUpdateLog"
	fi
}

# Remove the $HOME/.cache/updates.* file for the most recent run of the 
# shell/hyprland/updates script
function rmLastUpdatesRun {
	rm $(ls $HOME/.cache/updates.* | tail -n 1)
}

