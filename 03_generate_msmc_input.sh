#!/bin/bash
# =============================================================================
# 03_generate_msmc_input.sh - Generate MSMC Input Files
# =============================================================================
# Generates MSMC input files (multihetsep format) for:
# 1. Joint analysis of all samples together
# 2. Custom group combinations defined in group_combinations.txt
#
# Uses generate_multihetsep.py from msmc-tools.
#
# Usage:
#   source config.sh
#   bash 03_generate_msmc_input.sh
#
# Output:
#   msmc_input/ALL_chr{N}.msmc - Joint analysis input
#   msmc_input/{combo}_chr{N}.msmc - Per-combination input
#
# Requirements: generate_multihetsep.py, variant VCFs, mask files
# =============================================================================

#SBATCH --job-name=MSMC_GenInput
#SBATCH --output=%x_%A_%a.log
#SBATCH --error=%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4

set -euo pipefail

CONFIG_FILE="$(dirname "$0")/config.sh"
[[ ! -f "$CONFIG_FILE" ]] && echo "ERROR: config.sh not found" && exit 1
source "$CONFIG_FILE"

# =============================================================================
# Sample order file (for joint analysis)
# =============================================================================
ALL_SAMPLES_ORDER_FILE="${WORK_DIR}/all_samples_order.txt"

# =============================================================================
# Function: Generate joint MSMC input for all samples
# =============================================================================
generate_joint_msmc_input() {
    local chr="$1"
    local output_file="${MSMC_INPUT_DIR}/ALL_chr${chr}.msmc"

    if [[ "${RESUME_MODE}" -eq 1 && -f "${output_file}" ]]; then
        log "Joint MSMC input for chr${chr} exists, skipping..."
        return 0
    fi

    cmd=("${PYTHON3}" "${GENERATE_MULTIHETSEP}")

    # Add mask files
    while IFS= read -r sample_id; do
        sample_mask="${SINGLE_VCF_DIR}/${sample_id}_chr${chr}.mask.bed.gz"
        [[ -f "$sample_mask" ]] && cmd+=(--mask "$sample_mask")
    done < "${ALL_SAMPLES_ORDER_FILE}"

    # Add mappability mask
    if [[ -f "${MAP_MASK}" ]]; then
        if [[ "${MAP_MASK}" == *"chr"* ]]; then
            cmd+=(--mask "${MAP_MASK}")
        else
            cmd+=(--mask "${MAP_MASK%.bed}.chr${chr}.bed.gz")
        fi
    fi

    # Add variant VCF files
    while IFS= read -r sample_id; do
        variant_vcf="${SINGLE_VCF_DIR}/${sample_id}_chr${chr}.variant.vcf.gz"
        [[ -f "$variant_vcf" ]] && cmd+=("$variant_vcf")
    done < "${ALL_SAMPLES_ORDER_FILE}"

    log "Running: ${cmd[*]} > ${output_file}"
    "${cmd[@]}" > "${output_file}" 2>> "${LOG_DIR}/multihetsep.log"

    if [[ $? -eq 0 && -s "${output_file}" ]]; then
        log "Generated joint MSMC input for chr${chr}"
    else
        log "ERROR: Failed to generate joint MSMC input for chr${chr}"
        return 1
    fi
}

# =============================================================================
# Function: Build sample list file for a combo
# =============================================================================
build_sample_list_for_combo() {
    local combo_name="$1"
    shift
    local pops=("$@")
    local outfile="${WORK_DIR}/sample_orders/${combo_name}.samples"
    mkdir -p "$(dirname "$outfile")"
    > "$outfile"

    for pop in "${pops[@]}"; do
        local pop_file="${SAMPLE_LIST_DIR}/${pop}.txt"
        [[ ! -f "$pop_file" ]] && error_exit "Missing sample list: $pop_file"
        while IFS= read -r sample; do
            echo "${pop}_${sample}" >> "$outfile"
        done < "$pop_file"
    done

    echo "$outfile"
}

# =============================================================================
# Function: Generate MSMC input for a combo
# =============================================================================
generate_combo_msmc_input() {
    local combo_name="$1"
    local chr="$2"
    local sample_file="$3"
    local output_file="${MSMC_INPUT_DIR}/${combo_name}_chr${chr}.msmc"

    cmd=("${PYTHON3}" "${GENERATE_MULTIHETSEP}")

    # Add mask files
    while IFS= read -r sample; do
        mask_file="${SINGLE_VCF_DIR}/${sample}_chr${chr}.mask.bed.gz"
        [[ -f "$mask_file" ]] && cmd+=(--mask "$mask_file")
    done < "$sample_file"

    # Add mappability mask
    if [[ -f "${MAP_MASK}" ]]; then
        if [[ "${MAP_MASK}" == *"chr"* ]]; then
            cmd+=(--mask "${MAP_MASK}")
        else
            cmd+=(--mask "${MAP_MASK%.bed}.chr${chr}.bed.gz")
        fi
    fi

    # Add variant VCF files
    while IFS= read -r sample; do
        vcf_file="${SINGLE_VCF_DIR}/${sample}_chr${chr}.variant.vcf.gz"
        [[ -f "$vcf_file" ]] && cmd+=("$vcf_file")
    done < "$sample_file"

    log "Running combo ${combo_name}, chr${chr}"
    "${cmd[@]}" > "$output_file" 2>> "${LOG_DIR}/multihetsep.log"

    if [[ $? -eq 0 && -s "$output_file" ]]; then
        log "Generated MSMC input for combo ${combo_name}, chr${chr}"
    else
        log "ERROR: Failed to generate MSMC input for combo ${combo_name}, chr${chr}"
        return 1
    fi
}

# =============================================================================
# Main: Generate MSMC inputs
# =============================================================================
log "=========================================="
log "Starting MSMC Input Generation"
log "=========================================="

check_file "${GENERATE_MULTIHETSEP}"

# Check if group combination file exists
GROUP_COMBO_FILE="${WORK_DIR}/group_combinations.txt"

if [[ -f "${GROUP_COMBO_FILE}" ]]; then
    log "Processing custom group combinations from: ${GROUP_COMBO_FILE}"

    while read -r combo_name rest; do
        [[ -z "$combo_name" || "$combo_name" == \#* ]] && continue

        pops=($rest)
        combo_sample_file=$(build_sample_list_for_combo "$combo_name" "${pops[@]}")

        for chr in ${CHROMOSOMES}; do
            generate_combo_msmc_input "$combo_name" "$chr" "$combo_sample_file"
        done
    done < "$GROUP_COMBO_FILE"

    log "Custom group combination MSMC input generation complete"
else
    log "No group combination file found at ${GROUP_COMBO_FILE}"
    log "Skipping custom combos"
fi

# =============================================================================
# Summary
# =============================================================================
log "=========================================="
log "MSMC Input Generation Complete"
log "=========================================="
log "Output directory: ${MSMC_INPUT_DIR}"

n_files=$(ls -1 "${MSMC_INPUT_DIR}"/*.msmc 2>/dev/null | wc -l)
log "Total MSMC input files: ${n_files}"

mark_step "${WORK_DIR}/.step_03_input_done"
log "Done"