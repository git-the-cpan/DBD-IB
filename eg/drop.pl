#!/usr/bin/perl -w

use blib;
use DBI;

$dsn = 'dbi:IB:database=/home/edwin/proj/DBD/DBD-IB-0.02/test.gdb';
$dbh = DBI->connect($dsn, '', '', {RaiseError => 1})
	or die "$DBI::errstr";
$stmt = "drop table PERSON";
$dbh->do($stmt);
$dbh->disconnect;
