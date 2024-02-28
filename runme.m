function runme()
% function runme(name, trigger, stim_set, num_runs, task_num, start_run)
% Prompts experimenter for session parameters and executes functional
% localizer experiment used to define regions in high-level visual cortex
% selective to faces, places, bodies, and printed characters.
%
% Inputs (optional):
%   1) name -- session-specific identifier (e.g., particpant's initials)
%   2) trigger -- option to trigger scanner (0 = no, 1 = yes)
%   3) stim_set -- stimulus set (1 = standard, 2 = alternate, 3 = both)
%   4) num_runs -- number of runs (stimuli repeat after 2 runs/set)
%   5) task_num -- which task (1 = 1-back, 2 = 2-back, 3 =
%   oddball)
%   6) start_run -- run number to begin with (if sequence is interrupted)
%
% Version 3.0 8/2017
% Anthony Stigliani (astiglia@stanford.edu)
% Department of Psychology, Stanford University

% Modified by MMH in 2024 (mmhender@cmu.edu)


% skipping sync tests for debugging (set to 0 when running real)
Screen('Preference', 'SkipSyncTests', 1);
% Screen('Preference', 'SkipSyncTests', 0);

% clear all; setenv('WAYLAND_DISPLAY'); Screen('Preference','ConserveVRAM', 2^19);

%% add paths and check inputs

addpath('functions');

%% Collect information using a dialog box
% Modified by MMH 2024

prompt = {'Subject Initials',...
        'Trigger scanner? (0 = no, 1 = yes)',...
        'Which stimulus set? (1 = standard, 2 = alternate, 3 = both, 4 = food, 5 = food + scrambled)',...
        'Which task? (1 = 1-back, 2 = 2-back, 3 = oddball)',...
        'How many runs?',...
        'This run number?',...
        'Debug mode? (0=no, 1=yes)'};

dlgtitle = 'Enter Run Parameters';
dims = [1 35];
definput = {'XX','0','4','1','4','1','0'};
answer = inputdlg(prompt,dlgtitle,dims,definput);
name = answer{1};  
trigger = str2double(answer{2});
stim_set = str2double(answer{3});
task_num = str2double(answer{4});
num_runs = str2double(answer{5});
this_run = str2double(answer{6});
debug = str2double(answer{7});

% check values of these entries
if ~ismember(trigger,[0:1]);  error('trigger must be 0 or 1');  end
if ~ismember(stim_set,[1:5]); error('stim_set must be 1-5'); end
if ~ismember(task_num,[1:3]); error('task_num must be 1-3'); end
if ~ismember(this_run,[1:24]); error('this_run must be 1-24'); end
if ~ismember(debug,[0:1]); error('debug must be 0:1'); end

% % session name
% if nargin < 1
%     name = [];
%     while isempty(deblank(name))
%         name = input('Subject initials : ', 's');
%     end
% end
% 
% % option to trigger scanner
% if nargin < 2
%     trigger = -1;
%     while ~ismember(trigger, 0:1)
%         trigger = input('Trigger scanner? (0 = no, 1 = yes) : ');
%     end
% end
% 
% % which stimulus set/s to use
% if nargin < 3
%     stim_set = -1;
% %     while ~ismember(stim_set, 1:3)
% %         stim_set = input('Which stimulus set? (1 = standard, 2 = alternate, 3 = both) : ');
% %     end
%     while ~ismember(stim_set, 1:4)
%         stim_set = input('Which stimulus set? (1 = standard, 2 = alternate, 3 = both, 4 = food) : ');
%     end
% end
% 
% % number of runs to generate
% if nargin < 4
%     num_runs = -1;
%     while ~ismember(num_runs, 1:24)
%         num_runs = input('How many runs? : ');
%     end
% end
% 
% % which task to use
% if nargin < 5
%     task_num = -1;
%     while ~ismember(task_num, 1:3)
%         task_num = input('Which task? (1 = 1-back, 2 = 2-back, 3 = oddball) : ');
%     end
% end
% 
% % which run number to begin executing (default = 1)
% if nargin < 6
%     start_run = 1;
% end


%% initialize session object and execute experiment

% setup fLocSession and save session information
session = fLocSession(name, trigger, stim_set, num_runs, task_num, debug);
session_dir = (fullfile(session.exp_dir, 'data', session.id));
if ~exist(session_dir, 'dir')
    if (this_run~=1); error('check run number; expecting run 1'); end
    mkdir(session_dir); 
end
session_fpath = fullfile(session_dir, [session.id '_fLocSession.mat']);
if exist(session_fpath, 'file')
    % Modified MMH 2024: 
    % if the session file already exists, don't over-write it.
    fprintf('loading from %s\n', session_fpath)
    session = load(session_fpath);
    session = session.session;
    % now this "session" var replaces what we made in the code above.
    % check this has the same params as what we entered.
    assert(session.trigger==trigger)
    assert(session.stim_set==stim_set)
    assert(session.task_num==task_num)
    assert(session.num_runs==num_runs)
    assert(session.debug==debug)
    % check we're on the correct run number now
    expected_run = session.runs_done+1;
    if (this_run~=expected_run); error('check run number; expecting run %d', expected_run); end
else
    % if the session file doesn't exist yet, we're going to create it now.
    if (this_run~=1); error('check run number; expecting run 1'); end
    fprintf('saving to %s\n', session_fpath)
    save(session_fpath, 'session', '-v7.3');

end

% creating sequence for all runs in this session
% (if this is already created, this function loads it from disk).
session = load_seqs(session);

% pars_fpath = fullfile(session.exp_dir, 'data', session.id, [session.id '_fLoc_run1.par']);
% if 
% write_parfiles(session);

% disp(session_fpath)
% disp(exist(session_fpath, 'file'))
% 
% % execute all runs from start_run to num_runs and save parfiles
% fname = [session.id '_fLocSession.mat'];
% session_fpath = fullfile(session.exp_dir, 'data', session.id, fname);

ListenChar(2) % suppressing keyboard output to matlab
HideCursor;

% modified by MMH 2024: we are only doing one run at a time
% for rr = start_run:num_runs
session = run_exp(session, this_run);

fprintf('saving to %s\n', session_fpath)
save(session_fpath, 'session', '-v7.3');
% end

ListenChar(1) % back to normal keyboard output
ShowCursor;

end
