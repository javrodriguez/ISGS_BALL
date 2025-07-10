#!/usr/bin/env python3
"""
Script to compile all bedgraph files into a single table.
Input: Multiple bedgraph files with format: GSM6481795_impact_scores.bedgraph
Output: Single table with peak_id as first column, one column per sample with scores.
"""

import os
import pandas as pd
import re
from collections import defaultdict

def extract_sample_name(filename):
    """Extract sample name from filename like 'GSM6481795_impact_scores.bedgraph'"""
    match = re.match(r'(GSM\d+)_impact_scores\.bedgraph', filename)
    if match:
        return match.group(1)
    else:
        raise ValueError(f"Could not extract sample name from filename: {filename}")

def read_bedgraph_file(filepath):
    """Read bedgraph file and return dict of peak_id -> score"""
    peak_scores = {}
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            parts = line.split('\t')
            if len(parts) >= 5:  # chr, start, end, score, peak_id
                score = float(parts[3])
                peak_id = parts[4]
                peak_scores[peak_id] = score
    
    return peak_scores

def main():
    # Find all bedgraph files in current directory
    bedgraph_files = []
    for filename in os.listdir('.'):
        if filename.endswith('_impact_scores.bedgraph'):
            bedgraph_files.append(filename)
    
    if not bedgraph_files:
        print("No bedgraph files found in current directory!")
        return
    
    print(f"Found {len(bedgraph_files)} bedgraph files")
    
    # Read all bedgraph files and collect data
    all_peaks = set()
    sample_data = {}
    
    for filename in bedgraph_files:
        try:
            sample_name = extract_sample_name(filename)
            print(f"Processing {filename} -> {sample_name}")
            
            peak_scores = read_bedgraph_file(filename)
            sample_data[sample_name] = peak_scores
            all_peaks.update(peak_scores.keys())
            
        except Exception as e:
            print(f"Error processing {filename}: {e}")
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
    output_file = 'compiled_impact_scores.tsv'
    df.to_csv(output_file, sep='\t', index=False)
    
    print(f"Compiled table saved to: {output_file}")
    print(f"Table shape: {df.shape}")
    print(f"Sample columns: {list(df.columns)[1:]}")  # Skip peak_id column
    
    # Print some statistics
    print("\nStatistics:")
    for sample_name in sorted(sample_data.keys()):
        non_null_count = df[sample_name].notna().sum()
        print(f"  {sample_name}: {non_null_count} peaks with scores")

if __name__ == "__main__":
    main() 