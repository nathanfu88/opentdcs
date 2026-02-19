#include <inttypes.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "soc/dac_channel.h"
#include "driver/dac_oneshot.h"
#include "driver/i2c_master.h"
#include "ads1115.h"
#include "esp_check.h"


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_bt.h"

#include "esp_gap_ble_api.h"
#include "esp_gatts_api.h"
#include "esp_bt_defs.h"
#include "esp_bt_main.h"
#include "esp_bt_device.h"
#include "esp_gatt_common_api.h"

#include "sdkconfig.h"

#define I2C_MASTER_SCL_IO 22
#define I2C_MASTER_SDA_IO 21
#define I2C_MASTER_NUM I2C_NUM_0

#define GATTS_TAG "tDCS"
static const char *TAG = "tDCS";

static void gatts_profile_a_event_handler(esp_gatts_cb_event_t event, esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param);

#define GATTS_SERVICE_UUID_TEST_A   0x00FF
#define GATTS_CHAR_UUID_TEST_A      0xFF01
#define GATTS_DESCR_UUID_TEST_A     0x3333
#define GATTS_NUM_HANDLE_TEST_A     4

#define DEVICE_NAME "tDCS"

#define GATTS_DEMO_CHAR_VAL_LEN_MAX 0x40

static uint8_t char1_str[] = {0x11,0x22,0x33};
static esp_gatt_char_prop_t a_property = 0;

static esp_attr_value_t gatts_demo_char1_val =
{
    .attr_max_len = GATTS_DEMO_CHAR_VAL_LEN_MAX,
    .attr_len     = sizeof(char1_str),
    .attr_value   = char1_str,
};

static uint8_t adv_config_done = 0;

static esp_ble_adv_data_t adv_data = {
    .set_scan_rsp = false,
    .include_name = true,
    .include_txpower = false,
    .min_interval = 0x0006,
    .max_interval = 0x0010,
    .appearance = 0x00,
    .manufacturer_len = 0,
    .p_manufacturer_data = NULL,
    .service_data_len = 0,
    .p_service_data = NULL,
    .service_uuid_len = 0,
    .p_service_uuid = NULL,
    .flag = (ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT),
};

static esp_ble_adv_params_t adv_params = {
    .adv_int_min        = 0x20,
    .adv_int_max        = 0x40,
    .adv_type           = ADV_TYPE_IND,
    .own_addr_type      = BLE_ADDR_TYPE_PUBLIC,
    //.peer_addr            =
    //.peer_addr_type       =
    .channel_map        = ADV_CHNL_ALL,
    .adv_filter_policy = ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY,
};

#define PROFILE_NUM 1
#define PROFILE_A_APP_ID 0

struct gatts_profile_inst {
    esp_gatts_cb_t gatts_cb;
    uint16_t gatts_if;
    uint16_t app_id;
    uint16_t conn_id;
    uint16_t service_handle;
    esp_gatt_srvc_id_t service_id;
    uint16_t char_handle;
    esp_bt_uuid_t char_uuid;
    esp_gatt_perm_t perm;
    esp_gatt_char_prop_t property;
    uint16_t descr_handle;
    esp_bt_uuid_t descr_uuid;
};

/* One gatt-based profile one app_id and one gatts_if, this array will store the gatts_if returned by ESP_GATTS_REG_EVT */
static struct gatts_profile_inst gl_profile_tab[PROFILE_NUM] = {
    [PROFILE_A_APP_ID] = {
        .gatts_cb = gatts_profile_a_event_handler,
        .gatts_if = ESP_GATT_IF_NONE,       /* Not get the gatt_if, so initial is ESP_GATT_IF_NONE */
    },
};

static ads1115_handle_t ads1115_dev;
static i2c_master_bus_handle_t i2c_bus_handle;
static uint8_t dac_out_val = 0;
static bool dac_enabled = false;

// IMPORTANT: Circuit has INVERSE relationship between DAC voltage and output current
// DAC 0 (0V) = Maximum current (~2.48mA)
// DAC 255 (3.3V) = Minimal current (~0.007mA)
// For safety: when disabled, DAC should be set to 255 (high voltage = low current)

static void gap_event_handler(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param)
{
    switch (event) {
    case ESP_GAP_BLE_ADV_DATA_SET_COMPLETE_EVT:
        adv_config_done = 1;
        if (adv_config_done) {
            esp_ble_gap_start_advertising(&adv_params);
        }
        break;
    case ESP_GAP_BLE_ADV_START_COMPLETE_EVT:
        if (param->adv_start_cmpl.status != ESP_BT_STATUS_SUCCESS) {
            ESP_LOGE(GATTS_TAG, "Advertising start failed");
        }
        break;
    case ESP_GAP_BLE_ADV_STOP_COMPLETE_EVT:
        if (param->adv_stop_cmpl.status != ESP_BT_STATUS_SUCCESS) {
            ESP_LOGE(GATTS_TAG, "Advertising stop failed");
        }
        break;
    default:
        break;
    }
}

