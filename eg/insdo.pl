#!/usr/bin/perl -w
require 5.004;

use blib;
use DBI;

$dbpath = '/home/edwin/proj/DBI/perl_example.gdb';
DBI->trace(2, "./insdo.trace");
$dbh = DBI->connect("dbi:IB:database=$dbpath",'','', {AutoCommit => 0}) 
	or die $DBI::errstr;
#,{AutoCommit => 1}) 
#	or die $DBI::errstr;

$sql = 'insert into SIMPLE values (5, "Gurusamy Sarathy",
		"Main porter")';
$dbh->do($sql) or die $dbh->errstr;

$dbh->commit;
$dbh->disconnect or warn $dbh->errstr;

print "Added one record.\n";
__END__
