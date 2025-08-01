SHELL := /bin/bash -o pipefail
VERSION := $(shell cat VERSION)
VERSION_DASHES := $(subst .,-,$(VERSION))
SHORT_GIT_HASH := $(shell git rev-parse --short HEAD)

NGC_REGISTRY := nvcr.io/isv-ngc-partner/determined
NGC_PUBLISH := 1
export DOCKERHUB_REGISTRY := determinedai
export REGISTRY_REPO := environments

CPU_PREFIX_39 := $(REGISTRY_REPO):py-3.9-
CPU_PREFIX_310 := $(REGISTRY_REPO):py-3.10-
CUDA_113_PREFIX := $(REGISTRY_REPO):cuda-11.3-
CUDA_118_PREFIX := $(REGISTRY_REPO):cuda-11.8-
CUDA_129_PREFIX := $(REGISTRY_REPO):cuda-12.9-
ROCM_56_PREFIX := $(REGISTRY_REPO):rocm-5.6-
ROCM_57_PREFIX := $(REGISTRY_REPO):rocm-5.7-
ROCM_60_PREFIX := $(REGISTRY_REPO):rocm-6.0-
ROCM_61_PREFIX := $(REGISTRY_REPO):rocm-6.1-
ROCM_60_TF_PREFIX := tensorflow-infinity-hub:tensorflow-infinity-hub


CPU_SUFFIX := -cpu
CUDA_SUFFIX := -cuda
ARTIFACTS_DIR := /tmp/artifacts
PYTHON_VERSION_39 := 3.9.16
PYTHON_VERSION_310 := 3.10.12
PYTHON_VERSION_312 := 3.12
UBUNTU_VERSION := ubuntu20.04
UBUNTU_IMAGE_TAG := ubuntu:20.04
UBUNTU_VERSION_1804 := ubuntu18.04
PLATFORM_LINUX_ARM_64 := linux/arm64
PLATFORM_LINUX_AMD_64 := linux/amd64
HOROVOD_GPU_OPERATIONS := NCCL

ifeq "$(WITH_MPI)" "1"
# 	Don't bother supporting or building arm64+mpi builds.
	HPC_SUFFIX := -hpc
	PLATFORMS := $(PLATFORM_LINUX_AMD_64)
	HOROVOD_WITH_MPI := 1
	HOROVOD_WITHOUT_MPI := 0
	HOROVOD_CPU_OPERATIONS := MPI
	CUDA_SUFFIX := -cuda
	WITH_AWS_TRACE := 0
	NCCL_BUILD_ARG := WITH_NCCL
        ifeq "$(WITH_NCCL)" "1"
		NCCL_BUILD_ARG := WITH_NCCL=1
		ifeq "$(WITH_AWS_TRACE)" "1"
			WITH_AWS_TRACE := 1
		endif
        endif
	MPI_BUILD_ARG := WITH_MPI=1

	ifeq "$(WITH_OFI)" "1"
	        CUDA_SUFFIX := -cuda
		CPU_SUFFIX := -cpu
		OFI_BUILD_ARG := WITH_OFI=1
	else
		CPU_SUFFIX := -cpu
		OFI_BUILD_ARG := WITH_OFI
	endif
else
	PLATFORMS := $(PLATFORM_LINUX_AMD_64),$(PLATFORM_LINUX_ARM_64)
	WITH_MPI := 0
	OFI_BUILD_ARG := WITH_OFI
	NCCL_BUILD_ARG := WITH_NCCL
	HOROVOD_WITH_MPI := 0
	HOROVOD_WITHOUT_MPI := 1
	HOROVOD_CPU_OPERATIONS := GLOO
	MPI_BUILD_ARG := USE_GLOO=1
endif

export CPU_PY_39_BASE_NAME := $(CPU_PREFIX_39)base$(CPU_SUFFIX)
export CPU_PY_310_BASE_NAME := $(CPU_PREFIX_310)base$(CPU_SUFFIX)
export CUDA_113_BASE_NAME := $(CUDA_113_PREFIX)base$(CUDA_SUFFIX)
export CUDA_118_BASE_NAME := $(CUDA_118_PREFIX)base$(CUDA_SUFFIXS)
export CUDA_129_BASE_NAME := $(CUDA_129_PREFIX)base$(CUDA_SUFFIX)

# Timeout used by packer for AWS operations. Default is 120 (30 minutes) for
# waiting for AMI availablity. Bump to 360 attempts = 90 minutes.
export AWS_MAX_ATTEMPTS=360

# Base images.
.PHONY: build-cpu-py-39-base
build-cpu-py-39-base:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	docker buildx create --name builder --driver docker-container --use
	docker buildx build -f Dockerfile-base-cpu \
	    --platform "$(PLATFORMS)" \
		--build-arg BASE_IMAGE="$(UBUNTU_IMAGE_TAG)" \
		--build-arg PYTHON_VERSION="$(PYTHON_VERSION_39)" \
		--build-arg UBUNTU_VERSION="$(UBUNTU_VERSION)" \
		--build-arg "$(MPI_BUILD_ARG)" \
		--build-arg "$(OFI_BUILD_ARG)" \
		-t $(DOCKERHUB_REGISTRY)/$(CPU_PY_39_BASE_NAME)-$(SHORT_GIT_HASH) \
		--push \
		.

