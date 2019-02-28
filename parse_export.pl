#!/usr/bin/perl

# Author: Paul Shipley - paul@paulshipley.id.au http://paulshipley.id.au
# Name: Import Quickbooks data - Customers, Suppliers, Items, Shipping Companies, Payment Terms, Sales Persons
# Free software under GNU GPL

use strict;
use warnings;

$\ = "\n";

print "Import Quickbooks lists \n";

use Data::Dumper;

use File::Basename;
use File::Spec;

use Text::CSV;
my $qbexport = Text::CSV->new( { sep_char     => "\t" } );
my $csvout   = Text::CSV->new( { always_quote => 1 } );

my $file = $ARGV[0] or die "Quickbooks IIF file not specified on the command line\n";

open( my $data, '<', $file ) or die "Could not open '$file' $!\n";

my $dir = dirname($file);
print "Directory " . $dir . " contains results\n";

open( my $f_glaccnts, '>', File::Spec->catpath( "", $dir, "fa_glaccnts.csv" ) )
  or die "Could not open fa_glaccnts.csv $!\n";
open( my $f_items, '>', File::Spec->catpath( "", $dir, "fa_items.csv" ) )
  or die "Could not open fa_items.csv $!\n";
open( my $f_customers,
    '>', File::Spec->catpath( "", $dir, "fa_customers.csv" ) )
  or die "Could not open fa_customers.csv $!\n";
open( my $f_suppliers,
    '>', File::Spec->catpath( "", $dir, "fa_suppliers.csv" ) )
  or die "Could not open fa_suppliers.csv $!\n";
open( my $f_shipping, '>', File::Spec->catpath( "", $dir, "fa_shipping.csv" ) )
  or die "Could not open fa_shipping.csv $!\n";
open( my $f_paymentterms,
    '>', File::Spec->catpath( "", $dir, "fa_paymentterms.csv" ) )
  or die "Could not open fa_paymentterms.csv $!\n";
open( my $f_salespersons,
    '>', File::Spec->catpath( "", $dir, "fa_salespersons.csv" ) )
  or die "Could not open fa_salespersons.csv $!\n";

my $account_code = 10000;
my @glaccnts;
push @glaccnts,
  [
    "account_code", "account_name", "account_type", "account_code2",
    "accnttype",    "banknum", "accnum"
  ];

my @items;
push @items,
  [
    "stock_id",           "description",
    "long_description",   "category_id",
    "tax_type_id",        "units",
    "mb_flag",            "sales_account",
    "inventory_account",  "cogs_account",
    "adjustment_account", "wip_account",
    "dimension_id",       "dimension2_id",
    "no_sale",            "editable", "no_purchase",
    "sales_type_id",      "curr_abrev",
    "price",              "material_cost",
    "labour_cost",        "overhead_cost",
    "last_cost"
  ];

my @customers;
push @customers,
  [
    "CustName",      "cust_ref",     "address",       "tax_id",
    "curr_code",     "dimension_id", "dimension2_id", "credit_status",
    "payment_terms", "discount",     "pymt_discount", "credit_limit",
    "sales_type",    "notes",        "name",          "name2",
    "phone",         "phone2",       "fax",           "email",
    "salesman"
  ];

my @suppliers;
push @suppliers,
  [
    "supp_name",        "supp_ref",
    "address",          "supp_address",
    "gst_no",           "website",
    "supp_account_no",  "bank_account",
    "credit_limit",     "curr_code",
    "payment_terms",    "payable_account",
    "purchase_account", "payment_discount_account",
    "notes",            "tax_group_id",
    "tax_included"
  ];

my @shipping;
push @shipping, [ "shipper_name", "contact", "phone", "phone2", "address" ];

my @paymentterms;
push @paymentterms, [ "from_now", "terms", "days" ];

my @salespersons;
push @salespersons,
  [
    "salesman_name", "salesman_phone", "salesman_fax", "salesman_email",
    "provision",     "break_pt",       "provision2"
  ];

