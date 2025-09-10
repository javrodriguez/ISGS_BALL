#!/bin/bash

# Script to check screening results status across all chromosomes
# Usage: ./check_screening_status.sh [output_file]
# Default output: screening_metrics.csv

OUTPUT_FILE="${1:-screening_metrics.csv}"

echo "Checking screening results status..."
echo "Output file: $OUTPUT_FILE"

# Create header for CSV file
echo "Chromosome,Samples_Completed,Peaks_Per_Sample,Unified_Matrix_Exists,Unified_Matrix_Lines" > "$OUTPUT_FILE"

# Find all result directories (both old and new naming conventions)
for result_dir in screening_results_chr* results_*; do
    if [ -d "$result_dir" ]; then
        # Extract chromosome from directory name
        if [[ "$result_dir" =~ screening_results_chr(.+) ]]; then
            chr="${BASH_REMATCH[1]}"
        elif [[ "$result_dir" =~ results_.*_chr(.+)_ ]]; then
            chr="${BASH_REMATCH[1]}"
        else
            # For other naming patterns, use the full directory name
            chr=$(echo "$result_dir" | sed 's/^results_//' | sed 's/^screening_results_//')
        fi
        
        echo "Processing $result_dir (chr$chr)..."
        
        # Count samples with compiled_impact_scores.bedgraph files
        samples_completed=0
        peaks_per_sample=""
        
        if [ -d "$result_dir" ]; then
            # Count compiled bedgraph files
            samples_completed=$(find "$result_dir" -name "compiled_impact_scores.bedgraph" -type f | wc -l)
            
            # Get peak counts for each sample (if any exist)
            if [ $samples_completed -gt 0 ]; then
                peak_counts=()
                for bedgraph_file in "$result_dir"/*/compiled_impact_scores.bedgraph; do
                    if [ -f "$bedgraph_file" ]; then
                        peak_count=$(wc -l < "$bedgraph_file")
                        peak_counts+=("$peak_count")
                    fi
                done
                
                # Create summary of peak counts
                if [ ${#peak_counts[@]} -gt 0 ]; then
                    # Calculate min, max, avg
                    min_peaks=${peak_counts[0]}
                    max_peaks=${peak_counts[0]}
                    total_peaks=0
                    
                    for count in "${peak_counts[@]}"; do
                        if [ $count -lt $min_peaks ]; then
                            min_peaks=$count
                        fi
                        if [ $count -gt $max_peaks ]; then
                            max_peaks=$count
                        fi
                        total_peaks=$((total_peaks + count))
                    done
                    
                    avg_peaks=$((total_peaks / ${#peak_counts[@]}))
                    peaks_per_sample="min:$min_peaks,max:$max_peaks,avg:$avg_peaks"
                else
                    peaks_per_sample="N/A"
                fi
            else
                peaks_per_sample="N/A"
            fi
        else
            peaks_per_sample="N/A"
        fi
        
        # Check for unified matrix file
        unified_matrix_file="$result_dir/unified_impact_scores_matrix.tsv"
        unified_matrix_exists="No"
        unified_matrix_lines="N/A"
        
        if [ -f "$unified_matrix_file" ]; then
            unified_matrix_exists="Yes"
            unified_matrix_lines=$(wc -l < "$unified_matrix_file")
            # Subtract 1 for header line
            unified_matrix_lines=$((unified_matrix_lines - 1))
        fi
        
        # Write to CSV
        echo "$chr,$samples_completed,$peaks_per_sample,$unified_matrix_exists,$unified_matrix_lines" >> "$OUTPUT_FILE"
        
        echo "  - Samples completed: $samples_completed"
        echo "  - Peaks per sample: $peaks_per_sample"
        echo "  - Unified matrix: $unified_matrix_exists ($unified_matrix_lines lines)"
    fi
done

echo ""
echo "Screening status check completed!"
echo "Results saved to: $OUTPUT_FILE"
echo ""
echo "Summary:"
echo "========"

# Display summary table
if [ -f "$OUTPUT_FILE" ]; then
    echo "Chromosome | Samples | Peaks (min/max/avg) | Matrix | Matrix Lines"
    echo "-----------|---------|---------------------|--------|-------------"
    
    # Skip header line and display data
    tail -n +2 "$OUTPUT_FILE" | while IFS=',' read -r chr samples peaks matrix matrix_lines; do
        printf "%-10s | %-7s | %-19s | %-6s | %-11s\n" "$chr" "$samples" "$peaks" "$matrix" "$matrix_lines"
    done
fi

echo ""
echo "Detailed results available in: $OUTPUT_FILE"
