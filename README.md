# NAME

cleo - Play back shell commands for live demonstrations

# SYNOPSIS

    cleo COMMAND_FILE

# DESCRIPTION

`cleo` is a utility for playing back pre-recorded shell commands for a live
demonstration.  `cleo` displays the commands as if you had actually typed
them and then executes them interactively.

There is probably an easy way to do this with `expect` or a similar tool.
But I couldn't figure it out, so I built this.  Your mileage may vary.

# PLAYBACK CONTROLS

`cleo` always pauses and waits for a keypress before displaying a command and
before executing it.  Pressing any key besides those listed below will advance
the playback.

    Key         Action
    ------------------------------------------------------------------
    s           skips the current command
    q           quit playback

When things go wrong during the presentation, you can tell `cleo` to pause
and open a subshell so that you can fix the problem.  The subshell will have
the same environment as the playback. When you exit the subshell (usually by
typing `exit`) you will be returned to the playback.

    Key         Action
    ------------------------------------------------------------------
    ?           open subshell, then resume at current command
    !           open subshell, then resume at previous command

# COMMANDS

`cleo` reads commands from a file.  Each line is treated as one command.
Blank lines and those starting with `#` will be ignored.  The commands
theselves can be anything that you would type into an interactive shell.
You can also add a few special tokens that `cleo` recognizes:

- Commands starting with `!!!` (three exclamation points) are not echoed to the
screen and executed immediately. This is useful for running setup commands at
the beginning of your demonstration.
- Within a command, `%%%` (three percent signs) will cause `cleo` to pause and
wait for a keypress before displaying the rest of the command.  This is useful
if you want to stop in the middle of a command to give some explanation.

Otherwise, `cleo` displays and executes the commands verbatim.  Note that
some interactive commands like `vim` are picky about STDOUT and STDIN.  To
make them work properly with `cleo`, you may need to force them to attach
to the terminal like this:

    (exec < /dev/tty vim)

# EXAMPLE

I use this for giving demonstrations of [pinto](https://metacpan.org/pod/pinto), such as the one seen here
(the live demonstration starts around 10:47):

    https://www.youtube.com/watch?v=H-JkFXm8Xgk

The command file that I use for that presentation is included inside this
distribution at `example/pinto.demo`.  This file is for illustration only, so
don't expect it to actually work for you.

# TODO

- Jump to arbitrary command number
- Support backspacing in recorded command
- Support mult-line recorded commands
- Write unit tests

# AUTHOR

Jeffrey Ryan Thalhammer <thaljef@cpan.org>

# COPYRIGHT

Copyright (c) 2014, Imaginative Software Systems
