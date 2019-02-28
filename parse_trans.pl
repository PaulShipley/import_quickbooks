#!/usr/bin/perl

# Author: Paul Shipley - paul@paulshipley.id.au http://paulshipley.id.au
# Name: Import Quickbooks data - Transactions
# Free software under GNU GPL

use strict;
use warnings;

$\ = "\n";

print "Import Quickbooks transactions \n";

use Data::Dumper;
use File::Basename;
use File::Spec;
use Text::CSV;

my $max_entry = 999;

die "Usage: perl -f parse_trans.pl trans.csv [sales.csv] \n" if ( @ARGV < 1 );

# load GL Accounts to map QB accnt to FA accnt
my $gldata;
my @glaccnts;
my $qbexport = Text::CSV->new( { binary => 1, sep_char => "," } );
load_gl_accnts();

# if specifed, read sales data as lookup for invoice transactions
my $sdata;
my @sales;

if ( @ARGV > 1 ) {
    load_sales();
}
else {
    print "No Sales items specified";
}

print ", processing transactions\n";

# process transaction data
my $entryid;
my $tdata;
my $trans_file = 1;
my $first_entry = 1;
my @transactions;
my $csvout = Text::CSV->new( { binary => 1, always_quote => 1 } );
my $trans = $ARGV[0] or die "Transaction file not specified on command line\n";
open( $tdata, '<', $trans ) or die "Could not open '$trans' $!\n";

my $dir = dirname($trans);
print "Directory " . $dir . " contains results\n";

while ( !eof($tdata) ) {
   $entryid = $first_entry;
    process_trans();
    $trans_file++;
}

close $tdata;
close $sdata if defined $sdata;

print "Done.\n";

# read GL Accounts as lookup for QB Account Number to FA Account
sub load_gl_accnts {

    print "load GL Accounts data\n";

    open( $gldata, '<', 'fa_glaccnts.csv' )
      or die "Could not open fa_glaccnts.csv $!\n";

    while ( my $line = <$gldata> ) {
        chomp $line;

        if ( $. < 2 ) { next; }

        if ( $qbexport->parse($line) ) {
            my @fields = $qbexport->fields();

            push @glaccnts, parse_glaccnts(@fields);
        }
        else {
            print "Error in input data at line $. - skipped\n"
              . $qbexport->error_input() . "\n"
              . $qbexport->error_diag() . "\n";
        }
    }

    print "$. GL Account items loaded, processing sales\n";
}

# parse GL Accounts
sub parse_glaccnts {

#In: ,"account_code","account_name","account_type","account_code2","accnttype","banknum","accnum"
#Out: $accnum, $account_code

    my $account_code = shift();    # account_code
    shift();                       # account_name
    shift();                       # account_type
    shift();                       # account_code2
    shift();                       # accnttype
    shift();                       # banknum
    my $accnum = shift();          # accnum

    my $row = [ $accnum, $account_code ];

    return $row;
}

# load Sales data to include with Transactions
sub load_sales {
    print "load Sales data\n";

    my $sales = $ARGV[1]
      or die "Sales file not specified on the command line\n";
    open( $sdata, '<', $sales ) or die "Could not open '$sales' $!\n";

    while ( my $line = <$sdata> ) {
        chomp $line;

        if ( $. < 2 ) { next; }

        if ( $qbexport->parse($line) ) {
            my @fields = $qbexport->fields();

            push @sales, parse_sales(@fields);
        }
        else {
            print "Error in input data at line $. - skipped\n"
              . $qbexport->error_input() . "\n"
              . $qbexport->error_diag() . "\n";
        }
    }

    print "$. Sales items loaded";
}

# parse Sales data
sub parse_sales {

#In: ,"Type","Date","Num","Description","Name","Item","Qty","Sales Price","Amount","Balance"
#Out: $key, $entryid, $item, $qty

    shift();    #
    my $qbtype  = shift();    # Type
    my $date    = shift();    # Date
    my $num     = shift();    # Num
    my $memo    = shift();    # Description
    my $name    = shift();    # Name
    my $item    = shift();    # Item
    my $qty     = shift();    # Qty
    my $price   = shift();    # Sales Price
    my $amt     = shift();    # Amount
    my $balance = shift();    # Balance

    if ( $qbtype eq '' ) { return; }

    my $key = $qbtype . $date . $num . $memo . $name . $amt;

    my $row = [
        $qbtype, $date, $num,   $memo, $name,
        $item,   $qty,  $price, $amt,  $balance
    ];

    return $row;
}

# process Transactions, limiting file size to max_entry
sub process_trans {
    open(
        my $f_transactions,
        '>',
        File::Spec->catpath(
            "", $dir, "fa_transactions_" . $trans_file . ".csv"
        )
    ) or die "Could not open fa_transactions.csv $!\n";

    # csv header line
    push @transactions,
      [
        "entryid", "qbtype", "date", "num",   "name", "memo",
        "account", "item",   "qty",  "price", "amt",  "balance"
      ];

    while ( my $line = <$tdata> ) {
        chomp $line;

        if ( $. < 3 ) { next; }

        if ( $qbexport->parse($line) ) {
            my @fields = $qbexport->fields();

            push @transactions, parse_transaction(@fields);
        }
        else {
            print "Error in input data at line $. - skipped\n"
              . $qbexport->error_input() . "\n"
              . $qbexport->error_diag() . "\n";
        }

        last if $entryid > $max_entry;
    }

    print "$. lines processed, writting results";

    $csvout->print( $f_transactions, $_ ) for @transactions;

    close $f_transactions;
    @transactions = ();    # empty array;
}

# parse Transaction data
sub parse_transaction {

#In: ,"Type","Date","Num","Name","Description","Account","Clr","Split","Amount","Balance"
#Out: $entryid, $qbtype, $date, $num, $name, $memo, $account, $item, $qty, $price, $amt, $balance

    shift();    #
    my $qbtype  = shift();    # Type
    my $date    = shift();    # Date
    my $num     = shift();    # Num
    my $name    = shift();    # Name
    my $memo    = shift();    # Description
    my $account = shift();    # Account
    my $clr     = shift();    # Clr
    my $split   = shift();    # Split
    my $amt     = shift();    # Amount
    my $balance = shift();    # Balance

    if ( $qbtype eq '' ) { return; }

    my $item  = '';
    my $qty   = 0;
    my $price = 0;

    # lookup FA account number
    my ($qbacc) = ( $account =~ m/^([0-9.]*)/ );
    my $faacc = 0;

    foreach my $i ( 0 .. @glaccnts - 1 ) {
        if ( $glaccnts[$i][0] eq $qbacc ) {
            $faacc = $glaccnts[$i][1];
        }
    }

    # lookup Invoice details
    if ( $qbtype eq "Tax Invoice" or $qbtype eq "Sales Receipt" ) {
        foreach my $i ( 0 .. @sales - 1 ) {
            if (    $sales[$i][0] eq $qbtype
                and $sales[$i][1] eq $date
                and $sales[$i][2] eq $num
                and $sales[$i][3] eq $memo
                and $sales[$i][4] eq $name )
            {
                $item  = $sales[$i][5];
                $qty   = $sales[$i][6];
                $price = $sales[$i][7];
            }
        }
    }

    # output transaction
    my $row = [
        $entryid, $qbtype, $date, $num,   $name, $memo,
        $faacc,   $item,   $qty,  $price, $amt,  $balance
    ];

    if ( $balance == 0 ) { $entryid++; }

    return $row;
}

