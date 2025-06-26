#!/bin/bash

clear
echo "======================================"
echo "        CRM / ERP Installer Menu      "
echo "======================================"
echo "Select a system to install:"
echo
echo " 1) ERPNext"
echo " 2) Odoo Community"
echo " 3) EspoCRM"
echo " 4) SuiteCRM"
echo " 5) Vtiger"
echo " 6) YetiForce"
echo " 7) Dolibarr"
echo " 8) Axelor ERP"
echo " 9) Tryton"
echo "10) Metasfresh"
echo "11) ADempiere"
echo "12) Apache OFBiz"
echo "13) xTuple (PostBooks)"
echo "14) Frappe Framework only"
echo "15) Exit"
echo

read -p "Enter choice [1-15]: " choice

case $choice in
  1)  echo "▶ Installing ERPNext..."
      bash ./install_erpnext.sh
      ;;
  2)  echo "▶ Installing Odoo Community..."
      bash install_odoo.sh
      ;;
  3)  echo "▶ Installing EspoCRM..."
      bash install_espocrm.sh
      ;;
  4)  echo "▶ Installing SuiteCRM..."
      bash install_suitecrm.sh
      ;;
  5)  echo "▶ Installing Vtiger..."
      bash install_vtiger.sh
      ;;
  6)  echo "▶ Installing YetiForce..."
      bash install_yetiforce.sh
      ;;
  7)  echo "▶ Installing Dolibarr..."
      bash install_dolibarr.sh
      ;;
  8)  echo "▶ Installing Axelor ERP..."
      bash install_axelor.sh
      ;;
  9)  echo "▶ Installing Tryton..."
      bash install_tryton.sh
      ;;
 10)  echo "▶ Installing Metasfresh..."
      bash install_metasfresh.sh
      ;;
 11)  echo "▶ Installing ADempiere..."
      bash install_adempiere.sh
      ;;
 12)  echo "▶ Installing Apache OFBiz..."
      bash install_ofbiz.sh
      ;;
 13)  echo "▶ Installing xTuple (PostBooks)..."
      bash install_xtuple.sh
      ;;
 14)  echo "▶ Installing Frappe Framework only..."
      bash install_frappe.sh
      ;;
 15)  echo "👋 Exiting..."
      exit 0
      ;;
  *)  echo "❌ Invalid option!";;
esac
