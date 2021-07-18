/*!
 * Copyright (c) 2021 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for
 * license information.
 */

#ifdef USE_CUDA

#include "cuda_data_partition.hpp"
#include <LightGBM/tree.h>

namespace LightGBM {

#define CONFLICT_FREE_INDEX(n) \
  ((n) + ((n) >> LOG_NUM_BANKS_DATA_PARTITION)) \

__device__ void PrefixSum(uint32_t* elements, unsigned int n) {
  unsigned int offset = 1;
  unsigned int threadIdx_x = threadIdx.x;
  const unsigned int conflict_free_n_minus_1 = CONFLICT_FREE_INDEX(n - 1);
  const uint32_t last_element = elements[conflict_free_n_minus_1];
  __syncthreads();
  for (int d = (n >> 1); d > 0; d >>= 1) {
    if (threadIdx_x < d) {
      const unsigned int src_pos = offset * (2 * threadIdx_x + 1) - 1;
      const unsigned int dst_pos = offset * (2 * threadIdx_x + 2) - 1;
      elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
    }
    offset <<= 1;
    __syncthreads();
  }
  if (threadIdx_x == 0) {
    elements[conflict_free_n_minus_1] = 0; 
  }
  __syncthreads();
  for (int d = 1; d < n; d <<= 1) {
    offset >>= 1;
    if (threadIdx_x < d) {
      const unsigned int dst_pos = offset * (2 * threadIdx_x + 2) - 1;
      const unsigned int src_pos = offset * (2 * threadIdx_x + 1) - 1;
      const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
      const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
      const uint32_t src_val = elements[conflict_free_src_pos];
      elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
      elements[conflict_free_dst_pos] += src_val;
    }
    __syncthreads();
  }
  if (threadIdx_x == 0) {
    elements[CONFLICT_FREE_INDEX(n)] = elements[conflict_free_n_minus_1] + last_element;
  }
}

__device__ void PrefixSum_1024(uint32_t* elements, unsigned int n) {
  //unsigned int offset = 1;
  unsigned int threadIdx_x = threadIdx.x;
  const unsigned int conflict_free_n_minus_1 = CONFLICT_FREE_INDEX(n - 1);
  const uint32_t last_element = elements[conflict_free_n_minus_1];
  __syncthreads();

  if (threadIdx_x < 512) {
    const unsigned int src_pos = (2 * threadIdx_x + 1) - 1;
    const unsigned int dst_pos = (2 * threadIdx_x + 2) - 1;
    elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
  }
  __syncthreads();

  if (threadIdx_x < 256) {
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 1) - 1;
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 1) - 1;
    elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
  }
  __syncthreads();
  
  if (threadIdx_x < 128) {
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 2) - 1;
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 2) - 1;
    elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
  }
  __syncthreads();
  
  if (threadIdx_x < 64) {
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 3) - 1;
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 3) - 1;
    elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
  }
  __syncthreads();
  
  if (threadIdx_x < 32) {
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 4) - 1;
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 4) - 1;
    elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
  }
  __syncthreads();
  
  if (threadIdx_x < 16) {
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 5) - 1;
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 5) - 1;
    elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
  }
  __syncthreads();

  if (threadIdx_x < 8) {
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 6) - 1;
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 6) - 1;
    elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
  }
  __syncthreads();

  if (threadIdx_x < 4) {
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 7) - 1;
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 7) - 1;
    elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
  }
  __syncthreads();

  if (threadIdx_x < 2) {
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 8) - 1;
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 8) - 1;
    elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
  }
  __syncthreads();

  if (threadIdx_x == 0) {
    //const unsigned int src_pos = 511;
    //const unsigned int dst_pos = 1023;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(1023);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(511);
    //elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
    elements[conflict_free_dst_pos] += elements[conflict_free_src_pos];
  //}
  //__syncthreads();

  /*for (int d = (n >> 1); d > 0; d >>= 1) {
    if (threadIdx_x < d) {
      const unsigned int src_pos = offset * (2 * threadIdx_x + 1) - 1;
      const unsigned int dst_pos = offset * (2 * threadIdx_x + 2) - 1;
      elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
    }
    offset <<= 1;
    __syncthreads();
  }*/
  //if (threadIdx_x == 0) {
    elements[conflict_free_n_minus_1] = 0; 
  //}
  //__syncthreads();

  //if (threadIdx_x == 0) {
    //const unsigned int dst_pos = 1023;
    //const unsigned int src_pos = 511;
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  if (threadIdx_x < 2) {
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 8) - 1;
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 8) - 1;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  if (threadIdx_x < 4) {
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 7) - 1;
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 7) - 1;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  if (threadIdx_x < 8) {
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 6) - 1;
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 6) - 1;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  if (threadIdx_x < 16) {
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 5) - 1;
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 5) - 1;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  if (threadIdx_x < 32) {
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 4) - 1;
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 4) - 1;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  if (threadIdx_x < 64) {
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 3) - 1;
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 3) - 1;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  if (threadIdx_x < 128) {
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 2) - 1;
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 2) - 1;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  if (threadIdx_x < 256) {
    const unsigned int dst_pos = ((2 * threadIdx_x + 2) << 1) - 1;
    const unsigned int src_pos = ((2 * threadIdx_x + 1) << 1) - 1;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  if (threadIdx_x < 512) {
    const unsigned int dst_pos = (2 * threadIdx_x + 2) - 1;
    const unsigned int src_pos = (2 * threadIdx_x + 1) - 1;
    const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
    const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
    const uint32_t src_val = elements[conflict_free_src_pos];
    elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
    elements[conflict_free_dst_pos] += src_val;
  }
  __syncthreads();

  /*for (int d = 1; d < n; d <<= 1) {
    offset >>= 1;
    if (threadIdx_x < d) {
      const unsigned int dst_pos = offset * (2 * threadIdx_x + 2) - 1;
      const unsigned int src_pos = offset * (2 * threadIdx_x + 1) - 1;
      const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
      const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
      const uint32_t src_val = elements[conflict_free_src_pos];
      elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
      elements[conflict_free_dst_pos] += src_val;
    }
    __syncthreads();
  }*/
  if (threadIdx_x == 0) {
    elements[CONFLICT_FREE_INDEX(n)] = elements[conflict_free_n_minus_1] + last_element;
  }
}

__device__ void PrefixSum(uint16_t* elements, unsigned int n) {
  unsigned int offset = 1;
  unsigned int threadIdx_x = threadIdx.x;
  const unsigned int conflict_free_n_minus_1 = CONFLICT_FREE_INDEX(n - 1);
  const uint16_t last_element = elements[conflict_free_n_minus_1];
  __syncthreads();
  for (int d = (n >> 1); d > 0; d >>= 1) {
    if (threadIdx_x < d) {
      const unsigned int src_pos = offset * (2 * threadIdx_x + 1) - 1;
      const unsigned int dst_pos = offset * (2 * threadIdx_x + 2) - 1;
      elements[CONFLICT_FREE_INDEX(dst_pos)] += elements[CONFLICT_FREE_INDEX(src_pos)];
    }
    offset <<= 1;
    __syncthreads();
  }
  if (threadIdx_x == 0) {
    elements[conflict_free_n_minus_1] = 0; 
  }
  __syncthreads();
  for (int d = 1; d < n; d <<= 1) {
    offset >>= 1;
    if (threadIdx_x < d) {
      const unsigned int dst_pos = offset * (2 * threadIdx_x + 2) - 1;
      const unsigned int src_pos = offset * (2 * threadIdx_x + 1) - 1;
      const unsigned int conflict_free_dst_pos = CONFLICT_FREE_INDEX(dst_pos);
      const unsigned int conflict_free_src_pos = CONFLICT_FREE_INDEX(src_pos);
      const uint16_t src_val = elements[conflict_free_src_pos];
      elements[conflict_free_src_pos] = elements[conflict_free_dst_pos];
      elements[conflict_free_dst_pos] += src_val;
    }
    __syncthreads();
  }
  if (threadIdx_x == 0) {
    elements[CONFLICT_FREE_INDEX(n)] = elements[conflict_free_n_minus_1] + last_element;
  }
}

__device__ void ReduceSum(uint16_t* array, const size_t size) {
  const unsigned int threadIdx_x = threadIdx.x;
  for (int s = 1; s < size; s <<= 1) {
    if (threadIdx_x % (2 * s) == 0 && (threadIdx_x + s) < size) {
      array[CONFLICT_FREE_INDEX(threadIdx_x)] += array[CONFLICT_FREE_INDEX(threadIdx_x + s)];
    }
    __syncthreads();
  }
}

__device__ void ReduceSum(double* array, const size_t size) {
  const unsigned int threadIdx_x = threadIdx.x;
  for (int s = 1; s < size; s <<= 1) {
    if (threadIdx_x % (2 * s) == 0 && (threadIdx_x + s) < size) {
      array[threadIdx_x] += array[threadIdx_x + s];
    }
    __syncthreads();
  }
}

__global__ void FillDataIndicesBeforeTrainKernel(const data_size_t* cuda_num_data,
  data_size_t* data_indices, int* cuda_data_index_to_leaf_index) {
  const data_size_t num_data_ref = *cuda_num_data;
  const unsigned int data_index = threadIdx.x + blockIdx.x * blockDim.x;
  if (data_index < num_data_ref) {
    data_indices[data_index] = data_index;
    cuda_data_index_to_leaf_index[data_index] = 0;
  }
}

void CUDADataPartition::LaunchFillDataIndicesBeforeTrain() {
  const int num_blocks = (num_data_ + FILL_INDICES_BLOCK_SIZE_DATA_PARTITION - 1) / FILL_INDICES_BLOCK_SIZE_DATA_PARTITION;
  data_size_t cuda_num_data = 0;
  CopyFromCUDADeviceToHost<data_size_t>(&cuda_num_data, cuda_num_data_, 1);
  Log::Warning("cuda_num_data = %d, num_data_ = %d", cuda_num_data, num_data_);
  FillDataIndicesBeforeTrainKernel<<<num_blocks, FILL_INDICES_BLOCK_SIZE_DATA_PARTITION>>>(cuda_num_data_, cuda_data_indices_, cuda_data_index_to_leaf_index_);
}

__device__ void PrepareOffset(const data_size_t num_data_in_leaf_ref, const uint8_t* split_to_left_bit_vector,
  data_size_t* block_to_left_offset_buffer, data_size_t* block_to_right_offset_buffer,
  const int split_indices_block_size_data_partition,
  uint16_t* thread_to_left_offset_cnt) {
  const unsigned int threadIdx_x = threadIdx.x;
  const unsigned int blockDim_x = blockDim.x;
  __syncthreads();
  ReduceSum(thread_to_left_offset_cnt, split_indices_block_size_data_partition);
  __syncthreads();
  if (threadIdx_x == 0) {
    const data_size_t num_data_in_block = (blockIdx.x + 1) * blockDim_x <= num_data_in_leaf_ref ? static_cast<data_size_t>(blockDim_x) :
      num_data_in_leaf_ref - static_cast<data_size_t>(blockIdx.x * blockDim_x);
    if (num_data_in_block > 0) {
      const data_size_t data_to_left = static_cast<data_size_t>(thread_to_left_offset_cnt[0]);
      block_to_left_offset_buffer[blockIdx.x + 1] = data_to_left;
      block_to_right_offset_buffer[blockIdx.x + 1] = num_data_in_block - data_to_left;
    } else {
      block_to_left_offset_buffer[blockIdx.x + 1] = 0;
      block_to_right_offset_buffer[blockIdx.x + 1] = 0;
    }
  }
}

template <bool MIN_IS_MAX, bool MAX_TO_LEFT, bool MISSING_IS_ZERO, bool MISSING_IS_NA, bool MFB_IS_ZERO, bool MFB_IS_NA, typename BIN_TYPE>
__global__ void UpdateDataIndexToLeafIndexKernel(const data_size_t cuda_leaf_data_start,
  const data_size_t num_data_in_leaf, const data_size_t* cuda_data_indices,
  const uint32_t th, const BIN_TYPE* column_data,
  // values from feature
  const uint32_t t_zero_bin, const uint32_t max_bin_ref, const uint32_t min_bin_ref,
  int* cuda_data_index_to_leaf_index, const int left_leaf_index, const int right_leaf_index,
  const int default_leaf_index, const int missing_default_leaf_index) {
  const data_size_t* data_indices_in_leaf = cuda_data_indices + cuda_leaf_data_start;
  const unsigned int local_data_index = blockIdx.x * blockDim.x + threadIdx.x;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (!MIN_IS_MAX) {
      if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
        (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
        cuda_data_index_to_leaf_index[global_data_index] = missing_default_leaf_index;
      } else if (bin < min_bin_ref || bin > max_bin_ref) {
        if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
          cuda_data_index_to_leaf_index[global_data_index] = missing_default_leaf_index;
        } else {
          cuda_data_index_to_leaf_index[global_data_index] = default_leaf_index;
        }
      } else if (bin > th) {
        cuda_data_index_to_leaf_index[global_data_index] = right_leaf_index;
      }/* else {
        cuda_data_index_to_leaf_index[global_data_index] = left_leaf_index;
      }*/
    } else {
      if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
        cuda_data_index_to_leaf_index[global_data_index] = missing_default_leaf_index;
      } else if (bin != max_bin_ref) {
        if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
          cuda_data_index_to_leaf_index[global_data_index] = missing_default_leaf_index;
        } else {
          cuda_data_index_to_leaf_index[global_data_index] = default_leaf_index;
        }
      } else {
        if (MISSING_IS_NA && !MFB_IS_NA) {
          cuda_data_index_to_leaf_index[global_data_index] = missing_default_leaf_index;
        } else {
          if (!MAX_TO_LEFT) {
            /*cuda_data_index_to_leaf_index[global_data_index] = left_leaf_index;
          } else {*/
            cuda_data_index_to_leaf_index[global_data_index] = right_leaf_index;
          }
        }
      }
    }
  }
}

#define UpdateDataIndexToLeafIndex_ARGS leaf_data_start, \
  num_data_in_leaf, cuda_data_indices, th, column_data, \
  t_zero_bin, max_bin_ref, min_bin_ref, cuda_data_index_to_leaf_index, left_leaf_index, right_leaf_index, \
  default_leaf_index, missing_default_leaf_index

template <typename BIN_TYPE>
void CUDADataPartition::LaunchUpdateDataIndexToLeafIndexKernel(const data_size_t leaf_data_start,
  const data_size_t num_data_in_leaf, const data_size_t* cuda_data_indices,
  const uint32_t th, const BIN_TYPE* column_data,
  // values from feature
  const uint32_t t_zero_bin, const uint32_t max_bin_ref, const uint32_t min_bin_ref,
  int* cuda_data_index_to_leaf_index, const int left_leaf_index, const int right_leaf_index,
  const int default_leaf_index, const int missing_default_leaf_index,
  const bool missing_is_zero, const bool missing_is_na, const bool mfb_is_zero, const bool mfb_is_na, const bool max_to_left,
  const int num_blocks, const int block_size) {
  if (min_bin_ref < max_bin_ref) {
    if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, false, false, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, false, false, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, false, false, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, false, false, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, false, true, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, false, true, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, false, true, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, false, true, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, true, false, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, true, false, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, true, false, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, true, false, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, true, true, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, true, true, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, true, true, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, false, true, true, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, false, false, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, false, false, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, false, false, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, false, false, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, false, true, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, false, true, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, false, true, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, false, true, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, true, false, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, true, false, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, true, false, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, true, false, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, true, true, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, true, true, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, true, true, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<false, true, true, true, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    }
  } else {
    if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, false, false, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, false, false, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, false, false, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, false, false, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, false, true, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, false, true, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, false, true, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, false, true, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, true, false, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, true, false, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, true, false, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, true, false, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, true, true, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, true, true, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, true, true, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, false, true, true, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, false, false, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, false, false, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, false, false, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, false, false, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, false, true, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, false, true, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, false, true, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, false, true, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, true, false, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, true, false, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, true, false, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, true, false, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, true, true, false, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, true, true, false, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && !max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, true, true, true, false, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && max_to_left) {
      UpdateDataIndexToLeafIndexKernel<true, true, true, true, true, true, BIN_TYPE><<<num_blocks, block_size, 0, cuda_streams_[4]>>>(UpdateDataIndexToLeafIndex_ARGS);
    }
  }
}