.PHONY: build-cpu-py-310-base
build-cpu-py-310-base:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	docker buildx create --name builder --driver docker-container --use
	docker buildx build -f Dockerfile-base-cpu \
	    --platform "$(PLATFORMS)" \
		--build-arg BASE_IMAGE="$(UBUNTU_IMAGE_TAG)" \
		--build-arg PYTHON_VERSION="$(PYTHON_VERSION_310)" \
		--build-arg UBUNTU_VERSION="$(UBUNTU_VERSION)" \
		--build-arg "$(MPI_BUILD_ARG)" \
		--build-arg "$(OFI_BUILD_ARG)" \
		-t $(DOCKERHUB_REGISTRY)/$(CPU_PY_310_BASE_NAME)-$(SHORT_GIT_HASH) \
		--push \
		.

.PHONY: build-cuda-113-base
build-cuda-113-base:
	docker buildx build -f Dockerfile-base-cuda \
		--build-arg BASE_IMAGE="nvidia/cuda:11.3.1-cudnn8-devel-$(UBUNTU_VERSION)" \
		--build-arg PYTHON_VERSION="$(PYTHON_VERSION_39)" \
		--build-arg UBUNTU_VERSION="$(UBUNTU_VERSION)" \
		--build-arg WITH_AWS_TRACE="$(WITH_AWS_TRACE)" \
		--build-arg "$(MPI_BUILD_ARG)" \
		--build-arg "$(OFI_BUILD_ARG)" \
		--build-arg "$(NCCL_BUILD_ARG)" \
		-t $(DOCKERHUB_REGISTRY)/$(CUDA_113_BASE_NAME)-$(SHORT_GIT_HASH) \
		--load \
		.

.PHONY: build-cuda-118-base
build-cuda-118-base:
        docker buildx build -f Dockerfile-base-cuda \
                --build-arg BASE_IMAGE="nvidia/cuda:11.8.0-cudnn8-devel-$(UBUNTU_VERSION)" \
                --build-arg PYTHON_VERSION="$(PYTHON_VERSION_310)" \
                --build-arg UBUNTU_VERSION="$(UBUNTU_VERSION)" \
                --build-arg WITH_AWS_TRACE="$(WITH_AWS_TRACE)" \
                --build-arg "$(MPI_BUILD_ARG)" \
                --build-arg "$(OFI_BUILD_ARG)" \
                --build-arg "$(NCCL_BUILD_ARG)" \
                -t $(DOCKERHUB_REGISTRY)/$(CUDA_118_BASE_NAME)-$(SHORT_GIT_HASH) \
                --load \
                .

.PHONY: build-cuda-129-base
build-cuda-129-base:
        docker buildx build -f Dockerfile-base-cuda \
                --build-arg BASE_IMAGE="nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04" \
                --build-arg PYTHON_VERSION="$(PYTHON_VERSION_312)" \
                --build-arg UBUNTU_VERSION="ubuntu24.04" \
                --build-arg WITH_AWS_TRACE="$(WITH_AWS_TRACE)" \
                --build-arg "$(MPI_BUILD_ARG)" \
                --build-arg "$(OFI_BUILD_ARG)" \
                --build-arg "$(NCCL_BUILD_ARG)" \
                -t $(DOCKERHUB_REGISTRY)/$(CUDA_129_BASE_NAME)-$(SHORT_GIT_HASH) \
                --load \
                .

NGC_PYTORCH_PREFIX := nvcr.io/nvidia/pytorch
NGC_TENSORFLOW_PREFIX := nvcr.io/nvidia/tensorflow
NGC_PYTORCH_VERSION := 24.03-py3
NGC_TENSORFLOW_VERSION := 24.03-tf2-py3
export NGC_PYTORCH_REPO := pytorch-ngc-dev
NGC_PYTORCH_HPC_REPO := pytorch-ngc-hpc-dev
NGC_TF_REPO := tensorflow-ngc-dev
NGC_TF_HPC_REPO := tensorflow-ngc-hpc-dev

INFINITYHUB_PYTORCH_REPO := pytorch-infinityhub-dev
INFINITYHUB_PYTORCH_HPC_REPO := pytorch-infinityhub-hpc-dev

# build hpc together since hpc is dependent on the normal build
.PHONY: build-pytorch-ngc
build-pytorch-ngc:
	docker build -f Dockerfile-pytorch-ngc \
		--build-arg BASE_IMAGE="$(NGC_PYTORCH_PREFIX):$(NGC_PYTORCH_VERSION)" \
		-t $(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_REPO):$(SHORT_GIT_HASH) \
		.
	docker build -f Dockerfile-ngc-hpc \
		--build-arg BASE_IMAGE="$(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_REPO):$(SHORT_GIT_HASH)" \
		-t $(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_HPC_REPO):$(SHORT_GIT_HASH) \
		.
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_REPO):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m \"pytorch or deepspeed\" /workspace/tests"
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_HPC_REPO):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m \"pytorch or deepspeed\" /workspace/tests"

