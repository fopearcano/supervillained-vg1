# Windows host evidence for correction report 9

Fresh clone (Windows 11 25H2, `core.autocrlf=true`, PowerShell 7.7.0, Godot 4.7.2 console exe,
Node v24.15.0, pinned Chromium 153.0.8010.12) of the correction-9 code, taken before its report text
and this folder were written. The tested `godot/` tree is
`6a3c53bb9bf2c0cfc14e9c569ec03015543b914c`, equal to `git rev-parse <correction-9 commit>:godot`.
Every step exited 0; results are tabulated in IMPLEMENTATION_LOG.md, correction report 9.

Logs: each step's merged stdout/stderr; ANSI codes and carriage returns stripped, trailing spaces
and final blank lines removed, the local user name and paths replaced by placeholders.
`exit_codes.txt` has the exit code and duration of every step.