while ( my $line = <$data> ) {
    chomp $line;

    if ( $qbexport->parse($line) ) {
        my @fields = $qbexport->fields();

        my $transtype = $fields[0];

        if ( $transtype eq 'HDR' )     { }
        if ( $transtype eq 'ACCNT' )   { push @glaccnts, parse_accnt(@fields); }
        if ( $transtype eq 'INVITEM' ) { push @items, parse_invitem(@fields); }
        if ( $transtype eq 'CUST' )    { push @customers, parse_cust(@fields); }
        if ( $transtype eq 'EMP' )     { push @suppliers, parse_emp(@fields); }
        if ( $transtype eq 'OTHERNAME' ) {
            push @suppliers, parse_othername(@fields);
        }
        if ( $transtype eq 'SHIPMETH' ) {
            push @shipping, parse_shipmethod(@fields);
        }
        if ( $transtype eq 'PAYMETH' ) { }
        if ( $transtype eq 'INVMEMO' ) { }
        if ( $transtype eq 'TERMS' ) {
            push @paymentterms, parse_terms(@fields);
        }
        if ( $transtype eq 'SALESREP' ) {
            push @salespersons, parse_salesrep(@fields);
        }
        if ( $transtype eq 'VEND' ) { push @suppliers, parse_vend(@fields); }
        if ( $transtype eq 'CUSTITEMDICT' ) { }
        if ( $transtype eq 'CTYPE' )        { }
        if ( $transtype eq 'VTYPE' )        { }
        if ( $transtype eq 'TAXCODE' )      { }
        if ( $transtype eq 'SUPERFUND' )    { }
    }
    else {
        print "Error in input data at line $. - skipped\n"
          . $qbexport->error_input() . "\n"
          . $qbexport->error_diag() . "\n";
    }
}

print "$. lines processed, writting results\n";

$csvout->print( $f_glaccnts,     $_ ) for @glaccnts;
$csvout->print( $f_items,        $_ ) for @items;
$csvout->print( $f_customers,    $_ ) for @customers;
$csvout->print( $f_suppliers,    $_ ) for @suppliers;
$csvout->print( $f_shipping,     $_ ) for @shipping;
$csvout->print( $f_paymentterms, $_ ) for @paymentterms;
$csvout->print( $f_salespersons, $_ ) for @salespersons;

close $f_glaccnts;
close $f_items;
close $f_customers;
close $f_suppliers;
close $f_shipping;
close $f_paymentterms;
close $f_salespersons;

close $data;

print "Done.\n";

sub parse_accnt {

#In: !ACCNT	NAME	REFNUM	TIMESTAMP	ACCNTTYPE	OBAMOUNT	DESC	ACCNUM	TAXCODE	SCD	BANKNUM	EXTRA	CURRENCY	BALANCEREC	HIDDEN	DELCOUNT	USEID	WKPAPERREF
#Out: $account_code, $account_name, $account_type, $account_code2, $accnttype, $banknum, $accnum

    my $transtype = shift();

    my $account_name = shift();
    shift();    # refnum
    shift();    # timestamp
    my $accnttype = shift();
    shift();    # obamount
    my $desc = shift();
    my $accnum = shift();   
    shift();    # taxcode
    shift();    # scd
    my $banknum = shift();
    shift();    # extra
    shift();    # currency
    shift();    # balancerec
    my $hidden = shift();

    if ( $hidden eq 'Y' ) { return }

    my $account_type = '';

    if ( $accnttype eq 'BANK' )     { $account_type = 1 }
    if ( $accnttype eq 'AR' )       { $account_type = 1 }
    if ( $accnttype eq 'OCASSET' )  { $account_type = 1 }
    if ( $accnttype eq 'FIXASSET' ) { $account_type = 3 }
    if ( $accnttype eq 'OASSET' )   { $account_type = 3 }
    if ( $accnttype eq 'AP' )       { $account_type = 4 }
    if ( $accnttype eq 'OCLIAB' )   { $account_type = 4 }
    if ( $accnttype eq 'LTLIB' )    { $account_type = 5 }
    if ( $accnttype eq 'EQUITY' )   { $account_type = 6 }
    if ( $accnttype eq 'INC' )      { $account_type = 9 }
    if ( $accnttype eq 'COGS' )     { $account_type = 10 }
    if ( $accnttype eq 'EXP' )      { $account_type = 12 }
    if ( $accnttype eq 'EXEXP' )    { $account_type = 12 }

    $account_code += 10;
    my $account_code2 = '';

    my $row = [
        $account_code,  $account_name, $account_type,
        $account_code2, $accnttype,    $banknum, $accnum
    ];
    return $row;
}

