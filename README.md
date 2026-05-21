# oracleExec.vim

A Vim plugin for Oracle PL/SQL developers — execute SQL\*Plus sessions, compile PL/SQL objects, and run SQL statements directly from within Vim.

> **Origin:** This plugin is derived from [oracle.vim](https://www.vim.org/scripts/script.php?script_id=141) by Jamis Buck. It has been significantly extended over time to support external connection list files, multiple execution modes (including an embedded terminal and a Python-based background server), and interactive SQL result viewing.

> **Platform note:** The plugin uses Windows-specific commands and is designed to run on **Windows OS** only.

---

## Features

- **Connection menu** driven by an external, shareable connection list file supporting multi-level submenus
- **Three execution modes:** external CMD window, Vim's built-in terminal, or a Python background server (`sqlPlusExec.py`)
- **Execute the current file** in SQL\*Plus with a single keystroke (packages, procedures, functions, views, scripts, etc.)
- **Execute a single SQL statement** or a visual selection directly, with results displayed in a Vim buffer
- **Batch compile** all open PL/SQL buffers in dependency order, with compilation errors sent to the quickfix list
- **Table description** under the cursor via a helper SQL script
- **Interactive result buffer** — navigate query results with `Tab`/`Shift-Tab`, with the active cell highlighted
- **Dev environment auto-connect** — derives the database name from the SVN folder structure automatically
- **Status line** updates to show the active connection

---

## Requirements

- Vim (Windows)
- Oracle SQL\*Plus (`sqlplus`) available on `PATH`
- *(Optional)* Python 3 with [sqlPlusExec.py](https://github.com/domidx/sqlPlusExec-py) for the `pyserver` execution mode

---

## Installation

1. Copy `oracleExec.vim` to your Vim plugin directory (e.g. `%USERPROFILE%\vimfiles\plugin\`).
2. Create a connection list file (see [Connection List File](#connection-list-file) below).
3. Add the required configuration to your `_vimrc` (see [Configuration](#configuration)).

---

## Configuration

Add the following to your `_vimrc`. Only `g:ConnectionFile` is strictly required; all others have defaults.

```vim
" Path to your connection list file (required)
let g:ConnectionFile = 'C:\\path\\to\\vim.conlist.txt'

" Execution mode: omit this line for the default (external CMD window),
" or set to 'terminal' or 'pyserver' (see Execution Modes below).
let g:oracleExecVim_termstart = 'pyserver'

" Output format for pyserver mode (currently only 'presto' is supported by the plugin)
let g:PyServerSqlOutput = 'presto'

" Default credentials used as a fallback when no connection has been selected
let g:oracleExecVim_defaultUserName = 'myuser'
let g:oracleExecVim_defaultPwd = 'mypassword'

" Credentials used for the automatic Dev connection (see Dev Connection below)
let g:oracleExecVim_devUserName = 'devuser'
let g:oracleExecVim_devPwd = 'devpassword'

" SQL*Plus commands appended after running a PL/SQL object file.
" Shown after compilation — useful for displaying errors and pausing before exit.
" Only applies when NOT using pyserver mode (pyserver always runs 'show error').
let g:postSqlPlusCmd = ['show err', 'prompt', 'accept any char prompt "Press ENTER to exit.."', 'exit']

" Alternative: no post-commands (window closes immediately)
" let g:postSqlPlusCmd = []

" Alternative: just show errors
" let g:postSqlPlusCmd = ['show err']
```

### Configuration Variables Reference

| Variable | Default | Description |
|---|---|---|
| `g:ConnectionFile` | `''` | Full path to the connection list file. Must be set before the plugin loads. |
| `g:oracleExecVim_termstart` | *(unset)* | Execution mode. Unset = external CMD; `'terminal'` = Vim terminal; `'pyserver'` = Python server. |
| `g:PyServerSqlOutput` | `'csv'` | Output format requested from `sqlPlusExec.py`. The plugin's result viewer currently supports `'presto'` table format. |
| `g:oracleExecVim_defaultUserName` | `''` | Default Oracle username pre-populated when no connection is active. |
| `g:oracleExecVim_defaultPwd` | `''` | Default Oracle password. |
| `g:oracleExecVim_devUserName` | *(inherits default)* | Username used for the automatic Dev connection. |
| `g:oracleExecVim_devPwd` | *(inherits default)* | Password used for the automatic Dev connection. |
| `g:postSqlPlusCmd` | `[]` | List of SQL\*Plus commands appended to the run script after executing a PL/SQL object file. Applied to files with extensions `.pks`, `.pkb`, `.trg`, `.fnc`, `.prc`, `.vw`, `.tps`, `.tpb`. |

---

## Execution Modes

The plugin supports three ways to run SQL\*Plus, controlled by `g:oracleExecVim_termstart`.

### Default — External CMD Window *(no variable set)*

SQL\*Plus opens in a new Windows CMD window. Each execution spawns a fresh session. This is the original behaviour from oracle.vim.

### `'terminal'` — Vim Built-in Terminal

SQL\*Plus runs inside Vim's `:terminal`. The window closes automatically when SQL\*Plus exits (`++close`).

```vim
let g:oracleExecVim_termstart = 'terminal'
```

### `'pyserver'` — Python Background Server

SQL\*Plus runs as a persistent background process managed by [sqlPlusExec.py](https://github.com/domidx/sqlPlusExec-py). Commands are sent over named pipes; results are returned to Vim and displayed in a dedicated output buffer. This mode also enables the interactive SQL execution features (see [Running SQL Statements](#running-sql-statements)).

```vim
let g:oracleExecVim_termstart = 'pyserver'
let g:PyServerSqlOutput = 'presto'
```

`sqlPlusExec.py` must be placed in the same directory as `oracleExec.vim`.

---

## Connection List File

Instead of hardcoding connection details inside the plugin, connections are defined in a separate VimScript file that is sourced at startup. This file can be shared among team members — add or remove a connection once and everyone picks it up on the next reload.

The file must define a global variable `g:conlist` as a nested Vim list. Each entry is a list with the structure described below.

### Entry Types

**Menu entry** — opens a submenu when selected:
```vim
['m', '&MenuLabel', [ ...child entries... ]]
```

**Connection entry** — sets the active connection:
```vim
['d', '&MenuLabel', ['username', 'password', 'db_servicename']]
```

The `&` before a letter in the label makes that letter a keyboard shortcut in the menu dialog.

### Example Connection List File (`vim.conlist.txt`)

```vim
" vim.conlist.txt — Oracle connection list for oracleExec.vim

let g:conlist = [
    \ ['m', '&Production', [
    \     ['d', '&App Schema',    ['app_user',    'app_pass',    'PROD.world']],
    \     ['d', '&Report Schema', ['report_user', 'report_pass', 'PROD.world']],
    \ ]],
    \ ['m', '&UAT', [
    \     ['d', '&App Schema',    ['app_user',    'uat_pass',    'UAT.world']],
    \     ['d', '&Report Schema', ['report_user', 'uat_rpt_pass','UAT.world']],
    \ ]],
    \ ['m', '&Test', [
    \     ['m', 'Release &1', [
    \         ['d', '&App Schema',    ['app_user', 'tst_pass', 'TST1.world']],
    \         ['d', '&Report Schema', ['rpt_user', 'tst_pass', 'TST1.world']],
    \     ]],
    \     ['m', 'Release &2', [
    \         ['d', '&App Schema',    ['app_user', 'tst_pass', 'TST2.world']],
    \         ['d', '&Report Schema', ['rpt_user', 'tst_pass', 'TST2.world']],
    \     ]],
    \ ]],
    \ ['m', '&Shared Services', [
    \     ['d', '&ETL User',     ['etl_user',  'etl_pass',  'PROD.world']],
    \     ['d', '&Audit Schema', ['audit_user', 'audit_pass','PROD.world']],
    \ ]],
\ ]
```

This produces a top-level menu with four entries. Selecting **Production** or **UAT** opens a one-level submenu. Selecting **Test** opens a submenu with two further submenus (one per release), demonstrating three levels of nesting. The **Shared Services** entry shows a flat submenu with two connections.

### Hardcoded Menu Options

In addition to the entries from `g:conlist`, the connection menu always includes:

| Option | Behaviour |
|---|---|
| **dev** | Auto-connects to the dev database derived from the current file's SVN branch folder (see [Dev Connection](#dev-connection)). |
| **Other...** | Prompts you to type connection details manually (user, password, server). |
| **Reload** | Re-sources `g:ConnectionFile` to pick up any changes without restarting Vim. |

---

## Dev Connection

When working in an SVN-based folder structure, selecting **dev** from the connection menu calls `ConnectToDev()`, which walks the full path of the currently open file looking for a `branches` folder. The next path component is taken as the branch name, dots are stripped, and the resulting string is used to form the database service name as `dev<version>.world`.

For example, a file at `...\branches\3.14\app\pkg\mypackage.pkb` would connect to `dev314.world` using `g:oracleExecVim_devUserName` and `g:oracleExecVim_devPwd`.

---

## Key Mappings

All mappings use Vim's `<Leader>` key (default `\`).

| Mapping | Mode | Action |
|---|---|---|
| `<Leader>c` | Normal | Open the connection selection menu |
| `<Leader>r` | Normal/Visual | Execute the current file in SQL\*Plus |
| `<Leader>R` | Normal | Batch compile all open PL/SQL buffers (`CompAll`) |
| `<Leader>s` | Normal | Start a SQL\*Plus session without running a file |
| `<Leader>m` | Normal | Echo the active connection string to the command line |
| `<Leader>0` | Normal | Run `dsvn.sql` with the current filename (stem only) as an argument |
| `<Leader>9` | Normal | Run `dver.sql` |
| `<F9>` | Normal | Detect and execute the SQL statement under the cursor (`pyserver` mode only) |
| `<F9>` | Visual | Execute the visually selected SQL (`pyserver` mode only) |
| `<F5>` | Visual | Same as `<F9>` in visual mode |
| `<S-F4>` | Normal | Describe the table/object whose name is under the cursor |
| `<C-y>` | Normal/Insert | Paste the default register as a SQL-ready comma-separated list (strings quoted, numbers unquoted) |

### Result Buffer Mappings

When a result is displayed in the `PyServerOutputBuff` buffer:

| Mapping | Action |
|---|---|
| `Tab` | Jump to the next cell |
| `Shift-Tab` | Jump to the previous cell |
| `q` | Close the result buffer |

---

## Running SQL Statements

In `pyserver` mode, you can execute ad-hoc SQL without leaving Vim:

- **Single statement:** Place the cursor anywhere within a SQL statement (delimited by `;` or a line containing only `/`) and press `<F9>`. The plugin highlights the detected statement and sends it to SQL\*Plus.
- **Visual selection:** Select lines in Visual mode and press `<F9>` or `<F5>` to execute exactly that text.

Results are displayed in a split buffer at the bottom of the screen. SELECT results are returned in the format specified by `g:PyServerSqlOutput` (currently `presto` table format is supported). The active cell is highlighted as you navigate.

---

## Batch Compile (`CompAll`)

`<Leader>R` compiles every listed buffer in a controlled order: package specs (`.pks`) first, then functions (`.fnc`), procedures (`.prc`), package bodies (`.pkb`), generic scripts (`.sql`), with any remaining extensions appended at the end.

Compilation output is parsed for `LINE/COL ERROR` markers. Any errors found are loaded into Vim's quickfix list and the quickfix window is opened automatically so you can jump directly to the offending line in the correct file.

---

## Pasting as SQL List (`<C-y>`)

`<C-y>` in Normal or Insert mode takes whatever is in the default register (`"`) and formats it for use in a SQL `IN (...)` clause:

- Lines containing only numbers are joined as-is: `1, 2, 3`
- Lines containing any non-numeric content are wrapped in single quotes (with internal single quotes escaped): `'foo', 'bar', 'it''s'`

This is handy when you have copied a column of values from a query result and want to paste them directly into a `WHERE id IN (...)` condition.

---

## Related Project

The `pyserver` execution mode requires the companion Python script:

**[sqlPlusExec.py](https://github.com/domidx/sqlPlusExec-py)**

Place it in the same directory as `oracleExec.vim`. It manages a persistent SQL\*Plus process and communicates with Vim via named pipes.

---

## Acknowledgements

This plugin originated from **oracle.vim** by Jamis Buck, available at:
https://www.vim.org/scripts/script.php?script_id=141
