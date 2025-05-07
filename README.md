# SRR_fetch

## Description
Scripts for downloading, converting, and compressing SRR files from NCBI

## Scripts

### download_srr.sh

A sequential processor that downloads and processes one SRR ID at a time.

### download_srr_mc.sh

A multi-core version that processes multiple SRR IDs in parallel, optimizing system resource usage.

### Arguments 
1) File with SRR accession numbers
2) Output folder

### Example usage: 
``` bash
sh download_srr.sh ./demo/SRR_Acc_List.txt .
```
## Requirements

- pigz
- sra-tools