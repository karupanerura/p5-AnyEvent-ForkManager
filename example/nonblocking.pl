use AnyEvent;
use AnyEvent::ForkManager;

my $MAX_WORKERS = 10;
my $pm = AnyEvent::ForkManager->new(max_workers => $MAX_WORKERS);

use List::Util qw/shuffle/;
my @all_data = shuffle(1 .. 10);
foreach $data (@all_data) {
    $pm->start(
        cb => sub {
            my($pm, $data) = @_;
            sleep $data;
            printf("Sleeped %d sec.\n", $data);
        },
        args => [$data]
    );
}

my $cv = AnyEvent->condvar;
$pm->wait_all_children(
    cb => sub {
        my($pm) = @_;
        warn 'called';
        $cv->send;
    },
);
$cv->recv;
warn 'end';