sub parse_invitem {

#In: !INVITEM	NAME	REFNUM	TIMESTAMP	INVITEMTYPE	DESC	PURCHASEDESC	ACCNT	ASSETACCNT	COGSACCNT	QNTY	TOTVALUE	PRICE	COST	TAXABLE	TAXCODE	PAYMETH	TAXVEND	PREFVEND	REORDERPOINT	EXTRA	CUSTFLD1	CUSTFLD2	CUSTFLD3	CUSTFLD4	CUSTFLD5	DEP_TYPE	ISPASSEDTHRU	HIDDEN	DELCOUNT	USEID	AMTINCTAX	PURCHTAXCODE	GROSSPRICE	NETPRICE	BARCODE	ISNEW	PO_NUM	SERIALNUM	WARRANTY	LOCATION	VENDOR	ASSETDESC	SALEDATE	SALEEXPENSE	NOTES	ASSETNUM	COSTBASIS	ACCUMDEPR	UNRECBASIS	PURCHASEDATE	ISUSEDONPURCHTRANS	SALESTAXRETURNLINE	MANUFACPARTNO
#Out: $stock_id, $description, $long_description, $category_id,$tax_type_id, $units, $mb_flag, $sales_account, $inventory_account,$cogs_account, $adjustment_account,	$wip_account, $dimension_id,$dimension2_id, $no_sale, $editable, $no_purchase

    my $transtype = shift();

    my $description = shift();
    my $stock_id    = shift();    # refnum
    shift();                      # timestamp
    my $invitemtype      = shift();
    my $long_description = shift();
    shift();                      #purchasedesc
    shift();                      #accnt
    shift();                      #assetaccnt
    shift();                      #cogsaccnt
    shift();                      #qnty
    shift();                      #totvalue
    my $price         = shift();
    my $material_cost = shift();

    if ( $invitemtype eq 'COMPTAX' ) { return }
    if ( $invitemtype eq 'STAX' )    { return }

    #my $stock_id;
    #my $description;
    #my $long_description;
    my $category_id        = 0;
    my $tax_type_id        = 1;
    my $units              = 'each';
    my $mb_flag            = '';
    my $sales_account      = '';
    my $inventory_account  = '';
    my $cogs_account       = '';
    my $adjustment_account = '';
    my $wip_account   = '';
    my $dimension_id       = 0;
    my $dimension2_id      = 0;
    my $no_sale            = '';
    my $editable           = '';
    my $no_purchase            = '';
    my $sales_type_id      = 1;
    my $curr_abrev         = '';

    #my $price;
    #my $material_cost;
    my $labour_cost   = 0;
    my $overhead_cost = 0;
    my $last_cost     = 0;

    if ( $invitemtype eq 'SERV' ) { $category_id = 4; $mb_flag = 'D' }
    if ( $invitemtype eq 'PART' ) { $category_id = 1; $mb_flag = 'B' }
    if ( $invitemtype eq 'OTHC' ) { $category_id = 2; $mb_flag = 'D' }

    my $row = [
        $stock_id,      $description,        $long_description,
        $category_id,   $tax_type_id,        $units,
        $mb_flag,       $sales_account,      $inventory_account,
        $cogs_account,  $adjustment_account, $wip_account,
        $dimension_id,  $dimension2_id,      $no_sale,
        $editable,      $no_purchase, $sales_type_id,      $curr_abrev,
        $price,         $material_cost,      $labour_cost,
        $overhead_cost, $last_cost
    ];
    return $row;
}

