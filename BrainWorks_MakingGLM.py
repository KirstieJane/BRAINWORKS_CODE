#!/usr/bin/env python

import os

def create_files(name, EVs):
    mat_file = name + '.mat'    
    with open(mat_file, 'w') as f:
        f.write('/NumWaves {}\n'.format(len(EVs)))
        f.write('/NumPoints {}\n'.format(len(EVs[0])))
        f.write('\n')
        f.write('/Matrix \n')
        for a in zip(*EVs):
            f.write(' '.join(str(s) for s in a) + '\n')
    
    con_file = name + '.con'
    ftest_file = name + '.fts'

    if len(EVs) == 2:
        with open(con_file, 'w') as f:
            f.write('/NumWaves 2\n')
            f.write('/NumContrasts 2\n')
            f.write('\n')
            f.write('/Matrix \n')
            f.write('1 -1\n')
            f.write('-1 1\n')

    elif len(EVs) == 4:
        with open(con_file, 'w') as f:
            f.write('/NumWaves 4\n')
            f.write('/NumContrasts 4\n')
            f.write('\n')
            f.write('/Matrix \n')
            f.write('1 1 -1 -1\n')
            f.write('1 -1 1 -1\n')
            f.write('1 -1 -1 1\n')
            f.write('-1 1 1 -1\n')
        
        with open(ftest_file, 'w') as f:
            f.write('/NumWaves 4\n')
            f.write('/NumContrasts 3\n')
            f.write('\n')
            f.write('/Matrix \n')
            f.write('1 0 0 0\n')
            f.write('0 1 0 0\n')
            f.write('0 0 1 0\n')

os.chdir('C:\Users\Kirstie\Dropbox\GitHub\BRAINWORKS_CODE')

sublist_file = 'subs_excl325'

with open(sublist_file) as f:
    subs = f.readlines()

subs = [ sub.strip('\n') for sub in subs ]

LL_list = [ '1' if 'A' in sub else '0' for sub in subs ]
SS_list = [ '1' if 'B' in sub else '0' for sub in subs ]
CA_list = [ '1' if sub.endswith('1') else '0' for sub in subs ]
NoCA_list = [ '1' if sub.endswith('2') else '0' for sub in subs ]

LLCA_list = [ int(x) * int(y) for x, y in zip(LL_list, CA_list) ]
LLNoCA_list = [ int(x) * int(y) for x, y in zip(LL_list, NoCA_list) ]
SSCA_list = [ int(x) * int(y) for x, y in zip(SS_list, CA_list) ]
SSNoCA_list = [ int(x) * int(y) for x, y in zip(SS_list, NoCA_list) ]

# Let's make the models that compare ALL the participants

# First, LL vs SS *ignoring* CA
create_files('LLSS', [LL_list, SS_list])

# Then CA vs NoCA ignoring genotype
create_files('CANoCA', [CA_list, NoCA_list])

# Finally the anova
create_files('Anova_AlleleCA', [LLCA_list, LLNoCA_list, SSCA_list, SSNoCA_list])

