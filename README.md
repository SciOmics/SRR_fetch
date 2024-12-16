# SRR_fetch
Scripts for downloading, converting, and compressing SRR files from NCBI

download_srr_mc.sh takes advantage of parallel processing.

Arguments: 
1) File with SRR accession numbers
2) Output folder

Example usage: 
sh download_srr.sh ./demo/SRR_Acc_List.txt ~/Downloads

Be sure you have pigz and sra-tools installed. 
