ARG JETPACK_VERSION=36.4
ARG CUDA_VERSION=12.6.11-1
ARG L4T_CUDA_TAG=12.6.11-runtime
ARG BASE_CUDA_DEV_CONTAINER=nvcr.io/nvidia/l4t-cuda:${L4T_CUDA_TAG}
ARG BASE_CUDA_RUN_CONTAINER=nvcr.io/nvidia/l4t-cuda:${L4T_CUDA_TAG}

FROM ${BASE_CUDA_DEV_CONTAINER} AS build
ARG JETPACK_VERSION
ARG CUDA_VERSION
WORKDIR /app

# Orin Nano is Ampere with compute capability 8.7.
ARG CUDA_DOCKER_ARCH=87
ARG CMAKE_CUDA_ARCHITECTURES=${CUDA_DOCKER_ARCH}
ENV CUDA_DOCKER_ARCH=${CUDA_DOCKER_ARCH}
ENV PATH=/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda/compat:/usr/local/cuda/lib64:$LD_LIBRARY_PATH

LABEL org.opencontainers.image.description="whisper.cpp CUDA build for NVIDIA Jetson Orin Nano" \
      org.opencontainers.image.vendor="ggml-org" \
      com.nvidia.jetpack.version="${JETPACK_VERSION}" \
      com.nvidia.cuda.version="${CUDA_VERSION}"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      cuda-libraries-dev-12-6=${CUDA_VERSION} \
      cuda-minimal-build-12-6=${CUDA_VERSION} \
      git \
      libsdl2-dev \
      wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY . .
RUN cmake -B build \
      -DGGML_CUDA=1 \
      -DGGML_CUDA_NCCL=OFF \
      -DWHISPER_BUILD_TESTS=OFF \
      -DCMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHITECTURES}" && \
    cmake --build build --config Release --target whisper-cli whisper-server whisper-bench

RUN find /app/build -name "*.o" -delete && \
    find /app/build -name "*.a" -delete && \
    rm -rf /app/build/CMakeFiles && \
    rm -rf /app/build/cmake_install.cmake && \
    rm -rf /app/build/_deps

FROM ${BASE_CUDA_RUN_CONTAINER} AS runtime
ARG JETPACK_VERSION
ARG CUDA_VERSION
WORKDIR /app
ENV PATH=/app/build/bin:/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda/compat:/usr/local/cuda/lib64:$LD_LIBRARY_PATH

LABEL org.opencontainers.image.description="whisper.cpp CUDA runtime for NVIDIA Jetson Orin Nano" \
      org.opencontainers.image.vendor="ggml-org" \
      com.nvidia.jetpack.version="${JETPACK_VERSION}" \
      com.nvidia.cuda.version="${CUDA_VERSION}"

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates curl ffmpeg wget \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --from=build /app /app
EXPOSE 8080
ENTRYPOINT [ "bash", "-c" ]
CMD [ "whisper-server --host 0.0.0.0 --port 8080 -m /models/ggml-base.en.bin" ]
