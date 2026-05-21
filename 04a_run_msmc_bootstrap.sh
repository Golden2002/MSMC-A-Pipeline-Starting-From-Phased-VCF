#!/bin/bash
# =============================================================================
# 04a_run_msmc_bootstrap.sh - Run MSMC Bootstrap Analysis
# =============================================================================
# Generates bootstrap samples from MSMC input and runs MSMC on each replicate
# to estimate confidence intervals for Ne estimates.
#
# Bootstrap workflow from: https://github.com/stschiff/msmc-tools
#
# Usage:
#   source config.sh
#   bash 04a_run_msmc_bootstrap.sh
#
# Output:
#   bootstrap/{combo}_1/, {combo}_2/, ... {combo}_{N}/ - Bootstrap replicates
# =============================================================================

#SBATCH --job-name=MSMC_Bootstrap
#SBATCH --output=%x_%A_%a.log
#SBATCH --error=%x_err_%A_%a.log
#SBATCH --ntasks=1
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4

set -euo pipefail

CONFIG_FILE="$(dirname "$0")/config.sh"
[[ ! -f "$CONFIG_FILE" ]] && echo "ERROR: config.sh not found" && exit 1
source "$CONFIG_FILE"

# =============================================================================
# BOOTSTRAP PARAMETERS - MODIFY THESE
# =============================================================================

# Number of bootstrap replicates
NR_BOOTSTRAPS=20

# Chunk size in bp (1Mb recommended)
CHUNK_SIZE=1000000

# Chunks per chromosome
CHUNKS_PER_CHROMOSOME=20

# Number of chromosomes for bootstrap
NR_CHROMOSOMES=22

# Random seed for reproducibility
BOOTSTRAP_SEED=42

# Threads per bootstrap run
THREADS=4

# Time pattern (should match main MSMC runs)
TIME_PATTERN="1*2+15*1+1*2"

# =============================================================================
# BOOTSTRAP OUTPUT DIRECTORY
# =============================================================================
BOOTSTRAP_DIR="${WORK_DIR}/bootstrap"
mkdir -p "${BOOTSTRAP_DIR}"

# =============================================================================
# LOGGING
# =============================================================================
LOG_FILE="${LOG_DIR}/msmc_bootstrap.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

error_exit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "${LOG_FILE}"
    exit 1
}

# =============================================================================
# CHECK REQUIRED TOOLS AND FILES
# =============================================================================
MULTIHETSEP_BOOTSTRAP="${MSMC_TOOLS_DIR}/multihetsep_bootstrap.py"

[[ ! -f "$MULTIHETSEP_BOOTSTRAP" ]] && error_exit "multihetsep_bootstrap.py not found: $MULTIHETSEP_BOOTSTRAP"
[[ ! -d "${MSMC_INPUT_DIR}" ]] && error_exit "MSMC input directory not found: ${MSMC_INPUT_DIR}"
command -v msmc2 &> /dev/null || error_exit "msmc2 not found in PATH"

# =============================================================================
# COMBO DEFINITIONS - EDIT THESE (same as 04_run_msmc_single.sh)
# =============================================================================
COMBOS=(
    "Group1:PopA:2,PopB:2,PopC:2"
    "Group2:PopX:2,PopY:2"
)

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
# MAIN: Process each combo
# =============================================================================
log "=========================================="
log "Starting MSMC Bootstrap Analysis"
log "=========================================="
log "Parameters:"
log "  Number of bootstraps: ${NR_BOOTSTRAPS}"
log "  Chunk size: ${CHUNK_SIZE} bp"
log "  Chunks per chromosome: ${CHUNKS_PER_CHROMOSOME}"
log "  Chromosomes: ${NR_CHROMOSOMES}"
log "  Bootstrap seed base: ${BOOTSTRAP_SEED}"
log "=========================================="

