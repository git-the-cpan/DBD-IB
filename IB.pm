=head1 NAME

DBD::IB - InterBase driver for the Perl5 DataBase Interface

=head1 SYNOPSIS

  use DBI;
  
  $dbpath = '/usr/interbase/data/perl_example.gdb';
  $dbh = DBI->connect(DBI:IB:database=$dbpath) or die "DBI::errstr";
  $sth = $dbh->prepare("select * from SIMPLE") or die $dbh->errstr;
  $sth->execute;
  while (@row = $sth->fetchrow_array))
  {
    print @row, "\n";
  }
  $dbh->commit;
  $dbh->disconnect;  

For more examples, see eg/ directory.

=head1 DESCRIPTION

Currently this is a wrapper DBD module on top of IBPerl, written in pure
perl. For this is an B<pre-alpha code>, so use with caution!

=head1 PREREQUISITE

=over 2

=item * InterBase client

=item * IBPerl, by Bill Karwin

=back

Both are available at http://www.interbase.com, for more information, read the 
documentation of IBPerl.

=head1 WARNING

Not fully tested.

=head1 HISTORY

=over 2

=item * July 23, 1999

Pre-alpha code. An almost complete rewrite of DBI::IB in pure perl. Problems
encountered during handles destruction phase.

=item * July 22, 1999

DBI::IB, a DBI emulation layer for IBPerl is publicly announced.

=back

=head1 TODO

Independent implementation from IBPerl.

=head1 ACKNOWLEDGEMENT

Bill Karwin - author of IBPerl, Tim Bunce - author of DBI.

=head1 AUTHOR

Copyright (c) 1999 Edwin Pratomo <ed.pratomo@computer.org>.

All rights reserved. This is a B<free code>, available as-is;
you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

DBI(3), IBPerl(1).

=cut

use strict;

use Carp;
use DBI;
use IBPerl;

package DBD::IB;

use vars qw($VERSION $err $errstr $sqlstate $drh);

$VERSION = '0.01';

$err = 0;
$errstr = "";
$sqlstate = "";
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
#	connect
#	disconnect_all
#	DESTROY

package DBD::IB::dr;

$DBD::IB::dr::imp_data_size = 0;
$DBD::File::dr::data_sources_attr = undef;

sub connect {
    my($drh, $dsn, $dbuser, $dbpasswd, $attr) = @_;
	my %conn;
	my ($key, $val);

	foreach my $pair (split(/;/, $dsn))
	{
		($key, $val) = $pair =~ m{(.+)=(.*)};
		$conn{Server} = $val if ($key eq 'host');
		$conn{Path} = $val if ($key =~ m{database});
		$conn{Port} = $val if ($key eq 'port');
	}

	$conn{User} = $dbuser || "SYSDBA";
	$conn{Password} = $dbpasswd || "masterkey";
		
    my $db = new IBPerl::Connection(%conn);
	if ($db->{Handle} < 0) {
		$DBI::err = -1;
		$DBI::errstr = $db->{Error};
		return undef;
	}

	my $h = new IBPerl::Transaction(Database=>$db);
	if ($h->{Handle} < 0) {
		$DBI::err = -1;
		$DBI::errstr = $h->{Error};
		return undef;
	}

#	my $private_attr = {
#		'ib_conn_handle' => $db,
#		'ib_trans_handle' => $h,
#	};

    my $this = DBI::_new_dbh($drh, {
	'Name' => $dsn,
	'USER' => $dbuser, 
	'CURRENT_USER' => $dbuser,
    });

	if ($this)
	{
		while (($key, $val) = each(%$attr))
		{
			$this->STORE($key, $val);	#set attr like AutoCommit
		}
	}

	$this->STORE('ib_conn_handle', $db);
	$this->STORE('ib_trans_handle', $h);
    $this;
}

sub disconnect_all
{

}

sub DESTROY
{
	undef;
}

##################
# DBD::IB::db
# methods:
#	prepare
#	commit
#	rollback
#	disconnect
#	STORE
#	FETCH
#	DESTROY

package DBD::IB::db;

$DBD::IB::db::imp_data_size = 0;

