function combinefiles(directoryname,savepath)
%combinefiles(directoryname,savepath)
%
%This function takes mat files collected with the epsych program and
%combines them into a single file. Use this file to combine data from
%multiple sessions for a single animal into one mat file for easier
%storage, manipulation and analysis.
%
%Written by ML Caras Jan 29, 2018


%List folders in the directory (each folder = one animal)
[folders,folderIndex]= findRealDirs(directoryname);
folders = folders(folderIndex);

%For each folder...
for i = 1:numel(folders)
    
    %Start fresh
    clear Session
    
    foldername = [directoryname,folders(i).name];
    
    %List the files in the folder (each file = one session)
    [files,fileIndex] = listFiles(foldername,'*.mat');
    files = files(fileIndex);
    
    %Convert dates to datetime, then character array
    %This is important because if you combined the files in the order
    %they exist within the directory, you might erroneously combine them in
    %the wrong order. The files are stored with abbreviations for the month
    %(Oct, Dec, etc) and are ordered alphabetcially. Thus, if you don't
    %convert the dates to standard datetime format, you might end up with a
    %session collected in Dec listed before a session collected in Oct.
    for j = 1:numel(files)
        files(j).date = char(datetime(files(j).date,'Format','yyyyMMdd'));
    end
    
    %Sort files by date 
    [sortedfiles, ~] = sortStruct(files, 'date');
    
    %For each file...
    for k = 1:numel(sortedfiles)
        
        %Start fresh
        clear temp
        
        %Load data
        filename=sortedfiles(k).name;
        data_file=[foldername,'/',filename];
        temp = load(data_file);
        
        %Save data to data structure
        Session(k).Data = temp.Data;
        Session(k).Info = temp.Info;
    
    end

     
    
    %Save data structure to new file
    e = regexp(filename,'\d\d\d\d\d\d','end');
    savename = [savepath,filename(1:e),'.mat'];
    save(savename,'Session')
end