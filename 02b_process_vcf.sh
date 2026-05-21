#!/bin/bash
# =============================================================================
# 02b_process_vcf.sh - Process VCF to MSMC Format
# =============================================================================
# Uses vcfAllSiteParser to generate per-sample mask and variant-only VCF
# files required for MSMC input generation.
#
# Usage:
#   source config.sh
#   N=$(wc -l < sample_lists/all_samples.txt)
#   sbatch --array=0-$((N-1)) 02b_process_vcf.sh
#
# Output:
#   single_vcf/{pop}_{sample}_chr{N}.variant.vcf.gz - Variant sites only
#   single_vcf/{pop}_{sample}_chr{N}.mask.bed.gz - Per-sample mask
#
# Requirements: vcfAllSiteParser.py from msmc-tools
# =============================================================================

#SBATCH --job-name=MSMC_ProcessVCF
#SBATCH --output=%x_%A_%a.log
#SBATCH --error=%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4

set -euo pipefail

CONFIG_FILE="$(dirname "$0")/config.sh"
[[ ! -f "$CONFIG_FILE" ]] && echo "ERROR: config.sh not found" && exit 1
source "$CONFIG_FILE"

# Get array task ID
TASK_ID="${SLURM_ARRAY_TASK_ID:-${1:-0}}"

# =============================================================================
# Function: Process single-sample VCF to MSMC format
# =============================================================================
# vcfAllSiteParser usage: cat input.vcf | ./vcfAllSiteParser.py chrN mask.bed.gz > out.vcf
process_vcf_to_msmc() {
    local sample_id="$1"
    local pop_name="$2"
    local chr="$3"

    local input_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.vcf.gz"
    local variant_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.variant.vcf.gz"
    local sample_mask="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.mask.bed.gz"

    [[ "${RESUME_MODE}" -eq 1 && -f "${variant_vcf}" && -f "${sample_mask}" ]] && return 0

    [[ ! -f "$input_vcf" ]] && log "ERROR: Input VCF not found: $input_vcf" && return 1

    # Find vcfAllSiteParser script
    local vcf_parser="${MSMC_TOOLS_DIR}/vcfAllSiteParser.py"
    if [[ ! -f "$vcf_parser" ]]; then
        log "WARNING: vcfAllSiteParser.py not found at ${vcf_parser}"
        return 1
    fi

    # Process: cat VCF | vcfAllSiteParser.py > variant.vcf (同时生成mask)
    # Using -Ov for direct VCF output (faster than -Oz)
    ${BCFTOOLS} view -Ov "${input_vcf}" | \
    ${PYTHON2} "${vcf_parser}" "chr${chr}" "${sample_mask}" | \
    ${BCFTOOLS} view -Oz -o "${variant_vcf}"

    if [[ $? -eq 0 && -f "${variant_vcf}" && -f "${sample_mask}" ]]; then
        ${TABIX} -p -f vcf "${variant_vcf}" 2>/dev/null || true
        log "Processed VCF for ${sample_id} chr${chr}"
        return 0
    else
        log "ERROR: Failed to process VCF for ${sample_id} chr${chr}"
        return 1
    fi
}

# =============================================================================
# Fallback: Simple variant extraction using bcftools
# =============================================================================
process_vcf_simple() {
    local sample_id="$1"
    local pop_name="$2"
    local chr="$3"

    local input_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.vcf.gz"
    local variant_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.variant.vcf.gz"

    [[ ! -f "$input_vcf" ]] && return 1

    # Extract only variant sites (no indels)
    ${BCFTOOLS} view -r "${chr}" -V indels "${input_vcf}" -Oz -o "${variant_vcf}" 2>/dev/null

    if [[ $? -eq 0 && -f "${variant_vcf}" ]]; then
        ${TABIX} -p -f vcf "${variant_vcf}" 2>/dev/null || true
        log "Extracted variants for ${sample_id} chr${chr}"
        return 0
    fi
    return 1
}

# =============================================================================
# Main: Process all samples
# =============================================================================
log "=========================================="
log "Starting VCF Processing for MSMC"
log "Task ID: ${TASK_ID}"
log "=========================================="

check_file "${PHASED_VCF}"

# Build list of all (sample, population) pairs
ALL_SAMPLES=()
while IFS=$'\t' read -r sample pop; do
    ALL_SAMPLES+=("${sample}:${pop}")
done < "${SAMPLE_LIST_DIR}/all_samples.txt"

log "Total samples to process: ${#ALL_SAMPLES[@]}"

# Process one sample per task
BATCH_SIZE=1
START_IDX=$((TASK_ID * BATCH_SIZE))

for ((i=START_IDX; i<START_IDX+BATCH_SIZE && i<${#ALL_SAMPLES[@]}; i++)); do
    sample_pop="${ALL_SAMPLES[$i]}"
    sample_id="${sample_pop%%:*}"
    pop_name="${sample_pop##*:}"

    log "Processing sample: ${sample_id} (${pop_name})"

    for chr in ${CHROMOSOMES}; do
        # Try vcfAllSiteParser first, fallback to simple method
        process_vcf_to_msmc "${sample_id}" "${pop_name}" "${chr}" || \
        process_vcf_simple "${sample_id}" "${pop_name}" "${chr}"
    done
done

# =============================================================================
# Summary
# =============================================================================
n_variant=$(find "${SINGLE_VCF_DIR}" -name "*.variant.vcf.gz" | wc -l)
n_mask=$(find "${SINGLE_VCF_DIR}" -name "*.mask.bed.gz" | wc -l)
log "Variant VCF files: ${n_variant}"
log "Mask files: ${n_mask}"

mark_step "${WORK_DIR}/.step_02b_vcf_processing_done"
log "VCF processing complete"