// min_bin_ref < max_bin_ref
template <typename BIN_TYPE, bool MISSING_IS_ZERO, bool MISSING_IS_NA, bool MFB_IS_ZERO, bool MFB_IS_NA>
__global__ void GenDataToLeftBitVectorKernel0(const int best_split_feature_ref, const data_size_t cuda_leaf_data_start,
  const data_size_t num_data_in_leaf, const data_size_t* cuda_data_indices,
  const uint32_t th, const int num_features_ref, const BIN_TYPE* column_data,
  // values from feature
  const uint32_t t_zero_bin, const uint32_t most_freq_bin_ref, const uint32_t max_bin_ref, const uint32_t min_bin_ref,
  const uint8_t split_default_to_left, const uint8_t split_missing_default_to_left,
  uint8_t* cuda_data_to_left,
  data_size_t* block_to_left_offset_buffer, data_size_t* block_to_right_offset_buffer,
  const int split_indices_block_size_data_partition,
  int* cuda_data_index_to_leaf_index, const int left_leaf_index, const int right_leaf_index,
  const int default_leaf_index, const int missing_default_leaf_index) {
  __shared__ uint16_t thread_to_left_offset_cnt[SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 1 +
    (SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 1) / NUM_BANKS_DATA_PARTITION];
  const data_size_t* data_indices_in_leaf = cuda_data_indices + cuda_leaf_data_start;
  const unsigned int local_data_index = blockIdx.x * blockDim.x + threadIdx.x;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = 1;
    }
  } else {
    thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = 0;
  }
  __syncthreads();
  PrepareOffset(num_data_in_leaf, cuda_data_to_left, block_to_left_offset_buffer, block_to_right_offset_buffer,
    split_indices_block_size_data_partition, thread_to_left_offset_cnt);
}

// min_bin_ref < max_bin_ref
template <typename BIN_TYPE, bool MISSING_IS_ZERO, bool MISSING_IS_NA, bool MFB_IS_ZERO, bool MFB_IS_NA>
__global__ void GenDataToLeftBitVectorKernelPacked0(const int best_split_feature_ref, const data_size_t cuda_leaf_data_start,
  const data_size_t num_data_in_leaf, const data_size_t* cuda_data_indices,
  const uint32_t th, const int num_features_ref, const BIN_TYPE* column_data,
  // values from feature
  const uint32_t t_zero_bin, const uint32_t most_freq_bin_ref, const uint32_t max_bin_ref, const uint32_t min_bin_ref,
  const uint8_t split_default_to_left, const uint8_t split_missing_default_to_left,
  uint8_t* cuda_data_to_left,
  data_size_t* block_to_left_offset_buffer, data_size_t* block_to_right_offset_buffer,
  const int split_indices_block_size_data_partition,
  int* cuda_data_index_to_leaf_index, const int left_leaf_index, const int right_leaf_index,
  const int default_leaf_index, const int missing_default_leaf_index) {
  __shared__ uint16_t thread_to_left_offset_cnt[SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION * 4];
  const data_size_t* data_indices_in_leaf = cuda_data_indices + cuda_leaf_data_start;
  const unsigned int local_data_index = blockIdx.x * blockDim.x + threadIdx.x;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = 1;
    }
  } else {
    thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = 0;
  }
  __syncthreads();
  PrepareOffset(num_data_in_leaf, cuda_data_to_left, block_to_left_offset_buffer, block_to_right_offset_buffer,
    split_indices_block_size_data_partition, thread_to_left_offset_cnt);
}

// min_bin_ref == max_bin_ref
template <typename BIN_TYPE, bool MISSING_IS_ZERO, bool MISSING_IS_NA, bool MFB_IS_ZERO, bool MFB_IS_NA, bool MAX_TO_LEFT>
__global__ void GenDataToLeftBitVectorKernel16(const int best_split_feature_ref, const data_size_t cuda_leaf_data_start,
  const data_size_t num_data_in_leaf, const data_size_t* cuda_data_indices,
  const uint32_t th, const int num_features_ref, const BIN_TYPE* column_data,
  // values from feature
  const uint32_t t_zero_bin, const uint32_t most_freq_bin_ref, const uint32_t max_bin_ref, const uint32_t min_bin_ref,
  const uint8_t split_default_to_left, const uint8_t split_missing_default_to_left,
  uint8_t* cuda_data_to_left,
  data_size_t* block_to_left_offset_buffer, data_size_t* block_to_right_offset_buffer,
  const int split_indices_block_size_data_partition,
  int* cuda_data_index_to_leaf_index, const int left_leaf_index, const int right_leaf_index,
  const int default_leaf_index, const int missing_default_leaf_index) {
  __shared__ uint16_t thread_to_left_offset_cnt[SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 1 +
    (SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 1) / NUM_BANKS_DATA_PARTITION];
  const data_size_t* data_indices_in_leaf = cuda_data_indices + cuda_leaf_data_start;
  const unsigned int local_data_index = blockIdx.x * blockDim.x + threadIdx.x;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_missing_default_to_left;
    } else if (bin != max_bin_ref) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_default_to_left;
      }
    } else {
      if (MISSING_IS_NA && !MFB_IS_NA) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = split_missing_default_to_left;
      } else {
        if (MAX_TO_LEFT) {
          cuda_data_to_left[local_data_index] = 1;
          thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = 1;
        } else {
          cuda_data_to_left[local_data_index] = 0;
          thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = 0;
        }
      }
    }
  } else {
    thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = 0;
  }
  __syncthreads();
  PrepareOffset(num_data_in_leaf, cuda_data_to_left, block_to_left_offset_buffer, block_to_right_offset_buffer,
    split_indices_block_size_data_partition, thread_to_left_offset_cnt);
}

// min_bin_ref < max_bin_ref
template <typename BIN_TYPE, bool MISSING_IS_ZERO, bool MISSING_IS_NA, bool MFB_IS_ZERO, bool MFB_IS_NA>
__global__ void GenDataToLeftBitVectorKernel0_2(const int best_split_feature_ref, const data_size_t cuda_leaf_data_start,
  const data_size_t num_data_in_leaf, const data_size_t* cuda_data_indices,
  const uint32_t th, const int num_features_ref, const BIN_TYPE* column_data,
  // values from feature
  const uint32_t t_zero_bin, const uint32_t most_freq_bin_ref, const uint32_t max_bin_ref, const uint32_t min_bin_ref,
  const uint8_t split_default_to_left, const uint8_t split_missing_default_to_left,
  uint8_t* cuda_data_to_left,
  data_size_t* block_to_left_offset_buffer, data_size_t* block_to_right_offset_buffer,
  const int split_indices_block_size_data_partition,
  int* cuda_data_index_to_leaf_index, const int left_leaf_index, const int right_leaf_index,
  const int default_leaf_index, const int missing_default_leaf_index) {
  __shared__ uint16_t thread_to_left_offset_cnt[(SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION << 1) +
    ((SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION << 1) + 1) / NUM_BANKS_DATA_PARTITION];
  const data_size_t* data_indices_in_leaf = cuda_data_indices + cuda_leaf_data_start;
  uint8_t bit0 = 0;
  uint8_t bit1 = 0;
  uint8_t bit2 = 0;
  uint8_t bit3 = 0;
  uint8_t bit4 = 0;
  uint8_t bit5 = 0;
  uint8_t bit6 = 0;
  uint8_t bit7 = 0;
  unsigned int local_data_index = ((blockIdx.x * blockDim.x) << 3) + (threadIdx.x << 2);
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit0 = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit0 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit0 = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      bit0 = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      bit0 = 1;
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit1 = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit1 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit1 = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      bit1 = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      bit1 = 1;
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit2 = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit2 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit2 = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      bit2 = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      bit2 = 1;
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit3 = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit3 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit3 = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      bit3 = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      bit3 = 1;
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  local_data_index = ((blockIdx.x * blockDim.x) << 3) + ((threadIdx.x + blockDim.x) << 2);
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit4 = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit4 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit4 = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      bit4 = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      bit4 = 1;
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit5 = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit5 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit5 = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      bit5 = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      bit5 = 1;
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit6 = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit6 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit6 = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      bit6 = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      bit6 = 1;
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if ((MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) ||
      (MISSING_IS_NA && !MFB_IS_NA && bin == max_bin_ref)) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit7 = split_missing_default_to_left;
    } else if ((bin < min_bin_ref || bin > max_bin_ref)) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO || MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit7 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit7 = split_default_to_left;
      }
    } else if (bin > th) {
      cuda_data_to_left[local_data_index] = 0;
      bit7 = 0;
    } else {
      cuda_data_to_left[local_data_index] = 1;
      bit7 = 1;
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = bit0 + bit1 + bit2 + bit3;
  thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x + blockDim.x)] = bit4 + bit5 + bit6 + bit7;
  __syncthreads();
  ReduceSum(thread_to_left_offset_cnt, (split_indices_block_size_data_partition << 1));
  __syncthreads();
  if (threadIdx.x == 0) {
    const data_size_t num_data_in_block = (((blockIdx.x + 1) * blockDim.x * 8) <= num_data_in_leaf) ?
      static_cast<data_size_t>(blockDim.x * 8) :
      (num_data_in_leaf - static_cast<data_size_t>(blockIdx.x * blockDim.x * 8));
    if (num_data_in_block > 0) {
      const data_size_t data_to_left = static_cast<data_size_t>(thread_to_left_offset_cnt[0]);
      block_to_left_offset_buffer[blockIdx.x + 1] = data_to_left;
      block_to_right_offset_buffer[blockIdx.x + 1] = num_data_in_block - data_to_left;
    } else {
      block_to_left_offset_buffer[blockIdx.x + 1] = 0;
      block_to_right_offset_buffer[blockIdx.x + 1] = 0;
    }
  }
}

// min_bin_ref == max_bin_ref
template <typename BIN_TYPE, bool MISSING_IS_ZERO, bool MISSING_IS_NA, bool MFB_IS_ZERO, bool MFB_IS_NA, bool MAX_TO_LEFT>
__global__ void GenDataToLeftBitVectorKernel16_2(const int best_split_feature_ref, const data_size_t cuda_leaf_data_start,
  const data_size_t num_data_in_leaf, const data_size_t* cuda_data_indices,
  const uint32_t th, const int num_features_ref, const BIN_TYPE* column_data,
  // values from feature
  const uint32_t t_zero_bin, const uint32_t most_freq_bin_ref, const uint32_t max_bin_ref, const uint32_t min_bin_ref,
  const uint8_t split_default_to_left, const uint8_t split_missing_default_to_left,
  uint8_t* cuda_data_to_left,
  data_size_t* block_to_left_offset_buffer, data_size_t* block_to_right_offset_buffer,
  const int split_indices_block_size_data_partition,
  int* cuda_data_index_to_leaf_index, const int left_leaf_index, const int right_leaf_index,
  const int default_leaf_index, const int missing_default_leaf_index) {
  if (blockIdx.x == 0 && threadIdx.x == 0) {
    printf("********************************************** calling GenDataToLeftBitVectorKernel16_2 **********************************************\n");
  }
  __shared__ uint16_t thread_to_left_offset_cnt[(SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION << 1) + 1 +
    ((SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION << 1) + 1) / NUM_BANKS_DATA_PARTITION];
  const data_size_t* data_indices_in_leaf = cuda_data_indices + cuda_leaf_data_start;
  uint8_t bit0 = 0;
  uint8_t bit1 = 0;
  uint8_t bit2 = 0;
  uint8_t bit3 = 0;
  uint8_t bit4 = 0;
  uint8_t bit5 = 0;
  uint8_t bit6 = 0;
  uint8_t bit7 = 0;
  unsigned int local_data_index = ((blockIdx.x * blockDim.x) << 3) + (threadIdx.x << 2);
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit0 = split_missing_default_to_left;
    } else if (bin != max_bin_ref) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit0 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit0 = split_default_to_left;
      }
    } else {
      if (MISSING_IS_NA && !MFB_IS_NA) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit0 = split_missing_default_to_left;
      } else {
        if (MAX_TO_LEFT) {
          cuda_data_to_left[local_data_index] = 1;
          bit0 = 1;
        } else {
          cuda_data_to_left[local_data_index] = 0;
          bit0 = 0;
        }
      }
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit1 = split_missing_default_to_left;
    } else if (bin != max_bin_ref) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit1 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit1 = split_default_to_left;
      }
    } else {
      if (MISSING_IS_NA && !MFB_IS_NA) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit1 = split_missing_default_to_left;
      } else {
        if (MAX_TO_LEFT) {
          cuda_data_to_left[local_data_index] = 1;
          bit1 = 1;
        } else {
          cuda_data_to_left[local_data_index] = 0;
          bit1 = 0;
        }
      }
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit2 = split_missing_default_to_left;
    } else if (bin != max_bin_ref) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit2 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit2 = split_default_to_left;
      }
    } else {
      if (MISSING_IS_NA && !MFB_IS_NA) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit2 = split_missing_default_to_left;
      } else {
        if (MAX_TO_LEFT) {
          cuda_data_to_left[local_data_index] = 1;
          bit2 = 1;
        } else {
          cuda_data_to_left[local_data_index] = 0;
          bit2 = 0;
        }
      }
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit3 = split_missing_default_to_left;
    } else if (bin != max_bin_ref) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit3 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit3 = split_default_to_left;
      }
    } else {
      if (MISSING_IS_NA && !MFB_IS_NA) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit3 = split_missing_default_to_left;
      } else {
        if (MAX_TO_LEFT) {
          cuda_data_to_left[local_data_index] = 1;
          bit3 = 1;
        } else {
          cuda_data_to_left[local_data_index] = 0;
          bit3 = 0;
        }
      }
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  local_data_index = ((blockIdx.x * blockDim.x) << 3) + ((threadIdx.x + blockDim.x) << 2);
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit4 = split_missing_default_to_left;
    } else if (bin != max_bin_ref) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit4 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit4 = split_default_to_left;
      }
    } else {
      if (MISSING_IS_NA && !MFB_IS_NA) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit4 = split_missing_default_to_left;
      } else {
        if (MAX_TO_LEFT) {
          cuda_data_to_left[local_data_index] = 1;
          bit4 = 1;
        } else {
          cuda_data_to_left[local_data_index] = 0;
          bit4 = 0;
        }
      }
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit5 = split_missing_default_to_left;
    } else if (bin != max_bin_ref) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit5 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit5 = split_default_to_left;
      }
    } else {
      if (MISSING_IS_NA && !MFB_IS_NA) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit5 = split_missing_default_to_left;
      } else {
        if (MAX_TO_LEFT) {
          cuda_data_to_left[local_data_index] = 1;
          bit5 = 1;
        } else {
          cuda_data_to_left[local_data_index] = 0;
          bit5 = 0;
        }
      }
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit6 = split_missing_default_to_left;
    } else if (bin != max_bin_ref) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit6 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit6 = split_default_to_left;
      }
    } else {
      if (MISSING_IS_NA && !MFB_IS_NA) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit6 = split_missing_default_to_left;
      } else {
        if (MAX_TO_LEFT) {
          cuda_data_to_left[local_data_index] = 1;
          bit6 = 1;
        } else {
          cuda_data_to_left[local_data_index] = 0;
          bit6 = 0;
        }
      }
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  ++local_data_index;
  if (local_data_index < num_data_in_leaf) {
    const unsigned int global_data_index = data_indices_in_leaf[local_data_index];
    const uint32_t bin = static_cast<uint32_t>(column_data[global_data_index]);
    if (MISSING_IS_ZERO && !MFB_IS_ZERO && bin == t_zero_bin) {
      cuda_data_to_left[local_data_index] = split_missing_default_to_left;
      bit7 = split_missing_default_to_left;
    } else if (bin != max_bin_ref) {
      if ((MISSING_IS_NA && MFB_IS_NA) || (MISSING_IS_ZERO && MFB_IS_ZERO)) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit7 = split_missing_default_to_left;
      } else {
        cuda_data_to_left[local_data_index] = split_default_to_left;
        bit7 = split_default_to_left;
      }
    } else {
      if (MISSING_IS_NA && !MFB_IS_NA) {
        cuda_data_to_left[local_data_index] = split_missing_default_to_left;
        bit7 = split_missing_default_to_left;
      } else {
        if (MAX_TO_LEFT) {
          cuda_data_to_left[local_data_index] = 1;
          bit7 = 1;
        } else {
          cuda_data_to_left[local_data_index] = 0;
          bit7 = 0;
        }
      }
    }
  } else {
    cuda_data_to_left[local_data_index] = 0;
  }
  __syncthreads();
  thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x)] = bit0 + bit1 + bit2 + bit3;
  thread_to_left_offset_cnt[CONFLICT_FREE_INDEX(threadIdx.x + blockDim.x)] = bit4 + bit5 + bit6 + bit7;
  __syncthreads();
  ReduceSum(thread_to_left_offset_cnt, (split_indices_block_size_data_partition << 1));
  __syncthreads();
  if (threadIdx.x == 0) {
    const data_size_t num_data_in_block = (((blockIdx.x + 1) * blockDim.x * 8) <= num_data_in_leaf) ?
      static_cast<data_size_t>(blockDim.x * 8) :
      (num_data_in_leaf - static_cast<data_size_t>(blockIdx.x * blockDim.x * 8));
    if (num_data_in_block > 0) {
      const data_size_t data_to_left = static_cast<data_size_t>(thread_to_left_offset_cnt[0]);
      block_to_left_offset_buffer[blockIdx.x + 1] = data_to_left;
      block_to_right_offset_buffer[blockIdx.x + 1] = num_data_in_block - data_to_left;
    } else {
      block_to_left_offset_buffer[blockIdx.x + 1] = 0;
      block_to_right_offset_buffer[blockIdx.x + 1] = 0;
    }
  }
}

