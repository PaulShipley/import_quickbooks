<?php
/**********************************************
Author: Paul Shipley - paul@paulshipley.id.au
Name: Import Quickbooks data - Customers, Suppliers, Items, Shipping Companies, Payment Terms, Sales Persons, Transactions
Free software under GNU GPL
***********************************************/

function write_customer($CustName,$cust_ref,$address,$tax_id,$curr_code,$dimension_id,$dimension2_id,$credit_status,$payment_terms,$discount,$pymt_discount,$credit_limit,$sales_type,$notes,$name,$name2,$phone,$phone2,$fax,$email,$salesman){
	//initialise no input errors
	$input_error = 0;

	//  validate input
	if(strlen($CustName) == 0 || $CustName == ""){
		$input_error = 1;
		display_error(_("The customer name must be entered."));
	}

	if(strlen($cust_ref) == 0 || $cust_ref == ""){
		$input_error = 1;
		display_error(_("The customer short name must be entered."));
	}

	if($input_error != 1){
		// get $customer_id
		$customer_id = 0;
		$sql         = "SELECT debtor_no FROM ".TB_PREF."debtors_master WHERE name=".db_escape($CustName);
		if($result = db_query($sql)){
			$contact_row = db_fetch($result);
			$customer_id = $contact_row[0];
			db_free_result($result);
		}

		$company_record = get_company_prefs();
		$dflt_currency = $company_record["curr_default"];
		$curr_code = (!empty($curr_code) ? $curr_code : $dflt_currency);

		begin_transaction();

		if($customer_id){
			customer_edit($customer_id,$CustName,$cust_ref,$address,$tax_id,$curr_code,$dimension_id,$dimension2_id,$credit_status,$payment_terms,$discount,$pymt_discount,$credit_limit,$sales_type,$notes);

			display_notification(_('Selected customer data has been updated') . ' - ' . $CustName);
		}
		else{
			customer_add($CustName,$cust_ref,$address,$tax_id,$curr_code,$dimension_id,$dimension2_id,$credit_status,$payment_terms,$discount,$pymt_discount,$credit_limit,$sales_type,$notes,$name,$name2,$phone,$phone2,$fax,$email,$salesman);

			display_notification(_('New customer data has been added') . ' - ' . $CustName);
		}

		commit_transaction();
	}
}

function customer_add($CustName,$cust_ref,$address,$tax_id,$curr_code,$dimension_id,$dimension2_id,$credit_status,$payment_terms,$discount,$pymt_discount,$credit_limit,$sales_type,$notes,$name,$name2,$phone,$phone2,$fax,$email,$salesman){
	/*
	$CustName, $cust_ref, $address, $tax_id, $curr_code,
	$dimension_id, $dimension2_id, $credit_status, $payment_terms, $discount, $pymt_discount,
	$credit_limit, $sales_type, $notes
	*/
	add_customer(
		$CustName,
		$cust_ref,
		$address,
		$tax_id,
		$curr_code,
		$dimension_id,
		$dimension2_id,
		$credit_status,
		$payment_terms,
		$discount,
		$pymt_discount,
		$credit_limit,
		$sales_type,
		$notes
	);

	$customer_id = db_insert_id();

	/*
	$customer_id, $br_name, $br_ref, $br_address, $salesman, $area,
	$tax_group_id, $sales_account, $sales_discount_account, $receivables_account,
	$payment_discount_account, $default_location, $br_post_address, $disable_trans, $group_no,
	$default_ship_via, $notes
	*/
	// defaults
	$sales_account              = '';
	$default_sales_discount_act = get_company_pref('default_sales_discount_act');
	$debtors_act                = get_company_pref('debtors_act');
	$default_prompt_payment_act = get_company_pref('default_prompt_payment_act');

	// For default branch
	$salesman = (!empty($salesman) ? $salesman : get_default_salesman());
	$area = (!empty($area) ? $area : get_default_area());
	$tax_group_id = (!empty($tax_group_id) ? $tax_group_id : '1');
	$location = (!empty($location) ? $location : 'DEF');
	$ship_via = (!empty($ship_via) ? $ship_via : '1');
	$phone = (isset($phone) ? $phone : '');
	$phone2 = (isset($phone2) ? $phone2 : '');
	$fax = (isset($fax) ? $fax : '');
	$email = (isset($email) ? $email : '');
	$sales_account = '1';
	$disable_trans = 0;
	$group_no = 1;

	add_branch(
		$customer_id,
		$CustName,
		$cust_ref,
		$address,
		$salesman,
		$area,
		$tax_group_id,
		$sales_account,
		$default_sales_discount_act,
		$debtors_act,
		$default_prompt_payment_act,
		$location,
		$address,
		$disable_trans,
		$group_no,
		$ship_via,
		$notes
	);

	$selected_branch = db_insert_id();

	/*
	$ref, $name, $name2, $address, $phone, $phone2, $fax, $email, $lang, $notes
	*/
	add_crm_person(
		$cust_ref,
		$name,
		$name2,
		$address,
		$phone,
		$phone2,
		$fax,
		$email,
		'',
		''
	);

	$pers_id = db_insert_id();

	/*
	$type, $action, $entity_id, $person_id
	*/
	add_crm_contact(
		'cust_branch',
		'general',
		$selected_branch,
		$pers_id
	);

	add_crm_contact(
		'customer',
		'general',
		$customer_id,
		$pers_id
	);
}

function get_default_salesman(){
	$sql = "SELECT salesman_code FROM ".TB_PREF."salesman LIMIT 1" ;
	if($result = db_query($sql)){
		$contact_row = db_fetch($result);
		$salesman    = $contact_row[0];
		db_free_result($result);
	}

	return $salesman;
}

function get_default_area(){
	$sql = "SELECT area_code FROM ".TB_PREF."areas LIMIT 1" ;
	if($result = db_query($sql)){
		$contact_row = db_fetch($result);
		$area        = $contact_row[0];
		db_free_result($result);
	}

	return $area;
}

function customer_edit($customer_id,$CustName,$cust_ref,$address,$tax_id,$curr_code,$dimension_id,$dimension2_id,$credit_status,$payment_terms,$discount,$pymt_discount,$credit_limit,$sales_type,$notes){
	update_customer(
		$customer_id,
		$CustName,
		$cust_ref,
		$address,
		$tax_id,
		$curr_code,
		$dimension_id,
		$dimension2_id,
		$credit_status,
		$payment_terms,
		$discount,
		$pymt_discount,
		$credit_limit,
		$sales_type,
		$notes
	);
}

?>