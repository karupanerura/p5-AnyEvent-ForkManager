requires 'AnyEvent';
requires 'Class::Accessor::Lite', '0.04';
requires 'POSIX';
requires 'Scalar::Util';
requires 'Time::HiRes';
requires 'perl', '5.008001';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'Test::More', '0.88';
    requires 'Test::SharedFork';
    requires 'Time::HiRes';
};
