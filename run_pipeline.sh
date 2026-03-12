#!/bin/bash
# =====================================
# MSMC Pipeline Runner
# =====================================
# Description: Master script to run the complete MSMC analysis pipeline
# Author: Generated for MSMC Pipeline
# Date: 2025-03-11
# =====================================

#SBATCH --job-name=MSMC_Pipeline
#SBATCH --output=/PATH/TO/logs/%x_%A_%a.log
#SBATCH --error=/PATH/TO/logs/%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --partition=batch
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --time=7-00:00:00

# =====================================
# Strict mode
set -euo pipefail

# =====================================
# Configuration
# =====================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Source configuration
source "${SCRIPT_DIR}/config.sh"

# =====================================
# Helper Functions
# =====================================

log_step() {
    echo ""
    echo "=============================================="
    echo "STEP: $1"
    echo "=============================================="
}

run_step() {
    local step_name="$1"
    local script="$2"
    local step_marker="${WORK_DIR}/.step_${step_name}"
    
    # Check if step should run
    if [[ "${RESUME_MODE}" -eq 1 && -f "${step_marker}" ]]; then
        log "Step ${step_name} already completed, skipping..."
        return 0
    fi
    
    log_step "${step_name}"
    
    # Run the script
    bash "${script}"
    
    if [[ $? -eq 0 ]]; then
        touch "${step_marker}"
        log "${step_name} completed successfully"
        return 0
    else
        error_exit "${step_name} failed"
    fi
}

# =====================================
# Main Pipeline
# =====================================

echo ""
echo "=============================================="
echo "MSMC Analysis Pipeline"
echo "=============================================="
echo "Project: ${PROJECT_ROOT}"
echo "Working directory: ${WORK_DIR}"
echo "Date: $(date)"
echo ""

# Initialize log
log "Starting MSMC pipeline..."

# =====================================
# Step 1: Sample Selection
# =====================================
if [[ "${RUN_SAMPLE_SELECTION}" -eq 1 ]]; then
    run_step "01_samples" "${SCRIPT_DIR}/01_select_samples.sh"
fi

# =====================================
# Step 2: Extract Single-Sample VCF
# =====================================
fi

# =====================================
# Step 2b: Process VCF to MSMC format
# =====================================
# 使用 vcfAllSiteParser 生成 per-sample mask 和 variant-only VCF
if [[ "${RUN_EXTRACT_VCF}" -eq 1 ]]; then
    run_step "02b_process" "${SCRIPT_DIR}/02b_process_vcf.sh"
fi

# =====================================
# Step 3: Generate MSMC Input
# =====================================
if [[ "${RUN_GENERATE_INPUT}" -eq 1 ]]; then
    run_step "03_input" "${SCRIPT_DIR}/03_generate_msmc_input.sh"
fi

# =====================================
# Step 4: Run MSMC (Single Population)
# =====================================
if [[ "${RUN_MSMC_SINGLE}" -eq 1 ]]; then
    run_step "04_msmc_single" "${SCRIPT_DIR}/04_run_msmc.sh"
fi

# =====================================
# Step 5: Run MSMC (Cross-Population)
# =====================================
if [[ "${RUN_MSMC_CROSS}" -eq 1 ]]; then
    run_step "05_msmc_cross" "${SCRIPT_DIR}/05_run_msmc_cross.sh"
fi

# =====================================
# Step 6: Visualization
# =====================================
if [[ "${RUN_VISUALIZATION}" -eq 1 ]]; then
    log_step "06_Visualization"
    
    # Ne curves
    python3 "${SCRIPT_DIR}/plot_msmc_ne.py" \
        --input-dir "${MSMC_OUTPUT_DIR}" \
        --output-dir "${VISUALIZATION_DIR}" \
        --populations "${ALL_POPS}"
    
    # Cross-coalescence
    python3 "${SCRIPT_DIR}/plot_msmc_cross.py" \
        --input-dir "${MSMC_OUTPUT_DIR}" \
        --output-dir "${VISUALIZATION_DIR}"
    
    touch "${WORK_DIR}/.step_06_visualization_done"
fi

# =====================================
# Summary
# =====================================

echo ""
echo "=============================================="
echo "Pipeline Complete!"
echo "=============================================="
echo "Date: $(date)"
echo ""

echo "Output directories:"
echo "  - Sample lists: ${SAMPLE_LIST_DIR}"
echo "  - Single VCFs: ${SINGLE_VCF_DIR}"
echo "  - MSMC input: ${MSMC_INPUT_DIR}"
echo "  - MSMC output: ${MSMC_OUTPUT_DIR}"
echo "  - Visualization: ${VISUALIZATION_DIR}"
echo "  - Logs: ${LOG_DIR}"
echo ""

echo "Next steps:"
echo "  1. Check results in ${MSMC_OUTPUT_DIR}"
echo "  2. Review plots in ${VISUALIZATION_DIR}"
echo "  3. Adjust parameters if needed and re-run"
echo ""

log "MSMC pipeline completed successfully!"
