cmake_minimum_required(VERSION 3.20)
project(slozos-spotlight LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Quick Qml Network DBus)
find_package(KF6WindowSystem REQUIRED)
find_package(LayerShellQt REQUIRED)

add_executable(slozos-spotlight main.cpp spotlight.qrc)
target_link_libraries(slozos-spotlight PRIVATE
    Qt6::Gui Qt6::Quick Qt6::Qml Qt6::Network Qt6::DBus
    KF6::WindowSystem LayerShellQt::Interface)

install(TARGETS slozos-spotlight DESTINATION bin)
install(FILES org.slozos.spotlight.desktop DESTINATION share/applications)
