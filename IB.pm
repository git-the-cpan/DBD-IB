#$Id: IB.pm,v 1.14 1999/09/19 07:14:10 edwin Exp $

use strict;

use Carp;
use IBPerl;

package DBD::IB;

use vars qw($VERSION $err $errstr $drh);

$VERSION = '0.021';

$err = 0;
$errstr = "";
$drh = undef;

sub driver
{
    return $drh if $drh;
    my($class, $attr) = @_;

    $class .= "::dr";

    $drh = DBI::_new_drh($class, { 'Name' => 'IB',
                   'Version' => $VERSION,
                   'Err'    => \$DBD::IB::err,
                   'Errstr' => \$DBD::IB::errstr,
                   'Attribution' => 'DBD::IB by Edwin Pratomo'
                 });
    $drh;
}

#############   
# DBD::IB::dr
# methods:
#   connect
#   disconnect_all
#   DESTROY

package DBD::IB::dr;

$DBD::IB::dr::imp_data_size = $DBD::IB::dr::imp_data_size = 0;
$DBD::IB::dr::data_sources_attr = $DBD::IB::dr::data_sources_attr = undef;

sub connect {
    my($drh, $dsn, $dbuser, $dbpasswd, $attr) = @_;
    my %conn;
    my ($key, $val);

    foreach my $pair (split(/;/, $dsn))
    {
        ($key, $val) = $pair =~ m{(.+)=(.*)};
        if ($key eq 'host') { $conn{Server} = $val}
        elsif ($key =~ m{database}) { $conn{Path} = $val }
        elsif ($key =~ m{protocol}i) { $conn{Protocol} = $val }
        elsif ($key =~ m{role}i) {  $conn{Role} = $val }
        elsif ($key =~ m{charset}i) { $conn{Charset} = $val }
        elsif ($key =~ m{cache}i) {$conn{Cache} = $val }
    }

    $conn{User} = $dbuser || "SYSDBA";
    $conn{Password} = $dbpasswd || "masterkey";
        
    my $db = new IBPerl::Connection(%conn);
    if ($db->{Handle} < 0) {
        DBI::set_err(-1, $db->{Error});
        return undef;
    }

    my $h = new IBPerl::Transaction(Database=>$db);
    if ($h->{Handle} < 0) {
        DBI::set_err(-1, $db->{Error});
        return undef;
    }

    my $this = DBI::_new_dbh($drh, {
        'Name' => $dsn,
        'User' => $dbuser, 
    });

    if ($this)
    {
        while (($key, $val) = each(%$attr))
        {
            $this->STORE($key, $val);   #set attr like AutoCommit
        }
    }

    $this->STORE('ib_conn_handle', $db);
    $this->STORE('ib_trans_handle', $h);
    $this->STORE('Active', 1);
    $this;
}

sub disconnect_all { }

sub DESTROY { undef; }

##################
# DBD::IB::db
# methods:
#   prepare
#   commit
#   rollback
#   disconnect
#   do
#   ping
#   STORE
#   FETCH
#   DESTROY

package DBD::IB::db;

$DBD::IB::db::imp_data_size = $DBD::IB::db::imp_data_size= 0;

