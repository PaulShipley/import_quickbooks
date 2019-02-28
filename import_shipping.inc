<?php
/**********************************************
Author: Paul Shipley - paul@paulshipley.id.au
Name: Import Quickbooks data - Customers, Suppliers, Items, Shipping Companies, Payment Terms, Sales Persons, Transactions
Free software under GNU GPL
***********************************************/

include_once($path_to_root . "/admin/db/shipping_db.inc");

function write_shipping($shipper_name, $contact, $phone, $phone2, $address)
{
	//initialise no input errors assumed initially before we test
	$input_error = 0;

	if(strlen($shipper_name) == 0){
		$input_error = 1;
		display_error(_("The shipping company name cannot be empty."));
	}

	if($input_error != 1){
		// get $selected_id
		$selected_id = 0;
		$sql         = "SELECT shipper_id FROM ".TB_PREF."shippers where shipper_name=".db_escape($shipper_name);
		if($result = db_query($sql))
		{
			$contact_row = db_fetch($result);
			$selected_id = $contact_row[0];
			db_free_result($result);
		}

		begin_transaction();

		if($selected_id){
			update_shipper($selected_id, $shipper_name, $contact, $phone, $phone2, $address);

			display_notification(_('Selected shipping company data has been updated') . ' - ' . $shipper_name);
		}
		else
		{
			add_shipper($shipper_name, $contact, $phone, $phone2, $address);

			display_notification(_('New shipping company data has been added') . ' - ' . $shipper_name);
		}

		commit_transaction();
	}
}

?>