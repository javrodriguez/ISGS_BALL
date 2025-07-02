#!/bin/bash
#SBATCH -J multiSampleScheduler
#SBATCH --partition=gpu4_long,gpu8_long
#SBATCH --mem=2gb 
#SBATCH --output=logs-multi_sample_scheduler/%J.logout
#SBATCH --error=logs-multi_sample_scheduler/%J.logerr

# Multi-sample genetic screening scheduler
# Usage: sbatch multi_sample_scheduler.sh <bedfile> <samples_file> <input_dir> <model_path> <seq_path>

BEDFILE=$1
SAMPLES_FILE=$2
INPUT_DIR=$3
MODEL_PATH=$4
SEQ_PATH=$5

# Validate inputs
if [ $# -ne 5 ]; then
    echo "Usage: sbatch multi_sample_scheduler.sh <bedfile> <samples_file> <input_dir> <model_path> <seq_path>"
    echo "Example: sbatch multi_sample_scheduler.sh unified_peakome_1kb_exact.bed samples.txt /path/to/data /path/to/model.ckpt /path/to/seq"
    exit 1
fi

# Check if files exist
if [ ! -f "$BEDFILE" ]; then
    echo "Error: BED file $BEDFILE not found"
    exit 1
fi

if [ ! -f "$SAMPLES_FILE" ]; then
    echo "Error: Samples file $SAMPLES_FILE not found"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory $INPUT_DIR not found"
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "Error: Model file $MODEL_PATH not found"
    exit 1
fi

if [ ! -d "$SEQ_PATH" ]; then
    echo "Error: Sequence directory $SEQ_PATH not found"
    exit 1
fi

# Record overall start time
overall_start_time=$(date +%s)

echo "Starting multi-sample genetic screening pipeline"
echo "BED file: $BEDFILE"
echo "Samples file: $SAMPLES_FILE"
echo "Input directory: $INPUT_DIR"
echo "Model path: $MODEL_PATH"
echo "Sequence path: $SEQ_PATH"

# Create main output directory
MAIN_OUTDIR="screening_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$MAIN_OUTDIR"

# Create log directories
mkdir -p "logs-multi_sample_scheduler"

# Create timing log file
echo "Sample,Start Time,End Time,Duration (seconds),Status" > "${MAIN_OUTDIR}/sample_timing.csv"

# Count actual samples (excluding comments and empty lines)
total_samples=$(grep -v '^[[:space:]]*#' "$SAMPLES_FILE" | grep -v '^[[:space:]]*$' | wc -l)
echo "Total samples to process: $total_samples"

# Process each sample
sample_count=0

while IFS= read -r sample_name; do
    # Skip empty lines and comments
    [[ -z "$sample_name" || "$sample_name" =~ ^[[:space:]]*# ]] && continue
    
    sample_count=$((sample_count + 1))
    echo "Processing sample $sample_count/$total_samples: $sample_name"
    
    # Record sample start time
    sample_start_time=$(date +%s)
    
    # Set sample-specific paths
    SAMPLE_OUTDIR="${MAIN_OUTDIR}/${sample_name}"
    CTCF_PATH="${INPUT_DIR}/${sample_name}.dd-maxATAC-predict/maxatac_predict.bw"
    ATAC_PATH="${INPUT_DIR}/${sample_name}.dd-maxATAC_prepare/${sample_name}.dd_IS_slop20_RP20M_minmax01.bw"
    
    # Check if sample files exist
    if [ ! -f "$CTCF_PATH" ]; then
        echo "Warning: CTCF file not found for sample $sample_name: $CTCF_PATH"
        sample_end_time=$(date +%s)
        sample_duration=$((sample_end_time - sample_start_time))
        echo "${sample_name},${sample_start_time},${sample_end_time},${sample_duration},SKIPPED_CTCF_MISSING" >> "${MAIN_OUTDIR}/sample_timing.csv"
        continue
    fi
    
    if [ ! -f "$ATAC_PATH" ]; then
        echo "Warning: ATAC file not found for sample $sample_name: $ATAC_PATH"
        sample_end_time=$(date +%s)
        sample_duration=$((sample_end_time - sample_start_time))
        echo "${sample_name},${sample_start_time},${sample_end_time},${sample_duration},SKIPPED_ATAC_MISSING" >> "${MAIN_OUTDIR}/sample_timing.csv"
        continue
    fi
    
    # Create sample output directory
    mkdir -p "$SAMPLE_OUTDIR"
    
    # Create log directories with sample_name expanded at generation time
    mkdir -p "logs-job_scheduler_${sample_name}"
    mkdir -p "logs-screen_${sample_name}"
    
    # Create sample-specific screen script
    SAMPLE_SCREEN_SCRIPT="${SAMPLE_OUTDIR}/screen_${sample_name}.sh"
    echo "#!/bin/bash" > "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH -J screen_${sample_name}" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --mem=10gb" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --partition=gpu4_short,gpu4_medium,gpu8_short,gpu8_medium" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --output=logs-screen_${sample_name}/%J.out" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --error=logs-screen_${sample_name}/%J.err" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --time=12:00:00" >> "$SAMPLE_SCREEN_SCRIPT"
    cat >> "$SAMPLE_SCREEN_SCRIPT" << EOF
bedfile=\$1
outdir=\$2
model=${MODEL_PATH}
seq=${SEQ_PATH}
ctcf=${CTCF_PATH}
atac=${ATAC_PATH}

chr=\$(awk "NR==\${SLURM_ARRAY_TASK_ID} {print \\\$1}" \${bedfile})
start=\$(awk "NR==\${SLURM_ARRAY_TASK_ID} {print \\\$2}" \${bedfile})
end=\$(awk "NR==\${SLURM_ARRAY_TASK_ID} {print \\\$3}" \${bedfile})
peak_id=\$(awk "NR==\${SLURM_ARRAY_TASK_ID} {print \\\$4}" \${bedfile})
peak_length=\$((end-start))

source /gpfs/home/rodrij92/home_abl/miniconda3/etc/profile.d/conda.sh
conda activate corigami_ball
sleep 5

corigami-screen --out \${outdir} --celltype \${peak_id} --chr \${chr} --model \${model} --seq \${seq} --ctcf \${ctcf} --atac \${atac} --screen-start \${start} --screen-end \${end} --perturb-width \${peak_length} --step-size \${peak_length} --save-bedgraph --padding zero --save-frames
EOF
    
    chmod +x "$SAMPLE_SCREEN_SCRIPT"
    
    # Run the sample-specific job scheduler
    echo "Starting screening for sample: $sample_name"
    
    # Define batch parameters (previously in job_scheduler script)
    BATCH_SIZE=1000
    MAX_INDEX=2500
    
    # Record sample processing start time
    sample_processing_start_time=$(date +%s)
    
    # Create output directory if it doesn't exist
    mkdir -p "${SAMPLE_OUTDIR}"

    # Create timing log file
    echo "Batch,Start Time,End Time,Duration (seconds)" > "${SAMPLE_OUTDIR}/batch_timing.csv"

    # Split BED file into chunks
    split -l $MAX_INDEX -d $BEDFILE ${SAMPLE_OUTDIR}/bed_chunk_

    for chunk in ${SAMPLE_OUTDIR}/bed_chunk_*; do
        lines=$(wc -l < "$chunk")
        num_batches=$(( (lines + BATCH_SIZE - 1) / BATCH_SIZE ))
        
        for ((i=0; i<num_batches; i++)); do
            # Record batch start time
            batch_start_time=$(date +%s)
            
            start=$((i * BATCH_SIZE + 1))
            end=$(( (i + 1) * BATCH_SIZE ))
            [ "$end" -gt "$lines" ] && end=$lines
            
            # Submit batch job directly from main scheduler (no nested sbatch)
            JOB=$(sbatch --time=12:00:00 --array=${start}-${end} ${SAMPLE_SCREEN_SCRIPT} "$chunk" "${SAMPLE_OUTDIR}" | awk '{print $4}')
            echo "Submitted batch job with ID $JOB for sample ${sample_name}, waiting to complete..."
            sleep 5
            # Wait for job to appear in squeue
            while ! squeue -j $JOB | grep -q $JOB; do
                echo "Waiting for squeue to recognize job $JOB..."
                sleep 2
            done
            # Wait for job to finish (disappear from squeue)
            while squeue -j $JOB | grep -q $JOB; do
                echo "Waiting for job $JOB to finish..."
                sleep 10
            done
            
            # Record batch end time and duration
            batch_end_time=$(date +%s)
            batch_duration=$((batch_end_time - batch_start_time))
            
            # Log batch timing
            echo "${chunk}_batch_${i},${batch_start_time},${batch_end_time},${batch_duration}" >> "${SAMPLE_OUTDIR}/batch_timing.csv"
            
            echo "Completed batch ${i} of ${chunk} for sample ${sample_name} in ${batch_duration} seconds"
        done
    done

    # Record overall end time and calculate total duration
    overall_end_time=$(date +%s)
    total_duration=$((overall_end_time - sample_processing_start_time))

    # Add total duration to timing log
    echo "TOTAL,${sample_processing_start_time},${overall_end_time},${total_duration}" >> "${SAMPLE_OUTDIR}/batch_timing.csv"
    echo "Total execution time for sample ${sample_name}: ${total_duration} seconds"
    
    # Record sample end time and duration
    sample_end_time=$(date +%s)
    sample_duration=$((sample_end_time - sample_start_time))
    
    # Check if sample completed successfully
    if squeue -j $SAMPLE_JOB | grep -q $SAMPLE_JOB; then
        status="COMPLETED"
        echo "Sample $sample_name completed successfully in ${sample_duration} seconds"
    else
        status="FAILED"
        echo "Sample $sample_name failed after ${sample_duration} seconds"
    fi
    
    # Log sample timing
    echo "${sample_name},${sample_start_time},${sample_end_time},${sample_duration},${status}" >> "${MAIN_OUTDIR}/sample_timing.csv"
    
done < "$SAMPLES_FILE"

# Record overall end time and calculate total duration
overall_end_time=$(date +%s)
total_duration=$((overall_end_time - overall_start_time))

# Add total duration to timing log
echo "TOTAL,${overall_start_time},${overall_end_time},${total_duration}" >> "${MAIN_OUTDIR}/sample_timing.csv"

echo "Multi-sample screening completed!"
echo "Total execution time: ${total_duration} seconds"
echo "Results saved in: ${MAIN_OUTDIR}"
echo "Sample timing log: ${MAIN_OUTDIR}/sample_timing.csv" 