#!/bin/bash
# =============================================================================
# 03_a_generate_combo.sh - Generate Group Combination File
# =============================================================================
# Creates group_combinations.txt defining which populations to compare together.
# This file is used by 03_generate_msmc_input.sh to generate MSMC input files
# for cross-population analysis.
#
# Usage:
#   bash 03_a_generate_combo.sh
#
# Output:
#   group_combinations.txt - List of population group combinations
#
# Edit the COMBOS array below to define your own population groups.
# =============================================================================

# Configuration - EDIT THESE
SAMPLE_LIST_DIR="${1:-./sample_lists}"
OUTPUT_FILE="${2:-./group_combinations.txt}"

# Clear output file
> "$OUTPUT_FILE"

# =============================================================================
# USER CONFIGURATION - Define your population groups here
# =============================================================================
# Format: combo_name pop1 pop2 pop3 ...
# - combo_name: identifier for this group combination
# - pop1, pop2, ...: population names that should be analyzed together
#
# Example:
#   COMBOS=(
#       "GroupA:Pop1 Pop2 Pop3"
#       "GroupB:PopA PopB PopC"
#   )
#
# Each population must have a corresponding sample list file:
#   {SAMPLE_LIST_DIR}/{pop}.txt

COMBOS=(
    "Group1:PopA PopB PopC"
    "Group2:PopX PopY PopZ"
)

# =============================================================================
# Validation and file generation
# =============================================================================
missing_count=0

for combo in "${COMBOS[@]}"; do
    combo_name=$(echo "$combo" | awk '{print $1}')
    pop_list=$(echo "$combo" | awk '{$1=""; print $0}' | sed 's/^ //')

    missing=0
    for pop in $pop_list; do
        pop_file="${SAMPLE_LIST_DIR}/${pop}.txt"
        if [[ ! -f "$pop_file" ]]; then
            echo "WARNING: Sample list not found: $pop_file"
            missing=1
            ((missing_count++))
        fi
    done

    # Only write if all population files exist
    if [[ $missing -eq 0 ]]; then
        echo "$combo_name $pop_list" >> "$OUTPUT_FILE"
        echo "Added: $combo_name ($pop_list)"
    else
        echo "Skipping $combo_name - missing population file(s)"
    fi
done

echo ""
echo "Generated group combinations: $OUTPUT_FILE"
echo "Valid combinations: $((${#COMBOS[@]} - missing_count))/${#COMBOS[@]}"

if [[ -f "$OUTPUT_FILE" && -s "$OUTPUT_FILE" ]]; then
    echo ""
    echo "Contents:"
    cat "$OUTPUT_FILE"
fi