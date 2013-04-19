use Test::More qw/no_plan/;

is(1, 1, "One is one");
isnt(2, 1, "Two is not one");
like(1, qr/\d/, "One is a digit");
diag("option ",join(' ',@ARGV));

