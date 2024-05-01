classdef fLocSession
    
    properties
        name      % participant initials or id string
        date      % session date
        trigger   % option to trigger scanner (0 = no, 1 = yes)
        num_runs  % number of runs in experiment
        sequence  % session fLocSequence object
        responses % behavioral response data structure
        parfiles  % paths to vistasoft-compatible parfiles
        stim_set  % stimulus set/s (1 = standard, 2 = alternate, 3 = both)
        task_num  % task number (1 = 1-back, 2 = 2-back, 3 = oddball)
        runs_done % how many runs completed so far?
        debug     % debug mode? if 1, do just small num trials.
        hit_cnt   % number of hits per run
        fa_cnt    % number of false alarms per run
%     end
%     
%     properties (Hidden)
        input     % device number of input used for resonse collection
        keyboard  % device number of native computer keyboard
    end
    
    properties (Constant)
        count_down = 12; % pre-experiment countdown (secs)

        % MODIFIED BY MMH 2024 - WE CAN ADJUST STIM SIZE IN DEGREES
        % these are actual measurements of screen size/distance in our
        % setup. may need to change for different recording setups.
        % these measures are from JP, for BOLDscreen at UW Prisma
        view_dist_inches = 120 / 2.54; 
        screen_height_inches = 39.29 / 2.54;
        % desired size in degrees 
        % (this is the whole image height, top to bottom).
        stim_size_dva = 10;
%         stim_size = 768; % size to display images in pixels

        % MMH added this, so we can easily change key for trigger
        % TODO: check keys to use at BRIDGE
        trigger_key = 't';
        escape_key = KbName('escape');
        space_key = KbName('space');
        % Note the escape and space keys are converted to numeric indices
        % this is so we don't have to worry about doing capitalization
    end
    
    properties (Constant, Hidden)
        task_names = {'1back' '2back' 'oddball'};
        exp_dir = fileparts(fileparts(which(mfilename, 'class')));
        fix_color = [255 0 0]; % fixation marker color (RGB)
        text_color = 255;      % instruction text color (grayscale)
        blank_color = 128;     % baseline screen color (grayscale)
        wait_dur = 1;          % seconds to wait for response
    end
    
    properties (Dependent)
        id                  % session-specific id string
        task_name           % descriptor for each task number
        screen_height_dva   % height of screen in degrees
        hit_rate            % proportion of task probes detected in each run
        total_run_dur       % total run dur (s) including countdown
    end
    
    properties (Dependent, Hidden)
        instructions % task-specific instructions for participant
    end
    
    methods
        
        % class constructor
        function session = fLocSession(name, trigger, stim_set, num_runs, task_num, debug)
            session.name = deblank(name);
            session.trigger = trigger;
            session.debug = debug;
            if nargin < 3
                session.stim_set = 3;
            else
                session.stim_set = stim_set;
            end
            if nargin < 4
                session.num_runs = 4;
            else
                session.num_runs = num_runs;
            end
            if nargin < 5
                session.task_num = 3;
            else
                session.task_num = task_num;
            end
            session.date = date;
            session.hit_cnt = zeros(1, session.num_runs);
            session.fa_cnt = zeros(1, session.num_runs);
            session.runs_done = 0; % count how many runs done so far
        end
        
        % get session-specific id string
        function id = get.id(session)
            par_str = [session.name '_' session.date];
            % Modified MMH 2024: putting the "stim set" into the save 
            % name, because sometimes we might want to run diff sets on
            % same day and make different files for each. 