#define GenBitVector_ARGS \
  split_feature_index, leaf_data_start, num_data_in_leaf, cuda_data_indices_, \
  th, num_features_,  \
  column_data, t_zero_bin, most_freq_bin, max_bin, min_bin, split_default_to_left,  \
  split_missing_default_to_left, cuda_data_to_left_, cuda_block_data_to_left_offset_, cuda_block_data_to_right_offset_, \
  split_indices_block_size_data_partition_aligned, \
  cuda_data_index_to_leaf_index_, left_leaf_index, right_leaf_index, default_leaf_index, missing_default_leaf_index

template <typename BIN_TYPE>
void CUDADataPartition::LaunchGenDataToLeftBitVectorKernelMaxIsMinInner(
  const bool missing_is_zero,
  const bool missing_is_na,
  const bool mfb_is_zero,
  const bool mfb_is_na,
  const bool max_bin_to_left,
  const int column_index,
  const int num_blocks_final,
  const int split_indices_block_size_data_partition_aligned,
  const int split_feature_index,
  const data_size_t leaf_data_start,
  const data_size_t num_data_in_leaf,
  const uint32_t th,
  const uint32_t t_zero_bin,
  const uint32_t most_freq_bin,
  const uint32_t max_bin,
  const uint32_t min_bin,
  const uint8_t split_default_to_left,
  const uint8_t split_missing_default_to_left,
  const int left_leaf_index,
  const int right_leaf_index,
  const int default_leaf_index,
  const int missing_default_leaf_index) {
  if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, false, false, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, false, false, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, false, false, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, false, false, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, false, true, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, false, true, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, false, true, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, false, true, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, true, false, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, true, false, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, true, false, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, true, false, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, true, true, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, true, true, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, true, true, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, false, true, true, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, false, false, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, false, false, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, false, false, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, false, false, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, false, true, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, false, true, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, false, true, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, false, true, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, true, false, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, true, false, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, true, false, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, true, false, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, true, true, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, true, true, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, true, true, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16<BIN_TYPE, true, true, true, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  }
}

template <typename BIN_TYPE>
void CUDADataPartition::LaunchGenDataToLeftBitVectorKernelMaxIsMinInner2(
  const bool missing_is_zero,
  const bool missing_is_na,
  const bool mfb_is_zero,
  const bool mfb_is_na,
  const bool max_bin_to_left,
  const int column_index,
  const int num_blocks_final,
  const int split_indices_block_size_data_partition_aligned,
  const int split_feature_index,
  const data_size_t leaf_data_start,
  const data_size_t num_data_in_leaf,
  const uint32_t th,
  const uint32_t t_zero_bin,
  const uint32_t most_freq_bin,
  const uint32_t max_bin,
  const uint32_t min_bin,
  const uint8_t split_default_to_left,
  const uint8_t split_missing_default_to_left,
  const int left_leaf_index,
  const int right_leaf_index,
  const int default_leaf_index,
  const int missing_default_leaf_index) {
  int grid_dim = 0;
  int block_dim = 0;
  CalcBlockDim(num_data_in_leaf, &grid_dim, &block_dim);
  CHECK_EQ(num_blocks_final, grid_dim);
  CHECK_EQ(split_indices_block_size_data_partition_aligned, block_dim);
  if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, false, false, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, false, false, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, false, false, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, false, false, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, false, true, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, false, true, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, false, true, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, false, true, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, true, false, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, true, false, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, true, false, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, true, false, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, true, true, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, true, true, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, true, true, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, false, true, true, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, false, false, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, false, false, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, false, false, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, false, false, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, false, true, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, false, true, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, false, true, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, false, true, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, true, false, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, true, false, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, true, false, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, true, false, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, true, true, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, true, true, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && !max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, true, true, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na && max_bin_to_left) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel16_2<BIN_TYPE, true, true, true, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  }
}

template <typename BIN_TYPE>
void CUDADataPartition::LaunchGenDataToLeftBitVectorKernelMaxIsNotMinInner(
  const bool missing_is_zero,
  const bool missing_is_na,
  const bool mfb_is_zero,
  const bool mfb_is_na,
  const int column_index,
  const int num_blocks_final,
  const int split_indices_block_size_data_partition_aligned,
  const int split_feature_index,
  const data_size_t leaf_data_start,
  const data_size_t num_data_in_leaf,
  const uint32_t th,
  const uint32_t t_zero_bin,
  const uint32_t most_freq_bin,
  const uint32_t max_bin,
  const uint32_t min_bin,
  const uint8_t split_default_to_left,
  const uint8_t split_missing_default_to_left,
  const int left_leaf_index,
  const int right_leaf_index,
  const int default_leaf_index,
  const int missing_default_leaf_index) {
  if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, false, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, false, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, false, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, false, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, false, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, false, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, false, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, false, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, true, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, true, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, true, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, true, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, true, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, true, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, true, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, false, true, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, false, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, false, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, false, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, false, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, false, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, false, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, false, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, false, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, true, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, true, false, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, true, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, true, false, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, true, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, true, true, false><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, true, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0<BIN_TYPE, true, true, true, true><<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  }
}

template <typename BIN_TYPE>
void CUDADataPartition::LaunchGenDataToLeftBitVectorKernelMaxIsNotMinInner2(
  const bool missing_is_zero,
  const bool missing_is_na,
  const bool mfb_is_zero,
  const bool mfb_is_na,
  const int column_index,
  const int num_blocks_final,
  const int split_indices_block_size_data_partition_aligned,
  const int split_feature_index,
  const data_size_t leaf_data_start,
  const data_size_t num_data_in_leaf,
  const uint32_t th,
  const uint32_t t_zero_bin,
  const uint32_t most_freq_bin,
  const uint32_t max_bin,
  const uint32_t min_bin,
  const uint8_t split_default_to_left,
  const uint8_t split_missing_default_to_left,
  const int left_leaf_index,
  const int right_leaf_index,
  const int default_leaf_index,
  const int missing_default_leaf_index) {
  int grid_dim = 0;
  int block_dim = 0;
  CalcBlockDim(num_data_in_leaf, &grid_dim, &block_dim);
  CHECK_EQ(num_blocks_final, grid_dim);
  CHECK_EQ(split_indices_block_size_data_partition_aligned, block_dim);
  if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, false, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, false, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, false, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, false, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, false, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, false, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, false, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, false, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, true, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, true, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, true, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, true, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, true, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, true, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, true, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (!missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, false, true, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, false, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, false, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, false, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, false, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, false, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, false, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, false, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && !missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, false, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, true, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, true, false, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, true, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && !mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, true, false, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, true, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && !mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, true, true, false><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, true, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  } else if (missing_is_zero && missing_is_na && mfb_is_zero && mfb_is_na) {
    const BIN_TYPE* column_data = reinterpret_cast<const BIN_TYPE*>(cuda_data_by_column_[column_index]);
    GenDataToLeftBitVectorKernel0_2<BIN_TYPE, true, true, true, true><<<grid_dim, block_dim, 0, cuda_streams_[0]>>>(GenBitVector_ARGS);
  }
}

#undef GenBitVector_ARGS

void CUDADataPartition::LaunchGenDataToLeftBitVectorKernel(const data_size_t num_data_in_leaf,
  const int split_feature_index, const uint32_t split_threshold,
  const uint8_t split_default_left, const data_size_t leaf_data_start,
  const int left_leaf_index, const int right_leaf_index) {
  const int min_num_blocks = num_data_in_leaf <= 100 ? 1 : 80;
  const int num_blocks = std::max(min_num_blocks, (num_data_in_leaf + SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION - 1) / SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION);
  int split_indices_block_size_data_partition = (num_data_in_leaf + num_blocks - 1) / num_blocks - 1;
  int split_indices_block_size_data_partition_aligned = 1;
  while (split_indices_block_size_data_partition > 0) {
    split_indices_block_size_data_partition_aligned <<= 1;
    split_indices_block_size_data_partition >>= 1;
  }
  const int num_blocks_final = (num_data_in_leaf + split_indices_block_size_data_partition_aligned - 1) / split_indices_block_size_data_partition_aligned;
  const uint8_t missing_is_zero = feature_missing_is_zero_[split_feature_index];
  const uint8_t missing_is_na = feature_missing_is_na_[split_feature_index];
  const uint8_t mfb_is_zero = feature_mfb_is_zero_[split_feature_index];
  const uint8_t mfb_is_na = feature_mfb_is_na_[split_feature_index];
  const uint32_t default_bin = feature_default_bins_[split_feature_index];
  const uint32_t most_freq_bin = feature_most_freq_bins_[split_feature_index];
  const uint32_t min_bin = feature_min_bins_[split_feature_index];
  const uint32_t max_bin = feature_max_bins_[split_feature_index];

  uint32_t th = split_threshold + min_bin;
  uint32_t t_zero_bin = min_bin + default_bin;
  if (most_freq_bin == 0) {
    --th;
    --t_zero_bin;  
  }
  uint8_t split_default_to_left = 0;
  uint8_t split_missing_default_to_left = 0;
  int default_leaf_index = right_leaf_index;
  int missing_default_leaf_index = right_leaf_index;
  if (most_freq_bin <= split_threshold) {
    split_default_to_left = 1;
    default_leaf_index = left_leaf_index;
  }
  if (missing_is_zero || missing_is_na) {
    if (split_default_left) {
      split_missing_default_to_left = 1;
      missing_default_leaf_index = left_leaf_index;
    }
  }
  const int column_index = feature_index_to_column_index_[split_feature_index];
  const uint8_t bit_type = column_bit_type_[column_index];

  const bool max_bin_to_left = (max_bin <= th);

  if (min_bin < max_bin) {
    if (bit_type == 8) {
      LaunchGenDataToLeftBitVectorKernelMaxIsNotMinInner<uint8_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        column_index,
        num_blocks_final,
        split_indices_block_size_data_partition_aligned,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    } else if (bit_type == 16) {
      LaunchGenDataToLeftBitVectorKernelMaxIsNotMinInner<uint16_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        column_index,
        num_blocks_final,
        split_indices_block_size_data_partition_aligned,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    } else if (bit_type == 32) {
      LaunchGenDataToLeftBitVectorKernelMaxIsNotMinInner<uint32_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        column_index,
        num_blocks_final,
        split_indices_block_size_data_partition_aligned,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    }
  } else {
    if (bit_type == 8) {
      LaunchGenDataToLeftBitVectorKernelMaxIsMinInner<uint8_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        max_bin_to_left,
        column_index,
        num_blocks_final,
        split_indices_block_size_data_partition_aligned,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    } else if (bit_type == 16) {
      LaunchGenDataToLeftBitVectorKernelMaxIsMinInner<uint16_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        max_bin_to_left,
        column_index,
        num_blocks_final,
        split_indices_block_size_data_partition_aligned,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    } else if (bit_type == 32) {
      LaunchGenDataToLeftBitVectorKernelMaxIsMinInner<uint32_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        max_bin_to_left,
        column_index,
        num_blocks_final,
        split_indices_block_size_data_partition_aligned,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    }
  }

  if (bit_type == 8) {
    const uint8_t* column_data = reinterpret_cast<const uint8_t*>(cuda_data_by_column_[column_index]);
    LaunchUpdateDataIndexToLeafIndexKernel<uint8_t>(leaf_data_start, num_data_in_leaf,
      cuda_data_indices_, th, column_data, t_zero_bin, max_bin, min_bin, cuda_data_index_to_leaf_index_,
      left_leaf_index, right_leaf_index, default_leaf_index, missing_default_leaf_index,
      static_cast<bool>(missing_is_zero),
      static_cast<bool>(missing_is_na),
      static_cast<bool>(mfb_is_zero),
      static_cast<bool>(mfb_is_na),
      max_bin_to_left,
      num_blocks_final,
      split_indices_block_size_data_partition_aligned);
  } else if (bit_type == 16) {
    const uint16_t* column_data = reinterpret_cast<const uint16_t*>(cuda_data_by_column_[column_index]);
    LaunchUpdateDataIndexToLeafIndexKernel<uint16_t>(leaf_data_start, num_data_in_leaf,
      cuda_data_indices_, th, column_data, t_zero_bin, max_bin, min_bin, cuda_data_index_to_leaf_index_,
      left_leaf_index, right_leaf_index, default_leaf_index, missing_default_leaf_index,
      static_cast<bool>(missing_is_zero),
      static_cast<bool>(missing_is_na),
      static_cast<bool>(mfb_is_zero),
      static_cast<bool>(mfb_is_na),
      max_bin_to_left,
      num_blocks_final,
      split_indices_block_size_data_partition_aligned);
  } else if (bit_type == 32) {
    const uint32_t* column_data = reinterpret_cast<const uint32_t*>(cuda_data_by_column_[column_index]);
    LaunchUpdateDataIndexToLeafIndexKernel<uint32_t>(leaf_data_start, num_data_in_leaf,
      cuda_data_indices_, th, column_data, t_zero_bin, max_bin, min_bin, cuda_data_index_to_leaf_index_,
      left_leaf_index, right_leaf_index, default_leaf_index, missing_default_leaf_index,
      static_cast<bool>(missing_is_zero),
      static_cast<bool>(missing_is_na),
      static_cast<bool>(mfb_is_zero),
      static_cast<bool>(mfb_is_na),
      max_bin_to_left,
      num_blocks_final,
      split_indices_block_size_data_partition_aligned);
  }
}

