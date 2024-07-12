# Register the app as an IDF component
idf_component_register(
    SRCS "ESP32BLEControllerInterface.cpp"
    PRIV_INCLUDE_DIRS "."
    REQUIRES bt
)