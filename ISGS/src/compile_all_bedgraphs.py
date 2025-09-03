#!/usr/bin/env python3
"""
Script to compile all bedgraph files into a single table.
Input: Multiple bedgraph files with format: sample_name/compiled_impact_scores.bedgraph
Output: Single table with peak_id as first column, one column per sample with scores.
"""

import os
import pandas as pd
import re
import argparse
from collections import defaultdict

def extract_sample_name(filepath):
    """Extract sample name from filepath like '/path/to/GSM6481643/compiled_impact_scores.bedgraph'"""
    # Extract the sample directory name from the path
    sample_name = os.path.basename(os.path.dirname(filepath))
    return sample_name

def read_bedgraph_file(filepath):
    """Read bedgraph file and return dict of peak_id -> score"""
    peak_scores = {}
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            parts = line.split('\t')
            if len(parts) >= 4:  # chr, start, end, score_and_peak_id
                # The last part contains both score and peak_id separated by space
                score_peak_part = parts[3]
                # Split by space to separate score and peak_id
                score_peak_parts = score_peak_part.split(' ', 1)  # Split only on first space
                if len(score_peak_parts) == 2:
                    score = float(score_peak_parts[0])
                    peak_id = score_peak_parts[1]
                    peak_scores[peak_id] = score
    
    return peak_scores

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Compile all bedgraph files into a single table')
    parser.add_argument('--input-dir', '-i', required=True,
                       help='Input directory containing sample subdirectories with bedgraph files')
    parser.add_argument('--output-file', '-o', default='compiled_impact_scores.tsv',
                       help='Output file name (default: compiled_impact_scores.tsv)')
    
    args = parser.parse_args()
    
    # Check if input directory exists
    if not os.path.exists(args.input_dir):
        print(f"Error: Input directory '{args.input_dir}' does not exist!")
        return
    
    # Find all bedgraph files in any sample subdirectories
    bedgraph_files = []
    for item in os.listdir(args.input_dir):
        item_path = os.path.join(args.input_dir, item)
        if os.path.isdir(item_path):
            bedgraph_file = os.path.join(item_path, 'compiled_impact_scores.bedgraph')
            if os.path.exists(bedgraph_file):
                bedgraph_files.append(bedgraph_file)
    
    if not bedgraph_files:
        print(f"No bedgraph files found in directory: {args.input_dir}")
        return
    
    print(f"Found {len(bedgraph_files)} bedgraph files in {args.input_dir}")
    
    # Read all bedgraph files and collect data
    all_peaks = set()
    sample_data = {}
    
    for filepath in bedgraph_files:
        try:
            sample_name = extract_sample_name(filepath)
            print(f"Processing {sample_name} from {filepath}")
            
            peak_scores = read_bedgraph_file(filepath)
            sample_data[sample_name] = peak_scores
            all_peaks.update(peak_scores.keys())
            
        except Exception as e:
            print(f"Error processing {filepath}: {e}")
            continue
    
    # Create the compiled table
    print(f"Creating table with {len(all_peaks)} peaks and {len(sample_data)} samples")
    
    # Sort peaks for consistent output
    sorted_peaks = sorted(all_peaks, key=lambda x: int(x.split('_')[1]))
    
    # Create DataFrame
    data = {'peak_id': sorted_peaks}
    
    for sample_name in sorted(sample_data.keys()):
        sample_scores = []
        for peak_id in sorted_peaks:
            score = sample_data[sample_name].get(peak_id, None)
            sample_scores.append(score)
        data[sample_name] = sample_scores
    
    df = pd.DataFrame(data)
    
    # Save to file
    df.to_csv(args.output_file, sep='\t', index=False)
    
    print(f"Compiled table saved to: {args.output_file}")
    print(f"Table shape: {df.shape}")
    print(f"Sample columns: {list(df.columns)[1:]}")  # Skip peak_id column
    
    # Print some statistics
    print("\nStatistics:")
    for sample_name in sorted(sample_data.keys()):
        non_null_count = df[sample_name].notna().sum()
        print(f"  {sample_name}: {non_null_count} peaks with scores")

if __name__ == "__main__":
    main() 