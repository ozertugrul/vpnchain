cmake_minimum_required(VERSION 3.22.1)

project("udpspeeder")

add_library(
        udpspeeder
        SHARED
        UDPspeederJNI.cpp)

find_library(
        log-lib
        log)

target_link_libraries(
        udpspeeder
        ${log-lib})
