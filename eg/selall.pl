#!/usr/bin/perl -w
require 5.004;

use blib;
use DBI;

$dbpath = 'test.gdb';
$dbh = DBI->connect("dbi:IB:database=$dbpath") or die $DBI::errstr;

$stmt = "SELECT * FROM SIMPLE ORDER BY PERSON_ID";

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

$array_ref = $dbh->selectall_arrayref($stmt);

for (@{$array_ref}) {
    @row = @{$_};
    write;
}

$dbh->disconnect;

