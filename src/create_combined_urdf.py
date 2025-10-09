# create_combined_urdf.py
"""
Combine UR10e robot URDF with Robotiq Hand-E gripper URDF
"""
import xml.etree.ElementTree as ET
import sys
from pathlib import Path

def combine_urdf(robot_urdf_path, gripper_urdf_path, output_path, 
                 attach_link="tool0", gripper_base_link="robotiq_hande_coupler"):
    """
    Combine robot and gripper URDFs
    
    Args:
        robot_urdf_path: Path to robot URDF file
        gripper_urdf_path: Path to gripper URDF file
        output_path: Path for combined output URDF
        attach_link: Robot link to attach gripper to (default: tool0 for UR robots)
        gripper_base_link: Base link name in gripper URDF to attach (the first actual gripper link)
    """
    print(f"Combining URDFs:")
    print(f"  Robot: {robot_urdf_path}")
    print(f"  Gripper: {gripper_urdf_path}")
    print(f"  Output: {output_path}")
    print(f"  Attaching gripper '{gripper_base_link}' to robot link '{attach_link}'")
    
    # Parse both URDFs
    robot_tree = ET.parse(robot_urdf_path)
    robot_root = robot_tree.getroot()
    
    gripper_tree = ET.parse(gripper_urdf_path)
    gripper_root = gripper_tree.getroot()
    
    # Find or create robot element
    if robot_root.tag == 'robot':
        combined_robot = robot_root
    else:
        combined_robot = robot_root.find('robot')
        if combined_robot is None:
            raise ValueError("No robot element found in robot URDF")
    
    # Get gripper robot element
    if gripper_root.tag == 'robot':
        gripper_robot = gripper_root
    else:
        gripper_robot = gripper_root.find('robot')
        if gripper_robot is None:
            raise ValueError("No robot element found in gripper URDF")
    
    # Find the gripper's root link (tool0) and skip it since robot already has tool0
    gripper_root_link = None
    links_to_skip = set()
    
    print("\nAnalyzing gripper structure...")
    for link in gripper_robot.findall('link'):
        link_name = link.get('name')
        if link_name == 'tool0':
            gripper_root_link = link_name
            links_to_skip.add(link_name)
            print(f"  Found duplicate root link '{link_name}' - will skip and attach directly")
            break
    
    # Find the joint that connects tool0 to the first real gripper link
    gripper_attachment_joint = None
    for joint in gripper_robot.findall('joint'):
        parent = joint.find('parent')
        if parent is not None and parent.get('link') == 'tool0':
            child = joint.find('child')
            if child is not None:
                gripper_base_link = child.get('link')
                gripper_attachment_joint = joint
                print(f"  First gripper link after tool0: '{gripper_base_link}'")
                break
    
    # Add all gripper links except the duplicate tool0
    print("\nAdding gripper links...")
    for link in gripper_robot.findall('link'):
        link_name = link.get('name')
        if link_name not in links_to_skip:
            print(f"  Adding link: {link_name}")
            combined_robot.append(link)
    
    # Add all gripper joints except the one connecting to tool0
    print("\nAdding gripper joints...")
    for joint in gripper_robot.findall('joint'):
        joint_name = joint.get('name')
        parent = joint.find('parent')
        
        # Skip the joint that connects to the duplicate tool0
        if parent is not None and parent.get('link') == 'tool0':
            print(f"  Skipping joint '{joint_name}' (connects to duplicate tool0)")
            continue
        
        print(f"  Adding joint: {joint_name}")
        combined_robot.append(joint)
    
    # Add transmission elements if present
    for transmission in gripper_robot.findall('transmission'):
        combined_robot.append(transmission)
    
    # Add gazebo elements if present
    for gazebo in gripper_robot.findall('gazebo'):
        combined_robot.append(gazebo)
    
    # Create fixed joint to attach gripper to robot's tool0
    print(f"\nCreating attachment joint...")
    print(f"  Connecting robot '{attach_link}' to gripper '{gripper_base_link}'")
    
    attachment_joint = ET.Element('joint', attrib={
        'name': 'tool0_to_hande_gripper',
        'type': 'fixed'
    })
    
    parent = ET.SubElement(attachment_joint, 'parent', attrib={'link': attach_link})
    child = ET.SubElement(attachment_joint, 'child', attrib={'link': gripper_base_link})
    
    # Get the origin from the original gripper joint if it exists
    if gripper_attachment_joint is not None:
        original_origin = gripper_attachment_joint.find('origin')
        if original_origin is not None:
            origin_xyz = original_origin.get('xyz', '0 0 0')
            origin_rpy = original_origin.get('rpy', '0 0 0')
            print(f"  Using original gripper mounting offset: xyz='{origin_xyz}' rpy='{origin_rpy}'")
            origin = ET.SubElement(attachment_joint, 'origin', attrib={
                'xyz': origin_xyz,
                'rpy': origin_rpy
            })
        else:
            origin = ET.SubElement(attachment_joint, 'origin', attrib={
                'xyz': '0 0 0',
                'rpy': '0 0 0'
            })
    else:
        # Default: no offset
        origin = ET.SubElement(attachment_joint, 'origin', attrib={
            'xyz': '0 0 0',
            'rpy': '0 0 0'
        })
    
    combined_robot.append(attachment_joint)
    
    # Update robot name
    combined_robot.set('name', 'ur10e_with_hande')
    
    # Write combined URDF
    tree = ET.ElementTree(combined_robot)
    ET.indent(tree, space='  ')
    tree.write(output_path, encoding='utf-8', xml_declaration=True)
    
    print(f"\n✅ Combined URDF written to: {output_path}")
    
    # Print statistics
    links = combined_robot.findall('link')
    joints = combined_robot.findall('joint')
    print(f"\nCombined URDF statistics:")
    print(f"  Total links: {len(links)}")
    print(f"  Total joints: {len(joints)}")
    
    # List all links
    print(f"\nAll links in combined URDF:")
    for link in links:
        print(f"    - {link.get('name')}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python create_combined_urdf.py <robot_urdf> <gripper_urdf> <output_urdf>")
        sys.exit(1)
    
    robot_urdf = Path(sys.argv[1])
    gripper_urdf = Path(sys.argv[2])
    output_urdf = Path(sys.argv[3])
    
    if not robot_urdf.exists():
        print(f"Error: Robot URDF not found: {robot_urdf}")
        sys.exit(1)
    
    if not gripper_urdf.exists():
        print(f"Error: Gripper URDF not found: {gripper_urdf}")
        sys.exit(1)
    
    combine_urdf(robot_urdf, gripper_urdf, output_urdf)