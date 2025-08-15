# Safe CMake configuration for scantailor-experimental
# This configuration disables potentially problematic features that can cause segfaults

# Disable OpenCL acceleration (common cause of segfaults on servers)
set(ENABLE_OPENCL OFF CACHE BOOL "Disable OpenCL acceleration" FORCE)

# Disable OpenGL (may not be available on headless servers)
set(ENABLE_OPENGL OFF CACHE BOOL "Disable OpenGL" FORCE)

# Disable crash reporter (not needed for CLI usage)
set(BUILD_CRASH_REPORTER OFF CACHE BOOL "Disable crash reporter" FORCE)

# Use Release build for better performance and stability
set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)

# Add some safety flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-strict-aliasing" CACHE STRING "Additional CXX flags" FORCE)

# Ensure we're building the CLI version
set(BUILD_CLI ON CACHE BOOL "Build CLI version" FORCE)

message(STATUS "Safe configuration loaded:")
message(STATUS "  OpenCL: ${ENABLE_OPENCL}")
message(STATUS "  OpenGL: ${ENABLE_OPENGL}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  CLI build: ${BUILD_CLI}")