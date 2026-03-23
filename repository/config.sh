# =====================================
# MSMC Pipeline Configuration
# =====================================
# Author: Your Name
# Date: 2025-01-01
# Description: Configuration file for MSMC analysis pipeline
# =====================================

# =====================================
# 1. Project Paths - MODIFY THESE
# =====================================

# Project root directory
PROJECT_ROOT="/path/to/your/project"

# MSMC root directory
MSMC_ROOT="${PROJECT_ROOT}/116.MSMC"

# Working directory
WORK_DIR="${MSMC_ROOT}/msmc_analysis"

# =====================================
# 2. Input Data Paths - MODIFY THESE
# =====================================

# Phased multi-sample VCF file
PHASED_VCF="${PROJECT_ROOT}/path/to/phased.vcf.gz"

# Sample information file (format: SampleID\tPopulation\t...)
SAMPLE_INFO="${PROJECT_ROOT}/path/to/sample_info.txt"

# Mappability mask directory (chr1.bed.gz, chr2.bed.gz, ...)
# Format: {PATH}/chr{number}.bed.gz
MAP_MASK="${MSMC_ROOT}/mappability_mask/chr"

# MSMC-tools scripts directory
MSMC_TOOLS_DIR="${MSMC_ROOT}/msmc-tools"

# Path to generate_multihetsep.py
GENERATE_MULTIHETSEP="${MSMC_TOOLS_DIR}/generate_multihetsep.py"

# Path to vcfAllSiteParser.py
VCF_PARSER="${MSMC_TOOLS_DIR}/vcfAllSiteParser.py"

# =====================================
# 3. Output Directories
# =====================================

SAMPLE_LIST_DIR="${WORK_DIR}/sample_lists"
SINGLE_VCF_DIR="${WORK_DIR}/single_vcf"
MSMC_INPUT_DIR="${WORK_DIR}/msmc_input"
MSMC_OUTPUT_DIR="${WORK_DIR}/msmc_output"
VISUALIZATION_DIR="${WORK_DIR}/visualization"
LOG_DIR="${WORK_DIR}/logs"

# Create directories
mkdir -p "${SAMPLE_LIST_DIR}" "${SINGLE_VCF_DIR}" "${MSMC_INPUT_DIR}" \
         "${MSMC_OUTPUT_DIR}" "${VISUALIZATION_DIR}" "${LOG_DIR}"

# =====================================
# 4. Population Groups for Analysis
# =====================================

# Define your populations here
# Format: Group_Name="pop1,pop2,pop3"

TARGET_POP="YourTargetPop"

REFERENCE_POPS="Pop1,Pop2,Pop3"

# All populations combined
ALL_POPS="${TARGET_POP},${REFERENCE_POPS}"

# =====================================
# 5. Experiment Design for MSMC
# =====================================

# Define combinations for MSMC analysis
# Format: "combo_name:pop1:samples1,pop2:samples2,pop3:samples3,..."
# 
# Example:
#   "BTH:Blang:2,Tibetan:2,Han:2"
#   Means: Blang(2 samples), Tibetan(2 samples), Han(2 samples)
#   Sample indices: Blang(0-3), Tibetan(4-7), Han(8-11)

# Add your experiment designs here
GROUP_COMBO_FILE="${WORK_DIR}/group_combinations.txt"

# =====================================
# 6. Analysis Parameters
# =====================================

# Sample selection
N_SAMPLES_PER_POP=2           # Number of samples to select per population
RANDOM_SEED=42                # Random seed for reproducibility

# MSMC parameters
MSMC_THREADS=8                # Number of threads for MSMC
MSMC_TIME_INTERVALS="1*2+15*1+1*2"  # Time segment pattern

# Chromosomes to process (autosomes)
CHROMOSOMES=$(seq 1 22)

# =====================================
# 7. Software Configuration
# =====================================

MSMC2="msmc2"                  # MSMC2 executable
BCFTOOLS="bcftools"            # bcftools
BGZIP="bgzip"                  # bgzip
TABIX="tabix"                  # tabix
PYTHON3="python3"             # Python 3
PYTHON2="python2"              # Python 2

# =====================================
# 8. Pipeline Control
# =====================================

# Steps to run (1=yes, 0=no)
RUN_SAMPLE_SELECTION=1
RUN_EXTRACT_VCF=1
RUN_PROCESS_VCF=1
RUN_GENERATE_INPUT=1
RUN_MSMC_ANALYSIS=1
RUN_VISUALIZATION=1

# Resume from interruption
RESUME_MODE=1

# =====================================
# 9. Logging
# =====================================

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

check_step() {
    local step_marker="$1"
    if [[ "${RESUME_MODE}" -eq 1 && -f "${step_marker}" ]]; then
        log "Step $step_marker already completed, skipping..."
        return 0
    else
        return 1
    fi
}

mark_step() {
    local step_marker="$1"
    touch "${step_marker}"
}

# Export all variables
export PROJECT_ROOT MSMC_ROOT WORK_DIR
export PHASED_VCF SAMPLE_INFO MAP_MASK
export MSMC_TOOLS_DIR GENERATE_MULTIHETSEP VCF_PARSER
export SAMPLE_LIST_DIR SINGLE_VCF_DIR MSMC_INPUT_DIR MSMC_OUTPUT_DIR
export VISUALIZATION_DIR LOG_DIR
export N_SAMPLES_PER_POP RANDOM_SEED
export MSMC_THREADS MSMC_TIME_INTERVALS CHROMOSOMES
export MSMC2 BCFTOOLS BGZIP TABIX PYTHON3 PYTHON2
export RESUME_MODE

log "Configuration loaded successfully"
