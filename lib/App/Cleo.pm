package App::Cleo;

use strict;
use warnings;

use Term::ReadKey;
use Term::ANSIColor qw(colored);
use File::Slurp qw(read_file);
use Time::HiRes qw(usleep);

use constant PS1 => 'ps1';
use constant PS2 => 'ps2';
our $VERSION = 0.004;

#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $self = {
        shell  => $ENV{SHELL} || '/bin/bash',
        ps1    => colored( ['green'], '(%d)$ '),
        ps2    => colored( ['green'], '> '),
        delay  => 25_000,
        state  => PS1,
        @_,
    };

    return bless $self, $class;
}

#-----------------------------------------------------------------------------

sub run {
    my ($self, $commands) = @_;

    my $type = ref $commands;
    my @commands = !$type ? read_file($commands)
        : $type eq 'SCALAR' ? split "\n", ${$commands}
            : $type eq 'ARRAY' ? @{$commands}
                : die "Unsupported type: $type";

    open my $fh, '|-', $self->{shell} or die $!;
    $self->{fh} = $fh;
    ReadMode('raw');
    local $| = 1;

    local $SIG{CHLD} = sub {
        print "Child shell exited!\n";
        ReadMode('restore');
        exit;
    };

    chomp @commands;
    @commands = grep { /^\s*[^\#;]\S+/ } @commands;

    my $continue_to_end = 0;

    CMD:
    for (my $i = 0; $i < @commands; $i++) {

        my $cmd = defined $commands[$i] ? $commands[$i] : die "no command $i";
        chomp $cmd;

        my $keep_going = $cmd =~ s/^\.\.\.//;
        my $run_in_background = $cmd =~ s/^!!!//;

        $self->do_cmd($cmd) and next CMD
            if $run_in_background;

        no warnings 'redundant';
        my $prompt_state = $self->{state};
        print sprintf $self->{$prompt_state}, $i;

        my @steps = split /%%%/, $cmd;
        while (my $step = shift @steps) {

            my $should_pause = !($keep_going || $continue_to_end);
            my $key  = $should_pause ? ReadKey(0) : '';
               $key .= ReadKey(0) while ($key =~ /^\d+\z/);
            print "\n" if $key =~ m/[srp0-9]/;

            last CMD             if $key eq 'q';
            next CMD             if $key eq 's';
            redo CMD             if $key eq 'r';
            $i--, redo CMD       if $key eq 'p';
            $i = $key, redo CMD  if $key =~ /\d/;
            $continue_to_end = 1 if $key eq 'c';

            $step .= ' ' if not @steps;
            my @chars = split '', $step;
            print and usleep $self->{delay} for @chars;
        }

        my $should_pause = !($keep_going || $continue_to_end);
        my $key  = $should_pause ? ReadKey(0) : '';
           $key .= ReadKey(0) while ($key =~ /^\d+\z/);
        print "\n";

        last CMD             if $key eq 'q';
        next CMD             if $key eq 's';
        redo CMD             if $key eq 'r';
        $i--, redo CMD       if $key eq 'p';
        $i = $key, redo CMD  if $key =~ /\d/;
        $continue_to_end = 1 if $key eq 'c';

        $self->do_cmd($cmd);
    }

    ReadMode('restore');
    print "\n";

    return $self;
}

#-----------------------------------------------------------------------------

sub do_cmd {
    my ($self, $cmd) = @_;

    my $cmd_is_finished;
    local $SIG{ALRM} = sub {$cmd_is_finished = 1};

    $cmd =~ s/%%%//g;
    my $fh = $self->{fh};

    print $fh "$cmd\n";

    ($self->{state} = PS2) and return 1
        if $cmd =~ m{\s+\\$};

    print $fh "kill -14 $$\n";
    $fh->flush;

    # Wait for signal that command has ended
    until ($cmd_is_finished) {}
    $cmd_is_finished = 0;

    $self->{state} = PS1;

    return 1;
}

#-----------------------------------------------------------------------------
1;

=pod

=head1 NAME

App::Cleo - Play back shell commands for live demonstrations

=head1 SYNOPSIS

  use App::Cleo
  my $cleo = App::Cleo->new(%options);
  $cleo->run($commands);

=head1 DESCRIPTION

App::Cleo is the back-end for the L<cleo> utility.  Please see the L<cleo>
documentation for details on how to use this.

=head1 CONSTRUCTOR

The constructor accepts arguments as key-value pairs.  The following keys are
supported:

=over 4

=item delay

Number of microseconds to wait before displaying each character of the command.
The default is C<25_000>.

=item ps1

String to use for the artificial prompt.  The token C<%d> will be substituted
with the number of the current command.  The default is C<(%d)$>.

=item ps2

String to use for the artificial prompt that appears for multiline commands. The
token C<%d> will be substituted with the number of the current command.  The
default is C<< > >>.

=item shell

Path to the shell command that will be used to run the commands.  Defaults to
either the C<SHELL> environment variable or C</bin/bash>.

=back

=head1 METHODS

=over 4

=item run( $commands )

Starts playback of commands.  If the argument is a string, it will be treated
as a file name and commands will be read from the file. If the argument is a
scalar reference, it will be treated as a string of commands separated by
newlines.  If the argument is an array reference, then each element of the
array will be treated as a command.

=back

=head1 AUTHOR

Jeffrey Ryan Thalhammer <thaljef@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2014, Imaginative Software Systems

=cut