void CUDADataPartition::LaunchGenDataToLeftBitVectorKernel2(const data_size_t num_data_in_leaf,
  const int split_feature_index, const uint32_t split_threshold,
  const uint8_t split_default_left, const data_size_t leaf_data_start,
  const int left_leaf_index, const int right_leaf_index) {
  int grid_dim = 0;
  int block_dim = 0;
  CalcBlockDim(num_data_in_leaf, &grid_dim, &block_dim);
  const uint8_t missing_is_zero = feature_missing_is_zero_[split_feature_index];
  const uint8_t missing_is_na = feature_missing_is_na_[split_feature_index];
  const uint8_t mfb_is_zero = feature_mfb_is_zero_[split_feature_index];
  const uint8_t mfb_is_na = feature_mfb_is_na_[split_feature_index];
  const uint32_t default_bin = feature_default_bins_[split_feature_index];
  const uint32_t most_freq_bin = feature_most_freq_bins_[split_feature_index];
  const uint32_t min_bin = feature_min_bins_[split_feature_index];
  const uint32_t max_bin = feature_max_bins_[split_feature_index];

  uint32_t th = split_threshold + min_bin;
  uint32_t t_zero_bin = min_bin + default_bin;
  if (most_freq_bin == 0) {
    --th;
    --t_zero_bin;  
  }
  uint8_t split_default_to_left = 0;
  uint8_t split_missing_default_to_left = 0;
  int default_leaf_index = right_leaf_index;
  int missing_default_leaf_index = right_leaf_index;
  if (most_freq_bin <= split_threshold) {
    split_default_to_left = 1;
    default_leaf_index = left_leaf_index;
  }
  if (missing_is_zero || missing_is_na) {
    if (split_default_left) {
      split_missing_default_to_left = 1;
      missing_default_leaf_index = left_leaf_index;
    }
  }
  const int column_index = feature_index_to_column_index_[split_feature_index];
  const uint8_t bit_type = column_bit_type_[column_index];

  const bool max_bin_to_left = (max_bin <= th);

  if (min_bin < max_bin) {
    if (bit_type == 8) {
      LaunchGenDataToLeftBitVectorKernelMaxIsNotMinInner2<uint8_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        column_index,
        grid_dim,
        block_dim,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    } else if (bit_type == 16) {
      LaunchGenDataToLeftBitVectorKernelMaxIsNotMinInner2<uint16_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        column_index,
        grid_dim,
        block_dim,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    } else if (bit_type == 32) {
      LaunchGenDataToLeftBitVectorKernelMaxIsNotMinInner2<uint32_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        column_index,
        grid_dim,
        block_dim,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    }
  } else {
    if (bit_type == 8) {
      LaunchGenDataToLeftBitVectorKernelMaxIsMinInner2<uint8_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        max_bin_to_left,
        column_index,
        grid_dim,
        block_dim,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    } else if (bit_type == 16) {
      LaunchGenDataToLeftBitVectorKernelMaxIsMinInner2<uint16_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        max_bin_to_left,
        column_index,
        grid_dim,
        block_dim,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    } else if (bit_type == 32) {
      LaunchGenDataToLeftBitVectorKernelMaxIsMinInner2<uint32_t>(
        missing_is_zero,
        missing_is_na,
        mfb_is_zero,
        mfb_is_na,
        max_bin_to_left,
        column_index,
        grid_dim,
        block_dim,
        split_feature_index,
        leaf_data_start,
        num_data_in_leaf,
        th,
        t_zero_bin,
        most_freq_bin,
        max_bin,
        min_bin,
        split_default_to_left,
        split_missing_default_to_left,
        left_leaf_index,
        right_leaf_index,
        default_leaf_index,
        missing_default_leaf_index);
    }
  }

  int grid_dim_copy = 0;
  int block_dim_copy = 0;
  CalcBlockDimInCopy(num_data_in_leaf, &grid_dim_copy, &block_dim_copy);
  if (bit_type == 8) {
    const uint8_t* column_data = reinterpret_cast<const uint8_t*>(cuda_data_by_column_[column_index]);
    LaunchUpdateDataIndexToLeafIndexKernel<uint8_t>(leaf_data_start, num_data_in_leaf,
      cuda_data_indices_, th, column_data, t_zero_bin, max_bin, min_bin, cuda_data_index_to_leaf_index_,
      left_leaf_index, right_leaf_index, default_leaf_index, missing_default_leaf_index,
      static_cast<bool>(missing_is_zero),
      static_cast<bool>(missing_is_na),
      static_cast<bool>(mfb_is_zero),
      static_cast<bool>(mfb_is_na),
      max_bin_to_left,
      grid_dim_copy,
      block_dim_copy);
  } else if (bit_type == 16) {
    const uint16_t* column_data = reinterpret_cast<const uint16_t*>(cuda_data_by_column_[column_index]);
    LaunchUpdateDataIndexToLeafIndexKernel<uint16_t>(leaf_data_start, num_data_in_leaf,
      cuda_data_indices_, th, column_data, t_zero_bin, max_bin, min_bin, cuda_data_index_to_leaf_index_,
      left_leaf_index, right_leaf_index, default_leaf_index, missing_default_leaf_index,
      static_cast<bool>(missing_is_zero),
      static_cast<bool>(missing_is_na),
      static_cast<bool>(mfb_is_zero),
      static_cast<bool>(mfb_is_na),
      max_bin_to_left,
      grid_dim_copy,
      block_dim_copy);
  } else if (bit_type == 32) {
    const uint32_t* column_data = reinterpret_cast<const uint32_t*>(cuda_data_by_column_[column_index]);
    LaunchUpdateDataIndexToLeafIndexKernel<uint32_t>(leaf_data_start, num_data_in_leaf,
      cuda_data_indices_, th, column_data, t_zero_bin, max_bin, min_bin, cuda_data_index_to_leaf_index_,
      left_leaf_index, right_leaf_index, default_leaf_index, missing_default_leaf_index,
      static_cast<bool>(missing_is_zero),
      static_cast<bool>(missing_is_na),
      static_cast<bool>(mfb_is_zero),
      static_cast<bool>(mfb_is_na),
      max_bin_to_left,
      grid_dim_copy,
      block_dim_copy);
  }
}

__global__ void AggregateBlockOffsetKernel(const int* leaf_index, data_size_t* block_to_left_offset_buffer,
  data_size_t* block_to_right_offset_buffer, data_size_t* cuda_leaf_data_start,
  data_size_t* cuda_leaf_data_end, data_size_t* cuda_leaf_num_data, const data_size_t* cuda_data_indices,
  int* cuda_cur_num_leaves,
  const int* best_split_feature, const uint32_t* best_split_threshold,
  const uint8_t* best_split_default_left, const double* best_split_gain,
  const double* best_left_sum_gradients, const double* best_left_sum_hessians, const data_size_t* best_left_count,
  const double* best_left_gain, const double* best_left_leaf_value,
  const double* best_right_sum_gradients, const double* best_right_sum_hessians, const data_size_t* best_right_count,
  const double* best_right_gain, const double* best_right_leaf_value,
  // for leaf splits information update
  int* smaller_leaf_cuda_leaf_index_pointer, double* smaller_leaf_cuda_sum_of_gradients_pointer,
  double* smaller_leaf_cuda_sum_of_hessians_pointer, data_size_t* smaller_leaf_cuda_num_data_in_leaf_pointer,
  double* smaller_leaf_cuda_gain_pointer, double* smaller_leaf_cuda_leaf_value_pointer,
  const data_size_t** smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** smaller_leaf_cuda_hist_pointer_pointer,
  int* larger_leaf_cuda_leaf_index_pointer, double* larger_leaf_cuda_sum_of_gradients_pointer,
  double* larger_leaf_cuda_sum_of_hessians_pointer, data_size_t* larger_leaf_cuda_num_data_in_leaf_pointer,
  double* larger_leaf_cuda_gain_pointer, double* larger_leaf_cuda_leaf_value_pointer,
  const data_size_t** larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** larger_leaf_cuda_hist_pointer_pointer,
  const int* cuda_num_total_bin,
  hist_t* cuda_hist, hist_t** cuda_hist_pool, const int split_indices_block_size_data_partition) {
  __shared__ uint32_t block_to_left_offset[SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 2 +
    (SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 2) / NUM_BANKS_DATA_PARTITION];
  __shared__ uint32_t block_to_right_offset[SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 2 +
    (SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 2) / NUM_BANKS_DATA_PARTITION];
  const int leaf_index_ref = *leaf_index;
  const data_size_t num_data_in_leaf = cuda_leaf_num_data[leaf_index_ref];
  const unsigned int blockDim_x = blockDim.x;
  const unsigned int threadIdx_x = threadIdx.x;
  const unsigned int conflict_free_threadIdx_x = CONFLICT_FREE_INDEX(threadIdx_x);
  const unsigned int conflict_free_threadIdx_x_plus_blockDim_x = CONFLICT_FREE_INDEX(threadIdx_x + blockDim_x);
  const uint32_t num_blocks = (num_data_in_leaf + split_indices_block_size_data_partition - 1) / split_indices_block_size_data_partition;
  const uint32_t num_aggregate_blocks = (num_blocks + split_indices_block_size_data_partition - 1) / split_indices_block_size_data_partition;
  uint32_t left_prev_sum = 0;
  for (uint32_t block_id = 0; block_id < num_aggregate_blocks; ++block_id) {
    const unsigned int read_index = block_id * blockDim_x * 2 + threadIdx_x;
    if (read_index < num_blocks) {
      block_to_left_offset[conflict_free_threadIdx_x] = block_to_left_offset_buffer[read_index + 1];
    } else {
      block_to_left_offset[conflict_free_threadIdx_x] = 0;
    }
    const unsigned int read_index_plus_blockDim_x = read_index + blockDim_x;
    if (read_index_plus_blockDim_x < num_blocks) {
      block_to_left_offset[conflict_free_threadIdx_x_plus_blockDim_x] = block_to_left_offset_buffer[read_index_plus_blockDim_x + 1];
    } else {
      block_to_left_offset[conflict_free_threadIdx_x_plus_blockDim_x] = 0;
    }
    if (threadIdx_x == 0) {
      block_to_left_offset[0] += left_prev_sum;
    }
    __syncthreads();
    PrefixSum(block_to_left_offset, split_indices_block_size_data_partition);
    __syncthreads();
    if (threadIdx_x == 0) {
      left_prev_sum = block_to_left_offset[CONFLICT_FREE_INDEX(split_indices_block_size_data_partition)];
    }
    if (read_index < num_blocks) {
      const unsigned int conflict_free_threadIdx_x_plus_1 = CONFLICT_FREE_INDEX(threadIdx_x + 1);
      block_to_left_offset_buffer[read_index + 1] = block_to_left_offset[conflict_free_threadIdx_x_plus_1];
    }
    if (read_index_plus_blockDim_x < num_blocks) {
      const unsigned int conflict_free_threadIdx_x_plus_1_plus_blockDim_x = CONFLICT_FREE_INDEX(threadIdx_x + 1 + blockDim_x);
      block_to_left_offset_buffer[read_index_plus_blockDim_x + 1] = block_to_left_offset[conflict_free_threadIdx_x_plus_1_plus_blockDim_x];
    }
    __syncthreads();
  }
  const unsigned int to_left_total_cnt = block_to_left_offset_buffer[num_blocks];
  uint32_t right_prev_sum = to_left_total_cnt;
  for (uint32_t block_id = 0; block_id < num_aggregate_blocks; ++block_id) {
    const unsigned int read_index = block_id * blockDim_x * 2 + threadIdx_x;
    if (read_index < num_blocks) {
      block_to_right_offset[conflict_free_threadIdx_x] = block_to_right_offset_buffer[read_index + 1];
    } else {
      block_to_right_offset[conflict_free_threadIdx_x] = 0;
    }
    const unsigned int read_index_plus_blockDim_x = read_index + blockDim_x;
    if (read_index_plus_blockDim_x < num_blocks) {
      block_to_right_offset[conflict_free_threadIdx_x_plus_blockDim_x] = block_to_right_offset_buffer[read_index_plus_blockDim_x + 1];
    } else {
      block_to_right_offset[conflict_free_threadIdx_x_plus_blockDim_x] = 0;
    }
    if (threadIdx_x == 0) {
      block_to_right_offset[0] += right_prev_sum;
    }
    __syncthreads();
    PrefixSum(block_to_right_offset, split_indices_block_size_data_partition);
    __syncthreads();
    if (threadIdx_x == 0) {
      right_prev_sum = block_to_right_offset[CONFLICT_FREE_INDEX(split_indices_block_size_data_partition)];
    }
    if (read_index < num_blocks) {
      const unsigned int conflict_free_threadIdx_x_plus_1 = CONFLICT_FREE_INDEX(threadIdx_x + 1);
      block_to_right_offset_buffer[read_index + 1] = block_to_right_offset[conflict_free_threadIdx_x_plus_1];
    }
    if (read_index_plus_blockDim_x < num_blocks) {
      const unsigned int conflict_free_threadIdx_x_plus_1_plus_blockDim_x = CONFLICT_FREE_INDEX(threadIdx_x + 1 + blockDim_x);
      block_to_right_offset_buffer[read_index_plus_blockDim_x + 1] = block_to_right_offset[conflict_free_threadIdx_x_plus_1_plus_blockDim_x];
    }
    __syncthreads();
  }
  if (blockIdx.x == 0 && threadIdx.x == 0) {
    ++(*cuda_cur_num_leaves);
    const int cur_max_leaf_index = (*cuda_cur_num_leaves) - 1;
    block_to_left_offset_buffer[0] = 0;
    const unsigned int to_left_total_cnt = block_to_left_offset_buffer[num_blocks];
    block_to_right_offset_buffer[0] = to_left_total_cnt;
    const data_size_t old_leaf_data_end = cuda_leaf_data_end[leaf_index_ref];
    cuda_leaf_data_end[leaf_index_ref] = cuda_leaf_data_start[leaf_index_ref] + static_cast<data_size_t>(to_left_total_cnt);
    cuda_leaf_num_data[leaf_index_ref] = static_cast<data_size_t>(to_left_total_cnt);
    cuda_leaf_data_start[cur_max_leaf_index] = cuda_leaf_data_end[leaf_index_ref];
    cuda_leaf_data_end[cur_max_leaf_index] = old_leaf_data_end;
    cuda_leaf_num_data[cur_max_leaf_index] = block_to_right_offset_buffer[num_blocks] - to_left_total_cnt;
  }
}

__global__ void AggregateBlockOffsetKernel2(const int* leaf_index, data_size_t* block_to_left_offset_buffer,
  data_size_t* block_to_right_offset_buffer, data_size_t* cuda_leaf_data_start,
  data_size_t* cuda_leaf_data_end, data_size_t* cuda_leaf_num_data, const data_size_t* cuda_data_indices,
  int* cuda_cur_num_leaves,
  const int* best_split_feature, const uint32_t* best_split_threshold,
  const uint8_t* best_split_default_left, const double* best_split_gain,
  const double* best_left_sum_gradients, const double* best_left_sum_hessians, const data_size_t* best_left_count,
  const double* best_left_gain, const double* best_left_leaf_value,
  const double* best_right_sum_gradients, const double* best_right_sum_hessians, const data_size_t* best_right_count,
  const double* best_right_gain, const double* best_right_leaf_value,
  // for leaf splits information update
  int* smaller_leaf_cuda_leaf_index_pointer, double* smaller_leaf_cuda_sum_of_gradients_pointer,
  double* smaller_leaf_cuda_sum_of_hessians_pointer, data_size_t* smaller_leaf_cuda_num_data_in_leaf_pointer,
  double* smaller_leaf_cuda_gain_pointer, double* smaller_leaf_cuda_leaf_value_pointer,
  const data_size_t** smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** smaller_leaf_cuda_hist_pointer_pointer,
  int* larger_leaf_cuda_leaf_index_pointer, double* larger_leaf_cuda_sum_of_gradients_pointer,
  double* larger_leaf_cuda_sum_of_hessians_pointer, data_size_t* larger_leaf_cuda_num_data_in_leaf_pointer,
  double* larger_leaf_cuda_gain_pointer, double* larger_leaf_cuda_leaf_value_pointer,
  const data_size_t** larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** larger_leaf_cuda_hist_pointer_pointer,
  const int* cuda_num_total_bin,
  hist_t* cuda_hist, hist_t** cuda_hist_pool,
  const data_size_t num_blocks) {
  __shared__ uint32_t block_to_left_offset[AGGREGATE_BLOCK_SIZE + 2 +
    (AGGREGATE_BLOCK_SIZE + 2) / NUM_BANKS_DATA_PARTITION];
  __shared__ uint32_t block_to_right_offset[AGGREGATE_BLOCK_SIZE + 2 +
    (AGGREGATE_BLOCK_SIZE + 2) / NUM_BANKS_DATA_PARTITION];
  const int leaf_index_ref = *leaf_index;
  const data_size_t num_data_in_leaf = cuda_leaf_num_data[leaf_index_ref];
  const unsigned int blockDim_x = blockDim.x;
  const unsigned int threadIdx_x = threadIdx.x;
  const unsigned int conflict_free_threadIdx_x = CONFLICT_FREE_INDEX(threadIdx_x);
  const data_size_t num_blocks_plus_1 = num_blocks + 1;
  const uint32_t num_blocks_per_thread = (num_blocks_plus_1 + blockDim_x - 1) / blockDim_x;
  const uint32_t remain = num_blocks_plus_1 - ((num_blocks_per_thread - 1) * blockDim_x);
  const uint32_t remain_offset = remain * num_blocks_per_thread;
  uint32_t thread_start_block_index = 0;
  uint32_t thread_end_block_index = 0;
  if (threadIdx_x < remain) {
    thread_start_block_index = threadIdx_x * num_blocks_per_thread;
    thread_end_block_index = min(thread_start_block_index + num_blocks_per_thread, num_blocks_plus_1);
  } else {
    thread_start_block_index = remain_offset + (num_blocks_per_thread - 1) * (threadIdx_x - remain);
    thread_end_block_index = min(thread_start_block_index + num_blocks_per_thread - 1, num_blocks_plus_1);
  }
  if (threadIdx.x == 0) {
    block_to_right_offset_buffer[0] = 0;
  }
  __syncthreads();
  for (uint32_t block_index = thread_start_block_index + 1; block_index < thread_end_block_index; ++block_index) {
    block_to_left_offset_buffer[block_index] += block_to_left_offset_buffer[block_index - 1];
    block_to_right_offset_buffer[block_index] += block_to_right_offset_buffer[block_index - 1];
  }
  __syncthreads();
  if (thread_start_block_index < thread_end_block_index) {
    block_to_left_offset[conflict_free_threadIdx_x] = block_to_left_offset_buffer[thread_end_block_index - 1];
    block_to_right_offset[conflict_free_threadIdx_x] = block_to_right_offset_buffer[thread_end_block_index - 1];
  } else {
    block_to_left_offset[conflict_free_threadIdx_x] = 0;
    block_to_right_offset[conflict_free_threadIdx_x] = 0;
  }
  __syncthreads();
  PrefixSum_1024(block_to_left_offset, blockDim_x);
  PrefixSum_1024(block_to_right_offset, blockDim_x);
  __syncthreads();
  const uint32_t to_left_total_count = block_to_left_offset[CONFLICT_FREE_INDEX(blockDim_x)];
  const uint32_t to_left_thread_block_offset = block_to_left_offset[conflict_free_threadIdx_x];
  const uint32_t to_right_thread_block_offset = block_to_right_offset[conflict_free_threadIdx_x] + to_left_total_count;
  for (uint32_t block_index = thread_start_block_index; block_index < thread_end_block_index; ++block_index) {
    block_to_left_offset_buffer[block_index] += to_left_thread_block_offset;
    block_to_right_offset_buffer[block_index] += to_right_thread_block_offset;
  }
  __syncthreads();
  if (blockIdx.x == 0 && threadIdx.x == 0) {
    ++(*cuda_cur_num_leaves);
    const int cur_max_leaf_index = (*cuda_cur_num_leaves) - 1;
    const data_size_t old_leaf_data_end = cuda_leaf_data_end[leaf_index_ref];
    cuda_leaf_data_end[leaf_index_ref] = cuda_leaf_data_start[leaf_index_ref] + static_cast<data_size_t>(to_left_total_count);
    cuda_leaf_num_data[leaf_index_ref] = static_cast<data_size_t>(to_left_total_count);
    cuda_leaf_data_start[cur_max_leaf_index] = cuda_leaf_data_end[leaf_index_ref];
    cuda_leaf_data_end[cur_max_leaf_index] = old_leaf_data_end;
    cuda_leaf_num_data[cur_max_leaf_index] = num_data_in_leaf - static_cast<data_size_t>(to_left_total_count);
  }
}

