set(CMADE "cmade.cmake")
set(CMDEPS "CMakeDeps.txt")
set(CMADE_VERSION "0.1.0")
set(CMADE_CACHE ".cmade/cache")
list(
    APPEND
    CMADE_OPTIONS
    "help"
    "verbose"
    "simulate"
    "no-cache"
)

##############################################################################
#
# Utility functions
#
##############################################################################
function(show_help)
    message("\
CMake Dependency Installer v${CMADE_VERSION}

usage: ${CMADE} [OPTIONS] COMMAND

Options:
  --verbose     Verbose operation
  --simulate    Echo commands instead of running them
  --no-cache    Ignore/erase existing repositories

Commands:
  install       Install dependencies from ${CMDEPS}
  help          Display this information
")
endfunction()

function(die MSG)
    message(FATAL_ERROR "CMade: error: ${MSG}")
endfunction()

function(msg MSG)
    message("CMade: ${MSG}")
endfunction()

function(info MSG)
    if(CMADE_VERBOSE)
        msg(${MSG})
    endif()
endfunction()

function(setg VAR VAL)
    set(${VAR} "${VAL}" CACHE INTERNAL "${VAR}")
endfunction()

function(run_prog)
    if(CMADE_SIMULATE)
        set(CMD "echo")
    endif()

    list(APPEND CMD ${ARGV})

    execute_process(
        COMMAND ${CMD}
        RESULTS_VARIABLE RC
    )

    if(RC)
        list(JOIN ARGV " " CMD)
        die("command failed: ${CMD}")
    endif()
endfunction()

function(download URL FILE)
    if(CMADE_SIMULATE)
        msg("download ${URL} to ${FILE}")
    else()
        file(DOWNLOAD ${URL} ${FILE} STATUS ST)
    endif()

    list(GET ST 0 RC)

    if(RC)
        die("download of ${URL} failed: ${ST}")
    endif()
endfunction()

function(fetch_repo HOST REPO REF)
    if(HOST MATCHES "^\\$\\{(.+)\\}$")
        # Dereference variable
        set(HOST ${${CMAKE_MATCH_1}})
    endif()

    if(HOST STREQUAL "GH")
        set(HOST "https://github.com")
    elseif(TYPE STREQUAL "GL")
        set(HOST "https://gitlab.com")
    endif()

    set(URL "${HOST}/${REPO}.git")

    string(REPLACE "/" "_" REPO_DIR ${REPO})

    get_filename_component(CMADE_SRC "${CMADE_CACHE}/${REPO_DIR}" REALPATH)
    setg(CMADE_SRC "${CMADE_SRC}")

    set(GIT_ARGS "clone")
    list(
        APPEND GIT_ARGS
        "-c" "advice.detachedHead=false"
        "--depth" "1"
    )

    if(REF)
        list(APPEND GIT_ARGS "--branch" "${REF}")
    endif()

    if(IS_DIRECTORY "${CMADE_SRC}")
        if(NOT CMADE_NO_CACHE)
            msg("${REPO} already here")
            return()
        else()
            info("cleaning ${REPO}")
            file(REMOVE_RECURSE "${CMADE_SRC}")
        endif()
    endif()

    info("cloning ${URL} in ${CMADE_SRC}")
    run_prog(git ${GIT_ARGS} ${URL} ${CMADE_SRC})
endfunction()

function(fetch_url URL)
    string(MD5 HASH ${URL})

    if(URL MATCHES "/([^/]+)$")
        set(FILE ${CMAKE_MATCH_1})
    else()
        die("can't find filename from URL: ${URL}")
    endif()

    get_filename_component(DIR "${CMADE_CACHE}/${HASH}" REALPATH)
    setg(CMADE_SRC "${DIR}/sources")

    if(CMADE_NO_CACHE)
        file(REMOVE_RECURSE "${DIR}")
    endif()

    if(NOT EXISTS "${DIR}/${FILE}")
        info("downloading ${URL} in ${DIR}")
        download(${URL} "${DIR}/${FILE}")
    endif()

    if(NOT IS_DIRECTORY "${DIR}/sources")
        info("extracting ${FILE}")
        file(
            ARCHIVE_EXTRACT
            INPUT "${DIR}/${FILE}"
            DESTINATION "${DIR}/sources"
        )
    endif()
endfunction()

##############################################################################
#
# Dependency installation functions
#
##############################################################################
function(install_repo HOST REPO TAG ARGS)
    fetch_repo(${HOST} ${REPO} "${TAG}")
    msg("sources are in: ${CMADE_SRC}")
endfunction()

function(install_url URL ARGS)
    fetch_url(${URL})
    msg("sources are in: ${CMADE_SRC}")
endfunction()

function(install_deps)
    if(NOT EXISTS ${CMDEPS})
        msg("no dependencies")
        return()
    endif()

    file(STRINGS ${CMDEPS} DEPS)

    foreach(SPEC ${DEPS})
        if(SPEC MATCHES "^#")
            # Skip comments
            continue()
        elseif(SPEC MATCHES "^([A-Za-z0-9_-]+)=(.+)$")
            # Variable assignment
            setg(${CMAKE_MATCH_1} "${CMAKE_MATCH_2}")
        elseif(SPEC MATCHES "^git\\+([^:]+):([^ @]+)(@([^ ]+))?( (.*))?$")
            set(HOST ${CMAKE_MATCH_1})
            set(REPO ${CMAKE_MATCH_2})
            set(TAG ${CMAKE_MATCH_4})
            set(ARGS "${CMAKE_MATCH_6}")
            install_repo(${HOST} ${REPO} "${TAG}" "${ARGS}")
        elseif(SPEC MATCHES "^(.+)([ ](.+))?$")
            set(URL ${CMAKE_MATCH_1})
            set(ARGS "${CMAKE_MATCH_2}")
            install_url(${URL} "${ARGS}")
        else()
            die("invalid dependency line: ${SPEC}")
        endif()
    endforeach()
endfunction()

##############################################################################
#
# Argument functions
#
##############################################################################
function(parse_arguments)
    foreach(_arg RANGE ${CMAKE_ARGC})
        string(TOLOWER "${CMAKE_ARGV${_arg}}" ARG)

        if (ARG MATCHES "${CMADE}$")
            math(EXPR _arg "${_arg}+1")

            while(_arg LESS ${CMAKE_ARGC})
                if ("${CMAKE_ARGV${_arg}}" MATCHES "--?([A-Za-z0-9_-]+)")
                    list(FIND CMADE_OPTIONS ${CMAKE_MATCH_1} OPT)

                    if (OPT LESS 0)
                        die("unknown option: ${CMAKE_MATCH_1}")
                    else()
                        string(TOUPPER "CMADE_${CMAKE_MATCH_1}" OPT)
                        string(REPLACE "-" "_" OPT "${OPT}")
                        setg(${OPT} 1)
                    endif()
                else()
                    list(APPEND CMADE_ARGS "${CMAKE_ARGV${_arg}}")
                endif()

                math(EXPR _arg "${_arg}+1")
            endwhile()
        endif()
    endforeach()

    list(LENGTH CMADE_ARGS CMADE_ARGC)

    if (CMADE_ARGC GREATER 0)
        list(POP_FRONT CMADE_ARGS CMADE_CMD)
        setg(CMADE_CMD "${CMADE_CMD}")
    endif()

    setg(CMADE_ARGS "${CMADE_ARGS}")
endfunction()

##############################################################################
#
# Command processing
#
##############################################################################
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
# Main part
#
##############################################################################
parse_arguments()
process_cmd()
