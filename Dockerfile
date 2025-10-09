FROM ros:humble-ros-base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    python3-pip \
    python3-colcon-common-extensions \
    ros-humble-xacro \
    ros-humble-urdf \
    liburdfdom-tools \
    && rm -rf /var/lib/apt/lists/*

# Set up workspace
WORKDIR /workspace

# Clone Universal Robots description repository
RUN git clone --depth 1 --branch humble \
    https://github.com/UniversalRobots/Universal_Robots_ROS2_Description.git \
    src/Universal_Robots_ROS2_Description

# Clone Robotiq Hand-E gripper description
RUN git clone --depth 1 \
    https://github.com/macmacal/robotiq_hande_description.git \
    src/robotiq_hande_description

# Install Python dependencies for URDF processing
RUN pip3 install pyyaml

# Copy build script
COPY ./src/ /workspace/
RUN chmod +x /workspace/build_urdf.sh

# Set entrypoint
ENTRYPOINT ["/workspace/build_urdf.sh"]