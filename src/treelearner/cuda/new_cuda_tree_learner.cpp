/*!
 * Copyright (c) 2021 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for
 * license information.
 */

#ifdef USE_CUDA

#include "new_cuda_tree_learner.hpp"

#include <LightGBM/cuda/cuda_utils.h>
#include <LightGBM/feature_group.h>

namespace LightGBM {

NewCUDATreeLearner::NewCUDATreeLearner(const Config* config): SerialTreeLearner(config) {}

NewCUDATreeLearner::~NewCUDATreeLearner() {}

void NewCUDATreeLearner::Init(const Dataset* train_data, bool is_constant_hessian) {
  // use the first gpu by now
  SerialTreeLearner::Init(train_data, is_constant_hessian);
  num_threads_ = OMP_NUM_THREADS();
  CUDASUCCESS_OR_FATAL(cudaSetDevice(0));
  cuda_centralized_info_.reset(new CUDACentralizedInfo(num_data_, this->config_->num_leaves, num_features_));
  cuda_centralized_info_->Init();
  //cuda_centralized_info_->Test();

  cuda_smaller_leaf_splits_.reset(new CUDALeafSplits(num_data_, 0, cuda_centralized_info_->cuda_gradients(),
    cuda_centralized_info_->cuda_hessians(), cuda_centralized_info_->cuda_num_data()));
  cuda_smaller_leaf_splits_->Init();
  cuda_larger_leaf_splits_.reset(new CUDALeafSplits(num_data_, -1, cuda_centralized_info_->cuda_gradients(),
    cuda_centralized_info_->cuda_hessians(), cuda_centralized_info_->cuda_num_data()));
  cuda_larger_leaf_splits_->Init();

  cuda_data_partition_.reset(new CUDADataPartition(num_data_, this->config_->num_leaves,
    cuda_centralized_info_->cuda_num_data(), cuda_centralized_info_->cuda_num_leaves()));
  cuda_data_partition_->Init();

  cuda_histogram_constructor_.reset(new CUDAHistogramConstructor(train_data_, this->config_->num_leaves, num_threads_,
    cuda_centralized_info_->cuda_gradients(), cuda_centralized_info_->cuda_hessians()));
  cuda_histogram_constructor_->Init(train_data_);
  //cuda_histogram_constructor_->TestAfterInit();
}

void NewCUDATreeLearner::BeforeTrain() {
  cuda_centralized_info_->BeforeTrain(gradients_, hessians_);
  cuda_smaller_leaf_splits_->InitValues();
  //cuda_smaller_leaf_splits_->Test();
  cuda_data_partition_->BeforeTrain(nullptr);
  //cuda_data_partition_->Test();

  //SerialTreeLearner::BeforeTrain();
  /*#pragma omp parallel for schedule(static) num_threads(num_threads_)
  for (int device_id = 0; device_id < num_gpus_; ++device_id) {
    CUDASUCCESS_OR_FATAL(cudaSetDevice(device_id));
    device_leaf_splits_initializers_[device_id]->Init();
  }*/
}

void NewCUDATreeLearner::AllocateMemory(const bool is_constant_hessian) {
  /*device_data_indices_.resize(num_gpus_, nullptr);
  device_gradients_.resize(num_gpus_, nullptr);
  device_gradients_and_hessians_.resize(num_gpus_, nullptr);
  if (!is_constant_hessian) {
    device_hessians_.resize(num_gpus_, nullptr);
  }
  device_histograms_.resize(num_gpus_, nullptr);
  const int num_total_bin_from_dataset = train_data_->NumTotalBin();
  const int num_total_bin_from_share_states = share_state_->num_hist_total_bin();
  const int num_total_bin = std::max(num_total_bin_from_dataset, num_total_bin_from_share_states);
  #pragma omp parallel for schedule(static) num_threads(num_threads_)
  for (int device_id = 0; device_id < num_gpus_; ++device_id) {
    CUDASUCCESS_OR_FATAL(cudaSetDevice(device_id));
    if (device_data_indices_[device_id] != nullptr) {
      CUDASUCCESS_OR_FATAL(cudaFree(device_data_indices_[device_id]));
    }
    void* data_indices_ptr = reinterpret_cast<void*>(device_data_indices_[device_id]);
    CUDASUCCESS_OR_FATAL(cudaMalloc(&data_indices_ptr, num_data_ * sizeof(data_size_t)));
    device_data_indices_[device_id] = reinterpret_cast<data_size_t*>(data_indices_ptr);
    if (device_gradients_[device_id] != nullptr) {
      CUDASUCCESS_OR_FATAL(cudaFree(device_gradients_[device_id]));
    }
    void* gradients_ptr = reinterpret_cast<void*>(device_gradients_[device_id]);
    CUDASUCCESS_OR_FATAL(cudaMalloc(&gradients_ptr, num_data_ * sizeof(float)));
    device_gradients_[device_id] = reinterpret_cast<float*>(gradients_ptr);
    AllocateCUDAMemory<score_t>(2 * num_data_ * sizeof(score_t), &device_gradients_and_hessians_[device_id]);
    if (!is_constant_hessian) {
      if (device_hessians_[device_id] != nullptr) {
        CUDASUCCESS_OR_FATAL(cudaFree(device_hessians_[device_id]));
      }
      void* hessians_ptr = reinterpret_cast<void*>(device_hessians_[device_id]);
      CUDASUCCESS_OR_FATAL(cudaMalloc(&hessians_ptr, num_data_ * sizeof(float)));
      device_hessians_[device_id] = reinterpret_cast<float*>(hessians_ptr);
    }
    if (device_histograms_[device_id] != nullptr) {
      CUDASUCCESS_OR_FATAL(cudaFree(device_histograms_[device_id]));
    }
    void* histograms_ptr = reinterpret_cast<void*>(device_histograms_[device_id]);
    CUDASUCCESS_OR_FATAL(cudaMalloc(&histograms_ptr, num_total_bin * 2 * sizeof(double)));
    device_histograms_[device_id] = reinterpret_cast<double*>(histograms_ptr);
  }*/
}

void NewCUDATreeLearner::CreateCUDAHistogramConstructors() {
  /*Log::Warning("NewCUDATreeLearner::CreateCUDAHistogramConstructors num_gpus_ = %d", num_gpus_);
  device_histogram_constructors_.resize(num_gpus_);
  device_leaf_splits_initializers_.resize(num_gpus_);
  device_best_split_finders_.resize(num_gpus_);
  device_splitters_.resize(num_gpus_);
  #pragma omp parallel for schedule(static) num_threads(num_threads_)
  for (int device_id = 0; device_id < num_gpus_; ++device_id) {
    CUDASUCCESS_OR_FATAL(cudaSetDevice(device_id));
    Log::Warning("NewCUDATreeLearner::CreateCUDAHistogramConstructors step 1", num_gpus_);
    device_leaf_splits_initializers_[device_id].reset(
      new CUDALeafSplitsInit(device_gradients_[device_id], device_hessians_[device_id], num_data_));
    Log::Warning("NewCUDATreeLearner::CreateCUDAHistogramConstructors step 2", num_gpus_);
    device_histogram_constructors_[device_id].reset(
      new CUDAHistogramConstructor(device_feature_groups_[device_id],
        train_data_, config_->num_leaves, device_histograms_[device_id]));
    Log::Warning("NewCUDATreeLearner::CreateCUDAHistogramConstructors step 3", num_gpus_);
    device_best_split_finders_[device_id].reset(
      new CUDABestSplitFinder(device_histogram_constructors_[device_id]->cuda_hist(),
        train_data_, device_feature_groups_[device_id], config_->num_leaves));
    Log::Warning("NewCUDATreeLearner::CreateCUDAHistogramConstructors step 4", num_gpus_);
    device_splitters_[device_id].reset(
      new CUDADataSplitter(num_data_, config_->num_leaves));
    Log::Warning("NewCUDATreeLearner::CreateCUDAHistogramConstructors step 5", num_gpus_);
  }
  #pragma omp parallel for schedule(static) num_threads(num_threads_)
  for (int device_id = 0; device_id < num_gpus_; ++device_id) {
    CUDASUCCESS_OR_FATAL(cudaSetDevice(device_id));
    device_leaf_splits_initializers_[device_id]->Init();
    device_histogram_constructors_[device_id]->Init();
    device_splitters_[device_id]->Init();
  }
  Log::Warning("NewCUDATreeLearner::CreateCUDAHistogramConstructors step 6", num_gpus_);
  PushDataIntoDeviceHistogramConstructors();
  Log::Warning("NewCUDATreeLearner::CreateCUDAHistogramConstructors step 7", num_gpus_);*/
}

void NewCUDATreeLearner::PushDataIntoDeviceHistogramConstructors() {
  /*#pragma omp parallel for schedule(static) num_threads(num_threads_)
  for (int device_id = 0; device_id < num_gpus_; ++device_id) {
    CUDASUCCESS_OR_FATAL(cudaSetDevice(device_id));
    CUDAHistogramConstructor* cuda_histogram_constructor = device_histogram_constructors_[device_id].get();
    for (int group_id : device_feature_groups_[device_id]) {
      BinIterator* iter = train_data_->FeatureGroupIterator(group_id);
      iter->Reset(0);
      for (data_size_t data_index = 0; data_index < num_data_; ++data_index) {
        const uint32_t bin = static_cast<uint32_t>(iter->RawGet(data_index));
        CHECK_LE(bin, 255);
        cuda_histogram_constructor->PushOneData(bin, group_id, data_index);
      }
    }
    // call finish load to tranfer data from CPU to GPU
    cuda_histogram_constructor->FinishLoad();
  }*/
}

void NewCUDATreeLearner::FindBestSplits(const Tree* tree) {
  /*std::vector<int8_t> is_feature_used(num_features_, 1);
  ConstructHistograms(is_feature_used, true);
  FindBestSplitsFromHistograms(is_feature_used, true, tree);*/
}

void NewCUDATreeLearner::ConstructHistograms(const std::vector<int8_t>& /*is_feature_used*/,
  bool /*use_subtract*/) {
  /*#pragma omp parallel for schedule(static) num_threads(num_threads_)
  for (int device_id = 0; device_id < num_gpus_; ++device_id) {
    CUDASUCCESS_OR_FATAL(cudaSetDevice(device_id));
    
  }*/
}

void NewCUDATreeLearner::FindBestSplitsFromHistograms(const std::vector<int8_t>& /*is_feature_used*/,
  bool /*use_subtract*/, const Tree* /*tree*/) {
  /*#pragma omp parallel for schedule(static) num_threads(num_threads_)
  for (int device_id = 0; device_id < num_gpus_; ++device_id) {
    CUDASUCCESS_OR_FATAL(cudaSetDevice(device_id));
    device_best_split_finders_[device_id]->FindBestSplitsForLeaf(
      device_leaf_splits_initializers_[device_id]->smaller_leaf_index());
    device_best_split_finders_[device_id]->FindBestSplitsForLeaf(
      device_leaf_splits_initializers_[device_id]->larger_leaf_index());
    device_best_split_finders_[device_id]->FindBestFromAllSplits();
  }*/
}

void NewCUDATreeLearner::Split(Tree* /*tree*/, int /*best_leaf*/,
  int* /*left_leaf*/, int* /*right_leaf*/) {
  /*#pragma omp parallel for schedule(static) num_threads(num_threads_)
  for (int device_id = 0; device_id < num_gpus_; ++device_id) {
    CUDASUCCESS_OR_FATAL(cudaSetDevice(device_id));
    device_splitters_[device_id]->Split(
      device_best_split_finders_[device_id]->best_leaf(),
      device_best_split_finders_[device_id]->best_split_feature_index(),
      device_best_split_finders_[device_id]->best_split_threshold());
  }*/
}

Tree* NewCUDATreeLearner::Train(const score_t* gradients,
  const score_t *hessians, bool /*is_first_tree*/) {
  gradients_ = gradients;
  hessians_ = hessians;
  BeforeTrain();
  cuda_histogram_constructor_->ConstructHistogramForLeaf(
    cuda_smaller_leaf_splits_->cuda_leaf_index(),
    cuda_larger_leaf_splits_->cuda_leaf_index(),
    cuda_smaller_leaf_splits_->cuda_data_indices_in_leaf(),
    cuda_larger_leaf_splits_->cuda_data_indices_in_leaf(),
    cuda_data_partition_->cuda_leaf_num_data_offsets());
  /*CUDASUCCESS_OR_FATAL(cudaSetDevice(0));
  CUDASUCCESS_OR_FATAL(cudaMemcpy(device_gradients_[0], gradients, num_data_ * sizeof(score_t), cudaMemcpyHostToDevice));
  CUDASUCCESS_OR_FATAL(cudaMemcpy(device_hessians_[0], hessians, num_data_ * sizeof(score_t), cudaMemcpyHostToDevice));
  #pragma omp parallel for schedule(static) num_threads(num_threads_)
  for (data_size_t i = 0; i < num_data_; ++i) {
    gradients_and_hessians_[2 * i] = gradients[i];
    gradients_and_hessians_[2 * i + 1] = hessians[i];
  }
  CopyFromHostToCUDADevice(device_gradients_and_hessians_[0], gradients_and_hessians_.data(), 2 * static_cast<size_t>(num_data_));
  Log::Warning("before initialization of leaf splits");
  device_leaf_splits_initializers_[0]->Compute();
  Log::Warning("after initialization of leaf splits");
  device_splitters_[0]->BeforeTrain(nullptr);
  Log::Warning("after initialization of data indices");
  device_histogram_constructors_[0]->ConstructHistogramForLeaf(device_leaf_splits_initializers_[0]->smaller_leaf_index(),
    device_leaf_splits_initializers_[0]->larger_leaf_index(),
    device_splitters_[0]->leaf_num_data(), device_splitters_[0]->leaf_num_data_offsets(),
    device_splitters_[0]->data_indices(), device_gradients_[0], device_hessians_[0], device_gradients_and_hessians_[0]);
  Log::Warning("after construction of root histograms");*/
  return nullptr;
}

void NewCUDATreeLearner::ResetTrainingData(const Dataset* /*train_data*/,
                         bool /*is_constant_hessian*/) {}

void NewCUDATreeLearner::SetBaggingData(const Dataset* /*subset*/,
  const data_size_t* /*used_indices*/, data_size_t /*num_data*/) {}

}  // namespace LightGBM

#endif  // USE_CUDA
