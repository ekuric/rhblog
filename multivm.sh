#!/bin/bash

# Enhanced VM creation script with customizable prefix, range, CPU, memory, and storage support
# Usage: ./multivm.sh [OPTIONS]
# Options:
#   -p, --prefix PREFIX    VM name prefix (default: vm)
#   -s, --start NUMBER     Starting VM number (default: 1)
#   -e, --end NUMBER       Ending VM number (default: 1)
#   -c, --count NUMBER     Number of VMs to create (alternative to --end)
#   --cores NUMBER         CPU cores per socket (default: 2)
#   --sockets NUMBER       Number of CPU sockets (default: 2)
#   --threads NUMBER       CPU threads per core (default: 1)
#   --memory SIZE          Memory size with unit (default: 12Gi)
#   --storageclass NAME    Storage class name (default: ocs-storagecluster-ceph-rbd)
#   --imageurl URL         Image URL (default: Fedora Cloud Base 42)
#   -h, --help            Show this help message
#
# Examples:
#   ./multivm.sh -p test -s 1 -e 10                    # Creates test-1 to test-10
#   ./multivm.sh -p worker -c 5                        # Creates worker-1 to worker-5
#   ./multivm.sh -p db --cores 4 --memory 16Gi -c 3    # Creates db-1 to db-3 with 4 cores, 16Gi RAM

# Default values
PREFIX="vm"
START=1
END=1
COUNT=""
CPU_CORES=2
CPU_SOCKETS=2
CPU_THREADS=1
MEMORY="12Gi"
STORAGECLASS="ocs-storagecluster-ceph-rbd"
IMAGEURL="https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --prefix PREFIX    VM name prefix (default: vm)"
    echo "  -s, --start NUMBER     Starting VM number (default: 1)"
    echo "  -e, --end NUMBER       Ending VM number (default: 1)"
    echo "  -c, --count NUMBER     Number of VMs to create (alternative to --end)"
    echo "  --cores NUMBER         CPU cores per socket (default: 2)"
    echo "  --sockets NUMBER       Number of CPU sockets (default: 2)"
    echo "  --threads NUMBER       CPU threads per core (default: 1)"
    echo "  --memory SIZE          Memory size with unit (default: 12Gi)"
    echo "  --storageclass NAME    Storage class name (default: ocs-storagecluster-ceph-rbd)"
    echo "  --imageurl URL         Image URL (default: https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p test -s 1 -e 10                    # Creates test-1 to test-10"
    echo "  $0 -p worker -c 5                        # Creates worker-1 to worker-5"
    echo "  $0 -p db --cores 4 --memory 16Gi -c 3    # Creates db-1 to db-3 with 4 cores, 16Gi RAM"
    echo "  $0 -p app --sockets 1 --cores 8 -c 2     # Creates app-1 to app-2 with 1 socket, 8 cores"
    echo "  $0 -p web --storageclass fast-ssd -c 3   # Creates web-1 to web-3 with custom storage class"
    echo ""
    echo "CPU Configuration:"
    echo "  Total vCPUs = cores × sockets × threads"
    echo "  Default: 2 cores × 2 sockets × 1 thread = 4 vCPUs"
    echo ""
    echo "Memory Examples:"
    echo "  8Gi, 12Gi, 16Gi, 32Gi, 64Gi"
    echo ""
    echo "Note: You must specify at least one VM to create using -c, -e, or -s options"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -s|--start)
            START="$2"
            shift 2
            ;;
        -e|--end)
            END="$2"
            shift 2
            ;;
        -c|--count)
            COUNT="$2"
            shift 2
            ;;
        --cores)
            CPU_CORES="$2"
            shift 2
            ;;
        --sockets)
            CPU_SOCKETS="$2"
            shift 2
            ;;
        --threads)
            CPU_THREADS="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --storageclass)
            STORAGECLASS="$2"
            shift 2
            ;;
        --imageurl)
            IMAGEURL="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Unknown option $1"
            show_usage
            exit 1
            ;;
        *)
            echo "Invalid argument: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if any meaningful options were provided
if [[ -z "$COUNT" ]] && [[ "$START" -eq 1 ]] && [[ "$END" -eq 1 ]]; then
    echo "Error: No options provided. You must specify at least one VM to create."
    echo ""
    show_usage
    exit 1
fi

# Calculate END if COUNT is provided
if [[ -n "$COUNT" ]]; then
    END=$((START + COUNT - 1))
fi

# Validate inputs
if [[ ! "$START" =~ ^[0-9]+$ ]] || [[ ! "$END" =~ ^[0-9]+$ ]]; then
    echo "Error: Start and end must be positive integers"
    exit 1
fi

if [[ "$START" -gt "$END" ]]; then
    echo "Error: Start number ($START) cannot be greater than end number ($END)"
    exit 1
fi