for combo_info in "${COMBOS[@]}"; do
    combo_name="${combo_info%%:*}"
    pops_info="${combo_info#*:}"

    log ""
    log "=========================================="
    log "Processing combo: ${combo_name}"
    log "=========================================="

    # Collect MSMC input files for this combo
    msmc_files=("${MSMC_INPUT_DIR}/${combo_name}"_chr*.msmc)

    if [[ ${#msmc_files[@]} -eq 0 ]]; then
        log "WARNING: No MSMC input files found for ${combo_name}, skipping..."
        continue
    fi

    log "Found ${#msmc_files[@]} MSMC input files"

    # =============================================================================
    # Step 1: Generate bootstrap samples
    # =============================================================================
    bootstrap_prefix="${BOOTSTRAP_DIR}/${combo_name}"

    log "Generating ${NR_BOOTSTRAPS} bootstrap samples..."
    log "Output prefix: ${bootstrap_prefix}"

    python3 "${MULTIHETSEP_BOOTSTRAP}" \
        --nr_bootstraps ${NR_BOOTSTRAPS} \
        --chunk_size ${CHUNK_SIZE} \
        --chunks_per_chromosome ${CHUNKS_PER_CHROMOSOME} \
        --nr_chromosomes ${NR_CHROMOSOMES} \
        --seed ${BOOTSTRAP_SEED} \
        "${bootstrap_prefix}" \
        "${msmc_files[@]}" \
        > "${BOOTSTRAP_DIR}/${combo_name}_bootstrap_generation.log" 2>&1

    if [[ $? -ne 0 ]]; then
        log "ERROR: Failed to generate bootstrap samples for ${combo_name}"
        continue
    fi

    log "Bootstrap sample generation complete"

    # =============================================================================
    # Step 2: Run MSMC on each bootstrap replicate
    # =============================================================================
    for ((bid=1; bid<=NR_BOOTSTRAPS; bid++)); do
        boot_dir="${bootstrap_prefix}_${bid}"

        [[ ! -d "$boot_dir" ]] && log "WARNING: Bootstrap directory not found: ${boot_dir}" && continue

        log ""
        log "--- Bootstrap ${bid}/${NR_BOOTSTRAPS} ---"

        # Process each population in this combo
        IFS=',' read -ra pops <<< "$pops_info"
        for pop_entry in "${pops[@]}"; do
            pop_name="${pop_entry%%:*}"
            n_samples="${pop_entry##*:}"

            # Build haplotype index string
            n_haplotypes=$((n_samples * 2))
            haplotypes=""
            for ((i=0; i<n_haplotypes; i++)); do
                [[ $i -gt 0 ]] && haplotypes+=","
                haplotypes+="$i"
            done

            output_prefix="${boot_dir}/${combo_name}_${pop_name}"

            [[ -f "${output_prefix}.final.txt" ]] && log "  ${pop_name} bootstrap ${bid} exists, skipping" && continue

            # Bootstrap input files (per-chromosome)
            boot_input_files=("${boot_dir}"/bootstrap_multihetsep.chr*.txt)

            [[ ${#boot_input_files[@]} -eq 0 ]] && log "  WARNING: No bootstrap input files in ${boot_dir}" && continue

            log "  Running msmc2 for ${pop_name} bootstrap ${bid}..."

            msmc2 -t ${THREADS} -p ${TIME_PATTERN} -I ${haplotypes} \
                -o "${output_prefix}" \
                "${boot_input_files[@]}" \
                > "${output_prefix}.log" 2>&1

            [[ $? -eq 0 ]] && log "  Completed: ${output_prefix}.final.txt" || log "  ERROR: Failed for ${pop_name} bootstrap ${bid}"
        done
    done

    log "Completed all bootstraps for ${combo_name}"
done

# =============================================================================
# Summary
# =============================================================================
log ""
log "=========================================="
log "Bootstrap Analysis Complete!"
log "=========================================="
log "Output directory: ${BOOTSTRAP_DIR}"
log ""
log "Directory structure:"
log "  ${BOOTSTRAP_DIR}/{combo}_1/  - Bootstrap replicate 1"
log "  ${BOOTSTRAP_DIR}/{combo}_2/  - Bootstrap replicate 2"
log "  ... (up to ${NR_BOOTSTRAPS} replicates)"
log ""
log "Next steps:"
log "  1. Check bootstrap results in ${BOOTSTRAP_DIR}"
log "  2. Run main MSMC: bash 04_run_msmc_single.sh"
log "  3. Visualize results with bootstrap confidence intervals"

mark_step "${WORK_DIR}/.step_03_5_bootstrap_done"