static void handle_dac_write(uint8_t value) {
    if (value == 254) {
        dac_enabled = true;
        ESP_LOGI(GATTS_TAG, "DAC ENABLED");
    } else if (value == 253) {
        dac_enabled = false;
        ESP_LOGI(GATTS_TAG, "DAC DISABLED");
    } else {
        dac_out_val = value;
    }
}

static esp_err_t i2c_master_init(void)
{
    i2c_master_bus_config_t i2c_mst_config = {
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .i2c_port = I2C_MASTER_NUM,
        .scl_io_num = I2C_MASTER_SCL_IO,
        .sda_io_num = I2C_MASTER_SDA_IO,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };

    return i2c_new_master_bus(&i2c_mst_config, &i2c_bus_handle);
}

static esp_err_t ads1115_setup(void)
{
    ads1115_config_t config = {
        .addr = ADS1115_I2C_ADDR_DEFAULT,
        .gain = ADS1115_PGA_4_096V,
        .data_rate = ADS1115_DR_64SPS
    };
    return ads1115_init(&ads1115_dev, &config, i2c_bus_handle);
}

static void gatts_read_adc(esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param) {
    int16_t chan0_raw = 0;
    int16_t chan1_raw = 0;
    int16_t chan2_raw = 0;
    int16_t chan3_raw = 0;
    esp_err_t ret;

    ret = ads1115_read_single(&ads1115_dev, ADS1115_MUX_SINGLE_0, &chan0_raw);
    if (ret != ESP_OK) {
        ESP_LOGE(GATTS_TAG, "Failed to read ADS1115 A0: %s", esp_err_to_name(ret));
        chan0_raw = 0;
    }

    ret = ads1115_read_single(&ads1115_dev, ADS1115_MUX_SINGLE_1, &chan1_raw);
    if (ret != ESP_OK) {
        ESP_LOGE(GATTS_TAG, "Failed to read ADS1115 A1: %s", esp_err_to_name(ret));
        chan1_raw = 0;
    }

    ret = ads1115_read_single(&ads1115_dev, ADS1115_MUX_SINGLE_2, &chan2_raw);
    if (ret != ESP_OK) {
        ESP_LOGE(GATTS_TAG, "Failed to read ADS1115 A2: %s", esp_err_to_name(ret));
        chan2_raw = 0;
    }

    ret = ads1115_read_single(&ads1115_dev, ADS1115_MUX_SINGLE_3, &chan3_raw);
    if (ret != ESP_OK) {
        ESP_LOGE(GATTS_TAG, "Failed to read ADS1115 A3: %s", esp_err_to_name(ret));
        chan3_raw = 0;
    }

    esp_gatt_rsp_t rsp;
    memset(&rsp, 0, sizeof(esp_gatt_rsp_t));
    rsp.attr_value.handle = param->read.handle;
    rsp.attr_value.len = 8;
    rsp.attr_value.value[0] = (chan0_raw >> 8) & 0xFF;
    rsp.attr_value.value[1] = chan0_raw & 0xFF;
    rsp.attr_value.value[2] = (chan1_raw >> 8) & 0xFF;
    rsp.attr_value.value[3] = chan1_raw & 0xFF;
    rsp.attr_value.value[4] = (chan2_raw >> 8) & 0xFF;
    rsp.attr_value.value[5] = chan2_raw & 0xFF;
    rsp.attr_value.value[6] = (chan3_raw >> 8) & 0xFF;
    rsp.attr_value.value[7] = chan3_raw & 0xFF;
    
    esp_ble_gatts_send_response(gatts_if, param->read.conn_id, param->read.trans_id,
                                ESP_GATT_OK, &rsp);
}

