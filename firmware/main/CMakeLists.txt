# This file was automatically generated for projects
# without default 'CMakeLists.txt' file.

FILE(GLOB_RECURSE app_sources ${CMAKE_SOURCE_DIR}/main/*.*)

idf_component_register(SRCS ${app_sources}
                       REQUIRES esp_driver_dac nvs_flash bt driver ads1115)
