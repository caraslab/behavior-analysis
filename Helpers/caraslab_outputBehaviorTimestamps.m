function caraslab_outputBehaviorTimestamps(Behaviordir, Ephysdir, recording_format)
    % This function extracts behavioral timestamps of relevance for ephys
    % analyses. It searches within the processed ephys folder (Ephysdir) for information
    % about the behavioral session contained in the .info file generated by the
    % TDT system.
    % Inputs:
    % Behaviordir: path to ePsych behavior files
    % Ephysdir: path to processed (NOT TANK) ephys folder
    % recording_format: 'synapse' or 'intan'; important for TTL formatting
    
    % Outputs:
    %   *_spoutTimestamps.csv: All spout events containing onset and onset
    %       times
    %   *_trialInfo.csv: All trial events generated by the TDT system but with
    %       a bit more processing to bit-unmask the response variables.
    % Written by M Macedo-Lima November, 2020

    fprintf('\nProcessing behavioral timestamps (spout and trial info)...\n')

    %List the files in the folder (each file = one session)
    [files,fileIndex] = listFiles(Behaviordir,'*.mat');
    files = files(fileIndex);
    ephysfolders = caraslab_lsdir(Ephysdir);
    ephysfolders = {ephysfolders.name};

    % Empty folder. Not psychometric testing
    if isempty(files)
        return
    end


     %Load in behavior file
    % Catch error if -mat file is not found
    try
        fprintf('----------\nLoading behavioral -mat file: %s.......\n----------\n', files.name)
        load(fullfile(files.folder, files.name));
    catch ME
        if strcmp(ME.identifier, 'MATLAB:load:couldNotReadFile')
