#!/bin/bash
# =====================================
# Step 1: Sample Selection
# =====================================
# Description: Randomly select n samples per population from sample info file
# Author: Generated for MSMC Pipeline
# Date: 2025-03-11
# =====================================

#SBATCH --job-name=MSMC_SampleSelect
#SBATCH --output=${WORK_DIR}/logs/%x_%A_%a.log
#SBATCH --error=${WORK_DIR}/logs/%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --partition=batch
#SBATCH --mem=8G
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1

# =====================================
# Strict mode
set -euo pipefail

# =====================================
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#source "${SCRIPT_DIR}/config.sh" # 当作业提交给 SLURM Workload Manager 时：
                                    #
                                    #sbatch 会把脚本复制到计算节点
                                    #
                                    #临时存放在
                                    # /var/spool/slurmd/jobXXXX/
#CONFIG_FILE="${SLURM_SUBMIT_DIR}/config.sh" # 不要依赖脚本目录，而是使用 SLURM 提交目录变量。这样便于脚本移植
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config.sh not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"
# =====================================
# Function: Randomly select samples for a population
# =====================================
select_samples_for_pop() {
    local pop_name="$1"
    local n_samples="$2"
    local output_file="$3"
    local seed="${4:-42}"

    # Get all samples for this population
    # Sample info format: SampleID\tPopulation\tRegion\tSubRegion
    local pop_samples=$(awk -F'\t' -v pop="$pop_name" 'NR>1 && $2==pop {print $1}' "${SAMPLE_INFO}" | sort -u)

    if [[ -z "$pop_samples" ]]; then
        log "WARNING: No samples found for population: $pop_name"
        return 1
    fi

    local total_samples=$(echo "$pop_samples" | wc -l)
    log "Found $total_samples samples for population: $pop_name"

    # Check if we have enough samples
    if [[ $total_samples -lt $n_samples ]]; then
        log "WARNING: Only $total_samples samples available for $pop_name, selecting all"
        n_samples=$total_samples
    fi

    # Random selection using shuf
    # Use the provided seed for reproducibility
    local selected=$(echo "$pop_samples" | shuf --random-source=<(yes $seed) -n "$n_samples")
    
    # Write to output file
    echo "$selected" > "$output_file"
    
    log "Selected $n_samples samples for $pop_name: $(echo $selected | tr '\n' ',')"
}

# =====================================
# Main: Select samples for all populations
# =====================================

log "=========================================="
log "Starting Sample Selection for MSMC Analysis"
log "=========================================="

# Check required files
check_file "${SAMPLE_INFO}"

# Parse population list (comma-separated)
IFS=',' read -ra POP_ARRAY <<< "${ALL_POPS}"

# Process each population
for pop in "${POP_ARRAY[@]}"; do
    pop=$(echo "$pop" | xargs)  # Trim whitespace
    
    if [[ -z "$pop" ]]; then
        continue
    fi
    
    # Output file for this population
    output_file="${SAMPLE_LIST_DIR}/${pop}.txt"
    
    # Skip if already exists and resume mode is enabled
    if [[ "${RESUME_MODE}" -eq 1 && -f "${output_file}" ]]; then
        log "Sample list for $pop already exists, skipping..."
        continue
    fi
    
    log "Processing population: $pop"
    
    # Select samples for this population
    select_samples_for_pop "$pop" "${N_SAMPLES_PER_POP}" "$output_file" "${RANDOM_SEED}"
    
    if [[ $? -ne 0 ]]; then
        log "ERROR: Failed to select samples for $pop"
        continue
    fi
done

# =====================================
# Create master sample list file
# =====================================

log "Creating master sample list..."

MASTER_LIST="${SAMPLE_LIST_DIR}/all_samples.txt"
> "${MASTER_LIST}"  # Clear file

for pop in "${POP_ARRAY[@]}"; do
    pop=$(echo "$pop" | xargs)
    
    if [[ -z "$pop" ]]; then
        continue
    fi
    
    sample_file="${SAMPLE_LIST_DIR}/${pop}.txt"
    
    if [[ -f "$sample_file" ]]; then
        while IFS= read -r sample; do
            echo -e "${sample}\t${pop}" >> "${MASTER_LIST}"
        done < "${sample_file}"
    fi
done

log "Master sample list created: ${MASTER_LIST}"
log "Total samples: $(wc -l < "${MASTER_LIST}")"

# =====================================
# Summary
# =====================================

log "=========================================="
log "Sample Selection Complete"
log "=========================================="
log "Output directory: ${SAMPLE_LIST_DIR}"
log "Master list: ${MASTER_LIST}"

# List all sample files
log "Sample files created:"
ls -lh "${SAMPLE_LIST_DIR}"/*.txt 2>/dev/null || true

# Mark step as completed
mark_step "${WORK_DIR}/.step_01_samples_done"

log "Sample selection step completed successfully!"
