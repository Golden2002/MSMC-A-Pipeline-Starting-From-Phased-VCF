#!/bin/bash
# =====================================
# Step 5: Run MSMC for Cross-Population Analysis
# =====================================
# Description: Run MSMC2 to estimate cross-population coalescence rates
# Author: Generated for MSMC Pipeline
# Date: 2025-03-11
# =====================================

#SBATCH --job-name=MSMC_Cross
#SBATCH --output=/PATH/TO/logs/%x_%A_%a.log
#SBATCH --error=/PATH/TO/logs/%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --partition=batch
#SBATCH --mem=16G
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --array=0-20

# =====================================
# Strict mode
set -euo pipefail

# =====================================
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# =====================================
# Get array task ID
    TASK_ID="${SLURM_ARRAY_TASK_ID}"
elif [[ -n "$1" ]]; then
    TASK_ID="$1"
else
    TASK_ID=0
fi

# =====================================
# Function: Generate cross-population MSMC input
# =====================================
generate_cross_input() {
    local pop1="$1"
    local pop2="$2"
    local chr="$3"
    
    # Output file
    local output_file="${MSMC_INPUT_DIR}/${pop1}_${pop2}_chr${chr}.msmc"
    
    # Check if already exists
    if [[ "${RESUME_MODE}" -eq 1 && -f "${output_file}" ]]; then
        log "Cross-population input for ${pop1}_${pop2} chr${chr} exists, skipping..."
        return 0
    fi
    
    # Get sample lists for both populations
    local list1="${SAMPLE_LIST_DIR}/${pop1}.txt"
    local list2="${SAMPLE_LIST_DIR}/${pop2}.txt"
    
    if [[ ! -f "$list1" || ! -f "$list2" ]]; then
        log "WARNING: Sample list not found for ${pop1} or ${pop2}"
        return 1
    fi
    
    # Collect VCF files for each population
    local vcf1=()
    while IFS= read -r sample; do
        local f="${SINGLE_VCF_DIR}/${pop1}_${sample}_chr${chr}.vcf.gz"
        if [[ -f "$f" ]]; then
            vcf1+=("$f")
        fi
    done < "$list1"
    
    local vcf2=()
    while IFS= read -r sample; do
        local f="${SINGLE_VCF_DIR}/${pop2}_${sample}_chr${chr}.vcf.gz"
        if [[ -f "$f" ]]; then
            vcf2+=("$f")
        fi
    done < "$list2"
    
    # Need at least one sample from each population
    if [[ ${#vcf1[@]} -eq 0 || ${#vcf2[@]} -eq 0 ]]; then
        log "WARNING: Missing samples for cross-pop ${pop1}_${pop2}"
        return 1
    fi
    
    # For cross-population analysis, we need to create a combined input
    # Using generate_multihetsep.py with multiple samples from both populations
    
    # First generate per-sample inputs
    local temp_inputs=()
    
    # Process pop1 samples
    for v in "${vcf1[@]}"; do
        local prefix="${MSMC_INPUT_DIR}/temp_$(basename $v .vcf.gz)"
        ${PYTHON3} ${GENERATE_MULTIHETSEP} -o "${prefix}" "$v" 2>/dev/null || true
        if [[ -f "${prefix}" ]]; then
            temp_inputs+=("${prefix}")
        fi
    done
    
    # Process pop2 samples
    for v in "${vcf2[@]}"; do
        local prefix="${MSMC_INPUT_DIR}/temp_$(basename $v .vcf.gz)"
        ${PYTHON3} ${GENERATE_MULTIHETSEP} -o "${prefix}" "$v" 2>/dev/null || true
        if [[ -f "${prefix}" ]]; then
            temp_inputs+=("${prefix}")
        fi
    done
    
    # Combine all inputs
    if [[ ${#temp_inputs[@]} -lt 2 ]]; then
        log "WARNING: Not enough valid inputs for ${pop1}_${pop2}"
        return 1
    fi
    
    # Concatenate all input files
    cat "${temp_inputs[@]}" > "${output_file}"
    
    # Clean up temp files
    rm -f "${temp_inputs[@]}"
    
    log "Created cross-pop input for ${pop1}_${pop2} chr${chr}"
    return 0
}

# =====================================
# Function: Run cross-population MSMC
# =====================================
run_msmc_cross() {
    local pop1="$1"
    local pop2="$2"
    local chr="$3"
    
    # Output file
    local output_prefix="${MSMC_OUTPUT_DIR}/cross_${pop1}_${pop2}_chr${chr}"
    local output_file="${output_prefix}.msmc2"
    
    # Check if already exists
    if [[ "${RESUME_MODE}" -eq 1 && -f "${output_file}" ]]; then
        log "Cross MSMC output for ${pop1}_${pop2} chr${chr} exists, skipping..."
        return 0
    fi
    
    # Input file
    local input_file="${MSMC_INPUT_DIR}/${pop1}_${pop2}_chr${chr}.msmc"
    
    if [[ ! -f "$input_file" ]]; then
        log "WARNING: Input file not found for cross ${pop1}_${pop2} chr${chr}"
        return 1
    fi
    
    # Run MSMC2 with cross-population flag
    # Key parameter:
    #   -P, --populationPattern PATTERN
    #        Format: "a,a,b,b" where a=population for first set, b=for second set
    #        For 2 samples from pop1 and 2 from pop2: "0,0,1,1"
    #   --skipAmbiguous      Skip ambiguous sites
    
    # Determine sample counts
    local list1="${SAMPLE_LIST_DIR}/${pop1}.txt"
    local list2="${SAMPLE_LIST_DIR}/${pop2}.txt"
    local n1=$(wc -l < "$list1")
    local n2=$(wc -l < "$list2")
    
    # Create population pattern: 0,0,...,0,1,1,...,1
    local pattern=$(printf '0,'%.0s $(seq 1 $n1))
    pattern="${pattern}$(printf '1,'%.0s $(seq 1 $n2))"
    # Remove trailing comma
    pattern="${pattern%,}"
    
    log "Running cross-population MSMC for ${pop1} x ${pop2} chr${chr}..."
    log "Population pattern: ${pattern}"
    
    ${MSMC2} \
        -t ${MSMC_THREADS} \
        -o "${output_prefix}" \
        --fixedRecombination \
        --skipAmbiguous \
        -P "${pattern}" \
        -p "${MSMC_TIME_INTERVALS}" \
        "${input_file}" 2>&1 | tee -a "${LOG_DIR}/msmc_cross_${pop1}_${pop2}_chr${chr}.log"
    
    if [[ $? -eq 0 && -f "${output_file}" ]]; then
        log "Cross MSMC completed for ${pop1} x ${pop2} chr${chr}"
        return 0
    else
        log "ERROR: Cross MSMC failed for ${pop1} x ${pop2} chr${chr}"
        return 1
    fi
}

# =====================================
# Main: Process all population pairs
# =====================================

log "=========================================="
log "Starting Cross-Population MSMC Analysis"
log "Task ID: ${TASK_ID}"
log "=========================================="

# Check required tools
check_command "${MSMC2}"
check_command "${PYTHON3}"

# Define cross-population pairs
# Format: "pop1:pop2"
PAIRS=(
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

# Get populations from config if not defined
if [[ ${#PAIRS[@]} -eq 0 ]]; then
    # Generate all pairs from CROSS_PAIRS in config
    IFS=',' read -ra POPS <<< "${ALL_POPS}"
    for ((i=0; i<${#POPS[@]}; i++)); do
        for ((j=i+1; j<${#POPS[@]}; j++)); do
            PAIRS+=("${POPS[$i]}:${POPS[$j]}")
        done
    done
fi

log "Population pairs to analyze: ${#PAIRS[@]}"

# Calculate which pair to process
PAIR_IDX=$((TASK_ID % ${#PAIRS[@]}))
PAIR="${PAIRS[$PAIR_IDX]}"
POP1="${PAIR%%:*}"
POP2="${PAIR##*:}"

log "Processing pair: ${POP1} x ${POP2} (index: ${PAIR_IDX})"

# Generate input for each chromosome
for chr in ${CHROMOSOMES}; do
    generate_cross_input "${POP1}" "${POP2}" "${chr}"
    run_msmc_cross "${POP1}" "${POP2}" "${chr}"
done

# =====================================
# Summary
# =====================================

log "=========================================="
log "Cross-Population MSMC Analysis Complete"
log "=========================================="
log "Output directory: ${MSMC_OUTPUT_DIR}"

# Count output files
n_files=$(ls -1 "${MSMC_OUTPUT_DIR}"/cross_*.msmc2 2>/dev/null | wc -l)
log "Cross-population MSMC output files: ${n_files}"

# Mark step as completed
mark_step "${WORK_DIR}/.step_05_msmc_cross_done"

log "Cross-population MSMC step completed successfully!"
