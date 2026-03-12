#!/usr/bin/env python3
"""
=====================================
MSMC Visualization - Cross-Coalescence
=====================================
Description: Plot pairwise cross-population coalescence rates from MSMC2 output
Author: Generated for MSMC Pipeline
Date: 2025-03-11
=====================================

Usage:
    python plot_msmc_cross.py [--input-dir DIR] [--output-dir DIR] [--pairs POP1:POP2,POP3:POP4]
    
Output:
    - Cross_coalescence.png: Multi-population pairwise coalescence rates
    - Cross_coalescence.pdf: Vector format for publication
"""

import os
import sys
import argparse
import glob
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from pathlib import Path

# =====================================
# Configuration
# =====================================

# Default parameters
GENERATION_TIME = 25  # Years per generation
MUTATION_RATE = 1.2e-8
REC_RATE = 1e-8

# Plot styling
DEFAULT_FIGSIZE = (12, 8)
DEFAULT_DPI = 300
LINE_STYLES = ['-', '--', '-.', ':']
MARKERS = ['o', 's', '^', 'D', 'v', '<', '>', 'p', 'h', '*']


def parse_msmc_cross_output(filename):
    """
    Parse MSMC2 cross-population output file.
    
    For cross-population analysis, MSMC2 outputs:
    - Column 1: time_index
    - Column 2: left_time_boundary
    - Column 3: right_time_boundary  
    - Column 4: lambda_00 (within pop1)
    - Column 5: lambda_01 (cross-population)
    - Column 6: lambda_10 (cross-population)
    - Column 7: lambda_11 (within pop2)
    - Column 8: time_index
    - Column 9: effective_pop_size
    
    The cross-population coalescence rate is lambda_01 or lambda_10
    
    Parameters:
        filename: Path to MSMC2 cross-population output
        
    Returns:
        times: Array of time points
        cross_rate: Cross-population coalescence rate
        within_rate1: Within population 1 rate
        within_rate2: Within population 2 rate
    """
    times = []
    cross_rate = []
    within_rate1 = []
    within_rate2 = []
    
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('#'):
                continue
            if not line:
                continue
            
            parts = line.split('\t')
            if len(parts) < 7:
                continue
            
            try:
                left_time = float(parts[1])
                right_time = float(parts[2])
                lambda_00 = float(parts[3])
                lambda_01 = float(parts[4])
                lambda_11 = float(parts[7]) if len(parts) > 7 else float(parts[3])
                
                # Use geometric mean for time
                avg_time = np.sqrt(left_time * right_time)
                
                # Convert to years (approximate)
                time_years = avg_time * GENERATION_TIME * 1e6  # In million years
                
                times.append(time_years)
                cross_rate.append(lambda_01)
                within_rate1.append(lambda_00)
                within_rate2.append(lambda_11)
            except (ValueError, IndexError):
                continue
    
    return np.array(times), np.array(cross_rate), np.array(within_rate1), np.array(within_rate2)


def load_cross_population_data(input_dir, pairs=None):
    """
    Load MSMC cross-population data.
    
    Parameters:
        input_dir: Directory containing cross-population MSMC output
        pairs: List of population pairs (e.g., ['Jino:Han', 'Jino:Tibetan'])
        
    Returns:
        Dictionary: {(pop1, pop2): (times, cross_rate, within1, within2)}
    """
    data = {}
    
    # Find all cross-population output files
    if pairs is None:
        files = glob.glob(os.path.join(input_dir, 'cross_*.msmc2'))
        pair_names = set()
        for f in files:
            basename = os.path.basename(f)
            # Extract pop1_pop2 from cross_pop1_pop2_chr*.msmc2
            parts = basename.split('_')
            if len(parts) >= 3:
                pop1 = parts[1]
                pop2 = parts[2].split('.')[0].split('chr')[0]
                pair_names.add((pop1, pop2))
        pairs = sorted(list(pair_names))
    
    for pop1, pop2 in pairs:
        # Look for cross-population output
        cross_files = glob.glob(os.path.join(input_dir, f'cross_{pop1}_{pop2}_chr*.msmc2'))
        
        if not cross_files:
            # Try reverse order
            cross_files = glob.glob(os.path.join(input_dir, f'cross_{pop2}_{pop1}_chr*.msmc2'))
        
        if cross_files:
            # Use first chromosome as representative
            times, cross, within1, within2 = parse_msmc_cross_output(cross_files[0])
            if len(times) > 0:
                data[(pop1, pop2)] = (times, cross, within1, within2)
                print(f"Loaded {pop1} x {pop2}: {len(times)} time points")
    
    return data


