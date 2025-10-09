# build.sh - Main build script to run on host
#!/bin/bash

# Build the Docker image
docker build -t ur10e-urdf-builder .

# Run the container and extract URDF
docker run --rm \
    -v $(pwd)/out:/workspace/out \
    ur10e-urdf-builder

echo "URDF files are now available in ./out/"