#!/bin/bash
# =====================================
# Step 4: Run MSMC for Single Populations
# =====================================
# Description: Run MSMC to estimate Ne for each sub-population within combos
#              For each combo, compute:
#              1. Ne for each sub-population internally
#              2. Cross-population analysis between sub-populations
# Author: Generated for MSMC Pipeline
# Date: 2025-03-11

#SBATCH --job-name=MSMC_Single
#SBATCH --output=${WORK_DIR}/logs/%x_%A_%a.log
#SBATCH --error=${WORK_DIR}/logs/%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --partition=batch
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1

set -euo pipefail

# =====================================
# Configuration
# =====================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
source "$CONFIG_FILE"

# =====================================
# Experiment Design - MODIFY THESE
# =====================================
# Format: "combo_name:pop1:n_samples,pop2:n_samples,pop3:n_samples,..."

# Example experiments:
COMBOS=(
    "Combo1:PopA:2,PopB:2,PopC:2"
    "Combo2:PopD:2,PopE:2,PopF:2"
)

# =====================================
# MSMC Parameters
# =====================================
# Time segment pattern: time*states+time*states+...
# Recommendation:
#   4 haplotypes: 8-12 segments
#   8 haplotypes: 12-20 segments
#   12 haplotypes: 15-25 segments
TIME_PATTERN="1*2+15*1+1*2"
THREADS=4
SKIP_AMBIGUOUS=true

# =====================================
# Logging Setup
# =====================================
LOG_DIR="${WORK_DIR}/logs"
LOG_FILE="${LOG_DIR}/msmc_step4.log"
mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# =====================================
# Helper Functions
# =====================================

