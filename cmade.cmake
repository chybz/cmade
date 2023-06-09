set(CMADE "cmade.cmake")
set(CMDEPS "CMakeDeps.txt")
set(CMADE_VERSION "0.1.0")
set(CMADE_CACHE ".cmade/cache")

##############################################################################
#
# Utility functions
#
##############################################################################
function(show_help)
    message(
        "CMake Dependency Installer v${CMADE_VERSION}\n"
        "\n"
        "usage: ${CMADE} COMMAND\n"
        "\n"
        "Commands\n"
        "  install     Install dependencies from ${CMDEPS}\n"
        "  help        Display this information\n"
    )
endfunction()

function(die MSG)
    message(FATAL_ERROR "CMade: error: ${MSG}")
endfunction()

function(msg MSG)
    message("CMade: ${MSG}")
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

    file(DOWNLOAD ${URL} "${CMADE_CACHE}/${NAME}-${REF}.zip")
endfunction()

##############################################################################
#
# Argument functions
#
##############################################################################
function(parse_arguments)
    list(LENGTH CMADE_ARGS CMADE_ARGC)

    if (CMADE_ARGC GREATER 0)
        list(POP_FRONT CMADE_ARGS CMADE_CMD)
        set(CMADE_CMD "${CMADE_CMD}" PARENT_SCOPE)
    endif()

    set(CMADE_ARGS ${CMADE_ARGS} PARENT_SCOPE)
endfunction()

function(process_cmd)
    if (CMADE_CMD STREQUAL "install")
        install_deps()
    elseif (CMADE_CMD STREQUAL "help")
        show_help()
    elseif(CMADE_CMD)
        msg("unknown command: ${CMADE_CMD}")
    elseif(NOT CMADE_CMD)
        msg("no command")
    endif()
endfunction()

##############################################################################
#
# Dependency installation functions
#
##############################################################################
function(install_dep DEP)
    list(LENGTH DEP DEP_PARTS)

    if(DEP_PARTS LESS 3)
        msg("ignoring invalid dependency: ${DEP} (${DEP_PARTS} < 3)")
        return()
    endif()

    list(GET DEP 0 1 2 REPO_PARTS)
    make_url(${REPO_PARTS})
endfunction()

function(install_deps)
    if(NOT EXISTS ${CMDEPS})
        msg("no dependencies")
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

##############################################################################
#
# Main part
#
##############################################################################
# Crude script arguments parsing in CMADE_ARGS list
foreach(_arg RANGE ${CMAKE_ARGC})
    string(TOLOWER "${CMAKE_ARGV${_arg}}" ARG)

    if (ARG MATCHES "${CMADE}$")
        math(EXPR _arg "${_arg}+1")

        while(_arg LESS ${CMAKE_ARGC})
            list(APPEND CMADE_ARGS "${CMAKE_ARGV${_arg}}")
            math(EXPR _arg "${_arg}+1")
        endwhile()
    endif()
endforeach()

parse_arguments()
process_cmd()
