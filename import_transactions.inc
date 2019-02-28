<?php
/**********************************************
Author: Paul Shipley - paul@paulshipley.id.au
Name: Import Quickbooks data - Transactions
Free software under GNU GPL
***********************************************/

include_once($path_to_root . "/includes/ui/items_cart.inc");
include_once($path_to_root . "/sales/includes/cart_class.inc");
include_once($path_to_root . "/sales/includes/ui/sales_order_ui.inc");

//--------------------------------------------------------------------------------------------------
// write transactions to import to temporary table for processing

function write_import_transactions($entryid, $qbtype, $date, $num, $name, $memo, $account, $item, $qty, $price, $amt, $balance)
{
	global $db, $show_sql, $sql_trail, $select_trail, $go_debug, $sql_queries, $Ajax,
	$db_connections, $db_last_inserted_id;

	$cur_prefix = $db_connections[$_SESSION["wa_current_user"]->cur_con]['tbpref'];

	begin_transaction();

	$sql =
		"INSERT INTO ".$cur_prefix."import_transactions
		(`entry_id`, `qb_type`, `date`, `num`, `name`, `memo`, `account`, `item`, `qty`, `price`, `amt`, `balance`)
		VALUES(".db_escape($entryid).",".db_escape($qbtype).",".db_escape($date).",".db_escape($num).",".db_escape($name).",".db_escape($memo).",".db_escape($account).",".db_escape($item).",".db_escape($qty).",".db_escape($price).",".db_escape($amt).",".db_escape($balance).")";
	db_query($sql,"Could not insert");
	
	commit_transaction();
}



//--------------------------------------------------------------------------------------------------
// See gl / gl_journal::create_cart() & gl / gl_bank::handle_new_order()

function init_cart($type,$date,$name,$reference,$memo) 
{
	$cart = new items_cart($type);
	$cart->order_id = get_next_order_id();
	$cart->tran_date = $date;
	$cart->reference = $cart->order_id . "-" . $reference;
	$cart->memo_ = $memo;
	$cart->line_items = array();
	# $gl_items;
	# $from_loc;
	# $to_loc;
	# $transfer_type;
	# $increase;

	$cart->person_id = $name; // This is not correct but needed somewhere to hold name until write_transaction

	return $cart;
}

function get_next_order_id()
{
	$sql = "SELECT max(type_no) last_no FROM ".TB_PREF."gl_trans";
    $result = db_query($sql,"The next transaction number could not be retrieved");
    $myrow = db_fetch_row($result);

    return $myrow[0] + 1;
}

//--------------------------------------------------------------------------------------------------

function add_transaction($cart, $cartid, $qbtype, $date, $num, $name, $memo, $account, $item, $qty, $price, $amt, $balance)
{
	//initialise no input errors assumed initially before we test
	$input_error = 0;
	$dim1  = 0;
	$dim2 = 0;
	$reference = $qbtype . ($num == "" ? "" : "-" . $num);

	$type = -1;
	switch($qbtype)
	{
		case 'Cheque':
		$type = ST_BANKPAYMENT;
		//	$type = ST_SUPPAYMENT;
		break;

		case 'Deposit':
		$type = ST_BANKDEPOSIT;
		break;

		case 'Payment':
		$type = ST_CUSTPAYMENT;
		break;

		case 'General Journal':
		case 'Transfer':
		$type = ST_JOURNAL;
		break;

		case 'Sales Receipt':
		case 'Tax Invoice':
		$type = ST_SALESINVOICE; 
		break;

		default:
		display_error(_("QuickBooks type unknown."));
		$input_error = 1;
	}

	// convert dates like '1/3/2010' to '01/03/2010' to pass is_date() tests
	global $dateseps;
	$sep = $dateseps[user_date_sep()];
	$dd = explode($sep, $date);
    $d1 = (strlen($dd[0]) == 1 ? '0'.$dd[0] : $dd[0]);
    $d2 = (strlen($dd[1]) == 1 ? '0'.$dd[1] : $dd[1]);
    $d3 = (strlen($dd[2]) == 1 ? '0'.$dd[2] : $dd[2]);
    $date = $d1.$sep.$d2.$sep.$d3;

	if ($cart == NULL) {
		$cart = init_cart($type,$date,$name,$reference,$memo);
	}

	if (!is_date($date))
	{
		display_error(_("The entered date ($date) for the payment is invalid."));
		$input_error = 1;
	}

	if($input_error != 1)
	{
		$cart->add_gl_item($account,$dim1,$dim2,$amt,$reference,$memo);
	}
	
	if($input_error != 1 && $type == ST_SALESINVOICE && $item != "")
	{
		$stock_id = '';
		$sql = "SELECT stock_id FROM ".TB_PREF."stock_master WHERE description=".db_escape($item);
		if($result = db_query($sql))
		{
			$row = db_fetch($result);
			$stock_id = $row[0];
			db_free_result($result);
		}

		if($stock_id != '')
		{
			$line_no = $cart->count_items() + 1;
			$disc = 0;
			$cart->add_to_cart($line_no, $stock_id, $qty, $amt, $disc);
			$cart->line_items[$line_no]->price = $price;
		}
		else
		{
			display_error(_("The item ($item) is unknown."));
			$input_error = 1;
		}
	}

	return $cart;
}