__global__ void AggregateBlockOffsetKernel3(const int* leaf_index, data_size_t* block_to_left_offset_buffer,
  data_size_t* block_to_right_offset_buffer, data_size_t* cuda_leaf_data_start,
  data_size_t* cuda_leaf_data_end, data_size_t* cuda_leaf_num_data, const data_size_t* cuda_data_indices,
  int* cuda_cur_num_leaves,
  const int* best_split_feature, const uint32_t* best_split_threshold,
  const uint8_t* best_split_default_left, const double* best_split_gain,
  const double* best_left_sum_gradients, const double* best_left_sum_hessians, const data_size_t* best_left_count,
  const double* best_left_gain, const double* best_left_leaf_value,
  const double* best_right_sum_gradients, const double* best_right_sum_hessians, const data_size_t* best_right_count,
  const double* best_right_gain, const double* best_right_leaf_value,
  // for leaf splits information update
  int* smaller_leaf_cuda_leaf_index_pointer, double* smaller_leaf_cuda_sum_of_gradients_pointer,
  double* smaller_leaf_cuda_sum_of_hessians_pointer, data_size_t* smaller_leaf_cuda_num_data_in_leaf_pointer,
  double* smaller_leaf_cuda_gain_pointer, double* smaller_leaf_cuda_leaf_value_pointer,
  const data_size_t** smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** smaller_leaf_cuda_hist_pointer_pointer,
  int* larger_leaf_cuda_leaf_index_pointer, double* larger_leaf_cuda_sum_of_gradients_pointer,
  double* larger_leaf_cuda_sum_of_hessians_pointer, data_size_t* larger_leaf_cuda_num_data_in_leaf_pointer,
  double* larger_leaf_cuda_gain_pointer, double* larger_leaf_cuda_leaf_value_pointer,
  const data_size_t** larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** larger_leaf_cuda_hist_pointer_pointer,
  const int* cuda_num_total_bin,
  hist_t* cuda_hist, hist_t** cuda_hist_pool,
  const data_size_t num_blocks, const data_size_t num_blocks_aligned) {
  __shared__ uint32_t block_to_left_offset[AGGREGATE_BLOCK_SIZE + 2 +
    (AGGREGATE_BLOCK_SIZE + 2) / NUM_BANKS_DATA_PARTITION];
  __shared__ uint32_t block_to_right_offset[AGGREGATE_BLOCK_SIZE + 2 +
    (AGGREGATE_BLOCK_SIZE + 2) / NUM_BANKS_DATA_PARTITION];
  const int leaf_index_ref = *leaf_index;
  const data_size_t num_data_in_leaf = cuda_leaf_num_data[leaf_index_ref];
  const unsigned int threadIdx_x = threadIdx.x;
  const unsigned int conflict_free_threadIdx_x = CONFLICT_FREE_INDEX(threadIdx_x);
  const unsigned int conflict_free_threadIdx_x_plus_1 = CONFLICT_FREE_INDEX(threadIdx_x + 1);
  if (threadIdx_x < static_cast<unsigned int>(num_blocks)) {
    block_to_left_offset[conflict_free_threadIdx_x] = block_to_left_offset_buffer[threadIdx_x + 1];
    block_to_right_offset[conflict_free_threadIdx_x] = block_to_right_offset_buffer[threadIdx_x + 1];
  } else {
    block_to_left_offset[conflict_free_threadIdx_x] = 0;
    block_to_right_offset[conflict_free_threadIdx_x] = 0;
  }
  __syncthreads();
  PrefixSum(block_to_left_offset, num_blocks_aligned);
  PrefixSum(block_to_right_offset, num_blocks_aligned);
  __syncthreads();
  const uint32_t to_left_total_count = block_to_left_offset[CONFLICT_FREE_INDEX(num_blocks_aligned)];
  if (threadIdx_x < static_cast<unsigned int>(num_blocks)) {
    block_to_left_offset_buffer[threadIdx_x + 1] = block_to_left_offset[conflict_free_threadIdx_x_plus_1];
    block_to_right_offset_buffer[threadIdx_x + 1] = block_to_right_offset[conflict_free_threadIdx_x_plus_1] + to_left_total_count;
  }
  if (threadIdx_x == 0) {
    block_to_right_offset_buffer[0] = to_left_total_count;
  }
  __syncthreads();
  if (blockIdx.x == 0 && threadIdx.x == 0) {
    ++(*cuda_cur_num_leaves);
    const int cur_max_leaf_index = (*cuda_cur_num_leaves) - 1;
    const data_size_t old_leaf_data_end = cuda_leaf_data_end[leaf_index_ref];
    cuda_leaf_data_end[leaf_index_ref] = cuda_leaf_data_start[leaf_index_ref] + static_cast<data_size_t>(to_left_total_count);
    cuda_leaf_num_data[leaf_index_ref] = static_cast<data_size_t>(to_left_total_count);
    cuda_leaf_data_start[cur_max_leaf_index] = cuda_leaf_data_end[leaf_index_ref];
    cuda_leaf_data_end[cur_max_leaf_index] = old_leaf_data_end;
    cuda_leaf_num_data[cur_max_leaf_index] = num_data_in_leaf - static_cast<data_size_t>(to_left_total_count);
  }
}

__global__ void SplitTreeStructureKernel(const int* leaf_index, data_size_t* block_to_left_offset_buffer,
  data_size_t* block_to_right_offset_buffer, data_size_t* cuda_leaf_data_start,
  data_size_t* cuda_leaf_data_end, data_size_t* cuda_leaf_num_data, const data_size_t* cuda_data_indices,
  int* cuda_cur_num_leaves,
  const int* best_split_feature, const uint32_t* best_split_threshold,
  const uint8_t* best_split_default_left, const double* best_split_gain,
  const double* best_left_sum_gradients, const double* best_left_sum_hessians, const data_size_t* best_left_count,
  const double* best_left_gain, const double* best_left_leaf_value,
  const double* best_right_sum_gradients, const double* best_right_sum_hessians, const data_size_t* best_right_count,
  const double* best_right_gain, const double* best_right_leaf_value, uint8_t* best_split_found,
  // for leaf splits information update
  int* smaller_leaf_cuda_leaf_index_pointer, double* smaller_leaf_cuda_sum_of_gradients_pointer,
  double* smaller_leaf_cuda_sum_of_hessians_pointer, data_size_t* smaller_leaf_cuda_num_data_in_leaf_pointer,
  double* smaller_leaf_cuda_gain_pointer, double* smaller_leaf_cuda_leaf_value_pointer,
  const data_size_t** smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** smaller_leaf_cuda_hist_pointer_pointer,
  int* larger_leaf_cuda_leaf_index_pointer, double* larger_leaf_cuda_sum_of_gradients_pointer,
  double* larger_leaf_cuda_sum_of_hessians_pointer, data_size_t* larger_leaf_cuda_num_data_in_leaf_pointer,
  double* larger_leaf_cuda_gain_pointer, double* larger_leaf_cuda_leaf_value_pointer,
  const data_size_t** larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** larger_leaf_cuda_hist_pointer_pointer,
  const int* cuda_num_total_bin,
  hist_t* cuda_hist, hist_t** cuda_hist_pool, const int split_indices_block_size_data_partition,

  int* tree_split_leaf_index, int* tree_inner_feature_index, uint32_t* tree_threshold,
  double* tree_left_output, double* tree_right_output, data_size_t* tree_left_count, data_size_t* tree_right_count,
  double* tree_left_sum_hessian, double* tree_right_sum_hessian, double* tree_gain, uint8_t* tree_default_left,
  double* data_partition_leaf_output,
  int* cuda_split_info_buffer) {
  const int leaf_index_ref = *leaf_index;
  const int cur_max_leaf_index = (*cuda_cur_num_leaves) - 1;
  const unsigned int to_left_total_cnt = cuda_leaf_num_data[leaf_index_ref];
  const int cuda_num_total_bin_ref = *cuda_num_total_bin;
  double* cuda_split_info_buffer_for_hessians = reinterpret_cast<double*>(cuda_split_info_buffer + 8);
  const unsigned int global_thread_index = blockIdx.x * blockDim.x + threadIdx.x;
  if (global_thread_index == 0) {
    tree_split_leaf_index[cur_max_leaf_index - 1] = leaf_index_ref;
  } else if (global_thread_index == 1) {
    tree_inner_feature_index[cur_max_leaf_index - 1] = best_split_feature[leaf_index_ref];
  } else if (global_thread_index == 2) {
    tree_threshold[cur_max_leaf_index - 1] = best_split_threshold[leaf_index_ref];
  } else if (global_thread_index == 3) {
    tree_left_output[cur_max_leaf_index - 1] = best_left_leaf_value[leaf_index_ref];
  } else if (global_thread_index == 4) {
    tree_right_output[cur_max_leaf_index - 1] = best_right_leaf_value[leaf_index_ref];
  } else if (global_thread_index == 5) {
    tree_left_count[cur_max_leaf_index - 1] = best_left_count[leaf_index_ref];
  } else if (global_thread_index == 6) {
    tree_right_count[cur_max_leaf_index - 1] = best_right_count[leaf_index_ref];
  } else if (global_thread_index == 7) {
    tree_left_sum_hessian[cur_max_leaf_index - 1] = best_left_sum_hessians[leaf_index_ref];
  } else if (global_thread_index == 8) {
    tree_right_sum_hessian[cur_max_leaf_index - 1] = best_right_sum_hessians[leaf_index_ref];
  } else if (global_thread_index == 9) {
    tree_gain[cur_max_leaf_index - 1] = best_split_gain[leaf_index_ref];
  } else if (global_thread_index == 10) {
    tree_default_left[cur_max_leaf_index - 1] = best_split_default_left[leaf_index_ref];
  } else if (global_thread_index == 11) {
    data_partition_leaf_output[leaf_index_ref] = best_left_leaf_value[leaf_index_ref];
  } else if (global_thread_index == 12) {
    data_partition_leaf_output[cur_max_leaf_index] = best_right_leaf_value[leaf_index_ref];
  } else if (global_thread_index == 13) {
    cuda_split_info_buffer[0] = leaf_index_ref;
  } else if (global_thread_index == 14) {
    cuda_split_info_buffer[1] = cuda_leaf_num_data[leaf_index_ref];
  } else if (global_thread_index == 15) {
    cuda_split_info_buffer[2] = cuda_leaf_data_start[leaf_index_ref];
  } else if (global_thread_index == 16) {
    cuda_split_info_buffer[3] = cur_max_leaf_index;
  } else if (global_thread_index == 17) {
    cuda_split_info_buffer[4] = cuda_leaf_num_data[cur_max_leaf_index];
  } else if (global_thread_index == 18) {
    cuda_split_info_buffer[5] = cuda_leaf_data_start[cur_max_leaf_index];
  } else if (global_thread_index == 19) {
    cuda_split_info_buffer_for_hessians[0] = best_left_sum_hessians[leaf_index_ref];
  } else if (global_thread_index == 20) {
    cuda_split_info_buffer_for_hessians[1] = best_right_sum_hessians[leaf_index_ref];
  } else if (global_thread_index == 21) {
    best_split_found[leaf_index_ref] = 0;
  } else if (global_thread_index == 22) {
    best_split_found[cur_max_leaf_index] = 0;
  }

  if (cuda_leaf_num_data[leaf_index_ref] < cuda_leaf_num_data[cur_max_leaf_index]) {
    if (global_thread_index == 0) {
      hist_t* parent_hist_ptr = cuda_hist_pool[leaf_index_ref];
      cuda_hist_pool[cur_max_leaf_index] = parent_hist_ptr;
      cuda_hist_pool[leaf_index_ref] = cuda_hist + 2 * cur_max_leaf_index * cuda_num_total_bin_ref;
      *smaller_leaf_cuda_hist_pointer_pointer = cuda_hist_pool[leaf_index_ref];
      *larger_leaf_cuda_hist_pointer_pointer = cuda_hist_pool[cur_max_leaf_index];
    } else if (global_thread_index == 1) {
      *smaller_leaf_cuda_sum_of_gradients_pointer = best_left_sum_gradients[leaf_index_ref];
    } else if (global_thread_index == 2) {
      *smaller_leaf_cuda_sum_of_hessians_pointer = best_left_sum_hessians[leaf_index_ref];
    } else if (global_thread_index == 3) {
      *smaller_leaf_cuda_num_data_in_leaf_pointer = to_left_total_cnt;
    } else if (global_thread_index == 4) {
      *smaller_leaf_cuda_gain_pointer = best_left_gain[leaf_index_ref];
    } else if (global_thread_index == 5) {
      *smaller_leaf_cuda_leaf_value_pointer = best_left_leaf_value[leaf_index_ref];
    } else if (global_thread_index == 6) {
      *smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer = cuda_data_indices;
    } else if (global_thread_index == 7) {
      *larger_leaf_cuda_leaf_index_pointer = cur_max_leaf_index;
    } else if (global_thread_index == 8) {
      *larger_leaf_cuda_sum_of_gradients_pointer = best_right_sum_gradients[leaf_index_ref];
    } else if (global_thread_index == 9) {
      *larger_leaf_cuda_sum_of_hessians_pointer = best_right_sum_hessians[leaf_index_ref];
    } else if (global_thread_index == 10) {
      *larger_leaf_cuda_num_data_in_leaf_pointer = cuda_leaf_num_data[cur_max_leaf_index];
    } else if (global_thread_index == 11) {
      *larger_leaf_cuda_gain_pointer = best_right_gain[leaf_index_ref];
    } else if (global_thread_index == 12) {
      *larger_leaf_cuda_leaf_value_pointer = best_right_leaf_value[leaf_index_ref];
    } else if (global_thread_index == 13) {
      *larger_leaf_cuda_data_indices_in_leaf_pointer_pointer = cuda_data_indices + cuda_leaf_num_data[leaf_index_ref];
    } else if (global_thread_index == 14) {
      cuda_split_info_buffer[6] = leaf_index_ref;
    } else if (global_thread_index == 15) {
      cuda_split_info_buffer[7] = cur_max_leaf_index;
    } else if (global_thread_index == 16) {
      *smaller_leaf_cuda_leaf_index_pointer = leaf_index_ref;
    }
  } else {
    if (global_thread_index == 0) {
      *larger_leaf_cuda_leaf_index_pointer = leaf_index_ref;
    } else if (global_thread_index == 1) {
      *larger_leaf_cuda_sum_of_gradients_pointer = best_left_sum_gradients[leaf_index_ref];
    } else if (global_thread_index == 2) {
      *larger_leaf_cuda_sum_of_hessians_pointer = best_left_sum_hessians[leaf_index_ref];
    } else if (global_thread_index == 3) {
      *larger_leaf_cuda_num_data_in_leaf_pointer = to_left_total_cnt;
    } else if (global_thread_index == 4) {
      *larger_leaf_cuda_gain_pointer = best_left_gain[leaf_index_ref];
    } else if (global_thread_index == 5) {
      *larger_leaf_cuda_leaf_value_pointer = best_left_leaf_value[leaf_index_ref];
    } else if (global_thread_index == 6) {
      *larger_leaf_cuda_data_indices_in_leaf_pointer_pointer = cuda_data_indices;
    } else if (global_thread_index == 7) {
      *smaller_leaf_cuda_leaf_index_pointer = cur_max_leaf_index;
    } else if (global_thread_index == 8) {
      *smaller_leaf_cuda_sum_of_gradients_pointer = best_right_sum_gradients[leaf_index_ref];
    } else if (global_thread_index == 9) {
      *smaller_leaf_cuda_sum_of_hessians_pointer = best_right_sum_hessians[leaf_index_ref];
    } else if (global_thread_index == 10) {
      *smaller_leaf_cuda_num_data_in_leaf_pointer = cuda_leaf_num_data[cur_max_leaf_index];
    } else if (global_thread_index == 11) {
      *smaller_leaf_cuda_gain_pointer = best_right_gain[leaf_index_ref];
    } else if (global_thread_index == 12) {
      *smaller_leaf_cuda_leaf_value_pointer = best_right_leaf_value[leaf_index_ref];
    } else if (global_thread_index == 13) {
      *smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer = cuda_data_indices + cuda_leaf_num_data[leaf_index_ref];
    } else if (global_thread_index == 14) {
      cuda_hist_pool[cur_max_leaf_index] = cuda_hist + 2 * cur_max_leaf_index * cuda_num_total_bin_ref;
      *smaller_leaf_cuda_hist_pointer_pointer = cuda_hist_pool[cur_max_leaf_index];
    } else if (global_thread_index == 15) {
      *larger_leaf_cuda_hist_pointer_pointer = cuda_hist_pool[leaf_index_ref];
    } else if (global_thread_index == 16) {
      cuda_split_info_buffer[6] = cur_max_leaf_index;
    } else if (global_thread_index == 17) {
      cuda_split_info_buffer[7] = leaf_index_ref;
    }
  }
}

