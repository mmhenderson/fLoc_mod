%DEFINE ESCAPE RESPONSE FUNCTION------------------------------------------
function escape_response
    Screen('CloseAll');                
    ShowCursor;
    if IsWin
        ShowHideWinTaskbarMex;     
    end
    ListenChar(1)
    error('User exited program.');
end