%             fprintf('\n-mat file not found\n')
            return
        else
            fprintf(ME.identifier)
            fprintf(ME.message)
            return
        end
    end


        switch recording_format
            %% Synapse recording
            case 'synapse'
                % File matching to ephys info
                for ephys_folder_idx = 1:numel(ephysfolders)
                    cur_path.name = ephysfolders{ephys_folder_idx};
                    cur_savedir = fullfile(Ephysdir, cur_path.name);

                    %Load in info file
                    % Catch error if -mat file is not found
                    try
                        load(fullfile(cur_savedir, [cur_path.name '.info']), '-mat');
                    catch ME
                        if strcmp(ME.identifier, 'MATLAB:load:couldNotReadFile')
                            fprintf('\n-mat file not found\n')
                            continue
                        else
                            fprintf(ME.identifier)
                            fprintf(ME.message)
                            continue
                        end
                    end

                    % In case this folder is still absent
                    mkdir(fullfile(cur_savedir, 'CSV files'));

                    % Match current folder with behavioral session by blockname
                    folder_block = epData.info.blockname;
                    cur_session = [];
                    found_session_flag = 0;
                    for session_idx=1:numel(Session)

                        try
                            session_block = Session(session_idx).Info.ephys.block;
                        catch ME
                            if strcmp(ME.message, 'Reference to non-existent field ''ephys''.')
                                % This error appears when the file used for behavior is
                                % the recovered file from matlab crash files
                                % Variables have different names
                                session_block = Session(session_idx).Info.Subject.ephys.block;

                            else
                                rethrow(ME);
                            end
                        end

                        if strcmp(folder_block, session_block)
                            cur_session = Session(session_idx);
                            found_session_flag = 1;
                            break
                        end
                    end
                    if ~found_session_flag
                        continue
                    end
                    % Skip empty Session
                    if numel(cur_session.Data) == 1
                        continue
                    end
                    subj_id = cur_session.Info.Name;

                    session_id = epData.info.blockname;

                    %% Output spout onset-offset timestamps
                    spout_onsets = epData.epocs.Spou.onset;
                    spout_offsets = epData.epocs.Spou.offset;

                    fileID = fopen(fullfile(cur_savedir, 'CSV files', ...
                        [subj_id '_' session_id '_spoutTimestamps.csv']), 'w');

                    header = {'Subj_id', 'Session_id', 'Spout_onset', 'Spout_offset'};
                    fprintf(fileID,'%s,%s,%s,%s\n', header{:});
                    nrows = length(spout_onsets);
                    for idx = 1:nrows
                        output_cell = {subj_id, session_id, spout_onsets(idx), spout_offsets(idx)};

                        fprintf(fileID,'%s,%s,%d,%d\n', output_cell{:});
                    end
                    fclose(fileID);
                    %% Output trial parameters
                    % Combine the ephys-timelocked timestamps with the 
                    % session info from ePsych; also translate the response code bitmask
                    session_data = struct2table(cur_session.Data);

                    % Sometimes the recording ends before a trial is completed and the offset 
                    % value will be Inf. I'll add this checkpoint here to account for that
                    try
                        temp_offset = epData.epocs.TTyp.offset;
                        offset_inf = isinf(temp_offset);
                        session_data.Trial_onset = epData.epocs.TTyp.onset(~offset_inf);
                        session_data.Trial_offset = epData.epocs.TTyp.offset(~offset_inf);
                    catch ME
                        % Sometimes the above doesn't work. Not sure why but epData ends up
                        % with 1 more element than cur_session. Let's cut the last one for
                        % now
                        if strcmp(ME.identifier, 'MATLAB:table:RowDimensionMismatch')
                            session_data.Trial_onset = epData.epocs.TTyp.onset(1:size(session_data,1));
                            session_data.Trial_offset = epData.epocs.TTyp.offset(1:size(session_data,1));
                        end
                    end

                    session_data.Subj_id = repmat([subj_id], size(session_data, 1), 1);
                    session_data.Session_id = repmat([session_id], size(session_data, 1), 1);
                    % Unmask the bitmask    
                    response_code_bits = cur_session.Info.Bits;
                    session_data.Hit = bitget(session_data.ResponseCode, response_code_bits.hit);
                    session_data.Miss = bitget(session_data.ResponseCode, response_code_bits.miss);
                    session_data.CR = bitget(session_data.ResponseCode, response_code_bits.cr);
                    session_data.FA = bitget(session_data.ResponseCode, response_code_bits.fa);
                    
                    writetable(session_data, fullfile(cur_savedir, 'CSV files', ...
                        [subj_id '_' session_id '_trialInfo.csv']));

                    % Output the entire ePsych Info field as metadata
                    Info = cur_session.Info;
                    save(fullfile(cur_savedir, 'CSV files', ...
                        [subj_id '_' session_id '_ePsychMetadata']), 'Info', '-v7.3');
                end

            
            %% Intan recording
            case 'intan'
                % Find recording closest in time to the ePsych files
                % The downside of this is there is a risk of matching the
                % wrong behavior with ephys if you have a single behavior
                % file in the folder which happens to be the wrong one. In
                % other words, it is not fool-proof
                distance_matrix = Inf(length(ephysfolders), length(Session));
                %  Loop through all folders first to find the distances
                for ephys_folder_idx = 1:numel(ephysfolders)
                    cur_path.name = ephysfolders{ephys_folder_idx};
                    cur_savedir = fullfile(Ephysdir, cur_path.name);

                    %Load in info file
                    % Catch error if -mat file is not found
                    try
                        load(fullfile(cur_savedir, [cur_path.name '.info']), '-mat');
                    catch ME
                        if strcmp(ME.identifier, 'MATLAB:load:couldNotReadFile')
                            fprintf('info file not found for: %s\n', cur_path.name)
                            continue
                        else
                            fprintf(ME.identifier)
                            fprintf(ME.message)
                            continue
                        end
                    end

                    folder_block = epData.info.blockname;
                    cur_session = [];
                    for session_idx=1:numel(Session)
                        behavior_timestamp = Session(session_idx).Info.StartTime;
                        behavior_timestamp = datenum(behavior_timestamp);

                        ephys_timestamp = epData.info.StartTime;
                        ephys_timestamp = datenum(ephys_timestamp);


                        time_difference = abs(behavior_timestamp - ephys_timestamp);
                        
                        distance_matrix(ephys_folder_idx, session_idx) = time_difference;
                    end
                end
                
                % Now loop through all folders again using the distances
                for session_idx = 1:numel(Session)
                    [~, closest_ephys_idx] = min(distance_matrix(:, session_idx));
                    cur_path.name = ephysfolders{closest_ephys_idx};
                    cur_savedir = fullfile(Ephysdir, cur_path.name);

                    %Load in info file
                    % Catch error if -mat file is not found
                    try
                        load(fullfile(cur_savedir, [cur_path.name '.info']), '-mat');
                    catch ME
                        if strcmp(ME.identifier, 'MATLAB:load:couldNotReadFile')
                            fprintf('\n-mat file not found\n')
                            continue
                        else
                            fprintf(ME.identifier)
                            fprintf(ME.message)
                            continue
                        end
                    end
                    
                    cur_session = Session(session_idx);
                    
                    % Skip empty Session
                    if numel(cur_session.Data) == 1
                        continue
                    end
                    
                    % In case this folder is still absent
                    mkdir(fullfile(cur_savedir, 'CSV files'));

                    subj_id = cur_session.Info.Name;

                    session_id = epData.info.blockname;
                    
                    %% Output DAC codes
                    % Event IDs:
                        % 0: DAC1 = sound on/off
                        % 1: DAC2 = spout on/off
                        % 2: DAC3 = trial start/end
                    %% Output spout onset-offset timestamps
                    spout_events = epData.event_ids == 1;
                    all_spout_timestamps = epData.timestamps(spout_events);
                    
                    if sum(spout_events) > 0
                        spout_event_states = epData.event_states(spout_events);
                        spout_onset_events = spout_event_states == 1;
                        spout_offset_events = spout_event_states == 0;

                        spout_onset_timestamps = all_spout_timestamps(spout_onset_events);
                        spout_offset_timestamps = all_spout_timestamps(spout_offset_events);

                        % Remove first offset if lower than first onset because
                        % recording started while animal was already on spout
                        if spout_offset_timestamps(1) < spout_onset_timestamps(1)
                            spout_offset_timestamps = spout_offset_timestamps(2:end);
                        end

                        % Remove last onset if there is no matching offset
                        if length(spout_onset_timestamps) > length(spout_offset_timestamps)
                            spout_onset_timestamps = spout_onset_timestamps(1:end-1);
                        end

                        fileID = fopen(fullfile(cur_savedir, 'CSV files', ...
                            [subj_id '_' session_id '_spoutTimestamps.csv']), 'w');

                        header = {'Subj_id', 'Session_id', 'Spout_onset', 'Spout_offset'};
                        fprintf(fileID,'%s,%s,%s,%s\n', header{:});
                        nrows = length(spout_onset_timestamps);
                        for idx = 1:nrows
                            output_cell = {subj_id, session_id, spout_onset_timestamps(idx), spout_offset_timestamps(idx)};

                            fprintf(fileID,'%s,%s,%d,%d\n', output_cell{:});
                        end
                        fclose(fileID);
                    else
                        fprintf('No spout events for: %s\n', cur_path.name)
                    end
                    
                    %% Output modulated sound onset-offset timestamps
                    % Note: In some recordings I only recorded the
                    % onset/offset of modulated noise (and not the trials)
                    % The problem is I couldn't find a good spot to collect
                    % an AM noise flag, so sometimes the onset time is off.
                    % The offset time seems more accurate
                    % As a fix, find the first amplitude modulated noise
                    % offset and match with behavioral file to extrapolate
                    % trial onset/offsets
                    
                    % Note 2: DO NOT use this as a reliable timestamp. I
                    % couldn't find a good spot to collect these precisely
                    % yet. Trial onset/offset (DAC3) are much more reliable
                    sound_events = epData.event_ids == 0;
                    all_sound_timestamps = epData.timestamps(sound_events);
                    
                    sound_event_states = epData.event_states(sound_events);
                    sound_onset_events = sound_event_states == 1;
                    sound_offset_events = sound_event_states == 0;
                    
                    
                    sound_onset_timestamps = all_sound_timestamps(sound_onset_events);
                    sound_offset_timestamps = all_sound_timestamps(sound_offset_events);
                    
                    fileID = fopen(fullfile(cur_savedir, 'CSV files', ...
                        [subj_id '_' session_id '_AMsoundTimestamps.csv']), 'w');

                    header = {'Subj_id', 'Session_id', 'Sound_onset', 'Sound_offset'};
                    fprintf(fileID,'%s,%s,%s,%s\n', header{:});
                    nrows = length(sound_onset_timestamps);
                    for idx = 1:nrows
                        output_cell = {subj_id, session_id, sound_onset_timestamps(idx), sound_offset_timestamps(idx)};

                        fprintf(fileID,'%s,%s,%d,%d\n', output_cell{:});
                    end
                    fclose(fileID);
                    
                    %% Output trial parameters
                    % Combine the ephys-timelocked timestamps with the 
                    % session info from ePsych; also translate the response code bitmask
                    session_data = struct2table(cur_session.Data);

                    trial_events = epData.event_ids == 2;
                    all_trial_events_timestamps = epData.timestamps(trial_events);
                    % Check if this recording happened before I started
                    % collecting trial events
                    % If this is the case, use first sound offset to
                    % extrapolate all other times
                    if sum(trial_events) > 0
                        trial_event_states = epData.event_states(trial_events);
                        trial_onset_events = trial_event_states == 1;
                        trial_offset_events = trial_event_states == 0;
                        
                        try
                            
                            session_data.Trial_onset = all_trial_events_timestamps(trial_onset_events);
                            session_data.Trial_offset = all_trial_events_timestamps(trial_offset_events);
                        catch ME
                            if strcmp(ME.identifier, 'MATLAB:table:RowDimensionMismatch')
                                fprintf('Trial number mismatch between ePsych and intan system for: %s\n', cur_path.name)
                                fprintf('Deleting last TTL pulse but crossreference CSV files to make sure this is accurate');
                                temp_onset = all_trial_events_timestamps(trial_onset_events);
                                temp_offset = all_trial_events_timestamps(trial_offset_events);       
                                
                                session_data.Trial_onset = temp_onset(1:end-1);
                                session_data.Trial_offset = temp_offset(1:end-1);
                            end
                        end
                    else
                        first_go_trial_offset = sound_offset_timestamps(1);
                        % First GO offset TTL should roughly match with first
                        % onset + 1 second
                        first_go_trial_onset = first_go_trial_offset - 1;
                        
                        go_trial_data = session_data(session_data.TrialType == 0, :);
                        
                        
                        first_go_trial_onset_timestamp = datenum(go_trial_data.ComputerTimestamp(1,4:end));
                        all_computer_timestamps_seconds = datenum(session_data.ComputerTimestamp(:,4:end));
                        
                        distances_from_first_go_trial_onset = all_computer_timestamps_seconds - first_go_trial_onset_timestamp;

                        session_data.Trial_onset = distances_from_first_go_trial_onset + first_go_trial_onset;
                        session_data.Trial_offset = session_data.Trial_onset + 1;
                    end
                    session_data.Subj_id = repmat([subj_id], size(session_data, 1), 1);
                    session_data.Session_id = repmat([session_id], size(session_data, 1), 1);
                    % Unmask the bitmask    
                    response_code_bits = cur_session.Info.Bits;
                    session_data.Hit = bitget(session_data.ResponseCode, response_code_bits.hit);
                    session_data.Miss = bitget(session_data.ResponseCode, response_code_bits.miss);
                    session_data.CR = bitget(session_data.ResponseCode, response_code_bits.cr);
                    session_data.FA = bitget(session_data.ResponseCode, response_code_bits.fa);
                    
                    writetable(session_data, fullfile(cur_savedir, 'CSV files', ...
                        [subj_id '_' session_id '_trialInfo.csv']));

                    % Output the entire ePsych Info field as metadata
                    Info = cur_session.Info;
                    save(fullfile(cur_savedir, 'CSV files', ...
                        [subj_id '_' session_id '_ePsychMetadata']), 'Info', '-v7.3');

                end
        end

            %% TODO: output opto timestamps here when needed

end