#!/bin/bash -l
#SBATCH -p short -C xeon -N 1 -c 24 -n 1 --mem 16G --out logs/antismash.%a.log -J antismash

module load antismash/7.0.0
hostname
CPU=1
if [ ! -z $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi
OUTDIR=annotation
SAMPFILE=samples.csv
N=${SLURM_ARRAY_TASK_ID}
if [ -z "$N" ]; then
    N=$1
    if [ -z "$N" ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=`wc -l $SAMPFILE | awk '{print $1}'`

if [ "$N" -gt "$MAX" ]; then
    echo "$N is too big, only $MAX lines in $SAMPFILE"
    exit
fi

IFS=,
INPUTFOLDER=predict_results

IFS=, # set the delimiter to be ,
tail -n +2 $SAMPFILE | sed -n ${N}p | while read BASE SPECIES STRAIN BIOPROJECT NCBI_TAXONID BUSCO_LINEAGE PHYLUM SUBPHYLUM CLASS SUBCLASS ORDER FAMILY GENUS SPECIES2 TRANSL_TABLE LOCUS
do
    SPECIESNOSPACE=$(echo -n "$SPECIES $STRAIN" | perl -p -e 's/\s+/_/g')
    GENOME=$INDIR/$SPECIESNOSPACE.masked.fasta

    if [[ ! -d $OUTDIR/$BASE || ! -d $OUTDIR/$BASE/$INPUTFOLDER ]]; then
	    echo "No annotation dir for '$OUTDIR/${BASE}'"
	    exit
    fi
    if [[ ! -d $OUTDIR/$BASE/antismash_local && ! -s $OUTDIR/$BASE/antismash_local/index.html ]]; then
	    antismash --taxon fungi --output-dir $OUTDIR/$BASE/antismash_local  --genefinding-tool none \
	              --clusterhmmer --tigrfam --cb-general --pfam2go --rre --cc-mibig \
		      --cb-subclusters --cb-knownclusters -c $CPU \
	              $OUTDIR/$BASE/$INPUTFOLDER/*.gbk
    else
	echo "folder $OUTDIR/$BASE/antismash_local already exists, skipping."
    fi
done
