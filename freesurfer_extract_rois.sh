#!/bin/bash

#==============================================================================
# Extract DTI and MPM measures from freesurfer ROIs
# along with surface parameters from various parcellations
# Created by Kirstie Whitaker
# Contact kw401@cam.ac.uk
#==============================================================================

#==============================================================================
# Define the usage function
#==============================================================================

function usage {

    echo "USAGE: freesurfer_extract_rois.sh <data_dir> <subid>"
    echo "Note that data dir expects to find SUB_DATA within it"
    echo "and then the standard BRAINWORKS directory structure"
    echo ""
    echo "DESCRIPTION: This code will register the DTI B0 file to freesurfer space,"
    echo "apply this registration to the DTI measures in the <dti_dir>/FDT folder,"
    echo "and then create the appropriate <measure>_wmparc.stats and "
    echo "<measure>_aseg.stats files for each subject separately"
    echo "Finally, it will also extract surface stats from the parcellation schemes"
    exit
}

#=============================================================================
# CHECK INPUTS
#=============================================================================
data_dir=$1
sub=$2

# This needs to be in the same directory as this script
# Fine if you download the git repository but not fine 
# if you've only take the script itself!
lobes_ctab=`dirname ${0}`/LobesStrictLUT.txt

if [[ ! -d ${data_dir} ]]; then
    echo "${data_dir} is not a directory, please check"
    print_usage=1
fi

if [[ -z ${sub} ]]; then
    echo "No subject id provided"
    print_usage=1
fi

if [[ ! -f ${lobes_ctab} ]]; then
    echo "Can't find lobes color look up table file"
    echo "Check that LobesStrictLUT.txt is in the same directory"
    echo "as this script"
    print_usage=1
fi

if [[ ${print_usage} == 1 ]]; then 
    usage
fi

#=============================================================================
# START A LOOP OVER DTI SCANS
#=============================================================================

for dti_scan in DTI_64D_1A DTI_64D_iso_1000; do
    for scan_number in 1 2; do

#=============================================================================
# SET A COUPLE OF USEFUL VARIABLES
#=============================================================================
        surfer_dir=${data_dir}/SUB_DATA/${sub}/MPRAGE/SURF/
        dti_dir=${data_dir}/SUB_DATA/${sub}/${dti_scan}/DTI_${scan_number}/
        reg_dir=${data_dir}/SUB_DATA/${sub}/REG/${dti_scan}/DTI_${scan_number}/

        SUBJECTS_DIR=${surfer_dir}/../
        surf_sub=`basename ${surfer_dir}`
        
        if [[ -d ${dti_dir} ]]; then

#=============================================================================
# REGISTER B0 TO FREESURFER SPACE
#=============================================================================
            # The first step is ensuring that the dti_ec (B0) file
            # has been registered to freesurfer space
            if [[ ! -f ${reg_dir}/diffB0_TO_surf.dat ]]; then
                bbregister --s ${surf_sub} \
                           --mov ${dti_dir}/dti_ec.nii.gz \
                           --init-fsl \
                           --reg ${reg_dir}/diffB0_TO_surf.dat \
                           --t2
            fi

    #=============================================================================
    # TRANSFORM DTI MEASURES FILES TO FREESURFER SPACE
    #=============================================================================
            # If the dti measure file doesn't exist yet in the <surfer_dir>/mri folder
            # then you have to make it
            for measure in FA MD MO L1 L23 sse; do
            
                measure_file_dti=`ls -d ${dti_dir}/FDT/*_${measure}.nii.gz 2> /dev/null`
                if [[ ! -f ${measure_file_dti} ]]; then 
                    echo "${measure} file doesn't exist in dti_dir, please check"
                    usage
                fi
                
                # If the measure file has particularly small values
                # then multiply this file by 1000 first
                if [[ "MD L1 L23" =~ ${measure} ]]; then
                    if [[ ! -f ${measure_file_dti/.nii/_mul1000.nii} ]]; then
                        fslmaths ${measure_file_dti} -mul 1000 ${measure_file_dti/.nii/_mul1000.nii}
                    fi
                    measure_file_dti=${measure_file_dti/.nii/_mul1000.nii}
                fi
                
                # Now transform this file to freesurfer space
                if [[ ! -f ${surfer_dir}/mri/${measure}.mgz ]]; then
                    
                    mkdir -p ${surfer_dir}/mri/${dti_scan}/DTI_${scan_number}/
                    
                    echo "    Registering ${measure} file to freesurfer space"
                    mri_vol2vol --mov ${measure_file_dti} \
                                --targ ${surfer_dir}/mri/T1.mgz \
                                --o ${surfer_dir}/mri/${dti_scan}/DTI_${scan_number}/${measure}.mgz \
                                --reg ${reg_dir}/diffB0_TO_surf.dat \
                                --no-save-reg

                else
                    echo "    ${measure} file already in freesurfer space"
                   
                fi
            done
        