def plot_cross_coalescence(data, output_file, title='Cross-Population Coalescence Rates'):
    """
    Plot cross-population coalescence rates over time.
    
    Parameters:
        data: Dictionary of {(pop1, pop2): (times, cross_rate, ...)}
        output_file: Output file path
        title: Plot title
    """
    fig, ax = plt.subplots(figsize=DEFAULT_FIGSIZE)
    
    # Sort pairs for consistent ordering
    sorted_pairs = sorted(data.keys(), key=lambda x: (x[0], x[1]))
    
    for idx, (pop1, pop2) in enumerate(sorted_pairs):
        times, cross_rate, within1, within2 = data[(pop1, pop2)]
        
        label = f'{pop1} × {pop2}'
        
        # Use cycle for line styles
        linestyle = LINE_STYLES[idx % len(LINE_STYLES)]
        
        ax.plot(times, cross_rate, label=label, linewidth=2, 
                linestyle=linestyle, alpha=0.8)
    
    # Formatting
    ax.set_xlabel('Time (million years ago)', fontsize=12)
    ax.set_ylabel('Cross-Population Coalescence Rate', fontsize=12)
    ax.set_title(title, fontsize=14, fontweight='bold')
    
    # Log scale
    ax.set_yscale('log')
    
    # Legend
    ax.legend(loc='best', fontsize=9, framealpha=0.9, ncol=2)
    
    # Grid
    ax.grid(True, alpha=0.3, linestyle='--')
    ax.tick_params(axis='both', labelsize=10)
    
    plt.tight_layout()
    
    # Save
    png_file = output_file.replace('.png', '.png')
    plt.savefig(png_file, dpi=DEFAULT_DPI, bbox_inches='tight')
    print(f"Saved: {png_file}")
    
    pdf_file = output_file.replace('.png', '.pdf')
    plt.savefig(pdf_file, format='pdf', bbox_inches='tight')
    print(f"Saved: {pdf_file}")
    
    plt.close()


def plot_relative_cross_rate(data, output_file):
    """
    Plot cross-population rate relative to within-population rates.
    
    This shows when two populations coalesced relative to within-population coalescence.
    
    Parameters:
        data: Dictionary of cross-population data
        output_file: Output file path
    """
    fig, ax = plt.subplots(figsize=DEFAULT_FIGSIZE)
    
    sorted_pairs = sorted(data.keys(), key=lambda x: (x[0], x[1]))
    
    for idx, (pop1, pop2) in enumerate(sorted_pairs):
        times, cross, within1, within2 = data[(pop1, pop2)]
        
        # Calculate relative rate: cross / sqrt(within1 * within2)
        # This normalizes by the geometric mean of within-population rates
        relative_rate = cross / np.sqrt(within1 * within2)
        
        label = f'{pop1} × {pop2}'
        linestyle = LINE_STYLES[idx % len(LINE_STYLES)]
        
        ax.plot(times, relative_rate, label=label, linewidth=2,
                linestyle=linestyle, alpha=0.8)
    
    # Add reference line at 1 (expected under constant population)
    ax.axhline(y=1, color='black', linestyle='--', linewidth=1, alpha=0.5, 
               label='Expected (no divergence)')
    
    ax.set_xlabel('Time (million years ago)', fontsize=12)
    ax.set_ylabel('Relative Cross-Coalescence Rate', fontsize=12)
    ax.set_title('Relative Cross-Population Coalescence Rate\n(Normalized by Within-Population Rates)',
                 fontsize=14, fontweight='bold')
    
    ax.set_yscale('log')
    ax.legend(loc='best', fontsize=9, framealpha=0.9, ncol=2)
    ax.grid(True, alpha=0.3, linestyle='--')
    ax.tick_params(axis='both', labelsize=10)
    
    plt.tight_layout()
    
    png_file = output_file.replace('.png', '_relative.png')
    plt.savefig(png_file, dpi=DEFAULT_DPI, bbox_inches='tight')
    print(f"Saved: {png_file}")
    
    plt.close()