.PHONY: build-tensorflow-ngc
build-tensorflow-ngc:
	docker build -f Dockerfile-tensorflow-ngc \
		--build-arg BASE_IMAGE="$(NGC_TENSORFLOW_PREFIX):$(NGC_TENSORFLOW_VERSION)" \
		-t $(DOCKERHUB_REGISTRY)/$(NGC_TF_REPO):$(SHORT_GIT_HASH) \
		.
	docker build -f Dockerfile-ngc-hpc \
		--build-arg BASE_IMAGE="$(DOCKERHUB_REGISTRY)/$(NGC_TF_REPO):$(SHORT_GIT_HASH)" \
		-t $(DOCKERHUB_REGISTRY)/$(NGC_TF_HPC_REPO):$(SHORT_GIT_HASH) \
		.
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(NGC_TF_REPO):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m tensorflow /workspace/tests"
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(NGC_TF_HPC_REPO):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m tensorflow /workspace/tests"

ifeq ($(WITH_MPICH),1)
ROCM56_TORCH13_MPI :=pytorch-1.3-tf-2.10-rocm-mpich
else
ROCM56_TORCH13_MPI :=pytorch-1.3-tf-2.10-rocm-ompi
endif
export ROCM56_TORCH13_TF_ENVIRONMENT_NAME := $(ROCM_56_PREFIX)$(ROCM56_TORCH13_MPI)
.PHONY: build-pytorch13-tf210-rocm56
build-pytorch13-tf210-rocm56:
	docker build -f Dockerfile-default-rocm \
		--build-arg BASE_IMAGE="rocm/pytorch:rocm5.6_ubuntu20.04_py3.8_pytorch_1.13.1"\
		--build-arg TENSORFLOW_PIP="tensorflow-rocm==2.10.1.540" \
		--build-arg HOROVOD_PIP="horovod==0.28.1" \
		--build-arg WITH_MPICH=$(WITH_MPICH) \
		-t $(DOCKERHUB_REGISTRY)/$(ROCM56_TORCH13_TF_ENVIRONMENT_NAME)-$(SHORT_GIT_HASH) \
		-t $(DOCKERHUB_REGISTRY)/$(ROCM56_TORCH13_TF_ENVIRONMENT_NAME)-$(VERSION) \
		.
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(ROCM56_TORCH13_TF_ENVIRONMENT_NAME)-$(VERSION) /bin/bash -c "pip install pytest && pytest -m \"pytorch or tensorflow\" /workspace/tests"

ROCM_DEEPSPEED_VERSION := 0.14.4
WITH_MPICH=1
export ROCM61_TORCH_TF_ENVIRONMENT_NAME_DEEPSPEED := $(ROCM_61_PREFIX)pytorch-2.0-tf-2.10-rocm-deepspeed
.PHONY: build-pytorch-infinityhub
build-pytorch-infinityhub:
	docker build --shm-size='1gb' -f Dockerfile-infinityhub-pytorch \
                --build-arg BASE_IMAGE="rocm/pytorch:rocm6.1_ubuntu22.04_py3.10_pytorch_2.1.2" \
                --build-arg DEEPSPEED_PIP="deepspeed==$(ROCM_DEEPSPEED_VERSION)" \
                -t $(DOCKERHUB_REGISTRY)/$(INFINITYHUB_PYTORCH_REPO):$(SHORT_GIT_HASH) \
                .
	docker build --shm-size='1gb' -f Dockerfile-infinityhub-hpc \
                --build-arg BASE_IMAGE=$(DOCKERHUB_REGISTRY)/$(INFINITYHUB_PYTORCH_REPO):$(SHORT_GIT_HASH) \
                --build-arg WITH_MPICH=$(WITH_MPICH) \
                -t $(DOCKERHUB_REGISTRY)/$(INFINITYHUB_PYTORCH_HPC_REPO):$(SHORT_GIT_HASH) \
                .
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(INFINITYHUB_PYTORCH_REPO):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m \"deepspeed or pytorch\" /workspace/tests"
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(INFINITYHUB_PYTORCH_HPC_REPO):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m pytorch /workspace/tests"


