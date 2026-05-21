# MSMC Pipeline Scripts

A sanitized collection of scripts for running MSMC (Multiple Sequentially Markovian Coalescent)
analysis to infer effective population size (Ne) and population divergence times.

Designed for population genetics research using phased whole-genome sequencing data.

---

## Table of Contents

1. [Overview](#overview)
2. [Pipeline Flowchart](#pipeline-flowchart)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Usage](#usage)
7. [Input/Output Formats](#inputoutput-formats)
8. [Troubleshooting](#troubleshooting)
9. [Citation](#citation)

---

## Overview

**MSMC** (Multiple Sequentially Markovian Coalescent) analyzes the temporal pattern of
coalescent events in a population to estimate effective population size (Ne) changes
over time. This pipeline automates the complete workflow from VCF to MSMC results.

The pipeline includes:

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `01_select_samples.sh` | Randomly select samples per population |
| 2 | `02_extract_single_vcf.sh` | Extract per-sample VCF from phased VCF |
| 2b | `02b_process_vcf.sh` | Generate masks and variant VCFs for MSMC |
| 3 | `03_a_generate_combo.sh` | Define population group combinations |
| 3 | `03_generate_msmc_input.sh` | Generate MSMC input files (multihetsep) |
| 4 | `04_run_msmc_single.sh` | Run MSMC for sub-pop and cross-pop analysis |
| 4a | `04a_run_msmc_bootstrap.sh` | Bootstrap confidence intervals |

---

## Pipeline Flowchart

```
Phased VCF (multi-sample)
    │
    ▼
[Step 1] 01_select_samples.sh
    │        (select n samples per population)
    ▼
Sample lists (pop.txt, all_samples.txt)
    │
    ├──────────────────────┐
    ▼                      ▼
[Step 2] 02_extract_single_vcf.sh   [Step 2b] 02b_process_vcf.sh
    │        (per-sample VCFs)             │        (masks + variant VCFs)
    ▼                                    ▼
Per-sample, per-chromosome VCFs         masks + variant VCFs
    │                                    │
    └────────────────────────────────────┘
                                         ▼
                              [Step 3] 03_generate_msmc_input.sh
                                   │    (generate multihetsep files)
                                   ▼
                              MSMC input files (*.msmc)
                                   │
                                   ├──────────────────────┐
                                   ▼                      ▼
                         [Step 4]                [Step 4a]
                   04_run_msmc_single.sh   04a_run_msmc_bootstrap.sh
                         │                        │
                         ▼                        ▼
                    Ne estimates +         Bootstrap replicates
                    cross-pop divergence   (for confidence intervals)
```

---

## Prerequisites

### Software Requirements

| Software | Version | Purpose |
|----------|---------|---------|
| **MSMC / MSMC2** | 2.0+ | Main analysis tool |
| **bcftools** | 1.9+ | VCF manipulation |
| **tabix** | 0.2.6+ | Index compression |
| **Python** | 3.8+ | Scripting |
| **MSMC-tools** | latest | Helper scripts (generate_multihetsep.py, vcfAllSiteParser.py) |

### Data Requirements

1. **Phased multi-sample VCF**: bgzip compressed and tabix indexed
2. **Sample info file**: Tab-separated with columns: `SampleID\tPopulation\tRegion\tSubRegion`
3. **Genetic map** (optional): For recombination timing
4. **Mappability mask** (recommended): One `.bed.gz` file per chromosome
   - Download from: https://share.eva.mpg.de/index.php/s/ygfMbzwxneoTPZj

---

## Installation

### 1. Clone or download this repository

```bash
git clone https://github.com/yourusername/msmc-pipeline.git
cd msmc-pipeline
```

### 2. Install MSMC-tools

```bash
# Clone MSMC-tools repository
git clone https://github.com/stschiff/msmc-tools.git

# Or download release
wget https://github.com/stschiff/msmc-tools/releases/download/v1.0/msmc-tools.tar.gz
tar -xzf msmc-tools.tar.gz
```

### 3. Install MSMC binaries

```bash
# Download MSMC2 from the official site
wget https://github.com/stschiff/msmc/releases/download/v2.0.0/msmc2.linux
chmod +x msmc2.linux
sudo mv msmc2.linux /usr/local/bin/msmc2

# Verify installation
msmc2 --version
```

### 4. Install Python dependencies

```bash
pip install numpy pandas scipy
```

### 5. Make scripts executable

```bash
chmod +x *.sh
```

---

## Configuration

### Edit `config.sh`

**This is the only file you need to modify** to adapt the pipeline to your data.

```bash
# ============================================================================
# 1. PROJECT PATHS
# ============================================================================

PROJECT_ROOT="/path/to/your/project"
WORK_DIR="${PROJECT_ROOT}/msmc_pipeline"

# ============================================================================
# 2. INPUT DATA PATHS
# ============================================================================

# Your phased multi-sample VCF (bgzip + tabix)
PHASED_VCF="/path/to/your/phased.vcf.gz"

# Sample info: SampleID\tPopulation\tRegion\tSubRegion
SAMPLE_INFO="/path/to/your/sample_info.txt"

# ============================================================================
# 3. MASK FILES
# ============================================================================

# Mappability mask (one file per chromosome)
MAP_MASK="/path/to/mappability_mask/chr"

# MSMC-tools scripts
MSMC_TOOLS_DIR="/path/to/msmc-tools"
GENERATE_MULTIHETSEP="${MSMC_TOOLS_DIR}/generate_multihetsep.py"

# ============================================================================
# 4. OUTPUT DIRECTORIES
# ============================================================================

SAMPLE_LIST_DIR="${WORK_DIR}/sample_lists"
SINGLE_VCF_DIR="${WORK_DIR}/single_vcf"
MSMC_INPUT_DIR="${WORK_DIR}/msmc_input"
MSMC_OUTPUT_DIR="${WORK_DIR}/msmc_output"
LOG_DIR="${WORK_DIR}/logs"

# ============================================================================
# 5. POPULATION GROUPS
# ============================================================================

# Define populations present in your dataset
TARGET_POP="YourTargetPopulation"
REFERENCE_POP="YourReferencePopulation"
ALL_POPS="${TARGET_POP},${REFERENCE_POP}"

# ============================================================================
# 6. ANALYSIS PARAMETERS
# ============================================================================

# Samples per population to use
N_SAMPLES_PER_POP=2

# Chromosomes to process (1-22 autosomes)
CHROMOSOMES=$(seq 1 22)
```

### Define Population Combinations (in `03_a_generate_combo.sh`)

Edit the `COMBOS` array to define which populations to analyze together:

```bash
COMBOS=(
    "Group1:PopA PopB PopC"
    "Group2:PopX PopY PopZ"
)
```

### Define MSMC Combos (in `04_run_msmc_single.sh`)

Edit the `COMBOS` array to specify sample sizes per population:

```bash
COMBOS=(
    "Group1:PopA:2,PopB:2,PopC:2"   # PopA: 2 samples, PopB: 2 samples, PopC: 2 samples
    "Group2:PopX:2,PopY:2"          # PopX: 2 samples, PopY: 2 samples
)
```

---

## Usage

### Full Pipeline (SLURM)

```bash
# Load configuration
source config.sh

# Step 1: Select samples
sbatch 01_select_samples.sh

# Step 2: Extract single-sample VCFs (array job)
N=$(wc -l < sample_lists/all_samples.txt)
sbatch --array=0-$((N-1)) 02_extract_single_vcf.sh

# Step 2b: Process VCFs (array job, run after step 2 completes)
sbatch --array=0-$((N-1)) 02b_process_vcf.sh

# Step 3: Generate combos and MSMC inputs
bash 03_a_generate_combo.sh
sbatch 03_generate_msmc_input.sh

# Step 4: Run MSMC
sbatch 04_run_msmc_single.sh

# Step 4a: Bootstrap (optional, run after step 4)
sbatch 04a_run_msmc_bootstrap.sh
```

### Running Locally (without SLURM)

For testing on a single sample:

```bash
source config.sh

# Run step 1 (select samples)
bash 01_select_samples.sh

# Run step 2 for sample 0
TASK_ID=0 bash 02_extract_single_vcf.sh

# Run step 2b for sample 0
TASK_ID=0 bash 02b_process_vcf.sh
```

---

## Input/Output Formats

### Sample Info File

```
SampleID    Population    Region    SubRegion
Sample001   PopA          Asia      EastAsia
Sample002   PopA          Asia      EastAsia
Sample003   PopB          Asia      SouthAsia
```

### MSMC Input (multihetsep format)

Automatically generated by `03_generate_msmc_input.sh` using
`generate_multihetsep.py` from msmc-tools.

### Output Files

| File | Description |
|------|-------------|
| `sample_lists/{pop}.txt` | Sample IDs for each population |
| `sample_lists/all_samples.txt` | Master list (sample\tpop) |
| `single_vcf/{pop}_{sample}_chr{N}.vcf.gz` | Per-sample VCF |
| `single_vcf/{pop}_{sample}_chr{N}.mask.bed.gz` | Per-sample mask |
| `single_vcf/{pop}_{sample}_chr{N}.variant.vcf.gz` | Variant-only VCF |
| `msmc_input/{combo}_chr{N}.msmc` | MSMC input file |
| `msmc_output/{combo}_{pop}.final.txt` | Sub-population Ne |
| `msmc_output/{combo}_{pop1}_{pop2}.final.txt` | Cross-pop divergence |
| `msmc_output/{combo}_{pop1}_{pop2}.combined.txt` | Combined results |
| `bootstrap/{combo}_{N}/{combo}_{pop}.final.txt` | Bootstrap replicates |

---

## Troubleshooting

### Common Issues

**Error: "vcfAllSiteParser.py not found"**
- Ensure `MSMC_TOOLS_DIR` is set correctly in `config.sh`
- Download from: https://github.com/stschiff/msmc-tools

**Error: "No input files for MSMC"**
- Check that `SINGLE_VCF_DIR` contains variant VCFs and mask files
- Verify that step 2b (process_vcf) completed successfully

**Error: "msmc2 not found in PATH"**
- Ensure MSMC2 binary is installed and in your PATH
- Add to PATH: `export PATH="/path/to/msmc:$PATH"`

**Empty output files**
- Check SLURM logs in `logs/` directory
- Increase memory allocation in `#SBATCH --mem=`
- Verify input VCF is properly bgzip compressed and tabix indexed

### Monitoring Jobs

```bash
# Check job status
squeue -u $USER

# View logs
cat logs/msmc_pipeline.log

# Check for errors
grep -i error logs/*.log
```

---

## Citation

If you use this pipeline in your research, please cite the original MSMC papers:

> Schiffels S, Durbin R (2014)
> Inferring Human Population Size and Separation History from Genome-Wide Sequences
> *Nature Genetics*, 46(8): 919-925
> DOI: 10.1038/ng.3015

> Schiffels S, Wang K (2020)
> MSMC-tools: A Python toolbox for Multiple Sequentially Markovian Coalescent modeling
> *GitHub*: https://github.com/stschiff/msmc-tools

---

## License

This collection of scripts is provided as-is for research purposes.
The underlying MSMC tool is copyrighted by its authors.