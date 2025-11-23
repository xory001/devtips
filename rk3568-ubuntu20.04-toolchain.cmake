###2025.10.19，add by xory
#x64 ubunt20.04 交叉编译 qt 6.8.3 源码 for 鲁班猫2（RK3568）Ubuntu 20.04 成功
#鲁班猫2（RK3568）Ubuntu 20.04 需要预先编译 ffmpeg-6.1.3 到 /opt/ffmpeg-6.1.3, 然后打包到 sysroot 里面
#没有编译 QtWebEngine, QtPdf 模块 和 GStreamer 后端插件


cmake_minimum_required(VERSION 3.18)
include_guard(GLOBAL)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_LIBRARY_ARCHITECTURE aarch64-linux-gnu)
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)

set(TARGET_SYSROOT $ENV{HOME}/xoryDoc/sysroot-rk3568-ubuntu20.04)
set(CROSS_COMPILER /usr/bin)
set(CMAKE_SYSROOT ${TARGET_SYSROOT})

set(ENV{PKG_CONFIG_PATH} "")

set(ENV{PKG_CONFIG_LIBDIR} “${CMAKE_SYSROOT}/usr/lib/pkgconfig
	:${CMAKE_SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}/pkgconfig
	:${CMAKE_SYSROOT}/usr/share/pkgconfig
	:${CMAKE_SYSROOT}/opt/ffmpeg-6.1.3/lib/pkgconfig”)
	
set(ENV{PKG_CONFIG_SYSROOT_DIR} ${CMAKE_SYSROOT})

set(CMAKE_C_COMPILER ${CROSS_COMPILER}/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${CROSS_COMPILER}/aarch64-linux-gnu-g++)

set(QT_COMPILER_FLAGS "-march=armv8-a")
set(QT_COMPILER_FLAGS_RELEASE "-O2 -pipe")
set(QT_LINKER_FLAGS "-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

include(CMakeInitializeConfigs)

function(cmake_initialize_per_config_variable _PREFIX _DOCSTRING)
  if (_PREFIX MATCHES "CMAKE_(C|CXX|ASM)_FLAGS")
    set(CMAKE_${CMAKE_MATCH_1}_FLAGS_INIT "${QT_COMPILER_FLAGS}")

    foreach (config DEBUG RELEASE MINSIZEREL RELWITHDEBINFO)
      if (DEFINED QT_COMPILER_FLAGS_${config})
        set(CMAKE_${CMAKE_MATCH_1}_FLAGS_${config}_INIT "${QT_COMPILER_FLAGS_${config}}")
      endif()
    endforeach()
  endif()

  if (_PREFIX MATCHES "CMAKE_(SHARED|MODULE|EXE)_LINKER_FLAGS")
    foreach (config SHARED MODULE EXE)
      set(CMAKE_${config}_LINKER_FLAGS_INIT "${QT_LINKER_FLAGS}")
    endforeach()
  endif()

  _cmake_initialize_per_config_variable(${ARGV})
endfunction()

###以下部分为修正会链接到 dbus-1.a 而不是 dbus-1.so 导致错误的问题
set(DBUS_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/include/dbus-1.0")
set(DBUS_LIBRARY "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libdbus-1.so")

# 手动创建 dbus-1 导入目标作为 GLOBAL（避免提升错误）
if(NOT TARGET dbus-1)
  add_library(dbus-1 UNKNOWN IMPORTED)
  set_target_properties(dbus-1 PROPERTIES
    IMPORTED_LOCATION "${DBUS_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${DBUS_INCLUDE_DIR}"
    IMPORTED_GLOBAL TRUE
  )
endif()

  
#### 
# 设置 Clang 和 LLVM 的 CMake 模块路径，注意至少要 18 的版本，低版本有组件编译不出来。
set(Clang_DIR "${CMAKE_SYSROOT}/usr/lib/llvm-18/lib/cmake/clang")
set(LLVM_DIR "${CMAKE_SYSROOT}/usr/lib/llvm-18/lib/cmake/llvm")

# Qt 工具构建选项（强制生成所有工具，并包含在默认 "all" 目标中）
# QT_FORCE_BUILD_TOOLS 强制生成 qtbase 和 qttools 里面的工具程序，比如qdoc什么的，交叉编译默认不生成。
set(QT_FORCE_BUILD_TOOLS ON)
#QT_BUILD_TOOLS_BY_DEFAULT，即使强制生成工具程序，也有一些默认在交叉编译时不生成，这个是强制生成所有的工具程序
set(QT_BUILD_TOOLS_BY_DEFAULT ON)