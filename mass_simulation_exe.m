function Simu_indicator=mass_simulation_exe(f_path,f_des,f_name,tune_mode,Tune,diary_specs,save_spec)
% This functions does mass simulation.
% users just need to set the parameters they want to tune, the files
% they want to run simulation
%
% Input:
%   1. f_path       : path of files
%   2. f_des        : destination folder to save result
%   3. f_name       : name of file (does not contain .m)
%   4. tune_mode    : 1 for individual tunning
%                     2 for permutated tunning
%                     3 for manual tunning
%   5. Tune         : struct contains names of tunned parameters, and their values
%   6. diary_specs  : specify the diary of the simulation
%                       diary_specs.Enable
%   7. save_spec    : 1 data is saved after simulation
% Output:
%   1. Simu_indicator:  a randomly generated number to distinct
%                       realizations
% NOTES:
%   1. Running this file will clear current workspace, screen, figures,...
%   2. Results are automatically saved to specified folder
%   3. Tuning parameter assignements must not appear on the same line in their code
%   4. There will be files for extract results and plot
%   5. Tunned parameters must be in single column or single row matrices
%
% CAUTION:
%   1. Currently, the tunned names should be single letter (?)
% Example:
% 1/
%   Tune.SNR=1:10;
%   Mass_simulation_exe_func('D:\Matlab','D:\Matlab\Saved','SER_awgn',1,Tune)
% 2/
%   Tune.SNR=1:10;
%   Tune.Nr=2:4;
%   Mass_simulation_exe_func('D:\Matlab','D:\Matlab\Saved','SER_awgn',2,Tune)
% 3/
%   Tune.SNR=[1:5 1:5];
%   Tune.Nr=1:10;
%   Mass_simulation_exe_func('D:\Matlab','D:\Matlab\Saved','SER_awgn',3,Tune)
%
% Last modified: 06-Aug-2020

close all
clc
truerandom

if nargin==6
    save_spec=0;
end

if nargin<6
    diary_specs.Enable=false;
end

