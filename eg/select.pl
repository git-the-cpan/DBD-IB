#!/usr/bin/perl -w
require 5.004;

use blib;
use DBI;

=head1 NAME

DBI Simple Example to connect, fetch and print some values

=head1 SYNOPSIS

A very simple example to connect, fetch, and print values from a database.  This version prints the
output in a more report like format.  See the format specifier in the help
or Page 121-124 of Programming Perl, 2nd edition.

 Table SIMPLE 
 	 person_id integer not null,	
 	 person varchar(50) 
 	,comment varchar(200)

=head1 USES

DBI methods used:
	connect
	prepare
	execute
	fetchrow_array

Note: this program uses the "new" style connect which enables C<$dbh->{PrintError}>, C<$dbh->{AutoCommit}>.  
For simplicity, C<$h->{RaiseError}> is turned on, which causes a "die", if any significant errors occur.

$dbh is short for Database Handle
$cursor is the statement handle used for the select
@row is the array with the columns from the select 

=head1 REFERENCES

Programming Perl, 2nd edition.  Printed by O'Reilly & Associates, Inc.  
Authors: Larry Wall, Tom Christiansen & Randal L. Schwartz

=cut

$dbpath = '/home/edwin/proj/DBI/perl_example.gdb';
$dbh = DBI->connect("dbi:IB:database=$dbpath") or die $DBI::errstr;

$cursor = $dbh->prepare("SELECT * FROM SIMPLE ORDER BY PERSON_ID");
$cursor->execute;

format STDOUT_TOP =
  ID PERSON                    COMMENT
----------------------------------------------------------
.

format STDOUT =
@>>> @<<<<<<<<<<<<<<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<<<<<
$row[0],$row[1],$row[2]
~~                             ^<<<<<<<<<<<<<<<<<<<<<<<<<<              
$row[2]

.

while (@row = $cursor->fetchrow_array) {
	write;
}

$dbh->disconnect;
__END__
