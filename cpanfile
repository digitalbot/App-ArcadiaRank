requires 'perl', '>= 5.010';

requires 'Web::Query';
requires 'Coro';
requires 'Coro::LWP';
requires 'Getopt::Long';
requires 'Encode';

on 'test' => sub {
    requires 'Test::More', '0.98';
};