__global__ void SplitInnerKernel(const int* leaf_index, const int* cuda_cur_num_leaves,
  const data_size_t* cuda_leaf_data_start, const data_size_t* cuda_leaf_num_data,
  const data_size_t* cuda_data_indices, const uint8_t* split_to_left_bit_vector,
  const data_size_t* block_to_left_offset_buffer, const data_size_t* block_to_right_offset_buffer,
  data_size_t* out_data_indices_in_leaf, const int split_indices_block_size_data_partition) {
  //__shared__ uint8_t thread_split_to_left_bit_vector[SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION];
  __shared__ uint16_t thread_to_left_pos[SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 1 +
    (SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 2) / NUM_BANKS_DATA_PARTITION];
  __shared__ uint16_t thread_to_right_pos[SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION];
  uint8_t first_to_left = 0;
  uint8_t second_to_left = 0;
  const int leaf_index_ref = *leaf_index;
  const data_size_t leaf_num_data_offset = cuda_leaf_data_start[leaf_index_ref];
  const data_size_t num_data_in_leaf_ref = cuda_leaf_num_data[leaf_index_ref] + cuda_leaf_num_data[(*cuda_cur_num_leaves) - 1];
  const unsigned int threadIdx_x = threadIdx.x;
  const unsigned int blockDim_x = blockDim.x;
  const unsigned int conflict_free_threadIdx_x_plus_1 = CONFLICT_FREE_INDEX(threadIdx_x + 1);
  const unsigned int global_thread_index = blockIdx.x * blockDim_x * 2 + threadIdx_x;
  const data_size_t* cuda_data_indices_in_leaf = cuda_data_indices + leaf_num_data_offset;
  if (global_thread_index < num_data_in_leaf_ref) {
    const uint8_t bit = split_to_left_bit_vector[global_thread_index];
    first_to_left = bit;
    thread_to_left_pos[conflict_free_threadIdx_x_plus_1] = bit;
  } else {
    first_to_left = 0;
    thread_to_left_pos[conflict_free_threadIdx_x_plus_1] = 0;
  }
  const unsigned int conflict_free_threadIdx_x_plus_blockDim_x_plus_1 = CONFLICT_FREE_INDEX(threadIdx_x + blockDim_x + 1);
  const unsigned int global_thread_index_plus_blockDim_x = global_thread_index + blockDim_x;
  if (global_thread_index_plus_blockDim_x < num_data_in_leaf_ref) {
    const uint8_t bit = split_to_left_bit_vector[global_thread_index_plus_blockDim_x];
    second_to_left = bit;
    thread_to_left_pos[conflict_free_threadIdx_x_plus_blockDim_x_plus_1] = bit;
  } else {
    second_to_left = 0;
    thread_to_left_pos[conflict_free_threadIdx_x_plus_blockDim_x_plus_1] = 0;
  }
  __syncthreads();
  const uint32_t to_right_block_offset = block_to_right_offset_buffer[blockIdx.x];
  const uint32_t to_left_block_offset = block_to_left_offset_buffer[blockIdx.x];
  if (threadIdx_x == 0) {
    thread_to_left_pos[0] = 0;
    thread_to_right_pos[0] = 0;
  }
  __syncthreads();
  PrefixSum(thread_to_left_pos, split_indices_block_size_data_partition);
  __syncthreads();
  if (threadIdx_x > 0) {
    thread_to_right_pos[threadIdx_x] = (threadIdx_x - thread_to_left_pos[conflict_free_threadIdx_x_plus_1]);
  }
  thread_to_right_pos[threadIdx_x + blockDim_x] = (threadIdx_x + blockDim_x - thread_to_left_pos[conflict_free_threadIdx_x_plus_blockDim_x_plus_1]);
  __syncthreads();
  data_size_t* left_out_data_indices_in_leaf = out_data_indices_in_leaf + to_left_block_offset;
  data_size_t* right_out_data_indices_in_leaf = out_data_indices_in_leaf + to_right_block_offset;
  if (global_thread_index < num_data_in_leaf_ref) {
    if (first_to_left == 1) {
      left_out_data_indices_in_leaf[thread_to_left_pos[conflict_free_threadIdx_x_plus_1]] = cuda_data_indices_in_leaf[global_thread_index];
    } else {
      right_out_data_indices_in_leaf[thread_to_right_pos[threadIdx_x]] = cuda_data_indices_in_leaf[global_thread_index];
    }
  }
  if (global_thread_index_plus_blockDim_x < num_data_in_leaf_ref) {
    if (second_to_left == 1) {
      left_out_data_indices_in_leaf[thread_to_left_pos[conflict_free_threadIdx_x_plus_blockDim_x_plus_1]] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x];
    } else {
      right_out_data_indices_in_leaf[thread_to_right_pos[threadIdx_x + blockDim_x]] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x];
    }
  }
}

__global__ void SplitInnerKernel2(const int* leaf_index, const int* cuda_cur_num_leaves,
  const data_size_t* cuda_leaf_data_start, const data_size_t* cuda_leaf_num_data,
  const data_size_t* cuda_data_indices, const uint8_t* split_to_left_bit_vector,
  const data_size_t* block_to_left_offset_buffer, const data_size_t* block_to_right_offset_buffer,
  data_size_t* out_data_indices_in_leaf, const int split_indices_block_size_data_partition) {
  __shared__ uint16_t thread_to_left_pos[(SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION << 1) + 1 +
    ((SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION << 1) + 2) / NUM_BANKS_DATA_PARTITION];
  __shared__ uint16_t thread_to_right_pos[(SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION << 1)];
  const int leaf_index_ref = *leaf_index;
  const data_size_t leaf_num_data_offset = cuda_leaf_data_start[leaf_index_ref];
  const data_size_t num_data_in_leaf_ref = cuda_leaf_num_data[leaf_index_ref] + cuda_leaf_num_data[(*cuda_cur_num_leaves) - 1];
  const unsigned int threadIdx_x = threadIdx.x;
  const unsigned int blockDim_x = blockDim.x;
  const unsigned int conflict_free_threadIdx_x_plus_1 = CONFLICT_FREE_INDEX(threadIdx_x + 1);
  const unsigned int global_thread_index = blockIdx.x * blockDim_x * 2 + threadIdx_x;
  const data_size_t* cuda_data_indices_in_leaf = cuda_data_indices + leaf_num_data_offset;
  const uint32_t* split_to_left_bit_vector_uint32 = reinterpret_cast<const uint32_t*>(split_to_left_bit_vector);
  const uint32_t bit32_0 = split_to_left_bit_vector_uint32[global_thread_index];
  const uint8_t bit_0 = static_cast<uint8_t>(bit32_0 & 0xf);
  uint8_t bit_1 = static_cast<uint8_t>((bit32_0 >> 8) & 0xf);
  uint8_t bit_2 = static_cast<uint8_t>((bit32_0 >> 16) & 0xf);
  uint8_t bit_3 = static_cast<uint8_t>((bit32_0 >> 24) & 0xf);
  const uint8_t bit_1_acc = bit_1 + bit_0;
  const uint8_t bit_2_acc = bit_1_acc + bit_2;
  const uint8_t bit_3_acc = bit_2_acc + bit_3;
  thread_to_left_pos[conflict_free_threadIdx_x_plus_1] = bit_3_acc;
  const unsigned int conflict_free_threadIdx_x_plus_blockDim_x_plus_1 = CONFLICT_FREE_INDEX(threadIdx_x + blockDim_x + 1);
  const unsigned int global_thread_index_plus_blockDim_x = global_thread_index + blockDim_x;
  const uint32_t bit32_1 = split_to_left_bit_vector_uint32[global_thread_index_plus_blockDim_x];
  const uint8_t bit_4 = static_cast<uint8_t>(bit32_1 & 0xf);
  uint8_t bit_5 = static_cast<uint8_t>((bit32_1 >> 8) & 0xf);
  uint8_t bit_6 = static_cast<uint8_t>((bit32_1 >> 16) & 0xf);
  uint8_t bit_7 = static_cast<uint8_t>((bit32_1 >> 24) & 0xf);
  const uint8_t bit_5_acc = bit_4 + bit_5;
  const uint8_t bit_6_acc = bit_5_acc + bit_6;
  const uint8_t bit_7_acc = bit_6_acc + bit_7;
  thread_to_left_pos[conflict_free_threadIdx_x_plus_blockDim_x_plus_1] = bit_7_acc;
  __syncthreads();
  const uint32_t to_right_block_offset = block_to_right_offset_buffer[blockIdx.x];
  const uint32_t to_left_block_offset = block_to_left_offset_buffer[blockIdx.x];
  if (threadIdx_x == 0) {
    thread_to_left_pos[0] = 0;
    thread_to_right_pos[0] = 0;
  }
  __syncthreads();
  PrefixSum(thread_to_left_pos, (split_indices_block_size_data_partition << 1));
  __syncthreads();
  if (threadIdx_x > 0) {
    thread_to_right_pos[threadIdx_x] = ((threadIdx_x * 4) - thread_to_left_pos[conflict_free_threadIdx_x_plus_1]);
  }
  thread_to_right_pos[threadIdx_x + blockDim_x] = (((threadIdx_x + blockDim_x) * 4) - thread_to_left_pos[conflict_free_threadIdx_x_plus_blockDim_x_plus_1]);
  __syncthreads();
  data_size_t* left_out_data_indices_in_leaf = out_data_indices_in_leaf + to_left_block_offset;
  data_size_t* right_out_data_indices_in_leaf = out_data_indices_in_leaf + to_right_block_offset;
  const data_size_t global_thread_index_base = global_thread_index * 4;
  const data_size_t global_thread_index_plus_blockDim_x_base = global_thread_index_plus_blockDim_x * 4;
  const uint16_t to_left_pos_offset_0 = thread_to_left_pos[conflict_free_threadIdx_x_plus_1];
  const uint16_t to_right_pos_offset_0 = thread_to_right_pos[threadIdx_x];
  const uint16_t to_left_pos_offset_1 = thread_to_left_pos[conflict_free_threadIdx_x_plus_blockDim_x_plus_1];
  const uint16_t to_right_pos_offset_1 = thread_to_right_pos[threadIdx_x + blockDim_x];
  if (global_thread_index_base < num_data_in_leaf_ref) {
    if (bit_0 == 1) {
      left_out_data_indices_in_leaf[to_left_pos_offset_0] = cuda_data_indices_in_leaf[global_thread_index_base];
    } else {
      right_out_data_indices_in_leaf[to_right_pos_offset_0] = cuda_data_indices_in_leaf[global_thread_index_base];
    }
  }
  if (global_thread_index_base + 1 < num_data_in_leaf_ref) {
    if (bit_1 == 1) {
      left_out_data_indices_in_leaf[to_left_pos_offset_0 + bit_0] = cuda_data_indices_in_leaf[global_thread_index_base + 1];
    } else {
      right_out_data_indices_in_leaf[to_right_pos_offset_0 + 1 - bit_0] = cuda_data_indices_in_leaf[global_thread_index_base + 1];
    }
  }
  if (global_thread_index_base + 2 < num_data_in_leaf_ref) {
    if (bit_2 == 1) {
      left_out_data_indices_in_leaf[to_left_pos_offset_0 + bit_1_acc] = cuda_data_indices_in_leaf[global_thread_index_base + 2];
    } else {
      right_out_data_indices_in_leaf[to_right_pos_offset_0 + 2 - bit_1_acc] = cuda_data_indices_in_leaf[global_thread_index_base + 2];
    }
  }
  if (global_thread_index_base + 3 < num_data_in_leaf_ref) {
    if (bit_3 == 1) {
      left_out_data_indices_in_leaf[to_left_pos_offset_0 + bit_2_acc] = cuda_data_indices_in_leaf[global_thread_index_base + 3];
    } else {
      right_out_data_indices_in_leaf[to_right_pos_offset_0 + 3 - bit_2_acc] = cuda_data_indices_in_leaf[global_thread_index_base + 3];
    }
  }
  if (global_thread_index_plus_blockDim_x_base < num_data_in_leaf_ref) {
    if (bit_4 == 1) {
      left_out_data_indices_in_leaf[to_left_pos_offset_1] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x_base];
    } else {
      right_out_data_indices_in_leaf[to_right_pos_offset_1] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x_base];
    }
  }
  if (global_thread_index_plus_blockDim_x_base + 1 < num_data_in_leaf_ref) {
    if (bit_5 == 1) {
      left_out_data_indices_in_leaf[to_left_pos_offset_1 + bit_4] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x_base + 1];
    } else {
      right_out_data_indices_in_leaf[to_right_pos_offset_1 + 1 - bit_4] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x_base + 1];
    }
  }
  if (global_thread_index_plus_blockDim_x_base + 2 < num_data_in_leaf_ref) {
    if (bit_6 == 1) {
      left_out_data_indices_in_leaf[to_left_pos_offset_1 + bit_5_acc] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x_base + 2];
    } else {
      right_out_data_indices_in_leaf[to_right_pos_offset_1 + 2 - bit_5_acc] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x_base + 2];
    }
  }
  if (global_thread_index_plus_blockDim_x_base + 3 < num_data_in_leaf_ref) {
    if (bit_7 == 1) {
      left_out_data_indices_in_leaf[to_left_pos_offset_1 + bit_6_acc] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x_base + 3];
    } else {
      right_out_data_indices_in_leaf[to_right_pos_offset_1 + 3 - bit_6_acc] = cuda_data_indices_in_leaf[global_thread_index_plus_blockDim_x_base + 3];
    }
  }
}

