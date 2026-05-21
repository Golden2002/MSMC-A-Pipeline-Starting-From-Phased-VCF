#!/bin/bash
# =============================================================================
# 02_extract_single_vcf.sh - Extract Single-Sample VCF Files
# =============================================================================
# Extracts individual VCF files for each selected sample from the phased VCF.
# Designed to run as a SLURM array job (one task per sample).
#
# Usage:
#   source config.sh
#   N=$(wc -l < sample_lists/all_samples.txt)
#   sbatch --array=0-$((N-1)) 02_extract_single_vcf.sh
#
# Output:
#   single_vcf/{pop}_{sample}_chr{N}.vcf.gz - Per-sample, per-chromosome VCF
# =============================================================================

#SBATCH --job-name=MSMC_ExtractVCF
#SBATCH --output=%x_%A_%a.log
#SBATCH --error=%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
# #SBATCH --array=0-100  # Uncomment and set N for array job

set -euo pipefail

CONFIG_FILE="$(dirname "$0")/config.sh"
[[ ! -f "$CONFIG_FILE" ]] && echo "ERROR: config.sh not found" && exit 1
source "$CONFIG_FILE"

# Get task ID from SLURM array or argument
TASK_ID="${SLURM_ARRAY_TASK_ID:-${1:-0}}"

check_file "${PHASED_VCF}"
check_file "${SAMPLE_LIST_DIR}/all_samples.txt"

# =============================================================================
# Get sample info for this task
# =============================================================================
sample_line=$(sed -n "$((TASK_ID+1))p" "${SAMPLE_LIST_DIR}/all_samples.txt")

[[ -z "$sample_line" ]] && log "No sample for TASK_ID=$TASK_ID, exiting" && exit 0

sample_id=$(echo "$sample_line" | cut -f1)
pop_name=$(echo "$sample_line" | cut -f2)

log "Processing sample ${sample_id} (${pop_name})"

# =============================================================================
# Extract VCF per chromosome
# =============================================================================
extract_single_vcf() {
    local chr="$1"
    local output_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.vcf.gz"

    [[ "${RESUME_MODE}" -eq 1 && -f "${output_vcf}" ]] && return

    log "Extracting chr${chr}"

    ${BCFTOOLS} view -s "${sample_id}" -r "chr${chr}" -Oz -o "${output_vcf}" "${PHASED_VCF}"
    ${TABIX} -f -p vcf "${output_vcf}"
}

for chr in ${CHROMOSOMES}; do
    extract_single_vcf "${chr}"
done

log "Finished sample ${sample_id}"

# =============================================================================
# Summary (task 0 only)
# =============================================================================
if [[ "${TASK_ID}" == "0" ]]; then
    n_files=$(ls "${SINGLE_VCF_DIR}"/*.vcf.gz 2>/dev/null | wc -l)
    log "VCF extraction finished. Total files: ${n_files}"
    mark_step "${WORK_DIR}/.step_02_vcf_done"
fi