#!/bin/bash

# Test script for single sample to verify pipeline functionality
# This creates a minimal test environment

echo "Single Sample Pipeline Test"
echo "=========================="

# Create a test samples file with just one sample
echo "BALL-MCG001" > test_samples.txt

# Create a minimal test BED file (just 10 lines)
head -10 ../unified_peakome_1kb_no_overlaps.bed > test_bed.bed

echo "Created test files:"
echo "- test_samples.txt (1 sample)"
echo "- test_bed.bed (10 peaks)"
echo ""

# Test the pipeline with minimal data
echo "Testing pipeline with minimal data..."
echo "This will create the directory structure and scripts but won't submit jobs."

# Set test paths (these won't exist, but we're just testing script generation)
BEDFILE="test_bed.bed"
SAMPLES_FILE="test_samples.txt"
INPUT_DIR="/test/path"
MODEL_PATH="/test/model.ckpt"
SEQ_PATH="/test/seq"

# Create main output directory
MAIN_OUTDIR="test_screening_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$MAIN_OUTDIR"

echo "Processing test sample..."

# Read the sample name
while IFS= read -r sample_name; do
    echo "Processing sample: $sample_name"
    
    # Set sample-specific paths
    SAMPLE_OUTDIR="${MAIN_OUTDIR}/${sample_name}"
    CTCF_PATH="${INPUT_DIR}/${sample_name}.dd-maxATAC-predict/maxatac_predict.bw"
    ATAC_PATH="${INPUT_DIR}/${sample_name}.dd-maxATAC_prepare/${sample_name}.dd_IS_slop20_RP20M_minmax01.bw"
    
    # Create sample output directory
    mkdir -p "$SAMPLE_OUTDIR"
    
    # Create sample-specific screen script
    SAMPLE_SCREEN_SCRIPT="${SAMPLE_OUTDIR}/screen_${sample_name}.sh"
    cat > "$SAMPLE_SCREEN_SCRIPT" << EOF
#!/bin/bash
#SBATCH -J screen_${sample_name}
#SBATCH --mem=10gb 
#SBATCH --partition=gpu4_short,gpu4_medium,gpu8_short,gpu8_medium
#SBATCH --output=logs-screen_${sample_name}/%J.out
#SBATCH --error=logs-screen_${sample_name}/%J.logerr

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
    
    # Create sample-specific job scheduler
    SAMPLE_JOB_SCHEDULER="${SAMPLE_OUTDIR}/job_scheduler_${sample_name}.sh"
    cat > "$SAMPLE_JOB_SCHEDULER" << EOF
#!/bin/bash
#SBATCH -J jobScheduler_${sample_name}
#SBATCH --partition=gpu4_long,gpu8_long
#SBATCH --mem=2gb 
#SBATCH --output=logs-job_scheduler_${sample_name}/%J.logout
#SBATCH --error=logs-job_scheduler_${sample_name}/%J.logerr

# Record overall start time
overall_start_time=\$(date +%s)
BEDFILE=${BEDFILE}
OUTDIR=${SAMPLE_OUTDIR}
BATCH_SIZE=1000
MAX_INDEX=2500

# Create output directory if it doesn't exist
mkdir -p "\${OUTDIR}"

# Create log directories
mkdir -p "logs-job_scheduler_${sample_name}"
mkdir -p "logs-screen_${sample_name}"

# Create timing log file
echo "Batch,Start Time,End Time,Duration (seconds)" > "\${OUTDIR}/batch_timing.csv"

# Split BED file into chunks
split -l \$MAX_INDEX -d \$BEDFILE \${OUTDIR}/bed_chunk_

for chunk in \${OUTDIR}/bed_chunk_*; do
    lines=\$(wc -l < "\$chunk")
    num_batches=\$(( (lines + BATCH_SIZE - 1) / BATCH_SIZE ))
    
    for ((i=0; i<num_batches; i++)); do
        # Record batch start time
        batch_start_time=\$(date +%s)
        
        start=\$((i * BATCH_SIZE + 1))
        end=\$(( (i + 1) * BATCH_SIZE ))
        [ "\$end" -gt "\$lines" ] && end=\$lines
        
        JOB=\$(sbatch --array=\${start}-\${end} ${SAMPLE_SCREEN_SCRIPT} "\$chunk" "\${OUTDIR}" | awk '{print \\\$4}')
        echo "Submitted batch job with ID \$JOB for sample ${sample_name}, waiting to complete..."
        sleep 10
        
        while sacct -j \$JOB --format=State --noheader | grep -q 'RUNNING\|PENDING'; do
            sleep 10
        done
        
        # Record batch end time and duration
        batch_end_time=\$(date +%s)
        batch_duration=\$((batch_end_time - batch_start_time))
        
        # Log batch timing
        echo "\${chunk}_batch_\${i},\${batch_start_time},\${batch_end_time},\${batch_duration}" >> "\${OUTDIR}/batch_timing.csv"
        
        echo "Completed batch \${i} of \${chunk} for sample ${sample_name} in \${batch_duration} seconds"
    done
done

# Record overall end time and calculate total duration
overall_end_time=\$(date +%s)
total_duration=\$((overall_end_time - overall_start_time))

# Add total duration to timing log
echo "TOTAL,\${overall_start_time},\${overall_end_time},\${total_duration}" >> "\${OUTDIR}/batch_timing.csv"
echo "Total execution time for sample ${sample_name}: \${total_duration} seconds"
EOF
    
    chmod +x "$SAMPLE_JOB_SCHEDULER"
    
    echo "Generated scripts for sample $sample_name:"
    echo "- $SAMPLE_SCREEN_SCRIPT"
    echo "- $SAMPLE_JOB_SCHEDULER"
    
done < "$SAMPLES_FILE"

echo ""
echo "Test completed successfully!"
echo "Generated files in: $MAIN_OUTDIR"
echo ""
echo "To run the actual pipeline:"
echo "1. Update paths in run_multi_sample_screening.sh"
echo "2. Create a proper samples.txt file"
echo "3. Run: ./run_multi_sample_screening.sh" 