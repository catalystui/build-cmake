execute_process(
    COMMAND git rev-parse --short=7 HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_HASH
    RESULT_VARIABLE GIT_RESULT
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

# Enable Windows resources at file scope for MSVC DLL version metadata.
if(WIN32 AND MSVC AND NOT CMAKE_RC_COMPILER_LOADED)
    enable_language(RC)
endif()

function(metadata name version_major version_minor version_patch version_dash description)
    set(METADATA_NAME ${name})
    set(METADATA_VERSION_MAJOR ${version_major})
    set(METADATA_VERSION_MINOR ${version_minor})
    set(METADATA_VERSION_PATCH ${version_patch})
    if(NOT "${version_dash}" STREQUAL "")
        if (GIT_RESULT EQUAL 0)
            set(version_prerelease "-${version_dash}+${GIT_HASH}")
        else()
            set(version_prerelease "-${version_dash}")
        endif()
    endif()
    set(METADATA_VERSION ${version_major}.${version_minor}.${version_patch}${version_prerelease})
    set(METADATA_DESCRIPTION ${description})

    set(METADATA_NAME ${METADATA_NAME} PARENT_SCOPE)
    set(METADATA_VERSION_MAJOR ${METADATA_VERSION_MAJOR} PARENT_SCOPE)
    set(METADATA_VERSION_MINOR ${METADATA_VERSION_MINOR} PARENT_SCOPE)
    set(METADATA_VERSION_PATCH ${METADATA_VERSION_PATCH} PARENT_SCOPE)
    set(METADATA_VERSION ${METADATA_VERSION} PARENT_SCOPE)
    set(METADATA_DESCRIPTION ${METADATA_DESCRIPTION} PARENT_SCOPE)

    message(STATUS "Preparing build files for: ${METADATA_NAME} v${METADATA_VERSION}")
endfunction()

function(configure target_vendor target_system target_architecture)
    set(TARGET_VENDOR ${target_vendor} PARENT_SCOPE)
    set(TARGET_SYSTEM ${target_system} PARENT_SCOPE)
    set(TARGET_ARCHITECTURE ${target_architecture} PARENT_SCOPE)

    set(OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/build/${target_vendor}/${target_system}")
    if(NOT "${target_architecture}" STREQUAL "")
        set(OUTPUT_DIRECTORY "${OUTPUT_DIRECTORY}/${target_architecture}")
    endif()
    message(STATUS "Setting output directory: ${OUTPUT_DIRECTORY}")
    file(REMOVE_RECURSE "${OUTPUT_DIRECTORY}")
    file(MAKE_DIRECTORY "${OUTPUT_DIRECTORY}")
    get_property(CONFIGURE_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(CONFIGURE_MULTI_CONFIG)
        # Restrict generated projects and configuration-dependent byproducts
        # to the two supported build configurations, including existing caches.
        set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "Build configurations" FORCE)
        set(CMAKE_CONFIGURATION_TYPES "Debug;Release")
        set(CMAKE_CONFIGURATION_TYPES "Debug;Release" PARENT_SCOPE)
        foreach(CONFIG_NAME ${CMAKE_CONFIGURATION_TYPES})
            string(TOLOWER "${CONFIG_NAME}" CONFIG_LOWER)
            file(MAKE_DIRECTORY "${OUTPUT_DIRECTORY}/${CONFIG_LOWER}")
        endforeach()
        set(OUTPUT_DIRECTORY "${OUTPUT_DIRECTORY}/$<LOWER_CASE:$<CONFIG>>")
    else()
        if(NOT CMAKE_BUILD_TYPE)
            set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
        endif()
        string(TOLOWER "${CMAKE_BUILD_TYPE}" CONFIG_LOWER)
        set(OUTPUT_DIRECTORY "${OUTPUT_DIRECTORY}/${CONFIG_LOWER}")
        file(MAKE_DIRECTORY "${OUTPUT_DIRECTORY}")
    endif()

    # Runtime binaries go in the configuration root; linker inputs go in lib/.
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_DIRECTORY}" PARENT_SCOPE)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_DIRECTORY}" PARENT_SCOPE)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${OUTPUT_DIRECTORY}/lib" PARENT_SCOPE)

    # Identify target platform
    if(TARGET_VENDOR STREQUAL "microsoft" AND (TARGET_SYSTEM MATCHES "^nt" OR TARGET_SYSTEM MATCHES "^win"))
        set(CONFIGURE_FOUND_PLATFORM 1)
        set(TARGET_PLATFORM_WIN32 1 PARENT_SCOPE)
        set(TARGET_PLATFORM_WIN32 1)
        message(STATUS "Identified target platform as Win32 based on vendor '${TARGET_VENDOR}' and system '${TARGET_SYSTEM}'")
    else()
        set(TARGET_PLATFORM_WIN32 0 PARENT_SCOPE)
        set(TARGET_PLATFORM_WIN32 0)
        add_compile_definitions(TARGET_PLATFORM_WIN32=0)
    endif()
    if(TARGET_VENDOR STREQUAL "apple" AND TARGET_SYSTEM MATCHES "^darwin")
        set(CONFIGURE_FOUND_PLATFORM 1)
        set(TARGET_PLATFORM_DARWIN 1 PARENT_SCOPE)
        set(TARGET_PLATFORM_DARWIN 1)
        message(STATUS "Identified target platform as Darwin based on vendor '${TARGET_VENDOR}' and system '${TARGET_SYSTEM}'")
    else()
        set(TARGET_PLATFORM_DARWIN 0 PARENT_SCOPE)
        set(TARGET_PLATFORM_DARWIN 0)
    endif()
    if(TARGET_VENDOR STREQUAL "linux" AND TARGET_SYSTEM MATCHES "^linux")
        set(CONFIGURE_FOUND_PLATFORM 1)
        set(TARGET_PLATFORM_LINUX 1 PARENT_SCOPE)
        set(TARGET_PLATFORM_LINUX 1)
        message(STATUS "Identified target platform as Linux based on vendor '${TARGET_VENDOR}' and system '${TARGET_SYSTEM}'")
    else()
        set(TARGET_PLATFORM_LINUX 0 PARENT_SCOPE)
        set(TARGET_PLATFORM_LINUX 0)
    endif()
    if(NOT CONFIGURE_FOUND_PLATFORM)
        message(FATAL_ERROR "Unable to identify a target platform based on vendor '${TARGET_VENDOR}' and system '${TARGET_SYSTEM}'")
    endif()

    # Set library prefixes based on platform conventions
    set(CMAKE_STATIC_LIBRARY_PREFIX "lib" PARENT_SCOPE)
    if(TARGET_PLATFORM_DARWIN OR TARGET_PLATFORM_LINUX)
        set(CMAKE_SHARED_LIBRARY_PREFIX "lib" PARENT_SCOPE)
        message(STATUS "Using 'lib' prefix (UNIX-like conventions) for shared and static libraries")
    else()
        set(CMAKE_SHARED_LIBRARY_PREFIX "" PARENT_SCOPE)
        message(STATUS "Using no shared library prefix and a static library lib prefix")
    endif()

    # Resolve runtime dependencies relative to the binary, not the build machine.
    if(TARGET_PLATFORM_LINUX)
        set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE PARENT_SCOPE)
        set(CMAKE_INSTALL_RPATH "$ORIGIN" PARENT_SCOPE)
    elseif(TARGET_PLATFORM_DARWIN)
        set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE PARENT_SCOPE)
        set(CMAKE_INSTALL_RPATH "@loader_path" PARENT_SCOPE)
        set(CMAKE_INSTALL_NAME_DIR "@rpath" PARENT_SCOPE)
        set(CMAKE_BUILD_WITH_INSTALL_NAME_DIR TRUE PARENT_SCOPE)
    endif()

    # Identify UNICODE support
    if(TARGET_VENDOR STREQUAL "microsoft" AND (TARGET_SYSTEM MATCHES "^nt"))
        set(TARGET_SUPPORTS_UNICODE 1 PARENT_SCOPE)
    elseif(TARGET_VENDOR STREQUAL "apple" AND TARGET_SYSTEM MATCHES "^darwin")
        # TODO: Determine when the cutoff for UNICODE support on Darwin is, and condition this on the version
        set(TARGET_SUPPORTS_UNICODE 1 PARENT_SCOPE)
    elseif(TARGET_VENDOR STREQUAL "linux" AND TARGET_SYSTEM MATCHES "^linux")
        # TODO: Determine when the cutoff for UNICODE support on Linux is, and condition this on the version and/or C library
        set(TARGET_SUPPORTS_UNICODE 1 PARENT_SCOPE)
    else()
        set(TARGET_SUPPORTS_UNICODE 0 PARENT_SCOPE)
    endif()

    # Identify the STDC version
    if (CMAKE_C_STANDARD STREQUAL "95")
        set(TARGET_STDC_VERSION 199409L)
    elseif (CMAKE_C_STANDARD STREQUAL "99")
        set(TARGET_STDC_VERSION 199901L)
    elseif (CMAKE_C_STANDARD STREQUAL "11")
        set(TARGET_STDC_VERSION 201112L)
    elseif (CMAKE_C_STANDARD STREQUAL "17")
        set(TARGET_STDC_VERSION 201710L)
    elseif (CMAKE_C_STANDARD STREQUAL "23")
        set(TARGET_STDC_VERSION 202311L)
    else()
        set(TARGET_STDC_VERSION 0)
    endif()
    set(TARGET_STDC_VERSION ${TARGET_STDC_VERSION} PARENT_SCOPE)
    message(STATUS "Identified C standard version as ${CMAKE_C_STANDARD} (STDC version ${TARGET_STDC_VERSION})")

    # Determine the size of a pointer
    include(CheckTypeSize)
    check_type_size("void*" TARGET_SIZEOF_VOID_P)
    set(TARGET_SIZEOF_VOID_P ${TARGET_SIZEOF_VOID_P} PARENT_SCOPE)
    message(STATUS "Determined size of void* pointer: ${TARGET_SIZEOF_VOID_P} bytes")
