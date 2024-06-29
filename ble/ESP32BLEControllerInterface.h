
esp_bt_controller_config_t buildDefaultBTControllerConfiguration();

esp_err_t safe_swift_esp_ble_gap_set_device_name();

esp_err_t swift_temp_esp_ble_gatts_get_attr_value(uint16_t attr_handle);

esp_ble_adv_params_t adv_params_wo_peer_address(
    uint16_t adv_int_min, 
    uint16_t adv_int_max, 
    esp_ble_adv_type_t adv_type, 
    esp_ble_addr_type_t own_addr_type,
    esp_ble_adv_channel_t channel_map,
    esp_ble_adv_filter_t adv_filter_policy
);

esp_gatt_value_t safe_build_esp_gatt_value_t();

void update_gatt_value(esp_gatt_value_t *gatt_value, uint8_t value, uint16_t index);

/*
    GAP
*/

esp_ble_gap_cb_param_t::ble_adv_start_cmpl_evt_param read_ble_adv_start_cmpl_evt_param(esp_ble_gap_cb_param_t *param);

esp_ble_gap_cb_param_t::ble_adv_stop_cmpl_evt_param read_ble_adv_stop_cmpl_evt_param(esp_ble_gap_cb_param_t *param);

esp_ble_gap_cb_param_t::ble_update_conn_params_evt_param read_ble_update_conn_params_evt_param(esp_ble_gap_cb_param_t *param);


/*
    GATTS
*/

esp_ble_gatts_cb_param_t::gatts_reg_evt_param read_reg_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_read_evt_param read_read_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_write_evt_param read_write_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_exec_write_evt_param read_exec_write_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_mtu_evt_param read_mtu_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_conf_evt_param read_conf_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_create_evt_param read_create_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_add_incl_srvc_evt_param read_add_incl_srvc_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_add_char_evt_param read_add_char_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_add_char_descr_evt_param read_add_char_descr_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_delete_evt_param read_delete_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_start_evt_param read_start_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_stop_evt_param read_stop_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_connect_evt_param read_connect_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_disconnect_evt_param read_disconnect_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_open_evt_param read_open_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_cancel_open_evt_param read_cancel_open_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_close_evt_param read_close_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_congest_evt_param read_congest_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_rsp_evt_param read_rsp_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_add_attr_tab_evt_param read_add_attr_tab_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_set_attr_val_evt_param read_set_attr_val_evt_param(esp_ble_gatts_cb_param_t *param);

esp_ble_gatts_cb_param_t::gatts_send_service_change_evt_param read_send_service_change_evt_param(esp_ble_gatts_cb_param_t *param);