//--------------------------------------------------------------------------------------------------

function write_transaction($cart)
{
	begin_transaction();

	$input_error = 0;

	if ($cart->count_gl_items() < 1) {
		display_error(_('Transaction '.$cart->order_id."You must enter at least one payment line."));
		$input_error = 1;
	}

	if (abs($cart->gl_items_total()) > 0.0001)
	{
		display_error(_('Transaction '.$cart->order_id."The journal must balance (debits equal to credits) before it can be processed."));
		$input_error = 1;
	}

	if($input_error != 1)
	{
		// update cart with person details, return person type
		$person_type_id = process_cart($cart);
		
		switch($cart->trans_type){
			case ST_SALESINVOICE:
			write_salesinvoice($cart);
			break;

			default:
			write_journal_cart($cart,$person_type_id);
			break;
		}

		commit_transaction();
		display_notification('Transaction '.$cart->order_id.' has been added');

	} else {

		cancel_transaction();
		display_notification('Transaction '.$cart->order_id.' cancelled');
	}
}

function process_cart(&$cart)
{
	$name = $cart->person_id; // get name from where we stored it
	$cart->person_id = NULL;
	
	$person_type_id = NULL;
	$person_id = 0;

	// Get customer id
	$sql= "SELECT debtor_no FROM ".TB_PREF."debtors_master WHERE name=".db_escape($name);
	if($result = db_query($sql))
	{
		$row = db_fetch($result);
		$person_type_id = PT_CUSTOMER;
		$person_id = $row[0];
		db_free_result($result);
	}
	
	// if not customer, get supplier id
	if ($person_id == 0)
	{
	    $sql= "SELECT supplier_id FROM ".TB_PREF."suppliers WHERE supp_name=".db_escape($name);
		if($result = db_query($sql))
		{
			$row = db_fetch($result);
			$person_type_id = PT_SUPPLIER;
			$person_id = $row[0];
			db_free_result($result);
		}
	}
	
	$branch_id = 0;
	if ($person_type_id == PT_CUSTOMER) {
		$sql= "SELECT branch_code FROM ".TB_PREF."cust_branch WHERE debtor_no=".db_escape($person_id);
		if($result = db_query($sql))
		{
			$row = db_fetch($result);
			$branch_id = $row[0];
			db_free_result($result);
		}
	}
	$cart->branch_id = $branch_id;

	if ($person_id == 0)
	{
		$type = ST_BANKPAYMENT;
		$cart->trans_type = $type;
		$person_type_id = PT_MISC;
		$person_id = $name;
	} 

	$cart->person_id = $person_id;
	
	return $person_type_id;
}


//--------------------------------------------------------------------------------
// see // FA built-in function - gl/includes/db/gl_db_trans.inc