%             exp_str = [session.task_name '_' num2str(session.num_runs) 'runs'];
            exp_str = ['stimset' num2str(session.stim_set) '_' session.task_name '_' num2str(session.num_runs) 'runs'];
            id = [par_str '_' exp_str];
            if session.debug==1
                id = [id '_DEBUG'];
            end
        end
        
        % get name of task
        function task_name = get.task_name(session)
            task_name = session.task_names{session.task_num};
        end
        
        % compute screen height in degrees visual angle
        % added by MMH 2024
        function screen_height_dva = get.screen_height_dva(session)
            screen_height_dva = (2 * atan2(session.screen_height_inches/2, session.view_dist_inches))* (180/pi);
        end

        % get hit rate for task
        function hit_rate = get.hit_rate(session)
            num_probes = sum(session.sequence.task_probes);
            hit_rate = session.hit_cnt ./ num_probes;
        end

        function total_run_dur = get.total_run_dur(session)
            total_run_dur = session.sequence.run_dur + session.count_down;
        end
        
        % get instructions for participant given task
        function instructions = get.instructions(session)
            if session.task_num == 1
                instructions = 'Fixate. Press a button when an image repeats on sequential trials.';
            elseif session.task_num == 2
                instructions = 'Fixate. Press a button when an image repeats with one intervening image.';
            else
                instructions = 'Fixate. Press a button when a scrambled image appears.';
            end
        end
        
        % define/load stimulus sequences for this session
        function session = load_seqs(session)
            fname = [session.id '_fLocSequence.mat'];
            fpath = fullfile(session.exp_dir, 'data', session.id, fname);
            % make stimulus sequences if not already defined for session
            if ~exist(fpath, 'file')
                seq = fLocSequence(session.stim_set, session.num_runs, session.task_num);
                seq = make_runs(seq);
                if ~exist(fileparts(fpath), 'dir')
                    mkdir(fileparts(fpath));
                end
                fprintf('saving to %s\n', fpath)
                save(fpath, 'seq', '-v7.3');
                session.sequence = seq;
                session = write_parfiles(session);
            else
                fprintf('loading from %s\n', fpath)
                load(fpath);
                session.sequence = seq;
            end
            
        end
        
        % register input devices
        function session = find_inputs(session)

            % MMH 2024: this is a more general way of finding devices
            % without having to specify device number.
%             devices = PsychHID('Devices'); % all devices
%             % list all keyboard-like devices (indices into devices)
%             key_devices = GetKeyboardIndices(); 
            
            % Workaround for linux platform differences.
            % If we specify -1 here for device number, it just searches on
            % all devices for responses using default PTB settings.
            % this actually should work fine.
            laptop_index = -1;
            button_index = -1;
% 
%             if length(key_devices)>1
%                 laptop_index = key_devices(1);
%                 button_index = key_devices(2);
%                 fprintf('Found two devices:\n')
%                 fprintf('Keyboard is:\n')
%                 disp(devices(laptop_index).product)
%                 fprintf('Button box is:\n')
%                 disp(devices(button_index).product)
%                 % locationID is the "port" the device is connected to.
%                 % if it's the internal laptop keyboard, it should have
%                 % smaller port number than USB connected device.
% %                 assert(devices(button_index).locationID>devices(laptop_index).locationID);
%             else
%                 laptop_index = key_devices;
%                 button_index = key_devices;
%                 fprintf('Found one device:\n')
%                 disp(devices(laptop_index).product)
%             end


            % MMH: Not using these functions anymore
%             laptop_key = get_keyboard_num;
%             button_key = get_box_num;
%             if session.trigger == 1 && button_index ~= 0
            session.keyboard = laptop_index;
            session.input = button_index;
%             else
%                 session.keyboard = laptop_index;
%                 session.input = laptop_index;
%             end
        end
        
        % execute a run of the experiment
        function session = run_exp(session, run_num)
            % get timing information and initialize response containers
            session = find_inputs(session); %k = session.input;
            sdc = session.sequence.stim_duty_cycle;
            stim_dur = session.sequence.stim_dur;
            isi_dur = session.sequence.isi_dur;
            stim_names = session.sequence.stim_names(:, run_num);
            stim_dir = fullfile(session.exp_dir, 'stimuli');
            tcol = session.text_color; bcol = session.blank_color; fcol = session.fix_color;
            resp_keys = {}; resp_press = zeros(length(stim_names), 1);
            % setup screen and load all stimuli in run
            [window_ptr, center] = do_screen;

            % now that window is open, we can get exact pixel size to draw
            % stimuli for our desired DVA.
            [screen_width_pix, screen_height_pix] = Screen('WindowSize', window_ptr);
            % then figure out pixel size
            stim_size_pix = session.stim_size_dva * ...
                screen_height_pix/session.screen_height_dva;
            s = stim_size_pix / 2;