static void gatts_profile_a_event_handler(esp_gatts_cb_event_t event, esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param) {
    switch (event) {
    case ESP_GATTS_REG_EVT:
        gl_profile_tab[PROFILE_A_APP_ID].service_id.is_primary = true;
        gl_profile_tab[PROFILE_A_APP_ID].service_id.id.inst_id = 0x00;
        gl_profile_tab[PROFILE_A_APP_ID].service_id.id.uuid.len = ESP_UUID_LEN_16;
        gl_profile_tab[PROFILE_A_APP_ID].service_id.id.uuid.uuid.uuid16 = GATTS_SERVICE_UUID_TEST_A;

        esp_ble_gap_set_device_name(DEVICE_NAME);
        esp_ble_gap_config_adv_data(&adv_data);
        esp_ble_gatts_create_service(gatts_if, &gl_profile_tab[PROFILE_A_APP_ID].service_id, GATTS_NUM_HANDLE_TEST_A);
        break;
    case ESP_GATTS_READ_EVT:
        gatts_read_adc(gatts_if, param);
        break;
    case ESP_GATTS_WRITE_EVT:
        if (param->write.len == 1) {
            handle_dac_write(param->write.value[0]);
        }
        if (param->write.need_rsp) {
            esp_ble_gatts_send_response(gatts_if, param->write.conn_id, param->write.trans_id, ESP_GATT_OK, NULL);
        }
        break;
    case ESP_GATTS_CREATE_EVT:
        gl_profile_tab[PROFILE_A_APP_ID].service_handle = param->create.service_handle;
        gl_profile_tab[PROFILE_A_APP_ID].char_uuid.len = ESP_UUID_LEN_16;
        gl_profile_tab[PROFILE_A_APP_ID].char_uuid.uuid.uuid16 = GATTS_CHAR_UUID_TEST_A;
        esp_ble_gatts_start_service(gl_profile_tab[PROFILE_A_APP_ID].service_handle);
        a_property = ESP_GATT_CHAR_PROP_BIT_READ | ESP_GATT_CHAR_PROP_BIT_WRITE;
        esp_ble_gatts_add_char(gl_profile_tab[PROFILE_A_APP_ID].service_handle,
                              &gl_profile_tab[PROFILE_A_APP_ID].char_uuid,
                              ESP_GATT_PERM_READ | ESP_GATT_PERM_WRITE,
                              a_property,
                              &gatts_demo_char1_val, NULL);
        break;
    case ESP_GATTS_ADD_CHAR_EVT:
        gl_profile_tab[PROFILE_A_APP_ID].char_handle = param->add_char.attr_handle;
        break;
    case ESP_GATTS_CONNECT_EVT:
        gl_profile_tab[PROFILE_A_APP_ID].conn_id = param->connect.conn_id;
        break;
    case ESP_GATTS_DISCONNECT_EVT:
        esp_ble_gap_start_advertising(&adv_params);
        break;
    default:
        break;
    }
}

static void gatts_event_handler(esp_gatts_cb_event_t event, esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param)
{
    if (event == ESP_GATTS_REG_EVT) {
        if (param->reg.status == ESP_GATT_OK) {
            gl_profile_tab[param->reg.app_id].gatts_if = gatts_if;
        } else {
            return;
        }
    }

    for (int idx = 0; idx < PROFILE_NUM; idx++) {
        if (gatts_if == ESP_GATT_IF_NONE || gatts_if == gl_profile_tab[idx].gatts_if) {
            if (gl_profile_tab[idx].gatts_cb) {
                gl_profile_tab[idx].gatts_cb(event, gatts_if, param);
            }
        }
    }
}

#define DAC_AMPLITUDE 255
_Static_assert(DAC_AMPLITUDE < 256, "DAC is 8-bit");
static void dac_output_task(void *args)
{
    dac_oneshot_handle_t handle = (dac_oneshot_handle_t)args;
    while (1) {
        if (dac_enabled) {
            ESP_ERROR_CHECK(dac_oneshot_output_voltage(handle, dac_out_val));
        } else {
            ESP_ERROR_CHECK(dac_oneshot_output_voltage(handle, 255));
        }
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void app_main(void)
{
    dac_oneshot_handle_t chan0_handle;
    dac_oneshot_config_t chan0_cfg = {.chan_id = DAC_CHAN_0};
    ESP_ERROR_CHECK(dac_oneshot_new_channel(&chan0_cfg, &chan0_handle));
    xTaskCreate(dac_output_task, "dac_output_task", 4096, chan0_handle, 5, NULL);

    ESP_ERROR_CHECK(i2c_master_init());
    ESP_ERROR_CHECK(ads1115_setup());

    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    ESP_ERROR_CHECK(esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT));

    esp_bt_controller_config_t bt_cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();
    ret = esp_bt_controller_init(&bt_cfg);
    if (ret) {
        ESP_LOGE(GATTS_TAG, "%s initialize controller failed: %s", __func__, esp_err_to_name(ret));
        return;
    }

    ret = esp_bt_controller_enable(ESP_BT_MODE_BLE);
    if (ret) {
        ESP_LOGE(GATTS_TAG, "%s enable controller failed: %s", __func__, esp_err_to_name(ret));
        return;
    }

    ret = esp_bluedroid_init();
    if (ret) {
        ESP_LOGE(GATTS_TAG, "%s init bluetooth failed: %s", __func__, esp_err_to_name(ret));
        return;
    }
    ret = esp_bluedroid_enable();
    if (ret) {
        ESP_LOGE(GATTS_TAG, "%s enable bluetooth failed: %s", __func__, esp_err_to_name(ret));
        return;
    }

    ESP_ERROR_CHECK(esp_ble_gatts_register_callback(gatts_event_handler));
    ESP_ERROR_CHECK(esp_ble_gap_register_callback(gap_event_handler));
    ESP_ERROR_CHECK(esp_ble_gatts_app_register(PROFILE_A_APP_ID));
    esp_ble_gatt_set_local_mtu(500);
}
