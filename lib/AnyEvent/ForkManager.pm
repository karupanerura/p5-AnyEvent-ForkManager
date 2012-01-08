package AnyEvent::ForkManager;
use 5.008_001;
use strict;
use warnings;

our $VERSION = '0.01';

use AnyEvent;
use Proc::Wait3;
use Scalar::Util qw/weaken/;

use Class::Accessor::Lite 0.04 (
    ro  => [
        qw/max_workers manager_pid/,
    ],
    rw  => [
        qw/on_finish on_error/,
        qw/proccess_queue running_worker proccess_cb wait_async/,
    ],
);

sub default_max_workers { 10 }

sub new {
    my $class = shift;
    my $arg  = (@_ == 1) ? +shift : +{ @_ };
    $arg->{max_workers} ||= $class->default_max_workers;

    bless(+{
        on_finish => sub {},
        on_error  => sub {},
        %$arg,
        manager_pid => $$,
    } => $class)->init;
}

sub init {
    my $self = shift;

    $self->proccess_queue([]);
    $self->running_worker(+{});
    $self->proccess_cb(+{});

    return $self;
}

sub is_child { shift->manager_pid != $$ }
sub is_working_max {
    my $self = shift;

    $self->num_workers >= $self->max_workers;
}

sub num_workers {
    my $self = shift;
    return scalar keys %{ $self->running_worker };
}

sub num_queues {
    my $self = shift;
    return scalar @{ $self->proccess_queue };
}

sub start {
    my $self = shift;
    my $arg  = (@_ == 1) ? +shift : +{ @_ };

    die "\$fork_manager->start() should be called within the manager process\n"
        if $self->is_child;

    if ($self->is_working_max) {## child working max
        $self->enqueue($arg);
        return;
    }
    else {## create child process
        my $pid = fork;

        if (not(defined $pid)) {
            $self->on_error->($self, @{ $arg->{args} });
            return;
        }
        elsif ($pid) {
            # parent
            weaken($self);
            $self->proccess_cb->{$pid} = sub {
                my ($pid, $status) = @_;

                delete $self->running_worker->{$pid};
                delete $self->proccess_cb->{$pid};
                $self->on_finish->($pid, $status, @{ $arg->{args} });

                if ($self->num_queues) {
                    ## dequeue
                    $self->dequeue;
                }
            };
            $self->running_worker->{$pid} = AnyEvent->child(
                pid => $pid,
                cb  => $self->proccess_cb->{$pid},
            );

            return $pid;
        }
        else {
            # child
            $arg->{cb}->($self, @{ $arg->{args} });
            $self->finish;
        }
    }
}

sub finish {
    my ($self, $exit_code) = @_;
    die "\$fork_manager->finish() shouln't be called within the manager process\n"
        unless $self->is_child;

    exit($exit_code || 0);
}

sub enqueue {
    my($self, $arg) = @_;

    push @{ $self->proccess_queue } => $arg;
}

sub dequeue {
    my $self = shift;

    if (my $arg = shift @{ $self->proccess_queue }) {
        $self->start($arg);
    }
}

sub signal_all_children {
    my ($self, $sig) = @_;
    foreach my $pid (sort keys %{ $self->running_worker }) {
        kill $sig, $pid;
    }
}

sub wait_all_children {
    my $self = shift;
    my $arg  = (@_ == 1) ? +shift : +{ @_ };

    my $cb = $arg->{cb};
    if ($arg->{blocking}) {
        until ($self->num_workers == 0 and $self->num_queues == 0) {
            if (my ($pid, $status) = Proc::Wait3::wait3(1)) {
                if (my $cb = $self->proccess_cb->{$pid}) {
                    $cb->($pid, $status);
                }
            }
        }
        $self->$cb;
    }
    else {
        die 'cannot call.' if $self->wait_async;

        my $super = $self->on_finish;

        weaken($self);
        $self->on_finish(
            sub {
                $super->(@_);
                if ($self->num_workers == 0 and $self->num_queues == 0) {
                    $self->$cb;
                    $self->on_finish($super);
                    $self->wait_async(0);
                }
            }
        );

        $self->wait_async(1);
    }
}

1;
__END__

=head1 NAME

AnyEvent::ForkManager - A simple parallel processing fork manager with AnyEvent

=head1 VERSION

This document describes AnyEvent::ForkManager version 0.01.

=head1 SYNOPSIS

    use AnyEvent;
    use AnyEvent::ForkManager;

    my $MAX_WORKERS = 10;
    my $pm = AnyEvent::ForkManager->new(max_workers => $MAX_WORKERS);

    use List::MoreUtils qw/shuffle/;
    my @all_data = shuffle(1 .. 100);
    foreach $data (@all_data) {
        $pm->start(
            cb => sub {
                my($pm, $data) = @_;
                # ... do some work with $data in the child process ...
            },
            args => [$data]
        );
    }

    my $wait_blocking = 1;
    if ($wait_blocking) {
        # wait with blocking
        $pm->wait_all_children(
            cb => sub {
                my($pm) = @_;
                $cv->send;
            },
            blocking => 1,
        );
    }
    else {
        my $cv = AnyEvent->condvar;

        # wait with non-blocking
        $pm->wait_all_children(
            cb => sub {
                my($pm) = @_;
                $cv->send;
            },
        );

        $cv->recv;
    }

=head1 DESCRIPTION

# TODO

=head1 INTERFACE

=head2 Methods

=head3 C<< new >>

# TODO

=head3 C<< start >>

# TODO

=head3 C<< wait_all_children >>

# TODO

=head3 C<< signal_all_children >>

# TODO

=head3 C<< on_error >>

# TODO

=head3 C<< on_finish >>

# TODO

=head1 DEPENDENCIES

Perl 5.8.1 or later.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

L<AnyEvent>
L<AnyEvent::Util>
L<Parallel::ForkManager>
L<Parallel::Prefork>

=head1 AUTHOR

Kenta Sato E<lt>karupa@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012, Kenta Sato. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
