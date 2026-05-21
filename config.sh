#!/bin/bash
# =============================================================================
# config.sh - MSMC Pipeline Configuration
# =============================================================================
# Edit the paths and parameters below to match your setup.
#
# Usage: Source this file from other scripts:
#   source config.sh
# =============================================================================

# -----------------------------------------------------------------------------
# 1. PROJECT PATHS - MODIFY THESE
# -----------------------------------------------------------------------------

# Project root directory (where your data and results live)
PROJECT_ROOT="/path/to/your/project"

# Working directory for MSMC pipeline
WORK_DIR="${PROJECT_ROOT}/msmc_pipeline"

# -----------------------------------------------------------------------------
# 2. INPUT DATA PATHS - MODIFY THESE
# -----------------------------------------------------------------------------

# Phased multi-sample VCF file (must be bgzip compressed and tabix indexed)
PHASED_VCF="/path/to/your/phased.vcf.gz"

# Sample information file (format: SampleID\tPopulation\tRegion\tSubRegion)
SAMPLE_INFO="/path/to/your/sample_info.txt"

# -----------------------------------------------------------------------------
# 3. MASK FILES
# -----------------------------------------------------------------------------
# Mappability mask files (one per chromosome)
# Format: {PATH}/chr{N}.bed.gz
# Download from: https://share.eva.mpg.de/index.php/s/ygfMbzwxneoTPZj
MAP_MASK="/path/to/mappability_mask/chr"

# MSMC-tools scripts directory (download from https://github.com/stschiff/msmc-tools)
MSMC_TOOLS_DIR="/path/to/msmc-tools"
GENERATE_MULTIHETSEP="${MSMC_TOOLS_DIR}/generate_multihetsep.py"
BAM_CALLER="${MSMC_TOOLS_DIR}/bamCaller.py"

# -----------------------------------------------------------------------------
# 4. OUTPUT DIRECTORIES
# -----------------------------------------------------------------------------

SAMPLE_LIST_DIR="${WORK_DIR}/sample_lists"           # Selected sample lists
SINGLE_VCF_DIR="${WORK_DIR}/single_vcf"             # Per-sample VCF files
MSMC_INPUT_DIR="${WORK_DIR}/msmc_input"             # MSMC input files
MSMC_OUTPUT_DIR="${WORK_DIR}/msmc_output"           # MSMC results
VISUALIZATION_DIR="${WORK_DIR}/visualization"       # Plots
LOG_DIR="${WORK_DIR}/logs"                          # Log files

# Create all directories
mkdir -p "${SAMPLE_LIST_DIR}" "${SINGLE_VCF_DIR}" "${MSMC_INPUT_DIR}" \
         "${MSMC_OUTPUT_DIR}" "${VISUALIZATION_DIR}" "${LOG_DIR}"

# -----------------------------------------------------------------------------
# 5. POPULATION GROUPS - MODIFY THESE
# -----------------------------------------------------------------------------
# Define populations for MSMC analysis (comma-separated)
# Adjust these to match your sample populations

TARGET_POP="TargetPopulation"           # Primary population of interest
REFERENCE_POP="ReferencePopulation"      # Comparison population

# Example group definitions (replace with your populations):
# TIBETAN_POPS="Tibetan,Qiang,Sherpa"
# AUSTROASIATIC_POPS="Blang,Wa,Deang"

# All populations for joint analysis
ALL_POPS="${TARGET_POP},${REFERENCE_POP}"

# -----------------------------------------------------------------------------
# 6. ANALYSIS PARAMETERS
# -----------------------------------------------------------------------------

# Sample selection
N_SAMPLES_PER_POP=2            # Number of samples per population (default: 2)
RANDOM_SEED=42                 # Random seed for reproducibility

# MSMC parameters
MSMC_THREADS=8                 # Threads for MSMC
TIME_PATTERN="1*2+15*1+1*2"    # Time segment pattern (recommended: 4 haplotypes=8-12 segs)

# Chromosomes to process (autosomes 1-22)
CHROMOSOMES=$(seq 1 22)

# -----------------------------------------------------------------------------
# 7. SOFTWARE PATHS
# -----------------------------------------------------------------------------

MSMC2="msmc2"                  # Ensure msmc2 is in PATH
BCFTOOLS="bcftools"
TABIX="tabix"
PYTHON3="python3"
PYTHON2="python2"

# -----------------------------------------------------------------------------
# 8. PIPELINE CONTROL
# -----------------------------------------------------------------------------

RUN_SAMPLE_SELECTION=1
RUN_EXTRACT_VCF=1
RUN_GENERATE_INPUT=1
RUN_MSMC_BOOTSTRAP=1
RUN_MSMC_SINGLE=1
RUN_MSMC_CROSS=1

RESUME_MODE=1                  # Resume from interruption (1=yes, 0=no)

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_DIR}/msmc_pipeline.log"
}

error_exit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "${LOG_DIR}/msmc_pipeline.log"
    exit 1
}

check_file() {
    if [[ ! -f "$1" ]]; then
        error_exit "Required file not found: $1"
    fi
}

mark_step() {
    touch "$1"
}

# Export paths
export PROJECT_ROOT MSMC_ROOT WORK_DIR
export PHASED_VCF SAMPLE_INFO MAP_MASK
export MSMC_TOOLS_DIR GENERATE_MULTIHETSEP
export SAMPLE_LIST_DIR SINGLE_VCF_DIR MSMC_INPUT_DIR MSMC_OUTPUT_DIR
export LOG_DIR CHROMOSOMES
export BCFTOOLS TABIX PYTHON3