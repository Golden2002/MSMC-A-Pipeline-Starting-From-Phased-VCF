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
#SBATCH --array=0-100  # Array task for parallel processing

# =====================================
# Strict mode
set -euo pipefail

# =====================================
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# =====================================
# Get array task ID
# If not using SLURM array, use command line argument
if [[ -n "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    TASK_ID="${SLURM_ARRAY_TASK_ID}"
elif [[ -n "$1" ]]; then
    TASK_ID="$1"
else
    TASK_ID=0
fi

# =====================================
# Function: Extract single-sample VCF for a specific sample
# =====================================
extract_single_vcf() {
    local sample_id="$1"
    local pop_name="$2"
    local chr="$3"
    
    # Output file
    local output_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.vcf.gz"
    
    # Check if already exists (resume mode)
    if [[ "${RESUME_MODE}" -eq 1 && -f "${output_vcf}" ]]; then
        log "VCF for ${sample_id} chr${chr} already exists, skipping..."
        return 0
    # Extract sample from VCF using bcftools
    # 正确方式: 一次命令同时指定样本和染色体
    ${BCFTOOLS} view \
        -s "${sample_id}" \
        -r "${chr}" \
        -Oz \
        -o "${output_vcf}" \
        "${PHASED_VCF}"
    
    if [[ $? -eq 0 && -f "${output_vcf}" ]]; then
        # Index the VCF
        ${TABIX} -p vcf "${output_vcf}" 2>/dev/null || true
        log "Extracted VCF for ${sample_id} chr${chr}"
        return 0
    else
        log "ERROR: Failed to extract VCF for ${sample_id} chr${chr}"
        return 1
    fi
}

# =====================================
# Main: Process all samples for all chromosomes
# =====================================

log "=========================================="
log "Starting Single-Sample VCF Extraction"
log "Task ID: ${TASK_ID}"
log "=========================================="

# Check required files
check_file "${PHASED_VCF}"
check_file "${SAMPLE_INFO}"

# Get list of populations from sample list directory
if [[ ! -d "${SAMPLE_LIST_DIR}" ]]; then
    error_exit "Sample list directory not found: ${SAMPLE_LIST_DIR}"
fi

# Create a list of all (sample, population) pairs
ALL_SAMPLES=()
while IFS=$'\t' read -r sample pop; do
    ALL_SAMPLES+=("${sample}:${pop}")
done < "${SAMPLE_LIST_DIR}/all_samples.txt"

log "Total samples to process: ${#ALL_SAMPLES[@]}"

# Process in batches (TASK_ID determines which batch)
# Each task processes one sample per chromosome
BATCH_SIZE=1
START_IDX=$((TASK_ID * BATCH_SIZE))

for ((i=START_IDX; i<START_IDX+BATCH_SIZE && i<${#ALL_SAMPLES[@]}; i++)); do
    sample_pop="${ALL_SAMPLES[$i]}"
    sample_id="${sample_pop%%:*}"
    pop_name="${sample_pop##*:}"
    
    log "Processing sample: ${sample_id} (${pop_name})"
    
    # Process each chromosome
    for chr in ${CHROMOSOMES}; do
        extract_single_vcf "${sample_id}" "${pop_name}" "${chr}"
    done
done

# =====================================
# Summary
# =====================================

log "=========================================="
log "Single-Sample VCF Extraction Complete"
log "=========================================="
log "Output directory: ${SINGLE_VCF_DIR}"

# Count files created
n_files=$(ls -1 "${SINGLE_VCF_DIR}"/*.vcf.gz 2>/dev/null | wc -l)
log "VCF files created: ${n_files}"

# Mark step as completed
mark_step "${WORK_DIR}/.step_02_vcf_done"

log "VCF extraction step completed successfully!"
