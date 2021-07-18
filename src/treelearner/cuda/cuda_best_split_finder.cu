/*!
 * Copyright (c) 2021 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for
 * license information.
 */

#ifdef USE_CUDA

#include "cuda_best_split_finder.hpp"

namespace LightGBM {

#define K_MIN_SCORE (-1000000.0)

#define K_EPSILON (1e-15f)

#define CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(n) \
  ((n) + ((n) >> LOG_NUM_BANKS_DATA_PARTITION_BEST_SPLIT_FINDER)) \

__device__ void PrefixSumHist(hist_t* elements, unsigned int n) {
  unsigned int offset = 1;
  unsigned int threadIdx_x = threadIdx.x;
  const unsigned int conflict_free_n_minus_1 = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(n - 1);
  const hist_t last_element = elements[conflict_free_n_minus_1];
  __syncthreads();
  for (int d = (n >> 1); d > 0; d >>= 1) {
    if (threadIdx_x < d) {
      const unsigned int src_pos = offset * (2 * threadIdx_x + 1) - 1;
      const unsigned int dst_pos = offset * (2 * threadIdx_x + 2) - 1;
      elements[CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(dst_pos)] += elements[CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(src_pos)];
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
      const unsigned int dst_pos = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(offset * (2 * threadIdx_x + 2) - 1);
      const unsigned int src_pos = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(offset * (2 * threadIdx_x + 1) - 1);
      const hist_t src_val = elements[src_pos];
      elements[src_pos] = elements[dst_pos];
      elements[dst_pos] += src_val;
    }
    __syncthreads();
  }
  if (threadIdx_x == 0) {
    elements[CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(n)] = elements[conflict_free_n_minus_1] + last_element;
  }
  __syncthreads();
}

__device__ void PrefixSumHistCnt(data_size_t* elements, unsigned int n) {
  unsigned int offset = 1;
  unsigned int threadIdx_x = threadIdx.x;
  const unsigned int conflict_free_n_minus_1 = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(n - 1);
  const data_size_t last_element = elements[conflict_free_n_minus_1];
  __syncthreads();
  for (int d = (n >> 1); d > 0; d >>= 1) {
    if (threadIdx_x < d) {
      const unsigned int src_pos = offset * (2 * threadIdx_x + 1) - 1;
      const unsigned int dst_pos = offset * (2 * threadIdx_x + 2) - 1;
      elements[CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(dst_pos)] += elements[CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(src_pos)];
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
      const unsigned int dst_pos = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(offset * (2 * threadIdx_x + 2) - 1);
      const unsigned int src_pos = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(offset * (2 * threadIdx_x + 1) - 1);
      const data_size_t src_val = elements[src_pos];
      elements[src_pos] = elements[dst_pos];
      elements[dst_pos] += src_val;
    }
    __syncthreads();
  }
  if (threadIdx_x == 0) {
    elements[CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(n)] = elements[conflict_free_n_minus_1] + last_element;
  }
}

__device__ void ReduceBestGain(double* gain, hist_t* sum_gradients,
  hist_t* sum_hessians, /*data_size_t* num_data,*/ uint8_t* found,
  uint32_t* threshold_value) {
  const unsigned int tid = threadIdx.x;
  const unsigned int conflict_free_tid_plus_1 = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(tid + 1);
  for (unsigned int s = 1; s < MAX_NUM_BIN_IN_FEATURE; s *= 2) {
    if (tid % (2 * s) == 0 && (tid + s) < MAX_NUM_BIN_IN_FEATURE) {
      const uint32_t tid_s = tid + s;
      const uint32_t conflict_free_tid_s_plus_1 = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(tid_s + 1);
      if ((found[tid_s] && !found[tid]) || (found[tid_s] && found[tid] && gain[tid_s] > gain[tid])) {
        gain[tid] = gain[tid_s];
        sum_gradients[conflict_free_tid_plus_1] = sum_gradients[conflict_free_tid_s_plus_1];
        sum_hessians[conflict_free_tid_plus_1] = sum_hessians[conflict_free_tid_s_plus_1];
        found[tid] = found[tid_s];
        threshold_value[tid] = threshold_value[tid_s];
      }
    }
    __syncthreads();
  }
}

__device__ void ReduceBestGainForLeaves(double* gain, int* leaves, int cuda_cur_num_leaves) {
  const unsigned int tid = threadIdx.x;
  for (unsigned int s = 1; s < cuda_cur_num_leaves; s *= 2) {
    if (tid % (2 * s) == 0 && (tid + s) < cuda_cur_num_leaves) {
      const uint32_t tid_s = tid + s;
      if ((leaves[tid] == -1 && leaves[tid_s] != -1) || (leaves[tid] != -1 && leaves[tid_s] != -1 && gain[tid_s] > gain[tid])) {
        gain[tid] = gain[tid_s];
        leaves[tid] = leaves[tid_s];
      }
    }
    __syncthreads();
  }
}

__device__ double ThresholdL1(double s, double l1) {
  const double reg_s = fmax(0.0, fabs(s) - l1);
  if (s >= 0.0f) {
    return reg_s;
  } else {
    return -reg_s;
  }
}

__device__ double CalculateSplittedLeafOutput(double sum_gradients,
                                          double sum_hessians, double l1, const bool use_l1,
                                          double l2) {
  double ret;
  if (use_l1) {
    ret = -ThresholdL1(sum_gradients, l1) / (sum_hessians + l2);
  } else {
    ret = -sum_gradients / (sum_hessians + l2);
  }
  return ret;
}

__device__ double GetLeafGainGivenOutput(double sum_gradients,
                                      double sum_hessians, double l1, const bool use_l1,
                                      double l2, double output) {
  if (use_l1) {
    const double sg_l1 = ThresholdL1(sum_gradients, l1);
    return -(2.0 * sg_l1 * output + (sum_hessians + l2) * output * output);
  } else {
    return -(2.0 * sum_gradients * output +
              (sum_hessians + l2) * output * output);
  }
}

__device__ double GetLeafGain(double sum_gradients, double sum_hessians,
                          double l1, const bool use_l1, double l2) {
  if (use_l1) {
    const double sg_l1 = ThresholdL1(sum_gradients, l1);
    return (sg_l1 * sg_l1) / (sum_hessians + l2);
  } else {
    return (sum_gradients * sum_gradients) / (sum_hessians + l2);
  }
}

__device__ double GetSplitGains(double sum_left_gradients,
                            double sum_left_hessians,
                            double sum_right_gradients,
                            double sum_right_hessians,
                            double l1, const bool use_l1, double l2) {
  return GetLeafGain(sum_left_gradients,
                     sum_left_hessians,
                     l1, use_l1, l2) +
         GetLeafGain(sum_right_gradients,
                     sum_right_hessians,
                     l1, use_l1, l2);
}

__device__ void FindBestSplitsForLeafKernelInner(
  // input feature information
  const hist_t* feature_hist_ptr,
  const uint32_t feature_num_bin,
  const uint8_t feature_mfb_offset,
  const uint32_t feature_default_bin,
  const uint8_t feature_missing_type,
  const int inner_feature_index,
  // input config parameter values
  const double lambda_l1,
  const double lambda_l2,
  const data_size_t min_data_in_leaf,
  const double min_sum_hessian_in_leaf,
  const double min_gain_to_split,
  // input parent node information
  const double parent_gain,
  const double sum_gradients,
  const double sum_hessians,
  const data_size_t num_data,
  // input task information
  const bool reverse,
  const bool skip_default_bin,
  const bool na_as_missing,
  const uint8_t assume_out_default_left,
  // output parameters
  uint32_t* output_threshold,
  double* output_gain,
  uint8_t* output_default_left,
  double* output_left_sum_gradients,
  double* output_left_sum_hessians,
  data_size_t* output_left_num_data,
  double* output_left_gain,
  double* output_left_output,
  double* output_right_sum_gradients,
  double* output_right_sum_hessians,
  data_size_t* output_right_num_data,
  double* output_right_gain,
  double* output_right_output,
  uint8_t* output_found) {

  const double cnt_factor = num_data / sum_hessians;
  const bool use_l1 = lambda_l1 > 0.0f;
  const double min_gain_shift = parent_gain + min_gain_to_split;

  *output_found = 0;

  __shared__ hist_t local_grad_hist[MAX_NUM_BIN_IN_FEATURE + 1 + (MAX_NUM_BIN_IN_FEATURE + 1) / LOG_NUM_BANKS_DATA_PARTITION_BEST_SPLIT_FINDER];
  __shared__ hist_t local_hess_hist[MAX_NUM_BIN_IN_FEATURE + 1 + (MAX_NUM_BIN_IN_FEATURE + 1) / LOG_NUM_BANKS_DATA_PARTITION_BEST_SPLIT_FINDER];
  __shared__ double local_gain[MAX_NUM_BIN_IN_FEATURE];
  __shared__ uint8_t threshold_found[MAX_NUM_BIN_IN_FEATURE];
  __shared__ uint32_t threshold_value[MAX_NUM_BIN_IN_FEATURE];

  const unsigned int threadIdx_x = threadIdx.x;
  const bool skip_sum = (skip_default_bin && (threadIdx_x + feature_mfb_offset) == static_cast<int>(feature_default_bin));
  const uint32_t feature_num_bin_minus_offset = feature_num_bin - feature_mfb_offset;
  const bool skip_split = (skip_default_bin && (feature_num_bin_minus_offset - 1 - threadIdx_x + feature_mfb_offset == static_cast<int>(feature_default_bin)));
  const unsigned int bin_offset = threadIdx_x << 1;
  const unsigned int conflict_free_threadIdx_x = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(threadIdx_x);
  if (!reverse) {
    if (threadIdx_x < feature_num_bin_minus_offset && !skip_sum) {
      local_grad_hist[conflict_free_threadIdx_x] = feature_hist_ptr[bin_offset];
      const hist_t hess = feature_hist_ptr[bin_offset + 1];
      local_hess_hist[conflict_free_threadIdx_x] = hess;
    } else {
      local_grad_hist[conflict_free_threadIdx_x] = 0.0f;
      local_hess_hist[conflict_free_threadIdx_x] = 0.0f;
    }
  } else {
    if (threadIdx_x < feature_num_bin_minus_offset) {
      const unsigned int write_index = feature_num_bin_minus_offset - 1 - threadIdx_x;
      const unsigned int conflict_free_write_index = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(write_index);
      if (!skip_sum) {
        local_grad_hist[conflict_free_write_index] = feature_hist_ptr[bin_offset];
        const hist_t hess = feature_hist_ptr[bin_offset + 1];
        local_hess_hist[conflict_free_write_index] = hess;
      } else {
        local_grad_hist[conflict_free_write_index] = 0.0f;
        local_hess_hist[conflict_free_write_index] = 0.0f;
      }
    } else {
      local_grad_hist[conflict_free_threadIdx_x] = 0.0f;
      local_hess_hist[conflict_free_threadIdx_x] = 0.0f;
    }
  }
  __syncthreads();
  if (threadIdx_x == 0) {
    local_hess_hist[conflict_free_threadIdx_x] += K_EPSILON;
  }
  local_gain[threadIdx_x] = K_MIN_SCORE;
  __syncthreads();
  PrefixSumHist(local_grad_hist, MAX_NUM_BIN_IN_FEATURE);
  PrefixSumHist(local_hess_hist, MAX_NUM_BIN_IN_FEATURE);
  __syncthreads();
  const unsigned int conflict_free_threadIdx_x_plus_1 = CONFLICT_FREE_INDEX_BEST_SPLIT_FINDER(threadIdx_x + 1);
  if (reverse) {
    if (threadIdx_x >= static_cast<unsigned int>(na_as_missing) && threadIdx_x <= feature_num_bin - 2 && !skip_split) {
      const double sum_right_gradient = local_grad_hist[conflict_free_threadIdx_x_plus_1];
      const double sum_right_hessian = local_hess_hist[conflict_free_threadIdx_x_plus_1];
      const data_size_t right_count = static_cast<data_size_t>(__double2int_rn(sum_right_hessian * cnt_factor));
      const double sum_left_gradient = sum_gradients - sum_right_gradient;
      const double sum_left_hessian = sum_hessians - sum_right_hessian;
      const data_size_t left_count = num_data - right_count;
      if (sum_left_hessian >= min_sum_hessian_in_leaf && left_count >= min_data_in_leaf &&
        sum_right_hessian >= min_sum_hessian_in_leaf && right_count >= min_data_in_leaf) {
        double current_gain = GetSplitGains(
          sum_left_gradient, sum_left_hessian, sum_right_gradient,
          sum_right_hessian, lambda_l1, use_l1,
          lambda_l2);
        // gain with split is worse than without split
        if (current_gain <= min_gain_shift) {
          threshold_found[threadIdx_x] = 0;
        } else {
          local_gain[threadIdx_x] = current_gain - min_gain_shift;
          threshold_value[threadIdx_x] = static_cast<uint32_t>(feature_num_bin - 2 - threadIdx_x);
          threshold_found[threadIdx_x] = 1;
        }
      } else {
        threshold_found[threadIdx_x] = 0;
      }
    } else {
      threshold_found[threadIdx_x] = 0;
    }
  } else {
    if (threadIdx_x <= feature_num_bin_minus_offset - 2 /* TODO(shiyu1994): skip default */) {
      const double sum_left_gradient = local_grad_hist[conflict_free_threadIdx_x_plus_1];
      const double sum_left_hessian = local_hess_hist[conflict_free_threadIdx_x_plus_1];
      const data_size_t left_count = static_cast<data_size_t>(__double2int_rn(sum_left_hessian * cnt_factor));
      const double sum_right_gradient = sum_gradients - sum_left_gradient;
      const double sum_right_hessian = sum_hessians - sum_left_hessian;
      const data_size_t right_count = num_data - left_count;
      if (sum_left_hessian >= min_sum_hessian_in_leaf && left_count >= min_data_in_leaf &&
        sum_right_hessian >= min_sum_hessian_in_leaf && right_count >= min_data_in_leaf) {
        double current_gain = GetSplitGains(
          sum_left_gradient, sum_left_hessian, sum_right_gradient,
          sum_right_hessian, lambda_l1, use_l1,
          lambda_l2);
        // gain with split is worse than without split
        if (current_gain <= min_gain_shift) {
          threshold_found[threadIdx_x] = 0;
        } else {
          local_gain[threadIdx_x] = current_gain - min_gain_shift;
          threshold_value[threadIdx_x] = static_cast<uint32_t>(threadIdx_x + feature_mfb_offset);
          threshold_found[threadIdx_x] = 1;
        }
      } else {
        threshold_found[threadIdx_x] = 0;
      }
    } else {
      threshold_found[threadIdx_x] = 0;
    }
  }
  __syncthreads();
  ReduceBestGain(local_gain, local_grad_hist, local_hess_hist, threshold_found, threshold_value);
  const uint8_t found = threshold_found[0];
  if (found && threadIdx_x == 0) {
    *output_found = 1;
    *output_threshold = threshold_value[0];
    *output_gain = local_gain[0];
    *output_default_left = assume_out_default_left;
    if (reverse) {
      const double sum_right_gradient = local_grad_hist[1];
      const double sum_right_hessian = local_hess_hist[1] - K_EPSILON;
      const data_size_t right_count = static_cast<data_size_t>(__double2int_rn(sum_right_hessian * cnt_factor));
      const double sum_left_gradient = sum_gradients - sum_right_gradient;
      const double sum_left_hessian = sum_hessians - sum_right_hessian - K_EPSILON;
      const data_size_t left_count = num_data - right_count;
      const double left_output = CalculateSplittedLeafOutput(sum_left_gradient,
        sum_left_hessian, lambda_l1, use_l1, lambda_l2);
      const double right_output = CalculateSplittedLeafOutput(sum_right_gradient,
        sum_right_hessian, lambda_l1, use_l1, lambda_l2);
      *output_left_sum_gradients = sum_left_gradient;
      *output_left_sum_hessians = sum_left_hessian;
      *output_left_num_data = left_count;
      *output_right_sum_gradients = sum_right_gradient;
      *output_right_sum_hessians = sum_right_hessian;
      *output_right_num_data = right_count;
      *output_left_output = left_output;
      *output_left_gain = GetLeafGainGivenOutput(sum_left_gradient,
        sum_left_hessian, lambda_l1, use_l1, lambda_l2, left_output);
      *output_right_output = right_output;
      *output_right_gain = GetLeafGainGivenOutput(sum_right_gradient,
        sum_right_hessian, lambda_l1, use_l1, lambda_l2, right_output);
    } else {
      const double sum_left_gradient = local_grad_hist[1];
      const double sum_left_hessian = local_hess_hist[1] - K_EPSILON;
      const data_size_t left_count = static_cast<data_size_t>(__double2int_rn(sum_left_hessian * cnt_factor));
      const double sum_right_gradient = sum_gradients - sum_left_gradient;
      const double sum_right_hessian = sum_hessians - sum_left_hessian - K_EPSILON;
      const data_size_t right_count = num_data - left_count;
      const double left_output = CalculateSplittedLeafOutput(sum_left_gradient,
        sum_left_hessian, lambda_l1, use_l1, lambda_l2);
      const double right_output = CalculateSplittedLeafOutput(sum_right_gradient,
        sum_right_hessian, lambda_l1, use_l1, lambda_l2);
      *output_left_sum_gradients = sum_left_gradient;
      *output_left_sum_hessians = sum_left_hessian;
      *output_left_num_data = left_count;
      *output_right_sum_gradients = sum_right_gradient;
      *output_right_sum_hessians = sum_right_hessian;
      *output_right_num_data = right_count;
      *output_left_output = left_output;
      *output_left_gain = GetLeafGainGivenOutput(sum_left_gradient,
        sum_left_hessian, lambda_l1, use_l1, lambda_l2, left_output);
      *output_right_output = right_output;
      *output_right_gain = GetLeafGainGivenOutput(sum_right_gradient,
        sum_right_hessian, lambda_l1, use_l1, lambda_l2, right_output);
    }
  }
}

__global__ void FindBestSplitsForLeafKernel(
  // input feature information
  const uint32_t* feature_hist_offsets,
  const uint8_t* feature_mfb_offsets,
  const uint32_t* feature_default_bins, 
  const uint8_t* feature_missing_types,
  const uint32_t* feature_num_bins,
  // input task information
  const bool larger_only,
  const int num_tasks,
  const int* task_feature_index,
  const uint8_t* task_reverse,
  const uint8_t* task_skip_default_bin,
  const uint8_t* task_na_as_missing,
  const uint8_t* task_out_default_left,
  // input leaf information
  const int smaller_leaf_index,
  const double* smaller_leaf_gain,
  const double* smaller_sum_gradients_in_leaf,
  const double* smaller_sum_hessians_in_leaf,
  const data_size_t* smaller_num_data_in_leaf,
  hist_t** smaller_leaf_hist,
  const int larger_leaf_index,
  const double* larger_leaf_gain,
  const double* larger_sum_gradients_in_leaf,
  const double* larger_sum_hessians_in_leaf,
  const data_size_t* larger_num_data_in_leaf,
  hist_t** larger_leaf_hist,
  // input config parameter values
  const data_size_t min_data_in_leaf,
  const double min_sum_hessian_in_leaf,
  const double min_gain_to_split,
  const double lambda_l1,
  const double lambda_l2,
  // output
  uint32_t* cuda_best_split_threshold,
  uint8_t* cuda_best_split_default_left,
  double* cuda_best_split_gain,
  double* cuda_best_split_left_sum_gradient,
  double* cuda_best_split_left_sum_hessian,
  data_size_t* cuda_best_split_left_count, 
  double* cuda_best_split_left_gain,
  double* cuda_best_split_left_output,
  double* cuda_best_split_right_sum_gradient,
  double* cuda_best_split_right_sum_hessian,
  data_size_t* cuda_best_split_right_count,
  double* cuda_best_split_right_gain,
  double* cuda_best_split_right_output,
  uint8_t* cuda_best_split_found) {

  const unsigned int task_index = blockIdx.x % num_tasks;
  const bool is_larger = static_cast<bool>(blockIdx.x >= num_tasks || larger_only);
  const int inner_feature_index = task_feature_index[task_index];
  const bool reverse = static_cast<bool>(task_reverse[task_index]);
  const bool skip_default_bin = static_cast<bool>(task_skip_default_bin[task_index]);
  const bool na_as_missing = static_cast<bool>(task_na_as_missing[task_index]);
  const bool assume_out_default_left = task_out_default_left[task_index];
  const double parent_gain = is_larger ? *larger_leaf_gain : *smaller_leaf_gain;
  const double sum_gradients = is_larger ? *larger_sum_gradients_in_leaf : *smaller_sum_gradients_in_leaf;
  const double sum_hessians = (is_larger ? *larger_sum_hessians_in_leaf : *smaller_sum_hessians_in_leaf) + 2 * K_EPSILON;
  const double num_data = is_larger ? *larger_num_data_in_leaf : *smaller_num_data_in_leaf;
  const unsigned int output_offset = is_larger ? (task_index + num_tasks) : task_index;
  uint8_t* out_default_left = cuda_best_split_default_left + output_offset;
  uint32_t* out_threshold = cuda_best_split_threshold + output_offset;
  double* out_left_sum_gradients = cuda_best_split_left_sum_gradient + output_offset;
  double* out_left_sum_hessians = cuda_best_split_left_sum_hessian + output_offset;
  double* out_right_sum_gradients = cuda_best_split_right_sum_gradient + output_offset;
  double* out_right_sum_hessians = cuda_best_split_right_sum_hessian + output_offset;
  data_size_t* out_left_num_data = cuda_best_split_left_count + output_offset;
  data_size_t* out_right_num_data = cuda_best_split_right_count + output_offset;
  double* out_left_output = cuda_best_split_left_output + output_offset;
  double* out_right_output = cuda_best_split_right_output + output_offset;
  double* out_left_gain = cuda_best_split_left_gain + output_offset;
  double* out_right_gain = cuda_best_split_right_gain + output_offset;
  uint8_t* out_found = cuda_best_split_found + output_offset;
  double* out_gain = cuda_best_split_gain + output_offset;
  const hist_t* hist_ptr = (is_larger ? *larger_leaf_hist : *smaller_leaf_hist) + feature_hist_offsets[inner_feature_index] * 2;
  FindBestSplitsForLeafKernelInner(
    // input feature information
    hist_ptr,
    feature_num_bins[inner_feature_index],
    feature_mfb_offsets[inner_feature_index],
    feature_default_bins[inner_feature_index],
    feature_missing_types[inner_feature_index],
    inner_feature_index,
    // input config parameter values
    lambda_l1,
    lambda_l2,
    min_data_in_leaf,
    min_sum_hessian_in_leaf,
    min_gain_to_split,
    // input parent node information
    parent_gain,
    sum_gradients,
    sum_hessians,
    num_data,
    // input task information
    reverse,
    skip_default_bin,
    na_as_missing,
    assume_out_default_left,
    // output parameters
    out_threshold,
    out_gain,
    out_default_left,
    out_left_sum_gradients,
    out_left_sum_hessians,
    out_left_num_data,
    out_left_gain,
    out_left_output,
    out_right_sum_gradients,
    out_right_sum_hessians,
    out_right_num_data,
    out_right_gain,
    out_right_output,
    out_found);
}

void CUDABestSplitFinder::LaunchFindBestSplitsForLeafKernel(
  const CUDALeafSplits* smaller_leaf_splits,
  const CUDALeafSplits* larger_leaf_splits,
  const int smaller_leaf_index,
  const int larger_leaf_index,
  const bool is_smaller_leaf_valid,
  const bool is_larger_leaf_valid) {
  if (!is_smaller_leaf_valid && !is_larger_leaf_valid) {
    return;
  }
  bool larger_only = false;
  if (!is_smaller_leaf_valid) {
    larger_only = true;
  }
  if (!larger_only) {
    FindBestSplitsForLeafKernel<<<num_tasks_, MAX_NUM_BIN_IN_FEATURE, 0, cuda_streams_[0]>>>(
      // input feature information
      cuda_feature_hist_offsets_,
      cuda_feature_mfb_offsets_,
      cuda_feature_default_bins_,
      cuda_feature_missing_type_,
      cuda_feature_num_bins_,
      // input task information
      larger_only,
      num_tasks_,
      cuda_task_feature_index_,
      cuda_task_reverse_,
      cuda_task_skip_default_bin_,
      cuda_task_na_as_missing_,
      cuda_task_out_default_left_,
      // input leaf information
      smaller_leaf_index,
      smaller_leaf_splits->cuda_gain(),
      smaller_leaf_splits->cuda_sum_of_gradients(),
      smaller_leaf_splits->cuda_sum_of_hessians(),
      smaller_leaf_splits->cuda_num_data_in_leaf(),
      smaller_leaf_splits->cuda_hist_in_leaf_pointer_pointer(),
      larger_leaf_index,
      larger_leaf_splits->cuda_gain(),
      larger_leaf_splits->cuda_sum_of_gradients(),
      larger_leaf_splits->cuda_sum_of_hessians(),
      larger_leaf_splits->cuda_num_data_in_leaf(),
      larger_leaf_splits->cuda_hist_in_leaf_pointer_pointer(),
      // configuration parameter values
      min_data_in_leaf_,
      min_sum_hessian_in_leaf_,
      min_gain_to_split_,
      lambda_l1_,
      lambda_l2_,
      // output parameters
      cuda_best_split_threshold_,
      cuda_best_split_default_left_,
      cuda_best_split_gain_,
      cuda_best_split_left_sum_gradient_,
      cuda_best_split_left_sum_hessian_,
      cuda_best_split_left_count_,
      cuda_best_split_left_gain_,
      cuda_best_split_left_output_,
      cuda_best_split_right_sum_gradient_,
      cuda_best_split_right_sum_hessian_,
      cuda_best_split_right_count_,
      cuda_best_split_right_gain_,
      cuda_best_split_right_output_,
      cuda_best_split_found_);
  }
  SynchronizeCUDADevice();
  if (larger_leaf_index >= 0) {
    FindBestSplitsForLeafKernel<<<num_tasks_, MAX_NUM_BIN_IN_FEATURE, 0, cuda_streams_[1]>>>(
      // input feature information
      cuda_feature_hist_offsets_,
      cuda_feature_mfb_offsets_,
      cuda_feature_default_bins_,
      cuda_feature_missing_type_,
      cuda_feature_num_bins_,
      // input task information
      true,
      num_tasks_,
      cuda_task_feature_index_,
      cuda_task_reverse_,
      cuda_task_skip_default_bin_,
      cuda_task_na_as_missing_,
      cuda_task_out_default_left_,
      // input leaf information
      smaller_leaf_index,
      smaller_leaf_splits->cuda_gain(),
      smaller_leaf_splits->cuda_sum_of_gradients(),
      smaller_leaf_splits->cuda_sum_of_hessians(),
      smaller_leaf_splits->cuda_num_data_in_leaf(),
      smaller_leaf_splits->cuda_hist_in_leaf_pointer_pointer(),
      larger_leaf_index,
      larger_leaf_splits->cuda_gain(),
      larger_leaf_splits->cuda_sum_of_gradients(),
      larger_leaf_splits->cuda_sum_of_hessians(),
      larger_leaf_splits->cuda_num_data_in_leaf(),
      larger_leaf_splits->cuda_hist_in_leaf_pointer_pointer(),
      // configuration parameter values
      min_data_in_leaf_,
      min_sum_hessian_in_leaf_,
      min_gain_to_split_,
      lambda_l1_,
      lambda_l2_,
      // output parameters
      cuda_best_split_threshold_,
      cuda_best_split_default_left_,
      cuda_best_split_gain_,
      cuda_best_split_left_sum_gradient_,
      cuda_best_split_left_sum_hessian_,
      cuda_best_split_left_count_,
      cuda_best_split_left_gain_,
      cuda_best_split_left_output_,
      cuda_best_split_right_sum_gradient_,
      cuda_best_split_right_sum_hessian_,
      cuda_best_split_right_count_,
      cuda_best_split_right_gain_,
      cuda_best_split_right_output_,
      cuda_best_split_found_);
  }
}

__device__ void ReduceBestSplit(uint8_t* found, double* gain, uint32_t* shared_read_index,
  uint32_t num_features_aligned) {
  const uint32_t threadIdx_x = threadIdx.x;
  for (unsigned int s = 1; s < num_features_aligned; s <<= 1) {
    if (threadIdx_x % (2 * s) == 0 && (threadIdx_x + s) < num_features_aligned) {
      const uint32_t pos_to_compare = threadIdx_x + s;
      if ((!found[threadIdx_x] && found[pos_to_compare]) ||
        (found[threadIdx_x] && found[pos_to_compare] && gain[threadIdx_x] < gain[pos_to_compare])) {
        found[threadIdx_x] = found[pos_to_compare];
        gain[threadIdx_x] = gain[pos_to_compare];
        shared_read_index[threadIdx_x] = shared_read_index[pos_to_compare];
      }
    }
    __syncthreads();
  } 
}

__global__ void SyncBestSplitForLeafKernel(const int smaller_leaf_index, const int larger_leaf_index,
  const int* cuda_num_features, int* cuda_leaf_best_split_feature, uint8_t* cuda_leaf_best_split_default_left,
  uint32_t* cuda_leaf_best_split_threshold, double* cuda_leaf_best_split_gain,
  double* cuda_leaf_best_split_left_sum_gradient, double* cuda_leaf_best_split_left_sum_hessian,
  data_size_t* cuda_leaf_best_split_left_count, double* cuda_leaf_best_split_left_gain,
  double* cuda_leaf_best_split_left_output,
  double* cuda_leaf_best_split_right_sum_gradient, double* cuda_leaf_best_split_right_sum_hessian,
  data_size_t* cuda_leaf_best_split_right_count, double* cuda_leaf_best_split_right_gain,
  double* cuda_leaf_best_split_right_output,
  uint8_t* cuda_leaf_best_split_found,
  // input parameters
  const int* cuda_task_feature_index,
  const uint8_t* cuda_best_split_default_left,
  const uint32_t* cuda_best_split_threshold,
  const double* cuda_best_split_gain,
  const double* cuda_best_split_left_sum_gradient,
  const double* cuda_best_split_left_sum_hessian,
  const data_size_t* cuda_best_split_left_count,
  const double* cuda_best_split_left_gain,
  const double* cuda_best_split_left_output,
  const double* cuda_best_split_right_sum_gradient,
  const double* cuda_best_split_right_sum_hessian,
  const data_size_t* cuda_best_split_right_count,
  const double* cuda_best_split_right_gain,
  const double* cuda_best_split_right_output,
  const uint8_t* cuda_best_split_found,
  const uint32_t* cuda_feature_default_bins,
  const int num_tasks,
  const int num_tasks_aligned,
  const int num_blocks_per_leaf,
  const bool larger_only,
  const int num_leaves) {

  const uint32_t threadIdx_x = threadIdx.x;
  const uint32_t blockIdx_x = blockIdx.x;

  __shared__ uint8_t best_found[NUM_TASKS_PER_SYNC_BLOCK];
  __shared__ double best_gain[NUM_TASKS_PER_SYNC_BLOCK];
  __shared__ uint32_t shared_read_index[NUM_TASKS_PER_SYNC_BLOCK];

  const bool is_smaller = (blockIdx_x < static_cast<unsigned int>(num_blocks_per_leaf) && !larger_only);
  const uint32_t leaf_block_index = (is_smaller || larger_only) ? blockIdx_x : (blockIdx_x - static_cast<unsigned int>(num_blocks_per_leaf));
  const int task_index = static_cast<int>(leaf_block_index * blockDim.x + threadIdx_x);
  const uint32_t read_index = is_smaller ? static_cast<uint32_t>(task_index) : static_cast<uint32_t>(task_index + num_tasks);
  if (task_index < num_tasks) {
    best_found[threadIdx_x] = cuda_best_split_found[read_index];
    best_gain[threadIdx_x] = cuda_best_split_gain[read_index];
    shared_read_index[threadIdx_x] = read_index;
  } else {
    best_found[threadIdx_x] = 0;
  }

  __syncthreads();
  ReduceBestSplit(best_found, best_gain, shared_read_index, NUM_TASKS_PER_SYNC_BLOCK);
  if (threadIdx.x == 0) {
    const int leaf_index_ref = is_smaller ? smaller_leaf_index : larger_leaf_index;
    const unsigned buffer_write_pos = static_cast<unsigned int>(leaf_index_ref) + leaf_block_index * num_leaves;
    const uint32_t best_read_index = shared_read_index[0];
    if (best_found[0]) {
      cuda_leaf_best_split_gain[buffer_write_pos] = best_gain[0];
      cuda_leaf_best_split_feature[buffer_write_pos] = is_smaller ? cuda_task_feature_index[best_read_index] :
        cuda_task_feature_index[static_cast<int>(best_read_index) - num_tasks];
      cuda_leaf_best_split_default_left[buffer_write_pos] = cuda_best_split_default_left[best_read_index];
      cuda_leaf_best_split_threshold[buffer_write_pos] = cuda_best_split_threshold[best_read_index];
      cuda_leaf_best_split_left_sum_gradient[buffer_write_pos] = cuda_best_split_left_sum_gradient[best_read_index];
      cuda_leaf_best_split_left_sum_hessian[buffer_write_pos] = cuda_best_split_left_sum_hessian[best_read_index];
      cuda_leaf_best_split_left_count[buffer_write_pos] = cuda_best_split_left_count[best_read_index];
      cuda_leaf_best_split_left_gain[buffer_write_pos] = cuda_best_split_left_gain[best_read_index]; 
      cuda_leaf_best_split_left_output[buffer_write_pos] = cuda_best_split_left_output[best_read_index];
      cuda_leaf_best_split_right_sum_gradient[buffer_write_pos] = cuda_best_split_right_sum_gradient[best_read_index];
      cuda_leaf_best_split_right_sum_hessian[buffer_write_pos] = cuda_best_split_right_sum_hessian[best_read_index];
      cuda_leaf_best_split_right_count[buffer_write_pos] = cuda_best_split_right_count[best_read_index];
      cuda_leaf_best_split_right_gain[buffer_write_pos] = cuda_best_split_right_gain[best_read_index]; 
      cuda_leaf_best_split_right_output[buffer_write_pos] = cuda_best_split_right_output[best_read_index];
      cuda_leaf_best_split_found[buffer_write_pos] = 1;
    } else {
      cuda_leaf_best_split_gain[buffer_write_pos] = K_MIN_SCORE;
      cuda_leaf_best_split_found[buffer_write_pos] = 0;
    }
  }
}

__global__ void SyncBestSplitForLeafKernelAllBlocks(
  const int smaller_leaf_index,
  const int larger_leaf_index,
  const unsigned int num_blocks_per_leaf,
  const int num_leaves,
  int* cuda_leaf_best_split_feature, uint8_t* cuda_leaf_best_split_default_left,
  uint32_t* cuda_leaf_best_split_threshold, double* cuda_leaf_best_split_gain,
  double* cuda_leaf_best_split_left_sum_gradient, double* cuda_leaf_best_split_left_sum_hessian,
  data_size_t* cuda_leaf_best_split_left_count, double* cuda_leaf_best_split_left_gain,
  double* cuda_leaf_best_split_left_output,
  double* cuda_leaf_best_split_right_sum_gradient, double* cuda_leaf_best_split_right_sum_hessian,
  data_size_t* cuda_leaf_best_split_right_count, double* cuda_leaf_best_split_right_gain,
  double* cuda_leaf_best_split_right_output,
  uint8_t* cuda_leaf_best_split_found,
  const bool larger_only) {
  if (!larger_only) {
    if (blockIdx.x == 0) {
      for (unsigned int block_index = 1; block_index < num_blocks_per_leaf; ++block_index) {
        const unsigned int leaf_read_pos = static_cast<unsigned int>(smaller_leaf_index) + block_index * static_cast<unsigned int>(num_leaves);
        if ((cuda_leaf_best_split_found[leaf_read_pos] == 1 && cuda_leaf_best_split_found[smaller_leaf_index] == 1 &&
          cuda_leaf_best_split_gain[leaf_read_pos] > cuda_leaf_best_split_gain[smaller_leaf_index]) ||
            (cuda_leaf_best_split_found[smaller_leaf_index] == 0 && cuda_leaf_best_split_found[leaf_read_pos] == 1)) {
            cuda_leaf_best_split_found[smaller_leaf_index] = cuda_leaf_best_split_found[leaf_read_pos];
            cuda_leaf_best_split_feature[smaller_leaf_index] = cuda_leaf_best_split_feature[leaf_read_pos];
            cuda_leaf_best_split_default_left[smaller_leaf_index] = cuda_leaf_best_split_default_left[leaf_read_pos];
            cuda_leaf_best_split_threshold[smaller_leaf_index] = cuda_leaf_best_split_threshold[leaf_read_pos];
            cuda_leaf_best_split_gain[smaller_leaf_index] = cuda_leaf_best_split_gain[leaf_read_pos];
            cuda_leaf_best_split_left_sum_gradient[smaller_leaf_index] = cuda_leaf_best_split_left_sum_gradient[leaf_read_pos];
            cuda_leaf_best_split_left_sum_hessian[smaller_leaf_index] = cuda_leaf_best_split_left_sum_hessian[leaf_read_pos];
            cuda_leaf_best_split_left_count[smaller_leaf_index] = cuda_leaf_best_split_left_count[leaf_read_pos];
            cuda_leaf_best_split_left_gain[smaller_leaf_index] = cuda_leaf_best_split_left_gain[leaf_read_pos];
            cuda_leaf_best_split_left_output[smaller_leaf_index] = cuda_leaf_best_split_left_output[leaf_read_pos];
            cuda_leaf_best_split_right_sum_gradient[smaller_leaf_index] = cuda_leaf_best_split_right_sum_gradient[leaf_read_pos];
            cuda_leaf_best_split_right_sum_hessian[smaller_leaf_index] = cuda_leaf_best_split_right_sum_hessian[leaf_read_pos];
            cuda_leaf_best_split_right_count[smaller_leaf_index] = cuda_leaf_best_split_right_count[leaf_read_pos];
            cuda_leaf_best_split_right_gain[smaller_leaf_index] = cuda_leaf_best_split_right_gain[leaf_read_pos];
            cuda_leaf_best_split_right_output[smaller_leaf_index] = cuda_leaf_best_split_right_output[leaf_read_pos];
        }
      }
    }
  }
  if (larger_leaf_index >= 0) {
    if (blockIdx.x == 1 || larger_only) {
      for (unsigned int block_index = 1; block_index < num_blocks_per_leaf; ++block_index) {
        const unsigned int leaf_read_pos = static_cast<unsigned int>(larger_leaf_index) + block_index * static_cast<unsigned int>(num_leaves);
        if ((cuda_leaf_best_split_found[leaf_read_pos] == 1 && cuda_leaf_best_split_found[larger_leaf_index] == 1 &&
          cuda_leaf_best_split_gain[leaf_read_pos] > cuda_leaf_best_split_gain[larger_leaf_index]) ||
            (cuda_leaf_best_split_found[larger_leaf_index] == 0 && cuda_leaf_best_split_found[leaf_read_pos] == 1)) {
            cuda_leaf_best_split_found[larger_leaf_index] = cuda_leaf_best_split_found[leaf_read_pos];
            cuda_leaf_best_split_feature[larger_leaf_index] = cuda_leaf_best_split_feature[leaf_read_pos];
            cuda_leaf_best_split_default_left[larger_leaf_index] = cuda_leaf_best_split_default_left[leaf_read_pos];
            cuda_leaf_best_split_threshold[larger_leaf_index] = cuda_leaf_best_split_threshold[leaf_read_pos];
            cuda_leaf_best_split_gain[larger_leaf_index] = cuda_leaf_best_split_gain[leaf_read_pos];
            cuda_leaf_best_split_left_sum_gradient[larger_leaf_index] = cuda_leaf_best_split_left_sum_gradient[leaf_read_pos];
            cuda_leaf_best_split_left_sum_hessian[larger_leaf_index] = cuda_leaf_best_split_left_sum_hessian[leaf_read_pos];
            cuda_leaf_best_split_left_count[larger_leaf_index] = cuda_leaf_best_split_left_count[leaf_read_pos];
            cuda_leaf_best_split_left_gain[larger_leaf_index] = cuda_leaf_best_split_left_gain[leaf_read_pos];
            cuda_leaf_best_split_left_output[larger_leaf_index] = cuda_leaf_best_split_left_output[leaf_read_pos];
            cuda_leaf_best_split_right_sum_gradient[larger_leaf_index] = cuda_leaf_best_split_right_sum_gradient[leaf_read_pos];
            cuda_leaf_best_split_right_sum_hessian[larger_leaf_index] = cuda_leaf_best_split_right_sum_hessian[leaf_read_pos];
            cuda_leaf_best_split_right_count[larger_leaf_index] = cuda_leaf_best_split_right_count[leaf_read_pos];
            cuda_leaf_best_split_right_gain[larger_leaf_index] = cuda_leaf_best_split_right_gain[leaf_read_pos];
            cuda_leaf_best_split_right_output[larger_leaf_index] = cuda_leaf_best_split_right_output[leaf_read_pos];
        }
      }
    }
  }
}

void CUDABestSplitFinder::LaunchSyncBestSplitForLeafKernel(
  const int cpu_smaller_leaf_index,
  const int cpu_larger_leaf_index,
  const bool is_smaller_leaf_valid,
  const bool is_larger_leaf_valid) {

  int num_tasks = num_tasks_;
  int num_tasks_aligned = 1;
  num_tasks -= 1;
  while (num_tasks > 0) {
    num_tasks_aligned <<= 1;
    num_tasks >>= 1;
  }
  const int num_blocks_per_leaf = (num_tasks_ + NUM_TASKS_PER_SYNC_BLOCK - 1) / NUM_TASKS_PER_SYNC_BLOCK;
  if (cpu_larger_leaf_index >= 0 && is_smaller_leaf_valid && is_larger_leaf_valid) {
    SyncBestSplitForLeafKernel<<<num_blocks_per_leaf, NUM_TASKS_PER_SYNC_BLOCK, 0, cuda_streams_[0]>>>(
      cpu_smaller_leaf_index,
      cpu_larger_leaf_index,
      cuda_num_features_,
      cuda_leaf_best_split_feature_,
      cuda_leaf_best_split_default_left_,
      cuda_leaf_best_split_threshold_,
      cuda_leaf_best_split_gain_,
      cuda_leaf_best_split_left_sum_gradient_,
      cuda_leaf_best_split_left_sum_hessian_,
      cuda_leaf_best_split_left_count_,
      cuda_leaf_best_split_left_gain_,
      cuda_leaf_best_split_left_output_,
      cuda_leaf_best_split_right_sum_gradient_,
      cuda_leaf_best_split_right_sum_hessian_,
      cuda_leaf_best_split_right_count_,
      cuda_leaf_best_split_right_gain_,
      cuda_leaf_best_split_right_output_,
      cuda_leaf_best_split_found_,
      cuda_task_feature_index_,
      cuda_best_split_default_left_,
      cuda_best_split_threshold_,
      cuda_best_split_gain_,
      cuda_best_split_left_sum_gradient_,
      cuda_best_split_left_sum_hessian_,
      cuda_best_split_left_count_,
      cuda_best_split_left_gain_,
      cuda_best_split_left_output_,
      cuda_best_split_right_sum_gradient_,
      cuda_best_split_right_sum_hessian_,
      cuda_best_split_right_count_,
      cuda_best_split_right_gain_,
      cuda_best_split_right_output_,
      cuda_best_split_found_,
      cuda_feature_default_bins_,
      num_tasks_,
      num_tasks_aligned,
      num_blocks_per_leaf,
      false,
      num_leaves_);
    if (num_blocks_per_leaf > 1) {
      SyncBestSplitForLeafKernelAllBlocks<<<1, 1, 0, cuda_streams_[0]>>>(
        cpu_smaller_leaf_index,
        cpu_larger_leaf_index,
        num_blocks_per_leaf,
        num_leaves_,
        cuda_leaf_best_split_feature_,
        cuda_leaf_best_split_default_left_,
        cuda_leaf_best_split_threshold_,
        cuda_leaf_best_split_gain_,
        cuda_leaf_best_split_left_sum_gradient_,
        cuda_leaf_best_split_left_sum_hessian_,
        cuda_leaf_best_split_left_count_,
        cuda_leaf_best_split_left_gain_,
        cuda_leaf_best_split_left_output_,
        cuda_leaf_best_split_right_sum_gradient_,
        cuda_leaf_best_split_right_sum_hessian_,
        cuda_leaf_best_split_right_count_,
        cuda_leaf_best_split_right_gain_,
        cuda_leaf_best_split_right_output_,
        cuda_leaf_best_split_found_,
        false);
    }
    SynchronizeCUDADevice();
    SyncBestSplitForLeafKernel<<<num_blocks_per_leaf, NUM_TASKS_PER_SYNC_BLOCK, 0, cuda_streams_[1]>>>(
      cpu_smaller_leaf_index,
      cpu_larger_leaf_index,
      cuda_num_features_,
      cuda_leaf_best_split_feature_,
      cuda_leaf_best_split_default_left_,
      cuda_leaf_best_split_threshold_,
      cuda_leaf_best_split_gain_,
      cuda_leaf_best_split_left_sum_gradient_,
      cuda_leaf_best_split_left_sum_hessian_,
      cuda_leaf_best_split_left_count_,
      cuda_leaf_best_split_left_gain_,
      cuda_leaf_best_split_left_output_,
      cuda_leaf_best_split_right_sum_gradient_,
      cuda_leaf_best_split_right_sum_hessian_,
      cuda_leaf_best_split_right_count_,
      cuda_leaf_best_split_right_gain_,
      cuda_leaf_best_split_right_output_,
      cuda_leaf_best_split_found_,
      cuda_task_feature_index_,
      cuda_best_split_default_left_,
      cuda_best_split_threshold_,
      cuda_best_split_gain_,
      cuda_best_split_left_sum_gradient_,
      cuda_best_split_left_sum_hessian_,
      cuda_best_split_left_count_,
      cuda_best_split_left_gain_,
      cuda_best_split_left_output_,
      cuda_best_split_right_sum_gradient_,
      cuda_best_split_right_sum_hessian_,
      cuda_best_split_right_count_,
      cuda_best_split_right_gain_,
      cuda_best_split_right_output_,
      cuda_best_split_found_,
      cuda_feature_default_bins_,
      num_tasks_,
      num_tasks_aligned,
      num_blocks_per_leaf,
      true,
      num_leaves_);
    if (num_blocks_per_leaf > 1) {
      SyncBestSplitForLeafKernelAllBlocks<<<1, 1, 0, cuda_streams_[1]>>>(
        cpu_smaller_leaf_index,
        cpu_larger_leaf_index,
        num_blocks_per_leaf,
        num_leaves_,
        cuda_leaf_best_split_feature_,
        cuda_leaf_best_split_default_left_,
        cuda_leaf_best_split_threshold_,
        cuda_leaf_best_split_gain_,
        cuda_leaf_best_split_left_sum_gradient_,
        cuda_leaf_best_split_left_sum_hessian_,
        cuda_leaf_best_split_left_count_,
        cuda_leaf_best_split_left_gain_,
        cuda_leaf_best_split_left_output_,
        cuda_leaf_best_split_right_sum_gradient_,
        cuda_leaf_best_split_right_sum_hessian_,
        cuda_leaf_best_split_right_count_,
        cuda_leaf_best_split_right_gain_,
        cuda_leaf_best_split_right_output_,
        cuda_leaf_best_split_found_,
        true);
    }
  } else {
    const bool larger_only = (!is_smaller_leaf_valid && is_larger_leaf_valid);
    SyncBestSplitForLeafKernel<<<num_blocks_per_leaf, NUM_TASKS_PER_SYNC_BLOCK>>>(
      cpu_smaller_leaf_index,
      cpu_larger_leaf_index,
      cuda_num_features_,
      cuda_leaf_best_split_feature_,
      cuda_leaf_best_split_default_left_,
      cuda_leaf_best_split_threshold_,
      cuda_leaf_best_split_gain_,
      cuda_leaf_best_split_left_sum_gradient_,
      cuda_leaf_best_split_left_sum_hessian_,
      cuda_leaf_best_split_left_count_,
      cuda_leaf_best_split_left_gain_,
      cuda_leaf_best_split_left_output_,
      cuda_leaf_best_split_right_sum_gradient_,
      cuda_leaf_best_split_right_sum_hessian_,
      cuda_leaf_best_split_right_count_,
      cuda_leaf_best_split_right_gain_,
      cuda_leaf_best_split_right_output_,
      cuda_leaf_best_split_found_,
      cuda_task_feature_index_,
      cuda_best_split_default_left_,
      cuda_best_split_threshold_,
      cuda_best_split_gain_,
      cuda_best_split_left_sum_gradient_,
      cuda_best_split_left_sum_hessian_,
      cuda_best_split_left_count_,
      cuda_best_split_left_gain_,
      cuda_best_split_left_output_,
      cuda_best_split_right_sum_gradient_,
      cuda_best_split_right_sum_hessian_,
      cuda_best_split_right_count_,
      cuda_best_split_right_gain_,
      cuda_best_split_right_output_,
      cuda_best_split_found_,
      cuda_feature_default_bins_,
      num_tasks_,
      num_tasks_aligned,
      num_blocks_per_leaf,
      larger_only,
      num_leaves_);
    if (num_blocks_per_leaf > 1) {
      SynchronizeCUDADevice();
      SyncBestSplitForLeafKernelAllBlocks<<<1, 1>>>(
        cpu_smaller_leaf_index,
        cpu_larger_leaf_index,
        num_blocks_per_leaf,
        num_leaves_,
        cuda_leaf_best_split_feature_,
        cuda_leaf_best_split_default_left_,
        cuda_leaf_best_split_threshold_,
        cuda_leaf_best_split_gain_,
        cuda_leaf_best_split_left_sum_gradient_,
        cuda_leaf_best_split_left_sum_hessian_,
        cuda_leaf_best_split_left_count_,
        cuda_leaf_best_split_left_gain_,
        cuda_leaf_best_split_left_output_,
        cuda_leaf_best_split_right_sum_gradient_,
        cuda_leaf_best_split_right_sum_hessian_,
        cuda_leaf_best_split_right_count_,
        cuda_leaf_best_split_right_gain_,
        cuda_leaf_best_split_right_output_,
        cuda_leaf_best_split_found_,
        larger_only);
    }
  }
}

__global__ void FindBestFromAllSplitsKernel(const int* cuda_cur_num_leaves,
  const double* cuda_leaf_best_split_gain, int* out_best_leaf,
  const int* cuda_leaf_best_split_feature, const uint32_t* cuda_leaf_best_split_threshold,
  const uint32_t* cuda_feature_default_bins,
  const double* cuda_leaf_best_split_left_sum_gradient,
  const double* cuda_leaf_best_split_left_sum_hessian,
  const double* cuda_leaf_best_split_right_sum_gradient,
  const double* cuda_leaf_best_split_right_sum_hessian,
  const data_size_t* cuda_leaf_best_split_left_count,
  const data_size_t* cuda_leaf_best_split_right_count,
  const uint8_t* cuda_leaf_best_split_found,
  int* cuda_best_split_info_buffer) {
  const int cuda_cur_num_leaves_ref = *cuda_cur_num_leaves;
  __shared__ double thread_best_gain[NUM_THREADS_FIND_BEST_LEAF];
  __shared__ int thread_best_leaf[NUM_THREADS_FIND_BEST_LEAF];
  const unsigned int threadIdx_x = threadIdx.x;
  thread_best_gain[threadIdx_x] = K_MIN_SCORE;
  thread_best_leaf[threadIdx_x] = -1;
  const int num_leaves_per_thread = (cuda_cur_num_leaves_ref + NUM_THREADS_FIND_BEST_LEAF - 1) / NUM_THREADS_FIND_BEST_LEAF;
  const int cur_num_valid_threads = (cuda_cur_num_leaves_ref + num_leaves_per_thread - 1) / num_leaves_per_thread;
  if (threadIdx_x < static_cast<unsigned int>(cur_num_valid_threads)) {
    const int start = num_leaves_per_thread * threadIdx_x;
    const int end = min(start + num_leaves_per_thread, cuda_cur_num_leaves_ref);
    for (int leaf_index = threadIdx_x; leaf_index < cuda_cur_num_leaves_ref; leaf_index += cur_num_valid_threads) {
      const double leaf_best_gain = cuda_leaf_best_split_gain[leaf_index];
      if (cuda_leaf_best_split_found[leaf_index] && leaf_best_gain > thread_best_gain[threadIdx_x]) {
        thread_best_gain[threadIdx_x] = leaf_best_gain;
        thread_best_leaf[threadIdx_x] = leaf_index;
      }
    }
  }
  __syncthreads();
  ReduceBestGainForLeaves(thread_best_gain, thread_best_leaf, cur_num_valid_threads);
  if (threadIdx_x == 0) {
    *out_best_leaf = thread_best_leaf[0];
    cuda_best_split_info_buffer[6] = thread_best_leaf[0];
  }
}

__global__ void PrepareLeafBestSplitInfo(const int smaller_leaf_index, const int larger_leaf_index,
  int* cuda_best_split_info_buffer, const int* cuda_leaf_best_split_feature,
  const uint32_t* cuda_leaf_best_split_threshold, const uint8_t* cuda_leaf_best_split_default_left) {
  const unsigned int threadIdx_x = blockIdx.x;
  if (threadIdx_x == 0) {
    cuda_best_split_info_buffer[0] = cuda_leaf_best_split_feature[smaller_leaf_index];
  } else if (threadIdx_x == 1) {
    cuda_best_split_info_buffer[1] = cuda_leaf_best_split_threshold[smaller_leaf_index];
  } else if (threadIdx_x == 2) {
    cuda_best_split_info_buffer[2] = cuda_leaf_best_split_default_left[smaller_leaf_index];
  }
  if (larger_leaf_index >= 0) { 
    if (threadIdx_x == 3) {
      cuda_best_split_info_buffer[3] = cuda_leaf_best_split_feature[larger_leaf_index];
    } else if (threadIdx_x == 4) {
      cuda_best_split_info_buffer[4] = cuda_leaf_best_split_threshold[larger_leaf_index];
    } else if (threadIdx_x == 5) {
      cuda_best_split_info_buffer[5] = cuda_leaf_best_split_default_left[larger_leaf_index];
    }
  }
}

void CUDABestSplitFinder::LaunchFindBestFromAllSplitsKernel(const int* cuda_cur_num_leaves,
  const int smaller_leaf_index, const int larger_leaf_index, std::vector<int>* leaf_best_split_feature,
  std::vector<uint32_t>* leaf_best_split_threshold, std::vector<uint8_t>* leaf_best_split_default_left, int* best_leaf_index) {
  FindBestFromAllSplitsKernel<<<1, NUM_THREADS_FIND_BEST_LEAF, 0, cuda_streams_[1]>>>(cuda_cur_num_leaves, cuda_leaf_best_split_gain_, cuda_best_leaf_,
    cuda_leaf_best_split_feature_, cuda_leaf_best_split_threshold_, cuda_feature_default_bins_,
    cuda_leaf_best_split_left_sum_gradient_,
    cuda_leaf_best_split_left_sum_hessian_,
    cuda_leaf_best_split_right_sum_gradient_,
    cuda_leaf_best_split_right_sum_hessian_,
    cuda_leaf_best_split_left_count_,
    cuda_leaf_best_split_right_count_,
    cuda_leaf_best_split_found_,
    cuda_best_split_info_buffer_);
  PrepareLeafBestSplitInfo<<<6, 1, 0, cuda_streams_[0]>>>(smaller_leaf_index, larger_leaf_index,
    cuda_best_split_info_buffer_, cuda_leaf_best_split_feature_,
    cuda_leaf_best_split_threshold_, cuda_leaf_best_split_default_left_);
  std::vector<int> cpu_leaf_best_split_info_buffer(7);
  SynchronizeCUDADevice();
  CopyFromCUDADeviceToHost<int>(cpu_leaf_best_split_info_buffer.data(), cuda_best_split_info_buffer_, 7);
  (*leaf_best_split_feature)[smaller_leaf_index] = cpu_leaf_best_split_info_buffer[0];
  (*leaf_best_split_threshold)[smaller_leaf_index] = static_cast<uint32_t>(cpu_leaf_best_split_info_buffer[1]);
  (*leaf_best_split_default_left)[smaller_leaf_index] = static_cast<uint8_t>(cpu_leaf_best_split_info_buffer[2]);
  if (larger_leaf_index >= 0) {
    (*leaf_best_split_feature)[larger_leaf_index] = cpu_leaf_best_split_info_buffer[3];
    (*leaf_best_split_threshold)[larger_leaf_index] = static_cast<uint32_t>(cpu_leaf_best_split_info_buffer[4]);
    (*leaf_best_split_default_left)[larger_leaf_index] = static_cast<uint8_t>(cpu_leaf_best_split_info_buffer[5]);
  }
  *best_leaf_index = cpu_leaf_best_split_info_buffer[6];
  /*if (smaller_leaf_index == 0) {
    Log::Warning("smaller_leaf_index = %d, best_split_feature = %d, best_split_threshold = %d",
      smaller_leaf_index, cpu_leaf_best_split_info_buffer[0], cpu_leaf_best_split_info_buffer[1]);
  }*/
}

}  // namespace LightGBM

#endif  // USE_CUDA
