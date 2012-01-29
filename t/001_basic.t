#!perl -w
use strict;
use Test::More;
use Test::SharedFork;

use AnyEvent;
use AnyEvent::ForkManager;
use Time::HiRes;

my $MAX_WORKERS = 4;
my $JOB_COUNT   = $MAX_WORKERS * 5;
my $TEST_COUNT  =
    ($JOB_COUNT)     + # in child process tests
    ($JOB_COUNT)     + # start method is non-blocking tests
    ($JOB_COUNT * 2) + # on_start
    ($JOB_COUNT * 3) + # on_finish
    ($JOB_COUNT > $MAX_WORKERS ? (($JOB_COUNT - $MAX_WORKERS) * 2) : 0) + # on_enqueue
    ($JOB_COUNT > $MAX_WORKERS ? (($JOB_COUNT - $MAX_WORKERS) * 2) : 0) + # on_dequeue
    ($JOB_COUNT > $MAX_WORKERS ? (($JOB_COUNT - $MAX_WORKERS) * 2) : 0) + # on_working_max
    4;# wait_all_children
plan tests => $TEST_COUNT;

my $pm = AnyEvent::ForkManager->new(
    max_workers => $MAX_WORKERS,
    on_start    => sub{
        my($pm, $pid, $exit_code) = @_;

        cmp_ok $pm->num_workers, '<', $pm->max_workers, 'not working max';
        is $$, $pm->manager_pid, 'called by manager';
    },
    on_finish => sub{
        my($pm, $pid, $status, $exit_code) = @_;

        is $status >> 8, $exit_code, 'status';
        cmp_ok $pm->num_workers, '<', $pm->max_workers, 'not working max';
        is $$, $pm->manager_pid, 'called by manager';
    },
    on_enqueue => sub{
        my($pm, $exit_code) = @_;

        is $pm->num_workers, $pm->max_workers, 'working max';
        is $$, $pm->manager_pid, 'called by manager';
    },
    on_dequeue => sub{
        my($pm, $exit_code) = @_;

        cmp_ok $pm->num_workers, '<', $pm->max_workers, 'not working max';
        is $$, $pm->manager_pid, 'called by manager';
    },
    on_working_max => sub{
        my($pm, $exit_code) = @_;

        is $pm->num_workers, $pm->max_workers, 'working max';
        is $$, $pm->manager_pid, 'called by manager';
    }
);

my $cv = AnyEvent->condvar;

my @all_data = (1 .. $JOB_COUNT);
foreach my $exit_code (@all_data) {
    select undef, undef, undef, 0.07;
    my $start_time = Time::HiRes::gettimeofday;
    $pm->start(
        cb => sub {
            my($pm, $exit_code) = @_;
            select undef, undef, undef, 0.5;
            isnt $$, $pm->manager_pid, 'called by child';
            $pm->finish($exit_code);
            fail 'finish failed';
        },
        args => [$exit_code]
    );
    my $end_time = Time::HiRes::gettimeofday;
    cmp_ok $end_time - $start_time, '<', 0.1, 'non-blocking';
}

my $start_time = Time::HiRes::gettimeofday;
$pm->wait_all_children(
    cb => sub {
        my($pm) = @_;
        is $$, $pm->manager_pid, 'called by manager';
        is $pm->num_workers, 0, 'finished all child process';
        is $pm->num_queues,  0, 'empty all child process queue';
        $cv->send;
    },
);
my $end_time = Time::HiRes::gettimeofday;
cmp_ok $end_time - $start_time, '<', 0.1, 'non-blocking';

$cv->recv;
