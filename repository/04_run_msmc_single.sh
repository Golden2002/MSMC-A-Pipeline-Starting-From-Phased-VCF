#!/bin/bash
# =====================================
# MSMC Pipeline - Step 4
# =====================================
# Description:
#   Run MSMC2 for:
#   1. Single population Ne estimation
#   2. Cross-population coalescence analysis
#
# Features:
#   - Flexible population combinations
#   - Automatic haplotype index handling
#   - Configurable cross-population sampling
#
# =====================================

# =====================================
# SLURM SETTINGS (modify as needed)
# =====================================
#SBATCH --job-name=msmc_step4
#SBATCH --output=logs/%x_%A.log
#SBATCH --error=logs/%x_%A.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

set -euo pipefail

# =====================================
# CONFIGURATION (EDIT THESE PATHS)
# =====================================
WORK_DIR="/path/to/workdir"
MSMC_INPUT_DIR="${WORK_DIR}/msmc_input"
MSMC_OUTPUT_DIR="${WORK_DIR}/msmc_output"
LOG_DIR="${WORK_DIR}/logs"

CHROMOSOMES="1 2 3"

TIME_PATTERN="1*2+15*1+1*2"
THREADS=4
SKIP_AMBIGUOUS=true

# 控制cross分析使用的个体数
CROSS_N_INDIV=1

# 运行模式：single / cross / full
RUN_MODE="cross"

# =====================================
# DEFINE COMBINATIONS
# 格式: "combo:pop1:n,pop2:n,..."
# =====================================
COMBOS=(
    "Demo:PopA:2,PopB:2"
)

# =====================================
# LOG FUNCTION
# =====================================
LOG_FILE="${LOG_DIR}/step4.log"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

# =====================================
# RUN SINGLE POPULATION MSMC
# =====================================
run_subpop_ne() {
    local combo=$1
    local pop=$2
    local start_idx=$3
    local n_samples=$4

    local n_haps=$((n_samples * 2))
    local end_idx=$((start_idx + n_haps - 1))

    local hap_str=""
    for ((i=start_idx; i<=end_idx; i++)); do
        [[ $i -gt $start_idx ]] && hap_str+=","
        hap_str+="$i"
    done

    local out="${MSMC_OUTPUT_DIR}/${combo}_${pop}"

    [[ -f "${out}.final.txt" ]] && return 0

    local inputs=()
    for chr in $CHROMOSOMES; do
        f="${MSMC_INPUT_DIR}/${combo}_chr${chr}.msmc"
        [[ -f "$f" ]] && inputs+=("$f")
    done

    msmc2 -t $THREADS -p $TIME_PATTERN -I $hap_str -o $out "${inputs[@]}" \
        > "${out}.log" 2>&1
}

# =====================================
# RUN CROSS POPULATION MSMC
# =====================================
run_cross_population() {
    local combo=$1
    local pop1=$2
    local pop2=$3
    local start1=$4
    local start2=$5
    local n1=$6
    local n2=$7

    local cross_pairs=""

    local use_n1=$(( n1 < CROSS_N_INDIV ? n1 : CROSS_N_INDIV ))
    local use_n2=$(( n2 < CROSS_N_INDIV ? n2 : CROSS_N_INDIV ))

    for ((i=0; i<use_n1; i++)); do
        h1=$((start1 + 2*i))
        h2=$((start1 + 2*i + 1))

        for ((j=0; j<use_n2; j++)); do
            h3=$((start2 + 2*j))
            h4=$((start2 + 2*j + 1))

            for a in $h1 $h2; do
                for b in $h3 $h4; do
                    [[ -n "$cross_pairs" ]] && cross_pairs+=","
                    cross_pairs+="${a}-${b}"
                done
            done
        done
    done

    local out="${MSMC_OUTPUT_DIR}/${combo}_${pop1}_${pop2}"

    [[ -f "${out}.final.txt" ]] && return 0

    local inputs=()
    for chr in $CHROMOSOMES; do
        f="${MSMC_INPUT_DIR}/${combo}_chr${chr}.msmc"
        [[ -f "$f" ]] && inputs+=("$f")
    done

    local flag=""
    [[ "$SKIP_AMBIGUOUS" == true ]] && flag="-s"

    msmc2 -t $THREADS -p $TIME_PATTERN -I $cross_pairs $flag -o $out "${inputs[@]}" \
        > "${out}.log" 2>&1
}

# =====================================
# MAIN
# =====================================
mkdir -p "$MSMC_OUTPUT_DIR"

for combo_info in "${COMBOS[@]}"; do
    combo="${combo_info%%:*}"
    pops_str="${combo_info#*:}"

    IFS=',' read -ra pops <<< "$pops_str"

    declare -A start_idx
    current=0

    for p in "${pops[@]}"; do
        name="${p%%:*}"
        n="${p##*:}"
        start_idx[$name]=$current
        current=$((current + n*2))
    done

    # SINGLE
    if [[ "$RUN_MODE" == "single" || "$RUN_MODE" == "full" ]]; then
        for p in "${pops[@]}"; do
            name="${p%%:*}"
            n="${p##*:}"
            run_subpop_ne "$combo" "$name" "${start_idx[$name]}" "$n"
        done
    fi

    # CROSS
    if [[ "$RUN_MODE" == "cross" || "$RUN_MODE" == "full" ]]; then
        n_pops=${#pops[@]}
        for ((i=0; i<n_pops; i++)); do
            for ((j=i+1; j<n_pops; j++)); do
                p1="${pops[$i]}"
                p2="${pops[$j]}"

                name1="${p1%%:*}"
                name2="${p2%%:*}"
                n1="${p1##*:}"
                n2="${p2##*:}"

                run_cross_population "$combo" "$name1" "$name2" \
                    "${start_idx[$name1]}" "${start_idx[$name2]}" "$n1" "$n2"
            done
        done
    fi
done

log "MSMC Step 4 finished"
