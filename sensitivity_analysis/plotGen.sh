#!/bin/bash -l
#SBATCH -N 1
#SBATCH -t 30:00
#SBATCH -q debug
#SBATCH -J DL4N_full_prod
#SBATCH -L SCRATCH,cfs
#SBATCH -C knl
#SBATCH --output logs/%A_%a  # job-array encodding
#SBATCH --image=balewski/ubu20-neuron8:v3
#SBATCH --array 1-1 #a

export OMP_NUM_THREADS=1
module unload craype-hugepages2M

# All paths relative to this, prepend this for full path name
#WORKING_DIR=/global/cscratch1/sd/adisaran/DL4neurons
#OUT_DIR=/global/cfs/cdirs/m2043/adisaran/wrk/
OUT_DIR=/global/homes/k/ktub1999/testRun/
# simu run in the dir where  Slurm job was started

CELLS_FILE='excitatorycells.csv'
START_CELL=0
NCELLS=1
END_CELL=$((${START_CELL}+${NCELLS}))
NSAMPLES=1
NRUNS=1
NSAMPLES_PER_RUN=$(($NSAMPLES/$NRUNS))


echo "CELLS_FILE" ${CELLS_FILE}
echo "START_CELL" ${START_CELL}
echo "NCELLS" ${NCELLS}
echo "END_CELL" ${END_CELL}

export THREADS_PER_NODE=1

# to prevent: H5-write error: unable to lock file, errno = 524
export HDF5_USE_FILE_LOCKING=FALSE

# Create all outdirs
echo "Making outdirs at" `date`
arrIdx=${SLURM_ARRAY_TASK_ID}
jobId=${SLURM_ARRAY_JOB_ID}_${arrIdx}
RUNDIR=${OUT_DIR}/runs2/${jobId}
mkdir -p $RUNDIR
# for i in $(seq $((${START_CELL}+1)) ${END_CELL});
# do
#     line=$(head -$i ${CELLS_FILE} | tail -1)
#     bbp_name=$(echo $line | awk -F "," '{print $1}')
#     for k in {0..4}
#     do
#         mkdir -p $RUNDIR/$bbp_name/c${k}
#         chmod a+rx $RUNDIR/$bbp_name/c${k}
#     done
# done


for i in $(seq $((${START_CELL}+1)) ${END_CELL});
do
    line=$(head -$i ${CELLS_FILE} | tail -1)
    bbp_name=$(echo $line | awk -F "," '{print $1}')
    for STIM_MUL in 0.7 0.9 1.1 1.3
    do
            
            for STIM_OFFSET in -0.3 -0.2 0.1 0 0.1 0.2 0.3
            do
                adjustedval=$STIM_MUL+$STIM_OFFSET
                mkdir -p $RUNDIR/$bbp_name/c${adjustedval}
                chmod a+rx $RUNDIR/$bbp_name/c${adjustedval}

            done
    done
done
cp plotGen.sh $RUNDIR
chmod a+rx $RUNDIR
chmod a+rx $RUNDIR/*
echo done
date

echo "Done making outdirs at" `date`

export stimname1=chaotic3
export stimname2=step_200
export stimname3=ramp
export stimname4=chirp
export stimname5=step_500

stimfile1=stims/${stimname1}.csv
stimfile2=stims/${stimname2}.csv
stimfile3=stims/${stimname3}.csv
stimfile4=stims/${stimname4}.csv
stimfile5=stims/${stimname5}.csv
echo
env | grep SLURM
echo


FILENAME=\{BBP_NAME\}-v3
echo "STIM FILE" $stimfile
echo "SLURM_NODEID" ${SLURM_NODEID}
echo "SLURM_PROCID" ${SLURM_PROCID}

REMOTE_CELLS_FILE='/tmp/excitatorycells.csv'
#sbcast ${CELLS_FILE} ${REMOTE_CELLS_FILE}
REMOTE_CELLS_FILE=${CELLS_FILE}
echo REMOTE_CELLS_FILE $REMOTE_CELLS_FILE



for j in $(seq 1 ${NRUNS});
do
    echo "Doing run $j of $NRUNS at" `date`
    l=1
    for STIM_MUL in 0.7 0.9 1.1 1.3
    do
        
        for STIM_OFFSET in -0.3 -0.2 0.1 0 0.1 0.2 0.3
        do
          
            
            adjustedval=$STIM_MUL+$STIM_OFFSET
            OUT_DIR=$RUNDIR/\{BBP_NAME\}/c${adjustedval}/
            FILE_NAME=${FILENAME}-\{NODEID\}-$j-c${adjustedval}.h5
            OUTFILE=$OUT_DIR/$FILE_NAME
            args="--outfile $OUTFILE --stim-file ${stimfile1} ${stimfile2} ${stimfile3} ${stimfile4} ${stimfile5} --stim-multiplier $STIM_MUL --stim-dc-offset ${STIM_OFFSET} --model BBP --cell-i ${l} \
            --cori-csv ${REMOTE_CELLS_FILE} --cori-start ${START_CELL} --cori-end ${END_CELL} \
            --trivial-parallel --print-every 8 --linear-params-inds 12 17 18\
            --stim-noise --dt 0.1"

            echo "args" $args
            srun --input none -k -n $((${SLURM_NNODES}*${THREADS_PER_NODE})) --ntasks-per-node ${THREADS_PER_NODE} shifter python3 -u run.py $args
            
            
        done
            

    done
    # run.py sets permissions on the data files themselves (doing them here simultaneously takes forever)
    
    echo "Done run $j of $NRUNS at" `date`

done