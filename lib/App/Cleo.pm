package App::Cleo;

use strict;
use warnings;

use Term::ReadKey;
use Term::ANSIColor qw(colored);
use File::Slurp qw(read_file);
use Time::HiRes qw(usleep);

our $VERSION = 0.001;

#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $self = {
        shell  => $ENV{SHELL} || '/bin/bash',
        prompt => colored( ['green'], '(%d)$ '),
        delay  => 25000,
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

    my $cmd_is_finished;
    $SIG{ALRM} = sub {$cmd_is_finished = 1};

    open my $shell, '|-', $self->{shell} or die $!;
    ReadMode('raw');
    local $| = 1;

    chomp @commands;
    @commands = grep { /^\s*[^\#;]\S+/ } @commands;

    CMD:
    for (my $i = 0; $i <= @commands; $i++) {

        my $cmd = $commands[$i];
        chomp $cmd;

        goto RUN if $cmd =~ s/^!!!//;

        print sprintf $self->{prompt}, $i;

        my @steps = split /%%%/, $cmd;
        while (my $step = shift @steps) {

            my $key = ReadKey(0);

            last CMD                             if $key eq 'q';
            print "\n"        and next CMD       if $key eq 's';
            $self->subshell   and redo CMD       if $key eq '?';
            $self->subshell   and $i--, redo CMD if $key eq '!';


            $step .= ' ' if not @steps;
            my @chars = split '', $step;
            print and usleep $self->{delay} for @chars;
        }

        my $key = ReadKey(0);
        print "\n";

        last CMD                           if $key eq 'q';
        next CMD                           if $key eq 's';
        $self->subshell and redo CMD       if $key eq '?';
        $self->subshell and $i--, redo CMD if $key eq '!';

        RUN:
        $cmd =~ s/%%%//g;
        print $shell "$cmd\n";
        print $shell "kill -14 $$\n";
        $shell->flush;

        # Wait for signal that command has ended
        until ($cmd_is_finished) {}
        $cmd_is_finished = 0;
    }

    ReadMode('restore');
    print "\n";

    return $self;
}

#-----------------------------------------------------------------------------

sub subshell {
    my ($self) = @_;

    print "\n";

    ReadMode('restore');
    print "Entering subshell...\n";
    system $self->{shell};
    print "Returning to cleo...\n";
    ReadMode('raw');

    return 1;
}

#-----------------------------------------------------------------------------
1;

=pod

=head1 NAME

App::Cleo - Playback shell commands for live demonstrations

=head1 SYNOPSIS

  use App::Cleo
  my $cleo = App::Cleo->new(%options);
  $cleo->run($commands);

=head1 DESCRIPTION

App::Cleo is the backend for the L<cleo> utility.  Please see the L<cleo>
documentation for details on how to use this.

=head1 CONSTRUCTOR

The constructor accepts arguments as key-value pairs.  The following keys are
supported:

=over 4

=item delay

Number of miliseconds to wait before displaying each character of the command.
The default is C<25_000>.

=item prompt

String to use for the artificial prompt.  Consider using L<Term::ANSIColor> to
make it pretty.  The default is a green C<$>.

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