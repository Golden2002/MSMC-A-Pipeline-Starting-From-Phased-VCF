#!/bin/bash
# =====================================
# Step 3: Generate MSMC Input Files
# =====================================
# Description: Generate MSMC input files using generate_multihetsep.py
#              Requires single-sample VCF files and mask files
# Author: Generated for MSMC Pipeline
# Date: 2025-03-11
# =====================================

#SBATCH --job-name=MSMC_GenInput
#SBATCH --output=/PATH/TO/logs/%x_%A_%a.log
#SBATCH --error=/PATH/TO/logs/%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --partition=batch
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1

# =====================================
# Strict mode
set -euo pipefail

# =====================================
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# =====================================
# Function: Generate MSMC input for one population
# =====================================
generate_msmc_input() {
    local pop_name="$1"
    local sample_list="$2"
    local chr="$3"
    
    local output_file="${MSMC_INPUT_DIR}/${pop_name}_chr${chr}.msmc"
    
    # Check if already exists
    if [[ "${RESUME_MODE}" -eq 1 && -f "${output_file}" ]]; then
        log "MSMC input for ${pop_name} chr${chr} already exists, skipping..."
        return 0
    fi
    
    # Collect all VCF files for this population and chromosome
    local vcf_files=()
    while IFS= read -r sample; do
        vcf_file="${SINGLE_VCF_DIR}/${pop_name}_${sample}_chr${chr}.vcf.gz"
        if [[ -f "$vcf_file" ]]; then
            vcf_files+=("$vcf_file")
        else
            log "WARNING: VCF file not found: ${vcf_file}"
        fi
    done < "$sample_list"
    
    # Check if we have at least 2 samples
    if [[ ${#vcf_files[@]} -lt 2 ]]; then
        log "ERROR: Not enough VCF files for ${pop_name} chr${chr} (found ${#vcf_files[@]})"
        return 1
    fi
    
    # =====================================
    # 正确的调用方式 (根据README):
    # generate_multihetsep.py --mask sample1_mask --mask sample2_mask --mask mappability \
    #                           sample1.vcf.gz sample2.vcf.gz > output.msmc
    # 
    # 注意: 需要使用处理后的variant-only VCF和per-sample mask
    # =====================================
    
    # Build command
    local cmd="${PYTHON3} ${GENERATE_MULTIHETSEP}"
    
    # Add per-sample masks (每个样本的mask)
    while IFS= read -r sample; do
        sample_mask="${SINGLE_VCF_DIR}/${pop_name}_${sample}_chr${chr}.mask.bed.gz"
        if [[ -f "$sample_mask" ]]; then
            cmd="${cmd} --mask ${sample_mask}"
        fi
    done < "$sample_list"
    
    # Add mappability mask (按染色体)
    if [[ -f "${MAP_MASK}" ]]; then
        # 检查是否为染色体特异性
        if [[ "${MAP_MASK}" == *"chr"* ]]; then
            cmd="${cmd} --mask ${MAP_MASK}"
        else
            # 需要按染色体处理: ${MAP_MASK%.bed}.chr${chr}.bed.gz
            cmd="${cmd} --mask ${MAP_MASK%.bed}.chr${chr}.bed.gz"
        fi
    fi
    
    # Add variant-only VCF files (从Step 2b处理后的)
    while IFS= read -r sample; do
        variant_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample}_chr${chr}.variant.vcf.gz"
        if [[ -f "$variant_vcf" ]]; then
            cmd="${cmd} ${variant_vcf}"
        fi
    done < "$sample_list"
    
    # Output to stdout, redirect to file
    log "Running: ${cmd} > ${output_file}"
    eval "${cmd}" > "${output_file}" 2>&1
    
    if [[ $? -eq 0 && -s "${output_file}" ]]; then
        log "Generated MSMC input for ${pop_name} chr${chr} with ${#vcf_files[@]} samples"
        return 0
    else
        log "ERROR: Failed to generate MSMC input for ${pop_name} chr${chr}"
        return 1
    fi
}

# =====================================
# Main: Process all populations
# =====================================

log "=========================================="
log "Starting MSMC Input Generation"
log "=========================================="

# Check required files
check_file "${GENERATE_MULTIHETSEP}"
check_file "${PHASED_VCF}"

# Get list of populations from sample list directory
if [[ ! -d "${SAMPLE_LIST_DIR}" ]]; then
    error_exit "Sample list directory not found: ${SAMPLE_LIST_DIR}"
fi

# Process each population
for pop_file in "${SAMPLE_LIST_DIR}"/*.txt; do
    if [[ -f "${pop_file}" && "$(basename ${pop_file})" != "all_samples.txt" ]]; then
        pop_name=$(basename "${pop_file}" .txt)
        sample_list="${pop_file}"
        
        log "Processing population: ${pop_name}"
        
        # Process each chromosome
            generate_msmc_input "${pop_name}" "${sample_list}" "${chr}"
    fi
done

# =====================================
# Summary
# =====================================

log "=========================================="
log "MSMC Input Generation Complete"
log "=========================================="
log "Output directory: ${MSMC_INPUT_DIR}"

# Count files created
n_files=$(ls -1 "${MSMC_INPUT_DIR}"/*.msmc 2>/dev/null | wc -l)
log "MSMC input files created: ${n_files}"

# List populations processed
log "Populations processed:"
ls -1 "${SAMPLE_LIST_DIR}"/*.txt 2>/dev/null | xargs -I {} basename {} .txt | grep -v "all_samples" || true

# Mark step as completed
mark_step "${WORK_DIR}/.step_03_input_done"

log "MSMC input generation step completed successfully!"