ifeq ($(WITH_MPICH),1)
ROCM56_TORCH13_MPI :=pytorch-1.3-tf-2.10-rocm-mpich
else
ROCM56_TORCH13_MPI :=pytorch-1.3-tf-2.10-rocm-ompi
endif
export ROCM56_TORCH13_TF_ENVIRONMENT_NAME := $(ROCM_56_PREFIX)$(ROCM56_TORCH13_MPI)
.PHONY: build-pytorch13-tf210-rocm56
build-pytorch13-tf210-rocm56:
	docker build -f Dockerfile-default-rocm \
               --build-arg BASE_IMAGE="rocm/pytorch:rocm5.6_ubuntu20.04_py3.8_pytorch_1.13.1"\
               --build-arg TENSORFLOW_PIP="tensorflow-rocm==2.10.1.540" \
               --build-arg HOROVOD_PIP="horovod==0.28.1" \
               --build-arg WITH_MPICH=$(WITH_MPICH) \
               -t $(DOCKERHUB_REGISTRY)/$(ROCM56_TORCH13_TF_ENVIRONMENT_NAME)-$(SHORT_GIT_HASH) \
               -t $(DOCKERHUB_REGISTRY)/$(ROCM56_TORCH13_TF_ENVIRONMENT_NAME)-$(VERSION) \
               .
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(ROCM56_TORCH13_TF_ENVIRONMENT_NAME)-$(VERSION) /bin/bash -c "pip install pytest && pytest -m \"tensorflow or pytorch\" /workspace/tests"


ifeq ($(WITH_MPICH),1)
ROCM61_TORCH_MPI :=pytorch-2.0-tf-2.10-rocm-mpich
else
ROCM61_TORCH_MPI :=pytorch-2.0-tf-2.10-rocm-ompi
endif
export ROCM61_TORCH_TF_ENVIRONMENT_NAME := $(ROCM_61_PREFIX)$(ROCM61_TORCH_MPI)
.PHONY: build-pytorch20-tf210-rocm61
build-pytorch20-tf210-rocm61:
	docker build -f Dockerfile-default-rocm \
                --build-arg BASE_IMAGE="rocm/pytorch:rocm6.1_ubuntu22.04_py3.10_pytorch_2.1.2" \
                --build-arg TENSORFLOW_PIP="tensorflow-rocm==2.10.1.540" \
                --build-arg HOROVOD_PIP="0" \
                --build-arg WITH_MPICH=$(WITH_MPICH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_TF_ENVIRONMENT_NAME)-$(SHORT_GIT_HASH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_TF_ENVIRONMENT_NAME)-$(VERSION) \
                .
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_TF_ENVIRONMENT_NAME)-$(VERSION) /bin/bash -c "pip install pytest && pytest -m \"tensorflow or pytorch\" /workspace/tests"

ifeq ($(WITH_MPICH),1)
ROCM61_TORCH_MPI :=pytorch-3.10-rocm-mpich
else
ROCM61_TORCH_MPI :=pytorch-3.10-rocm-ompi
endif
export ROCM61_TORCH_ENVIRONMENT_NAME := $(ROCM_61_PREFIX)$(ROCM61_TORCH_MPI)
.PHONY: build-pytorch20-rocm61
build-pytorch20-rocm61:
	docker build -f Dockerfile-default-rocm \
                --build-arg BASE_IMAGE="rocm/pytorch:rocm6.1_ubuntu22.04_py3.10_pytorch_2.1.2" \
                --build-arg TENSORFLOW_PIP="0" \
                --build-arg HOROVOD_PIP="0" \
                --build-arg WITH_MPICH=$(WITH_MPICH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_ENVIRONMENT_NAME)-$(SHORT_GIT_HASH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_ENVIRONMENT_NAME)-$(VERSION) \
                .
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_ENVIRONMENT_NAME)-$(VERSION) /bin/bash -c "pip install pytest && pytest -m \"tensorflow or pytorch\" /workspace/tests"



export ROCM61_TF_ENVIRONMENT_NAME := $(ROCM_61_TF_PREFIX)
build-tf210-rocm61:
	docker build -f Dockerfile-tensorflow-rocm \
                --build-arg BASE_IMAGE="rocm/tensorflow:rocm6.1-py3.9-tf2.15-dev" \
                --build-arg HOROVOD_PIP="0" \
                --build-arg WITH_MPICH=$(WITH_MPICH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM61_TF_ENVIRONMENT_NAME)-$(SHORT_GIT_HASH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM61_TF_ENVIRONMENT_NAME)-$(VERSION) \
                .
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(ROCM61_TF_ENVIRONMENT_NAME)-$(VERSION) /bin/bash -c "pip install pytest && pytest -m tensorflow /workspace/tests"


DEEPSPEED_VERSION := 0.8.3
export GPU_DEEPSPEED_ENVIRONMENT_NAME := $(CUDA_113_PREFIX)pytorch-1.10-deepspeed-$(DEEPSPEED_VERSION)$(GPU_SUFFIX)
export GPU_GPT_NEOX_DEEPSPEED_ENVIRONMENT_NAME := $(CUDA_113_PREFIX)pytorch-1.10-gpt-neox-deepspeed$(GPU_SUFFIX)
export TORCH_PIP_DEEPSPEED_GPU := torch==1.10.2+cu113 torchvision==0.11.3+cu113 torchaudio==0.10.2+cu113 -f https://download.pytorch.org/whl/cu113/torch_stable.html

