#!/usr/bin/env python3

import subprocess
import json
import sys
import shutil
import os

def main():
    if not shutil.which("scc"):
        print("Error: 'scc' is not installed or not in PATH.", file=sys.stderr)
        sys.exit(1)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    
    try:
        # Run scc on the repository root and get JSON output
        result = subprocess.run(["scc", "-f", "json", repo_root], capture_output=True, text=True, check=True)
        data = json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running scc: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print("Error: Could not parse scc output as JSON.", file=sys.stderr)
        sys.exit(1)

    # Categories to aggregate into "Shell"
    shell_variants = {"Zsh", "BASH", "Shell", "Bourne Shell", "Fish", "C Shell", "Korn Shell"}
    
    aggregated_shell = {
        "Name": "Shell",
        "Lines": 0,
        "Bytes": 0,
        "Code": 0,
        "Comment": 0,
        "Blank": 0,
        "Complexity": 0,
        "Count": 0
    }
    
    other_languages = []
    
    for lang in data:
        name = lang.get("Name")
        if name in shell_variants:
            aggregated_shell["Lines"] += lang.get("Lines", 0)
            aggregated_shell["Bytes"] += lang.get("Bytes", 0)
            aggregated_shell["Code"] += lang.get("Code", 0)
            aggregated_shell["Comment"] += lang.get("Comment", 0)
            aggregated_shell["Blank"] += lang.get("Blank", 0)
            aggregated_shell["Complexity"] += lang.get("Complexity", 0)
            aggregated_shell["Count"] += lang.get("Count", 0)
        else:
            other_languages.append(lang)
            
    # Add Shell category if it has any content
    final_list = []
    if aggregated_shell["Lines"] > 0:
        final_list.append(aggregated_shell)
        
    final_list.extend(other_languages)
    
    # Calculate total lines and complexity
    total_lines = sum(lang.get("Lines", 0) for lang in final_list)
    total_complexity = sum(lang.get("Complexity", 0) for lang in final_list)
    
    if total_lines == 0:
        print("No lines of code found.")
        return

    # Sort by Lines descending
    final_list.sort(key=lambda x: x.get("Lines", 0), reverse=True)

    # Generate Markdown Table
    table_lines = []
    table_lines.append(f"| Language | Lines | Lines % | Complexity | Complexity % |")
    table_lines.append(f"| :--- | :--- | :--- | :--- | :--- |")
    
    for lang in final_list:
        name = lang.get("Name")
        lines = lang.get("Lines", 0)
        complexity = lang.get("Complexity", 0)
        percentage = (lines / total_lines) * 100
        
        if total_complexity > 0:
            comp_percentage = (complexity / total_complexity) * 100
        else:
            comp_percentage = 0.0
        
        table_lines.append(f"| {name} | {lines} | {percentage:.2f}% | {complexity} | {comp_percentage:.2f}% |")

    table_lines.append(f"| **Total** | **{total_lines}** | **100.00%** | **{total_complexity}** | **100.00%** |")
    
    markdown_table = "\n".join(table_lines)
    
    # Print to stdout
    print(markdown_table)
    
    # Update README.md
    readme_path = os.path.join(repo_root, "README.md")
    try:
        with open(readme_path, "r") as f:
            lines = f.readlines()
            
        start_marker = "<!-- STATS START -->\n"
        end_marker = "<!-- STATS END -->\n"
        
        new_content = []
        in_stats = False
        stats_inserted = False
        
        # Check if we already have stats block
        has_existing_stats = any(start_marker.strip() in line for line in lines)
        
        if has_existing_stats:
            for line in lines:
                if start_marker.strip() in line:
                    in_stats = True
                    new_content.append(start_marker)
                    new_content.append(markdown_table + "\n")
                    stats_inserted = True
                elif end_marker.strip() in line:
                    in_stats = False
                    new_content.append(end_marker)
                elif not in_stats:
                    new_content.append(line)
        else:
            # Insert before # Shell profile
            for line in lines:
                if line.strip() == "# Shell profile" and not stats_inserted:
                    new_content.append(start_marker)
                    new_content.append(markdown_table + "\n")
                    new_content.append(end_marker)
                    new_content.append("\n") # Add extra newline
                    new_content.append(line)
                    stats_inserted = True
                else:
                    new_content.append(line)
            
            if not stats_inserted:
                print("Warning: Could not find '# Shell profile' line in README.md. Appending stats to end.", file=sys.stderr)
                new_content.append("\n" + start_marker)
                new_content.append(markdown_table + "\n")
                new_content.append(end_marker)

        with open(readme_path, "w") as f:
            f.writelines(new_content)
            
        print(f"\nStats successfully written to {readme_path}")

    except FileNotFoundError:
        print(f"Error: {readme_path} not found.", file=sys.stderr)
    except Exception as e:
        print(f"Error updating README.md: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