sub parse_cust {

#In: !CUST	NAME	REFNUM	TIMESTAMP	BADDR1	BADDR2	BADDR3	BADDR4	BADDR5	SADDR1	SADDR2	SADDR3	SADDR4	SADDR5	S1ADDR1	S1ADDR2	S1ADDR3	S1ADDR4	S1ADDR5	S1ADDR6	S2ADDR1	S2ADDR2	S2ADDR3	S2ADDR4	S2ADDR5	S2ADDR6	S3ADDR1	S3ADDR2	S3ADDR3	S3ADDR4	S3ADDR5	S3ADDR6	S4ADDR1	S4ADDR2	S4ADDR3	S4ADDR4	S4ADDR5	S4ADDR6	SDEFAULTADDR1	SDEFAULTADDR2	SDEFAULTADDR3	SDEFAULTADDR4	SDEFAULTADDR5	SDEFAULTADDR6	PHONE1	PHONE2	FAXNUM	EMAIL	CC	NOTE	CONT1	CONT2	CTYPE	TERMS	TAXABLE	TAXCODE	TAXCOUNTRY	PREFERREDPAYMENT	PREFERREDSENDMETHOD	OBAMOUNT	OBDATE	LIMIT	TAXID	REP	TAXITEM	NOTEPAD	SALUTATION	COMPANYNAME	FIRSTNAME	MIDINIT	LASTNAME	CUSTFLD1	CUSTFLD2	CUSTFLD3	CUSTFLD4	CUSTFLD5	CUSTFLD6	CUSTFLD7	CUSTFLD8	CUSTFLD9	CUSTFLD10	CUSTFLD11	CUSTFLD12	CUSTFLD13	CUSTFLD14	CUSTFLD15	NAMECURRENCY	JOBDESC	JOBTYPE	JOBSTATUS	JOBSTART	JOBPROJEND	JOBEND	HIDDEN	DELCOUNT	PRICELEVEL
#Out: $CustName,$cust_ref,$address,$tax_id,$curr_code,$dimension_id,$dimension2_id,$credit_status,$payment_terms,$discount,$pymt_discount,$credit_limit,$sales_type,$notes,$name,$name2,$phone,$phone2,$fax,$email,$salesman

    my $transtype = shift();

    my $CustName = shift();
    my $cust_ref = $CustName;
    shift();    #refnum
    shift();    #timestamp
    my $address =
      shift() . ";" . shift() . ";" . shift() . ";" . shift() . ";" . shift();
    shift();    # saddr1
    shift();    # saddr2
    shift();    # saddr3
    shift();    # saddr4
    shift();    # saddr5
    shift();    # s1ddr1
    shift();    # s1ddr2
    shift();    # s1ddr3
    shift();    # s1ddr4
    shift();    # s1ddr5
    shift();    # s1ddr6
    shift();    # s2ddr1
    shift();    # s2ddr2
    shift();    # s2ddr3
    shift();    # s2ddr4
    shift();    # s2ddr5
    shift();    # s2ddr6
    shift();    # s3ddr1
    shift();    # s3ddr2
    shift();    # s3ddr3
    shift();    # s3ddr4
    shift();    # s3ddr5
    shift();    # s3ddr6
    shift();    # s4ddr1
    shift();    # s4ddr2
    shift();    # s4ddr3
    shift();    # s4ddr4
    shift();    # s4ddr5
    shift();    # s4ddr6
    shift();    # sdefaultddr1
    shift();    # sdefaultddr2
    shift();    # sdefaultddr3
    shift();    # sdefaultddr4
    shift();    # sdefaultddr5
    shift();    # sdefaultddr6
    my $phone  = shift();
    my $phone2 = shift();
    my $fax    = shift();
    my $email  = shift();
    shift();    # cc;
    my $notes = shift();
    my $name  = shift();
    my $name2 = shift();

    my $tax_id        = '';
    my $curr_code     = '';
    my $dimension_id  = 0;
    my $dimension2_id = 0;
    my $credit_status = 1;
    my $payment_terms = 1;
    my $discount      = 0;
    my $pymt_discount = 0;
    my $credit_limit  = 0;
    my $sales_type    = 1;
    my $ship_via      = 1;
    my $location      = 1;
    my $area          = '';
    my $tax_group_id  = 1;
    my $salesman      = '';

    my $row = [
        $CustName,      $cust_ref,     $address,       $tax_id,
        $curr_code,     $dimension_id, $dimension2_id, $credit_status,
        $payment_terms, $discount,     $pymt_discount, $credit_limit,
        $sales_type,    $notes,        $name,          $name2,
        $phone,         $phone2,       $fax,           $email,
        $salesman
    ];
    return $row;
}

