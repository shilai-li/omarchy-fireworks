cmake_minimum_required(VERSION 3.24)
project(OmarchyFireworks VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_BUILD_RPATH_USE_ORIGIN TRUE)
find_package(Qt6 6.7 REQUIRED COMPONENTS Core Gui GuiPrivate Qml Quick QuickControls2 ShaderTools Multimedia Concurrent)
qt_standard_project_setup()

add_library(fireworks_core SHARED
    src/simulation.cpp src/simulation.h src/palette.h src/shell.h
    src/audio.cpp src/audio.h
    src/renderer.cpp src/renderer.h
    src/fireworksview.cpp src/fireworksview.h
    src/showdirector.cpp src/showdirector.h)
target_include_directories(fireworks_core PUBLIC src)
target_link_libraries(fireworks_core PUBLIC Qt6::Quick Qt6::Multimedia PRIVATE Qt6::GuiPrivate Qt6::Concurrent)
target_compile_options(fireworks_core PRIVATE -Wall -Wextra -Wpedantic)
qt_add_shaders(fireworks_core fireworks_shaders
    PREFIX /fireworks BASE shaders
    GLSL "330,300es" HLSL 50 MSL 12
    FILES shaders/scene.vert shaders/scene.frag shaders/post.vert shaders/post.frag)

add_library(fireworksplugin MODULE src/plugin.cpp)
target_link_libraries(fireworksplugin PRIVATE fireworks_core Qt6::Qml)
set_target_properties(fireworksplugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Omarchy/Fireworks"
    BUILD_RPATH "$ORIGIN;$ORIGIN/../../.." INSTALL_RPATH "$ORIGIN")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Omarchy/Fireworks")
configure_file(qml/qmldir "${CMAKE_BINARY_DIR}/qml/Omarchy/Fireworks/qmldir" COPYONLY)

add_executable(omarchy-fireworks src/main.cpp)
target_link_libraries(omarchy-fireworks PRIVATE fireworks_core Qt6::QuickControls2)
qt_add_resources(omarchy-fireworks preview PREFIX / FILES qml/Preview.qml)

add_executable(fireworks-capture src/capture.cpp)
find_path(FIREWORKS_VULKAN_INCLUDE_DIR vulkan/vulkan.h REQUIRED)
target_include_directories(fireworks-capture PRIVATE "${FIREWORKS_VULKAN_INCLUDE_DIR}")
target_link_libraries(fireworks-capture PRIVATE fireworks_core Qt6::GuiPrivate)

include(CTest)
if(BUILD_TESTING)
    add_executable(fireworks-tests tests/engine_tests.cpp)
    target_link_libraries(fireworks-tests PRIVATE fireworks_core)
    add_test(NAME engine COMMAND fireworks-tests)
    add_executable(fireworks-shell-tests tests/shell_tests.cpp)
    target_link_libraries(fireworks-shell-tests PRIVATE fireworks_core)
    add_test(NAME authored-shells COMMAND fireworks-shell-tests)
    find_program(FIREWORKS_QML_EXECUTABLE qml HINTS /usr/lib/qt6/bin REQUIRED)
    configure_file(tests/import.qml.in "${CMAKE_BINARY_DIR}/tests/import.qml" @ONLY)
    configure_file(tests/launch-pool.qml.in "${CMAKE_BINARY_DIR}/tests/launch-pool.qml" @ONLY)
    configure_file(tests/overlay.qml.in "${CMAKE_BINARY_DIR}/tests/overlay.qml" @ONLY)
    add_test(NAME native-qml-import COMMAND "${FIREWORKS_QML_EXECUTABLE}" "${CMAKE_BINARY_DIR}/tests/import.qml")
    add_test(NAME overlapping-launches COMMAND "${FIREWORKS_QML_EXECUTABLE}" "${CMAKE_BINARY_DIR}/tests/launch-pool.qml")
    set_tests_properties(native-qml-import overlapping-launches PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QPA_PLATFORMTHEME=generic;QT_FORCE_STDERR_LOGGING=1"
        TIMEOUT 10)
endif()

# A relocatable user plugin bundle. No system or desktop files are changed here.
# The plugin itself lives at the repo root, a sibling of backend/ (this
# directory), so it can be `omarchy plugin add`ed directly — an Omarchy plugin
# is cloned files only, and manifest.json has to be at the root of that clone.
# copy_directory can't be used to gather it: the repo root also contains
# backend/ itself, docs/, and .git — only these seven files are the plugin.
get_filename_component(FIREWORKS_REPO_ROOT "${CMAKE_SOURCE_DIR}/.." ABSOLUTE)
set(FIREWORKS_PLUGIN_FILES
    Fireworks.qml BarWidget.qml FireworksState.qml LaunchPool.qml
    fireworks-ctl.sh qmldir manifest.json)
list(TRANSFORM FIREWORKS_PLUGIN_FILES PREPEND "${FIREWORKS_REPO_ROOT}/")

add_custom_target(plugin-bundle ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/plugin/native"
    COMMAND ${CMAKE_COMMAND} -E copy ${FIREWORKS_PLUGIN_FILES} "${CMAKE_BINARY_DIR}/plugin"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:fireworksplugin>" "${CMAKE_BINARY_DIR}/plugin/native/"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:fireworks_core>" "${CMAKE_BINARY_DIR}/plugin/native/"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/qml/qmldir" "${CMAKE_BINARY_DIR}/plugin/native/qmldir"
    DEPENDS fireworksplugin fireworks_core)
set_target_properties(fireworks_core PROPERTIES BUILD_RPATH "$ORIGIN" INSTALL_RPATH "$ORIGIN")
