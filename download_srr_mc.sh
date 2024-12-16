#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <srr_ids_file.txt> <output_folder>"
    exit 1
fi

# Assign arguments to variables
SRR_ID_FILE="$1"
OUTPUT_FOLDER="$2"
FASTQ_FOLDER="$OUTPUT_FOLDER/fastq"

# Detect operating system and set the number of processors
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    TOTAL_PROCESSORS=$(nproc)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    TOTAL_PROCESSORS=$(sysctl -n hw.ncpu)
else
    echo "Unsupported OS"
    exit 1
fi

# Set up number of processors for multi-core processes
NUM_PARALLEL_TASKS=$((TOTAL_PROCESSORS / 2)) # Use half the cores for simultaneous tasks
NUM_FASTERQ_CPUS=$((TOTAL_PROCESSORS / 4))   # Use one-fourth of cores for each fasterq-dump
NUM_PIGZ_CPUS=$((TOTAL_PROCESSORS / 4))     # Use one-fourth of cores for each pigz
[ "$NUM_PARALLEL_TASKS" -lt 1 ] && NUM_PARALLEL_TASKS=1
[ "$NUM_FASTERQ_CPUS" -lt 1 ] && NUM_FASTERQ_CPUS=1
[ "$NUM_PIGZ_CPUS" -lt 1 ] && NUM_PIGZ_CPUS=1

echo "Using $TOTAL_PROCESSORS total cores."
echo "Running $NUM_PARALLEL_TASKS parallel tasks."
echo "Allocating $NUM_FASTERQ_CPUS CPUs for fasterq-dump and $NUM_PIGZ_CPUS CPUs for pigz."

# Create output folder if it doesn't exist
if [ ! -d "$FASTQ_FOLDER" ]; then
    mkdir -p "$FASTQ_FOLDER"
fi

process_srr_id() {
    local SRR_ID="$1"
    echo "Processing $SRR_ID"

    # Start the timer
    start_time=$(date +%s)

    # Prefetch the data using the SRR ID
    echo "Prefetching $SRR_ID"
    if ! prefetch "$SRR_ID" -O "$OUTPUT_FOLDER"; then
        echo "Error: Prefetch failed for $SRR_ID" >&2
        return 1
    fi

    # Dump the fastq files
    echo "Fasterq dump on $SRR_ID"
    if ! fasterq-dump "$OUTPUT_FOLDER/$SRR_ID" \
        -O "$FASTQ_FOLDER" \
        -e "$NUM_FASTERQ_CPUS" \
        --split-files \
        --progress; then
        echo "Error: fasterq-dump failed for $SRR_ID" >&2
        return 1
    fi

    # Compress the fastq files using pigz
    echo "Compressing $SRR_ID"
    if ! pigz -p "$NUM_PIGZ_CPUS" \
        "$FASTQ_FOLDER/${SRR_ID}_1.fastq" "$FASTQ_FOLDER/${SRR_ID}_2.fastq"; then
        echo "Error: pigz compression failed for $SRR_ID" >&2
        return 1
    fi

    # Check if .fastq.gz files exist and remove the prefetch folder if they do
    if ls "$FASTQ_FOLDER/${SRR_ID}*.fastq.gz" 1> /dev/null 2>&1; then
        echo ".fastq.gz files found for $SRR_ID, removing prefetch folder"
        rm -rf "$OUTPUT_FOLDER/$SRR_ID"
    else
        echo "No .fastq.gz files found for $SRR_ID, keeping prefetch folder"
    fi

    # End the timer
    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))
    minutes=$((elapsed_time / 60))
    seconds=$((elapsed_time % 60))
    echo "$SRR_ID processed in $minutes minutes and $seconds seconds."
}

export -f process_srr_id  # Export the function for use by xargs
export OUTPUT_FOLDER FASTQ_FOLDER NUM_FASTERQ_CPUS NUM_PIGZ_CPUS  # Export variables

# Process all SRR IDs in parallel
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xargs_cmd="xargs -a"
else
    xargs_cmd="cat"
fi

${xargs_cmd} "$SRR_ID_FILE" | xargs -n 1 -P "$NUM_PARALLEL_TASKS" bash -c 'process_srr_id "$@"' _

echo "Done."

echo "Done."