sub parse_vend {

#In: !VEND	NAME	REFNUM	TIMESTAMP	PRINTAS	ADDR1	ADDR2	ADDR3	ADDR4	ADDR5	VTYPE	CONT1	CONT2	PHONE1	PHONE2	FAXNUM	EMAIL	CC	NOTE	TAXID	LIMIT	TERMS	NOTEPAD	SALUTATION	COMPANYNAME	FIRSTNAME	MIDINIT	LASTNAME	CUSTFLD1	CUSTFLD2	CUSTFLD3	CUSTFLD4	CUSTFLD5	CUSTFLD6	CUSTFLD7	CUSTFLD8	CUSTFLD9	CUSTFLD10	CUSTFLD11	CUSTFLD12	CUSTFLD13	CUSTFLD14	CUSTFLD15	NAMECURRENCY	1099	HIDDEN	DELCOUNT	ACCNTNAME	ACCNTNUM	BRANCHNUM	BANKNAME	LODGEMENT	TAXCODE	TAXCOUNTRY	BILLRATELVL
#Out:  $supp_name,$supp_ref,$address,$supp_address,$gst_no,$website,$supp_account_no,$bank_account,$credit_limit,$dimension_id,$dimension2_id,$curr_code,$payment_terms,$payable_account,$purchase_account,$payment_discount_account,$notes,$tax_group_id,$tax_included,$contact,$phone,$phone2,$fax,$email,$rep_lang,$inactive

    my $transtype = shift();

    my $supp_name = shift();
    my $supp_ref  = $supp_name;
    shift();    # refnum
    shift();    # timestamp
    shift();    # printas
    my $address =
      shift() . ";" . shift() . ";" . shift() . ";" . shift() . ";" . shift();
    my $supp_address = $address;
    shift();    # vtype
    my $contact = shift() . ' ' . shift();    # cont1 # cont2
    my $phone   = shift();                    # phone1
    my $phone2  = shift();                    # phone2
    my $fax     = shift();                    # faxnum
    my $email   = shift();                    # email
    shift();                                  # cc
    my $notes        = shift();
    my $gst_no       = shift();
    my $credit_limit = shift();
    $credit_limit = $credit_limit eq "" ? 0 : $credit_limit;

    my $website                  = '';
    my $supp_account_no          = '';
    my $bank_account             = '';
    my $dimension_id             = 0;
    my $dimension2_id            = 0;
    my $curr_code                = '';
    my $payment_terms            = 0;
    my $payable_account          = '';
    my $purchase_account         = '';
    my $payment_discount_account = '';
    my $tax_group_id             = '';
    my $tax_included             = 0;
    my $rep_lang                 = '';
    my $inactive                 = 0;

    my $row = [
        $supp_name,        $supp_ref,
        $address,          $supp_address,
        $gst_no,           $website,
        $supp_account_no,  $bank_account,
        $credit_limit,     $dimension_id,
        $dimension2_id,    $curr_code,
        $payment_terms,    $payable_account,
        $purchase_account, $payment_discount_account,
        $notes,            $tax_group_id,
        $tax_included,     $contact,
        $phone,            $phone2,
        $fax,              $email,
        $rep_lang,         $inactive
    ];
    return $row;
}

