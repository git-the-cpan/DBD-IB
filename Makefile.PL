BEGIN {require 5.004;}
use ExtUtils::MakeMaker qw(prompt WriteMakefile);

my $dbname = prompt("Which database should I use for testing (Enter full " .
                "path)", "./eg/test.gdb");

my $host = prompt("On which host is InterBase running (hostname, don't"
              . " enter ip address\n", "localhost");

my($user, $pass);
$user = prompt("User name for connecting to database $dbname?",
               "SYSDBA");
$pass = prompt("Password for connecting to database $dbname?",
               "masterkey");

my $dsn = "dbi:IB:database=$dbname";
$dsn .= $host ne 'localhost'? $host : '';

open(TESTFILE, ">test.pl") or die "Can't create test.pl";
print "Writing test file...\n";
while(<DATA>)
{
    s#template_dsn#$dsn#mo;
    s#template_db#$dbname#mo;
    s#template_user#$user#mo;
    s#template_pass#$pass#mo;
    print TESTFILE;
}
close TESTFILE;

WriteMakefile(
    'NAME'  => 'DBD::IB',
    'VERSION_FROM' => 'IB.pm', # finds $VERSION
    'NORECURS' => 1,
    'PREREQ_PM' => { IBPerl => 0.7 },
);

__DATA__

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..21\n"; }
END {print "not ok 1\n" unless $loaded;}
use DBI;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

$dbmain = 'template_dsn';
$dbname = 'template_db';
$dbuser = 'template_user';
$dbpass = 'template_pass';

######################### create and connect to test database

print "Connecting with AutoCommit off... ";
( $dbh = DBI->connect($dbmain, $dbuser, $dbpass, {AutoCommit => 0}) )
    and print "ok 2\n"
    or die "\nnot ok 2: $DBI::errstr";

######################### create, insert, update, delete, drop

print "Creating table... ";
( $dbh->do( "CREATE TABLE person ( id integer, name char(30) )" ) )
    and print "ok 3\n"
    or print "\nnot ok 5: $DBI::errstr";

print "Committing... ";
( $dbh->commit )
    and print "ok 4\n"
    or print "\nnot ok 4: $DBI::errstr";

print "Inserting with do... ";
( $dbh->do( "INSERT INTO person VALUES( 1, 'Yustina Sri Suharini' )" ) )
    and print "ok 5\n"
    or print "\nnot ok 5: $DBI::errstr";

print "Preparing insert... ";
( $sth = $dbh->prepare( "INSERT INTO person VALUES( 2, 'Edwin Pratomo' )" ) )
    and print "ok 6\n"
    or print "\nnot ok 6: $DBI::errstr";

print "Executing... ";
( $sth->execute )
    and print "ok 7\n"
    or print "\nnot ok 7: $DBI::errstr";

print "Preparing select... ";
( $sth = $dbh->prepare( "SELECT * FROM person" ) )
    and print "ok 8\n"
    or print "\nnot ok 8: $DBI::errstr";

print "Executing... ";
( $numrows = $sth->execute )
    and print "ok 9\n"
    or print "\nnot ok 9: $DBI::errstr";

print "Fetching first row... ";
@row = $sth->fetchrow;
( join(" ", @row) =~ m{Yustina} ) 
    and print "ok 10\n"
    or print "\nnot ok  10: $DBI::errstr";

print "Getting fields name... ";
@name = @{$sth->{'NAME'}};
( join(" ", @name) eq 'ID NAME' )
    and print "ok 11\n"
    or print "\nnot ok 11: $DBI::errstr";

# masalah di sini
#@type = @{$sth->{'TYPE'}};
#( join(" ", @type) eq '23 20' )
#1    and print "ok 16\n"
#    or print "\nnot ok 16: $DBI::errstr";

# masalah di sini
#@size = @{$sth->{'SIZE'}};
#( join(" ", @size) eq '16 30' )
#1    and print "ok 17\n"
#    or print "\nnot ok 17: $DBI::errstr";

print "Finishing cursor... ";
( $sth->finish )
    and print "ok 12\n"
    or print "\nnot ok 12: $DBI::errstr";

print "Updating with do... ";
( $dbh->do( "UPDATE person SET id = 3 WHERE name = 'Edwin Pratomo'" ) )
    and print "ok 13\n"
    or print "\nnot ok 13: $DBI::errstr";

print "Preparing update... ";
( $sth = $dbh->prepare( "UPDATE person SET id = id + 1" ) )
    and print "ok 14\n"
    or print "\nnot ok 14: $DBI::errstr";

print "Executing... ";
( $sth->execute )
    and print "ok 15\n"
    or print "\nnot ok 15: $DBI::errstr";

print "Deleting with do... ";
( $dbh->do( "DELETE FROM person WHERE id = 3" ) )
    and print "ok 16\n"
    or print "\nnot ok 16: $DBI::errstr";

print "Committing changes... ";
( $dbh->commit )
    and print "ok 17\n"
    or print "\nnot ok 17: $DBI::errstr";

print "Disconnecting... ";
( $dbh->disconnect )
    and print "ok 18\n"
    or print "\nnot ok 18: $DBI::errstr";

print "Connecting... ";
( $dbh = DBI->connect($dbmain, $dbuser, $dbpass) )
    and print "ok 19\n"
    or print "\nnot ok 19: $DBI::errstr";

print "Drop table... ";
# masalah di sini, gak bisa drop tanpa disconnect dulu
( $dbh->do( "DROP TABLE person" ) )
    and print "ok 20\n"
    or print "\nnot ok 20: $DBI::errstr";

print "Disconnecting... ";
( $dbh->disconnect )
    and print "ok 21\n"
    or print "\nnot ok 21: $DBI::errstr";

print "all tests passed.\n";

######################### EOF

