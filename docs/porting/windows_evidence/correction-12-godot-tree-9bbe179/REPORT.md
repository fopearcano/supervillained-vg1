# Windows host evidence for correction report 12

Fresh clone (Windows 11 25H2, `core.autocrlf=true`, PowerShell 7.7.0, Godot 4.7.2 console exe,
Node v24.15.0, pinned Chromium 153.0.8010.12) of the correction-12 code, taken before its report text
and this folder were written. The tested `godot/` tree is
`9bbe179546b3b600340eebe26fc364d64abd933c`, equal to `git rev-parse <correction-12 commit>:godot`.
Every step exited 0; results are tabulated in IMPLEMENTATION_LOG.md, correction report 12.

Steps as in correction report 11: `step_m` (focused ARCH-001a), `step_n` (focused DOG-008a restart
case, `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`; its resets are recorded in
the entry process frame, before the test's next awaited frame, with no rendered frame read back),
`step_o` (the unchanged rendered interpolation probe, `--rendering-driver opengl3 --disable-vsync`,
RTX 3090: **supplemental command evidence** only, it satisfies no rendered clause, and not a suite
result) and `step_p` (`git status --porcelain` after every step).

Logs: each step's merged stdout/stderr; ANSI codes and carriage returns stripped, trailing spaces
and final blank lines removed, the local user name and paths replaced by placeholders.
`exit_codes.txt` has the exit code and duration of every step.
