function ved {
	cdphd Rcode/RQ5
	vim Edits_to_parameters_$(date +"%Y-%m-%d").txt
}

function ged {
	cdphd Rcode/RQ5
	grep --include="Edits_to_parameters*.txt" -R "$1" | sort
}