sub parse_emp {

#In: !EMP	NAME	REFNUM	TIMESTAMP	INIT	ADDR1	ADDR2	ADDR3	ADDR4	ADDR5	CITY	STATE	POST	PHONE1	PHONE2	MOBILENUM	FAXNUM	EMAIL	EMPNUM	NOTEPAD	FIRSTNAME	MIDINIT	LASTNAME	SALUTATION	CUSTFLD1	CUSTFLD2	CUSTFLD3	CUSTFLD4	CUSTFLD5	CUSTFLD6	CUSTFLD7	CUSTFLD8	CUSTFLD9	CUSTFLD10	CUSTFLD11	CUSTFLD12	CUSTFLD13	CUSTFLD14	CUSTFLD15	HIDDEN	DELCOUNT	DOB	ETRN
#Out:  $supp_name,$supp_ref,$address,$supp_address,$gst_no,$website,$supp_account_no,$bank_account,$credit_limit,$dimension_id,$dimension2_id,$curr_code,$payment_terms,$payable_account,$purchase_account,$payment_discount_account,$notes,$tax_group_id,$tax_included,$contact,$phone,$phone2,$fax,$email,$rep_lang,$inactive

    my $transtype = shift();

    my $supp_name = shift();
    my $supp_ref  = $supp_name;
    shift();    # refnum
    shift();    # timestamp
    shift();    # init
    my $address =
        shift() . "; "
      . shift() . "; "
      . shift() . "; "
      . shift() . "; "
      . shift();
    my $supp_address = $address;
    shift();    # city
    shift();    # state
    shift();    # post
    my $phone  = shift();    # phone1
    my $phone2 = shift();    # phone2
    shift();                 # mobilenum
    my $fax   = shift();     # faxnum
    my $email = shift();     # email
    shift();                 # empnum
    my $notes = shift();

    my $contact                  = $supp_name;
    my $gst_no                   = '';
    my $website                  = '';
    my $supp_account_no          = '';
    my $bank_account             = '';
    my $credit_limit             = 0;
    my $dimension_id             = 0;
    my $dimension2_id            = 0;
    my $curr_code                = '';
    my $payment_terms            = 0;
    my $payable_account          = '';
    my $purchase_account         = '';
    my $payment_discount_account = '';
    my $tax_group_id             = '';
    my $tax_included             = 0;
    my $rep_lang                 = '';
    my $inactive                 = 0;

    my $row = [
        $supp_name,        $supp_ref,
        $address,          $supp_address,
        $gst_no,           $website,
        $supp_account_no,  $bank_account,
        $credit_limit,     $dimension_id,
        $dimension2_id,    $curr_code,
        $payment_terms,    $payable_account,
        $purchase_account, $payment_discount_account,
        $notes,            $tax_group_id,
        $tax_included,     $contact,
        $phone,            $phone2,
        $fax,              $email,
        $rep_lang,         $inactive
    ];
    return $row;
}

sub parse_othername {

#In: !OTHERNAME	NAME	REFNUM	TIMESTAMP	BADDR1	BADDR2	BADDR3	BADDR4	BADDR5	PHONE1	PHONE2	FAXNUM	EMAIL	NOTE	CONT1	CONT2	NOTEPAD	SALUTATION	COMPANYNAME	FIRSTNAME	MIDINIT	LASTNAME	NAMECURRENCY	HIDDEN	DELCOUNT
#Out:  $supp_name,$supp_ref,$address,$supp_address,$gst_no,$website,$supp_account_no,$bank_account,$credit_limit,$dimension_id,$dimension2_id,$curr_code,$payment_terms,$payable_account,$purchase_account,$payment_discount_account,$notes,$tax_group_id,$tax_included,$contact,$phone,$phone2,$fax,$email,$rep_lang,$inactive

    my $transtype = shift();

    my $supp_name = shift();
    my $supp_ref  = $supp_name;
    shift();    # refnum
    shift();    # timestamp
    my $address =
      shift() . ";" . shift() . ";" . shift() . ";" . shift() . ";" . shift();
    my $supp_address = $address;
    my $phone        = shift();                    # phone1
    my $phone2       = shift();                    # phone2
    my $fax          = shift();                    # faxnum
    my $email        = shift();                    # email
    my $notes        = shift();
    my $contact      = shift() . ' ' . shift();    # cont1 # cont2

    my $gst_no                   = '';
    my $website                  = '';
    my $supp_account_no          = '';
    my $bank_account             = '';
    my $credit_limit             = 0;
    my $dimension_id             = 0;
    my $dimension2_id            = 0;
    my $curr_code                = '';
    my $payment_terms            = 0;
    my $payable_account          = '';
    my $purchase_account         = '';
    my $payment_discount_account = '';
    my $tax_group_id             = '';
    my $tax_included             = 0;
    my $rep_lang                 = '';
    my $inactive                 = 0;

    my $row = [
        $supp_name,        $supp_ref,
        $address,          $supp_address,
        $gst_no,           $website,
        $supp_account_no,  $bank_account,
        $credit_limit,     $dimension_id,
        $dimension2_id,    $curr_code,
        $payment_terms,    $payable_account,
        $purchase_account, $payment_discount_account,
        $notes,            $tax_group_id,
        $tax_included,     $contact,
        $phone,            $phone2,
        $fax,              $email,
        $rep_lang,         $inactive
    ];
    return $row;
}

