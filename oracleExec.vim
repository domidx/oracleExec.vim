""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" Originated from oracle.vim:
"   https://www.vim.org/scripts/script.php?script_id=141
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Do not load, if already been loaded
if exists("loaded_sqlrc")
  finish
endif

let loaded_sqlrc=1

" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Variables
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" following are the default values for the variables used to connect to an
" Oracle instance. you can change these variables to connect to a different
" instance or as a different user. use :CC command to change the connection
" variables.

let s:sqlcmd='sqlplus '	" executable name of SQL*Plus (non GUI version), if sqlplus is not in the PATH, use the complete path to sqlplus. Make sure you insert a space before the ending quote (')
let s:user=''	" Default Oracle user name
let s:password=''	" Default Oracle password
let s:server=''	" Default Oracle server to use
let s:do_highlight_errors=1 " set this variable to 1 to highlight errors after compiling, set to 0 to turn it off
let s:selected_title=''

" Check and load the menu array file.
if !exists('g:ConnectionFile')
    let g:ConnectionFile = ''
endif
execute "source ".fnameescape(g:ConnectionFile)
if !exists('g:conlist')
    let g:conlist = ''
endif

" Set up a way to run the commands.
" The default is to open a sqlplus session in a separate cmd window.
" If g:oracleExecVim_termstart is set to 'terminal', open the sqlplus session in
" the vim's terminal.
" If g:oracleExecVim_termstart is set to 'pyserver', use the sqlPlusExec.py
" script to run the commands.
let s:termstart='!start %s %s @%s'
if exists('g:oracleExecVim_termstart')
    if g:oracleExecVim_termstart == 'terminal'
        let s:termstart='terminal ++close  %s %s @%s'
    elseif g:oracleExecVim_termstart == 'pyserver'
        let s:plugin_dir = fnamemodify(expand('<sfile>'), ':h')
        let s:termstart = 'py ' . s:plugin_dir . (has('win32') ? '\' : '/') . 'sqlPlusExec.py --conn %s --sqlcmd %s'
    endif
else
    let g:oracleExecVim_termstart = 'default'
endif

if !exists('g:PyServerSqlOutput')
    let g:PyServerSqlOutput = 'csv'
endif

if !exists('g:oracleExecVim_defaultUserName')
    let g:oracleExecVim_defaultUserName = ''
else
    let s:user = g:oracleExecVim_defaultUserName
endif
if !exists('g:oracleExecVim_defaultPwd')
    let g:oracleExecVim_defaultPwd = ''
else
    let s:password = g:oracleExecVim_defaultPwd
endif

if !exists('g:oracleExecVim_devUserName')
    let g:oracleExecVim_devUserName = g:oracleExecVim_defaultUserName
endif
if !exists('g:oracleExecVim_devPwd')
    let g:oracleExecVim_devPwd = g:oracleExecVim_defaultPwd
endif

if !exists('g:postSqlPlusCmd')
    let g:postSqlPlusCmd = []
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Commands
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
command! CC call s:ChangeConnection()
command! -range=% Sql call s:SqlPlus()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:CheckModified() abort
	"check the file is modified
	if &modified
		let l:choice = confirm("Do you want to save changes before continuing?", "&Yes\n&No\n&Cancel", 1, "Question")
		if l:choice == 1
			write
		elseif l:choice == 2
			"nothing to do
		else
			return -1
		endif
	endif
	return 0
endfunction

function! s:CheckConnection() abort
	" Check to ensure the connection details are defined in the global
	" variables
	if exists("s:user") == 0 || exists("s:password") == 0 || exists("s:server") == 0 || s:user == "" || s:password == "" || s:server == ""
		call s:SelectDatabase()
	endif
	" if the variables are still not set return error
	if exists("s:user") == 0 || exists("s:password") == 0 || exists("s:server") == 0 || s:user == "" || s:password == "" || s:server == ""
		echohl ErrorMsg
		echo "Invalid connection information"
		echohl None
		return -1
	else
		return 0
	endif
endfunction

function! s:ChangeConnection() abort
	" Prompt user for all the connection information to Oracle
	let l:user = input('Enter userid [' . s:user . ']: ')
	let l:password = inputsecret('Enter Password [****]: ')
	let l:server = input('Enter Server [' . s:server . ']: ')
	if l:user != ""
		let s:user = l:user
	endif
	if l:password != ""
		let s:password = l:password
	endif
	if l:server != ""
		let s:server = l:server
	endif

	let s:connect_string = s:user . '/' . s:password . '@' .  s:server
    let s:selected_title = ''
endfunction

function! s:DescribeObject() abort
	if s:CheckConnection() != 0
		return
	endif

	" create a new buffer with server:user:object.sql name and delete all the
	" texts
	let l:object = @"
	silent execute 'new ' . s:server . ':' . s:user . ':' . l:object . '.sql'
	1,$delete	" empty the buffer

	" create the SQL statements for describe and execute
	call append(0, "prompt " . l:object)
	call append(1, "desc " . l:object)
	1,$call s:SqlPlus()

	"delete the SQL> prompts
	normal dW+df 
	setlocal ts=8 nomodified

endfunction

function! s:SetConnectionString(auser, apwd, aserver) abort
    let s:user = a:auser
	let s:password = a:apwd
	let s:server = a:aserver
	let s:connect_string = s:user . '/' . s:password . '@' .  s:server

	echo s:connect_string
endfunction

function! s:ConnectToDev() abort
    let l:branchname = ''
    let l:dirs = split(expand('%:p'), '[/\\]')
    let i = 0
    while i < len(l:dirs)
        if l:dirs[i] == 'branches' && (i + 1) < len(l:dirs)
            let l:branchname = l:dirs[i+1]
        endif
        let i += 1
    endwhile
    let l:version = substitute(l:branchname, '\.', '', 'g')
    if l:version != ''
        call s:SetConnectionString(g:oracleExecVim_devUserName, g:oracleExecVim_devPwd, 'dev'.l:version.'.world')
    endif
endfunction

function! s:BuildSelectDbMenu(llist, title) abort
	let retVal = ""
	let strlist = ""

    if a:title == ""
        let strlist .= "dev\n"
    endif

	for i in a:llist
		let strlist .= i[1]."\n"
	endfor

	if a:title == ""
		let strlist .= "&Other...\nReload"
	endif

    let strlist = substitute(strlist, '\n\+$', '', '')

	let l:old_guioptions = &guioptions
	set guioptions+=v
	let l:choice = confirm("Select ".a:title.":", strlist, 1, "Question")
	let &guioptions=l:old_guioptions

    let l:menu_shift = 2
    if a:title != ""
        let l:menu_shift = 1
    endif

	if l:choice == 0
		" Esc or CTRL+c
		let retVal = ""

	elseif (a:title == "") && (l:choice == 1)
		" dev
		call s:ConnectToDev()

	elseif (a:title == "") && (l:choice == (len(a:llist)+2))
		" Other...
		call s:ChangeConnection()

	elseif (a:title == "") && (l:choice == (len(a:llist)+3))
		" Reload
		silent execute 'source '.fnameescape(g:ConnectionFile)

	elseif (l:choice < len(a:llist)+l:menu_shift)
		if (a:llist[l:choice-l:menu_shift][0] == 'm')
			let retVal = s:BuildSelectDbMenu(a:llist[l:choice-l:menu_shift][2], a:title." ".substitute(a:llist[l:choice-l:menu_shift][1], "&", "", "g"))

		else
            call s:SetConnectionString(a:llist[l:choice-l:menu_shift][2][0], a:llist[l:choice-l:menu_shift][2][1], a:llist[l:choice-l:menu_shift][2][2])

            let s:selected_title = a:title." ".substitute(a:llist[l:choice-l:menu_shift][1], "&", "", "g")
		endif
	endif

    if s:user != '' && s:server != ''
        exec 'set statusline='.s:user.'@'.s:server.':>'
        exec 'set statusline+=\ %f\ %h%m%r'
        exec 'set statusline+=%<\ %=%l,%c\ \ \ \ \ \ \ \ \ \ \ %P'
    endif

	return retVal
endfunction

function! s:SelectDatabase() abort
	let retVal = s:BuildSelectDbMenu(g:conlist, "")
endfunction

function! s:CompAll() abort
    let lSortExt = ['.pks', '.fnc', '.prc', '.pkb', '.sql']
    let lBufNamesFullPath = map(filter(range(0,bufnr('$')), 'buflisted(v:val)'), 'fnamemodify(bufname(v:val), ":p")')
    let lBufNamesFullPath = filter(copy(lBufNamesFullPath), 'index(lBufNamesFullPath, v:val, v:key+1)==-1')

    let lSorted = []

    for extension in lSortExt
        for fullPathName in lBufNamesFullPath
            if fullPathName[len(fullPathName)-len(extension):] == extension
                call add(lSorted, fullPathName)
            endif
        endfor

        " Remove from lBufNamesFullPath what's in lSorted already.
        for inSorted in lSorted
            if index(lBufNamesFullPath, inSorted) > -1
                call remove(lBufNamesFullPath, index(lBufNamesFullPath, inSorted))
            endif
        endfor
    endfor

    " Whatever is left in lBufNamesFullPath at this point has no extension
    " in lSortExt so just stack it at the end.
    for fullPathName in lBufNamesFullPath
        call add(lSorted, fullPathName)
    endfor

    let l:lines = []

    for lFileName in lSorted
        call add(l:lines, 'prompt')
        call add(l:lines, 'prompt Running '.lFileName.'..')
        call add(l:lines, '@'.lFileName)
        call add(l:lines, 'show error')
        call add(l:lines, 'prompt Finished '.lFileName.'..')
    endfor

    call s:SqlPlus('compall', l:lines)

endfunction

function! s:DescTable() abort
    let l:tableName = expand('<cword>')

    if !empty(l:tableName)
        let l:param = input('Additional parameter? ')

        if empty(l:param)
            let l:param = '%'
        endif

        call s:ExecuteFile('"@desc.sql '.l:tableName.' '.l:param.'"')
    else
        echo "No word under cursor!"
    endif
endfunction

function! s:JumpCell(aDir) abort
    let l:curPos = getpos('.')

    if a:aDir == 'f'
        " Search for next pipe '|' forward after current position.
        let l:pipeRow = search('|', 'we', line('.'))
    else
        " Backwards - first search moves cursor at the beginning
        " of a current cell.
        let l:curChar = strcharpart(getline(l:curPos[1]), l:curPos[2] - 1, 1)
        let l:pipeRow = search('|', 'be', line('.'))

        if l:pipeRow == 0
            " No more pipes, cursor is in the first cell of a row, move one line up.
            " If already at the top, move cursor to the end of last line.
            let l:nextLine = l:curPos[1] - 1
            if l:nextLine <= 0
                let l:nextLine = line('$')
            endif
            call cursor(l:nextLine, col('$'))
            let l:curChar = strcharpart(getline(l:nextLine), col('$')-1, 1)
        endif

        if l:curChar != '|'
            " Move to previous cell.
            let l:pipeRow = search('|', 'be', line('.'))
            if l:pipeRow == 0
                call cursor(l:curPos[1], 1)
            endif
        endif
    endif

    let l:newCurPos = getpos('.')

    if l:curPos == l:newCurPos
        if a:aDir == 'f'
            " Forward - no pipe found: move to first cell of next line
            let l:nextLine = l:curPos[1] + 1
            if l:nextLine > line('$')
                let l:nextLine = 1
            endif
        else
            " Backwards - no pipe found, move to the last cell of previous row
            let l:nextLine = l:curPos[1] - 1
            if l:nextLine <= 0
                let l:nextLine = line('$')
            endif
        endif

        " Move cursor to first non-blank char or col 1 of next line
        let next_line_text = getline(l:nextLine)
        let first_nonspace = match(next_line_text, '\S')
        if first_nonspace >= 0
            call cursor(l:nextLine, first_nonspace + 1)
        else
            call cursor(l:nextLine, 1)
        endif
    else
        " Move one character further after pipe.
        call cursor(l:newCurPos[1], l:newCurPos[2]+1)
    endif
endfunction

highlight CurrentTableCell guibg=#FFA500 ctermbg=208

function! s:HighlightCurrentCell() abort
  " Delete previous match
  if exists('w:current_cell_matchid')
    call matchdelete(w:current_cell_matchid)
    unlet w:current_cell_matchid
  endif

  let lnum = line('.')
  let colnum = col('.')
  let line_text = getline(lnum)

  " Get pipe positions
  let pipe_positions = []
  let start_pos = 0
  while 1
    let idx = match(line_text, '|', start_pos)
    if idx == -1
      break
    endif
    call add(pipe_positions, idx + 1)
    let start_pos = idx + 1
  endwhile

  " Determine current cell boundaries
  let cell_start = 1
  for pos in pipe_positions
    if pos < colnum
      let cell_start = pos + 1
    else
      break
    endif
  endfor

  let cell_end = len(line_text)
  for pos in pipe_positions
    if pos > colnum
      let cell_end = pos - 1
      break
    endif
  endfor

  " Calculate length of match
  let cell_length = cell_end - cell_start + 1

  " Don't highlight invalid ranges
  if cell_length <= 0
    return
  endif

  " Build valid pattern and apply highlight
  let pattern = '\%' . lnum . 'l\%' . cell_start . 'c.\{' . cell_length . '}'
  let w:current_cell_matchid = matchadd('CurrentTableCell', pattern)
endfunction

function! s:SetupHighlightAutocmds() abort
    augroup TableCellHighlight
        autocmd! * <buffer>
        autocmd CursorMoved,CursorMovedI <buffer> call s:HighlightCurrentCell()
    augroup END
    call s:HighlightCurrentCell()
endfunction

function! s:ShowExecOutput(aLines, aBack) abort
    let bufInfo = getbufinfo('PyServerOutputBuff')

    if empty(bufInfo)
        " Open a new split window at the bottom
        botright 30new
        " Set the buffer to scratch mode so it doesn't affect your files
        setlocal buftype=nofile
        setlocal bufhidden=wipe
        setlocal noswapfile
        setlocal cursorline
        setlocal nowrap
        silent! file PyServerOutputBuff
    else
        " Find the window showing this buffer (there should be exactly one)
        for w in range(1, winnr('$'))
            if winbufnr(w) == bufInfo[0].bufnr
                execute w . 'wincmd w'
                break
            endif
        endfor
    endif

    " Make buffer modifiable before changing content
    setlocal modifiable

    " Clear all existing lines
    silent! %delete _

    " Put output in the new buffer
    call setline(1, a:aLines)
    setlocal nomodifiable

    " Map 'q' to close the buffer
    nnoremap <buffer> q :bd!<CR>
    nnoremap <buffer> <Tab> :call <SID>JumpCell('f')<CR>
    nnoremap <buffer> <S-Tab> :call <SID>JumpCell('b')<CR>
    " Delay the autocommand setup until they enter the buffer
    autocmd BufEnter <buffer> call s:SetupHighlightAutocmds()

    if a:aBack == 1
        " Go back to original buffer/window.
        wincmd p
    endif
endfunction

function! s:ParseAndShowErrors(aQfData) abort
    let qflist = [{'text': '============ Compilation errors ============'}]

    for data in a:aQfData
        " Find the index of line containing 'LINE/COL ERROR'
        let start_idx = -1
        for i in range(len(data.errLines))
            if data.errLines[i] =~? '^.*LINE\/COL\s\+ERROR.*$'
                let start_idx = i
                break
            endif
        endfor

        " Skip the 'LINE/COL ERROR' line and the dashed line below it
        let parse_lines = data.errLines[start_idx + 2 :]

        " Regex to parse each error line like: 466/9    PL/SQL: Statement ignored
        " Capture line, col, and the message
        let pattern = '^\s*\(\d\+\)/\(\d\+\)\s\+\(.*\)$'

        for line in parse_lines
            if line =~ pattern
                let matchlist = matchlist(line, pattern)
                call add(qflist, {
                        \ 'filename': data.filename,
                        \ 'lnum': str2nr(matchlist[1]),
                        \ 'text': matchlist[3]
                        \ })
            endif
        endfor
    endfor

    call setqflist(qflist, 'r')
    copen

    nnoremap <buffer> <silent> x 10<C-w>_<CR>zxzz:copen<CR>
    nnoremap <buffer> <silent> <CR> <CR>zxzz:cclose<CR>
    nnoremap <buffer> <silent> q :cclose<CR>

endfunction

" The procedure loops through the lines.
" When get to the line starting with 'Running' (see function CompAll)
" it starts adding lines to errLines until it reaches line starting
" with 'Finished' (again, see function CompAll).
" Then call function to add to quickfix.
function! s:ProcessCompallErrors(aLines) abort
    let filename = ''
    let addErr = 0
    let errLines = []
    let qfData = []

    for line in a:aLines
        if line =~? 'Running'
            " Get the file name from 'Running <path>/filename.ext..'.
            " Split the string by path separator (both / and \)
            let parts = split(line, '[/\\]')
            " Get the last element from the array
            let last_field = parts[-1]
            " Remove the last two characters ('..')
            let filename = strpart(last_field, 0, len(last_field) - 2)

            let errLines = []
            let addErr = 0
            continue
        endif

        if line =~? '^.*LINE\/COL\s\+ERROR.*$'
            " Found error, add following lines to the list.
            let addErr = 1
        endif

        if line =~? 'Finished'
            " Reached end of part for the file, add to quickfix.
            call add(qfData, {'filename': filename, 'errLines': errLines})

            " Initialise
            let errLines = []
            let addErr = 0
            let filename = ''
            continue
        endif

        if addErr == 1
            call add(errLines, line)
        endif

    endfor

    call s:ParseAndShowErrors(qfData)
endfunction

function! s:ProcessExecOutput(aOutput, aType, aStartTime) abort
    let lines = split(a:aOutput, '\n')

    if a:aOutput =~? '^.*LINE\/COL\s\+ERROR.*$'
        if a:aType == 'compall'
            call s:ProcessCompallErrors(lines)
        else
            let qfData = []
            call add(qfData, {'filename': expand("%"), 'errLines': lines})
            call s:ParseAndShowErrors(qfData)
        endif
    elseif expand('%:e') == 'sql'
        call s:ShowExecOutput(lines, 0)
    elseif a:aOutput =~? 'created' && a:aType != 'compall'
        let l:end_time = localtime()
        echo '============ PROCESSING SUCCESSFUL ('.s:server.' '.strftime("%d-%m-%Y %H:%M:%S", l:end_time) .' '.(l:end_time - a:aStartTime).'s): '.filter(copy(lines), 'v:val =~ "created"')[0].' ============'
    else
        call s:ShowExecOutput(lines, 0)
    endif
endfunction

" ============================================================
"  Async Job Runner with Spinner Popup
" ============================================================

let s:spinner_frames = ['⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏']
let s:spinner_idx    = 0
let s:spinner_timer  = -1
let s:collected_output = []

highlight RunSqlPopupBorder guibg=#5f3a1e guifg=#ffaa00
highlight RunSqlPopupBody   guibg=#5f3a1e guifg=#ffdd88

" ------------------------------------------------------------
"  Public entry point — call this to kick things off
" ------------------------------------------------------------
function! s:RunAsyncTask(cmd, callback) abort
  let s:collected_output = []
  let s:spinner_idx      = 0

  let l:popup_id = s:OpenSpinnerPopup()

  call job_start(a:cmd, {
    \ 'out_cb':  function('s:OnOutput'),
    \ 'err_cb':  function('s:OnError'),
    \ 'exit_cb': function('s:OnExit', [l:popup_id, a:callback]),
    \ 'out_mode': 'nl',
    \ })
endfunction

" ------------------------------------------------------------
"  Popup
" ------------------------------------------------------------
function! s:OpenSpinnerPopup() abort
  let l:popup_id = popup_create(s:spinner_frames[0] . ' Running...', {
    \ 'title':           ' Processing ',
    \ 'border':          [],
    \ 'borderhighlight': ['RunSqlPopupBorder'],
    \ 'padding':         [1, 4, 1, 4],
    \ 'pos':             'center',
    \ 'zindex':          200,
    \ 'highlight':       'RunSqlPopupBody',
    \ 'shadow':          1,
    \ })
  redraw

  let s:spinner_timer = timer_start(100,
    \ function('s:SpinTick', [l:popup_id]),
    \ {'repeat': -1})

  return l:popup_id
endfunction

function! s:CloseSpinnerPopup(popup_id) abort
  call timer_stop(s:spinner_timer)
  let s:spinner_timer = -1
  call popup_close(a:popup_id)
  redraw
endfunction

" ------------------------------------------------------------
"  Spinner tick (called every 100ms by the timer)
" ------------------------------------------------------------
function! s:SpinTick(popup_id, timer) abort
  let s:spinner_idx = (s:spinner_idx + 1) % len(s:spinner_frames)
  call popup_settext(a:popup_id, s:spinner_frames[s:spinner_idx] . ' Running...')
  redraw
endfunction

" ------------------------------------------------------------
"  Job callbacks
" ------------------------------------------------------------
function! s:OnOutput(channel, line) abort
  call add(s:collected_output, a:line)
endfunction

function! s:OnError(channel, line) abort
  call add(s:collected_output, '!ERR: ' . a:line)
endfunction

function! s:OnExit(popup_id, callback, job, status) abort
  call s:CloseSpinnerPopup(a:popup_id)

  if a:status != 0
    echoerr '❌ Task failed (status ' . a:status . ')'
    return
  endif

  call a:callback(s:collected_output)
endfunction

function! s:RunSqlExec(sqlcmd, callback) abort
    call s:RunAsyncTask(printf(s:termstart, s:connect_string, a:sqlcmd), a:callback)
endfunction

function! s:OnExitExecuteFile(type, start_time, lines) abort
    let l:result = join(a:lines, "\n")
    let l:result = substitute(l:result, '\n$', '', '')

    call s:ProcessExecOutput(l:result, a:type, a:start_time)
endfunction

function! s:ExecuteFile(...) abort
    " type(a:1) == 3 -- this is true for list

    if g:oracleExecVim_termstart == 'pyserver'
        let l:start_time = localtime()

        if type(a:1) == 3
            " If any lines returned, concatenate into a single line
            " for cmd parameter, enclose each line in double quotes
            " and keep an empty space between them.
            let l:sqlcmd = '"'.join(a:1, '" "').'"'
        else
            let l:sqlcmd = a:1
        endif

        let l:type = ''
        if a:0 > 1
            let l:type = a:2
        endif

        call s:RunSqlExec(l:sqlcmd, function('s:OnExitExecuteFile', [l:type, l:start_time]))

    else
        let l:runFile = ""
        if type(a:1) == 3 && len(a:1) > 0
            let l:runFile = $temp."/compile.sql"
            call delete(l:runFile)
            call writefile(a:1, l:runFile, '')
        else
            let l:runFile = a:1
        endif

        silent execute printf(s:termstart, s:sqlcmd, s:connect_string, l:runFile)
    endif
endfunction

function! s:ClearHighlight() abort
    if exists('w:highlightedCmd')
        call matchdelete(w:highlightedCmd)
        unlet w:highlightedCmd
    endif
endfunction

function! s:HighlightRange(startPos, endPos) abort
    let startLine = a:startPos[0]
    let startCol  = a:startPos[1]
    let endLine   = a:endPos[0]
    let endCol    = a:endPos[1]

    " If endCol is 0, highlight up to the end of the previous line
    if endCol == 0
        let endLine -= 1
        let endCol = col([endLine, '$']) - 1
    endif

    if endLine < startLine || (endLine == startLine && endCol < startCol)
        return
    endif

    let positions = []

    " If range is in one line
    if startLine == endLine
        let length = endCol - startCol + 1
        call add(positions, [startLine, startCol, length])
    else
        " Highlight from startCol to end of startLine
        let startLineLen = col([startLine, '$']) - 1
        call add(positions, [startLine, startCol, startLineLen - startCol + 1])

        " Highlight full lines in between
        for lnum in range(startLine + 1, endLine - 1)
            let lineLen = col([lnum, '$']) - 1
            if lineLen > 0
                call add(positions, [lnum, 1, lineLen])
            endif
        endfor

        " Highlight from col 1 to endCol in endLine
        call add(positions, [endLine, 1, endCol])
    endif

    " Highlight group: use 'Visual' or create your own highlight group
    let w:highlightedCmd = matchaddpos('Visual', positions)
endfunction

function! s:GetAndHighlightSingleCmd() abort
    let l:searchPattern = '\s*;\s*$\|^\s*\/\s*$'
    " Save current cursor position.
    let l:curPos = getpos('.')

    " Read character under cursor.
    let l:line = getline(l:curPos[1])
    let l:curChar = strcharpart(l:line, l:curPos[2] - 1, 1)

    " Find end of previous command.
    let l:prevEnd = searchpos(l:searchPattern, 'b', line('w0'))

    if l:prevEnd != [0, 0]
        let l:prevEnd = searchpos('\k\+', 'W')
    endif

    " Handle case where no previous command terminator was found
    if l:prevEnd == [0, 0]
        let l:prevEnd = [1, 1]
    endif

    " Now find an end of command. If a cursor is on ; or /, use the current
    " position.
    if l:curChar ==# ';' || l:curChar ==# '/'
        let l:cmdEnd = [l:curPos[1], l:curPos[2]]
    else
        let l:cmdEnd = searchpos(l:searchPattern, 'W', line("w$"))
        if l:cmdEnd == [0, 0]
            let l:lastLine = line('$')
            let l:lastCol = col([l:lastLine, '$']) - 1 " Adjust for the end-of-line position
            let l:cmdEnd = [l:lastLine, l:lastCol]
        endif
    endif

    " Get all lines between startLine and endLine (inclusive)
    let l:lines = getline(l:prevEnd[0], l:cmdEnd[0])

    if l:prevEnd[0] == l:cmdEnd[0]
        " If it's only one line, just take the substring between startCol and endCol.
        " Vim columns are 1-based, string indexing is 0-based
        let l:lines = [strpart(l:lines[0], l:prevEnd[1] - 1, l:cmdEnd[1] - l:prevEnd[1] + 1)]
    else
        " Otherwise, handle multiple lines:
        " Trim start line from startCol to end of line
        let l:lines[0] = strpart(l:lines[0], l:prevEnd[1] - 1)

        " Trim end line from beginning up to endCol
        let l:lines[-1] = strpart(l:lines[-1], 0, l:cmdEnd[1])
        " Remove any leading empty lines.
        while !empty(l:lines) && l:lines[0] == ''
            call remove(l:lines, 0)
        endwhile
    endif

    " Ensure last element is a semicolon line or slash.
    if !empty(l:lines) && l:lines[-1] !~ '[;/]$'
        call add(l:lines, ';')
    endif

    " Move cursor to the original position.
    call setpos('.', l:curPos)

    call s:ClearHighlight()
    call s:HighlightRange(l:prevEnd, l:cmdEnd)
    redraw

    return l:lines
endfunction

" Function to get visually selected text.
function! s:GetSelectedText() abort
    " Save current register contents to restore later
    let l:saveReg = getreg('"')
    let l:saveRegType = getregtype('"')

    " Yank visual selection into register "
    silent normal! gv"xy

    " Get the yanked text from register x
    let l:selectedText = split(getreg('x'), '\n')

    " Restore previous register
    call setreg('"', l:saveReg, l:saveRegType)

    return l:selectedText
endfunction

function! s:ParseCSVLine(line) abort
    let fields = []
    " Pattern invented by JammyDonut, thanks a lot!!!
    let pat = '\("\(""\|[^"]\)*"\|[^,]*\)[,]\?'
    let pos = 0
    while pos <= len(a:line)
        let [match, start, end] = matchstrpos(a:line, pat, pos)
        if start == -1 || end == pos
            break
        endif
        " strip surrounding quotes if present
        let field = match
        let field = substitute(field, ',$', '', '')   " strip trailing comma
        if field =~ '^".*"$'
            let field = field[1:-2]                     " strip outer quotes
            let field = substitute(field, '""', '"', 'g') " unescape ""
        endif
        call add(fields, field)
        let pos = end
    endwhile
    return fields
endfunction

function! s:MakeSep(col_widths) abort
    let parts = []
    for w in a:col_widths
        call add(parts, repeat('-', w + 2))
    endfor
    return join(parts, '+')
endfunction

function! s:MakeRow(row, col_widths) abort
    let parts = []
    for i in range(len(a:col_widths))
        let val = get(a:row, i, '')
        call add(parts, ' ' . val . repeat(' ', a:col_widths[i] - len(val) + 1))
    endfor
    return join(parts, '|')
endfunction

function! s:CSVToTable(csv_lines) abort
    " Parse CSV into rows
    let rows = []
    let rn = 0
    for line in a:csv_lines
        let fields = s:ParseCSVLine(line)
        " Trim whitespace from each field
        let fields = map(fields, 'substitute(v:val, "^\\s*\\|\\s*$", "", "g")')

        " Prepend row number (header gets label, data rows get count)
        if rn == 0
            let fields = ['rn'] + fields
        else
            let fields = [string(rn)] + fields
        endif
        let rn += 1

        call add(rows, fields)
    endfor

    " Determine number of columns (use max across all rows)
    let ncols = max(map(copy(rows), 'len(v:val)'))

    " Pad rows that have fewer columns than ncols
    for row in rows
        while len(row) < ncols
            call add(row, '')
        endwhile
    endfor

    " Compute max width for each column
    let col_widths = repeat([0], ncols)
    for row in rows
        for i in range(ncols)
            let w = len(row[i])
            if w > col_widths[i]
                let col_widths[i] = w
            endif
        endfor
    endfor

    let sep = s:MakeSep(col_widths)
    let output = []

    call add(output, s:MakeRow(rows[0], col_widths))   " header row
    call add(output, sep)                                " separator

    for row in rows[1:]
        call add(output, s:MakeRow(row, col_widths))
    endfor

    return output
endfunction

function! s:OnExitExecuteSql(start_time, isSelect, lines) abort
    let l:end_time = localtime()
    echo '============ RESULTS RETURNED ('.s:server.' '.strftime("%d-%m-%Y %H:%M:%S", l:end_time) .' '.(l:end_time - a:start_time).'s) ============'

    let l:lines = a:lines
    let l:result = join(a:lines, "\n")

    " If SELECT statement then build result table.
    " Don't output table for errors or 'no rows selected'
    if a:isSelect && stridx(l:result, "no rows selected") == -1 && stridx(l:result, "ERROR") == -1
        let l:lines = s:CSVToTable(l:lines)
    endif

    call s:ShowExecOutput(l:lines, 1)

    call s:ClearHighlight()

endfunction

function! s:ExecuteSql(aType) abort
    if g:oracleExecVim_termstart == 'pyserver'

        if s:CheckConnection() != 0
            return
        endif

        let l:start_time = localtime()

        if a:aType == 'selected'
            let l:SqlLines = s:GetSelectedText()
        else
            let l:SqlLines = s:GetAndHighlightSingleCmd()
        endif

        if len(l:SqlLines) > 0
            " Remove lines that are commented out -> --
            let l:SqlLines = filter(copy(l:SqlLines), 'v:val !~ "^\\s*--"')
            let l:isSelect = l:SqlLines[0] =~? '^\s*\(select\|with\)\(\W\|$\)'

            " If any lines returned, concatenate into a single line
            " for cmd parameter, enclose each line in double quotes
            " and keep an empty space between them.
            let l:sqlcmd = '"'.join(l:SqlLines, '" "').'"'

            call s:RunSqlExec(l:sqlcmd, function('s:OnExitExecuteSql', [l:start_time, l:isSelect]))

        endif

    endif
endfunction

function! s:PasteSingleLineFromReg() abort
    let l:lines = split(getreg('"'), '\n')
    " Remove leading and trailing blank spaces.
    let l:lines = map(l:lines, {_, v -> trim(v)})

    " Check for non-numeric using a regex
    let l:nonNumeric = filter(copy(l:lines), {_, v -> match(v, '^\d\+\(\.\d\+\)\?$') == -1})

    if !empty(l:nonNumeric)
        " There are non numeric data selected, enclose with single quote.
        let l:lines = map(copy(l:lines), {_, v -> "'" . substitute(v, "'", "''", 'g') . "'"})
        let l:oneLine = join(l:lines, ', ')
    else
        let l:oneLine = join(l:lines, ", ")
    endif

    execute "normal! a".l:oneLine
endfunction

function! s:SqlPlus(...) range abort
" this function lets you
"       - start SQL*Plus
"       - execute the contents of the current buffer and show the results back in
"       the same buffer
"       - execute the selected lines from the current buffer and show results in a
"       new buffer

    if s:CheckConnection() != 0
        return
    endif

    if a:0 > 0
        if a:1 == "@"
            " run the 2nd parameter as a file

            "check the file is modified
            if s:CheckModified() == -1
                return
            endif

            let l:postSqlPlusCmd = []
            if g:oracleExecVim_termstart == 'pyserver'
                let l:postSqlPlusCmd = ['show error']
            elseif len(g:postSqlPlusCmd) > 0
                let l:postSqlPlusCmd = g:postSqlPlusCmd
            endif

            if len(l:postSqlPlusCmd) > 0 && index(['pks', 'pkb', 'trg', 'fnc', 'prc', 'vw', 'tps', 'tpb'], expand("%:e")) >=0
                call s:ExecuteFile(['@'.expand("%:p")]+l:postSqlPlusCmd)
            else
                call s:ExecuteFile('@'.a:2)
            endif

        elseif a:1 == 'compall'
            call s:ExecuteFile(a:2, 'compall')

        else
            " just start SQL*Plus
            silent execute '!start ' . s:sqlcmd . s:connect_string
        endif
    else
        " Execute the range and display the result in buffer
        silent execute a:firstline ',' a:lastline '!' . s:sqlcmd . ' ' . s:connect_string

        let l:old_search = @/
        " this is for standard SQLPROMPT
        silent execute '/SQL>'
        " use the following search for user@server> SQLPROMPT
        "silent execute "/" . s:user . '@' . s:server . ' >'
        " remove the unwanted SQL*Plus details from top & bottom
        silent execute "normal kVggdGNdGgg"
        let @/ = l:old_search
        setlocal ts=8 nomodified
    endif
endfunction

function! s:EchoConnectString() abort
	echo s:selected_title.": ".s:connect_string
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Select Database dialog
nnoremap <Leader>c :call <SID>SelectDatabase()<CR>

" Start SQL*Plus window
nnoremap <Leader>s :call <SID>SqlPlus(1)<CR>

" Execute current file in SQL*Plus window
nnoremap <Leader>r :call <SID>SqlPlus('@', expand('%:p'))<CR>

nnoremap <Leader>R :call <SID>CompAll()<CR>

nnoremap <Leader>0 :call <SID>ExecuteFile('"@dsvn.sql '.fnamemodify(expand('%:t'), ':r').'"')<CR>
nnoremap <Leader>9 :call <SID>ExecuteFile('@dver.sql')<CR>

nnoremap <Leader>m :call <SID>EchoConnectString()<CR>

" domi IDE
nnoremap <F9> :call <SID>ExecuteSql('get')<CR>
inoremap <F9> <C-o>:call <SID>ExecuteSql('get')<CR>
vnoremap <F9> :<C-U>call <SID>ExecuteSql('selected')<CR>
vnoremap <F5> :<C-U>call <SID>ExecuteSql('selected')<CR>
nnoremap <C-y> :call <SID>PasteSingleLineFromReg()<CR>a
inoremap <C-y> <C-o>:call <SID>PasteSingleLineFromReg()<CR><Esc>a
nnoremap <S-F4> :call <SID>DescTable()<CR>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Signs
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has("signs")
	let v:errmsg = ""
	silent! sign list SQLMakeError
	if "" != v:errmsg
		sign define SQLMakeError linehl=Error text=?> texthl=Error
	endif
endif

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save

