cmake_minimum_required(VERSION 3.20)
project(slozos-dock LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Quick Qml)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6KIO REQUIRED)
find_package(LayerShellQt REQUIRED)

add_executable(slozos-dock main.cpp dock.qrc)
target_link_libraries(slozos-dock PRIVATE
    Qt6::Gui Qt6::Quick Qt6::Qml
    KF6::WindowSystem KF6::KIOCore KF6::KIOGui LayerShellQt::Interface)

install(TARGETS slozos-dock DESTINATION bin)
install(FILES org.slozos.dock.desktop DESTINATION share/applications)
