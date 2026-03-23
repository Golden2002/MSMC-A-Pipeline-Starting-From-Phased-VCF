# MSMC Analysis Pipeline

A comprehensive pipeline for Multiple Sequential Markovian Coalescent (MSMC) analysis to estimate effective population size history and population divergence times.

## Overview

This pipeline processes phased VCF files to:
1. Select samples by population
2. Extract single-sample VCF files
3. Generate MSMC input files
4. Run MSMC for population size estimation
5. Visualize results

## Requirements

### Software
- **MSMC2**: `msmc2` executable
- **bcftools**: VCF file manipulation
- **Python 3**: For visualization scripts
- **MSMC-tools**: Official MSMC helper scripts
  - `generate_multihetsep.py`
  - `vcfAllSiteParser.py`
  - `combineCrossCoal.py`

### Data
- **Phased VCF**: Must be phased (GT field with | separator)
- **Mappability mask**: Per-chromosome bed.gz files (chr1.bed.gz, chr2.bed.gz, ...)
- **Sample info**: Tab-separated file with sample metadata

## Quick Start

### 1. Configuration

Edit `config.sh` to set your paths:

```bash
# Project paths
PROJECT_ROOT="/path/to/your/project"
WORK_DIR="${PROJECT_ROOT}/msmc_analysis"

# Input data
PHASED_VCF="${PROJECT_ROOT}/data/phased.vcf.gz"
SAMPLE_INFO="${PROJECT_ROOT}/data/sample_info.txt"
MAP_MASK="${PROJECT_ROOT}/mappability_mask/chr"
```

### 2. Define Experiment

Edit the `COMBOS` variable in `04_run_msmc_single.sh`:

```bash
COMBOS=(
    "BTH:Blang:2,Tibetan:2,Han:2"
    "MTH:Mosuo:2,Tibetan:2,Han:2"
    "JTH:Jino:2,Tibetan:2,Han:2"
    "QTH:Qiang:2,Tibetan:2,Han:2"
)
```

Format: `combo_name:pop1:samples1,pop2:samples2,...`

### 3. Run Pipeline

```bash
# Run all steps
bash run_pipeline.sh

# Run from a specific step
bash run_pipeline.sh 3  # Start from step 3

# Or run steps individually
bash 01_select_samples.sh
bash 02_extract_single_vcf.sh
bash 02b_process_vcf.sh
bash 03_generate_msmc_input.sh
bash 04_run_msmc_single.sh
python3 plot_msmc_ne.py
python3 plot_msmc_cross.py
```

## Pipeline Steps

| Step | Script | Description |
|------|--------|-------------|
| 1 | 01_select_samples.sh | Select samples by population |
| 2 | 02_extract_single_vcf.sh | Extract single-sample VCF |
| 2b | 02b_process_vcf.sh | Process VCF (variant + mask) |
| 3 | 03_generate_msmc_input.sh | Generate MSMC input files |
| 4 | 04_run_msmc_single.sh | Run MSMC analysis |
| 5 | plot_msmc_*.py | Visualization |

## Output

```
msmc_analysis/
├── sample_lists/          # Sample lists by population
├── single_vcf/            # Single-sample VCF files
├── msmc_input/           # MSMC input files
├── msmc_output/          # MSMC results
│   ├── {combo}_{pop}.final.txt           # Ne estimates
│   ├── {combo}_{pop1}_{pop2}.final.txt   # Cross-population
│   └── {combo}_{pop1}_{pop2}.combined.txt
├── visualization/         # Plots
│   ├── Ne_curves.png
│   └── Cross_coalescence.png
└── logs/                 # Log files
```

## Experiment Design Format

The pipeline supports flexible experiment designs:

```bash
# Format: "combo_name:pop1:n_samples,pop2:n_samples,..."

# Example 1: 3 populations, 2 samples each
"BTH:Blang:2,Tibetan:2,Han:2"

# Example 2: 3 populations, different sample sizes
"Custom:PopA:3,PopB:2,PopC:4"

# Example 3: 2 populations, 4 samples each
"PairAB:PopA:4,PopB:4"
```

Sample indices are calculated automatically:
- PopA: 0 to (n_samples*2 - 1)
- PopB: n_samples*2 to (2*n_samples*2 - 1)

## Visualization

### Ne Curves

```bash
python3 plot_msmc_ne.py
```

Generates:
- `Ne_curves.png` - Effective population size over time
- `Ne_ratio.png` - Ne ratio relative to reference

### Cross-Population

```bash
python3 plot_msmc_cross.py
```

Generates:
- `Cross_coalescence.png` - Relative cross-coalescence rate
- `Split_time.png` - Estimated split times

## Parameters

### MSMC Time Pattern

Default: `1*2+15*1+1*2`

Format: `time*states+time*states+...`
- `1*2` = 2 segments joined (fixed rate)
- `15*1` = 15 segments with individual rates
- `1*2` = 2 segments joined (fixed rate)

### Mutation Rate & Generation Time

Edit in visualization scripts:
```python
MU = 1.25e-8   # Mutation rate per base per generation
GEN = 30        # Generation time in years
```

## Troubleshooting

### No segregating sites
- Check VCF contains all sites (not just variants)
- Verify chromosome naming matches (chr1 vs 1)

### Empty MSMC input files
- Check mask files exist and are correctly formatted
- Verify VCF files are not empty

### Index errors
- Ensure sample count matches between VCF and configuration

## References

- Schiffels & Durbin (2014). Nature
- [MSMC GitHub](https://github.com/stschiff/msmc)
- [MSMC-tools](https://github.com/stschiff/msmc-tools)

## License

MIT License - See LICENSE file
