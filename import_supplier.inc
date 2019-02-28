<?php
/**********************************************
Author: Paul Shipley - paul@paulshipley.id.au
Name: Import Quickbooks data - Customers, Suppliers, Items, Shipping Companies, Payment Terms, Sales Persons, Transactions
Free software under GNU GPL
***********************************************/

function write_supplier($supp_name,$supp_ref,$address,$supp_address,$gst_no,$website,$supp_account_no,$bank_account,$credit_limit,$dimension_id,$dimension2_id,$curr_code,$payment_terms,$payable_account,$purchase_account,$payment_discount_account,$notes,$tax_group_id,$tax_included,$contact,$phone,$phone2,$fax,$email,$rep_lang,$inactive)
{
	//initialise no input errors
	$input_error = 0;

	//  validate input
	if(strlen($supp_name) == 0 || $supp_name == ""){
		$input_error = 1;
		display_error(_("The supplier name must be entered."));
	}

	if(strlen($supp_ref) == 0 || $supp_ref == ""){
		$input_error = 1;
		display_error(_("The supplier short name must be entered."));
	}

	// process data
	if($input_error != 1 ){
		// get supplier_id
		$supplier_id = 0;
		$sql         = "SELECT supplier_id FROM ".TB_PREF."suppliers where supp_name=".db_escape($supp_name);
		if($result = db_query($sql))
		{
			$contact_row = db_fetch($result);
			$supplier_id = $contact_row[0];
			db_free_result($result);
		}

		// set default values
		$company_record           = get_company_prefs();
		$curr_code                = ($curr_code ? $curr_code : $company_record["curr_default"]);
		$payable_account          = ($payable_account ? $payable_account : $company_record["creditors_act"]);
		$payment_discount_account = ($payment_discount_account ? $payment_discount_account : $company_record['pyt_discount_act']);

		begin_transaction();

		if($supplier_id){
			update_supplier($supplier_id, $supp_name, $supp_ref, $address,
				$supp_address, $gst_no,
				$website, $supp_account_no, $bank_account,
				$credit_limit, $dimension_id, $dimension2_id, $curr_code,
				$payment_terms, $payable_account, $purchase_account, $payment_discount_account,
				$notes, $tax_group_id, $tax_included);

			update_record_status($supplier_id, $inactive,'suppliers', 'supplier_id');

			display_notification(_("Supplier has been updated.")." - ".$supp_name);
		}
		else
		{
			add_supplier($supp_name, $supp_ref, $address, $supp_address,
				$gst_no, $website, $supp_account_no, $bank_account,
				$credit_limit, $dimension_id, $dimension2_id,
				$curr_code, $payment_terms, $payable_account, $purchase_account,
				$payment_discount_account, $notes, $tax_group_id, $tax_included);

			$supplier_id = db_insert_id();

			update_record_status($supplier_id, $inactive,'suppliers', 'supplier_id');

			add_crm_person($supp_ref, $contact, '', $address,
				$phone, $phone2, $fax, $email,
				$rep_lang, '');

			add_crm_contact('supplier', 'general', $supplier_id, db_insert_id());

			display_notification(_("A new supplier has been added.")." - ".$supp_name);
		}

		commit_transaction();
	}
}

?>