export ROCM57_TORCH_TF_ENVIRONMENT_NAME_DEEPSPEED := $(ROCM_57_PREFIX)pytorch-2.0-tf-2.10-rocm-deepspeed
.PHONY: build-pytorch20-tf210-rocm57-deepspeed
build-pytorch20-tf210-rocm57-deepspeed:
	docker build --shm-size='1gb' -f Dockerfile-default-rocm \
                --build-arg BASE_IMAGE="rocm/pytorch:rocm5.7_ubuntu20.04_py3.9_pytorch_2.1.1" \
                --build-arg TENSORFLOW_PIP="tensorflow-rocm==2.10.1.540" \
                --build-arg HOROVOD_PIP="horovod==0.28.1" \
                --build-arg TORCH_PIP="$(TORCH_PIP_DEEPSPEED_GPU)" \
                --build-arg TORCH_TB_PROFILER_PIP="$(TORCH_TB_PROFILER_PIP)" \
                --build-arg TORCH_CUDA_ARCH_LIST="6.0;6.1;6.2;7.0;7.5;8.0" \
                --build-arg APEX_GIT="https://github.com/determined-ai/apex.git@3caf0f40c92e92b40051d3afff8568a24b8be28d" \
                --build-arg DEEPSPEED_PIP="deepspeed==$(DEEPSPEED_VERSION)" \
                --build-arg WITH_MPICH=$(WITH_MPICH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM57_TORCH_TF_ENVIRONMENT_NAME_DEEPSPEED)-$(SHORT_GIT_HASH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM57_TORCH_TF_ENVIRONMENT_NAME_DEEPSPEED)-$(VERSION) \
                .
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(ROCM57_TORCH_TF_ENVIRONMENT_NAME_DEEPSPEED)-$(VERSION) /bin/bash -c "pip install pytest && pytest -m \"tensorflow or pytorch or deepspeed\" /workspace/tests"

export ROCM61_TORCH_TF_ENVIRONMENT_NAME_DEEPSPEED := $(ROCM_61_PREFIX)pytorch-2.0-tf-2.10-rocm-deepspeed
.PHONY: build-pytorch20-tf210-rocm61-deepspeed
build-pytorch20-tf210-rocm61-deepspeed:
	docker build --shm-size='1gb' -f Dockerfile-default-rocm \
                --build-arg BASE_IMAGE="rocm/pytorch:rocm6.1_ubuntu22.04_py3.10_pytorch_2.1.2" \
                --build-arg TENSORFLOW_PIP="tensorflow-rocm==2.10.1.540" \
                --build-arg HOROVOD_PIP="0" \
                --build-arg TORCH_PIP="$(TORCH_PIP_DEEPSPEED_GPU)" \
                --build-arg TORCH_TB_PROFILER_PIP="$(TORCH_TB_PROFILER_PIP)" \
                --build-arg TORCH_CUDA_ARCH_LIST="6.0;6.1;6.2;7.0;7.5;8.0" \
                --build-arg APEX_GIT="https://github.com/determined-ai/apex.git@3caf0f40c92e92b40051d3afff8568a24b8be28d" \
                --build-arg DEEPSPEED_PIP="deepspeed==$(DEEPSPEED_VERSION)" \
                --build-arg WITH_MPICH=$(WITH_MPICH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_TF_ENVIRONMENT_NAME_DEEPSPEED)-$(SHORT_GIT_HASH) \
                -t $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_TF_ENVIRONMENT_NAME_DEEPSPEED)-$(VERSION) \
                .
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_TF_ENVIRONMENT_NAME_DEEPSPEED)-$(VERSION) /bin/bash -c "pip install pytest && pytest -m \"tensorflow or pytorch or deepspeed\" /workspace/tests"



DEEPSPEED_VERSION := 0.8.3
export GPT_NEOX_DEEPSPEED_ENVIRONMENT_NAME := deepspeed-cuda-gpt-neox
export TORCH_PIP_DEEPSPEED_CUDA := torch==1.10.2+cu113 torchvision==0.11.3+cu113 torchaudio==0.10.2+cu113 -f https://download.pytorch.org/whl/cu113/torch_stable.html

