<?php
/**********************************************
Author: Paul Shipley - paul@paulshipley.id.au
Name: Import Quickbooks data - Customers, Suppliers, Items, Shipping Companies, Payment Terms, Sales Persons, Transactions
Free software under GNU GPL
***********************************************/

include_once($path_to_root . "/admin/db/shipping_db.inc");

function write_payterms($from_now, $terms, $days)
{
	//initialise no input errors assumed initially before we test
	$input_error = 0;

	if(strlen($terms) == 0){
		$input_error = 1;
		display_error(_("The payment terms cannot be empty."));
	}

	if($input_error != 1){
		// get $selected_id
		$selected_id = 0;
		$sql         = "SELECT terms_indicator FROM ".TB_PREF."payment_terms where terms=".db_escape($terms);
		if($result = db_query($sql))
		{
			$contact_row = db_fetch($result);
			$selected_id = $contact_row[0];
			db_free_result($result);
		}

		begin_transaction();

		if($selected_id){
			update_payment_terms($selected_id, $from_now, $terms, $days);

			display_notification(_('Selected payment terms have been updated') . ' - ' . $terms);
		}
		else
		{
			add_payment_terms($from_now, $terms, $days);

			display_notification(_('New payment terms has been added') . ' - ' . $terms);
		}

		commit_transaction();
	}
}

?>