%             disp([screen_height_dva, screen_height_pix, stim_size_pix])

            center_x = center(1); center_y = center(2); 
            stim_rect = [center_x - s center_y - s center_x + s center_y + s];
            img_ptrs = [];
            for ii = 1:length(stim_names)
                if strcmp(stim_names{ii}, 'baseline')
                    img_ptrs(ii) = 0;
                else
                    cat_dir = stim_names{ii}(1:find(stim_names{ii} == '-') - 1);
                    img = imread(fullfile(stim_dir, cat_dir, stim_names{ii}));
                    img_ptrs(ii) = Screen('MakeTexture', window_ptr, img);
                end
            end
            % start experiment triggering scanner if applicable
            if session.trigger == 0
                Screen('FillRect', window_ptr, bcol);
                Screen('Flip', window_ptr);
                DrawFormattedText(window_ptr, session.instructions, 'center', 'center', tcol);
                Screen('Flip', window_ptr);
                get_key(session.trigger_key, session.keyboard, session.escape_key);
            elseif session.trigger == 1
                Screen('FillRect', window_ptr, bcol);
                Screen('Flip', window_ptr);
                DrawFormattedText(window_ptr, session.instructions, 'center', 'center', tcol); % 'flipHorizontal', 1);
                Screen('Flip', window_ptr);
                while 1
                    get_key(session.trigger_key, session.keyboard, session.escape_key);
                    [status, ~] = start_scan;
                    if status == 0
                        break
                    else
                        message = 'Trigger failed.';
                        DrawFormattedText(window_ptr, message, 'center', 'center', fcol);
                        Screen('Flip', window_ptr);
                    end
                end
            end
            % display countdown numbers
            [cnt_time, rem_time] = deal(session.count_down + GetSecs);
            cnt = session.count_down;
            while rem_time > 0
                if floor(rem_time) <= cnt
                    DrawFormattedText(window_ptr, num2str(cnt), 'center', 'center', tcol);
                    Screen('Flip', window_ptr);
                    cnt = cnt - 1;
                end
                rem_time = cnt_time - GetSecs;
                % MMH 2024 adding this: allow the user to easily escape
                % with escape key if desired
                [key_is_down, ~, key_code] = KbCheck(session.keyboard);
                key_index = find(key_code);
                if ismember(session.escape_key, key_index)
                    escape_response()
                end
            end
            % main display loop
            start_time = GetSecs;
            for ii = 1:length(stim_names)
                % MMH 2024 added this: if debug=True, we stop early (for
                % testing the code).
                if (session.debug==1) && (ii>(session.sequence.stim_per_block*2))
                    continue
                end
                % display blank screen if baseline and image if stimulus
                if strcmp(stim_names{ii}, 'baseline')
                    Screen('FillRect', window_ptr, bcol);
                    draw_fixation(window_ptr, center, fcol);
                else
                    Screen('DrawTexture', window_ptr, img_ptrs(ii), [], stim_rect);
                    draw_fixation(window_ptr, center, fcol);
                end
                Screen('Flip', window_ptr);
                % collect responses
                ii_press = []; ii_keys = [];
                % MMH: monitor both the keyboard and button box here
                [keys, ie] = record_keys(start_time + (ii - 1) * sdc, stim_dur, ...
                    [session.keyboard, session.input], session.escape_key, session.trigger_key);
                ii_keys = [ii_keys keys]; ii_press = [ii_press ie];
                % display ISI if necessary
                if isi_dur > 0
                    Screen('FillRect', window_ptr, bcol);
                    draw_fixation(window_ptr, center, fcol);
                    [keys, ie] = record_keys(start_time + (ii - 1) * sdc + stim_dur, isi_dur, ...
                        [session.keyboard, session.input], session.escape_key, session.trigger_key);
                    ii_keys = [ii_keys keys]; ii_press = [ii_press ie];
                    Screen('Flip', window_ptr);
                end
                resp_keys{ii} = ii_keys;
                % MMH 2024: the ii_press var is tracking whether the
                % responses field was EMPTY (is_empty from record_keys)
                % so we want to record if the field was ever NOT empty
                any_not_empty = any(ii_press==0);
                resp_press(ii) = any_not_empty;
