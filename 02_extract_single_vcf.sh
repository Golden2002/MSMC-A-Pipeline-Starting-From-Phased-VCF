#!/bin/bash
# =====================================
# Step 2: Extract Single-Sample VCF Files
# =====================================
# Description: Extract individual VCF files for each selected sample from phased VCF
# Author: Generated for MSMC Pipeline
# Date: 2025-03-11
# =====================================

#SBATCH --job-name=MSMC_ExtractVCF
#SBATCH --output=/PATH/TO/logs/%x_%A_%a.log
#SBATCH --error=/PATH/TO/logs/%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --partition=batch
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
# #SBATCH --array=0-100  # Array task for parallel processing

# =====================================
#N=$(wc -l < sample_lists/all_samples.txt)
#
#sbatch --array=0-$((N-1)) msmc/02_extract_single_vcf.sh
# Strict mode
set -euo pipefail

# =====================================
# Load configuration
# =====================================

CONFIG_FILE="msmc/config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config.sh not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

log "Configuration loaded"

# =====================================
# Detect task id
# =====================================

TASK_ID="${SLURM_ARRAY_TASK_ID:-${1:-0}}"

# =====================================
# Check required files
# =====================================

check_file "${PHASED_VCF}"
check_file "${SAMPLE_LIST_DIR}/all_samples.txt"

# =====================================
# Get sample info for this task
# =====================================

sample_line=$(sed -n "$((TASK_ID+1))p" "${SAMPLE_LIST_DIR}/all_samples.txt")

if [[ -z "$sample_line" ]]; then
    log "No sample for TASK_ID=${TASK_ID}, exiting"
    exit 0
fi

sample_id=$(echo "$sample_line" | cut -f1)
pop_name=$(echo "$sample_line" | cut -f2)

log "Processing sample ${sample_id} (${pop_name})"

# =====================================
# Extract VCF per chromosome
# =====================================

extract_single_vcf() {

    local chr="$1"

    local output_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.vcf.gz"

    if [[ "${RESUME_MODE}" -eq 1 && -f "${output_vcf}" ]]; then
        log "Skipping existing ${output_vcf}"
        return
    fi

    log "Extracting chr${chr}"

    ${BCFTOOLS} view \
        -s "${sample_id}" \
        -r "chr${chr}" \
        -Oz \
        -o "${output_vcf}" \
        "${PHASED_VCF}"

    ${TABIX} -f -p vcf "${output_vcf}"

}

# =====================================
# Main loop
# =====================================

for chr in ${CHROMOSOMES}; do
    extract_single_vcf "${chr}"
done

log "Finished sample ${sample_id}"

# =====================================
# Summary
# =====================================

if [[ "${TASK_ID}" == "0" ]]; then

    n_files=$(ls "${SINGLE_VCF_DIR}"/*.vcf.gz 2>/dev/null | wc -l)

    log "=========================================="
    log "VCF extraction finished"
    log "Total files: ${n_files}"
    log "=========================================="

    mark_step "${WORK_DIR}/.step_02_vcf_done"

fi
