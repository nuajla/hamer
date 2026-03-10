# syntax=docker/dockerfile:1.7
FROM nvidia/cuda:11.7.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 python3.10-dev python3-pip python3.10-venv python3-wheel \
    build-essential gcc g++ make cmake git wget curl ffmpeg \
    ninja-build pkg-config \
    libglib2.0-0 libsm6 libxext6 libgl1 \
    libglfw3-dev libgles2-mesa-dev \
    espeak-ng libsndfile1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN python3.10 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Stari paketi v HaMeR stacku se tepajo z novejšim setuptools in NumPy 2.x
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -U pip wheel "setuptools<82" "numpy<2" cython ninja

# Uradna PyTorch kombinacija za CUDA 11.7
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
      torch==1.13.1+cu117 \
      torchvision==0.14.1+cu117 \
      torchaudio==0.13.1 \
      --extra-index-url https://download.pytorch.org/whl/cu117

# Osnovni python deps, ročno in stabilno
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
      gdown opencv-python pyrender pytorch-lightning scikit-image \
      smplx==0.1.28 yacs timm einops pandas \
      hydra-core hydra-submitit-launcher hydra-colorlog \
      pyrootutils rich webdataset

# xtcocotools raje iz source zaradi ABI težav z NumPy
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install "numpy<2" cython matplotlib

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-build-isolation --no-binary xtcocotools xtcocotools
# chumpy je star in rad pade z build isolation
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-build-isolation chumpy==0.70

# mmcv po upstream setup.py
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-build-isolation mmcv==1.3.9

# detectron2 zgradi v containerju, kjer se CUDA ujema s torch buildom
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-build-isolation --no-deps 'git+https://github.com/facebookresearch/detectron2.git'

COPY third-party/ third-party/
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-build-isolation -v -e third-party/ViTPose

COPY . .

# Sam projekt editable, brez resolverja, da ti ne prepiše torch stacka
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-deps -e .

CMD ["/bin/bash"]