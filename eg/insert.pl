#!/usr/bin/perl -w
require 5.004;

use blib;
use DBI;

$dbpath = 'test.gdb';
#DBI->trace(2, "./insert.trace");
$dbh = DBI->connect("dbi:IB:database=$dbpath",'','') 
    or die $DBI::errstr;

@params = ([1, "Tim Bunce", "Creator of DBI"],
           [2, "Jonathan Leffler", "Creator of DBD::Informix"],
           [3, "Larry Wall", "Creator of Perl"],
           [4, "Steven Haryanto", 'Bandung main mangler :-)'],

           [6, "Yustina Sri Suharini", 'My fiance']);
#          [5, "Gurusamy Sarathy", 'Main porter'],
$sql = "insert into SIMPLE values (?, ?, ?)";
$cursor = $dbh->prepare($sql) or die $dbh->errstr;

print "Inserting records...\n";
for (@params)
{
    $cursor->execute(${@$_}[0], ${@$_}[1], ${@$_}[2])
        or die $dbh->errstr;
}
#print "Jumlah baris terpengaruh: ", $cursor->rows, "\n";
print "Finished.\n";
$dbh->disconnect or warn $dbh->errstr;

__END__
