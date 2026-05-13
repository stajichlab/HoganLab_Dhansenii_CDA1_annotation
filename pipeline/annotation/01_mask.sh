#!/usr/bin/bash -l
#SBATCH -p batch -N 1 -c 16 --mem 24gb --out logs/repeatmask.%a.log -a 1,3,5

module load RepeatModeler

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

INDIR=genomes
MASKDIR=analysis/RepeatMasker
SAMPLES=samples.csv
RMLIBFOLDER=lib/repeat_library
FUNGILIB=lib/fungi_repeat.20170127.lib.gz
mkdir -p $RMLIBFOLDER
RMLIBFOLDER=$(realpath $RMLIBFOLDER)
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

IFS=,
tail -n +2 $SAMPLES | sed -n ${N}p | while read BASE SPECIES STRAIN BIOPROJECT NCBI_TAXONID BUSCO_LINEAGE PHYLUM SUBPHYLUM CLASS SUBCLASS ORDER FAMILY GENUS SPECIES2 TRANSL_TABLE LOCUS
do
    mkdir -p $MASKDIR/$BASE
    SPECIESNOSPACE=$(echo -n "$SPECIES $STRAIN" | perl -p -e 's/\s+/_/g')
    GENOME=$(realpath $INDIR)/$BASE.AAFTF.fasta
    if [ ! -s $MASKDIR/$BASE/$BASE.AAFTF.fasta.masked ]; then
	LIBRARY=$RMLIBFOLDER/$BASE.repeatmodeler.lib
	COMBOLIB=$RMLIBFOLDER/$BASE.combined.lib
	if [ ! -f $LIBRARY ]; then
		pushd $MASKDIR/$BASE
		BuildDatabase -name $BASE $GENOME
		RepeatModeler -pa $CPU -database $BASE -LTRStruct
		rsync -a RM_*/consensi.fa.classified $LIBRARY
		rsync -a RM_*/families-classified.stk $RMLIBFOLDER/$BASE.repeatmodeler.stk
		popd
	fi
	if [ ! -s $COMBOLIB ]; then
	    cp $LIBRARY $COMBOLIB
	    zcat $FUNGILIB >> $COMBOLIB
	fi
	if [[ -s $LIBRARY && -s $COMBOLIB ]]; then
	   module load RepeatMasker
	   RepeatMasker -e ncbi -xsmall -s -pa $CPU -lib $COMBOLIB -dir $MASKDIR/$INTERNALID -gff $GENOME
	fi
    	rsync -a $MASKDIR/$INTERNALID/$(basename $GENOME).masked $INDIR/$SPECIESNOSPACE.masked.fasta
    else
	echo "Skipping $INTERNALID as masked file already exists"
   fi
done