sub prepare 
{
    my($dbh, $statement, @attribs)= @_;
	my $h = $dbh->FETCH('ib_trans_handle');

	if (!$h)
	{
		return $dbh->DBI::set_err(-1, "Fail to get transaction handle");
	}

	my $st = new IBPerl::Statement(
		Transaction => $h,
	    Stmt => $statement);

	if ($st->{Handle} < 0) {
		return $dbh->DBI::set_err(-1, $st->{Error});
	}

    my $sth = DBI::_new_sth($dbh, {'Statement' => $statement});

    if ($sth) {
		$sth->STORE('ib_stmt_handle', $st);
	    $sth->STORE('ib_stmt', $statement);
		$sth->STORE('ib_params', []);
		$sth->STORE('NUM_OF_PARAMS', ($statement =~ tr/?//));
    }
    $sth;
}

sub commit
{
	my $dbh = shift;
    if ($dbh->FETCH('AutoCommit')) {
		warn("Commit ineffective while AutoCommit is on", -1);
    }
	else
	{
		my $h = $dbh->{ib_trans_handle};
		if ($h->IBPerl::Transaction::commit < 0) {
			return $dbh->DBI::set_err(-1, $h->{Error});
		}	
	}
	1;
}

sub rollback
{
	my $dbh = shift;
    if ($dbh->FETCH('Warn')) {
		warn("Rollback ineffective while AutoCommit is on", -1);
    }
	else
	{
		my $h = $dbh->{ib_trans_handle};
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
		$h->commit or return undef;
	}
	if ($db->IBPerl::Connection::disconnect < 0)
	{
		return $dbh->$DBI::set_err($db->{Error});
	}	
	1;
}

sub STORE
{
	my ($dbh, $attr, $val) = @_;
	if ($attr eq 'AutoCommit')
	{
		if ($val == 1 or $val == 0)	{
			$dbh->{$attr} = $val;
			return 1;
		}
		else {die "Invalid AutoCommit value";}
	}
	if ($attr =~ /^ib_/)
	{
		$dbh->{$attr} = $val;
		return 1;
	}
	$dbh->DBD::_::db::STORE($attr, $val);
#	$dbh->SUPER::STORE($attr, $val);
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
	#$dbh->SUPER::FETCH($attr, $attr);	
}


sub DESTROY
{
	shift->disconnect;
}

####################
#
# DBD::IB::st
# methods:
#	execute
#	fetchrow_arrayref
#	finish	*
#	STORE
#	FETCH
#	DESTROY *
#
####################

package DBD::IB::st;
use strict;
$DBD::IB::st::imp_data_size = 0;

# not yet implemented
#sub bind_param
#{
#
#}

sub execute
{
    my ($sth, @params) = @_;
	my $st = $sth->{'ib_stmt_handle'};
    my $stmt = $sth->{'ib_stmt'};

# use open() for select and execute() for non-select
	if ($stmt =~ m{^\s*?SELECT}i)
	{
# verbose for clarity
		if ($st->IBPerl::Statement::open(@params) < 0)
		{
			return $sth->DBI::set_err(1, $st->{Error});
		}
	}
	else
	{
		if ($st->IBPerl::Statement::execute(@params) < 0)
		{
			return $sth->DBI::set_err(1, $st->{Error});
		}
	}
# doesn't have method for this:
#    my @fields = $h->FieldNames;
#    $h->{NAME} = \@fields;
#    $h->{NUM_OF_FIELDS} = scalar @fields;

    $st;
}

sub fetch
{
	my $sth = shift;
#	my $st = $sth->{'ib_stmt_handle'};
	my $st = $sth->FETCH('ib_stmt_handle');
	my @record = ();

	my $retval = $st->IBPerl::Statement::fetch(\@record);
	if ($retval == 0) {return \@record;}
	if ($retval < 0) {
		return $sth->DBI::set_err(1, $st->{Error});
	}
    return undef;
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
	1;
}

sub STORE
{
	my ($sth, $attr, $val) = @_;
	if ($attr =~ /^ib_/)
	{
		$sth->{$attr} = $val;
		return 1;
	}
	$sth->DBD::_::st::STORE($attr, $val);
#	$dbh->SUPER::STORE($attr, $val);
}

sub FETCH
{
	my ($sth, $attr) = @_;
	if ($attr =~ /^ib_/)
	{
		return $sth->{$attr};
	}
	$sth->DBD::_::st::FETCH($attr);
#	$dbh->SUPER::FETCH($attr, $attr);	
}

sub DESTROY
{
	1;#shift->finish;
}
1;
__END__