#=============================================================================
# EXTRACT THE STATS FROM THE SEGMENTATION FILES
#=============================================================================
# Specifically this will loop through the following segmentations:
#     wmparc
#     aseg
#     lobesStrict
#=============================================================================
  
            for measure in FA MD MO L1 L23 sse; do
                if [[ -f ${surfer_dir}/mri/${measure}.mgz ]]; then

                    #=== wmparc
                    if [[ ! -f ${surfer_dir}/stats/${dti_scan}/DTI_${scan_number}/${measure}_wmparc.stats ]]; then
                        mri_segstats --i ${surfer_dir}/mri/${dti_scan}/DTI_${scan_number}/${measure}.mgz \
                                     --seg ${surfer_dir}/mri/wmparc.mgz \
                                     --ctab ${FREESURFER_HOME}/WMParcStatsLUT.txt \
                                     --sum ${surfer_dir}/stats/${dti_scan}/DTI_${scan_number}/${measure}_wmparc.stats \
                                     --pv ${surfer_dir}/mri/norm.mgz
                    fi
                    
                    #=== aseg
                    if [[ ! -f ${surfer_dir}/stats/${dti_scan}/DTI_${scan_number}/${measure}_aseg.stats ]]; then
                        mri_segstats --i ${surfer_dir}/mri/${dti_scan}/DTI_${scan_number}/${measure}.mgz \
                                     --seg ${surfer_dir}/mri/aseg.mgz \
                                     --sum ${surfer_dir}/stats/${dti_scan}/DTI_${scan_number}/${measure}_aseg.stats \
                                     --pv ${surfer_dir}/mri/norm.mgz \
                                     --ctab ${FREESURFER_HOME}/ASegStatsLUT.txt 
                    fi
                    
                    #=== lobesStrict
                    if [[ ! -f ${surfer_dir}/stats/${dti_scan}/DTI_${scan_number}/${measure}_lobesStrict.stats ]]; then
                        mri_segstats --i ${surfer_dir}/mri/${dti_scan}/DTI_${scan_number}/${measure}.mgz \
                                     --seg ${surfer_dir}/mri/lobes+aseg.mgz \
                                     --sum ${surfer_dir}/stats/${dti_scan}/DTI_${scan_number}/${measure}_lobesStrict.stats \
                                     --pv ${surfer_dir}/mri/norm.mgz \
                                     --ctab ${lobes_ctab}
                    
                    fi
                                    
                else
                    echo "${measure} file not transformed to Freesurfer space"
                fi
            done

#=============================================================================
# CLOSE THE DTI SCAN LOOPS
#=============================================================================
        fi
    done
done
    
#=============================================================================
# EXTRACT THE STATS FROM THE SURFACE PARCELLATION FILES
#=============================================================================
# Specifically this will loop through the following segmentations:
#     aparc
#     500.aparc
#     lobesStrict
#=============================================================================

# Loop over both left and right hemispheres
for hemi in lh rh; do
    # Loop over parcellations
    for parc in aparc 500.aparc lobesStrict; do

        if [[ ! -f ${surfer_dir}/stats/${hemi}.${parc}.stats \
                && -f ${surfer_dir}/label/${hemi}.${parc}.annot ]]; then
            mris_anatomical_stats -a ${surfer_dir}/label/${hemi}.${parc}.annot \
                                    -f ${surfer_dir}/stats/${hemi}.${parc}.stats \
                                    ${surf_sub} \
                                    ${hemi}
        fi
        
    done # Close parcellation loop
done # Close hemi loop

#=============================================================================
# Well done. You're all finished :)
#=============================================================================
