#!/usr/bin/perl -w 

use IBPerl;
use strict;

my $DBPATH='../test.gdb',

my ($tr, $db);

sub komit
{
    print "Committing... ";
    if ($tr->commit() < 0)
    {
    print STDERR "Commit Error:\n$tr->{'Error'}\n";
    print "not ok\n"; # Test 7
    exit 1;
    }
    print "ok\n"; # Test 7
}

sub new_trans
{
    $tr = new IBPerl::Transaction(Database=>$db);
    if ($tr->{'Handle'} < 0)
    {
    print STDERR "Transaction Error:\n$tr->{'Error'}\n";
    print "not ok\n"; # Test 2
    exit 1;
    }
    print "ok\n"; # Test 2
}

$db = new IBPerl::Connection(
    Path=>"$DBPATH",
    User=>'sysdba', Password=>'masterkey');

if ($db->{'Handle'} < 0)
{
    print STDERR "Connection Error:\n$db->{'Error'}\n";
    print "not ok\n"; # Test 1
    exit 1;
}
print "ok\n"; # Test 1

######################################################################

    $tr = new IBPerl::Transaction(Database=>$db);
    if ($tr->{'Handle'} < 0)
    {
    print STDERR "Transaction Error:\n$tr->{'Error'}\n";
    print "not ok\n"; # Test 2
    exit 1;
    }
    print "ok\n"; # Test 2

    ######################################################################

my $stmt = "create table trivial (id integer)";
    my $st = new IBPerl::Statement(Transaction=>$tr,
        Stmt=>$stmt);
    if ($st->{'Handle'} < 0)
    {
        print STDERR "Statement Error:\n$st->{'Error'}\n";
        print "not ok\n"; # Test 3
        exit 1;
    }

    if ($st->execute == 0)
    {
        print "ok\n"; # Test 4
    } else {
        print STDERR "Statement Error:\n$st->{'Error'}\n";
        print "not ok\n"; # Test 4
        exit 1;
    }

    ######################################################################

    print "Committing... ";
    if ($tr->commit() < 0)
    {
    print STDERR "Commit Error:\n$tr->{'Error'}\n";
    print "not ok\n"; # Test 7
    exit 1;
    }

new_trans();
{
my $tmt = "insert into trivial values(1)";
my  $sth = new IBPerl::Statement(Transaction=>$tr,
        Stmt=>$tmt);
    if ($sth->{'Handle'} < 0)
    {
        print STDERR "Statement Error:\n$sth->{'Error'}\n";
        print "not ok\n"; # Test 3
        exit 1;
    }

    if ($sth->execute == 0)
    {
        print "ok\n"; # Test 4
    } else {
        print STDERR "Statement Error:\n$sth->{'Error'}\n";
        print "not ok\n"; # Test 4
        exit 1;
    }


$tmt = "insert into trivial values(2)";
    $sth = new IBPerl::Statement(Transaction=>$tr,
        Stmt=>$tmt);
    if ($sth->{'Handle'} < 0)
    {
        print STDERR "Statement Error:\n$sth->{'Error'}\n";
        print "not ok\n"; # Test 3
        exit 1;
    }

    if ($sth->execute == 0)
    {
        print "ok\n"; # Test 4
    } else {
        print STDERR "Statement Error:\n$sth->{'Error'}\n";
        print "not ok\n"; # Test 4
        exit 1;
    }
}
komit();
new_trans();

$st = undef;
$stmt = "drop table trivial";
    $st = new IBPerl::Statement(Transaction=>$tr,
        Stmt=>$stmt);
    if ($st->{'Handle'} < 0)
    {
        print STDERR "Statement Error:\n$st->{'Error'}\n";
        print "not ok\n"; # Test 3
        exit 1;
    }

    if ($st->execute == 0)
    {
        print "ok\n"; # Test 4
    } else {
        print STDERR "Statement Error:\n$st->{'Error'}\n";
        print "not ok\n"; # Test 4
        exit 1;
    }

komit();
new_trans();

######################################################################

print "Disconnecting... ";
if ($db->disconnect() < 0)
{
    print STDERR "Connection Error:\n$tr->{'Error'}\n";
    print "not ok\n"; # Test 8
    exit 1;
}
print "ok\n"; # Test 8

######################################################################

exit 0;