__global__ void CopyDataIndicesKernel(
  const data_size_t num_data_in_leaf,
  const data_size_t* out_data_indices_in_leaf,
  data_size_t* cuda_data_indices) {
  const unsigned int threadIdx_x = threadIdx.x;
  const unsigned int global_thread_index = blockIdx.x * blockDim.x + threadIdx_x;
  if (global_thread_index < num_data_in_leaf) {
    cuda_data_indices[global_thread_index] = out_data_indices_in_leaf[global_thread_index];
  }
}

void CUDADataPartition::LaunchSplitInnerKernel(const int* leaf_index, const data_size_t num_data_in_leaf,
  const int* best_split_feature, const uint32_t* best_split_threshold,
  const uint8_t* best_split_default_left, const double* best_split_gain,
  const double* best_left_sum_gradients, const double* best_left_sum_hessians, const data_size_t* best_left_count,
  const double* best_left_gain, const double* best_left_leaf_value,
  const double* best_right_sum_gradients, const double* best_right_sum_hessians, const data_size_t* best_right_count,
  const double* best_right_gain, const double* best_right_leaf_value, uint8_t* best_split_found,
  // for leaf splits information update
  int* smaller_leaf_cuda_leaf_index_pointer, double* smaller_leaf_cuda_sum_of_gradients_pointer,
  double* smaller_leaf_cuda_sum_of_hessians_pointer, data_size_t* smaller_leaf_cuda_num_data_in_leaf_pointer,
  double* smaller_leaf_cuda_gain_pointer, double* smaller_leaf_cuda_leaf_value_pointer,
  const data_size_t** smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** smaller_leaf_cuda_hist_pointer_pointer,
  int* larger_leaf_cuda_leaf_index_pointer, double* larger_leaf_cuda_sum_of_gradients_pointer,
  double* larger_leaf_cuda_sum_of_hessians_pointer, data_size_t* larger_leaf_cuda_num_data_in_leaf_pointer,
  double* larger_leaf_cuda_gain_pointer, double* larger_leaf_cuda_leaf_value_pointer,
  const data_size_t** larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** larger_leaf_cuda_hist_pointer_pointer,
  std::vector<data_size_t>* cpu_leaf_num_data, std::vector<data_size_t>* cpu_leaf_data_start,
  std::vector<double>* cpu_leaf_sum_hessians,
  int* smaller_leaf_index, int* larger_leaf_index, const int cpu_leaf_index) {
  const int min_num_blocks = num_data_in_leaf <= 100 ? 1 : 80;
  const int num_blocks = std::max(min_num_blocks, (num_data_in_leaf + SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION - 1) / SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION);
  int split_indices_block_size_data_partition = (num_data_in_leaf + num_blocks - 1) / num_blocks - 1;
  int split_indices_block_size_data_partition_aligned = 1;
  while (split_indices_block_size_data_partition > 0) {
    split_indices_block_size_data_partition_aligned <<= 1;
    split_indices_block_size_data_partition >>= 1;
  }
  const int num_blocks_final = (num_data_in_leaf + split_indices_block_size_data_partition_aligned - 1) / split_indices_block_size_data_partition_aligned;
  int num_blocks_final_ref = num_blocks_final - 1;
  int num_blocks_final_aligned = 1;
  while (num_blocks_final_ref > 0) {
    num_blocks_final_aligned <<= 1;
    num_blocks_final_ref >>= 1;
  }
  global_timer.Start("CUDADataPartition::AggregateBlockOffsetKernel");

  if (num_blocks_final > AGGREGATE_BLOCK_SIZE) {
    AggregateBlockOffsetKernel2<<<1, AGGREGATE_BLOCK_SIZE, 0, cuda_streams_[0]>>>(leaf_index, cuda_block_data_to_left_offset_,
      cuda_block_data_to_right_offset_, cuda_leaf_data_start_, cuda_leaf_data_end_,
      cuda_leaf_num_data_, cuda_data_indices_,
      cuda_cur_num_leaves_,
      best_split_feature, best_split_threshold, best_split_default_left, best_split_gain,
      best_left_sum_gradients, best_left_sum_hessians, best_left_count,
      best_left_gain, best_left_leaf_value,
      best_right_sum_gradients, best_right_sum_hessians, best_right_count,
      best_right_gain, best_right_leaf_value,

      smaller_leaf_cuda_leaf_index_pointer, smaller_leaf_cuda_sum_of_gradients_pointer,
      smaller_leaf_cuda_sum_of_hessians_pointer, smaller_leaf_cuda_num_data_in_leaf_pointer,
      smaller_leaf_cuda_gain_pointer, smaller_leaf_cuda_leaf_value_pointer,
      smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
      smaller_leaf_cuda_hist_pointer_pointer,
      larger_leaf_cuda_leaf_index_pointer, larger_leaf_cuda_sum_of_gradients_pointer,
      larger_leaf_cuda_sum_of_hessians_pointer, larger_leaf_cuda_num_data_in_leaf_pointer,
      larger_leaf_cuda_gain_pointer, larger_leaf_cuda_leaf_value_pointer,
      larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
      larger_leaf_cuda_hist_pointer_pointer,
      cuda_num_total_bin_,
      cuda_hist_,
      cuda_hist_pool_,
      num_blocks_final);
  } else {
    AggregateBlockOffsetKernel3<<<1, num_blocks_final_aligned, 0, cuda_streams_[0]>>>(leaf_index, cuda_block_data_to_left_offset_,
      cuda_block_data_to_right_offset_, cuda_leaf_data_start_, cuda_leaf_data_end_,
      cuda_leaf_num_data_, cuda_data_indices_,
      cuda_cur_num_leaves_,
      best_split_feature, best_split_threshold, best_split_default_left, best_split_gain,
      best_left_sum_gradients, best_left_sum_hessians, best_left_count,
      best_left_gain, best_left_leaf_value,
      best_right_sum_gradients, best_right_sum_hessians, best_right_count,
      best_right_gain, best_right_leaf_value,

      smaller_leaf_cuda_leaf_index_pointer, smaller_leaf_cuda_sum_of_gradients_pointer,
      smaller_leaf_cuda_sum_of_hessians_pointer, smaller_leaf_cuda_num_data_in_leaf_pointer,
      smaller_leaf_cuda_gain_pointer, smaller_leaf_cuda_leaf_value_pointer,
      smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
      smaller_leaf_cuda_hist_pointer_pointer,
      larger_leaf_cuda_leaf_index_pointer, larger_leaf_cuda_sum_of_gradients_pointer,
      larger_leaf_cuda_sum_of_hessians_pointer, larger_leaf_cuda_num_data_in_leaf_pointer,
      larger_leaf_cuda_gain_pointer, larger_leaf_cuda_leaf_value_pointer,
      larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
      larger_leaf_cuda_hist_pointer_pointer,
      cuda_num_total_bin_,
      cuda_hist_,
      cuda_hist_pool_,
      num_blocks_final, num_blocks_final_aligned);
  }
  SynchronizeCUDADevice();
  global_timer.Stop("CUDADataPartition::AggregateBlockOffsetKernel");
  global_timer.Start("CUDADataPartition::SplitInnerKernel");

  SplitInnerKernel<<<num_blocks_final, split_indices_block_size_data_partition_aligned / 2, 0, cuda_streams_[1]>>>(
    leaf_index, cuda_cur_num_leaves_, cuda_leaf_data_start_, cuda_leaf_num_data_, cuda_data_indices_, cuda_data_to_left_,
    cuda_block_data_to_left_offset_, cuda_block_data_to_right_offset_,
    cuda_out_data_indices_in_leaf_, split_indices_block_size_data_partition_aligned);
  //SynchronizeCUDADevice();
  global_timer.Stop("CUDADataPartition::SplitInnerKernel");

  global_timer.Start("CUDADataPartition::SplitTreeStructureKernel");
  SplitTreeStructureKernel<<<4, 6, 0, cuda_streams_[0]>>>(leaf_index, cuda_block_data_to_left_offset_,
    cuda_block_data_to_right_offset_, cuda_leaf_data_start_, cuda_leaf_data_end_,
    cuda_leaf_num_data_, cuda_out_data_indices_in_leaf_,
    cuda_cur_num_leaves_,
    best_split_feature, best_split_threshold, best_split_default_left, best_split_gain,
    best_left_sum_gradients, best_left_sum_hessians, best_left_count,
    best_left_gain, best_left_leaf_value,
    best_right_sum_gradients, best_right_sum_hessians, best_right_count,
    best_right_gain, best_right_leaf_value, best_split_found,

    smaller_leaf_cuda_leaf_index_pointer, smaller_leaf_cuda_sum_of_gradients_pointer,
    smaller_leaf_cuda_sum_of_hessians_pointer, smaller_leaf_cuda_num_data_in_leaf_pointer,
    smaller_leaf_cuda_gain_pointer, smaller_leaf_cuda_leaf_value_pointer,
    smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
    smaller_leaf_cuda_hist_pointer_pointer,
    larger_leaf_cuda_leaf_index_pointer, larger_leaf_cuda_sum_of_gradients_pointer,
    larger_leaf_cuda_sum_of_hessians_pointer, larger_leaf_cuda_num_data_in_leaf_pointer,
    larger_leaf_cuda_gain_pointer, larger_leaf_cuda_leaf_value_pointer,
    larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
    larger_leaf_cuda_hist_pointer_pointer,
    cuda_num_total_bin_,
    cuda_hist_,
    cuda_hist_pool_, split_indices_block_size_data_partition_aligned,

    tree_split_leaf_index_, tree_inner_feature_index_, tree_threshold_,
    tree_left_output_, tree_right_output_, tree_left_count_, tree_right_count_,
    tree_left_sum_hessian_, tree_right_sum_hessian_, tree_gain_, tree_default_left_,
    data_partition_leaf_output_, cuda_split_info_buffer_);
  global_timer.Stop("CUDADataPartition::SplitTreeStructureKernel");
  std::vector<int> cpu_split_info_buffer(12);
  const double* cpu_sum_hessians_info = reinterpret_cast<const double*>(cpu_split_info_buffer.data() + 8);
  global_timer.Start("CUDADataPartition::CopyFromCUDADeviceToHostAsync");
  CopyFromCUDADeviceToHostAsync<int>(cpu_split_info_buffer.data(), cuda_split_info_buffer_, 12, cuda_streams_[0]);
  global_timer.Stop("CUDADataPartition::CopyFromCUDADeviceToHostAsync");
  SynchronizeCUDADevice();
  const data_size_t left_leaf_num_data = cpu_split_info_buffer[1];
  const data_size_t left_leaf_data_start = cpu_split_info_buffer[2];
  const data_size_t right_leaf_num_data = cpu_split_info_buffer[4];
  global_timer.Start("CUDADataPartition::CopyDataIndicesKernel");
  CopyDataIndicesKernel<<<num_blocks_final, split_indices_block_size_data_partition_aligned, 0, cuda_streams_[2]>>>(
    left_leaf_num_data + right_leaf_num_data, cuda_out_data_indices_in_leaf_, cuda_data_indices_ + left_leaf_data_start);
  global_timer.Stop("CUDADataPartition::CopyDataIndicesKernel");
  const int left_leaf_index = cpu_split_info_buffer[0];
  const int right_leaf_index = cpu_split_info_buffer[3];
  const data_size_t right_leaf_data_start = cpu_split_info_buffer[5];
  (*cpu_leaf_num_data)[left_leaf_index] = left_leaf_num_data;
  (*cpu_leaf_data_start)[left_leaf_index] = left_leaf_data_start;
  (*cpu_leaf_num_data)[right_leaf_index] = right_leaf_num_data;
  (*cpu_leaf_data_start)[right_leaf_index] = right_leaf_data_start;
  (*cpu_leaf_sum_hessians)[left_leaf_index] = cpu_sum_hessians_info[0];
  (*cpu_leaf_sum_hessians)[right_leaf_index] = cpu_sum_hessians_info[1];
  *smaller_leaf_index = cpu_split_info_buffer[6];
  *larger_leaf_index = cpu_split_info_buffer[7];
}

