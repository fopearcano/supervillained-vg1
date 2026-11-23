# Windows host evidence for correction report 11

Fresh clone (Windows 11 25H2, `core.autocrlf=true`, PowerShell 7.7.0, Godot 4.7.2 console exe,
Node v24.15.0, pinned Chromium 153.0.8010.12) of the correction-11 code, taken before its report text
and this folder were written. The tested `godot/` tree is
`a06b1df5e3db91f0fc7690785d94932fdf6bca24`, equal to `git rev-parse <correction-11 commit>:godot`.
Every step exited 0; results are tabulated in IMPLEMENTATION_LOG.md, correction report 11.

Added for this report: `step_m` (focused ARCH-001a), `step_n` (focused DOG-008a restart case,
`test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`), `step_o` (rendered interpolation
probe, `--rendering-driver opengl3 --disable-vsync`, RTX 3090: command-level rendered evidence
accepted by the architect, not a suite result) and `step_p` (`git status --porcelain` after every
step).

Logs: each step's merged stdout/stderr; ANSI codes and carriage returns stripped, trailing spaces
and final blank lines removed, the local user name and paths replaced by placeholders.
`exit_codes.txt` has the exit code and duration of every step.
