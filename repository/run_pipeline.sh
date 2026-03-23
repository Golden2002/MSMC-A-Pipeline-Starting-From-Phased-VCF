#!/bin/bash
# =====================================
# MSMC Pipeline - Master Runner
# =====================================
# Description: Run the complete MSMC analysis pipeline
# Usage: 
#   bash run_pipeline.sh        # Run all steps
#   bash run_pipeline.sh 1      # Run from step 1
#   bash run_pipeline.sh 3     # Run from step 3
# Author: Your Name
# Date: 2025-01-01

# =====================================
# Configuration
# =====================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

source "$CONFIG_FILE"

# =====================================
# Helper Functions
# =====================================

print_header() {
    echo ""
    echo "================================================"
    echo "$1"
    echo "================================================"
}

# =====================================
# Main Pipeline
# =====================================

START_STEP=${1:-1}

echo ""
echo "Starting MSMC Analysis Pipeline"
echo "Working directory: ${WORK_DIR}"
echo "Starting from step: ${START_STEP}"
echo ""

# Step 1: Sample Selection
if [[ $START_STEP -le 1 ]] && [[ $RUN_SAMPLE_SELECTION -eq 1 ]]; then
    print_header "Step 1: Sample Selection"
    cd "${SCRIPT_DIR}"
    bash 01_select_samples.sh
    if [[ $? -ne 0 ]]; then
        error_exit "Step 1 failed"
    fi
fi

# Step 2: Extract Single-Sample VCF
if [[ $START_STEP -le 2 ]] && [[ $RUN_EXTRACT_VCF -eq 1 ]]; then
    print_header "Step 2: Extract Single-Sample VCF"
    cd "${SCRIPT_DIR}"
    bash 02_extract_single_vcf.sh
    if [[ $? -ne 0 ]]; then
        error_exit "Step 2 failed"
    fi
fi

# Step 2b: Process VCF to MSMC format
if [[ $START_STEP -le 2 ]] && [[ $RUN_PROCESS_VCF -eq 1 ]]; then
    print_header "Step 2b: Process VCF"
    cd "${SCRIPT_DIR}"
    bash 02b_process_vcf.sh
    if [[ $? -ne 0 ]]; then
        error_exit "Step 2b failed"
    fi
fi

# Step 3: Generate MSMC Input Files
if [[ $START_STEP -le 3 ]] && [[ $RUN_GENERATE_INPUT -eq 1 ]]; then
    print_header "Step 3: Generate MSMC Input Files"
    cd "${SCRIPT_DIR}"
    bash 03_generate_msmc_input.sh
    if [[ $? -ne 0 ]]; then
        error_exit "Step 3 failed"
    fi
fi

# Step 4: Run MSMC Analysis
if [[ $START_STEP -le 4 ]] && [[ $RUN_MSMC_ANALYSIS -eq 1 ]]; then
    print_header "Step 4: Run MSMC Analysis"
    cd "${SCRIPT_DIR}"
    bash 04_run_msmc_single.sh
    if [[ $? -ne 0 ]]; then
        error_exit "Step 4 failed"
    fi
fi

# Step 5: Visualization
if [[ $START_STEP -le 5 ]] && [[ $RUN_VISUALIZATION -eq 1 ]]; then
    print_header "Step 5: Visualization"
    cd "${SCRIPT_DIR}"
    python3 plot_msmc_ne.py
    python3 plot_msmc_cross.py
    if [[ $? -ne 0 ]]; then
        error_exit "Step 5 failed"
    fi
fi

# =====================================
# Summary
# =====================================

print_header "Pipeline Complete!"

echo ""
echo "Output directories:"
echo "  - Sample lists: ${SAMPLE_LIST_DIR}"
echo "  - Single VCF: ${SINGLE_VCF_DIR}"
echo "  - MSMC input: ${MSMC_INPUT_DIR}"
echo "  - MSMC output: ${MSMC_OUTPUT_DIR}"
echo "  - Visualization: ${VISUALIZATION_DIR}"
echo ""
echo "Log file: ${LOG_FILE}"
echo ""

log "Pipeline completed successfully!"
