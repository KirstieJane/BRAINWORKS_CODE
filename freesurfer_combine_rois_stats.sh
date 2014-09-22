#!/bin/bash

#==============================================================================
# Combine stats measures of surface parcellations and segmentations for
# BRAINWORKS MPRAGE and DTI data for all subjects
# Created by Kirstie Whitaker
# Contact kw401@cam.ac.uk
#==============================================================================

#==============================================================================
# USAGE: freesurfer_combine_rois_stats.sh <data_dir>
#==============================================================================
function usage {

    echo "USAGE: freesurfer_combine_rois_stats.sh <data_dir>"
    echo "Note that data dir expects to find SUB_DATA within it"
    echo "and then the standard Brainworks directory structure"
    echo ""
    echo "DESCRIPTION: This code looks for the output of freesurfer_extract_rois.sh"
    echo "in each subject's directory and then combines that information together"
    echo "in the FS_ROIS folder within DATA_DIR"
    exit
}

#=============================================================================
# READ IN COMMAND LINE ARGUMENTS
#=============================================================================

data_dir=$1

if [[ ! -d ${data_dir} ]]; then
    usage
fi

    
#=============================================================================
# GET STARTED
#=============================================================================

mkdir -p ${data_dir}/FS_ROIS/

#=============================================================================
# SEGMENTATIONS
#=============================================================================
# Loop through the various segmentations
for seg in aseg wmparc lobesStrict ; do

    for measure in FA MD MO L1 L23 sse; do
    
        # Find all the individual stats files for that segmentation
        inputs=(`ls -d ${data_dir}/SUB_DATA/*/MPRAGE/SURF/stats/*/*/${measure}_${seg}.stats 2> /dev/null `)

        if [[ ${#inputs[@]} -gt 0 ]]; then

            # Write out the mean value for the measure
            asegstats2table --inputs ${inputs[@]} \
                            -t ${data_dir}/FS_ROIS/${dti_scan}/SEG_${measure}_${seg}_mean_temp.csv \
                            -d comma \
                            --common-segs \
                            --meas mean
                        
            # Create the sub_id column:
            echo "sub_id,scan_size,scan_number" > ${data_dir}/FS_ROIS/sub_id_col
            for sub in ${inputs[@]}; do
                sub=${sub/${data_dir}/}
                dti_scan=${sub/${sub:0:35}/}
                scan_size=${dti_scan%%/*}
                scan_number=${dti_scan%/*}
                scan_number=${scan_number#*/}
                echo ${sub:10:3},${scan_size},${scan_number} >> ${data_dir}/FS_ROIS/sub_id_col
            done
        
            # Now paste the data together
            paste -d , ${data_dir}/FS_ROIS/sub_id_col \
                        ${data_dir}/FS_ROIS/SEG_${measure}_${seg}_mean_temp.csv \
                            > ${data_dir}/FS_ROIS/SEG_${measure}_${seg}_mean.csv

            # And replace all '-' with '_' because statsmodels in python
            # likes that more :P
            sed -i "s/-/_/g" ${data_dir}/FS_ROIS/SEG_${measure}_${seg}_mean.csv
            sed -i "s/_0/-0/g" ${data_dir}/FS_ROIS/SEG_${measure}_${seg}_mean.csv
            sed -i "s/://g" ${data_dir}/FS_ROIS/SEG_${measure}_${seg}_mean.csv
                                    
            # Remove the temporary files
            rm ${data_dir}/FS_ROIS/*temp.csv
            rm ${data_dir}/FS_ROIS/sub_id_col
        
        else
            echo "    No input files for ${measure}_${seg}!"
        fi
    done
done

#=============================================================================
# PARCELLATIONS
#=============================================================================
# Loop through the various parcellations

subjects=(`ls -d ${data_dir}/SUB_DATA/*/MPRAGE/SURF/ 2> /dev/null`)

for parc in aparc 500.aparc lobesStrict; do

    for measure in area volume thickness meancurv gauscurv foldind curvind; do
    
        for hemi in lh rh; do
        
            # Combine stats for all subjects for each measure and for each 
            # hemisphere separately
            aparcstats2table --hemi ${hemi} \
                                --subjects ${subjects[@]} \
                                --parc ${parc} \
                                --meas ${measure} \
                                -d comma \
                                --common-parcs \
                                -t ${data_dir}/FS_ROIS/PARC_${parc}_${measure}_${hemi}_temptemp.csv 
                                
            # Drop the first column because it isn't necessary
            cut -d, -f2- ${data_dir}/FS_ROIS/PARC_${parc}_${measure}_${hemi}_temptemp.csv \
                    > ${data_dir}/FS_ROIS/PARC_${parc}_${measure}_${hemi}_temp.csv 
           
        done
        
        # Create the sub_id column:
        echo "sub_id" > ${data_dir}/FS_ROIS/sub_id_col
        for sub in ${subjects[@]}; do
            sub=${sub/${data_dir}/}
            echo ${sub:10:3} >> ${data_dir}/FS_ROIS/sub_id_col
        done
        
        # Now paste the data together
        paste -d , ${data_dir}/FS_ROIS/sub_id_col \
                ${data_dir}/FS_ROIS/PARC_${parc}_${measure}_lh_temp.csv \
                ${data_dir}/FS_ROIS/PARC_${parc}_${measure}_rh_temp.csv \
                    > ${data_dir}/FS_ROIS/PARC_${parc}_${measure}.csv
        
        # And replace all '-' with '_' because statsmodels in python
        # likes that more :P
        sed -i "s/-/_/g" ${data_dir}/FS_ROIS/PARC_${parc}_${measure}.csv
        sed -i "s/_0/-0/g" ${data_dir}/FS_ROIS/PARC_${parc}_${measure}.csv
        sed -i "s/://g" ${data_dir}/FS_ROIS/PARC_${parc}_${measure}.csv
                                
        # Remove the temporary files
        rm ${data_dir}/FS_ROIS/*temp.csv
        rm ${data_dir}/FS_ROIS/sub_id_col

    done
done


