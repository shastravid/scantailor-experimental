# ARM64 Ubuntu 22.04 Server Optimized Configuration
# Specifically designed for Oracle Cloud VPS without GPU

# Target ARM64 architecture
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Disable GPU-dependent features
set(ENABLE_OPENCL OFF CACHE BOOL "Disable OpenCL on headless server" FORCE)
set(ENABLE_OPENGL OFF CACHE BOOL "Disable OpenGL on headless server" FORCE)
set(BUILD_CRASH_REPORTER OFF CACHE BOOL "Disable crash reporter for server" FORCE)

# Optimize for ARM64 Cortex-A72 (Oracle Cloud ARM instances)
set(CMAKE_C_FLAGS_RELEASE "-march=armv8-a -mtune=cortex-a72 -O3 -DNDEBUG -ffast-math -funroll-loops -fomit-frame-pointer" CACHE STRING "ARM64 optimized C flags" FORCE)
set(CMAKE_CXX_FLAGS_RELEASE "-march=armv8-a -mtune=cortex-a72 -O3 -DNDEBUG -ffast-math -funroll-loops -fomit-frame-pointer -std=c++17" CACHE STRING "ARM64 optimized CXX flags" FORCE)

# Link-time optimizations for better performance
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -flto" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -flto" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "-flto -Wl,--gc-sections -Wl,--strip-all" CACHE STRING "Optimized linker flags" FORCE)

# Memory optimizations for VPS environment
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DEIGEN_DONT_PARALLELIZE" CACHE STRING "Disable Eigen parallelization" FORCE)

# Server-specific optimizations
set(QT_NO_DEBUG_OUTPUT ON CACHE BOOL "Disable Qt debug output" FORCE)
set(QT_NO_WARNING_OUTPUT ON CACHE BOOL "Disable Qt warning output" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "Disable testing for server build" FORCE)

# Use Release build type
set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)

# Prefer static linking where possible to reduce dependencies
set(CMAKE_FIND_LIBRARY_SUFFIXES ".a;.so" CACHE STRING "Prefer static libraries" FORCE)

# Optimize for size and speed
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON CACHE BOOL "Enable IPO/LTO" FORCE)

# ARM64 NEON optimizations
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpu=neon" CACHE STRING "Enable NEON" FORCE)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon" CACHE STRING "Enable NEON" FORCE)

# Disable unnecessary features for CLI
set(BUILD_GUI OFF CACHE BOOL "CLI only build" FORCE)
set(CMAKE_SKIP_RPATH ON CACHE BOOL "Skip RPATH for server deployment" FORCE)

message(STATUS "ARM64 Ubuntu 22.04 Server configuration loaded:")
message(STATUS "  Target: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "  OpenCL: ${ENABLE_OPENCL}")
message(STATUS "  OpenGL: ${ENABLE_OPENGL}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C flags: ${CMAKE_C_FLAGS_RELEASE}")
message(STATUS "  CXX flags: ${CMAKE_CXX_FLAGS_RELEASE}")
message(STATUS "  Linker flags: ${CMAKE_EXE_LINKER_FLAGS_RELEASE}")