# Validate CPU parameters
if [[ ! "$CPU_CORES" =~ ^[0-9]+$ ]] || [[ ! "$CPU_SOCKETS" =~ ^[0-9]+$ ]] || [[ ! "$CPU_THREADS" =~ ^[0-9]+$ ]]; then
    echo "Error: CPU cores, sockets, and threads must be positive integers"
    exit 1
fi

if [[ "$CPU_CORES" -lt 1 ]] || [[ "$CPU_SOCKETS" -lt 1 ]] || [[ "$CPU_THREADS" -lt 1 ]]; then
    echo "Error: CPU cores, sockets, and threads must be at least 1"
    exit 1
fi

# Validate memory format (basic check for Gi suffix)
if [[ ! "$MEMORY" =~ ^[0-9]+Gi$ ]]; then
    echo "Error: Memory must be specified with Gi suffix (e.g., 8Gi, 12Gi, 16Gi)"
    exit 1
fi

# Calculate total VMs and total vCPUs
TOTAL_VMS=$((END - START + 1))
TOTAL_VCPUS=$((CPU_CORES * CPU_SOCKETS * CPU_THREADS))

echo "=========================================="
echo "    VM Creation Summary"
echo "=========================================="
echo "Prefix:        $PREFIX"
echo "Range:         $PREFIX-$START to $PREFIX-$END"
echo "Total VMs:     $TOTAL_VMS"
echo "CPU Config:    $CPU_CORES cores × $CPU_SOCKETS sockets × $CPU_THREADS threads = $TOTAL_VCPUS vCPUs"
echo "Memory:        $MEMORY per VM"
echo "Namespace:     default"
echo "Storage Class: $STORAGECLASS"
echo "Image URL:     $IMAGEURL"
echo ""
echo "VM Specifications:"
echo "  • CPU: $TOTAL_VCPUS vCPUs ($CPU_CORES cores × $CPU_SOCKETS sockets × $CPU_THREADS threads)"
echo "  • Memory: $MEMORY RAM"
echo "  • OS Disk: 10Gi ($IMAGEURL)"
echo "  • Data Disk: 50Gi (blank)"
echo ""
echo "Starting VM creation in 3 seconds..."
echo "Press Ctrl+C to cancel..."
sleep 3

for vm in $(seq "$START" "$END"); do
	cat << EOF | oc create -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  annotations:
  name: $PREFIX-$vm
  namespace: default
spec:
  dataVolumeTemplates:
    - metadata:
        name: $PREFIX-$vm
      spec:
        pvc:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 10Gi
          storageClassName: $STORAGECLASS
          volumeMode: Block
        source:
          http:
            url: >-
              $IMAGEURL
    - metadata:
        name: $PREFIX-$vm-data
      spec:
        pvc:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 50Gi
          storageClassName: $STORAGECLASS
          volumeMode: Block
        source:
          blank: {}
  runStrategy: Always  
  template:
    metadata:
      annotations:
        vm.kubevirt.io/flavor: large
        vm.kubevirt.io/os: fedora
        vm.kubefirt.io/workload: server
      labels:
        flavor.template.kubevirt.io/large: 'true'
        kubevirt.io/domain: $PREFIX-vmroot
        kubevirt.io/size: large
        vm.kubevirt.io/name: $PREFIX-vmroot-$vm 
    spec:
      accessCredentials:
        - sshPublicKey:
            propagationMethod:
              noCloud: {} 
            source:
              secret:
                secretName: vmkeyroot
      domain:
        cpu:
          cores: $CPU_CORES
          sockets: $CPU_SOCKETS
          threads: $CPU_THREADS
        devices:
          disks:
            - disk:
                bus: virtio
              name: cloudinitdisk
            - disk:
                bus: virtio
              name: $PREFIX-test-disk-$vm
              bootOrder: 1
            - disk:
                bus: virtio
              name: $PREFIX-db-disk-$vm
          inputs:
            - bus: virtio
              name: tablet
              type: tablet
          interfaces:
            - masquerade: {}
              model: virtio
              name: default
          networkInterfaceMultiqueue: true
          rng: {}
        resources:
          requests:
            memory: $MEMORY
      evictionStrategy: None
      hostname: $PREFIX-vmroot-$vm
      networks:
        - name: default
          pod: {}
      terminationGracePeriodSeconds: 180
      volumes:
        - cloudInitNoCloud:
            userData: |
              #cloud-config
              user: root
              password: fedora
              chpasswd:
                expire: false
              disable_root: false
          name: cloudinitdisk
          disable_root: false
        - dataVolume:
            name: $PREFIX-$vm
          name: $PREFIX-test-disk-$vm
        - dataVolume:
            name: $PREFIX-$vm-data
          name: $PREFIX-db-disk-$vm

EOF
sleep 1
done

echo ""
echo "✅ Successfully created $TOTAL_VMS VMs: $PREFIX-$START to $PREFIX-$END"
echo "You can check the status with: oc get vms -n default | grep $PREFIX" 
