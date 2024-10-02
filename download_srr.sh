#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <ssr_ids_file.txt> <output_folder>"
    exit 1
fi

# Assign arguments to variables
SSR_ID_FILE="$1"
OUTPUT_FOLDER="$2"
FASTQ_FOLDER="$OUTPUT_FOLDER/fastq"

# Detect operating system and set the number of processors
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux OS
    NUM_PROCESSORS=$(nproc --ignore=1)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    TOTAL_CPUS=$(sysctl -n hw.ncpu)
    NUM_PROCESSORS=$((TOTAL_CPUS - 1))
else
    echo "Unsupported OS"
    exit 1
fi

# Create output folder if it doesn't exist
if [ ! -d "$FASTQ_FOLDER" ]; then
    mkdir -p "$FASTQ_FOLDER"
fi

# Read the SSR IDs from the file
while read -r SSR_ID; do
    echo "Processing $SSR_ID"

    # Start the timer
    start_time=$(date +%s)

    # Prefetch the data using the SSR ID
    echo "Prefetching $SSR_ID"
    prefetch "$SSR_ID" \
      -O "$OUTPUT_FOLDER"

    # Dump the fastq files
    echo "Fasterq dump on $SSR_ID"
    fasterq-dump "$OUTPUT_FOLDER/$SSR_ID" \
      -O "$FASTQ_FOLDER" \
      -e "$NUM_PROCESSORS" \
      --split-files \
      --progress

    # Compress the fastq files using pigz
    echo "Compressing $SSR_ID"
    pigz -p "$NUM_PROCESSORS" \
      "$FASTQ_FOLDER/${SSR_ID}_1.fastq" "$FASTQ_FOLDER/${SSR_ID}_2.fastq"

    # Check if .fastq.gz files exist and remove the prefetch folder if they do
    if ls "$FASTQ_FOLDER/${SSR_ID}*.fastq.gz" 1> /dev/null 2>&1; then
        echo ".fastq.gz files found for $SSR_ID, removing prefetch folder"
        rm -rf "$OUTPUT_FOLDER/$SSR_ID"
    else
        echo "No .fastq.gz files found for $SSR_ID, keeping prefetch folder"
    fi

    # End the timer
    end_time=$(date +%s)
    
    # Calculate elapsed time
    elapsed_time=$((end_time - start_time))
    
    # Convert seconds to minutes and seconds format
    minutes=$((elapsed_time / 60))
    seconds=$((elapsed_time % 60))
    
    # Print the time taken for this SSR_ID
    echo "$SSR_ID processed in $minutes minutes and $seconds seconds."

done < "$SSR_ID_FILE"