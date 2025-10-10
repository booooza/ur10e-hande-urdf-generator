#!/bin/bash
set -e

echo "Building UR10e URDF with Hand-E gripper for Isaac Lab..."

# Source ROS 2
source /opt/ros/humble/setup.bash

# Build the workspace
cd /workspace
colcon build --packages-select ur_description robotiq_hande_description

# Source the built workspace
source install/setup.bash

# Generate URDF from xacro
OUTPUT_DIR="/workspace/out"
mkdir -p ${OUTPUT_DIR}

# Check if calibrated config exists
# Default config paths
DEFAULT_BASE="/workspace/src/Universal_Robots_ROS2_Description/config/ur10e"
KINEMATICS_CONFIG="${DEFAULT_BASE}/default_kinematics.yaml"
PHYSICAL_CONFIG="${DEFAULT_BASE}/physical_parameters.yaml"
JOINT_LIMITS_CONFIG="${DEFAULT_BASE}/joint_limits.yaml"
VISUAL_CONFIG="${DEFAULT_BASE}/visual_parameters.yaml"

# Set custom config paths
CUSTOM_BASE="/workspace/config/ur10e_calibrated"

# Check kinematics config
if [ -f "${CUSTOM_BASE}/default_kinematics.yaml" ]; then
    KINEMATICS_CONFIG="${CUSTOM_BASE}/default_kinematics.yaml"
    echo "Using custom kinematics configuration"
fi

# Check physical parameters config
if [ -f "${CUSTOM_BASE}/physical_parameters.yaml" ]; then
    PHYSICAL_CONFIG="${CUSTOM_BASE}/physical_parameters.yaml"
    echo "Using custom physical parameters configuration"
fi

# Check joint limits config
if [ -f "${CUSTOM_BASE}/joint_limits.yaml" ]; then
    JOINT_LIMITS_CONFIG="${CUSTOM_BASE}/joint_limits.yaml"
    echo "Using custom joint limits configuration"
fi

# Check visual parameters config
if [ -f "${CUSTOM_BASE}/visual_parameters.yaml" ]; then
    VISUAL_CONFIG="${CUSTOM_BASE}/visual_parameters.yaml"
    echo "Using custom visual parameters configuration"
fi

echo ""
echo "Configuration files:"
echo "  - Kinematics: ${KINEMATICS_CONFIG}"
echo "  - Physical:   ${PHYSICAL_CONFIG}"
echo "  - Limits:     ${JOINT_LIMITS_CONFIG}"
echo "  - Visual:     ${VISUAL_CONFIG}"
echo ""

echo "==================================="
echo "Generating base UR10e URDF..."
echo "==================================="
ros2 run xacro xacro \
    src/Universal_Robots_ROS2_Description/urdf/ur.urdf.xacro \
    ur_type:=ur10e \
    name:=ur10e \
    kinematics_params:=${KINEMATICS_CONFIG} \
    physical_params:=${PHYSICAL_CONFIG} \
    joint_limit_params:=${JOINT_LIMITS_CONFIG} \
    visual_params:=${VISUAL_CONFIG} \
    > ${OUTPUT_DIR}/ur10e_base.urdf

# Validate base URDF
echo "Validating base URDF..."
check_urdf ${OUTPUT_DIR}/ur10e_base.urdf

echo "==================================="
echo "Generating Hand-E gripper URDF..."
echo "==================================="
ros2 run xacro xacro \
    src/robotiq_hande_description/urdf/robotiq_hande_gripper.urdf.xacro \
    > ${OUTPUT_DIR}/hand_e_gripper.urdf

# Validate gripper URDF
echo "Validating gripper URDF..."
check_urdf ${OUTPUT_DIR}/hand_e_gripper.urdf

echo "==================================="
echo "Combining UR10e + Hand-E gripper..."
echo "==================================="
python3 /workspace/create_combined_urdf.py \
    ${OUTPUT_DIR}/ur10e_base.urdf \
    ${OUTPUT_DIR}/hand_e_gripper.urdf \
    ${OUTPUT_DIR}/ur10e_with_hande.urdf

# Validate combined URDF
echo "Validating combined URDF..."
check_urdf ${OUTPUT_DIR}/ur10e_with_hande.urdf

# Copy meshes to output directory
echo "==================================="
echo "Copying mesh files..."
echo "==================================="
mkdir -p ${OUTPUT_DIR}/meshes
mkdir -p ${OUTPUT_DIR}/meshes/hande
cp -r src/Universal_Robots_ROS2_Description/meshes/ur10e ${OUTPUT_DIR}/meshes/
cp -r src/robotiq_hande_description/meshes/* ${OUTPUT_DIR}/meshes/hande/

# Update mesh paths in URDFs to be relative
# echo "Updating mesh paths to relative paths..."
sed -i 's|package://ur_description/meshes/|meshes/|g' ${OUTPUT_DIR}/ur10e_base.urdf
sed -i 's|package://robotiq_hande_description/meshes/|meshes/hande/|g' ${OUTPUT_DIR}/hand_e_gripper.urdf
sed -i 's|package://ur_description/meshes/|meshes/|g' ${OUTPUT_DIR}/ur10e_with_hande.urdf
sed -i 's|package://robotiq_hande_description/meshes/|meshes/hande/|g' ${OUTPUT_DIR}/ur10e_with_hande.urdf

echo "==================================="
echo "Build complete! Files available in ${OUTPUT_DIR}"
echo "==================================="
ls -lh ${OUTPUT_DIR}
echo ""
echo "Generated files:"
echo "  - ur10e_base.urdf          : UR10e robot only"
echo "  - hand_e_gripper.urdf      : Hand-E gripper only"
echo "  - ur10e_with_hande.urdf    : Combined UR10e + Hand-E"
echo "  - meshes/                  : All mesh files"