sub prepare 
{
    my($dbh, $statement, $attribs)= @_;
    my $h = $dbh->FETCH('ib_trans_handle');

    if (!$h)
    {
        return $dbh->DBI::set_err(-1, "Fail to get transaction handle");
    }

    $attribs->{Separator} = undef unless exists ($attribs->{Separator});
    $attribs->{DateFormat} = "%c" unless exists ($attribs->{DateFormat});

    my $st = new IBPerl::Statement(
        Transaction => $h,
        Stmt => $statement,
        Separator => $attribs->{Separator},
        DateFormat => $attribs->{DateFormat},
    );

    if ($st->{Handle} < 0) {
        return $dbh->DBI::set_err(-1, $st->{Error});
    }

    my $sth = DBI::_new_sth($dbh, {'Statement' => $statement});

    if ($sth) {
        $sth->STORE('ib_stmt_handle', $st);
        $sth->STORE('ib_stmt', $statement);
        $sth->STORE('ib_params', []); #storing bind values
        $sth->STORE('NUM_OF_PARAMS', ($statement =~ tr/?//));
    }
    $sth;
}

sub _commit
{
    my $dbh = shift;
    my $db = $dbh->FETCH('ib_conn_handle');
    my $h = $dbh->FETCH('ib_trans_handle');
    if ($h->IBPerl::Transaction::commit < 0) {
        return $dbh->DBI::set_err(-1, $h->{Error});
    }
    $h = new IBPerl::Transaction(Database => $db);
    if ($h->{Handle} < 0) {
        return $dbh->DBI::set_err(-1, $h->{Error});
    }
    $dbh->STORE('ib_trans_handle', $h);

    1;
}

sub commit
{
    my $dbh = shift;

    if ($dbh->FETCH('AutoCommit')) {
        warn("Commit ineffective while AutoCommit is on");
    }
    else { return _commit($dbh); }
    return 1;
}

sub rollback
{
    my $dbh = shift;
    if ($dbh->FETCH('AutoCommit')) {
        warn("Rollback ineffective while AutoCommit is on");
    }
    else
    {
        my $h = $dbh->FETCH('ib_trans_handle');
        if ($h->IBPerl::Transaction::rollback < 0) {
            return $dbh->DBI::set_err(-1, $h->{Error});
        }   
    }
    1;
}

sub disconnect
{
    my $dbh = shift;
    my $db = $dbh->FETCH('ib_conn_handle');
    my $h = $dbh->FETCH('ib_trans_handle');
    if ($dbh->FETCH('AutoCommit'))
    {
        if ($h->IBPerl::Transaction::commit < 0) {
            return $dbh->DBI::set_err(-1, $h->{Error});
        }
    }
    else
    {
        if ($h->IBPerl::Transaction::rollback < 0) {
            return $dbh->DBI::set_err(-1, $h->{Error});
        }
    }
    my $retval = $db->IBPerl::Connection::disconnect;
    if ($retval < 0)
    {
        return $dbh->$DBI::set_err($db->{Error});
    }   
    $dbh->STORE('Active', 0);
    1;
}

sub do
{
    my ($dbh, $stmt, $attr, @params) = @_;
    my $sth = $dbh->prepare($stmt, $attr) or return undef;
    my $st = $sth->{'ib_stmt_handle'};
    if ($st->IBPerl::Statement::execute(@params) < 0)
    {
        return $sth->DBI::set_err(1, $st->{Error});
    }   
    _commit($dbh) if ($dbh->{AutoCommit});
    -1;
}

sub STORE
{
    my ($dbh, $attr, $val) = @_;
    if ($attr eq 'AutoCommit')
    {
        if (exists $dbh->{AutoCommit} and $val == 1 and $dbh->{$attr} == 0) 
        {
            _commit($dbh) or 
                warn("Problem encountered while setting AutoCommit to On");
        }
        $dbh->{$attr} = $val;
        return 1;
    }
    if ($attr =~ /^ib_/)
    {
        $dbh->{$attr} = $val;
        return 1;
    }
    $dbh->DBD::_::db::STORE($attr, $val);
}

sub FETCH
{
    my ($dbh, $attr) = @_;
    if ($attr eq 'AutoCommit')
    {
        return $dbh->{$attr};
    }
    if ($attr =~ /^ib_/)
    {
        return $dbh->{$attr};
    }
    $dbh->DBD::_::db::FETCH($attr);
}

sub DESTROY
{
    my $dbh = shift;
    $dbh->disconnect if $dbh->FETCH('Active');
    undef;
}

####################
#
# DBD::IB::st
# methods:
#   execute
#   fetchrow_arrayref
#   finish  
#   STORE
#   FETCH
#   DESTROY 
#
####################

package DBD::IB::st;
use strict;
$DBD::IB::st::imp_data_size = $DBD::IB::st::imp_data_size = 0;

sub bind_param
{
    my ($sth, $pNum, $val, $attr) = @_;
    my $type = (ref $attr) ? $attr->{TYPE} : $attr;
    if ($type) {
        my $dbh = $sth->{'Database'};
        $val = $dbh->quote($sth, $type);
    }
    $sth->{ib_params}->[$pNum-1] = $val;
    1;
}

sub execute
{
    my ($sth, @bind_values) = @_;
    my $params = (@bind_values) ? \@bind_values : 
                 $sth->FETCH('ib_params');
    my $num_param = $sth->FETCH('NUM_OF_PARAMS');

    if (@$params != $num_param) {
        return $sth->DBI::set_err(1, 'Invalid number of params');       
    }

    my $st = $sth->{'ib_stmt_handle'};
    my $stmt = $sth->{'ib_stmt'};
    my $dbh = $sth->{'Database'};

# use open() for select and execute() for non-select
# execute procedure doesn't work at IBPerl
    if ($stmt =~ m{^\s*?SELECT}i or 
        $stmt =~ m{^\s*?EXECUTE\s+PROCEDURE}i)
    {
        if ($st->IBPerl::Statement::open(@$params) < 0)
        {
            return $sth->DBI::set_err(1, $st->{Error});
        }
    }
    else
    {
        if ($st->IBPerl::Statement::execute(@$params) < 0)
        {
            return $sth->DBI::set_err(1, $st->{Error});
        }
#       $sth->finish; #not work for non-select
        DBD::IB::db::_commit($dbh) if ($dbh->{AutoCommit});
    }
    -1;
}

sub fetch
{
    my $sth = shift;
    my $st = $sth->FETCH('ib_stmt_handle');
    my $record_ref = [];

    my $retval = $st->IBPerl::Statement::fetch($record_ref);
    if ($retval == 0) {
        unless ($sth->{NAME})
        {
            $sth->STORE('NAME', $st->{Columns});
            $sth->STORE('NUM_OF_FIELDS', scalar (@{$sth->{NAME}}));
        }
        $sth->STORE('NULLABLE', $st->{Nulls});

        if ($sth->FETCH('ChopBlanks')) {
            map { $_ =~ s/\s+$//; } @$record_ref;
        }
        return $sth->_set_fbav($record_ref);
#       return $record_ref;
    }

    elsif ($retval < 0) {
        return $sth->DBI::set_err(1, $st->{Error});
    }
    elsif ($retval == 100) {
        $sth->finish;
        return undef;
    }
}

*fetchrow_arrayref = \&fetch;

sub finish
{
    my $sth = shift;
    my $st = $sth->FETCH('ib_stmt_handle');
    if ($st->IBPerl::Statement::close < 0) 
    {
        return $sth->DBI::set_err(-1, $st->{Error});
    }
    $sth->DBD::_::st::finish();
    1;
}

sub STORE
{
    my ($sth, $attr, $val) = @_;
    # read-only attributes... who's responsible?
    if ($attr eq 'NAME' 
#       or $attr eq 'NUM_OF_FIELDS' #must be passed to SUPER::STORE()
#       or $attr eq 'NUM_OF_PARAMS' #same as above
        or $attr eq 'NULLABLE'
        or ($attr =~ /^ib_/o)
    )   
    {
        return $sth->{$attr} = $val;
    }

    $sth->DBD::_::st::STORE($attr, $val);
#   $dbh->SUPER::STORE($attr, $val);
}

sub FETCH
{
    my ($sth, $attr) = @_;
    if ($attr =~ /^ib_/ or $attr eq 'NAME' or $attr eq 'NULLABLE')
    {
        return $sth->{$attr};
    }
    $sth->DBD::_::st::FETCH($attr);
#   $dbh->SUPER::FETCH($attr, $attr);   
}

sub DESTROY { undef; }

1;

__END__

=head1 NAME

DBD::IB - DBI driver for InterBase RDBMS server

=head1 SYNOPSIS

  use DBI;
  
  $dbpath = '/home/edwin/perl_example.gdb';
  $dsn = "DBI:IB:database=$dbpath;host=puskom-4";

  $dbh = DBI->connect($dsn, '', '', {AutoCommit => 0}) 
    or die "$DBI::errstr";

  $dbh = DBI->connect($dsn, '', '', {RaiseError => 1}) 
    or die "$DBI::errstr";

  $sth = $dbh->prepare("select * from SIMPLE") or die $dbh->errstr;
  $sth->execute;

  while (@row = $sth->fetchrow_array))
  {
    print @row, "\n";
  }

  $dbh->commit or warn $dbh->errstr;
  $dbh->disconnect or warn $dbh->errstr;  

For more examples, see eg/ directory.

=head1 DESCRIPTION

This DBI driver currently is a wrapper around IBPerl, written in pure
perl. It is based on the DBI 1.13 specification dan IBPerl 0.7. This module 
should B<obsoletes the DBIx::IB>. 

B<Connecting with InterBase-specific optional parameters>

InterBase allows you to connect with specifiying Role, Protocol, Cache, and 
Charset. These parameters can be passed to InterBase via $dsn of DBI connect 
method. Eg:

  $dsn = 'dbi:IB:database=/path/to/data.gdb;charset=ISO8859_1';

=head1 PREREQUISITE

=over 2

=item * InterBase client

Available at http://www.interbase.com/,

=item * IBPerl 0.7, by Bill Karwin

Don't worry, it is included in this distribution.

=back

=head1 INSTALLATION

Run:

  # perl Makefile.PL

Here you will be prompted with some questions due to the database that will 
be used during 'make test'.

  # make
  # make test (optional)

The database you specify when running Makefile.PL should has been existed
before running 'make test', otherwise you will get 'Invalid DBI handle -1'
error message. 

  # make install

=head1 WARNING

InterBase specific behaviour:

=over 2

=item * $sth->{NAME} available after the first fetch

=item * $sth->{NUM_OF_FIELDS} available after the first fetch

=item * $dbh->do() doesn't return number of records affected

=item * $sth->execute() doesn't return number of records

=back

=head1 TESTED PLATFORMS

This module has been tested on Linux (2.0.33, 2.0.34), IBPerl 0.7, 
Perl 5.004_04, to access InterBase 4.0 for Linux, and InterBase 5.5 for NT.
It has also been used under mod_perl and Apache::DBI with no problems
reported (yet).

=head1 KNOWN BUGS

This sequence won't work:

  $dbh->do($stmt); #any statement on table TBL
  $dbh->commit;
  $dbh->do("drop table TBL");

Workaround: Change the commit with disconnect, and then connect again. This
bug seems to occurs at IBPerl level. Try some examples in eg/ibperl directory.

=head1 BUG REPORTS

Please send any bug report to dbi-users mailing list
(http://www.isc.org/dbi-lists.html) Any bug report should be accompanied with 
the script that got the problem, and the output of DBI trace method.

=head1 HISTORY

B<Version 0.021, September 19, 1999>

Separator and DateFormat options works for prepare() and do(). bind_param()
now works. One more fix to AutoCommit behaviour.

B<Version 0.02, July 31, 1999>

Alpha code. Major enhancement from the previous pre-alpha code. Previous 
known problems have been fixed. AutoCommit attribute works as expected. 

B<Version 0.01, July 23, 1999>

Pre-alpha code. An almost complete rewrite of DBIx::IB in pure perl. Problems
encountered during handles destruction phase.

B<DBIx::IB Version 0.01, July 22, 1999>

DBIx::IB, a DBI emulation layer for IBPerl is publicly announced.

=head1 TODO

=over 2

=item * Rigorous test under mod_perl and Apache::DBI

=item * An xs version should be much powerful, and simplify the installation 
process.

=back

=head1 ACKNOWLEDGEMENTS

Bill Karwin - author of IBPerl, Tim Bunce - author of DBI.

=head1 AUTHOR

Copyright (c) 1999 Edwin Pratomo <ed.pratomo@computer.org>.

All rights reserved. This is a B<free code>, available as-is;
you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

DBI(3), IBPerl(1).

=cut
