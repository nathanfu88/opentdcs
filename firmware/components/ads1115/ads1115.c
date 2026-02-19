#include "ads1115.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "ADS1115";

#define ADS1115_TIMEOUT_MS 1000

static esp_err_t ads1115_write_reg(ads1115_handle_t *dev, uint8_t reg, uint16_t value)
{
    uint8_t data[3];
    data[0] = reg;
    data[1] = (value >> 8) & 0xFF;  // MSB
    data[2] = value & 0xFF;         // LSB
    
    return i2c_master_transmit(dev->i2c_dev_handle, data, sizeof(data), ADS1115_TIMEOUT_MS);
}

static esp_err_t ads1115_read_reg(ads1115_handle_t *dev, uint8_t reg, uint16_t *value)
{
    esp_err_t ret;
    uint8_t data[2];
    
    ret = i2c_master_transmit_receive(dev->i2c_dev_handle, &reg, 1, data, 2, ADS1115_TIMEOUT_MS);
    if (ret != ESP_OK) {
        return ret;
    }
    
    *value = ((uint16_t)data[0] << 8) | data[1];
    return ESP_OK;
}

esp_err_t ads1115_init(ads1115_handle_t *dev, const ads1115_config_t *config, i2c_master_bus_handle_t bus_handle)
{
    if (!dev || !config || !bus_handle) {
        return ESP_ERR_INVALID_ARG;
    }
    
    dev->config = *config;
    
    // Create I2C device handle
    i2c_device_config_t dev_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = config->addr,
        .scl_speed_hz = 100000,  // 100kHz
    };
    
    esp_err_t ret = i2c_master_bus_add_device(bus_handle, &dev_cfg, &dev->i2c_dev_handle);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to add I2C device: %s", esp_err_to_name(ret));
        return ret;
    }
    
    dev->initialized = true;
    
    ESP_LOGI(TAG, "ADS1115 initialized with address 0x%02x", config->addr);
    
    return ESP_OK;
}

esp_err_t ads1115_read_single(ads1115_handle_t *dev, uint16_t mux, int16_t *raw_value)
{
    if (!dev || !dev->initialized || !raw_value) {
        return ESP_ERR_INVALID_ARG;
    }
    
    esp_err_t ret;
    uint16_t config_reg;
    uint16_t conversion_reg;
    
    // Build configuration register value
    config_reg = ADS1115_OS_SINGLE |    // Start single conversion
                 mux |                   // Input multiplexer
                 dev->config.gain |      // Gain setting
                 ADS1115_CMODE_TRAD |    // Traditional comparator
                 ADS1115_CPOL_ACTVLOW |  // Comparator polarity
                 ADS1115_CLAT_NONLAT |   // Non-latching comparator
                 ADS1115_CQUE_NONE |     // Disable comparator
                 dev->config.data_rate;  // Data rate
    
    // Write configuration to start conversion
    ESP_LOGD(TAG, "Starting conversion with config: 0x%04X (mux=0x%04X, gain=0x%04X, rate=0x%04X)", 
             config_reg, mux, dev->config.gain, dev->config.data_rate);
    
    ret = ads1115_write_reg(dev, ADS1115_REG_CONFIG, config_reg);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to write config register: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Verify the write was successful by reading back
    uint16_t readback_config;
    ret = ads1115_read_reg(dev, ADS1115_REG_CONFIG, &readback_config);
    if (ret == ESP_OK) {
        ESP_LOGD(TAG, "Config readback: 0x%04X (expected: 0x%04X)", readback_config, config_reg);
        if ((readback_config & ~ADS1115_OS_NOTBUSY) != (config_reg & ~ADS1115_OS_NOTBUSY)) {
            ESP_LOGW(TAG, "Config readback mismatch - I2C communication issue?");
        }
    }
    
    // Wait for conversion to complete using fixed delay
    // Calculate delay based on data rate with sufficient margin for reliability
    uint32_t delay_ms;
    switch (dev->config.data_rate) {
        case ADS1115_DR_8SPS:   delay_ms = 130; break;  // ~125ms theoretical + margin
        case ADS1115_DR_16SPS:  delay_ms = 70;  break;  // ~62.5ms theoretical + margin
        case ADS1115_DR_32SPS:  delay_ms = 35;  break;  // ~31.25ms theoretical + margin
        case ADS1115_DR_64SPS:  delay_ms = 20;  break;  // ~15.6ms theoretical + margin
        case ADS1115_DR_128SPS: delay_ms = 10;  break;  // ~7.8ms theoretical + margin
        case ADS1115_DR_250SPS: delay_ms = 5;   break;  // ~4ms theoretical + margin
        case ADS1115_DR_475SPS: delay_ms = 3;   break;  // ~2.1ms theoretical + margin
        case ADS1115_DR_860SPS: delay_ms = 2;   break;  // ~1.16ms theoretical + margin
        default:                delay_ms = 10;  break;
    }
    
    ESP_LOGD(TAG, "Waiting %u ms for conversion to complete", (unsigned)delay_ms);
    vTaskDelay(pdMS_TO_TICKS(delay_ms));
    
    // Read conversion result
    ret = ads1115_read_reg(dev, ADS1115_REG_CONVERSION, &conversion_reg);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to read conversion register: %s", esp_err_to_name(ret));
        return ret;
    }
    
    *raw_value = (int16_t)conversion_reg;
    ESP_LOGD(TAG, "Conversion successful: raw=0x%04X (%d)", conversion_reg, *raw_value);
    return ESP_OK;
}

esp_err_t ads1115_read_voltage(ads1115_handle_t *dev, uint16_t mux, float *voltage)
{
    if (!voltage) {
        return ESP_ERR_INVALID_ARG;
    }
    
    int16_t raw_value;
    esp_err_t ret = ads1115_read_single(dev, mux, &raw_value);
    if (ret != ESP_OK) {
        return ret;
    }
    
    *voltage = ads1115_raw_to_voltage(raw_value, dev->config.gain);
    return ESP_OK;
}

float ads1115_raw_to_voltage(int16_t raw_value, uint16_t gain)
{
    float lsb_size;
    
    // Determine LSB size based on gain setting
    switch (gain) {
        case ADS1115_PGA_6_144V: lsb_size = 0.1875f; break;  // mV per LSB
        case ADS1115_PGA_4_096V: lsb_size = 0.125f;  break;
        case ADS1115_PGA_2_048V: lsb_size = 0.0625f; break;
        case ADS1115_PGA_1_024V: lsb_size = 0.03125f; break;
        case ADS1115_PGA_0_512V: lsb_size = 0.015625f; break;
        case ADS1115_PGA_0_256V: lsb_size = 0.0078125f; break;
        default:                 lsb_size = 0.125f;   break;  // Default to 4.096V range
    }
    
    return (float)raw_value * lsb_size;  // Returns voltage in mV
}