#!/bin/bash -l
#SBATCH -N 1 -c 24 -n 1 --mem 64G -p batch --out logs/annotate.%a.log
# note this doesn't need that much memory EXCEPT for the XML -> tsv parsing that happens when you provided an interpro XML file

module load workspace/scratch

CPUS=$SLURM_CPUS_ON_NODE

if [ -z "$CPUS" ]; then
    CPUS=2
fi
SAMPFILE=samples.csv
N=${SLURM_ARRAY_TASK_ID}

if [ -z "$N" ]; then
    N=$1
    if [ -z "$N" ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPFILE | awk '{print $1}')
if [ "$N" -gt "$MAX" ]; then
    echo "$N is too big, only $MAX lines in $SAMPFILE"
    exit
fi

INDIR=genomes
OUTDIR=annotation
SBTTEMPLATE=lib/sbt

IFS=, # set the delimiter to be ,
tail -n +2 $SAMPFILE | sed -n ${N}p | while read BASE SPECIES STRAIN BIOPROJECT NCBI_TAXONID BUSCO_LINEAGE PHYLUM SUBPHYLUM CLASS SUBCLASS ORDER FAMILY GENUS SPECIES2 TRANSL_TABLE LOCUS
do
    SPECIESNOSPACE=$(echo -n "$SPECIES $STRAIN" | perl -p -e 's/\s+/_/g')
    GENOME=$INDIR/$SPECIESNOSPACE.masked.fasta
    MITO=$INDIR/$SPECIESNOSPACE.mito.fasta
    SBT=$SBTTEMPLATE/$SPECIESNOSPACE.sbt
    if [ ! -f $SBT ]; then
        echo "no SBT file $SBT"
        exit
    fi
    echo "$BASE"
    module load funannotate
    export FUNANNOTATE_DB=/bigdata/stajichlab/shared/lib/funannotate_db

    ANTISMASH=$OUTDIR/$BASE/antismash_local/$SPECIESNOSPACE.gbk
    ARGS=()
    if [[ -d $(dirname $ANTISMASH) && -s $ANTISMASH ]]; then
	ARGS+=(--antismash $ANTISMASH)
    fi 
    if [ -s $MITO  ]; then
	ARGS+=(--mito $MITO)
    fi
    funannotate annotate -i $OUTDIR/$BASE --cpus $CPUS --tmpdir $SCRATCH  \
		--species "$SPECIES" --strain "$STRAIN" --sbt $SBT \
		-o $OUTDIR/$BASE --busco_db ${BUSCO_LINEAGE}_odb10 --rename $LOCUS \
		"${ARGS[@]}"
done


