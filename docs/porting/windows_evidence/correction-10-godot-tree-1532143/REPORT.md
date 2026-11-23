# Windows host evidence for correction report 10

Fresh clone (Windows 11 25H2, `core.autocrlf=true`, PowerShell 7.7.0, Godot 4.7.2 console exe,
Node v24.15.0, pinned Chromium 153.0.8010.12) of the correction-10 code, taken before its report text
and this folder were written. The tested `godot/` tree is
`15321434e94325b632bc38bb2a40246e0577ad08`, equal to `git rev-parse <correction-10 commit>:godot`.
Every step exited 0; results are tabulated in IMPLEMENTATION_LOG.md, correction report 10.

Logs: each step's merged stdout/stderr; ANSI codes and carriage returns stripped, trailing spaces
and final blank lines removed, the local user name and paths replaced by placeholders.
`exit_codes.txt` has the exit code and duration of every step.