if ~strcmp(f_path(end),'\')
    f_path=[f_path '\'];    % add back dash automatically
end

if ~strcmp(f_des(end),'\')
    f_des=[f_des '\'];    % add back dash automatically
end

% to avoid confusion between simulation results, we randomly generate a
% number to indicate the simulation realizations

Simu_indicator=randi([1e6 9e6],1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%% Sets of tuning parameters %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% NOTE: only tuning parameters will be changed, users must care what other
% parameters are, in their file.
% for now, tuning parameters can only be scalar

% convert matrices to cell, if any
S=fieldnames(Tune);
tune_size=zeros(numel(S),1);

for ii=1:numel(S)
    
    if ~iscell(Tune.(S{ii}))
        Tune.(S{ii})= num2cell(Tune.(S{ii}));
    end
    tune_size(ii)=numel(Tune.(S{ii}));
end


tune_explain={'INDIVIDUAL','PERMUTATED','MANUAL'};

switch tune_mode
    case 1
        % In this mode, each parameter will be tuned individually
        % nothing to check here
    case 2
        % In this mode, every possible combination of parameters will be
        % simulated
        % nothing to check here
    case 3
        % This mode is similar to permutated tuning,
        % except that only combinations specified by user will be simulated
        if any(tune_size~=tune_size(1))
            error('Numbers of parameters have to be the same in manual mode')
        end
    otherwise
        error('Tunning mode is not set')
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% <--- FROM THIS LINE, DO NOT EDIT

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%% Modify the main execution file %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

file_org=fileread([f_path f_name '.m']);    % read the original content

% Since files usually contain clear and plot commands, we need to create
% a replica of this file without these commands
% the replica is a function without any output
% any result will be saved to disk

if 1 %                                                                     <--- DO NOT EDIT
    % STEP 0: clear all multiple spaces and change special characters (\,%)
    % WARNING: IT WILL CLEAR ALL MULTIPLE SPACES IN EVERY STRING
    %          IT WILL AFFECT INDENTS AS WELL
    
    file_clc=regexprep(file_org,' +',' ');
    
    file_clc=regexprep(file_clc,'%+','%%');
    
    file_clc=strrep(file_clc,'\','\\');
    
    
    % STEP 1: clear all clear commands
    clear_cmd={'clear all', 'clc', 'close all', 'clearvars'};
    
    for ii=1:numel(clear_cmd)
        file_clc=strrep(file_clc,clear_cmd{ii},'');
    end
    
    
    % STEP 2: clear all plot commands
    plot_cmd_vary={'figure','subplot', 'semilog', 'plot', 'scatter', 'legend',...
        'title', 'xlim', 'ylim', 'axes', 'xlabel', 'ylabel'};
    
    for ii=1:numel(plot_cmd_vary)
        file_clc=regexprep(file_clc,[plot_cmd_vary{ii} '.*\(.*\)'],'','dotexceptnewline');
    end
    
    plot_cmd_exact={'figure', 'hold on', 'hold off', 'grid on', 'grid off'};
    
    for ii=1:numel(plot_cmd_exact)
        file_clc=strrep(file_clc,plot_cmd_exact{ii},'');
    end
    
    
    % STEP 3: deal with multiple-line commands
        % currently not support
        
    % STEP 4: Printf warning if anything calls pwd
    if contains(file_clc,'pwd')
        warning('PWD DETECTED, BE EXTREMELY CAREFUL WHILE USING THIS COMMAND IN THIS CODE')
    end
    
end

%                                                                          <--- FOR INDIVIDUAL TUNING, DO NOT EDIT
if tune_mode==1
    S=fieldnames(Tune);
    
    for ii=1:numel(S)
        
        tuned_name=S{ii};
        tuned_name_hashed=DataHash(tuned_name);
        tuned_name_hashed=tuned_name_hashed(1:6);
        
        %%%%%%% Create the replica %%%%%%%%%%
        rep_name=[f_name '_rep_' tuned_name_hashed];
        fileID_rep = fopen([f_path rep_name '.m'], 'wt'); % create the replica
        str_1st=['function ' rep_name '(' tuned_name ',tuned_ind,save_path)'];
        
        % Eliminate the line that define the tuning parameter in the file
        Old_line_d=[tuned_name '\b?=\d*.\d*;']; % for 1.3
        Old_line_e=[tuned_name '\b?=\d*e\d*;']; % for 1e3
        
        str_rep=regexprep(file_clc,Old_line_d,' ','dotexceptnewline');
        str_rep=regexprep(str_rep,Old_line_e,' ','dotexceptnewline');
        
        fprintf(fileID_rep,[str_1st '\n']);
        if diary_specs.Enable
            diary_specs.Name=['[save_path' ' '''  f_name '[' tuned_name_hashed '_'' num2str(tuned_ind) ''][log].txt'']'];
            fprintf(fileID_rep,['diary(' diary_specs.Name ');\n']);
        end
        fprintf(fileID_rep,[str_rep '\n']);
        
        %%%%%%% Code to save results %%%%%%%%%%
        if save_spec==1
            save_str=['save([save_path' ' '''  f_name '[' tuned_name_hashed...
                '_'' num2str(tuned_ind) ''].mat''])'];
        else
            save_str='';
        end
        fprintf(fileID_rep,[save_str '\n']);
        
        if diary_specs.Enable
            fprintf(fileID_rep,'diary off \n');
        end
        
        fprintf(fileID_rep,'end');
        fclose(fileID_rep);
    end
end

%                                                                          <--- FOR MANUAL AND PERMUTATED TUNING , DO NOT EDIT
if tune_mode==3 || tune_mode==2
    S=fieldnames(Tune);
    tuned_name=[];
    for ii=1:numel(S)
        tuned_name=[tuned_name '_' S{ii}];
    end
    
    tuned_name_hashed=DataHash(tuned_name);
    tuned_name_hashed=tuned_name_hashed(1:6);
        
    %%%%%%% Create the replica %%%%%%%%%%
    rep_name=[f_name '_rep' tuned_name_hashed];
    fileID_rep = fopen([f_path rep_name '.m'], 'wt'); % create the replica
    str_1st=['function ' rep_name '('];
    for ii=1:numel(S)
        str_1st=[str_1st S{ii} ','];
    end
    
    str_1st=[str_1st 'tuned_ind,save_path)'];
    
    % Eliminate the line that define the tuning parameter in the file
    str_rep=file_clc;
    for ii=1:numel(S)
        Old_line_d=[S{ii} '\b?=\d*.\d*;']; % for 1.3 or 1
        Old_line_e=[S{ii} '\b?=\d*e\d*;']; % for 1e3
        
        str_rep=regexprep(str_rep,Old_line_d,' ','dotexceptnewline');
        str_rep=regexprep(str_rep,Old_line_e,' ','dotexceptnewline');
    end
    
%     tuned_name1=['[' tuned_name(2:end)];  % omit '_', add '['
    
    fprintf(fileID_rep,[str_1st '\n']);
    if diary_specs.Enable
        diary_specs.Name=['[save_path' ' '''  f_name '[' tuned_name_hashed '_'' num2str(tuned_ind) ''][log].txt'']'];
        fprintf(fileID_rep,['diary(' diary_specs.Name ');\n']);
    end
    fprintf(fileID_rep,[str_rep '\n']);

    %%%%%%% Code to save results %%%%%%%%%%
    if save_spec==1
    save_str=['save([save_path' ' '''  f_name '[' tuned_name_hashed...
        '_'' num2str(tuned_ind) ''].mat''])'];
    else
        save_str='';
    end
    fprintf(fileID_rep,[save_str '\n']);
    
    if diary_specs.Enable
        fprintf(fileID_rep,'diary off \n');
    end
    
    fprintf(fileID_rep,'end');
    fclose(fileID_rep);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%% Run the main execution file and save results %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% NOTE: .mat file will have a pretty long formated name
% file names cannot contains the values of tuning parameters, because they
% can be float (0.1)
% Instead, they will contain the indices of this value in the array of
% tuning parameters
% User wishing to load results manually needs to be careful

% make the folder to store save results
fsave_path=[f_des 'Results for ' f_name];
mkdir(fsave_path);

fsave_path=[fsave_path '\'];
TSTART=tic;

fprintf('****************** Start massive simulation in %s mode ******************\n',tune_explain{tune_mode})

%                                                                          <--- FOR INDIVIDUAL TUNING, DO NOT EDIT
if tune_mode==1
    for ii=1:numel(S)
        tuned_name=S{ii};
        tuned_name_hashed=DataHash(tuned_name);
        tuned_name_hashed=tuned_name_hashed(1:6);
        
        rep_name=[f_name '_rep_' tuned_name_hashed];
        tuned_exe=Tune.(tuned_name);
        
        for jj=1:numel(tuned_exe)
            
            tuned_val=cell2mat(tuned_exe(jj));
            exe_save=[fsave_path '[' num2str(Simu_indicator) ']'];
            
            str_exe=[rep_name '(tuned_val,' num2str(jj) ',exe_save);'];
            addpath(f_path)
            
            fprintf('************** Run the simulation for %s = %d **************\n\n',tuned_name,tuned_val)
            
            eval(str_exe)
            
            fprintf('\n************** End the simulation for %s = %d **************\n\n',tuned_name,tuned_val)
        end
    end
end

%                                                                          <--- FOR MANUAL AND PERMUTATED TUNING, DO NOT EDIT
if tune_mode==3 || tune_mode==2
    
    if tune_mode==2
        % modify the Tune variable here
        for ii=1:numel(S)
            Tune.(S{ii})=reshape(Tune.(S{ii}),1,[]); % conver to row
        end
        x=combvec(cell2mat(Tune.(S{1})),cell2mat(Tune.(S{2})));
        try
            for ii=3:numel(S)
                x=combvec(x,cell2mat(Tune.(S{ii})));
            end
        catch
        end
        
        for ii=1:numel(S)
            Tune.(S{ii})=num2cell(x(ii,:)); % assign new values for tuned paramaters
        end
    end
    
    tuned_name=[];
    for ii=1:numel(S)
        tuned_name=[tuned_name '_' S{ii}];
    end
    tuned_name_hashed=DataHash(tuned_name);
    tuned_name_hashed=tuned_name_hashed(1:6);
    
    rep_name=[f_name '_rep' tuned_name_hashed];
    
    tuned_exe=Tune.(S{1});
    str_exe=[rep_name '('];
    
    for ii=1:numel(S)
        str_exe=[str_exe 'tuned_val(' num2str(ii) '),'];
    end
    
    str_exe=[str_exe 'tune_ind,exe_save);'];
    
    for jj=1:numel(tuned_exe)
        exe_save=[fsave_path '[' num2str(Simu_indicator) ']'];
        
        tune_ind=jj;
        
        tuned_val=zeros(1,numel(S));
        for ii=1:numel(S)
            tune_dump=cell2mat(Tune.(S{ii}));
            tuned_val(ii)=tune_dump(jj);
        end
        
        addpath(f_path)
        
        fprintf('************** Run the simulation for ')
        for ii=1:numel(S)
            tune_dump=cell2mat(Tune.(S{ii}));
            if ii>1
                fprintf(', %s = %d',S{ii},tune_dump(jj))
            else
                fprintf('%s = %d',S{ii},tune_dump(jj))
            end
        end
        
        fprintf(' **************\n\n')
%         str_exe
        eval(str_exe)
        
        fprintf('************** End the simulation for ')
        for ii=1:numel(S)
            tune_dump=cell2mat(Tune.(S{ii}));
            if ii>1
                fprintf(', %s = %d',S{ii},tune_dump(jj))
            else
                fprintf('%s = %d',S{ii},tune_dump(jj))
            end
        end
        
        fprintf(' **************\n\n')
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%% Print some statistics %%%%%%%%%%%%%%%%%%%%%%%%%%%% <--- PRINT STATISTICS, CAN EDIT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
fprintf('** Tunning mode is %s\n',tune_explain{tune_mode})
fprintf('** Simulation indicator number is %d\n', Simu_indicator)
fprintf('** Diary enable is %d, Save option is %d\n', diary_specs.Enable, save_spec)
fprintf('Elapsed time is %f\n',toc(TSTART))
fprintf('\n************** End of massive simulation\n')

% Save the configurations for further read and plot results
save([fsave_path '[' num2str(Simu_indicator) '][' f_name '][Config_TM_' num2str(tune_mode) '].mat'])