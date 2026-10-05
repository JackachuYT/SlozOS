cmake_minimum_required(VERSION 3.20)
project(slozos-welcome LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Quick Qml QuickControls2)

add_executable(slozos-welcome main.cpp welcome.qrc)
target_link_libraries(slozos-welcome PRIVATE Qt6::Gui Qt6::Quick Qt6::Qml Qt6::QuickControls2)

install(TARGETS slozos-welcome DESTINATION bin)
install(FILES org.slozos.welcome.desktop DESTINATION share/applications)