function write_journal_cart(&$cart,$person_type_id)
{
	global $Refs;

	$date_ = $cart->tran_date;
	$ref   = $cart->reference;
	$memo_ = $cart->memo_;
	$trans_type = $cart->trans_type;
	
	$company_record = get_company_prefs();
	$currency = $company_record["curr_default"];

    $trans_id = $cart->order_id;

	switch($person_type_id)
	{
		case PT_CUSTOMER:
		$discount=0;
		$Tax=0;
		$Freight=0;
		$FreightTax=0;
	    $sales_type=1; // first sales type, ie: Retail
	    $order_no=$cart->order_id;
	    $ship_via=1; // first shipper, ie: Default
	    $due_date=$cart->tran_date;
	    $AllocAmt=0;
	    $rate=0;
	    $dimension_id=0;
	    $dimension2_id=0;
	    $payment_terms=1; // first payment terms, ie: 15th of month

		$trans_id = write_customer_trans($trans_type,$trans_id,$cart->person_id,$cart->branch_id,$cart->tran_date,$cart->reference,$cart->gl_items_total_debit(), $discount, $Tax, $Freight, $FreightTax, $sales_type, $order_no, $ship_via, $due_date, $AllocAmt, $rate, $dimension_id, $dimension2_id, $payment_terms);
		break;

		case PT_SUPPLIER:
		$trans_id = write_supp_trans($trans_type,$trans_id,$cart->person_id,$cart->tran_date,$cart->tran_date,$cart->reference,"",$cart->gl_items_total_credit(),0,0);
		break;
	}

	foreach ($cart->gl_items as $journal_item)
	{

		add_gl_trans($trans_type, $trans_id, $date_, $journal_item->code_id,
			$journal_item->dimension_id, $journal_item->dimension2_id,
			$journal_item->reference, $journal_item->amount, $currency, $person_type_id, $cart->person_id);

		// post to first found bank account using given gl acount code.
		$is_bank_to = is_bank_account($journal_item->code_id);
    	if ($is_bank_to)
    	{
    		add_bank_trans($trans_type, $trans_id, $is_bank_to, $ref,
    			$date_, $journal_item->amount,	$person_type_id, $cart->person_id, get_company_currency(),
    			"Cannot insert a destination bank transaction");
    	}

		// store tax details if the gl account is a tax account
		add_gl_tax_details($journal_item->code_id, 
			ST_JOURNAL, $trans_id, $journal_item->amount, 1, $date_, $memo_);
	}
	
	$Refs->save($trans_type, $trans_id, $ref);
	add_comments($trans_type, $trans_id, $date_, $memo_);

	add_audit_trail($trans_type, $trans_id, $date_);
}

//--------------------------------------------------------------------------------
// see sales/SalesOrderEntry NewOrder

function write_salesinvoice(&$cart)
{
	global $Refs;

    // create sales order
	$doc = new Cart(ST_SALESORDER, 0);
	$doc->trans_type = ST_SALESINVOICE; //$cart->trans_type;
	$doc->reference = $Refs->get_next($doc->trans_type);
	$doc->trans_no = 0;
	$doc->document_date = new_doc_date();
	$doc->pos = get_sales_point(user_pos());

    $line_num = 0;
	foreach($cart->line_items as $line_no => $line) {
		$doc->add_to_cart($line_num, $line->stock_id, $line->quantity, $line->price, 0, $line->quantity, $line->standard_cost, $line->item_description);
		$line_num ++;
	}

	// copy_to_cart();
	$doc->Comments =  $cart->memo_;
	$doc->document_date = $cart->tran_date;
	$doc->payment = $cart->gl_items_total_debit();
	$doc->payment_terms = get_payment_terms(1);
	$doc->due_date = get_invoice_duedate($doc->payment, $doc->document_date);
	$doc->cust_ref = '';
	$doc->deliver_to = '';
	$doc->delivery_address = '';
	$doc->phone = '';
	$doc->ship_via = 1; // first shipper, ie: Default
	$doc->Location = 'DEF';
	$doc->freight_cost = 0;
	$doc->email = '';
	$doc->customer_id = $cart->person_id;
	$doc->Branch = $cart->branch_id;
	$doc->sales_type = 1; // first sales type, ie: Retail
	$doc->ex_rate = null;
	
	get_customer_details_to_order($doc, $cart->person_id, $cart->branch_id);
	
	$ret = $doc->write(1);
}

?>