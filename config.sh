#!/bin/bash
# =====================================
# MSMC Pipeline Configuration
# =====================================
# Author: Generated for Jino Population Genetics Study
# Date: 2025-03-11
# Description: Configuration file for MSMC analysis pipeline
# =====================================

# =====================================
# 1. Project Paths
# =====================================

# Project root (cluster path)
PROJECT_ROOT="/share/home/litianxing/100My_Jino"

# This directory (MSMC working directory)
MSMC_ROOT="${PROJECT_ROOT}/116.MSMC"
WORK_DIR="${MSMC_ROOT}/true_msmc"

# =====================================
# 2. Input Data Paths
# =====================================

# Phased multi-sample VCF file
PHASED_VCF="${PROJECT_ROOT}/107.IBD/data/NGS.phased.vcf.gz"

# Sample information file
SAMPLE_INFO="${PROJECT_ROOT}/101DataPanel/101.5Info/modified_PanAsian_info2.txt"

# =====================================
# MASK FILES - 重要!
# =====================================
# 
# Mappability mask 需要按染色体分开:
#   格式: {PATH}/chr{编号}.bed.gz
#   示例: mappability_mask/chr1.bed.gz, chr2.bed.gz...
#   
# 配置方式 (推荐):
#   MAP_MASK="${MSMC_ROOT}/mappability_mask/chr"
#   脚本会自动添加 ".bed.gz" 和染色体编号
#
# 下载地址: https://share.eva.mpg.de/index.php/s/ygfMbzwxneoTPZj
#
# =====================================
MAP_MASK="${MSMC_ROOT}/mappability_mask/chr"

# MSMC-tools scripts
MSMC_TOOLS_DIR="${MSMC_ROOT}/msmc-tools"
GENERATE_MULTIHETSEP="${MSMC_TOOLS_DIR}/generate_multihetsep.py"
BAM_CALLER="${MSMC_TOOLS_DIR}/bamCaller.py"

# =====================================
# 3. Output Directories
# =====================================

SAMPLE_LIST_DIR="${WORK_DIR}/sample_lists"
SINGLE_VCF_DIR="${WORK_DIR}/single_vcf"
MSMC_INPUT_DIR="${WORK_DIR}/msmc_input"
MSMC_OUTPUT_DIR="${WORK_DIR}/msmc_output"
VISUALIZATION_DIR="${WORK_DIR}/visualization"
LOG_DIR="${WORK_DIR}/logs"

# Create all directories
mkdir -p "${SAMPLE_LIST_DIR}" "${SINGLE_VCF_DIR}" "${MSMC_INPUT_DIR}" \
         "${MSMC_OUTPUT_DIR}" "${VISUALIZATION_DIR}" "${LOG_DIR}"

# =====================================
# 4. Population Groups for Analysis
# =====================================

# Define populations for MSMC analysis
# Format: Group_Name="pop1,pop2,pop3"

# Primary target population
TARGET_POP="Jino"

# Tibetan-related populations
TIBETAN_POPS="Tibetan,Qiang,Sherpa"

# Jino-related populations (language family)
JINO_RELATED_POPS="Hani,Lahu"

# Northern Yunnan minorities
NORTH_YUNNAN_POPS="Pumi,Mosuo,Naxi"

# Austroasiatic populations
AUSTROASIATIC_POPS="Blang,Wa,Deang"

# Tai-Kadai populations
TAI_KADAI_POPS="Dai,Zhuang,Dong,Buyei"

# Reference populations
REFERENCE_POPS="Han"

# All populations combined
ALL_POPS="${TARGET_POP},${TIBETAN_POPS},${JINO_RELATED_POPS},${NORTH_YUNNAN_POPS},${AUSTROASIATIC_POPS},${TAI_KADAI_POPS},${REFERENCE_POPS}"

# =====================================
# 5. Analysis Parameters
# =====================================

# Sample selection parameters
N_SAMPLES_PER_POP=2           # Number of samples to select per population (default: 2)
RANDOM_SEED=42                # Random seed for reproducibility

# MSMC parameters
MSMC_THREADS=8                # Number of threads for MSMC
MSMC_TIME_INTERVALS="0.1*15+0.2*10+0.5*5+1*5+2*5"  # Time segment pattern

# Chromosomes to process (autosomes)
CHROMOSOMES=$(seq 1 22)

# Cross-population analysis pairs
# Format: pop1:pop2,pop3:pop4,...
CROSS_PAIRS=(
    "Jino:Tibetan"
    "Jino:Han"
    "Jino:Dai"
    "Jino:Hani"
    "Jino:Lahu"
    "Jino:Pumi"
    "Jino:Mosuo"
    "Jino:Naxi"
    "Tibetan:Han"
    "Dai:Zhuang"
)

# =====================================
# 6. Software Configuration
# =====================================

# MSMC executable (ensure it's in PATH or provide full path)
MSMC2="msmc2"

# Required tools
BCFTOOLS="bcftools"
VCFTOOLS="vcftools"
BGZIP="bgzip"
TABIX="tabix"
PYTHON3="python3"

# =====================================
# 7. Pipeline Control
# =====================================

# Steps to run (1=yes, 0=no)
RUN_SAMPLE_SELECTION=1
RUN_EXTRACT_VCF=1
RUN_GENERATE_INPUT=1
RUN_MSMC_SINGLE=1
RUN_MSMC_CROSS=1
RUN_VISUALIZATION=1

# Resume from interruption (1=yes, 0=no)
RESUME_MODE=1

# =====================================
# 8. Logging
# =====================================

# Log file
LOG_FILE="${LOG_DIR}/msmc_pipeline.log"

# =====================================
# Helper Functions
# =====================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

error_exit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "${LOG_FILE}"
    exit 1
}

check_file() {
    if [[ ! -f "$1" ]]; then
        error_exit "Required file not found: $1"
    fi
}

check_dir() {
    if [[ ! -d "$1" ]]; then
        mkdir -p "$1"
    fi
}

# Check if step is already completed
check_step() {
    local step_marker="$1"
    if [[ "${RESUME_MODE}" -eq 1 && -f "${step_marker}" ]]; then
        log "Step $step_marker already completed, skipping..."
        return 0
    else
        return 1
    fi
}

# Mark step as completed
mark_step() {
    local step_marker="$1"
    touch "${step_marker}"
}

# =====================================
# Export all variables for use in subscripts
# =====================================

export PROJECT_ROOT MSMC_ROOT WORK_DIR
export PHASED_VCF SAMPLE_INFO
export MAP_MASK COV_MASK
export MSMC_TOOLS_DIR GENERATE_MULTIHETSEP BAM_CALLER
export SAMPLE_LIST_DIR SINGLE_VCF_DIR MSMC_INPUT_DIR MSMC_OUTPUT_DIR
export VISUALIZATION_DIR LOG_DIR
export N_SAMPLES_PER_POP RANDOM_SEED
export MSMC_THREADS MSMC_TIME_INTERVALS
export CHROMOSOMES
export MSMC2 BCFTOOLS VCFTOOLS BGZIP TABIX PYTHON3

log "Configuration loaded successfully"
