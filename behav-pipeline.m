
%% 1. MERGE STRUCTURES (OPTIONAL)
%Use this script to merge the data and info structures from two different
%data files. Necessary when program crashes in the middle of testing, and a
%second session is run immediately after crash.

mergestruct

%% 2. COMBINE INDIVIDUAL MAT FILES INTO SINGLE FILE
%This function takes mat files collected with the epsych program and
%combines them into a single file. Use this file to combine data from
%multiple sessions for a single animal into one mat file for easier
%storage, manipulation and analysis.
%
%Note: Combine all the shock training data files into one "training" file,
%and all the psychometric testing data into a separate "testing" file for
%each animal. Thus, in the end, each animal will have two behavioral files
%associated with it. This approach makes it easier to analyze different
%stages of learning separately.

directoryname = '/Users/Melissa/Desktop/NewDataTraining/';

savepath = directoryname;


combinefiles(directoryname,savepath)

%% 3. CREATE TRIALMAT AND DPRIMEMAT IN PREPARATION FOR PSYCHOMETRIC FITTING
%This function goes through each datafile in a directory, and calculates
%hits, misses and dprime values for each behavioral session. Aggregate data
%are compiled into an [1 x M] 'output' structure, where M is equal to the 
%number of behavioral sessions. 'output' has two fields:
%   'trialmat': [N x 3] matrix arranged as follows- 
%       [stimulus value, n_yes_responses, n_trials_delivered]
%
%   'dprimemat': [N x 2] matrix arranged as follows-
%       [stimulus value, dprime]
%
%Within each matrix, stimulus values are dB re:100% depth.

directoryname = 'Enter the data directory path here';


preprocess(directoryname)

%% 4. FIT PSYCHOMETRIC FUNCTIONS 
%Fits behavioral data with psychometric functions using psignifit v4. Fit
%info is saved to a data structure within the file. Fits are created both
%in percent correct space, and in dprime space. 

directoryname = 'Enter the data directory path here';
figuredirectory = 'Enterthe directory path where you want your figures saved here';

plot_pfs_behav(directoryname,figuredirectory)

%% 5. QUALITY CONTROL CHECK
%This function checks files to ensure that there are a sufficient number of
%sessions, that there is no data missing, that the animal ID in the
%file metadata matches the name of the file, and that session dates are in
%the correct order.
%
%Inputs:
%
%   n   The minimum number of sessions required

%Make sure every shock training file has at least n = 3 sessions.
%Make sure every psychometric testing file has at least n = 5 sessions.

directoryname = 'Enter the data directory path here';

n = 1;

qualitycontrol(directoryname,n)



 

