use Test::More qw/no_plan/;

is(2, 2, "two is two");
isnt(1, 2, "One is not two");
like(2, qr/\d/, "Two is a digit");
diag("option",join(' ',@ARGV));

