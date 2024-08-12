function convert_floc_data(data_folder)

% convert the files that floc saves into a more typical 
% matlab structure format. this can then also be loaded into python.

% this is wherever your floc code is located. this defines the "session"
% object that you need in order to load the .mat file.
floc_code_folder = '/Users/margarethenderson/Dropbox/CMU/fMRI/localizer_code/fLoc';

addpath(genpath(floc_code_folder));

% data_folder = '/Users/margarethenderson/Dropbox/CMU/fMRI/data_UW_localizers/Session1/KC_04-Jun-2024_stimset6_1back_2runs/KC_04-Jun-2024_stimset6_1back_2runs';
% data_file = 'KC_04-Jun-2024_stimset6_1back_2runs_fLocSession.mat';
data_file = dir(fullfile(data_folder, '*fLocSession.mat'));

for fi = 1:length(data_file)

    fn = fullfile(data_folder, data_file(fi).name);
    
    new_fn = strcat(fn(1:end-4), '_new.mat');
    
    fprintf('loading from %s\n', fn)
    session = load(fn);
    
    session = session.session;
    
    % we're going to take all fields from this "Session" object and make them
    % into identical fields in a regular matlab structure.
    prop_names = properties(session);
    
    p = [];
    
    for pp = 1:length(prop_names)
    
        prop_name = prop_names{pp};
    
        p.(prop_name) = session.(prop_name);
    
    end
    
    % Now doing same thing for the "sequence" object.
    p.sequence = [];
    
    prop_names = properties(session.sequence);
    
    for pp = 1:length(prop_names)
    
        prop_name = prop_names{pp};
    
        p.sequence.(prop_name) = session.sequence.(prop_name);
    
    end
    
    session = p;
    
    fprintf('saving to %s\n', new_fn);
    
    save(new_fn, 'session');

end





