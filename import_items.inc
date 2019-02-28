<?php
/**********************************************
Author: Paul Shipley - paul@paulshipley.id.au
Name: Import Quickbooks data - Customers, Suppliers, Items, Shipping Companies, Payment Terms, Sales Persons, Transactions
Free software under GNU GPL
***********************************************/
include_once($path_to_root . "/inventory/includes/db/items_category_db.inc");

function write_items($stock_id,$description,$long_description,$category_id,$tax_type_id,$units,$mb_flag,$sales_account,$inventory_account,$cogs_account,$adjustment_account,$wip_account,$dimension_id,$dimension2_id,$no_sale,$editable,$no_purchase,$sales_type_id,$curr_abrev,$price,$material_cost,$labour_cost,$overhead_cost,$last_cost){
	//initialise no input errors assumed initially before we test
	$input_error = 0;

	if(strlen(trim($stock_id)) == 0){
		$input_error = 1;
		display_error( _("The item code must be entered."));
	}
	elseif(strlen(trim($description)) == 0){
		$input_error = 1;
		display_error( _("The itme name cannot be empty."));
	}

	if($input_error != 1){
		// get $selected_id
		$selected_id = 0;
		if($result = get_item($stock_id)){
			$selected_id = $result[0];
		}

		$category_record = get_item_category($category_id);

		$tax_type_id = !empty($tax_type_id) ? $tax_type_id : $category_record["dflt_tax_type"];
		$units = !empty($units) ? $units : $category_record["dflt_units"];
		$mb_flag = !empty($mb_flag) ? $mb_flag : $category_record["dflt_mb_flag"];
		$inventory_account = !empty($inventory_account) ? $inventory_account : $category_record["dflt_inventory_act"];
		$cogs_account = !empty($cogs_account) ? $cogs_account : $category_record["dflt_cogs_act"];
		$sales_account = !empty($sales_account) ? $sales_account : $category_record["dflt_sales_act"];
		$adjustment_account = !empty($adjustment_account) ? $adjustment_account : $category_record["dflt_adjustment_act"];
		$wip_account = !empty($wip_account) ? $wip_account : $category_record["dflt_wip_act"];
		$dimension_id = !empty($dimension_id) ? $dimension_id : $category_record["dflt_dim1"];
		$dimension2_id = !empty($dimension2_id) ? $dimension2_id : $category_record["dflt_dim2"];
		$no_sale = !empty($no_sale) ? $no_sale : $category_record["dflt_no_sale"];
		$no_purchase = !empty($no_purchase) ? $no_purchase : $category_record["dflt_no_purchase"];
		$refline = "";
		$memo_ = $description;
		$editable = 0;
		$inactive = 0;

		if($selected_id){
			update_item($stock_id,$description,$long_description,$category_id,$tax_type_id,$units,$mb_flag,$sales_account,$inventory_account,$cogs_account,$adjustment_account,$wip_account,$dimension_id,$dimension2_id,$no_sale,$editable,$no_purchase);
			update_record_status($stock_id, $inactive,'stock_master', 'stock_id');
			update_record_status($stock_id, $inactive,'item_codes', 'item_code');
			stock_cost_update($stock_id,$material_cost,$labour_cost,$overhead_cost,$last_cost,$refline,$memo_);

			write_item_price($stock_id,$sales_type_id,$curr_abrev,$price);

			display_notification(_('Selected Item has been updated') . ' - ' . $stock_id);
		}
		else{
			add_item($stock_id,$description,$long_description,$category_id,$tax_type_id,$units,$mb_flag,$sales_account,$inventory_account,$cogs_account,$adjustment_account,$wip_account,$dimension_id,$dimension2_id,$no_sale,$editable,$no_purchase);
			stock_cost_update($stock_id,$material_cost,$labour_cost,$overhead_cost,$last_cost,$refline,$memo_);
			write_item_price($stock_id,$sales_type_id,$curr_abrev,$price);

			display_notification(_('New Item has been added') . ' - ' . $stock_id);
		}
	}
}

function write_item_price($stock_id,$sales_type_id,$curr_abrev,$price){
	if($result = get_prices($stock_id)){
		update_item_price($stock_id,$sales_type_id,$curr_abrev,$price);
	}
	else{
		add_item_price($stock_id,$sales_type_id,$curr_abrev,$price);
	}
}

?>