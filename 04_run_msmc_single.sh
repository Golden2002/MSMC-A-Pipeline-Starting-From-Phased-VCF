#!/bin/bash
# =============================================================================
# 04_run_msmc_single.sh - Run MSMC for Single and Cross-Population Analysis
# =============================================================================
# Runs MSMC to estimate effective population size (Ne) for each sub-population
# and cross-population divergence times between sub-populations within combos.
#
# Usage:
#   source config.sh
#   bash 04_run_msmc_single.sh
#
# Output:
#   msmc_output/{combo}_{pop}.final.txt - Sub-population Ne
#   msmc_output/{combo}_{pop1}_{pop2}.final.txt - Cross-population
#
# Configuration:
#   Edit COMBOS array below to define population groups
#   Or use group_combinations.txt with CROSS_N_INDIV settings
# =============================================================================

#SBATCH --job-name=MSMC_Single
#SBATCH --output=%x_%A_%a.log
#SBATCH --error=%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --mem=64G
#SBATCH --cpus-per-task=1

set -euo pipefail

CONFIG_FILE="$(dirname "$0")/config.sh"
[[ ! -f "$CONFIG_FILE" ]] && echo "ERROR: config.sh not found" && exit 1
source "$CONFIG_FILE"

# =============================================================================
# MSMC PARAMETERS
# =============================================================================

# Time segment pattern (recommend: 4 haplotypes=8-12, 8 haplotypes=12-20)
# Format: time*states+time*states+...
TIME_PATTERN="1*2+15*1+1*2"

# Cross-population: number of individuals per population to use
CROSS_N_INDIV=1

# Run mode: "single" (sub-pop only), "cross" (between populations), "full" (both)
RUN_MODE="cross"

# Cross method: "I" (use -I flag) - only supported option
CROSS_METHOD="I"

# Threads
THREADS=4

# Skip ambiguous phasing
SKIP_AMBIGUOUS=true

# =============================================================================
# COMBO DEFINITIONS - EDIT THESE
# =============================================================================
# Format: "combo_name:pop1:n_samples,pop2:n_samples,pop3:n_samples,..."
#
# Example:
#   COMBOS=(
#       "GroupA:PopA:2,PopB:2,PopC:2"
#       "GroupB:PopX:2,PopY:2"
#   )
#
# The haplotype indices are automatically computed:
#   PopA (2 samples): indices 0-3
#   PopB (2 samples): indices 4-7
#   PopC (2 samples): indices 8-11

COMBOS=(
    "Group1:PopA:2,PopB:2,PopC:2"
    "Group2:PopX:2,PopY:2"
)

# Alternative: read from group_combinations.txt
GROUP_COMBO_FILE="${WORK_DIR}/group_combinations.txt"

