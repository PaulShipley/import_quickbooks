<?php
/**********************************************
Author: Paul Shipley - paul@paulshipley.id.au
Name: Import Quickbooks data - Customers, Suppliers, Items, Shipping Companies, Payment Terms, Sales Persons, Transactions
Free software under GNU GPL
***********************************************/

$page_security = 'SA_IMPORTQUICKBOOKS';
$path_to_root  = "../..";

include_once($path_to_root . "/includes/db/crm_contacts_db.inc");

include_once($path_to_root . "/includes/session.inc");
add_access_extensions();

include('import_customer.inc');
include('import_shipping.inc');
include('import_salesperson.inc');
include('import_supplier.inc');
include('import_glaccount.inc');
include('import_payterms.inc');
include('import_items.inc');
include('import_transactions.inc');


// Turn these next two lines on for debugging
error_reporting(E_ALL);
ini_set("display_errors", "on");

$l_customers   = 0;
$l_suppliers   = 1;
$l_items       = 2;
$l_shipping    = 3;
$l_payterms    = 4;
$l_salespersons= 5;
$l_glaccounts  = 6;
$l_transactions= 7;

$arr           = array(
	$l_customers   => "Customers",
	$l_suppliers   => "Suppliers",
	$l_items       => "Items",
	$l_shipping    => "Shipping Companies",
	$l_payterms    => "Payment Terms",
	$l_salespersons=> "Sales Persons",
	$l_glaccounts  => "GL Accounts",
	$l_transactions=> "Transactions"
);

//--------------------------------------------------------------------------------------------------

function import_type_list_row($label, $name, $arr, $selected = null, $submit_on_change = false)
{
	echo "<tr><td class='label'>$label</td><td>";
	echo array_selector($name, $selected, $arr,
		array(
			'select_submit'=> $submit_on_change,
			'async'        => false,
		));
	echo "</td></tr>\n";
}

//--------------------------------------------------------------------------------------------------

function convert_address_lines($address)
{
	return str_replace(";","\n",$address);
}

//--------------------------------------------------------------------------------------------------
// Begin the UI
include_once($path_to_root . "/includes/ui.inc");

page("Import Quickbooks");

// If the import button was selected, we'll process the form here.  (If not, skip to actual content below.)
if(isset($_POST['import'])){
	if(isset($_FILES['imp']) && $_FILES['imp']['name'] != ''){
		$filename = $_FILES['imp']['tmp_name'];
		$sep      = ',';
		$type     = $_POST['type'];

		// Open the file
		$fp       = @fopen($filename, "r");
		if(!$fp){
			display_error("Error opening file $filename");
		}
		else
		{

			// Process the import file
			$line       = 0;
			$entryCount = 0;
			$entry      = NULL;
			$error      = false;
			$errCnt     = 0;

			while($data = fgetcsv($fp, 4096, $sep)){
				// Skip the first line, as it's a header
				if($line++ == 0) continue;

				// Skip blank lines (which shouldn't happen in a well formed CSV, but we'll be safe)
				if(count($data) == 1) continue;

				switch($type)
				{
					case $l_customers:
					list($CustName,$cust_ref,$address,$tax_id,$curr_code,$dimension_id,$dimension2_id,$credit_status,$payment_terms,$discount,$pymt_discount,$credit_limit,$sales_type,$notes,$name,$name2,$phone,$phone2,$fax,$email,$salesman) = $data;
					$address = convert_address_lines($address);
					write_customer($CustName,$cust_ref,$address,$tax_id,$curr_code,$dimension_id,$dimension2_id,$credit_status,$payment_terms,$discount,$pymt_discount,$credit_limit,$sales_type,$notes,$name,$name2,$phone,$phone2,$fax,$email,$salesman);
					break;

					case $l_suppliers:
					list($supp_name,$supp_ref,$address,$supp_address,$gst_no,$website,$supp_account_no,$bank_account,$credit_limit,$dimension_id,$dimension2_id,$curr_code,$payment_terms,$payable_account,$purchase_account,$payment_discount_account,$notes,$tax_group_id,$tax_included,$contact,$phone,$phone2,$fax,$email,$rep_lang,$inactive) = $data;
					$address = convert_address_lines($address);
					$supp_address = convert_address_lines($supp_address);
					write_supplier($supp_name,$supp_ref,$address,$supp_address,$gst_no,$website,$supp_account_no,$bank_account,$credit_limit,$dimension_id,$dimension2_id,$curr_code,$payment_terms,$payable_account,$purchase_account,$payment_discount_account,$notes,$tax_group_id,$tax_included,$contact,$phone,$phone2,$fax,$email,$rep_lang,$inactive);
					break;

					case $l_items:
					list($stock_id,$description,$long_description,$category_id,$tax_type_id,$units,$mb_flag,$sales_account,$inventory_account,$cogs_account,$adjustment_account,$wip_account,$dimension_id,$dimension2_id,$no_sale,$editable,$no_purchase,$sales_type_id,$curr_abrev,$price,$material_cost,$labour_cost,$overhead_cost,$last_cost) = $data;
					write_items($stock_id,$description,$long_description,$category_id,$tax_type_id,$units,$mb_flag,$sales_account,$inventory_account,$cogs_account,$adjustment_account,$wip_account,$dimension_id,$dimension2_id,$no_sale,$editable,$no_purchase,$sales_type_id,$curr_abrev,$price,$material_cost,$labour_cost,$overhead_cost,$last_cost);
					break;

					case $l_shipping:
					list($shipper_name, $contact, $phone, $phone2, $address) = $data;
					$address = convert_address_lines($address);
					write_shipping($shipper_name, $contact, $phone, $phone2, $address);
					break;

					case $l_payterms:
					list($from_now, $terms, $days) = $data;
					write_payterms($from_now, $terms, $days);
					break;

					case $l_salespersons:
					list($salesman_name,$salesman_phone,$salesman_fax,$salesman_email,$provision,$break_pt,$provision2) = $data;
					write_salesperson($salesman_name,$salesman_phone,$salesman_fax,$salesman_email,$provision,$break_pt,$provision2);
					break;

					case $l_glaccounts:
					list($account_code, $account_name, $account_type, $account_code2, $accnttype, $banknum) = $data;
					write_glaccount($account_code, $account_name, $account_type, $account_code2, $accnttype, $banknum);
					break;

					case $l_transactions:
					list($entryid, $qbtype, $date, $num, $name, $memo, $account, $item, $qty, $price, $amt, $balance) = $data;
					write_import_transactions($entryid, $qbtype, $date, $num, $name, $memo, $account, $item, $qty, $price, $amt, $balance);
/*					$entry = add_transaction($entry, $entryid, $qbtype, $date, $num, $name, $memo, $account, $item, $qty, $price, $amt, $balance);
					if ($balance == 0) {
						write_transaction($entry);
						$entry = NULL;
					}
*/
					break;

				}

				$entryCount++;
			}

			@fclose($fp);

			if(!$errCnt)
			{
				if($entryCount > 0)
				display_notification("$entryCount $arr[$type] have been imported.");
				else
				display_error("Import file contained no $arr[$type].");
			}
		}
	}
	else
	display_error("No import file selected");
}

start_form(true);

start_table(TABLESTYLE2);

if(!isset($_POST['type']))
$_POST['type'] = $l_customers;

table_section_title("Import Quickbooks Data");
import_type_list_row("Import Type:", 'type', $arr, $_POST['type'], true);
label_row("Import File:", "<input type='file' id='imp' name='imp'>");

end_table(1);

submit_center('import', "Perform Import");

end_form();

end_page();

?>
