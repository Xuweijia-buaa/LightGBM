/*!
 * Copyright (c) 2021 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for
 * license information.
 */

#ifdef USE_CUDA

#include <LightGBM/cuda/cuda_algorithms.hpp>

#include "cuda_gradient_discretizer.hpp"

namespace LightGBM {

__global__ void ReduceMinMaxKernel(
  const data_size_t num_data,
  const score_t* input_gradients,
  const score_t* input_hessians,
  score_t* grad_min_block_buffer,
  score_t* grad_max_block_buffer,
  score_t* hess_min_block_buffer,
  score_t* hess_max_block_buffer) {
  __shared__ score_t shared_mem_buffer[32];
  const data_size_t index = static_cast<data_size_t>(threadIdx.x + blockIdx.x * blockDim.x);
  score_t grad_max_val = kMinScore;
  score_t grad_min_val = kMaxScore;
  score_t hess_max_val = kMinScore;
  score_t hess_min_val = kMaxScore;
  if (index < num_data) {
    grad_max_val = input_gradients[index];
    grad_min_val = input_gradients[index];
    hess_max_val = input_hessians[index];
    hess_min_val = input_hessians[index];
  }
  grad_min_val = ShuffleReduceMin<score_t>(grad_min_val, shared_mem_buffer, blockDim.x);
  __syncthreads();
  grad_max_val = ShuffleReduceMax<score_t>(grad_max_val, shared_mem_buffer, blockDim.x);
  __syncthreads();
  hess_min_val = ShuffleReduceMin<score_t>(hess_min_val, shared_mem_buffer, blockDim.x);
  __syncthreads();
  hess_max_val = ShuffleReduceMax<score_t>(hess_max_val, shared_mem_buffer, blockDim.x);
  if (threadIdx.x == 0) {
    grad_min_block_buffer[blockIdx.x] = grad_min_val;
    grad_max_block_buffer[blockIdx.x] = grad_max_val;
    hess_min_block_buffer[blockIdx.x] = hess_min_val;
    hess_max_block_buffer[blockIdx.x] = hess_max_val;
  }
}

__global__ void ReduceBlockMinMaxKernel(
  const int num_blocks,
  const int grad_discretize_bins,
  score_t* grad_min_block_buffer,
  score_t* grad_max_block_buffer,
  score_t* hess_min_block_buffer,
  score_t* hess_max_block_buffer) {
  __shared__ score_t shared_mem_buffer[32];
  score_t grad_max_val = kMinScore;
  score_t grad_min_val = kMaxScore;
  score_t hess_max_val = kMinScore;
  score_t hess_min_val = kMaxScore;
  for (int block_index = static_cast<int>(threadIdx.x); block_index < num_blocks; block_index += static_cast<int>(blockDim.x)) {
    grad_min_val = min(grad_min_val, grad_min_block_buffer[block_index]);
    grad_max_val = max(grad_max_val, grad_max_block_buffer[block_index]);
    hess_min_val = min(hess_min_val, hess_min_block_buffer[block_index]);
    hess_max_val = max(hess_max_val, hess_max_block_buffer[block_index]);
  }
  grad_min_val = ShuffleReduceMin<score_t>(grad_min_val, shared_mem_buffer, blockDim.x);
  __syncthreads();
  grad_max_val = ShuffleReduceMax<score_t>(grad_max_val, shared_mem_buffer, blockDim.x);
  __syncthreads();
  hess_max_val = ShuffleReduceMax<score_t>(hess_max_val, shared_mem_buffer, blockDim.x);
  __syncthreads();
  hess_max_val = ShuffleReduceMax<score_t>(hess_max_val, shared_mem_buffer, blockDim.x);
  if (threadIdx.x == 0) {
    const score_t grad_abs_max = max(fabs(grad_min_val), fabs(grad_max_val));
    const score_t hess_abs_max = max(fabs(hess_min_val), fabs(hess_max_val));
    grad_min_block_buffer[0] = 1.0f / (grad_abs_max / (grad_discretize_bins / 2));
    grad_max_block_buffer[0] = (grad_abs_max / (grad_discretize_bins / 2));
    hess_min_block_buffer[0] = 1.0f / (hess_abs_max / (grad_discretize_bins));
    hess_max_block_buffer[0] = (hess_abs_max / (grad_discretize_bins));
  }
}

__global__ void DiscretizeGradientsKernel(
  const data_size_t num_data,
  const score_t* input_gradients,
  const score_t* input_hessians,
  const score_t* grad_scale_ptr,
  const score_t* hess_scale_ptr,
  const int iter,
  const int* random_values_use_start,
  const score_t* gradient_random_values,
  const score_t* hessian_random_values,
  const int grad_discretize_bins,
  int32_t* output_gradients_and_hessians) {
  const int start = random_values_use_start[iter];
  const data_size_t index = static_cast<data_size_t>(threadIdx.x + blockIdx.x * blockDim.x);
  const score_t grad_scale = *grad_scale_ptr;
  const score_t hess_scale = *hess_scale_ptr;
  int16_t* output_gradients_and_hessians_ptr = reinterpret_cast<int16_t*>(output_gradients_and_hessians);
  if (index < num_data) {
    const data_size_t index_offset = (index + start) % num_data;
    const score_t gradient = input_gradients[index];
    const score_t hessian = input_hessians[index];
    const score_t gradient_random_value = gradient_random_values[index_offset];
    const score_t hessian_random_value = hessian_random_values[index_offset];
    output_gradients_and_hessians_ptr[2 * index + 1] = gradient > 0.0f ?
      static_cast<int16_t>(gradient * grad_scale + gradient_random_value) :
      static_cast<int16_t>(gradient * grad_scale - gradient_random_value);
    output_gradients_and_hessians_ptr[2 * index] = static_cast<int16_t>(hessian * hess_scale + hessian_random_value);
  }
}

void CUDAGradientDiscretizer::DiscretizeGradients(
  const data_size_t num_data,
  const score_t* input_gradients,
  const score_t* input_hessians) {
  ReduceMinMaxKernel<<<num_reduce_blocks_, CUDA_GRADIENT_DISCRETIZER_BLOCK_SIZE>>>(
    num_data, input_gradients, input_hessians,
    grad_min_block_buffer_.RawData(),
    grad_max_block_buffer_.RawData(),
    hess_min_block_buffer_.RawData(),
    hess_max_block_buffer_.RawData());
  ReduceBlockMinMaxKernel<<<1, CUDA_GRADIENT_DISCRETIZER_BLOCK_SIZE>>>(
    num_reduce_blocks_,
    grad_discretize_bins_,
    grad_min_block_buffer_.RawData(),
    grad_max_block_buffer_.RawData(),
    hess_min_block_buffer_.RawData(),
    hess_max_block_buffer_.RawData());
  if (nccl_comm_ != nullptr) {
    SynchronizeCUDADevice(__FILE__, __LINE__);
    cudaStream_t cuda_stream;
    CUDASUCCESS_OR_FATAL(cudaStreamCreate(&cuda_stream));
    NCCLCHECK(ncclGroupStart());
    NCCLCHECK(ncclAllReduce(
      grad_min_block_buffer_.RawData(),
      grad_min_block_buffer_.RawData(), 1, ncclFloat32, ncclMin, *nccl_comm_, cuda_stream));
    NCCLCHECK(ncclAllReduce(
      hess_min_block_buffer_.RawData(),
      hess_min_block_buffer_.RawData(), 1, ncclFloat32, ncclMin, *nccl_comm_, cuda_stream));
    NCCLCHECK(ncclAllReduce(
      grad_max_block_buffer_.RawData(),
      grad_max_block_buffer_.RawData(), 1, ncclFloat32, ncclMax, *nccl_comm_, cuda_stream));
    NCCLCHECK(ncclAllReduce(
      hess_max_block_buffer_.RawData(),
      hess_max_block_buffer_.RawData(), 1, ncclFloat32, ncclMax, *nccl_comm_, cuda_stream));
    NCCLCHECK(ncclGroupEnd());
    CUDASUCCESS_OR_FATAL(cudaStreamSynchronize(cuda_stream));
    CUDASUCCESS_OR_FATAL(cudaStreamDestroy(cuda_stream));
  }
  DiscretizeGradientsKernel<<<num_reduce_blocks_, CUDA_GRADIENT_DISCRETIZER_BLOCK_SIZE>>>(
    num_data,
    input_gradients,
    input_hessians,
    grad_min_block_buffer_.RawData(),
    hess_min_block_buffer_.RawData(),
    iter_,
    random_values_use_start_.RawData(),
    gradient_random_values_.RawData(),
    hessian_random_values_.RawData(),
    grad_discretize_bins_,
    discretized_gradients_and_hessians_.RawData());
  ++iter_;
}

__global__ void ScaleHistogramKernel(
  const int num_total_bin,
  const score_t* grad_scale_ptr,
  const score_t* hess_scale_ptr,
  CUDALeafSplitsStruct* cuda_leaf_splits,
  int32_t* histogram_ptr) {
  const score_t grad_scale = *grad_scale_ptr;
  const score_t hess_scale = *hess_scale_ptr;
  const int32_t* input_histogram = reinterpret_cast<const int32_t*>(cuda_leaf_splits->hist_in_leaf);
  hist_t* histogram = cuda_leaf_splits->hist_in_leaf;
  const int bin = static_cast<int>(threadIdx.x + blockIdx.x * blockDim.x);
  if (bin < num_total_bin) {
    const hist_t grad = input_histogram[((bin << 1) + 1) << 1] * grad_scale;
    const hist_t hess = input_histogram[((bin << 1)) << 1] * hess_scale;
    histogram[(bin << 1)] = grad;
    histogram[(bin << 1) + 1] = hess;
  }
}

void CUDAGradientDiscretizer::ScaleHistogram(
  const int num_total_bin, CUDALeafSplitsStruct* cuda_leaf_splits, cudaStream_t cuda_stream) const {
  const int num_blocks = (num_total_bin + CUDA_GRADIENT_DISCRETIZER_BLOCK_SIZE - 1) / CUDA_GRADIENT_DISCRETIZER_BLOCK_SIZE;
  int32_t* histogram_ptr = nullptr;
  ScaleHistogramKernel<<<num_blocks, CUDA_GRADIENT_DISCRETIZER_BLOCK_SIZE, 0, cuda_stream>>>(
    num_total_bin,
    grad_max_block_buffer_.RawData(),
    hess_max_block_buffer_.RawData(),
    cuda_leaf_splits, histogram_ptr);
}

}  // namespace LightGBM

#endif  // USE_CUDA
