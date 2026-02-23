cmake_minimum_required(VERSION 3.8)
project(uav_interfaces)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)

# Uncomment and list .msg / .srv / .action files when ready:
# rosidl_generate_interfaces(${PROJECT_NAME}
#   "msg/UavState.msg"
#   "srv/SetAltitude.srv"
# )

ament_package()
