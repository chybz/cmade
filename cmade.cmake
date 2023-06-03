set(CMDEPS "CMakeDeps.txt")
set(CMADE_VERSION "0.1.0")
set(CMADE_ARCDIR "build/archives")

function(greeting)
    message("CMake Dependency Installer v${CMADE_VERSION}")
endfunction()

function(die MSG)
    message(FATAL_ERROR "CMade error: ${MSG}")
endfunction()

function(make_url TYPE REPO REF)
    set(URL "")
    set(HOST "")
    string(REPLACE "/" ";" REPO_PARTS ${REPO})
    list(GET REPO_PARTS 0 AUTHOR)
    list(GET REPO_PARTS 1 NAME)

    if(TYPE MATCHES "^([A-Za-z]+):\\$\\{(.+)\\}$")
        set(TYPE ${CMAKE_MATCH_1})
        set(HOST ${${CMAKE_MATCH_2}})
    endif()

    if(TYPE STREQUAL "GH")
        if (NOT HOST)
            set(HOST "https://github.com")
        endif()
        # FIXME: handle branches from "heads"
        # set(URL "https://github.com/${REPO}/archive/refs/heads/${NAME}.zip")
        set(URL "${HOST}/${REPO}/archive/refs/tags/${REF}.zip")
    elseif(TYPE STREQUAL "GL")
        if (NOT HOST)
            set(HOST "https://gitlab.com")
        endif()
        set(URL "${HOST}/${REPO}/-/archive/${NAME}-${REF}.zip")
    elseif(TYPE STREQUAL "Git")
        set(URL "${HOST}/${REPO}.git")
    else()
        die("unrecognized dependency type: ${TYPE}")
    endif()

    message("URL is ${URL}")
    #file(DOWNLOAD ${URL} "${CMADE_ARCDIR}/${NAME}-${REF}.zip")
endfunction()

function(install_dep DEP)
    list(LENGTH DEP DEP_PARTS)

    if(DEP_PARTS LESS 3)
        message("ignoring invalid dependency: ${DEP} (${DEP_PARTS} < 3)")
        return()
    endif()

    list(GET DEP 0 1 2 REPO_PARTS)
    make_url(${REPO_PARTS})
endfunction()

function(install_deps)
    if(NOT EXISTS ${CMDEPS})
        message("no dependencies")
        return()
    endif()

    file(STRINGS ${CMDEPS} DEPS)

    foreach(DEP ${DEPS})
        if(DEP MATCHES "^([A-Za-z0-9_-]+)=(.+)$")
            # Variable assignment
            set(${CMAKE_MATCH_1} "${CMAKE_MATCH_2}")
        else()
            install_dep("${DEP}")
        endif()
    endforeach()
endfunction()

greeting()
install_deps()
