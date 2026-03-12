#!/bin/bash
# =====================================
# Step 2b: Process VCF to MSMC format
# =====================================
# Description: Use vcfAllSiteParser to generate per-sample mask 
#              and variant-only VCF for MSMC input generation
# Author: Generated for MSMC Pipeline
# Date: 2025-03-11
# =====================================

#SBATCH --job-name=MSMC_ProcessVCF
#SBATCH --output=/PATH/TO/logs/%x_%A_%a.log
#SBATCH --error=/PATH/TO/logs/%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --partition=batch
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
##SBATCH --array=0-100

# =====================================
# Strict mode
set -euo pipefail

#Total samples: 32 提交方式。根据样本数确定并行任务数
 #N=32
 #sbatch --array=0-$((N-1)) msmc/02b_process_vcf.sh
 #Submitted batch job

# =====================================
# Load configuration
#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#source "${SCRIPT_DIR}/config.sh"

CONFIG_FILE="msmc/config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config.sh not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

log "Configuration loaded"
# =====================================
# Get array task ID
if [[ -n "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    TASK_ID="${SLURM_ARRAY_TASK_ID}"
elif [[ -n "$1" ]]; then
    TASK_ID="$1"
else
    TASK_ID=0
fi

# =====================================
# Function: Process single-sample VCF to MSMC format
# =====================================
# vcfAllSiteParser.py 用法:
# cat input.vcf | ./vcfAllSiteParser.py chr1 mask_chr1.bed.gz > variant_only_chr1.vcf.gz
process_vcf_to_msmc() {
    local sample_id="$1"
    local pop_name="$2"
    local chr="$3"

    # Input: single-sample VCF (all sites, from Step 2)
    local input_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.vcf.gz"

    # Output 1: variant-only VCF
    local variant_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.variant.vcf.gz"

    # Output 2: per-sample mask
    local sample_mask="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.mask.bed.gz"

    # Check if already exists
    if [[ "${RESUME_MODE}" -eq 1 && -f "${variant_vcf}" && -f "${sample_mask}" ]]; then
        log "Processed VCF for ${sample_id} chr${chr} already exists, skipping..."
        return 0
    fi

    # Check input exists
    if [[ ! -f "$input_vcf" ]]; then
        log "ERROR: Input VCF not found: ${input_vcf}"
        return 1
    fi

    # Get vcfAllSiteParser script
    local vcf_parser="${MSMC_TOOLS_DIR}/vcfAllSiteParser.py"
    if [[ ! -f "$vcf_parser" ]]; then
        vcf_parser="${SCRIPT_DIR}/guide_from_github/vcfAllSiteParser_AllowMultiallelic.py"
    fi

    if [[ ! -f "$vcf_parser" ]]; then
        log "ERROR: vcfAllSiteParser.py not found"
        return 1
    fi

    # Process: cat VCF | vcfAllSiteParser.py > variant.vcf
    # 同时生成 mask 文件
#    ${BCFTOOLS} view -r "${chr}" "${input_vcf}" 2>/dev/null | \
#    ${PYTHON3} "${vcf_parser}" "${chr}" "${sample_mask}" 2>/dev/null | \
#    ${BCFTOOLS} view -Oz -o "${variant_vcf}" 2>/dev/null

    # 删除 -r chr
          #使用 -Ou
          #减少 IO
    # 不需要额外对mask文件进行bgzip，因为原脚本解决了这个问题。
    ${BCFTOOLS} view -Ou "${input_vcf}" | \
    ${PYTHON3} "${vcf_parser}" "${chr}" "${sample_mask}" | \
    ${BCFTOOLS} view -Oz -o "${variant_vcf}"

    if [[ $? -eq 0 && -f "${variant_vcf}" && -f "${sample_mask}" ]]; then
        # Index the variant VCF
        ${TABIX} -p -f vcf "${variant_vcf}" 2>/dev/null || true
        log "Processed VCF for ${sample_id} chr${chr}"
        return 0
    else
        log "ERROR: Failed to process VCF for ${sample_id} chr${chr}"
        return 1
    fi
}

# =====================================
# Alternative: If vcfAllSiteParser not available, use bcftools
# =====================================
# 也可以直接用bcftools提取变异位点
process_vcf_simple() {
    local sample_id="$1"
    local pop_name="$2"
    local chr="$3"

    local input_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.vcf.gz"
    local variant_vcf="${SINGLE_VCF_DIR}/${pop_name}_${sample_id}_chr${chr}.variant.vcf.gz"

    if [[ ! -f "$input_vcf" ]]; then
        return 1
    fi

    # 直接提取变异位点 (只保留有ALT等位基因的位点)
    ${BCFTOOLS} view -r "${chr}" -V indels "${input_vcf}" -Oz -o "${variant_vcf}" 2>/dev/null

    if [[ $? -eq 0 && -f "${variant_vcf}" ]]; then
        ${TABIX} -p -f vcf "${variant_vcf}" 2>/dev/null || true
        log "Extracted variants for ${sample_id} chr${chr}"
        return 0
    fi
    return 1
}

# =====================================
# Main: Process all samples
# =====================================

log "=========================================="
log "Starting VCF Processing for MSMC"
log "Task ID: ${TASK_ID}"
log "=========================================="

# Check required files
check_file "${PHASED_VCF}"

# Get list of populations
if [[ ! -d "${SAMPLE_LIST_DIR}" ]]; then
    error_exit "Sample list directory not found: ${SAMPLE_LIST_DIR}"
fi

# Create a list of all (sample, population) pairs
ALL_SAMPLES=()
while IFS=$'\t' read -r sample pop; do
    ALL_SAMPLES+=("${sample}:${pop}")
done < "${SAMPLE_LIST_DIR}/all_samples.txt"

log "Total samples to process: ${#ALL_SAMPLES[@]}"

# Process in batches
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

# =====================================
# Summary
# =====================================

log "=========================================="
log "VCF Processing Complete"
log "=========================================="

#n_variant=$(ls -1 "${SINGLE_VCF_DIR}"/*.variant.vcf.gz 2>/dev/null | wc -l)
#n_mask=$(ls -1 "${SINGLE_VCF_DIR}"/*.mask.bed.gz 2>/dev/null | wc -l)
n_variant=$(find "${SINGLE_VCF_DIR}" -name "*.variant.vcf.gz" | wc -l)
n_mask=$(find "${SINGLE_VCF_DIR}" -name "*.mask.bed.gz" | wc -l)
log "Variant VCF files: ${n_variant}"
log "Mask files: ${n_mask}"

mark_step "${WORK_DIR}/.step_02b_vcf_processing_done"

log "VCF processing step completed!"
