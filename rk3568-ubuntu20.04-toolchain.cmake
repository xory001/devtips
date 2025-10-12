###2025.10.12��add by xory
#x64 ubunt20.04 ������� qt 6.8.3 Դ�� for ³��è2��RK3568��Ubuntu 20.04 �ɹ�
#³��è2��RK3568��Ubuntu 20.04 ��ҪԤ�ȱ��� ffmpeg-6.1.3 �� /opt/ffmpeg-6.1.3, Ȼ������ sysroot ����



cmake_minimum_required(VERSION 3.18)
include_guard(GLOBAL)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm64)
set(CMAKE_LIBRARY_ARCHITECTURE aarch64-linux-gnu)


set(TARGET_SYSROOT $ENV{HOME}/xoryDoc/sysroot-rk3568-ubuntu20.04)
set(CROSS_COMPILER /usr/bin)
set(CMAKE_SYSROOT ${TARGET_SYSROOT})

set(ENV{PKG_CONFIG_PATH} "")
set(ENV{PKG_CONFIG_LIBDIR} ${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig/:${CMAKE_SYSROOT}/opt/ffmpeg-6.1.3/lib/pkgconfig)
set(ENV{PKG_CONFIG_SYSROOT_DIR} ${CMAKE_SYSROOT})

#set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

#set(CMAKE_C_COMPILER ${CROSS_COMPILER}/arm-poky-linux-gnueabi-gcc)
#set(CMAKE_CXX_COMPILER ${CROSS_COMPILER}/arm-poky-linux-gnueabi-g++)
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)

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

###���²���Ϊ���������ӵ� dbus-1.a ������ dbus-1.so ���´��������
set(DBUS_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/include/dbus-1.0")
set(DBUS_LIBRARY "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libdbus-1.so")

#set(CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY ON)
#set(CMAKE_FIND_PACKAGE_NO_SYSTEM_PACKAGE_REGISTRY ON)
# ǿ�ƶ�̬�⣨����ԭ�����ã�
#set(BUILD_SHARED_LIBS ON)
#set(CMAKE_FIND_LIBRARY_SUFFIXES ".so;.so.3;.so.1")
#set(ENV{PKG_CONFIG_DISABLE_STATIC} "true")
#set(QT_LINKER_FLAGS "${QT_LINKER_FLAGS} -Wl,--no-as-needed -Wl,-Bdynamic")

# �ֶ����� dbus-1 ����Ŀ����Ϊ GLOBAL��������������
if(NOT TARGET dbus-1)
  add_library(dbus-1 UNKNOWN IMPORTED)
  set_target_properties(dbus-1 PROPERTIES
    IMPORTED_LOCATION "${DBUS_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${DBUS_INCLUDE_DIR}"
    IMPORTED_GLOBAL TRUE
  )
endif()

###���²��ֿ��Ժ���
# OpenGL ES2/EGL ·�����ã����Ƕ��ʽ ARM64��
#set(GL_INC_DIR ${CMAKE_SYSROOT}/usr/include)
#set(GL_LIB_DIR ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu)

#set(EGL_INCLUDE_DIR ${GL_INC_DIR})
#set(EGL_LIBRARY ${GL_LIB_DIR}/libEGL.so)

# ���ʹ������ OpenGL���������
#set(OPENGL_INCLUDE_DIR ${GL_INC_DIR})
#set(OPENGL_opengl_LIBRARY ${GL_LIB_DIR}/libOpenGL.so) 

#set(GLESv2_INCLUDE_DIR ${GL_INC_DIR})
#set(GLESv2_LIBRARY ${GL_LIB_DIR}/libGLESv2.so)

#set(GBM_INCLUDE_DIR ${GL_INC_DIR})
#set(GBM_LIBRARY ${GL_LIB_DIR}/libgbm.so)

#set(DRM_INCLUDE_DIR ${GL_INC_DIR})
#set(DRM_LIBRARY ${GL_LIB_DIR}/libdrm.so)

# ��ѡ��XCB ֧�֣������Ҫ X11��
#set(XCB_INCLUDE_DIR ${GL_INC_DIR})
#set(XCB_LIBRARY ${GL_LIB_DIR}/libxcb.so)