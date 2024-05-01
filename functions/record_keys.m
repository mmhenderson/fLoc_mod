function [keys, is_empty] = record_keys(start_time, dur, device_num, escape_key, trigger_key)
% Collects all keypresses for a given duration (in secs).
% Written by KGS Lab
% Edited by AS 8/2014
% Edited by MMH 2024

% wait until keys are released
keys = [];
while KbCheck(device_num)
    if (GetSecs - start_time) > dur
        break
    end
end

% check for pressed keys
while 1
    [key_is_down, ~, key_code] = KbCheck(device_num);
    
    % MMH 2024 adding this: allow the user to easily escape
    % with escape key if desired
    key_index = find(key_code);
    if ismember(escape_key, key_index)
        escape_response()
    end

    % MMH 2024 adding this: if pressed key is the trigger key, ignore it.
    trigger_ind = KbName(trigger_key);
    key_code(trigger_ind) = 0;
    % note that key_code can have multiple elements true.
    % so if something else was pressed besides trigger, we'll still look at that.
    % but if only trigger, then we treat it as no press.
    key_is_down = any(key_code);

    if key_is_down
        keys = [keys KbName(key_code)];
        while KbCheck(device_num)
            if (GetSecs - start_time) > dur
                break
            end
        end
    end
    if (GetSecs - start_time) > dur
        break
    end
    
end

% label null responses and store multiple presses as an array
if isempty(keys)
    is_empty = 1;
elseif iscell(keys)
    keys = num2str(cell2mat(keys));
    is_empty = 0;
else
    is_empty = 0;
end

end