%                 resp_press(ii) = min(ii_press);
            end

            % modified MMH 2024: 
            % increment run counter
            session.runs_done  = session.runs_done + 1;

            % modified MMH 2024: 
            % save data from this run BEFORE showing last screen (in case
            % something goes wrong with exit)
            session_dir = fullfile(session.exp_dir, 'data', session.id);
            session_fpath = fullfile(session_dir, [session.id '_fLocSession.mat']);
            fprintf('saving to %s\n', session_fpath);
            save(session_fpath, 'session', '-v7.3');

            % also saving a backup of responses for this run.
            session.responses(run_num).keys = resp_keys;
            session.responses(run_num).press = resp_press;
            backup_fpath = fullfile(session_dir, [session.id '_backup_run' num2str(run_num) '.mat']);
            fprintf('saving to %s\n', backup_fpath);
            save(backup_fpath, 'resp_keys', 'resp_press', '-v7.3');


            % analyze response data and display performance
            session = score_task(session, run_num);
            num_probes = num2str(sum(session.sequence.task_probes(:, run_num)));
            hit_cnt = num2str(session.hit_cnt(run_num));
            fa_cnt = num2str(session.fa_cnt(run_num));
            hit_rate = num2str(session.hit_rate(run_num) * 100);
            hit_str = ['Hits: ' hit_cnt '/' num_probes ' (' hit_rate '%)'];
            fa_str = ['False alarms: ' fa_cnt];
            Screen('FillRect', window_ptr, bcol);
            Screen('Flip', window_ptr);
            score_str = [hit_str '\n' fa_str];
            DrawFormattedText(window_ptr, score_str, 'center', 'center', tcol);
            Screen('Flip', window_ptr);
            % MMH changed this: can exit with space bar, esc
            % Changed 5/1/2024: the trigger key will NOT quit experiment.
            get_key([KbName(session.escape_key), KbName(session.space_key)], ...
                session.keyboard, session.escape_key);
            ShowCursor;
            Screen('CloseAll');
        end
        
        % quantify performance in stimulus task
        function session = score_task(session, run_num)
            sdc = session.sequence.stim_duty_cycle;
            fpw = session.wait_dur / sdc;
            % get response time windows for task probes
            resp_presses = session.responses(run_num).press;
            resp_correct = session.sequence.task_probes(:, run_num);
            probe_idxs = find(resp_correct);
            hit_windows = zeros(size(resp_correct));
            for ww = 1:ceil(fpw)
                hit_windows(probe_idxs + ww - 1) = 1;
            end
            hit_resp_windows = resp_presses(hit_windows == 1);
            fa_resp_windows = resp_presses(hit_windows == 0);
            % count hits and false alarms
            session.hit_cnt(run_num) = sum(max(reshape(hit_resp_windows, fpw, [])));
            session.fa_cnt(run_num) = sum(fa_resp_windows);
        end
        
        % write vistasoft-compatible parfile for each run
        function session = write_parfiles(session)
            session.parfiles = cell(1, session.num_runs);
            % list of conditions and plotting colors
            conds = ['Baseline' session.sequence.stim_conds];
%             cols = {[1 1 1] [0 0 1] [0 0 0] [1 0 0] [.8 .8 0] [0 1 0]};
            % MMH added an additional color here
            cols = {[1 1 1] [0 0 1] [0 0 0] [1 0 0] [.8 .8 0] [0 1 0] [.8 0 .8] [0 0.8 .8]};
            % write information about each block on a separate line
            for rr = 1:session.num_runs
                block_onsets = session.sequence.block_onsets(:, rr);
                block_conds = session.sequence.block_conds(:, rr);
                cond_names = conds(block_conds + 1);
                cond_cols = cols(block_conds + 1);
                fname = [session.id '_fLoc_run' num2str(rr) '.par'];
                fpath = fullfile(session.exp_dir, 'data', session.id, fname);
%                 fprintf('saving to %s\n', fpath)
                fid = fopen(fpath, 'w');
                for bb = 1:length(block_onsets)
                    fprintf(fid, '%d \t %d \t', block_onsets(bb), block_conds(bb));
                    fprintf(fid, '%s \t', cond_names{bb});
                    fprintf(fid, '%i %i %i \n', cond_cols{bb});
                end
                fclose(fid);
                session.parfiles{rr} = fpath;
            end
        end
        
    end
    
end