# This builds deepspeed environment off of a patched version of EleutherAI's fork of DeepSpeed
# that we need for gpt-neox support.
.PHONY: build-deepspeed-gpt-neox
build-deepspeed-gpt-neox: build-cuda-113-base
	docker build -f Dockerfile-default-cuda \
		--build-arg BASE_IMAGE="$(DOCKERHUB_REGISTRY)/$(CUDA_113_BASE_NAME)-$(SHORT_GIT_HASH)" \
		--build-arg TORCH_PIP="$(TORCH_PIP_DEEPSPEED_CUDA)" \
		--build-arg TORCH_CUDA_ARCH_LIST="6.0;6.1;6.2;7.0;7.5;8.0" \
		--build-arg APEX_GIT="https://github.com/determined-ai/apex.git@3caf0f40c92e92b40051d3afff8568a24b8be28d" \
		--build-arg "$(NCCL_BUILD_ARG)" \
		--build-arg DEEPSPEED_PIP="git+https://github.com/determined-ai/deepspeed.git@eleuther_dai" \
		-t $(DOCKERHUB_REGISTRY)/$(GPT_NEOX_DEEPSPEED_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) \
		-t $(NGC_REGISTRY)/$(GPT_NEOX_DEEPSPEED_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) \
		.
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(GPT_NEOX_DEEPSPEED_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m \"deepspeed or pytorch\" /workspace/tests"

TORCH_VERSION := 2.7.1
TF_VERSION_SHORT := 2.11
TF_VERSION := 2.11.1
TF_PIP_CPU := tensorflow-cpu==$(TF_VERSION)
TF_PIP_CUDA := tensorflow==$(TF_VERSION)
TORCH_PIP_CPU := torch==2.7.1+cpu torchvision==0.22.1+cpu torchaudio==2.7.1+cpu --index-url https://download.pytorch.org/whl/cpu
TORCH_PIP_CUDA := torch==2.7.1+cu121 torchvision==0.22.1+cu121 torchaudio==2.7.1+cu121 --index-url https://download.pytorch.org/whl/cu121
HOROVOD_PIP_COMMAND := horovod==0.28.1

export CPU_TF_ENVIRONMENT_NAME := pytorch-tensorflow$(CPU_SUFFIX)$(HPC_SUFFIX)-dev
export CUDA_TF_ENVIRONMENT_NAME := pytorch-tensorflow$(CUDA_SUFFIX)$(HPC_SUFFIX)-dev

ifeq ($(NGC_PUBLISH),)
define CPU_TF_TAGS
-t $(DOCKERHUB_REGISTRY)/$(CPU_TF_ENVIRONMENT_NAME):$(SHORT_GIT_HASH)
endef
else
define CPU_TF_TAGS
-t $(DOCKERHUB_REGISTRY)/$(CPU_TF_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) \
-t $(NGC_REGISTRY)/$(CPU_TF_ENVIRONMENT_NAME):$(SHORT_GIT_HASH)
endef
endif

.PHONY: build-tensorflow-cpu
build-tensorflow-cpu: build-cpu-py-39-base
	docker buildx build -f Dockerfile-default-cpu \
	    --platform "$(PLATFORMS)" \
		--build-arg BASE_IMAGE="$(DOCKERHUB_REGISTRY)/$(CPU_PY_39_BASE_NAME)-$(SHORT_GIT_HASH)" \
		--build-arg TENSORFLOW_PIP="$(TF_PIP_CPU)" \
		--build-arg TORCH_PIP="$(TORCH_PIP_CPU)" \
		--build-arg HOROVOD_PIP="$(HOROVOD_PIP_COMMAND)" \
		--build-arg HOROVOD_WITH_MPI="$(HOROVOD_WITH_MPI)" \
		--build-arg HOROVOD_WITHOUT_MPI="$(HOROVOD_WITHOUT_MPI)" \
		--build-arg HOROVOD_CPU_OPERATIONS="$(HOROVOD_CPU_OPERATIONS)" \
		$(CPU_TF_TAGS) \
		--push \
		.
	docker run --platform linux/amd64 --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(CPU_TF_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m \"pytorch or tensorflow\" /workspace/tests"

.PHONY: build-tensorflow-cuda
build-tensorflow-cuda: build-cuda-129-base
	docker build -f Dockerfile-default-cuda \
                --build-arg BASE_IMAGE="$(DOCKERHUB_REGISTRY)/$(CUDA_129_BASE_NAME)-$(SHORT_GIT_HASH)" \
		--build-arg TENSORFLOW_PIP="$(TF_PIP_CUDA)" \
		--build-arg TORCH_PIP="$(TORCH_PIP_CUDA)" \
		--build-arg TORCH_CUDA_ARCH_LIST="3.7;6.0;6.1;6.2;7.0;7.5;8.0" \
		--build-arg APEX_GIT="https://github.com/determined-ai/apex.git@3caf0f40c92e92b40051d3afff8568a24b8be28d" \
		--build-arg HOROVOD_PIP="$(HOROVOD_PIP_COMMAND)" \
		--build-arg WITH_AWS_TRACE="$(WITH_AWS_TRACE)" \
		--build-arg INTERNAL_AWS_DS="$(INTERNAL_AWS_DS)" \
		--build-arg INTERNAL_AWS_PATH="$(INTERNAL_AWS_PATH)" \
		--build-arg "$(OFI_BUILD_ARG)" \
		--build-arg "$(NCCL_BUILD_ARG)" \
		--build-arg HOROVOD_WITH_MPI="$(HOROVOD_WITH_MPI)" \
		--build-arg HOROVOD_WITHOUT_MPI="$(HOROVOD_WITHOUT_MPI)" \
		--build-arg HOROVOD_CPU_OPERATIONS="$(HOROVOD_CPU_OPERATIONS)" \
		--build-arg HOROVOD_GPU_OPERATIONS="$(HOROVOD_GPU_OPERATIONS)" \
		--build-arg HOROVOD_GPU_ALLREDUCE="$(HOROVOD_GPU_ALLREDUCE)" \
		-t $(DOCKERHUB_REGISTRY)/$(CUDA_TF_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) \
		-t $(NGC_REGISTRY)/$(CUDA_TF_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) \
		.
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(CUDA_TF_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m \"pytorch or tensorflow\" /workspace/tests"

# torch 2.0 recipes
TORCH2_VERSION := 2.7.1
TORCH2_PIP_CPU := torch==2.7.1+cpu torchvision==0.22.1+cpu torchaudio==2.7.1+cpu --index-url https://download.pytorch.org/whl/cpu
TORCH2_PIP_CUDA := torch==2.7.1+cu121 torchvision==0.22.1+cu121 torchaudio==2.7.1+cu121 --index-url https://download.pytorch.org/whl/cu121
TORCH2_APEX_GIT_URL := https://github.com/determined-ai/apex.git@50ac8425403b98147cbb66aea9a2a27dd3fe7673
export CPU_PYTORCH_ENVIRONMENT_NAME := pytorch$(CPU_SUFFIX)$(HPC_SUFFIX)-dev
export CUDA_PYTORCH_ENVIRONMENT_NAME := pytorch$(CUDA_SUFFIX)$(HPC_SUFFIX)-dev

ifeq ($(NGC_PUBLISH),)
define CPU_PYTORCH_TAGS
-t $(DOCKERHUB_REGISTRY)/$(CPU_PYTORCH_ENVIRONMENT_NAME):$(SHORT_GIT_HASH)
endef
else
define CPU_PYTORCH_TAGS
-t $(DOCKERHUB_REGISTRY)/$(CPU_PYTORCH_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) \
-t $(NGC_REGISTRY)/$(CPU_PYTORCH_ENVIRONMENT_NAME):$(SHORT_GIT_HASH)
endef
endif

.PHONY: build-pytorch-cpu
build-pytorch-cpu: build-cpu-py-310-base
	docker buildx build -f Dockerfile-default-cpu \
	    --platform "$(PLATFORMS)" \
		--build-arg BASE_IMAGE="$(DOCKERHUB_REGISTRY)/$(CPU_PY_310_BASE_NAME)-$(SHORT_GIT_HASH)" \
		--build-arg TORCH_PIP="$(TORCH2_PIP_CPU)" \
		--build-arg HOROVOD_PIP="$(HOROVOD_PIP_COMMAND)" \
		--build-arg HOROVOD_WITH_MPI="$(HOROVOD_WITH_MPI)" \
		--build-arg HOROVOD_WITHOUT_MPI="$(HOROVOD_WITHOUT_MPI)" \
		--build-arg HOROVOD_CPU_OPERATIONS="$(HOROVOD_CPU_OPERATIONS)" \
		$(CPU_PYTORCH_TAGS) \
		--push \
		.
	docker run --platform linux/amd64 --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(CPU_PYTORCH_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m pytorch /workspace/tests"

.PHONY: build-pytorch-cuda
build-pytorch-cuda: build-cuda-129-base
        docker build -f Dockerfile-default-cuda \
                --build-arg BASE_IMAGE="$(DOCKERHUB_REGISTRY)/$(CUDA_129_BASE_NAME)-$(SHORT_GIT_HASH)" \
                --build-arg TORCH_PIP="$(TORCH2_PIP_CUDA)" \
                --build-arg TORCH_CUDA_ARCH_LIST="6.0;6.1;6.2;7.0;7.5;8.0" \
                --build-arg APEX_GIT=$(TORCH2_APEX_GIT_URL) \
		--build-arg HOROVOD_PIP="$(HOROVOD_PIP_COMMAND)" \
		--build-arg "$(NCCL_BUILD_ARG)" \
		--build-arg HOROVOD_WITH_MPI="$(HOROVOD_WITH_MPI)" \
		--build-arg HOROVOD_WITHOUT_MPI="$(HOROVOD_WITHOUT_MPI)" \
		--build-arg HOROVOD_CPU_OPERATIONS="$(HOROVOD_CPU_OPERATIONS)" \
		-t $(DOCKERHUB_REGISTRY)/$(CUDA_PYTORCH_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) \
		-t $(NGC_REGISTRY)/$(CUDA_PYTORCH_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) \
		.
	docker run --rm -v `pwd`/tests:/workspace/tests -it $(DOCKERHUB_REGISTRY)/$(CUDA_PYTORCH_ENVIRONMENT_NAME):$(SHORT_GIT_HASH) /bin/bash -c "pip install pytest && pytest -m pytorch /workspace/tests"

.PHONY: publish-tensorflow-cpu
publish-tensorflow-cpu:
	scripts/publish-versionless-docker.sh tensorflow-cpu-$(WITH_MPI) $(DOCKERHUB_REGISTRY)/$(CPU_TF_ENVIRONMENT_NAME) $(SHORT_GIT_HASH) $(ARTIFACTS_DIR) --no-push

.PHONY: publish-tensorflow-cuda
publish-tensorflow-cuda:
	scripts/publish-versionless-docker.sh tensorflow-cuda-$(WITH_MPI) $(DOCKERHUB_REGISTRY)/$(CUDA_TF_ENVIRONMENT_NAME) $(SHORT_GIT_HASH) $(ARTIFACTS_DIR)
ifneq ($(NGC_PUBLISH),)
	scripts/publish-versionless-docker.sh tensorflow-cuda-$(WITH_MPI) $(NGC_REGISTRY)/$(CUDA_TF_ENVIRONMENT_NAME) $(SHORT_GIT_HASH)
endif

.PHONY: publish-pytorch-cpu
publish-pytorch-cpu:
	scripts/publish-versionless-docker.sh pytorch-cpu-$(WITH_MPI) $(DOCKERHUB_REGISTRY)/$(CPU_PYTORCH_ENVIRONMENT_NAME) $(SHORT_GIT_HASH) $(ARTIFACTS_DIR) --no-push

.PHONY: publish-pytorch-cuda
publish-pytorch-cuda:
	scripts/publish-versionless-docker.sh pytorch-cuda-$(WITH_MPI) $(DOCKERHUB_REGISTRY)/$(CUDA_PYTORCH_ENVIRONMENT_NAME) $(SHORT_GIT_HASH) $(ARTIFACTS_DIR)
ifneq ($(NGC_PUBLISH),)
	scripts/publish-versionless-docker.sh pytorch-cuda-$(WITH_MPI) $(NGC_REGISTRY)/$(CUDA_PYTORCH_ENVIRONMENT_NAME) $(SHORT_GIT_HASH)
endif

.PHONY: publish-deepspeed-gpt-neox
publish-deepspeed-gpt-neox:
	scripts/publish-versionless-docker.sh deepspeed-gpt-neox-$(WITH_MPI) $(DOCKERHUB_REGISTRY)/$(GPT_NEOX_DEEPSPEED_ENVIRONMENT_NAME) $(SHORT_GIT_HASH) $(ARTIFACTS_DIR)
ifneq ($(NGC_PUBLISH),)
	scripts/publish-versionless-docker.sh deepspeed-gpt-neox-$(WITH_MPI) $(NGC_REGISTRY)/$(GPT_NEOX_DEEPSPEED_ENVIRONMENT_NAME) $(SHORT_GIT_HASH)
endif

.PHONY: publish-pytorch-ngc
publish-pytorch-ngc:
	scripts/publish-versionless-docker.sh pytorch-ngc $(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_REPO) $(SHORT_GIT_HASH) $(ARTIFACTS_DIR)
	scripts/publish-versionless-docker.sh pytorch-ngc-hpc $(DOCKERHUB_REGISTRY)/$(NGC_PYTORCH_HPC_REPO) $(SHORT_GIT_HASH) $(ARTIFACTS_DIR)

.PHONY: publish-pytorch13-tf210-rocm56
publish-pytorch13-tf210-rocm56:
	scripts/publish-docker.sh pytorch13-tf210-rocm56-$(WITH_MPI) $(DOCKERHUB_REGISTRY)/$(ROCM56_TORCH13_TF_ENVIRONMENT_NAME) $(SHORT_GIT_HASH) $(VERSION) $(ARTIFACTS_DIR)

.PHONY: publish-pytorch20-tf210-rocm61
publish-pytorch20-tf210-rocm61:
	scripts/publish-docker.sh pytorch20-tf210-rocm61-$(WITH_MPI) $(DOCKERHUB_REGISTRY)/$(ROCM61_TORCH_TF_ENVIRONMENT_NAME) $(SHORT_GIT_HASH) $(VERSION) $(ARTIFACTS_DIR)

.PHONY: publish-tensorflow-ngc
publish-tensorflow-ngc:
	scripts/publish-versionless-docker.sh tensorflow-ngc $(DOCKERHUB_REGISTRY)/$(NGC_TF_REPO) $(SHORT_GIT_HASH) $(ARTIFACTS_DIR)
	scripts/publish-versionless-docker.sh tensorflow-ngc-hpc $(DOCKERHUB_REGISTRY)/$(NGC_TF_HPC_REPO) $(SHORT_GIT_HASH) $(ARTIFACTS_DIR)

.PHONY: publish-cloud-images
publish-cloud-images:
	mkdir -p $(ARTIFACTS_DIR)
	cd cloud \
		&& packer build $(PACKER_FLAGS) -machine-readable -var "image_suffix=$(SHORT_GIT_HASH)" environments-packer.json \
		| tee $(ARTIFACTS_DIR)/packer-log
