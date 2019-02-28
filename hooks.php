<?php
define ('SS_IMPORTQUICKBOOKS', 101<<8);

class hooks_import_quickbooks extends hooks {
	var $module_name = 'import_quickbooks'; 

	/*
		Install additonal menu options provided by module
	*/
	function install_options($app) {
		global $path_to_root;

		switch($app->id) {
			case 'system':
				$app->add_rapp_function(2, _('Import Quickbooks'), 
					$path_to_root.'/modules/import_quickbooks/import_quickbooks.php', 'SA_IMPORTQUICKBOOKS');
		}
	}

	function install_access()
	{
		$security_sections[SS_IMPORTQUICKBOOKS] =	_("Import Quickbooks");

		$security_areas['SA_IMPORTQUICKBOOKS'] = array(SS_IMPORTQUICKBOOKS|101, _("Import Quickbooks"));

		return array($security_areas, $security_sections);
	}
}
?>