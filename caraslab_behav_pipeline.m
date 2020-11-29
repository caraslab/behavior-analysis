% caraslab_behavior_pipeline.m
% This pipeline takes ePsych .mat behavioral files, combines and analyzes them and
% outputs files ready for further behavioral analyses and for aligning
% timestamps with neural recordings
% Author ML Caras

% In this patched version, this pipeline also incorporates ephys recordings
% in the processing to extract timestamps related to spout and stimulus
% delivery
% Author: M Macedo-Lima
% November, 2020

%% Set your paths
% Ephysdir: Where your processed ephys recordings are. No need to declare this
%   variable if you are not interested in or don't have ephys

% Behaviordir: Where the ePsych behavior files are; -mat files will be
%   combined into a single file. Before running this, group similar sessions
%   into folders named: 
%   shock_training, psych_testing, pre_passive, post_passive

% sel: whether you want to run all or a subset of the folders. If 1, you
%   will be prompted to select folders. Multiple folders can be selected
%   using Ctrl or Shift
% 
% Ephysdir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-13-200125-124647';  
% Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-13';

Ephysdir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-14-200126-125925';  
Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-14';
% 
% Ephysdir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-26-200614-103221';  
% Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-26';

% Ephysdir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-27-200614-104657';  
% Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-27';
% 
% Ephysdir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/Matt/Sorted/SUBJ-ID-28-200615-141009';  
% Behaviordir = '/mnt/132bfc10-ead6-48da-986e-007a5a3d1d87/matlab_data_files/SUBJ-ID-28';

sel = 1;  % Select subfolders; 0 will run all subfolders

if ~sel
    datafolders = caraslab_lsdir(Behaviordir);
    datafolders = {datafolders.name};

elseif sel  
    %Prompt user to select folder
    % uigetfile_n_dir copied from here:
    % https://www.mathworks.com/matlabcentral/fileexchange/32555-uigetfile_n_dir-select-multiple-files-and-directories
    datafolders_names = uigetfile_n_dir(Behaviordir,'Select data directory');  % 
    datafolders = {};
    for i=1:length(datafolders_names)
        [~, datafolders{end+1}, ~] = fileparts(datafolders_names{i});
    end
end


%For each data folder...
for i = 1:numel(datafolders)
    cur_savedir = fullfile(Ephysdir, 'Behavior', datafolders{i});
    cur_sourcedir = fullfile(Behaviordir, datafolders{i});
    mkdir(cur_savedir);
    
    %% 1. MERGE STRUCTURES (OPTIONAL)
    %Use this script to merge the data and info structures from two different
    %data files. Necessary when program crashes in the middle of testing, and a
    %second session is run immediately after crash.

    % Not implemented for current patch

    % mergestruct
    
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
    
    caraslab_combinefiles(cur_sourcedir,cur_savedir)


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
    
    % This function also outputs two csv files with trial performance
    % _allSessions_trialMat.csv: number of stimulus presentations and hits/FAs 
    % _allSessions_dprimeMat.csv: d' by stimulus

    preprocess(cur_savedir)

    %% 4. FIT PSYCHOMETRIC FUNCTIONS 
    %Fits behavioral data with psychometric functions using psignifit v4. Fit
    %info is saved to a data structure within the file. Fits are created both
    %in percent correct space, and in dprime space. 
    % In addition to plots, output a csv file with the thresholds by day
    plot_pfs_behav(cur_savedir,cur_savedir)
    
    %% 5. Output timestamps info
    % This function extracts behavioral timestamps of relevance for ephys
    % analyses. It searches within the processed ephys folder (Ephysdir) for information
    % about the behavioral session contained in the .info file generated by the
    % TDT system.
    % Outputs:
    %   *_spoutTimestamps.csv: All spout events containing onset and onset
    %       times
    %   *_trialInfo.csv: All trial events generated by the TDT system but with
    %       a bit more processing to bit-unmask the response variables.
    caraslab_outputBehaviorTimestamps(cur_savedir, Ephysdir)
end

 