endfunction()

function(configure_target)
    cmake_parse_arguments(ARG "" "NAME;FOLDER;SUBDIR" "TARGETS;SOURCES;DEPENDS" ${ARGN})
    set(ARG_SUBDIR_LOWER "")
    if(NOT "${ARG_SUBDIR}" STREQUAL "")
        string(TOLOWER "${ARG_SUBDIR}" ARG_SUBDIR_LOWER)
    endif()
    foreach(TARGET_NAME ${ARG_TARGETS})
        get_target_property(CONFIGURE_TARGET_TYPE ${TARGET_NAME} TYPE)

        # Set output name and folder if specified
        if(NOT "${ARG_NAME}" STREQUAL "")
            set(CONFIGURE_OUTPUT_NAME "${ARG_NAME}")
            if(
                CONFIGURE_TARGET_TYPE STREQUAL "STATIC_LIBRARY" OR
                CONFIGURE_TARGET_TYPE STREQUAL "SHARED_LIBRARY" OR
                CONFIGURE_TARGET_TYPE STREQUAL "MODULE_LIBRARY"
            )
                string(TOLOWER "${CONFIGURE_OUTPUT_NAME}" CONFIGURE_OUTPUT_NAME)

                # The lib marker is an artifact prefix, not part of the base name.
                string(REGEX REPLACE "lib$" "" CONFIGURE_OUTPUT_NAME "${CONFIGURE_OUTPUT_NAME}")
            elseif(TARGET_PLATFORM_DARWIN OR TARGET_PLATFORM_LINUX)
                string(TOLOWER "${CONFIGURE_OUTPUT_NAME}" CONFIGURE_OUTPUT_NAME)
            endif()
            set_target_properties(${TARGET_NAME} PROPERTIES
                OUTPUT_NAME "${CONFIGURE_OUTPUT_NAME}"
            )
            if(CONFIGURE_TARGET_TYPE STREQUAL "STATIC_LIBRARY")
                set_target_properties(${TARGET_NAME} PROPERTIES PREFIX "lib")
            elseif(CONFIGURE_TARGET_TYPE STREQUAL "SHARED_LIBRARY")
                if(DEFINED METADATA_VERSION_MAJOR AND DEFINED METADATA_VERSION_MINOR AND DEFINED METADATA_VERSION_PATCH)
                    set(CONFIGURE_LIBRARY_VERSION "${METADATA_VERSION_MAJOR}.${METADATA_VERSION_MINOR}.${METADATA_VERSION_PATCH}")
                    set(CONFIGURE_ABI_VERSION "${METADATA_VERSION_MAJOR}.${METADATA_VERSION_MINOR}")
                    if(TARGET_PLATFORM_WIN32)
                        set(CONFIGURE_DLL_NAME "${CONFIGURE_OUTPUT_NAME}${METADATA_VERSION_MAJOR}${METADATA_VERSION_MINOR}")
                        set_target_properties(${TARGET_NAME} PROPERTIES
                            PREFIX ""
                            IMPORT_PREFIX ""
                            RUNTIME_OUTPUT_NAME "${CONFIGURE_DLL_NAME}"
                            ARCHIVE_OUTPUT_NAME "${CONFIGURE_OUTPUT_NAME}"
                            VERSION "${CONFIGURE_LIBRARY_VERSION}"
                        )
                        if(MSVC)
                            set(CONFIGURE_VERSION_RESOURCE "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}.rc")
                            configure_file(
                                "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/CMakeVersion.rc.in"
                                "${CONFIGURE_VERSION_RESOURCE}"
                                @ONLY
                            )
                            target_sources(${TARGET_NAME} PRIVATE "${CONFIGURE_VERSION_RESOURCE}")
                        endif()
                    endif()
                endif()
            endif()
        endif()
        if(NOT "${ARG_FOLDER}" STREQUAL "")
            set_target_properties(${TARGET_NAME} PROPERTIES
                FOLDER "${ARG_FOLDER}"
            )
        endif()

        # Set output subdirectory if specified
        if(NOT "${ARG_SUBDIR_LOWER}" STREQUAL "")
            if(CONFIGURE_TARGET_TYPE STREQUAL "EXECUTABLE")
                set_target_properties(${TARGET_NAME} PROPERTIES
                    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${ARG_SUBDIR_LOWER}"
                )
            elseif(CONFIGURE_TARGET_TYPE STREQUAL "STATIC_LIBRARY")
                set_target_properties(${TARGET_NAME} PROPERTIES
                    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/${ARG_SUBDIR_LOWER}"
                )
            elseif(CONFIGURE_TARGET_TYPE STREQUAL "SHARED_LIBRARY")
                if(TARGET_PLATFORM_WIN32)
                    set_target_properties(${TARGET_NAME} PROPERTIES
                        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${ARG_SUBDIR_LOWER}"
                        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/${ARG_SUBDIR_LOWER}"
                    )
                else()
                    set_target_properties(${TARGET_NAME} PROPERTIES
                        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${ARG_SUBDIR_LOWER}"
                    )
                endif()
            elseif(CONFIGURE_TARGET_TYPE STREQUAL "MODULE_LIBRARY")
                set_target_properties(${TARGET_NAME} PROPERTIES
                    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${ARG_SUBDIR_LOWER}"
                )
            endif()
        endif()

        # CMake's automatic namelink is always beside the versioned binary.
        # Name the real Unix binary directly, set its ABI identity explicitly,
        # and generate the runtime and development links in their proper directories.
        if(NOT "${ARG_NAME}" STREQUAL "" AND CONFIGURE_TARGET_TYPE STREQUAL "SHARED_LIBRARY"
            AND (TARGET_PLATFORM_DARWIN OR TARGET_PLATFORM_LINUX)
            AND DEFINED METADATA_VERSION_MAJOR AND DEFINED METADATA_VERSION_MINOR AND DEFINED METADATA_VERSION_PATCH)
            set(CONFIGURE_BASE_NAME "lib${CONFIGURE_OUTPUT_NAME}")
            if(TARGET_PLATFORM_DARWIN)
                set(CONFIGURE_SUFFIX ".${CONFIGURE_LIBRARY_VERSION}.dylib")
                set(CONFIGURE_ABI_NAME "${CONFIGURE_BASE_NAME}.${CONFIGURE_ABI_VERSION}.dylib")
                set(CONFIGURE_LINKER_NAME "${CONFIGURE_BASE_NAME}.dylib")
                target_link_options(${TARGET_NAME} PRIVATE
                    "LINKER:-install_name,@rpath/${CONFIGURE_ABI_NAME}"
                    "LINKER:-compatibility_version,${CONFIGURE_ABI_VERSION}"
                    "LINKER:-current_version,${CONFIGURE_LIBRARY_VERSION}"
                )
            else()
                set(CONFIGURE_SUFFIX ".so.${CONFIGURE_LIBRARY_VERSION}")
                set(CONFIGURE_ABI_NAME "${CONFIGURE_BASE_NAME}.so.${CONFIGURE_ABI_VERSION}")
                set(CONFIGURE_LINKER_NAME "${CONFIGURE_BASE_NAME}.so")
                target_link_options(${TARGET_NAME} PRIVATE "LINKER:-soname,${CONFIGURE_ABI_NAME}")
            endif()
            set_target_properties(${TARGET_NAME} PROPERTIES
                PREFIX "lib"
                SUFFIX "${CONFIGURE_SUFFIX}"
                NO_SONAME TRUE
            )
            set(CONFIGURE_RUNTIME_DIR "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
            set(CONFIGURE_LINKER_DIR "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
            set(CONFIGURE_LINK_TARGET "../${CONFIGURE_ABI_NAME}")
            if(NOT "${ARG_SUBDIR_LOWER}" STREQUAL "")
                set(CONFIGURE_RUNTIME_DIR "${CONFIGURE_RUNTIME_DIR}/${ARG_SUBDIR_LOWER}")
                set(CONFIGURE_LINKER_DIR "${CONFIGURE_LINKER_DIR}/${ARG_SUBDIR_LOWER}")
                file(RELATIVE_PATH CONFIGURE_LINK_TARGET
                    "/output/lib/${ARG_SUBDIR_LOWER}"
                    "/output/${ARG_SUBDIR_LOWER}/${CONFIGURE_ABI_NAME}"
                )
            endif()
            add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
                BYPRODUCTS
                    "${CONFIGURE_RUNTIME_DIR}/${CONFIGURE_ABI_NAME}"
                    "${CONFIGURE_LINKER_DIR}/${CONFIGURE_LINKER_NAME}"
                COMMAND ${CMAKE_COMMAND} -E make_directory "${CONFIGURE_LINKER_DIR}"
                COMMAND ${CMAKE_COMMAND} -E create_symlink
                    "$<TARGET_FILE_NAME:${TARGET_NAME}>"
                    "${CONFIGURE_RUNTIME_DIR}/${CONFIGURE_ABI_NAME}"
                COMMAND ${CMAKE_COMMAND} -E create_symlink
                    "${CONFIGURE_LINK_TARGET}"
                    "${CONFIGURE_LINKER_DIR}/${CONFIGURE_LINKER_NAME}"
                VERBATIM
            )
        endif()

        if(TARGET_PLATFORM_DARWIN AND CONFIGURE_TARGET_TYPE STREQUAL "EXECUTABLE")
            get_target_property(CONFIGURE_IS_BUNDLE ${TARGET_NAME} MACOSX_BUNDLE)
            if(CONFIGURE_IS_BUNDLE)
                set_property(TARGET ${TARGET_NAME} APPEND PROPERTY INSTALL_RPATH "@executable_path/../../..")
            endif()
        endif()

        # Add sources and dependencies if specified
        if(ARG_SOURCES)
            target_sources(${TARGET_NAME} PRIVATE ${ARG_SOURCES})
        endif()

        # Link dependencies if specified
        if(ARG_DEPENDS)
            target_link_libraries(${TARGET_NAME} PRIVATE ${ARG_DEPENDS})
        endif()
    endforeach()

    # Report configuration details
    set(CONFIGURE_TARGET_MESSAGE "Configured target(s) ${ARG_TARGETS}")
    if(NOT "${ARG_NAME}" STREQUAL "")
        set(CONFIGURE_TARGET_MESSAGE "${CONFIGURE_TARGET_MESSAGE} with output name '${ARG_NAME}'")
    endif()
    if(NOT "${ARG_FOLDER}" STREQUAL "")
        set(CONFIGURE_TARGET_MESSAGE "${CONFIGURE_TARGET_MESSAGE}, folder '${ARG_FOLDER}'")
    endif()
    if(NOT "${ARG_SUBDIR_LOWER}" STREQUAL "")
        set(CONFIGURE_TARGET_MESSAGE "${CONFIGURE_TARGET_MESSAGE}, output subdir '${ARG_SUBDIR_LOWER}'")
    endif()
    if(ARG_SOURCES)
        set(CONFIGURE_TARGET_MESSAGE "${CONFIGURE_TARGET_MESSAGE}, sources: ${ARG_SOURCES}")
    endif()
    if(ARG_DEPENDS)
        set(CONFIGURE_TARGET_MESSAGE "${CONFIGURE_TARGET_MESSAGE}, dependencies: ${ARG_DEPENDS}")
    endif()
    message(STATUS "${CONFIGURE_TARGET_MESSAGE}")
endfunction()

function(define config_file_name config_header_name)
    # Add compile definitions
    add_compile_definitions(
        METADATA_NAME=\"${METADATA_NAME}\"
        METADATA_VERSION_MAJOR=${METADATA_VERSION_MAJOR}
        METADATA_VERSION_MINOR=${METADATA_VERSION_MINOR}
        METADATA_VERSION_PATCH=${METADATA_VERSION_PATCH}
        METADATA_VERSION=\"${METADATA_VERSION}\"
        METADATA_DESCRIPTION=\"${METADATA_DESCRIPTION}\"
        TARGET_VENDOR=\"${TARGET_VENDOR}\"
        TARGET_SYSTEM=\"${TARGET_SYSTEM}\"
        TARGET_ARCHITECTURE=\"${TARGET_ARCHITECTURE}\"
        TARGET_PLATFORM_WIN32=${TARGET_PLATFORM_WIN32}
        TARGET_PLATFORM_DARWIN=${TARGET_PLATFORM_DARWIN}
        TARGET_PLATFORM_LINUX=${TARGET_PLATFORM_LINUX}
        TARGET_STDC_VERSION=${TARGET_STDC_VERSION}
        TARGET_SIZEOF_VOID_P=${TARGET_SIZEOF_VOID_P}
        TARGET_SUPPORTS_UNICODE=${TARGET_SUPPORTS_UNICODE}
        "$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,SHARED_LIBRARY>:TARGET_SHARED=1>"
    )
    message(STATUS "Added compile definition METADATA_NAME=\"${METADATA_NAME}\"")
    message(STATUS "Added compile definition METADATA_VERSION_MAJOR=${METADATA_VERSION_MAJOR}")
    message(STATUS "Added compile definition METADATA_VERSION_MINOR=${METADATA_VERSION_MINOR}")
    message(STATUS "Added compile definition METADATA_VERSION_PATCH=${METADATA_VERSION_PATCH}")
    message(STATUS "Added compile definition METADATA_VERSION=\"${METADATA_VERSION}\"")
    message(STATUS "Added compile definition METADATA_DESCRIPTION=\"${METADATA_DESCRIPTION}\"")
    message(STATUS "Added compile definition TARGET_VENDOR=\"${TARGET_VENDOR}\"")
    message(STATUS "Added compile definition TARGET_SYSTEM=\"${TARGET_SYSTEM}\"")
    message(STATUS "Added compile definition TARGET_ARCHITECTURE=\"${TARGET_ARCHITECTURE}\"")
    message(STATUS "Added compile definition TARGET_PLATFORM_WIN32=${TARGET_PLATFORM_WIN32}")
    message(STATUS "Added compile definition TARGET_PLATFORM_DARWIN=${TARGET_PLATFORM_DARWIN}")
    message(STATUS "Added compile definition TARGET_PLATFORM_LINUX=${TARGET_PLATFORM_LINUX}")
    message(STATUS "Added compile definition TARGET_STDC_VERSION=${TARGET_STDC_VERSION}")
    message(STATUS "Added compile definition TARGET_SIZEOF_VOID_P=${TARGET_SIZEOF_VOID_P}")
    message(STATUS "Added compile definition TARGET_SUPPORTS_UNICODE=${TARGET_SUPPORTS_UNICODE}")
    message(STATUS "Added compile definition TARGET_SHARED=1 for shared library targets")

    # Process the configuration file/header
    if(EXISTS "${CMAKE_SOURCE_DIR}/${config_file_name}")
        set(GENERATED_REAL_DIR "${CMAKE_BINARY_DIR}/generated")
        set(GENERATED_REAL_FILE "${GENERATED_REAL_DIR}/${config_header_name}")
        get_filename_component(BINARY_PARENT_DIR "${CMAKE_BINARY_DIR}" DIRECTORY)
        set(GENERATED_LINK_DIR "${BINARY_PARENT_DIR}/generated")
        set(GENERATED_LINK_FILE "${GENERATED_LINK_DIR}/${config_header_name}")
        file(MAKE_DIRECTORY "${GENERATED_REAL_DIR}")
        file(MAKE_DIRECTORY "${GENERATED_LINK_DIR}")
        configure_file(
            "${CMAKE_SOURCE_DIR}/${config_file_name}"
            "${GENERATED_REAL_FILE}"
            @ONLY
        )
        file(REMOVE "${GENERATED_LINK_FILE}")
        file(CREATE_LINK
            "${GENERATED_REAL_FILE}"
            "${GENERATED_LINK_FILE}"
            SYMBOLIC
            COPY_ON_ERROR
        )
        include_directories("${GENERATED_LINK_DIR}")
        message(STATUS "Processed configuration file '${config_file_name}' to generate '${GENERATED_REAL_FILE}'")
        message(STATUS "Linked generated header to '${GENERATED_LINK_FILE}'")
    else()
        message(WARNING "Configuration file '${config_file_name}' not found, skipping generation of '${config_header_name}'")
    endif()
endfunction()

function(define_wayland_protocol protocol_xml protocol_header_name protocol_source_name)
    find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
    if(NOT EXISTS "${protocol_xml}")
        message(FATAL_ERROR "Wayland protocol XML not found: '${protocol_xml}'")
    endif()
    set(GENERATED_REAL_DIR "${CMAKE_BINARY_DIR}/generated")
    set(GENERATED_REAL_HEADER "${GENERATED_REAL_DIR}/${protocol_header_name}")
    set(GENERATED_REAL_SOURCE "${GENERATED_REAL_DIR}/${protocol_source_name}")
    get_filename_component(BINARY_PARENT_DIR "${CMAKE_BINARY_DIR}" DIRECTORY)
    set(GENERATED_LINK_DIR "${BINARY_PARENT_DIR}/generated")
    set(GENERATED_LINK_HEADER "${GENERATED_LINK_DIR}/${protocol_header_name}")
    set(GENERATED_LINK_SOURCE "${GENERATED_LINK_DIR}/${protocol_source_name}")
    file(MAKE_DIRECTORY "${GENERATED_REAL_DIR}")
    file(MAKE_DIRECTORY "${GENERATED_LINK_DIR}")
    execute_process(
        COMMAND "${WAYLAND_SCANNER}" client-header "${protocol_xml}" "${GENERATED_REAL_HEADER}"
        RESULT_VARIABLE WAYLAND_HEADER_RESULT
    )
    if(NOT WAYLAND_HEADER_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to generate Wayland header '${GENERATED_REAL_HEADER}' from '${protocol_xml}'")
    endif()
    execute_process(
        COMMAND "${WAYLAND_SCANNER}" private-code "${protocol_xml}" "${GENERATED_REAL_SOURCE}"
        RESULT_VARIABLE WAYLAND_SOURCE_RESULT
    )
    if(NOT WAYLAND_SOURCE_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to generate Wayland source '${GENERATED_REAL_SOURCE}' from '${protocol_xml}'")
    endif()
    file(REMOVE "${GENERATED_LINK_HEADER}")
    file(CREATE_LINK
        "${GENERATED_REAL_HEADER}"
        "${GENERATED_LINK_HEADER}"
        SYMBOLIC
        COPY_ON_ERROR
    )
    file(REMOVE "${GENERATED_LINK_SOURCE}")
    file(CREATE_LINK
        "${GENERATED_REAL_SOURCE}"
        "${GENERATED_LINK_SOURCE}"
        SYMBOLIC
        COPY_ON_ERROR
    )
    include_directories("${GENERATED_LINK_DIR}")
    set(WAYLAND_PROTOCOL_HEADER "${GENERATED_LINK_HEADER}" PARENT_SCOPE)
    set(WAYLAND_PROTOCOL_SOURCE "${GENERATED_LINK_SOURCE}" PARENT_SCOPE)
    message(STATUS "Generated Wayland header '${GENERATED_REAL_HEADER}'")
    message(STATUS "Generated Wayland source '${GENERATED_REAL_SOURCE}'")
    message(STATUS "Linked Wayland header to '${GENERATED_LINK_HEADER}'")
    message(STATUS "Linked Wayland source to '${GENERATED_LINK_SOURCE}'")
endfunction()

function(define_test_executables)
    set(OPTIONS)
    set(ONE_VALUE_ARGS)
    set(MULTI_VALUE_ARGS STATIC_DEPENDS SHARED_DEPENDS)

    cmake_parse_arguments(TESTS
        "${OPTIONS}"
        "${ONE_VALUE_ARGS}"
        "${MULTI_VALUE_ARGS}"
        ${ARGN}
    )

    if(EXISTS "${CMAKE_SOURCE_DIR}/test")
        file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS
            "${CMAKE_SOURCE_DIR}/test/*.cpp"
        )

        if(TEST_SOURCES)
            message(STATUS "Test source files found, configuring test executables...")

            foreach(TEST_SOURCE ${TEST_SOURCES})
                get_filename_component(TEST_NAME "${TEST_SOURCE}" NAME_WE)

                add_executable(${TEST_NAME}
                    "${TEST_SOURCE}"
                )

                if(TEST_NAME STREQUAL "exe")
                    if(TARGET_PLATFORM_WIN32)
                        set_target_properties(${TEST_NAME} PROPERTIES
                            WIN32_EXECUTABLE TRUE
                        )

                        message(STATUS "Configured ${TEST_NAME} as a Windows GUI application")
                    elseif(TARGET_PLATFORM_DARWIN)
                        set_target_properties(${TEST_NAME} PROPERTIES
                            MACOSX_BUNDLE TRUE
                            MACOSX_BUNDLE_BUNDLE_NAME "${TEST_NAME}"
                            MACOSX_BUNDLE_GUI_IDENTIFIER "org.catalystui.${TEST_NAME}"
                        )

                        message(STATUS "Configured ${TEST_NAME} as a macOS GUI application")
                    elseif(TARGET_PLATFORM_LINUX AND TESTS_SHARED_DEPENDS)
                        add_executable(${TEST_NAME}_shared
                            "${TEST_SOURCE}"
                        )

                        configure_target(
                            NAME ${TEST_NAME}_shared
                            FOLDER "test"
                            TARGETS ${TEST_NAME}_shared
                            DEPENDS
                                ${TESTS_SHARED_DEPENDS}
                        )

                        message(STATUS "Configured ${TEST_NAME}_shared as a Linux GUI application")
                    endif()
                endif()

                if(MSVC)
                    target_link_options(${TEST_NAME} PRIVATE
                        /ENTRY:mainCRTStartup
                    )
                endif()

                configure_target(
                    NAME ${TEST_NAME}
                    FOLDER "test"
                    TARGETS ${TEST_NAME}
                    DEPENDS
                        ${TESTS_STATIC_DEPENDS}
                )
            endforeach()
        else()
            message(STATUS "No .cpp test source files found, skipping test executable configuration")
            message(STATUS "    To configure test executables, add one or more .cpp files")
            message(STATUS "    to the 'test' directory, then reload the CMake configuration.")
        endif()
    else()
        message(STATUS "No test directory found, skipping test executable configuration")
        message(STATUS "    To configure test executables, create a 'test' directory")
        message(STATUS "    in the project root and add one or more .cpp files,")
        message(STATUS "    then reload the CMake configuration.")
    endif()
endfunction()
