<?php
/**********************************************
Author: Paul Shipley - paul@paulshipley.id.au
Name: Import Quickbooks data - Customers, Suppliers, Items, Shipping Companies, Payment Terms, Sales Persons, Transactions
Free software under GNU GPL
***********************************************/

function write_glaccount($account_code, $account_name, $account_type, $account_code2, $accnttype, $banknum){
	global $accounts_alpha;
	
	//initialise no input errors assumed initially before we test
	$input_error = 0;

	if(strlen(trim($account_code)) == 0){
		$input_error = 1;
		display_error( _("The account code must be entered."));
	} 
	elseif(strlen(trim($account_name)) == 0){
		$input_error = 1;
		display_error( _("The account name cannot be empty."));
	} 
	elseif(!$accounts_alpha && !is_numeric($account_code)){
		$input_error = 1;
		display_error( _("The account code must be numeric."));
	}

	if($input_error != 1){
		// get $selected_id
		$selected_id = 0;
		if($result = get_gl_account($account_code)){
			$selected_id = $result[0];
		}

		begin_transaction();

		if($selected_id){
			update_gl_account($account_code, $account_name, $account_type, $account_code2);

			display_notification(_('Selected GL Account has been updated') . ' - ' . $account_code);
		}
		else{
			add_gl_account($account_code, $account_name, $account_type, $account_code2);

			display_notification(_('New GL Account has been added') . ' - ' . $account_code);
		}

		if($accnttype == 'BANK'){
			$selected_id = 0;
			if($result = get_bank_account($account_code)){
				$selected_id = $result[0];
			}

			$account_type = 0; # Savings
			$bank_account_name = $account_name;
			$bank_account_number = $banknum;
			$bank_name = '';
			$bank_address = '';
			$company_record      = get_company_prefs();
			$BankAccountCurrency = $company_record["curr_default"];
			$dflt_curr_act = 0;
			$bank_charge_act = $company_record["bank_charge_act"];
					
			if($selected_id){
				update_bank_account($selected_id, $account_code,
					$account_type, $bank_account_name, 
					$bank_name, $bank_account_number, 
					$bank_address, $BankAccountCurrency,
					$dflt_curr_act, $bank_charge_act);

				display_notification(_('Bank account has been updated') . ' - ' . $account_code);
			} 
			else{
				add_bank_account($account_code, $account_type, 
					$bank_account_name, $bank_name, 
					$bank_account_number, $bank_address, 
					$BankAccountCurrency, $dflt_curr_act, $bank_charge_act);

				display_notification(_('New bank account has been added') . ' - ' . $account_code);
			}
		}

		commit_transaction();
	}
}

?>