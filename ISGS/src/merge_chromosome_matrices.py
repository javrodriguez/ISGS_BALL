#!/usr/bin/env python3
"""
Script to merge all chromosome-specific unified matrices into one single matrix.
Input: Multiple unified_impact_scores_matrix.tsv files from different chromosomes
Output: Single unified_matrix.csv with all chromosomes combined
"""

import os
import pandas as pd
import argparse
import glob

def find_chromosome_matrices(input_dir):
    """Find all unified_impact_scores_matrix.tsv files in chromosome directories"""
    pattern = os.path.join(input_dir, "screening_results_chr*/unified_impact_scores_matrix.tsv")
    matrix_files = glob.glob(pattern)
    
    # Sort by chromosome number
    matrix_files.sort(key=lambda x: int(os.path.basename(os.path.dirname(x)).replace('screening_results_chr', '')))
    
    return matrix_files

def extract_chromosome_from_path(filepath):
    """Extract chromosome number from file path"""
    dirname = os.path.basename(os.path.dirname(filepath))
    chr_num = dirname.replace('screening_results_chr', '')
    return f"chr{chr_num}"

def read_and_prepare_matrix(filepath, chromosome):
    """Read matrix file and add chromosome prefix to peak IDs"""
    print(f"Reading {chromosome} matrix from {filepath}")
    
    df = pd.read_csv(filepath, sep='\t')
    
    # Add chromosome prefix to peak IDs
    df['peak_id'] = df['peak_id'].apply(lambda x: f"{chromosome}_{x}")
    
    print(f"  - Shape: {df.shape}")
    print(f"  - Peaks: {len(df)}")
    print(f"  - Samples: {len(df.columns) - 1}")
    
    return df

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Merge chromosome-specific matrices into one unified matrix')
    parser.add_argument('--input-dir', '-i', default='.',
                       help='Input directory containing screening_results_chr* directories (default: current directory)')
    parser.add_argument('--output-file', '-o', default='unified_matrix.csv',
                       help='Output file name (default: unified_matrix.csv)')
    parser.add_argument('--format', '-f', choices=['csv', 'tsv'], default='csv',
                       help='Output format: csv or tsv (default: csv)')
    
    args = parser.parse_args()
    
    print("Merging chromosome-specific matrices into unified matrix...")
    print(f"Input directory: {args.input_dir}")
    print(f"Output file: {args.output_file}")
    print(f"Output format: {args.format}")
    print("")
    
    # Find all chromosome matrix files
    matrix_files = find_chromosome_matrices(args.input_dir)
    
    if not matrix_files:
        print(f"No chromosome matrices found in {args.input_dir}")
        print("Looking for files matching: screening_results_chr*/unified_impact_scores_matrix.tsv")
        return
    
    print(f"Found {len(matrix_files)} chromosome matrices:")
    for filepath in matrix_files:
        chromosome = extract_chromosome_from_path(filepath)
        print(f"  - {chromosome}: {filepath}")
    print("")
    
    # Read and prepare all matrices
    chromosome_dfs = []
    
    for filepath in matrix_files:
        chromosome = extract_chromosome_from_path(filepath)
        df = read_and_prepare_matrix(filepath, chromosome)
        chromosome_dfs.append(df)
    
    print("")
    print("Merging matrices...")
    
    # Merge all dataframes
    unified_df = pd.concat(chromosome_dfs, ignore_index=True)
    
    print(f"Unified matrix created:")
    print(f"  - Total peaks: {len(unified_df)}")
    print(f"  - Total samples: {len(unified_df.columns) - 1}")
    print(f"  - Shape: {unified_df.shape}")
    
    # Determine separator based on format
    separator = ',' if args.format == 'csv' else '\t'
    
    # Save unified matrix
    unified_df.to_csv(args.output_file, sep=separator, index=False)
    
    print(f"")
    print(f"Unified matrix saved to: {args.output_file}")
    print(f"File size: {os.path.getsize(args.output_file) / (1024*1024):.2f} MB")
    
    # Print summary statistics
    print(f"")
    print("Summary by chromosome:")
    print("Chromosome | Peaks | Samples")
    print("-----------|-------|--------")
    
    for i, filepath in enumerate(matrix_files):
        chromosome = extract_chromosome_from_path(filepath)
        peak_count = len(chromosome_dfs[i])
        sample_count = len(chromosome_dfs[i].columns) - 1
        print(f"{chromosome:10} | {peak_count:5} | {sample_count:7}")
    
    # Check for missing values
    total_cells = unified_df.shape[0] * unified_df.shape[1]
    missing_cells = unified_df.isnull().sum().sum()
    missing_percentage = (missing_cells / total_cells) * 100
    
    print(f"")
    print(f"Data completeness:")
    print(f"  - Total cells: {total_cells:,}")
    print(f"  - Missing cells: {missing_cells:,}")
    print(f"  - Missing percentage: {missing_percentage:.2f}%")
    
    # Show sample columns
    sample_columns = [col for col in unified_df.columns if col != 'peak_id']
    print(f"")
    print(f"Sample columns ({len(sample_columns)}):")
    for i, sample in enumerate(sample_columns):
        if i < 5:
            print(f"  - {sample}")
        elif i == 5:
            print(f"  - ... and {len(sample_columns) - 5} more samples")
            break

if __name__ == "__main__":
    main()