void CUDADataPartition::LaunchSplitInnerKernel2(const int* leaf_index, const data_size_t num_data_in_leaf,
  const int* best_split_feature, const uint32_t* best_split_threshold,
  const uint8_t* best_split_default_left, const double* best_split_gain,
  const double* best_left_sum_gradients, const double* best_left_sum_hessians, const data_size_t* best_left_count,
  const double* best_left_gain, const double* best_left_leaf_value,
  const double* best_right_sum_gradients, const double* best_right_sum_hessians, const data_size_t* best_right_count,
  const double* best_right_gain, const double* best_right_leaf_value, uint8_t* best_split_found,
  // for leaf splits information update
  int* smaller_leaf_cuda_leaf_index_pointer, double* smaller_leaf_cuda_sum_of_gradients_pointer,
  double* smaller_leaf_cuda_sum_of_hessians_pointer, data_size_t* smaller_leaf_cuda_num_data_in_leaf_pointer,
  double* smaller_leaf_cuda_gain_pointer, double* smaller_leaf_cuda_leaf_value_pointer,
  const data_size_t** smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** smaller_leaf_cuda_hist_pointer_pointer,
  int* larger_leaf_cuda_leaf_index_pointer, double* larger_leaf_cuda_sum_of_gradients_pointer,
  double* larger_leaf_cuda_sum_of_hessians_pointer, data_size_t* larger_leaf_cuda_num_data_in_leaf_pointer,
  double* larger_leaf_cuda_gain_pointer, double* larger_leaf_cuda_leaf_value_pointer,
  const data_size_t** larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
  hist_t** larger_leaf_cuda_hist_pointer_pointer,
  std::vector<data_size_t>* cpu_leaf_num_data, std::vector<data_size_t>* cpu_leaf_data_start,
  std::vector<double>* cpu_leaf_sum_hessians,
  int* smaller_leaf_index, int* larger_leaf_index, const int cpu_leaf_index) {
  int block_dim = 0;
  int grid_dim = 0;
  CalcBlockDim(num_data_in_leaf, &grid_dim, &block_dim);
  int grid_dim_ref = grid_dim - 1;
  int grid_dim_aligned = 1;
  while (grid_dim_ref > 0) {
    grid_dim_aligned <<= 1;
    grid_dim_ref >>= 1;
  }
  global_timer.Start("CUDADataPartition::AggregateBlockOffsetKernel");

  if (grid_dim > AGGREGATE_BLOCK_SIZE) {
    AggregateBlockOffsetKernel2<<<1, AGGREGATE_BLOCK_SIZE, 0, cuda_streams_[0]>>>(leaf_index, cuda_block_data_to_left_offset_,
      cuda_block_data_to_right_offset_, cuda_leaf_data_start_, cuda_leaf_data_end_,
      cuda_leaf_num_data_, cuda_data_indices_,
      cuda_cur_num_leaves_,
      best_split_feature, best_split_threshold, best_split_default_left, best_split_gain,
      best_left_sum_gradients, best_left_sum_hessians, best_left_count,
      best_left_gain, best_left_leaf_value,
      best_right_sum_gradients, best_right_sum_hessians, best_right_count,
      best_right_gain, best_right_leaf_value,

      smaller_leaf_cuda_leaf_index_pointer, smaller_leaf_cuda_sum_of_gradients_pointer,
      smaller_leaf_cuda_sum_of_hessians_pointer, smaller_leaf_cuda_num_data_in_leaf_pointer,
      smaller_leaf_cuda_gain_pointer, smaller_leaf_cuda_leaf_value_pointer,
      smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
      smaller_leaf_cuda_hist_pointer_pointer,
      larger_leaf_cuda_leaf_index_pointer, larger_leaf_cuda_sum_of_gradients_pointer,
      larger_leaf_cuda_sum_of_hessians_pointer, larger_leaf_cuda_num_data_in_leaf_pointer,
      larger_leaf_cuda_gain_pointer, larger_leaf_cuda_leaf_value_pointer,
      larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
      larger_leaf_cuda_hist_pointer_pointer,
      cuda_num_total_bin_,
      cuda_hist_,
      cuda_hist_pool_,
      grid_dim);
  } else {
    AggregateBlockOffsetKernel3<<<1, grid_dim_aligned, 0, cuda_streams_[0]>>>(leaf_index, cuda_block_data_to_left_offset_,
      cuda_block_data_to_right_offset_, cuda_leaf_data_start_, cuda_leaf_data_end_,
      cuda_leaf_num_data_, cuda_data_indices_,
      cuda_cur_num_leaves_,
      best_split_feature, best_split_threshold, best_split_default_left, best_split_gain,
      best_left_sum_gradients, best_left_sum_hessians, best_left_count,
      best_left_gain, best_left_leaf_value,
      best_right_sum_gradients, best_right_sum_hessians, best_right_count,
      best_right_gain, best_right_leaf_value,

      smaller_leaf_cuda_leaf_index_pointer, smaller_leaf_cuda_sum_of_gradients_pointer,
      smaller_leaf_cuda_sum_of_hessians_pointer, smaller_leaf_cuda_num_data_in_leaf_pointer,
      smaller_leaf_cuda_gain_pointer, smaller_leaf_cuda_leaf_value_pointer,
      smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
      smaller_leaf_cuda_hist_pointer_pointer,
      larger_leaf_cuda_leaf_index_pointer, larger_leaf_cuda_sum_of_gradients_pointer,
      larger_leaf_cuda_sum_of_hessians_pointer, larger_leaf_cuda_num_data_in_leaf_pointer,
      larger_leaf_cuda_gain_pointer, larger_leaf_cuda_leaf_value_pointer,
      larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
      larger_leaf_cuda_hist_pointer_pointer,
      cuda_num_total_bin_,
      cuda_hist_,
      cuda_hist_pool_,
      grid_dim, grid_dim_aligned);
  }
  SynchronizeCUDADevice();
  global_timer.Stop("CUDADataPartition::AggregateBlockOffsetKernel");
  global_timer.Start("CUDADataPartition::SplitInnerKernel");

  SplitInnerKernel2<<<grid_dim, block_dim, 0, cuda_streams_[1]>>>(
    leaf_index, cuda_cur_num_leaves_, cuda_leaf_data_start_, cuda_leaf_num_data_, cuda_data_indices_, cuda_data_to_left_,
    cuda_block_data_to_left_offset_, cuda_block_data_to_right_offset_,
    cuda_out_data_indices_in_leaf_, block_dim);
  //SynchronizeCUDADevice();
  global_timer.Stop("CUDADataPartition::SplitInnerKernel");

  global_timer.Start("CUDADataPartition::SplitTreeStructureKernel");
  SplitTreeStructureKernel<<<4, 6, 0, cuda_streams_[0]>>>(leaf_index, cuda_block_data_to_left_offset_,
    cuda_block_data_to_right_offset_, cuda_leaf_data_start_, cuda_leaf_data_end_,
    cuda_leaf_num_data_, cuda_out_data_indices_in_leaf_,
    cuda_cur_num_leaves_,
    best_split_feature, best_split_threshold, best_split_default_left, best_split_gain,
    best_left_sum_gradients, best_left_sum_hessians, best_left_count,
    best_left_gain, best_left_leaf_value,
    best_right_sum_gradients, best_right_sum_hessians, best_right_count,
    best_right_gain, best_right_leaf_value, best_split_found,

    smaller_leaf_cuda_leaf_index_pointer, smaller_leaf_cuda_sum_of_gradients_pointer,
    smaller_leaf_cuda_sum_of_hessians_pointer, smaller_leaf_cuda_num_data_in_leaf_pointer,
    smaller_leaf_cuda_gain_pointer, smaller_leaf_cuda_leaf_value_pointer,
    smaller_leaf_cuda_data_indices_in_leaf_pointer_pointer,
    smaller_leaf_cuda_hist_pointer_pointer,
    larger_leaf_cuda_leaf_index_pointer, larger_leaf_cuda_sum_of_gradients_pointer,
    larger_leaf_cuda_sum_of_hessians_pointer, larger_leaf_cuda_num_data_in_leaf_pointer,
    larger_leaf_cuda_gain_pointer, larger_leaf_cuda_leaf_value_pointer,
    larger_leaf_cuda_data_indices_in_leaf_pointer_pointer,
    larger_leaf_cuda_hist_pointer_pointer,
    cuda_num_total_bin_,
    cuda_hist_,
    cuda_hist_pool_, block_dim,

    tree_split_leaf_index_, tree_inner_feature_index_, tree_threshold_,
    tree_left_output_, tree_right_output_, tree_left_count_, tree_right_count_,
    tree_left_sum_hessian_, tree_right_sum_hessian_, tree_gain_, tree_default_left_,
    data_partition_leaf_output_, cuda_split_info_buffer_);
  //SynchronizeCUDADevice();
  global_timer.Stop("CUDADataPartition::SplitTreeStructureKernel");
  std::vector<int> cpu_split_info_buffer(12);
  const double* cpu_sum_hessians_info = reinterpret_cast<const double*>(cpu_split_info_buffer.data() + 8);
  global_timer.Start("CUDADataPartition::CopyFromCUDADeviceToHostAsync");
  CopyFromCUDADeviceToHostAsync<int>(cpu_split_info_buffer.data(), cuda_split_info_buffer_, 12, cuda_streams_[0]);
  global_timer.Stop("CUDADataPartition::CopyFromCUDADeviceToHostAsync");
  SynchronizeCUDADevice();
  const data_size_t left_leaf_num_data = cpu_split_info_buffer[1];
  const data_size_t left_leaf_data_start = cpu_split_info_buffer[2];
  const data_size_t right_leaf_num_data = cpu_split_info_buffer[4];
  global_timer.Start("CUDADataPartition::CopyDataIndicesKernel");
  int grid_dim_copy = 0;
  int block_dim_copy = 0;
  CalcBlockDimInCopy(num_data_in_leaf, &grid_dim_copy, &block_dim_copy);
  CopyDataIndicesKernel<<<grid_dim_copy, block_dim_copy, 0, cuda_streams_[2]>>>(
    left_leaf_num_data + right_leaf_num_data, cuda_out_data_indices_in_leaf_, cuda_data_indices_ + left_leaf_data_start);
  global_timer.Stop("CUDADataPartition::CopyDataIndicesKernel");
  const int left_leaf_index = cpu_split_info_buffer[0];
  const int right_leaf_index = cpu_split_info_buffer[3];
  const data_size_t right_leaf_data_start = cpu_split_info_buffer[5];
  (*cpu_leaf_num_data)[left_leaf_index] = left_leaf_num_data;
  (*cpu_leaf_data_start)[left_leaf_index] = left_leaf_data_start;
  (*cpu_leaf_num_data)[right_leaf_index] = right_leaf_num_data;
  (*cpu_leaf_data_start)[right_leaf_index] = right_leaf_data_start;
  (*cpu_leaf_sum_hessians)[left_leaf_index] = cpu_sum_hessians_info[0];
  (*cpu_leaf_sum_hessians)[right_leaf_index] = cpu_sum_hessians_info[1];
  *smaller_leaf_index = cpu_split_info_buffer[6];
  *larger_leaf_index = cpu_split_info_buffer[7];
}

__global__ void PrefixSumKernel(uint32_t* cuda_elements) {
  __shared__ uint32_t elements[SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION + 1];
  const unsigned int threadIdx_x = threadIdx.x;
  const unsigned int global_read_index = blockIdx.x * blockDim.x * 2 + threadIdx_x;
  elements[threadIdx_x] = cuda_elements[global_read_index];
  elements[threadIdx_x + blockDim.x] = cuda_elements[global_read_index + blockDim.x];
  __syncthreads();
  PrefixSum(elements, SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION);
  __syncthreads();
  cuda_elements[global_read_index] = elements[threadIdx_x];
  cuda_elements[global_read_index + blockDim.x] = elements[threadIdx_x + blockDim.x];
}

void CUDADataPartition::LaunchPrefixSumKernel(uint32_t* cuda_elements) {
  PrefixSumKernel<<<1, SPLIT_INDICES_BLOCK_SIZE_DATA_PARTITION / 2>>>(cuda_elements);
  SynchronizeCUDADevice();
}

__global__ void AddPredictionToScoreKernel(const double* data_partition_leaf_output,
  const data_size_t* num_data_in_leaf, const data_size_t* data_indices_in_leaf,
  const data_size_t* leaf_data_start, const double learning_rate, double* cuda_scores,
  const int* cuda_data_index_to_leaf_index, const data_size_t num_data) {
  const unsigned int threadIdx_x = threadIdx.x;
  const unsigned int blockIdx_x = blockIdx.x;
  const unsigned int blockDim_x = blockDim.x;
  //const data_size_t num_data = num_data_in_leaf[blockIdx_x];
  //const data_size_t* data_indices = data_indices_in_leaf + leaf_data_start[blockIdx_x];
  const int data_index = static_cast<int>(blockIdx_x * blockDim_x + threadIdx_x);
  //const double leaf_prediction_value = data_partition_leaf_output[blockIdx_x] * learning_rate;
  /*for (unsigned int offset = 0; offset < static_cast<unsigned int>(num_data); offset += blockDim_x) {
    const data_size_t inner_data_index = static_cast<data_size_t>(offset + threadIdx_x);
    if (inner_data_index < num_data) {
      const data_size_t data_index = data_indices[inner_data_index];
      cuda_scores[data_index] += leaf_prediction_value;
    }
  }*/
  if (data_index < num_data) {
    const int leaf_index = cuda_data_index_to_leaf_index[data_index];
    const double leaf_prediction_value = data_partition_leaf_output[leaf_index] * learning_rate;
    cuda_scores[data_index] += leaf_prediction_value;
  }
}

void CUDADataPartition::LaunchAddPredictionToScoreKernel(const double learning_rate, double* cuda_scores) {
  global_timer.Start("CUDADataPartition::AddPredictionToScoreKernel");
  //const int leaf_check_size = 10500000;
  //std::vector<int> cpu_leaf_predict(leaf_check_size);
  //std::vector<double> cpu_predict_value(leaf_check_size);
  //CopyFromCUDADeviceToHost<int>(cpu_leaf_predict.data(), cuda_data_index_to_leaf_index_, leaf_check_size);
  const int num_blocks = (num_data_ + FILL_INDICES_BLOCK_SIZE_DATA_PARTITION - 1) / FILL_INDICES_BLOCK_SIZE_DATA_PARTITION;
  AddPredictionToScoreKernel<<<num_blocks, FILL_INDICES_BLOCK_SIZE_DATA_PARTITION>>>(data_partition_leaf_output_,
    cuda_leaf_num_data_, cuda_data_indices_, cuda_leaf_data_start_, learning_rate, cuda_scores, cuda_data_index_to_leaf_index_, num_data_);
  //SynchronizeCUDADevice();
  //global_timer.Stop("CUDADataPartition::AddPredictionToScoreKernel");
  /*for (int i = 0; i < leaf_check_size; ++i) {
    Log::Warning("cpu_leaf_predict[%d] = %d", i, cpu_leaf_predict[i]);
  }*/
  //static int iter = 0;
  //if (iter == 0) {
  //  OutputToFile("cuda_data_partition.txt", cpu_leaf_predict);
  //}
  //++iter;
}

__global__ void CopyColWiseDataKernel(const uint8_t* row_wise_data,
  const data_size_t num_data, const int num_features,
  uint8_t* col_wise_data) {
  const data_size_t data_index = static_cast<data_size_t>(threadIdx.x + blockIdx.x * blockDim.x);
  if (data_index < num_data) {
    const data_size_t read_offset = data_index * num_features;
    for (int feature_index = 0; feature_index < num_features; ++feature_index) {
      const data_size_t write_pos = feature_index * num_data + data_index;
      col_wise_data[write_pos] = row_wise_data[read_offset + feature_index];
    }
  }
}

__global__ void CUDACheckKernel(const data_size_t** data_indices_in_leaf_ptr,
  const data_size_t num_data_in_leaf,
  const score_t* gradients,
  const score_t* hessians,
  double* gradients_sum_buffer,
  double* hessians_sum_buffer) {
  const data_size_t* data_indices_in_leaf = *data_indices_in_leaf_ptr;
  const data_size_t local_data_index = static_cast<data_size_t>(blockIdx.x * blockDim.x + threadIdx.x);
  __shared__ double local_gradients[1024];
  __shared__ double local_hessians[1024];
  if (local_data_index < num_data_in_leaf) {
    const data_size_t global_data_index = data_indices_in_leaf[local_data_index];
    local_gradients[threadIdx.x] = gradients[global_data_index];
    local_hessians[threadIdx.x] = hessians[global_data_index];
  } else {
    local_gradients[threadIdx.x] = 0.0f;
    local_hessians[threadIdx.x] = 0.0f;
  }
  __syncthreads();
  ReduceSum(local_gradients, 1024);
  __syncthreads();
  ReduceSum(local_hessians, 1024);
  __syncthreads();
  if (threadIdx.x == 0) {
    gradients_sum_buffer[blockIdx.x] = local_gradients[0];
    hessians_sum_buffer[blockIdx.x] = local_hessians[0];
  }
}

__global__ void CUDACheckKernel2(
  const int leaf_index,
  const data_size_t* num_data_expected,
  const double* sum_gradients_expected,
  const double* sum_hessians_expected,
  const double* gradients_sum_buffer,
  const double* hessians_sum_buffer,
  const int num_blocks) {
  double sum_gradients = 0.0f;
  double sum_hessians = 0.0f;
  for (int i = 0; i < num_blocks; ++i) {
    sum_gradients += gradients_sum_buffer[i];
    sum_hessians += hessians_sum_buffer[i];
  }
  if (fabs(sum_gradients - *sum_gradients_expected) >= 1.0f) {
    printf("error in leaf_index = %d\n", leaf_index);
    printf("num data expected = %d\n", *num_data_expected);
    printf("error sum_gradients: %f vs %f\n", sum_gradients, *sum_gradients_expected);
  }
  if (fabs(sum_hessians - *sum_hessians_expected) >= 1.0f) {
    printf("error in leaf_index = %d\n", leaf_index);
    printf("num data expected = %d\n", *num_data_expected);
    printf("error sum_hessians: %f vs %f\n", sum_hessians, *sum_hessians_expected);
  }
}

void CUDADataPartition::LaunchCUDACheckKernel(
  const int smaller_leaf_index,
  const int larger_leaf_index,
  const std::vector<data_size_t>& num_data_in_leaf,
  const CUDALeafSplits* smaller_leaf_splits,
  const CUDALeafSplits* larger_leaf_splits,
  const score_t* gradients,
  const score_t* hessians) {
  const data_size_t num_data_in_smaller_leaf = num_data_in_leaf[smaller_leaf_index];
  const int block_dim = 1024;
  const int smaller_num_blocks = (num_data_in_smaller_leaf + block_dim - 1) / block_dim;
  CUDACheckKernel<<<smaller_num_blocks, block_dim>>>(smaller_leaf_splits->cuda_data_indices_in_leaf(),
    num_data_in_smaller_leaf,
    gradients,
    hessians,
    cuda_gradients_sum_buffer_,
    cuda_hessians_sum_buffer_);
  CUDACheckKernel2<<<1, 1>>>(
    smaller_leaf_index,
    smaller_leaf_splits->cuda_num_data_in_leaf(),
    smaller_leaf_splits->cuda_sum_of_gradients(),
    smaller_leaf_splits->cuda_sum_of_hessians(),
    cuda_gradients_sum_buffer_,
    cuda_hessians_sum_buffer_,
    smaller_num_blocks);
  if (larger_leaf_index >= 0) {
    const data_size_t num_data_in_larger_leaf = num_data_in_leaf[larger_leaf_index];
    const int larger_num_blocks = (num_data_in_larger_leaf + block_dim - 1) / block_dim;
    CUDACheckKernel<<<larger_num_blocks, block_dim>>>(larger_leaf_splits->cuda_data_indices_in_leaf(),
      num_data_in_larger_leaf,
      gradients,
      hessians,
      cuda_gradients_sum_buffer_,
      cuda_hessians_sum_buffer_);
    CUDACheckKernel2<<<1, 1>>>(
      larger_leaf_index,
      larger_leaf_splits->cuda_num_data_in_leaf(),
      larger_leaf_splits->cuda_sum_of_gradients(),
      larger_leaf_splits->cuda_sum_of_hessians(),
      cuda_gradients_sum_buffer_,
      cuda_hessians_sum_buffer_,
      larger_num_blocks);
  }
}

}  // namespace LightGBM

#endif  // USE_CUDA
