#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Deep;
use Redis::hiredis;
use Try::Tiny;
use MapReduce;

my $redis = Redis::hiredis->new(utf8 => 0);

$redis->connect('127.0.0.1', 6379);
$redis->select(9);
$redis->flushdb();

my $mr = MapReduce->new(
    name => 'test-single-process',
    
    mapper => sub {
        my ($self, $input) = @_;
        
        $input->{value} *= 2;
        
        return $input;
    },
    
    reducer => sub {
        my ($self, $nums) = @_;
        
        my %seen;
        
        return [ grep { !$seen{ $_->{value} }++ } @$nums ];
    }
);

# Load up some numbers to feed into our map-reduce functions
my $inputs = [ map {{ key => $_, value => $_ }} 5, 2, 3, 4, 1 ];

$mr->inputs($inputs);

local $SIG{ALRM} = sub { die 'Timeout' };

alarm 3;

my $results;

try {
    $results = $mr->all_results;

    my @values  = map { $_->{value} } @$results;

    cmp_deeply \@values, bag(2, 4, 6, 8, 10), 'Got all results from map-reduce operation';

    ok !defined $mr->next_result(), 'No more results, so we get undefined';
    ok !defined $mr->next_result(), 'No more results, so we get undefined';
    ok !defined $mr->next_result(), 'No more results, so we get undefined';
}
catch {
    fail $_;
};

alarm 0;

done_testing;

