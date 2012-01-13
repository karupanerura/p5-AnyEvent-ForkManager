use strict;
use warnings;
use utf8;

use AnyEvent::ForkManager;

my $MAX_WORKERS = 10;
my $pm = AnyEvent::ForkManager->new(max_workers => $MAX_WORKERS);

use List::Util qw/shuffle/;
my @all_data = shuffle(1 .. $MAX_WORKERS);
foreach my $data (@all_data) {
    $pm->start(
        cb => sub {
            my($pm, $data) = @_;
            sleep $data;
            printf("Sleeped %d sec.\n", $data);
            my $exit_code = $data;
            printf("  Exit code = %d\n", $exit_code);
            $pm->finish($exit_code);
        },
        args => [$data]
    );
}

$pm->on_finish(sub{
    my($pm, $pid, $status, $data) = @_;

    printf("finished child proccess. {pid => %d, status => %d, sleep_time => %d}\n", $pid, $status >> 8, $data);
});
$pm->on_error(sub{
    my($pm, $data) = @_;

    printf("fork failed. on dispatch %d. object => %s.}\n", $data, $pm);
});

$pm->wait_all_children(
    cb => sub {
        my($pm) = @_;
        warn 'called';
    },
    blocking => 1,
);
warn 'end';
