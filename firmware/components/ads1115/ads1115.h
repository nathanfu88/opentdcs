#ifndef ADS1115_H
#define ADS1115_H

#include <stdint.h>
#include "esp_err.h"
#include "driver/i2c_master.h"

#ifdef __cplusplus
extern "C" {
#endif

#define ADS1115_I2C_ADDR_DEFAULT    0x48
#define ADS1115_I2C_ADDR_VDD        0x49
#define ADS1115_I2C_ADDR_SDA        0x4A
#define ADS1115_I2C_ADDR_SCL        0x4B

#define ADS1115_REG_CONVERSION      0x00
#define ADS1115_REG_CONFIG          0x01
#define ADS1115_REG_LO_THRESH       0x02
#define ADS1115_REG_HI_THRESH       0x03

// Configuration register bits
#define ADS1115_OS_SINGLE           0x8000
#define ADS1115_OS_BUSY             0x0000
#define ADS1115_OS_NOTBUSY          0x8000

// Multiplexer configuration
#define ADS1115_MUX_DIFF_0_1        0x0000  // Differential P = AIN0, N = AIN1 (default)
#define ADS1115_MUX_DIFF_0_3        0x1000  // Differential P = AIN0, N = AIN3
#define ADS1115_MUX_DIFF_1_3        0x2000  // Differential P = AIN1, N = AIN3
#define ADS1115_MUX_DIFF_2_3        0x3000  // Differential P = AIN2, N = AIN3
#define ADS1115_MUX_SINGLE_0        0x4000  // Single-ended AIN0
#define ADS1115_MUX_SINGLE_1        0x5000  // Single-ended AIN1
#define ADS1115_MUX_SINGLE_2        0x6000  // Single-ended AIN2
#define ADS1115_MUX_SINGLE_3        0x7000  // Single-ended AIN3

// Gain amplifier configuration
#define ADS1115_PGA_6_144V          0x0000  // +/-6.144V range = Gain 2/3
#define ADS1115_PGA_4_096V          0x0200  // +/-4.096V range = Gain 1 (default)
#define ADS1115_PGA_2_048V          0x0400  // +/-2.048V range = Gain 2
#define ADS1115_PGA_1_024V          0x0600  // +/-1.024V range = Gain 4
#define ADS1115_PGA_0_512V          0x0800  // +/-0.512V range = Gain 8
#define ADS1115_PGA_0_256V          0x0A00  // +/-0.256V range = Gain 16

// Data rate
#define ADS1115_DR_8SPS             0x0000  // 8 samples per second
#define ADS1115_DR_16SPS            0x0020  // 16 samples per second
#define ADS1115_DR_32SPS            0x0040  // 32 samples per second
#define ADS1115_DR_64SPS            0x0060  // 64 samples per second
#define ADS1115_DR_128SPS           0x0080  // 128 samples per second (default)
#define ADS1115_DR_250SPS           0x00A0  // 250 samples per second
#define ADS1115_DR_475SPS           0x00C0  // 475 samples per second
#define ADS1115_DR_860SPS           0x00E0  // 860 samples per second

// Comparator mode
#define ADS1115_CMODE_TRAD          0x0000  // Traditional comparator with hysteresis (default)
#define ADS1115_CMODE_WINDOW        0x0010  // Window comparator

// Comparator polarity
#define ADS1115_CPOL_ACTVLOW        0x0000  // ALERT/RDY pin is low when active (default)
#define ADS1115_CPOL_ACTVHI         0x0008  // ALERT/RDY pin is high when active

// Latching comparator
#define ADS1115_CLAT_NONLAT         0x0000  // Non-latching comparator (default)
#define ADS1115_CLAT_LATCH          0x0004  // Latching comparator

// Comparator queue
#define ADS1115_CQUE_1CONV          0x0000  // Assert ALERT/RDY after one conversions
#define ADS1115_CQUE_2CONV          0x0001  // Assert ALERT/RDY after two conversions
#define ADS1115_CQUE_4CONV          0x0002  // Assert ALERT/RDY after four conversions
#define ADS1115_CQUE_NONE           0x0003  // Disable the comparator and put ALERT/RDY in high state (default)

typedef struct {
    uint8_t addr;
    uint16_t gain;
    uint16_t data_rate;
} ads1115_config_t;

typedef struct {
    ads1115_config_t config;
    i2c_master_dev_handle_t i2c_dev_handle;
    bool initialized;
} ads1115_handle_t;

esp_err_t ads1115_init(ads1115_handle_t *dev, const ads1115_config_t *config, i2c_master_bus_handle_t bus_handle);
esp_err_t ads1115_read_single(ads1115_handle_t *dev, uint16_t mux, int16_t *raw_value);
esp_err_t ads1115_read_voltage(ads1115_handle_t *dev, uint16_t mux, float *voltage);
float ads1115_raw_to_voltage(int16_t raw_value, uint16_t gain);

#ifdef __cplusplus
}
#endif

#endif // ADS1115_H