if [[ ${#COMBOS[@]} -eq 0 && -f "$GROUP_COMBO_FILE" ]]; then
    COMBOS=()
    while read -r combo_name pops; do
        [[ -z "$combo_name" || "$combo_name" == \#* ]] && continue
        combo_str="${combo_name}:"
        first_pop=true
        for pop in $pops; do
            if [[ "$first_pop" == "true" ]]; then
                first_pop=false
            else
                combo_str+=","
            fi
            combo_str+="${pop}:2"
        done
        COMBOS+=("$combo_str")
    done < "$GROUP_COMBO_FILE"
fi

# =============================================================================
# LOGGING
# =============================================================================
LOG_FILE="${LOG_DIR}/msmc_step4.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# =============================================================================
# FUNCTION: Run sub-population MSMC (within combo)
# =============================================================================
run_subpop_ne() {
    local combo_name=$1
    local pop_name=$2
    local start_idx=$3
    local n_samples=$4

    local n_haplotypes=$((n_samples * 2))
    local end_idx=$((start_idx + n_haplotypes - 1))

    # Build haplotype index string: 0,1,2,3
    local haplotypes=""
    for ((i=start_idx; i<=end_idx; i++)); do
        [[ $i -gt $start_idx ]] && haplotypes+=","
        haplotypes+="$i"
    done

    local output_prefix="${MSMC_OUTPUT_DIR}/${combo_name}_${pop_name}"

    [[ -f "${output_prefix}.final.txt" ]] && log "${combo_name}_${pop_name} exists, skipping" && return 0

    # Collect input files (per chromosome)
    local -a input_files=()
    for chr in ${CHROMOSOMES}; do
        local msmc_file="${MSMC_INPUT_DIR}/${combo_name}_chr${chr}.msmc"
        [[ -f "$msmc_file" ]] && input_files+=("$msmc_file")
    done

    [[ ${#input_files[@]} -eq 0 ]] && log "ERROR: No input files for ${combo_name}" && return 1

    log "Running MSMC for ${combo_name} ${pop_name}: haplotypes ${haplotypes}"

    msmc2 -t ${THREADS} -p ${TIME_PATTERN} -I ${haplotypes} -o ${output_prefix} "${input_files[@]}" \
        > "${output_prefix}.log" 2>&1

    [[ $? -eq 0 ]] && log "Completed: ${output_prefix}.final.txt" || log "ERROR: Failed for ${combo_name}_${pop_name}"
}

# =============================================================================
# FUNCTION: Run cross-population MSMC (between two pops in same combo)
# =============================================================================
run_cross_population() {
    local combo_name=$1
    local pop1=$2
    local pop2=$3
    local start_idx1=$4
    local start_idx2=$5
    local n_samples1=$6
    local n_samples2=$7

    # Build cross-pair haplotype indices
    local cross_pairs=""
    local use_n1=$(( n_samples1 < CROSS_N_INDIV ? n_samples1 : CROSS_N_INDIV ))
    local use_n2=$(( n_samples2 < CROSS_N_INDIV ? n_samples2 : CROSS_N_INDIV ))

    for ((i=0; i<use_n1; i++)); do
        h1=$((start_idx1 + 2*i))
        h2=$((start_idx1 + 2*i + 1))
        for ((j=0; j<use_n2; j++)); do
            h3=$((start_idx2 + 2*j))
            h4=$((start_idx2 + 2*j + 1))
            for a in $h1 $h2; do
                for b in $h3 $h4; do
                    [[ -n "$cross_pairs" ]] && cross_pairs+=","
                    cross_pairs+="${a}-${b}"
                done
            done
        done
    done

    local output_prefix="${MSMC_OUTPUT_DIR}/${combo_name}_${pop1}_${pop2}"

    [[ -f "${output_prefix}.final.txt" ]] && log "${combo_name}_${pop1}_${pop2} exists, skipping" && return 0

    local -a input_files=()
    for chr in ${CHROMOSOMES}; do
        local msmc_file="${MSMC_INPUT_DIR}/${combo_name}_chr${chr}.msmc"
        [[ -f "$msmc_file" ]] && input_files+=("$msmc_file")
    done

    [[ ${#input_files[@]} -eq 0 ]] && log "ERROR: No input files for ${combo_name}" && return 1

    log "Running cross-MSMC: ${combo_name} ${pop1} vs ${pop2}"
    log "Cross pairs: ${cross_pairs}"

    local skip_flag=""
    [[ "$SKIP_AMBIGUOUS" == "true" ]] && skip_flag="-s"

    msmc2 -t ${THREADS} -p ${TIME_PATTERN} -I ${cross_pairs} ${skip_flag} -o ${output_prefix} "${input_files[@]}" \
        > "${output_prefix}.log" 2>&1

    [[ $? -eq 0 ]] && log "Completed: ${output_prefix}.final.txt" || log "ERROR: Failed for ${combo_name}_${pop1}_${pop2}"
}

# =============================================================================
# FUNCTION: Combine cross results using combineCrossCoal.py
# =============================================================================
combine_cross_results() {
    local combo_name=$1
    local pop1=$2
    local pop2=$3

    local cross_file="${MSMC_OUTPUT_DIR}/${combo_name}_${pop1}_${pop2}.final.txt"
    local pop1_file="${MSMC_OUTPUT_DIR}/${combo_name}_${pop1}.final.txt"
    local pop2_file="${MSMC_OUTPUT_DIR}/${combo_name}_${pop2}.final.txt"
    local combined_file="${MSMC_OUTPUT_DIR}/${combo_name}_${pop1}_${pop2}.combined.txt"

    [[ -f "$combined_file" ]] && log "Combined file exists: ${combined_file}" && return 0

    if [[ ! -f "$cross_file" || ! -f "$pop1_file" || ! -f "$pop2_file" ]]; then
        log "WARNING: Missing files for combining ${pop1} vs ${pop2}"
        return 1
    fi

    if [[ -f "${MSMC_TOOLS_DIR}/combineCrossCoal.py" ]]; then
        python3 "${MSMC_TOOLS_DIR}/combineCrossCoal.py" "$cross_file" "$pop1_file" "$pop2_file" > "$combined_file"
        log "Generated combined: ${combined_file}"
    else
        log "WARNING: combineCrossCoal.py not found"
    fi
}

# =============================================================================
# MAIN: Process each combo
# =============================================================================
log "=========================================="
log "Starting MSMC Analysis"
log "=========================================="

[[ ! -d "${MSMC_INPUT_DIR}" ]] && log "ERROR: MSMC input directory not found: ${MSMC_INPUT_DIR}" && exit 1
command -v msmc2 &> /dev/null || log "ERROR: msmc2 not found in PATH"

for combo_info in "${COMBOS[@]}"; do
    combo_name="${combo_info%%:*}"
    pops_info="${combo_info#*:}"

    IFS=',' read -ra pops <<< "$pops_info"

    log ""
    log "=========================================="
    log "Processing combo: ${combo_name}"
    log "Populations: ${pops_info}"
    log "=========================================="

    # Compute start indices for each population
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

    # 1. Run sub-population Ne analysis
    if [[ "$RUN_MODE" == "single" || "$RUN_MODE" == "full" ]]; then
        log ""
        log "--- Computing Ne for each sub-population ---"
        for pop_entry in "${pops[@]}"; do
            pop_name="${pop_entry%%:*}"
            n_samples="${pop_entry##*:}"
            start_idx=${pop_start_idx[$pop_name]}

            run_subpop_ne "$combo_name" "$pop_name" "$start_idx" "$n_samples"
        done
    fi

    # 2. Run cross-population analysis
    if [[ "$RUN_MODE" == "cross" || "$RUN_MODE" == "full" ]]; then
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

                [[ "$CROSS_METHOD" == "I" ]] && \
                    run_cross_population "$combo_name" "$pop1" "$pop2" "$start_idx1" "$start_idx2" "$n_samp1" "$n_samp2"
            done
        done
    fi

    # 3. Combine cross-population results
    log ""
    log "--- Combining cross-population results ---"
    for ((i=0; i<n_pops; i++)); do
        for ((j=i+1; j<n_pops; j++)); do
            pop1_entry="${pops[$i]}"
            pop2_entry="${pops[$j]}"
            pop1="${pop1_entry%%:*}"
            pop2="${pop2_entry##*:}"

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