#!/bin/bash
# =====================================
# Step 3: Generate MSMC Input Files
# =====================================
# Description: Generate MSMC input files using generate_multihetsep.py
#              Supports all-sample joint and custom group combinations
# Author: Generated for MSMC Pipeline
# Date: 2025-03-11
# =====================================

#SBATCH --job-name=MSMC_GenInput
#SBATCH --output=${WORK_DIR}/logs/%x_%A_%a.log
#SBATCH --error=${WORK_DIR}/logs/%x_err_%A_%a.log
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
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config.sh not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# =====================================
# 定义所有样本顺序文件（用于固定顺序）
ALL_SAMPLES_ORDER_FILE="${WORK_DIR}/all_samples_order.txt"

# =====================================
# 函数：生成联合 multihetsep 文件（所有样本）
generate_joint_msmc_input() {
    local chr="$1"
    local output_file="${MSMC_INPUT_DIR}/ALL_chr${chr}.msmc"

    if [[ "${RESUME_MODE}" -eq 1  ]]; then # && -f "${output_file}"
        log "Joint MSMC input for chr${chr} already exists, skipping..."
        return 0
    fi

    cmd=("${PYTHON3}" "${GENERATE_MULTIHETSEP}")

    while IFS= read -r sample_id; do
        sample_mask="${SINGLE_VCF_DIR}/${sample_id}_chr${chr}.mask.bed.gz"
        [[ -f "$sample_mask" ]] && cmd+=(--mask "$sample_mask")
    done < "${ALL_SAMPLES_ORDER_FILE}"

    # 添加 mappability mask
    if [[ -f "${MAP_MASK}" ]]; then
        if [[ "${MAP_MASK}" == *"chr"* ]]; then
            cmd+=(--mask "${MAP_MASK}")
        else
            cmd+=(--mask "${MAP_MASK%.bed}.chr${chr}.bed.gz")
        fi
    fi

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

# =====================================
# 新增功能：根据组合生成样本列表文件
build_sample_list_for_combo() {
    local combo_name="$1"
    shift
    local pops=("$@")
    local outfile="${WORK_DIR}/sample_orders/${combo_name}.samples"
    mkdir -p "$(dirname "$outfile")"
    > "$outfile"

    for pop in "${pops[@]}"; do
        local pop_file="${SAMPLE_LIST_DIR}/${pop}.txt"
        if [[ ! -f "$pop_file" ]]; then
            error_exit "Missing sample list: $pop_file"
        fi
        while IFS= read -r sample; do
            echo "${pop}_${sample}" >> "$outfile"
        done < "$pop_file"
    done

    echo "$outfile"
}

# =====================================
# 新增功能：生成组合 multihetsep 文件
generate_combo_msmc_input() {
    local combo_name="$1"
    local chr="$2"
    local sample_file="$3"
    local output_file="${MSMC_INPUT_DIR}/${combo_name}_chr${chr}.msmc"

#    if [[ "${RESUME_MODE}" -eq 1 ]]; then # && -f "${output_file}"
#        log "MSMC input for combo ${combo_name}, chr${chr} exists, skipping..."
#        return 0
#    fi

    cmd=("${PYTHON3}" "${GENERATE_MULTIHETSEP}")

    while IFS= read -r sample; do
        mask_file="${SINGLE_VCF_DIR}/${sample}_chr${chr}.mask.bed.gz"
        [[ -f "$mask_file" ]] && cmd+=(--mask "$mask_file")
    done < "$sample_file"

    if [[ -f "${MAP_MASK}" ]]; then
        if [[ "${MAP_MASK}" == *"chr"* ]]; then
            cmd+=(--mask "${MAP_MASK}")
        else
            cmd+=(--mask "${MAP_MASK%.bed}.chr${chr}.bed.gz")
        fi
    fi

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

# =====================================
## 主流程：生成全样本 multihetsep
#log "=========================================="
#log "Starting Joint MSMC Input Generation"
#log "=========================================="
#
## 检查必要文件
#check_file "${GENERATE_MULTIHETSEP}"
#check_file "${PHASED_VCF}"
#
#if [[ ! -d "${SAMPLE_LIST_DIR}" ]]; then
#    error_exit "Sample list directory not found: ${SAMPLE_LIST_DIR}"
#fi
#
## 生成全样本顺序文件
#if [[ ! -f "${ALL_SAMPLES_ORDER_FILE}" ]]; then
#    log "Generating global sample order list: ${ALL_SAMPLES_ORDER_FILE}"
#    for pop_file in "${SAMPLE_LIST_DIR}"/*.txt; do
#        if [[ -f "$pop_file" && "$(basename $pop_file)" != "all_samples.txt" ]]; then
#            pop_name=$(basename "$pop_file" .txt)
#            while IFS= read -r sample; do
#                echo "${pop_name}_${sample}"
#            done < "$pop_file"
#        fi
#    done > "$ALL_SAMPLES_ORDER_FILE"
#    log "Generated order file with $(wc -l < $ALL_SAMPLES_ORDER_FILE) samples"
#else
#    log "Using existing sample order file: ${ALL_SAMPLES_ORDER_FILE}"
#fi
#
#n_samples=$(wc -l < "$ALL_SAMPLES_ORDER_FILE")
#if [[ $n_samples -lt 2 ]]; then
#    error_exit "Insufficient samples (found $n_samples) to run MSMC"
#fi
#log "Total samples to include in joint analysis: ${n_samples}"
#
## 生成全样本 multihetsep 文件
#for chr in ${CHROMOSOMES}; do
#    generate_joint_msmc_input "${chr}"
#done

# =====================================
# 生成自定义组合 multihetsep 文件
GROUP_COMBO_FILE="${WORK_DIR}/group_combinations.txt"
if [[ -f "${GROUP_COMBO_FILE}" ]]; then
    log "Starting custom group combination MSMC input generation"
    while read -r combo_name rest; do
        pops=($rest)
        combo_sample_file=$(build_sample_list_for_combo "$combo_name" "${pops[@]}")
        for chr in ${CHROMOSOMES}; do
            generate_combo_msmc_input "$combo_name" "$chr" "$combo_sample_file"
        done
    done < "$GROUP_COMBO_FILE"
    log "Custom group combination MSMC input generation complete"
else
    log "No group combination file found, skipping custom combos."
fi

# =====================================
# 汇总
log "=========================================="
log "Joint MSMC Input Generation Complete"
log "=========================================="
log "Output directory: ${MSMC_INPUT_DIR}"

n_files=$(ls -1 "${MSMC_INPUT_DIR}"/ALL_chr*.msmc 2>/dev/null | wc -l)
log "Joint MSMC input files created: ${n_files}"

log "Sample order file: ${ALL_SAMPLES_ORDER_FILE}"

mark_step "${WORK_DIR}/.step_03_input_done"
awk '{print NR-1, $0}' ${ALL_SAMPLES_ORDER_FILE}
log "MSMC input generation step completed successfully!"