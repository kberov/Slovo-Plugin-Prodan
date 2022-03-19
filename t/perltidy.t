use Mojo::Base -strict, -signatures;
use Mojo::File 'path';
use Test::More;

eval { require Test::PerlTidy; } or do {
  plan(skip_all => 'Test::PerlTidy required to criticise code');
};

unless ($ENV{TEST_AUTHOR}) {
  plan(skip_all => 'Set $ENV{TEST_AUTHOR} to a true value to run this test.');
}

my $ROOT = path(__FILE__)->dirname->dirname->to_string;
Test::PerlTidy::run_tests(

  #debug      => 1,
  path       => $ROOT,
  exclude    => ['local/', 'blib/', 'data/', 'lib/perl5/', 'domove'],
  perltidyrc => "$ROOT/.perltidyrc"
);

