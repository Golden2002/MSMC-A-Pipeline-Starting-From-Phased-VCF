#!/bin/bash
# =============================================================================
# 01_select_samples.sh - Sample Selection
# =============================================================================
# Randomly selects n samples per population from the sample info file.
# Generates per-population sample lists and a master list for the pipeline.
#
# Usage:
#   source config.sh
#   sbatch 01_select_samples.sh
#
# Output:
#   sample_lists/{pop}.txt - Per-population sample lists
#   sample_lists/all_samples.txt - Master list (sample\tpop)
# =============================================================================

#SBATCH --job-name=MSMC_SampleSelect
#SBATCH --output=%x_%A_%a.log
#SBATCH --error=%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --mem=8G
#SBATCH --cpus-per-task=4

set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config.sh not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# =============================================================================
# Function: Select random samples for a population
# =============================================================================
select_samples_for_pop() {
    local pop_name="$1"
    local n_samples="$2"
    local output_file="$3"
    local seed="${4:-42}"

    # Sample info format: SampleID\tPopulation\tRegion\tSubRegion
    local pop_samples=$(awk -F'\t' -v pop="$pop_name" 'NR>1 && $2==pop {print $1}' "${SAMPLE_INFO}" | sort -u)

    if [[ -z "$pop_samples" ]]; then
        log "WARNING: No samples found for population: $pop_name"
        return 1
    fi

    local total_samples=$(echo "$pop_samples" | wc -l)
    log "Found $total_samples samples for population: $pop_name"

    if [[ $total_samples -lt $n_samples ]]; then
        log "WARNING: Only $total_samples available, selecting all"
        n_samples=$total_samples
    fi

    # Random selection with seed for reproducibility
    local selected=$(echo "$pop_samples" | shuf --random-source=<(yes $seed) -n "$n_samples")

    echo "$selected" > "$output_file"
    log "Selected $n_samples samples for $pop_name"
}

# =============================================================================
# Main: Select samples for all populations
# =============================================================================
log "=========================================="
log "Starting Sample Selection for MSMC"
log "=========================================="

check_file "${SAMPLE_INFO}"

IFS=',' read -ra POP_ARRAY <<< "${ALL_POPS}"

for pop in "${POP_ARRAY[@]}"; do
    pop=$(echo "$pop" | xargs)
    [[ -z "$pop" ]] && continue

    output_file="${SAMPLE_LIST_DIR}/${pop}.txt"

    if [[ "${RESUME_MODE}" -eq 1 && -f "${output_file}" ]]; then
        log "Sample list for $pop exists, skipping..."
        continue
    fi

    select_samples_for_pop "$pop" "${N_SAMPLES_PER_POP}" "$output_file" "${RANDOM_SEED}"
done

# =============================================================================
# Create master sample list
# =============================================================================
MASTER_LIST="${SAMPLE_LIST_DIR}/all_samples.txt"
> "${MASTER_LIST}"

for pop in "${POP_ARRAY[@]}"; do
    pop=$(echo "$pop" | xargs)
    [[ -z "$pop" ]] && continue

    sample_file="${SAMPLE_LIST_DIR}/${pop}.txt"
    [[ -f "$sample_file" ]] || continue

    while IFS= read -r sample; do
        echo -e "${sample}\t${pop}" >> "${MASTER_LIST}"
    done < "$sample_file"
done

log "Master sample list: ${MASTER_LIST}"
log "Total samples: $(wc -l < "${MASTER_LIST}")"

mark_step "${WORK_DIR}/.step_01_samples_done"
log "Sample selection complete"