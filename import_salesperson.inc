<?php
/**********************************************
Author: Paul Shipley - paul@paulshipley.id.au
Name: Import Quickbooks data - Customers, Suppliers, Items, Shipping Companies, Payment Terms, Sales Persons, Transactions
Free software under GNU GPL
***********************************************/

function write_salesperson($salesman_name,$salesman_phone,$salesman_fax,$salesman_email,$provision,$break_pt,$provision2)
{
	//initialise no input errors assumed initially before we test
	$input_error = 0;

	if(strlen($salesman_name) == 0){
		$input_error = 1;
		display_error(_("The sales person name cannot be empty."));
	}
	/*	$pr1 = check_num('provision', 0,100);
	if (!$pr1 || !check_num('provision2', 0, 100)) {
	$input_error = 1;
	display_error( _("Salesman provision cannot be less than 0 or more than 100%."));
	}
	if (!check_num('break_pt', 0)) {
	$input_error = 1;
	display_error( _("Salesman provision breakpoint must be numeric and not less than 0."));
	} */
	if($input_error != 1){
		begin_transaction();

		// get $selected_id
		$selected_id = 0;
		$sql         = "SELECT salesman_code FROM ".TB_PREF."salesman where salesman_name=".db_escape($salesman_name);
		if($result = db_query($sql))
		{
			$contact_row = db_fetch($result);
			$selected_id = $contact_row[0];
			db_free_result($result);
		}

		if($selected_id){
			update_salesman($selected_id, $salesman_name, $salesman_phone, $salesman_fax,
				$salesman_email, $provision, $break_pt, $provision2);

			display_notification(_('Selected sales person data has been updated') . ' - ' . $salesman_name);
		}
		else
		{
			add_salesman($salesman_name, $salesman_phone, $salesman_fax,
				$salesman_email, $provision, $break_pt, $provision2);

			display_notification(_('New sales person data has been added') . ' - ' . $salesman_name);
		}

		commit_transaction();
	}
}

?>