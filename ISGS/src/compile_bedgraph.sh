#!/bin/bash
#SBATCH --partition=gpu4_short,gpu4_medium,gpu8_short,gpu8_medium
#SBATCH -c 10
#SBATCH --mem=5G
#SBATCH -t 4:00:00

INPUT_DIR=$1
OUTPUT_FILE=$2

module load parallel

find "${INPUT_DIR}" -type f -path "*/PEAK_*/screening/bedgraph/*impact_score.bedgraph" | \
parallel -j 20 '
    peak_id=$(echo {} | grep -o "PEAK_[0-9]\+")
    awk -v peak="$peak_id" "{print \$0, peak}" {}
' > "$OUTPUT_FILE"

# Remove the individual files after compiling
find "${INPUT_DIR}" -type f -path "*/PEAK_*/screening/bedgraph/*impact_score.bedgraph" -delete 