#!/bin/bash

# Convenient wrapper script for multi-sample genetic screening
# This script sets up the parameters and runs the multi-sample scheduler

# Configuration - Update these paths according to your setup
BEDFILE="$(dirname "$0")/../peakome_test_4k.bed"
SAMPLES_FILE="$(dirname "$0")/../samples_test.txt"
INPUT_DIR="/gpfs/data/abl/home/rodrij92/PROJECTS/BALL_Corigami/maxATAC_GSE226400"
MODEL_PATH="/gpfs/data/abl/home/rodrij92/PROJECTS/BALL_Corigami/C.Origami/ball_stringent-oe_exp_pred_ep32.ckpt"
SEQ_PATH="/gpfs/data/abl/home/rodrij92/PROJECTS/BALL_Corigami/C.Origami/data/hg38/dna_sequence"

echo "Multi-Sample Genetic Screening Pipeline"
echo "========================================"
echo "BED file: $BEDFILE"
echo "Samples file: $SAMPLES_FILE"
echo "Input directory: $INPUT_DIR"
echo "Model path: $MODEL_PATH"
echo "Sequence path: $SEQ_PATH"
echo ""

# Check if all files exist
echo "Checking input files..."
if [ ! -f "$BEDFILE" ]; then
    echo "ERROR: BED file not found: $BEDFILE"
    exit 1
fi

if [ ! -f "$SAMPLES_FILE" ]; then
    echo "ERROR: Samples file not found: $SAMPLES_FILE"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory not found: $INPUT_DIR"
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found: $MODEL_PATH"
    exit 1
fi

if [ ! -d "$SEQ_PATH" ]; then
    echo "ERROR: Sequence directory not found: $SEQ_PATH"
    exit 1
fi

echo "All input files found successfully!"
echo ""

# Count samples
TOTAL_SAMPLES=$(grep -v '^[[:space:]]*#' "$SAMPLES_FILE" | grep -v '^[[:space:]]*$' | wc -l)
echo "Total samples to process: $TOTAL_SAMPLES"
echo ""

# Show sample list
echo "Sample list:"
grep -v '^[[:space:]]*#' "$SAMPLES_FILE" | grep -v '^[[:space:]]*$' | nl
echo ""

# Ask for confirmation
read -p "Do you want to proceed with the screening? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Screening cancelled."
    exit 0
fi

echo ""
echo "Starting multi-sample screening pipeline..."
echo "This will process all $TOTAL_SAMPLES samples sequentially."
echo "Each sample will be processed with the same BED file but different genomic features."
echo ""

# Submit the job
sbatch "$(dirname "$0")/multi_sample_scheduler.sh" "$BEDFILE" "$SAMPLES_FILE" "$INPUT_DIR" "$MODEL_PATH" "$SEQ_PATH"

echo ""
echo "Job submitted successfully!"
echo "You can monitor progress using:"
echo "  squeue -u $USER"
echo ""
echo "Results will be saved in: results_<bedfile_name>_<samples_name>/"
echo "Sample timing information will be in: results_<bedfile_name>_<samples_name>/sample_timing.csv" 