def plot_split_time_heatmap(data, output_file):
    """
    Create a heatmap showing estimated split times between populations.
    
    This uses the time when relative cross-coalescence rate drops below 0.5
    
    Parameters:
        data: Dictionary of cross-population data
        output_file: Output file path
    """
    # Calculate split times (when relative rate drops to 0.5)
    split_times = {}
    
    for (pop1, pop2), (times, cross, within1, within2) in data.items():
        relative_rate = cross / np.sqrt(within1 * within2)
        
        # Find time when relative rate first drops below 0.5
        below_half = np.where(relative_rate < 0.5)[0]
        
        if len(below_half) > 0:
            split_time = times[below_half[0]]
            split_times[(pop1, pop2)] = split_time
    
    if not split_times:
        print("WARNING: Could not calculate split times")
        return
    
    # Create matrix for heatmap
    all_pops = sorted(set([p[0] for p in split_times.keys()] + [p[1] for p in split_times.keys()]))
    n_pops = len(all_pops)
    
    # Initialize matrix
    split_matrix = np.full((n_pops, n_pops), np.nan)
    
    for (pop1, pop2), time in split_times.items():
        i = all_pops.index(pop1)
        j = all_pops.index(pop2)
        split_matrix[i, j] = time
        split_matrix[j, i] = time
    
    # Plot heatmap
    fig, ax = plt.subplots(figsize=(10, 8))
    
    im = ax.imshow(split_matrix, cmap='YlOrRd', aspect='auto')
    
    # Add colorbar
    cbar = plt.colorbar(im, ax=ax)
    cbar.set_label('Split Time (million years ago)', fontsize=12)
    
    # Set labels
    ax.set_xticks(np.arange(n_pops))
    ax.set_yticks(np.arange(n_pops))
    ax.set_xticklabels(all_pops, rotation=45, ha='right', fontsize=10)
    ax.set_yticklabels(all_pops, fontsize=10)
    
    # Add value annotations
    for i in range(n_pops):
        for j in range(n_pops):
            if not np.isnan(split_matrix[i, j]):
                text = ax.text(j, i, f'{split_matrix[i, j]:.1f}',
                              ha='center', va='center', color='black', fontsize=8)
    
    ax.set_title('Estimated Population Split Times\n(Time when cross-coalescence < 50%)',
                 fontsize=14, fontweight='bold')
    
    plt.tight_layout()
    
    png_file = output_file.replace('.png', '_heatmap.png')
    plt.savefig(png_file, dpi=DEFAULT_DPI, bbox_inches='tight')
    print(f"Saved: {png_file}")
    
    plt.close()


def main():
    parser = argparse.ArgumentParser(
        description='Plot MSMC cross-population coalescence rates'
    )
    parser.add_argument(
        '--input-dir', '-i',
        default='msmc_output',
        help='Directory containing cross-population MSMC output'
    )
    parser.add_argument(
        '--output-dir', '-o',
        default='visualization',
        help='Output directory for plots'
    )
    parser.add_argument(
        '--pairs', '-p',
        default=None,
        help='Comma-separated list of population pairs (e.g., Jino:Han,Jino:Tibetan)'
    )
    parser.add_argument(
        '--generation-time', '-g',
        type=int,
        default=25,
        help='Generation time in years'
    )
    
    args = parser.parse_args()
    
    global GENERATION_TIME
    GENERATION_TIME = args.generation_time
    
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Parse pairs
    pairs = None
    if args.pairs:
        pairs = []
        for pair in args.pairs.split(','):
            if ':' in pair:
                pop1, pop2 = pair.split(':')
                pairs.append((pop1.strip(), pop2.strip()))
    
    print("=" * 60)
    print("MSMC Cross-Coalescence Rate Visualization")
    print("=" * 60)
    print(f"Input directory: {args.input_dir}")
    print(f"Output directory: {args.output_dir}")
    print()
    
    # Load data
    print("Loading cross-population MSMC data...")
    data = load_cross_population_data(args.input_dir, pairs)
    
    if not data:
        print("ERROR: No cross-population data loaded")
        sys.exit(1)
    
    print(f"Loaded {len(data)} population pairs")
    print()
    
    # Plot cross-coalescence rates
    print("Generating cross-coalescence plot...")
    output_file = os.path.join(args.output_dir, 'Cross_coalescence.png')
    plot_cross_coalescence(data, output_file)
    
    # Plot relative rates
    print("\nGenerating relative rate plot...")
    rel_output = os.path.join(args.output_dir, 'Cross_coalescence_relative.png')
    plot_relative_cross_rate(data, rel_output)
    
    # Plot split time heatmap
    print("\nGenerating split time heatmap...")
    heatmap_output = os.path.join(args.output_dir, 'Split_time_heatmap.png')
    plot_split_time_heatmap(data, heatmap_output)
    
    print("\n" + "=" * 60)
    print("Visualization complete!")
    print("=" * 60)


if __name__ == '__main__':
    main()
