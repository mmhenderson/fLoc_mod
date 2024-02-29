function get_key(key, device_num, escape_key)
% Waits until user presses the key specified in first argument.
% Written by KGS Lab
% Edited by AS 8/2014

while 1
    while 1
        [key_is_down, ~, key_code] = KbCheck(device_num);
        if key_is_down
            break
        end
    end
    pressed_key = KbName(key_code);
    % MMH modifying this to work with multiple keys
    if any(ismember(key, pressed_key))
        break
    end
    % MMH 2024 adding this: allow the user to easily escape
    % with escape key if desired
    key_index = find(key_code);
    if ismember(escape_key, key_index)
        escape_response()
    end
end

end
