#!/bin/bash -l
#SBATCH --nodes 1 --ntasks 24 --mem 128G --out logs/train.%a.log -J trainRhod --time 96:00:00

MEM=128G
module load funannotate

#export PASAHOME=`dirname $(which Launch_PASA_pipeline.pl)`
RNADIR=lib/RNASeq
CPUS=$SLURM_CPUS_ON_NODE

if [ ! $CPUS ]; then
    CPUS=2
fi
SAMPLES=samples.csv
N=${SLURM_ARRAY_TASK_ID}

if [ -z $N ]; then
    N=$1
    if [ -z $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPLES | awk '{print $1}')
if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPLES"
    exit
fi

INDIR=final_genomes
OUTDIR=annotation

IFS=,
tail -n +2 $SAMPLES | sed -n ${N}p | while read BASE SPECIES STRAIN BIOPROJECT NCBI_TAXONID BUSCO_LINEAGE PHYLUM SUBPHYLUM CLASS SUBCLASS ORDER FAMILY GENUS SPECIES2 TRANSL_TABLE LOCUS
do    
    name=$BASE
    GENOME=$INDIR/$BASE.masked.fasta
    if [ -z $RNASEQ ]; then
	echo "No RNASeq for training, skipping $BASE"
    else
	# this is dynamically checking for files that are paired but if not paired we use the --single option
	LEFT=$(ls $RNADIR/${RNASEQ} | sed -n 1p)
	RIGHT=$(ls $RNADIR/${RNASEQ} | sed -n 2p)
	if [[ ! -z $LEFT && ! -z $RIGHT ]]; then
		# paired end data
		funannotate train -i $GENOME --cpus $CPUS --memory $MEM  --species "$SPECIES" --strain $STRAIN  -o $OUTDIR/$BASE --jaccard_clip --max_intronlen 1000 \
			--left $LEFT --right $RIGHT
	elif [ ! -z $LEFT ]; then
		# unpaired - single end only
		funannotate train -i $GENOME --cpus $CPUS --memory $MEM  --species "$SPECIES" --strain $STRAIN  -o $OUTDIR/$BASE --jaccard_clip  --max_intronlen 1000 \
			--single $LEFT
	else
	    echo "No RNASeq files found in '$RNADIR' for '$RNASEQ' - check RNASEQ column in $SAMPLES"
	    exit
	fi
    fi
done