# Run single-population MSMC (compute Ne for one sub-population)
run_subpop_ne() {
    local combo_name=$1
    local pop_name=$2
    local start_idx=$3
    local n_samples=$4
    
    local n_haplotypes=$((n_samples * 2))
    local end_idx=$((start_idx + n_haplotypes - 1))
    
    # Build haplotype indices
    local haplotypes=""
    for ((i=start_idx; i<=end_idx; i++)); do
        if [[ $i -gt $start_idx ]]; then
            haplotypes+=","
        fi
        haplotypes+="$i"
    done
    
    local output_prefix="${MSMC_OUTPUT_DIR}/${combo_name}_${pop_name}"
    
    # Skip if already exists
    if [[ -f "${output_prefix}.final.txt" ]]; then
        log "${combo_name}_${pop_name} already exists, skipping..."
        return 0
    fi
    
    # Build input file list using array (safe for spaces)
    local -a input_files=()
    for chr in ${CHROMOSOMES}; do
        local msmc_file="${MSMC_INPUT_DIR}/${combo_name}_chr${chr}.msmc"
        if [[ -f "$msmc_file" ]]; then
            input_files+=("$msmc_file")
        fi
    done
    
    if [[ ${#input_files[@]} -eq 0 ]]; then
        log "ERROR: No input files for ${combo_name}"
        return 1
    fi
    
    # Check completeness
    local expected=$(echo ${CHROMOSOMES} | wc -w)
    local actual=${#input_files[@]}
    if [[ $actual -lt $expected ]]; then
        log "WARNING: Missing MSMC input files ($actual/$expected)"
    fi
    
    log "Running MSMC for ${combo_name} ${pop_name}: haplotypes ${haplotypes}"
    
    # Use standardized parameter order
    msmc2 -t ${THREADS} -p ${TIME_PATTERN} -I ${haplotypes} -o ${output_prefix} "${input_files[@]}" \
        > "${output_prefix}.log" 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "Completed: ${output_prefix}.final.txt"
    else
        log "ERROR: Failed for ${combo_name}_${pop_name}"
        return 1
    fi
}

# Run cross-population MSMC (compute divergence between two sub-populations)
run_cross_population() {
    local combo_name=$1
    local pop1=$2
    local pop2=$3
    local start_idx1=$4
    local start_idx2=$5
    local n_samples1=$6
    local n_samples2=$7
    
    # Build cross-population haplotype index pairs
    # CRITICAL: sample index → haplotype index mapping
    # sample i → haplotypes 2*i and 2*i+1
    local cross_pairs=""
    
    for ((i=0; i<n_samples1; i++)); do
        # Get haplotype indices for sample i in population 1
        local h1=$((start_idx1 + 2*i))
        local h2=$((start_idx1 + 2*i + 1))
        
        for ((j=0; j<n_samples2; j++)); do
            # Get haplotype indices for sample j in population 2
            local h3=$((start_idx2 + 2*j))
            local h4=$((start_idx2 + 2*j + 1))
            
            # All pairs between haplotypes from pop1 and pop2
            for a in $h1 $h2; do
                for b in $h3 $h4; do
                    if [[ -n "$cross_pairs" ]]; then
                        cross_pairs+=","
                    fi
                    cross_pairs+="${a}-${b}"
                done
            done
        done
    done
    
    local output_prefix="${MSMC_OUTPUT_DIR}/${combo_name}_${pop1}_${pop2}"
    
    # Skip if already exists
    if [[ -f "${output_prefix}.final.txt" ]]; then
        log "${combo_name}_${pop1}_${pop2} already exists, skipping..."
        return 0
    fi
    
    # Build input file list using array (safe for spaces)
    local -a input_files=()
    for chr in ${CHROMOSOMES}; do
        local msmc_file="${MSMC_INPUT_DIR}/${combo_name}_chr${chr}.msmc"
        if [[ -f "$msmc_file" ]]; then
            input_files+=("$msmc_file")
        fi
    done
    
    if [[ ${#input_files[@]} -eq 0 ]]; then
        log "ERROR: No input files for ${combo_name}"
        return 1
    fi
    
    log "Running cross-MSMC: ${combo_name} ${pop1} vs ${pop2}"
    log "Cross pairs: ${cross_pairs}"
    
    # -s to skip ambiguous phasing
    local skip_flag=""
    if [[ "$SKIP_AMBIGUOUS" == "true" ]]; then
        skip_flag="-s"
    fi
    
    # Use standardized parameter order
    msmc2 -t ${THREADS} -p ${TIME_PATTERN} -I ${cross_pairs} ${skip_flag} -o ${output_prefix} "${input_files[@]}" \
        > "${output_prefix}.log" 2>&1
    
    if [[ $? -eq 0 ]]; then
        log "Completed: ${output_prefix}.final.txt"
    else
        log "ERROR: Failed for ${combo_name}_${pop1}_${pop2}"
        return 1
    fi
}

# Combine cross results for visualization
combine_cross_results() {
    local combo_name=$1
    local pop1=$2
    local pop2=$3
    
    local cross_file="${MSMC_OUTPUT_DIR}/${combo_name}_${pop1}_${pop2}.final.txt"
    local pop1_file="${MSMC_OUTPUT_DIR}/${combo_name}_${pop1}.final.txt"
    local pop2_file="${MSMC_OUTPUT_DIR}/${combo_name}_${pop2}.final.txt"
    local combined_file="${MSMC_OUTPUT_DIR}/${combo_name}_${pop1}_${pop2}.combined.txt"
    
    if [[ ! -f "$cross_file" || ! -f "$pop1_file" || ! -f "$pop2_file" ]]; then
        log "WARNING: Missing files for combining ${pop1} vs ${pop2}"
        return 1
    fi
    
    if [[ -f "$combined_file" ]]; then
        log "Combined file already exists: ${combined_file}"
        return 0
    fi
    
    # Use combineCrossCoal.py
    if command -v combineCrossCoal.py &> /dev/null; then
        combineCrossCoal.py "$cross_file" "$pop1_file" "$pop2_file" > "$combined_file"
        log "Generated combined: ${combined_file}"
    else
        log "WARNING: combineCrossCoal.py not found, skipping combine"
        return 1
    fi
}

# =====================================
# Main
# =====================================
log "=========================================="
log "Starting MSMC Analysis for Each Sub-population"
log "=========================================="

# Check directories and tools
if [[ ! -d "${MSMC_INPUT_DIR}" ]]; then
    log "ERROR: MSMC input directory not found: ${MSMC_INPUT_DIR}"
    exit 1
fi

if ! command -v msmc2 &> /dev/null; then
    log "ERROR: msmc2 not found in PATH"
    exit 1
fi

# Process each combo
for combo_info in "${COMBOS[@]}"; do
    combo_name="${combo_info%%:*}"
    pops_info="${combo_info#*:}"
    
    # Parse populations and sample counts
    IFS=',' read -ra pops <<< "$pops_info"
    
    log ""
    log "=========================================="
    log "Processing combo: ${combo_name}"
    log "Populations: ${pops_info}"
    log "=========================================="
    
    # Calculate start index for each population
    declare -A pop_start_idx
    declare -A pop_n_samples
    
    current_idx=0
    for pop_entry in "${pops[@]}"; do
        pop_name="${pop_entry%%:*}"
        n_samples="${pop_entry##*:}"
        n_haplotypes=$((n_samples * 2))
        
        pop_start_idx[$pop_name]=$current_idx
        pop_n_samples[$pop_name]=$n_samples
        
        log "  ${pop_name}: samples=${n_samples}, haplotypes=${n_haplotypes}, start_idx=${current_idx}"
        
        current_idx=$((current_idx + n_haplotypes))
    done
    
    # 1. Compute Ne for each sub-population
    log ""
    log "--- Computing Ne for each sub-population ---"
    for pop_entry in "${pops[@]}"; do
        pop_name="${pop_entry%%:*}"
        n_samples="${pop_entry##*:}"
        start_idx=${pop_start_idx[$pop_name]}
        
        run_subpop_ne "$combo_name" "$pop_name" "$start_idx" "$n_samples"
    done
    
    # 2. Compute cross-population divergence
    log ""
    log "--- Computing cross-population divergence ---"
    n_pops=${#pops[@]}
    for ((i=0; i<n_pops; i++)); do
        for ((j=i+1; j<n_pops; j++)); do
            pop1_entry="${pops[$i]}"
            pop2_entry="${pops[$j]}"
            
            pop1="${pop1_entry%%:*}"
            pop2="${pop2_entry%%:*}"
            n_samp1="${pop1_entry##*:}"
            n_samp2="${pop2_entry##*:}"
            
            start_idx1=${pop_start_idx[$pop1]}
            start_idx2=${pop_start_idx[$pop2]}
            
            run_cross_population "$combo_name" "$pop1" "$pop2" "$start_idx1" "$start_idx2" "$n_samp1" "$n_samp2"
        done
    done
    
    # 3. Combine cross results for visualization
    log ""
    log "--- Combining cross-population results ---"
    for ((i=0; i<n_pops; i++)); do
        for ((j=i+1; j<n_pops; j++)); do
            pop1_entry="${pops[$i]}"
            pop2_entry="${pops[$j]}"
            
            pop1="${pop1_entry%%:*}"
            pop2="${pop2_entry%%:*}"
            
            combine_cross_results "$combo_name" "$pop1" "$pop2"
        done
    done
    
    log "Completed combo: ${combo_name}"
done

log ""
log "=========================================="
log "All MSMC analyses complete!"
log "=========================================="

mark_step "${WORK_DIR}/.step_04_msmc_single_done"