sub parse_shipmethod {

    #In: !SHIPMETH	NAME	REFNUM	TIMESTAMP	HIDDEN
    #Out: $shipper_name, $contact, $phone, $phone2, $address

    my $transtype = shift();

    my $shipper_name = shift();
    shift();    # refnum
    shift();    # timestamp
    my $hidden = shift();

    if ( $hidden eq 'Y' ) { return }

    my $contact = '';
    my $phone   = '';
    my $phone2  = '';
    my $address = '';

    my $row = [ $shipper_name, $contact, $phone, $phone2, $address ];
    return $row;
}

sub parse_paymethod {

    #!PAYMETH	NAME	REFNUM	TIMESTAMP	HIDDEN

    # nowhere to put this, ignore

    my $transtype = shift();

    my $name   = shift();
    my $refnum = shift();
    shift();    # timestamp
    my $hidden = shift();

    if ( $hidden eq 'Y' ) { return }

    my $row = [ $refnum, $name, $hidden ];
    return $row;
}

sub parse_invmemo {

    #!INVMEMO	NAME	REFNUM	TIMESTAMP	HIDDEN

    # nowhere to put this, ignore
}

sub parse_terms {

#!TERMS	NAME	REFNUM	TIMESTAMP	DISCPER	STDDUEDAYS	STDDISCDAYS	DAYOFMONTHDUE	DISCDAYOFMONTH	DATEMINDAYS	TERMSTYPE	HIDDEN

    my $transtype = shift();

    my $terms = shift();    # name
    shift();                # refnum
    shift();                # timestamp
    shift();                # discper
    my $stdduedays = shift();    # stdduedays
    shift();                     # stddiscday
    my $dayofmonthdue = shift(); # dayofmonthdue
    shift();                     # datemindays
    my $termstype = shift();     # termstype
    my $hidden    = shift();     # hidden

    if ( $hidden eq 'Y' ) { return }

    my $from_now = $termstype eq 0 ? -1          : 0;
    my $days     = $termstype eq 0 ? $stdduedays : $dayofmonthdue;

    my $row = [ $from_now, $terms, $days ];
    return $row;
}

sub parse_salesrep {

#In: !SALESREP	INITIALS	ASSOCIATEDNAME	NAMETYPE	REFNUM	TIMESTAMP	HIDDEN	DELCOUNT
#Out: $salesman_name,$salesman_phone,$salesman_fax,$salesman_email,$provision,$break_pt,$provision2
    my $transtype = shift();

    shift();    # initials
    my $salesman_name = shift();
    shift();    # nametype
    shift();    # refnum
    shift();    # timestamp
    my $hidden = shift();

    if ( $hidden eq 'Y' ) { return }

    my $salesman_phone = "";
    my $salesman_fax   = "";
    my $salesman_email = "";
    my $provision      = 0;
    my $break_pt       = 0;
    my $provision2     = 0;

    my $row = [
        $salesman_name, $salesman_phone, $salesman_fax, $salesman_email,
        $provision,     $break_pt,       $provision2
    ];
    return $row;
}

