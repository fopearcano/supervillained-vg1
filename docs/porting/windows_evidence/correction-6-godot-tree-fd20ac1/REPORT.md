# Windows host evidence for correction report 6

Fresh clone (Windows 11 25H2, `core.autocrlf=true`, PowerShell 7.7.0, Godot 4.7.2 console exe,
Node v24.15.0, pinned Chromium 153.0.8010.12) of the correction-6 code, taken before its report
table and this folder were written. The tested `godot/` tree is
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`, equal to `git rev-parse <correction-6 commit>:godot`.
Every step exited 0; results are tabulated in IMPLEMENTATION_LOG.md, correction report 6.

Logs: each step's merged stdout/stderr; ANSI codes and carriage returns stripped, trailing spaces
and final blank lines removed, the local user name and paths replaced by placeholders.
`exit_codes.txt` has the exit code and duration of every step.
