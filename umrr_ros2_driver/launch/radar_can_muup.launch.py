#!/usr/bin/env python3
# Copyright (c) 2021, s.m.s, smart microwave sensors GmbH, Brunswick, Germany
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Launch file para radar smartmicro con CAN - MUUP Configuration
"""

import os
from ament_index_python import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

PACKAGE_NAME = 'umrr_ros2_driver'


def generate_launch_description():
    """Generate the launch description."""
    
    # Parámetros del radar (configuración CAN)
    radar_params = os.path.join(
        get_package_share_directory(PACKAGE_NAME), 
        'param/radar.can.muup.yaml'
    )
    
    # Nodo del radar
    radar_node = Node(
        package=PACKAGE_NAME,
        executable='smartmicro_radar_node_exe',
        name='smart_radar',
        parameters=[radar_params],
        output='screen',
        emulate_tty=True,
    )
    
    return LaunchDescription([
        radar_node
    ])
