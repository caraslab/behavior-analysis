function preprocess(directoryname)
%preprocess(directoryname)
%
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
%Within each matrix, stimulus values are dB re:100% depth
%
%Written by ML Caras Jan 29, 2018


%List the files in the folder (each file = animal)
[files,fileIndex] = listFiles(directoryname,'*.mat');
files = files(fileIndex);

%For each file...
for i = 1:numel(files)
    
    %Start fresh
    clear Session
    output = [];
    
    %Load data
    filename=files(i).name;
    data_file=[directoryname,'/',filename];
    load(data_file);
    
    %For each session...
    for j = 1:numel(Session)
       
      %Create trialmat and dprimemat in preparation for psychometric fits  
      output = create_mats(Session,output,j);

    end
    
    %Save the file
    save(data_file,'output','-append')
    
    
    
end


%Create trialmat and dprimemat in preparation for psychometric fitting
function output = create_mats(Session,output,j)

%-------------------------------
%Prepare data
%-------------------------------
%Initialize trial matrix
trialmat = [];

%Stimuli (AM depth in proportion)
stim = [Session(j).Data.AMdepth]';

%Responses (coded via bitmask in Info.Bits)
resp = [Session(j).Data.ResponseCode]';

%Trial type (0 = GO; 1 = NOGO)
ttype = [Session(j).Data.TrialType]';

%Remove reminder trials
rmind = ~logical([Session(j).Data.Reminder]');

stim = stim(rmind);
resp = resp(rmind);
ttype = ttype(rmind);

%Pull out bits for decoding responses
fabit = Session(j).Info.Bits.fa;
hitbit = Session(j).Info.Bits.hit;



%-------------------------------------
%Calculate fa rate
%-------------------------------------
nogo_ind = find(ttype == 1);
stim_val = stim(nogo_ind(1));
nogo_resp = resp(nogo_ind);
n_fa = sum(bitget(nogo_resp,fabit));
n_nogo = numel(nogo_resp);

fa_rate = n_fa/n_nogo;

%Correct floor
if fa_rate <0.05
    fa_rate = 0.05;
end

%Correct ceiling
if fa_rate >0.95
    fa_rate = 0.95;
end

%Adjust number of false alarms to match adjusted fa rate (so we can
%fit data with psignifit later)
n_fa = fa_rate*n_nogo;

%Convert to z score
z_fa = sqrt(2)*erfinv(2*fa_rate-1);

%Append to trialmat
trialmat = [trialmat;stim_val,n_fa,n_nogo];




%-------------------------------------
%Calculate hit rates
%-------------------------------------
go_ind = find(ttype == 0);
go_stim = stim(go_ind);
go_resp = resp(go_ind);

u_go_stim =unique(go_stim);

%For each go stimulus...
for m = 1:numel(u_go_stim)
    
    %Pull out data for just that stimulus
    m_ind = find(go_stim == u_go_stim(m));
    go_resp_m = go_resp(m_ind); %#ok<*FNDSB>
    
    %Calculate the hit rate
    n_hit = sum(bitget(go_resp_m,hitbit));
    n_go = numel(go_resp_m);
    
    hit_rate = n_hit/n_go;
    
    %Adjust floor
    if hit_rate <0.05
        hit_rate = 0.05;
    end
    
    %adjust ceiling
    if hit_rate >0.95
        hit_rate = 0.95;
    end
    
    %Adjust number of hits to match adjusted hit rate (so we can fit
    %data with psignifit later)
    n_hit = hit_rate*n_go;
    
    %Append to trial mat
    trialmat = [trialmat;u_go_stim(m),n_hit,n_go]; %#ok<AGROW>
    
end

%Convert stimulus values to log and sort data so safe stimulus is on top
trialmat(:,1) = make_stim_log(trialmat);
trialmat = sortrows(trialmat,1);

%Calculate dprime
hitrates = trialmat(2:end,2)./trialmat(2:end,3);
z_hit = sqrt(2)*erfinv(2*(hitrates)-1);
dprime = z_hit - z_fa;
dprimemat = [trialmat(2:end,1),dprime];

output(j).trialmat = trialmat;
output(j).dprimemat = dprimemat;

       
       