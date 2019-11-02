/*!
 * Copyright (c) 2016 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for license information.
 */

#include "serial_tree_learner.h"
#include <queue>

namespace LightGBM {

Tree* SymmetricTreeShareThresholdRefreshLearner::Train(const score_t* gradients, const score_t *hessians, bool is_constant_hessian,
              Json& /*forced_split_json*/) {
  sum_gradients_ = 0.0;
  sum_hessians_ = 0.0;
  gradients_ = gradients;
  hessians_ = hessians;
  is_constant_hessian_ = is_constant_hessian;
  hist_time_ = std::chrono::duration<double>(0.0);
  find_split_time_ = std::chrono::duration<double>(0.0);
  auto set_share_time = std::chrono::duration<double>(0.0);
  auto intialize_time = std::chrono::duration<double>(0.0);
  auto split_time = std::chrono::duration<double>(0.0);
  auto sort_time = std::chrono::duration<double>(0.0);
  auto before_time = std::chrono::duration<double>(0.0);
  auto train_tree_start_time = std::chrono::steady_clock::now();
  #ifdef TIMETAG
  auto start_time = std::chrono::steady_clock::now();
  #endif
  // some initial works before training
  auto before_time_start = std::chrono::steady_clock::now();
  BeforeTrain();
  before_time += (std::chrono::steady_clock::now() - before_time_start);

  #ifdef TIMETAG
  init_train_time += std::chrono::steady_clock::now() - start_time;
  #endif

  auto tree = std::unique_ptr<Tree>(new Tree(config_->num_leaves));
  // root leaf
  int left_leaf = 0;
  // only root leaf can be splitted on first time
  int right_leaf = -1;
  
  std::vector<SplitInfo> level_splits;
  std::queue<int> level_leaf_queue;
  bool is_left_right_update = false;
  used_features_.clear();
  is_feature_used_.clear();
  is_feature_used_.resize(num_features_, 1);
  prev_features_used_.clear();
  prev_features_used_.resize(num_features_, 1);
  for(int level = 0; level < config_->max_depth; ++level) {
      std::queue<int> next_level_leaf_queue;
      if(level == 0) {
          auto root_time_start = std::chrono::steady_clock::now();
          BeforeFindBestSplit(tree.get(), left_leaf, right_leaf);
          before_time += std::chrono::steady_clock::now() - root_time_start;
          FindBestSplits();
          Log::Warning("root time for histogram %f s", (static_cast<std::chrono::duration<double>>(std::chrono::steady_clock::now() - root_time_start)).count());
          is_feature_used_.clear();
          is_feature_used_.resize(num_features_, 0);
          for(int feature_index = 0; feature_index < num_features_; ++feature_index) {
              level_splits.push_back(splits_per_leaf_[feature_index]);
          }
          auto sort_time_start = std::chrono::steady_clock::now();
          std::sort(level_splits.begin(), level_splits.end(), [] (SplitInfo a, SplitInfo b) { return a.gain > b.gain; });
          //SetOrderedBin(level_splits);
          Log::Warning("sort time for histogram %f s", (static_cast<std::chrono::duration<double>>(std::chrono::steady_clock::now() - sort_time_start)).count());
          int best_leaf = 0;
          auto split_start_time = std::chrono::steady_clock::now();
          Split(tree.get(), best_leaf, &left_leaf, &right_leaf);
          split_time += std::chrono::steady_clock::now() - split_start_time;
          for(int i = 0; i < config_->symmetric_cycle && i < num_features_; ++i) {
            int inner_feature_idx = train_data_->InnerFeatureIndex(level_splits[i].feature);
            used_features_.push_back(inner_feature_idx);
            is_feature_used_[inner_feature_idx] = 1;
          }
          auto init_start_time = std::chrono::steady_clock::now();
          InitializeThresholdStats(1 << (config_->max_depth - 1));
          intialize_time += std::chrono::steady_clock::now() - init_start_time;
          is_left_right_update = true;
          next_level_leaf_queue.push(left_leaf);
          next_level_leaf_queue.push(right_leaf);
          cur_leaf_id_in_level_ = 0;
      }
      else {
        int level_size = static_cast<int>(level_leaf_queue.size());
        while(!level_leaf_queue.empty()) {
            int best_leaf = level_leaf_queue.front();
            const int node_in_level = level_size - static_cast<int>(level_leaf_queue.size());
            if(is_left_right_update) {
              auto before_time_start = std::chrono::steady_clock::now();
              BeforeFindBestSplit(tree.get(), left_leaf, right_leaf);
              before_time += std::chrono::steady_clock::now() - before_time_start;
              FindBestSplitForFeature(left_leaf, right_leaf, -1, -1);
              cur_leaf_id_in_level_ += 2;
            }
            if(node_in_level == 0) {
              feature_threshold_gain_ = next_feature_threshold_gain_;
              feature_threshold_split_info_ = next_feature_threshold_split_info_;
              prev_features_used_.clear();
              prev_features_used_.resize(num_features_, 0);
              for(int i = 0; i < static_cast<int>(used_features_.size()); ++i) {
                prev_features_used_[used_features_[i]] = 1;
              }
              bool need_refresh =  level % config_->symmetric_cycle == config_->symmetric_cycle - 1;
              auto set_share_threshold_start = std::chrono::steady_clock::now();
              SetShareThreshold(level_leaf_queue, level % config_->symmetric_cycle == 0);
              set_share_time += std::chrono::steady_clock::now() - set_share_threshold_start;
              auto init_start_time = std::chrono::steady_clock::now();
              if(level < config_->max_depth - 1) {
                if(need_refresh) {
                  RefreshTopFeatures();
                }
                if(need_refresh || level % config_->symmetric_cycle == 0) {
                  InitializeThresholdStats(1 << (config_->max_depth - 1));
                }
                //ClearGainVector();
              }
              intialize_time += static_cast<std::chrono::duration<double>>(std::chrono::steady_clock::now() - init_start_time);
              CHECK(cur_leaf_id_in_level_ == level_size || level == config_->max_depth - 1);
              cur_leaf_id_in_level_ = 0;
            }

            level_leaf_queue.pop();
            auto split_start_time = std::chrono::steady_clock::now();
            Split(tree.get(), best_leaf, &left_leaf, &right_leaf);
            split_time += std::chrono::steady_clock::now() - split_start_time;
            is_left_right_update = level < config_->max_depth - 1;

            next_level_leaf_queue.push(left_leaf);
            next_level_leaf_queue.push(right_leaf);
        }
      }
      level_leaf_queue = next_level_leaf_queue;
      if(level_leaf_queue.empty()) {
        break;
      }
  }
  Log::Warning("histogram time %f s", hist_time_.count());
  Log::Warning("find best split from histogram time %f s", find_split_time_.count());
  Log::Warning("train tree with histogram time %f s", (static_cast<std::chrono::duration<double>>(std::chrono::steady_clock::now() - train_tree_start_time)).count());
  Log::Warning("set share threshold for histogram time %f s", set_share_time.count());
  Log::Warning("split for histogram time %f s", split_time.count());
  Log::Warning("before time for histogram %f s", before_time.count());
  Log::Warning("init_mem_time for histogram %f s", intialize_time.count());
  return tree.release();
}

void SymmetricTreeShareThresholdRefreshLearner::FindBestSplitForFeature(int left_leaf, int right_leaf, int /*left_inner_feature_index*/, int /*right_inner_feature_index*/) {

  #ifdef TIMETAG
  auto start_time = std::chrono::steady_clock::now();
  #endif

  int smaller_in_level = cur_leaf_id_in_level_;
  int larger_in_level = cur_leaf_id_in_level_ + 1;
  int left_leaf_data_count = GetGlobalDataCountInLeaf(left_leaf);
  int right_leaf_data_count = GetGlobalDataCountInLeaf(right_leaf);
  if(right_leaf != -1 && left_leaf_data_count >= right_leaf_data_count) {
    smaller_in_level = cur_leaf_id_in_level_ + 1;
    larger_in_level = cur_leaf_id_in_level_;
  }

  auto hist_start_time = std::chrono::steady_clock::now();
  // construct smaller leaf
  HistogramBinEntry* ptr_smaller_leaf_hist_data = smaller_leaf_histogram_array_[0].RawData() - 1;
  train_data_->ConstructHistograms(is_feature_used_,
                                  smaller_leaf_splits_->data_indices(), smaller_leaf_splits_->num_data_in_leaf(),
                                  smaller_leaf_splits_->LeafIndex(),
                                  ordered_bins_, gradients_, hessians_,
                                  ordered_gradients_.data(), ordered_hessians_.data(), is_constant_hessian_,
                                  ptr_smaller_leaf_hist_data);
  if(right_leaf != -1) {
    //construct larger leaf
    HistogramBinEntry* ptr_larger_leaf_hist_data = larger_leaf_histogram_array_[0].RawData() - 1;
    std::vector<int8_t> tmp_is_feature_used(num_features_, 0);
    bool need_construct_larger_histogram = false;
    for(int i = 0; i < num_features_; ++i) {
      if(is_feature_used_[i] && !prev_features_used_[i]) {
        tmp_is_feature_used[i] = 1;
        need_construct_larger_histogram = true;
      }
    }
    if(need_construct_larger_histogram) {
      train_data_->ConstructHistograms(tmp_is_feature_used,
                                        larger_leaf_splits_->data_indices(), larger_leaf_splits_->num_data_in_leaf(),
                                        larger_leaf_splits_->LeafIndex(),
                                        ordered_bins_, gradients_, hessians_,
                                        ordered_gradients_.data(), ordered_hessians_.data(), is_constant_hessian_,
                                        ptr_larger_leaf_hist_data);
    }
  }

  hist_time_ += static_cast<std::chrono::duration<double>>(std::chrono::steady_clock::now() - hist_start_time);

  auto find_split_start_time = std::chrono::steady_clock::now();
  //find best threshold for smaller leaf
  #pragma omp parallel for schedule(static) num_threads(config_->num_threads)
  for(size_t i = 0; i < used_features_.size(); ++i) {
    SplitInfo smaller_split;
    int smaller_inner_feature_index = used_features_[i];
    train_data_->FixHistogram(smaller_inner_feature_index,
                              smaller_leaf_splits_->sum_gradients(), smaller_leaf_splits_->sum_hessians(),
                              smaller_leaf_splits_->num_data_in_leaf(),
                              smaller_leaf_histogram_array_[smaller_inner_feature_index].RawData());
    int smaller_real_fidx = train_data_->RealFeatureIndex(smaller_inner_feature_index);
    smaller_leaf_histogram_array_[smaller_inner_feature_index].FindBestThreshold(
      smaller_leaf_splits_->sum_gradients(),
      smaller_leaf_splits_->sum_hessians(),
      smaller_leaf_splits_->num_data_in_leaf(),
      smaller_leaf_splits_->min_constraint(),
      smaller_leaf_splits_->max_constraint(),
      &smaller_split,
      &next_feature_threshold_gain_[i],
      &next_feature_threshold_split_info_[i][smaller_in_level]);
    smaller_split.feature = smaller_real_fidx;
  }

  if(right_leaf != -1) {
    #pragma omp parallel for schedule(static) num_threads(config_->num_threads)
    for(size_t i = 0; i < used_features_.size(); ++i) {
      SplitInfo larger_split;
      int larger_inner_feature_index = used_features_[i];
      if(prev_features_used_[larger_inner_feature_index]) {
        larger_leaf_histogram_array_[larger_inner_feature_index].Subtract(smaller_leaf_histogram_array_[larger_inner_feature_index]);
      }
      train_data_->FixHistogram(larger_inner_feature_index,
                                larger_leaf_splits_->sum_gradients(), larger_leaf_splits_->sum_hessians(),
                                larger_leaf_splits_->num_data_in_leaf(),
                                larger_leaf_histogram_array_[larger_inner_feature_index].RawData());
      int larger_real_fidx = train_data_->RealFeatureIndex(larger_inner_feature_index);
      larger_leaf_histogram_array_[larger_inner_feature_index].FindBestThreshold(
        larger_leaf_splits_->sum_gradients(),
        larger_leaf_splits_->sum_hessians(),
        larger_leaf_splits_->num_data_in_leaf(),
        larger_leaf_splits_->min_constraint(),
        larger_leaf_splits_->max_constraint(),
        &larger_split,
        &next_feature_threshold_gain_[i],
        &next_feature_threshold_split_info_[i][larger_in_level]);
      larger_split.feature = larger_real_fidx;
    }
  }
  find_split_time_ += std::chrono::steady_clock::now() - find_split_start_time;
}

void SymmetricTreeShareThresholdRefreshLearner::SetShareThreshold(const std::queue<int>& level_leaf_queue, bool need_refresh) {
  std::queue<int> copy_level_leaf_queue = level_leaf_queue;
  uint32_t best_threshold = 0;
  int best_dir = -1;
  double best_gain = kMinScore;
  size_t best_i = 0;
  std::vector<double> feature_best_gain(num_features_, kMinScore);
  CHECK(feature_threshold_gain_.size() >= used_features_.size());
  for(size_t i = 0; i < feature_threshold_gain_.size(); ++i) {
    for(size_t j = 0; j < feature_threshold_gain_[i].size(); ++j) {
      if(feature_threshold_gain_[i][j][0] > best_gain) {
        best_gain = feature_threshold_gain_[i][j][0];
        best_threshold = j;
        best_dir = 0;
        best_i = i;
        int inner_feature = used_features_[i];
        if(best_gain > feature_best_gain[inner_feature]) {
          feature_best_gain[inner_feature] = best_gain;
        }
      }
      if(feature_threshold_gain_[i][j][1] > best_gain) {
        best_gain = feature_threshold_gain_[i][j][1];
        best_threshold = j;
        best_dir = 1;
        best_i = i;
        int inner_feature = used_features_[i];
        if(best_gain > feature_best_gain[inner_feature]) {
          feature_best_gain[inner_feature] = best_gain;
        }
      }
    }
  }
  int feature = train_data_->RealFeatureIndex(used_features_[best_i]);
  int cur_leaf_id_in_level = 0;
  double tmp_sum_gradients = 0.0, tmp_sum_hessians = 0.0;
  bool is_first = false;
  if(sum_gradients_ == 0.0 && sum_hessians_ == 0.0) {
    is_first = true;
  }
  while(!copy_level_leaf_queue.empty()) {
    int leaf = copy_level_leaf_queue.front();
    copy_level_leaf_queue.pop();
    best_split_per_leaf_[leaf] = feature_threshold_split_info_[best_i][cur_leaf_id_in_level][best_threshold][best_dir];
    best_split_per_leaf_[leaf].feature = feature;
    SplitInfo& split_info = best_split_per_leaf_[leaf];
    split_info.left_output = FeatureHistogram::CalculateSplittedLeafOutput(split_info.left_sum_gradient, split_info.left_sum_hessian, config_->lambda_l1, config_->lambda_l2, config_->max_delta_step);
    split_info.right_output = FeatureHistogram::CalculateSplittedLeafOutput(split_info.right_sum_gradient, split_info.right_sum_hessian, config_->lambda_l1, config_->lambda_l2, config_->max_delta_step);

    CHECK(feature == split_info.feature);
    if(is_first) {
      sum_gradients_ += split_info.left_sum_gradient;
      sum_hessians_ += split_info.left_sum_hessian;
      sum_gradients_ += split_info.right_sum_gradient;
      sum_hessians_ += split_info.right_sum_hessian;
    }
    else {
      tmp_sum_gradients += split_info.left_sum_gradient;
      tmp_sum_hessians += split_info.left_sum_hessian;
      tmp_sum_gradients += split_info.right_sum_gradient;
      tmp_sum_hessians += split_info.right_sum_hessian;
    }
    ++cur_leaf_id_in_level;
  }
  if(!is_first) {
    if(std::fabs(sum_gradients_ - tmp_sum_gradients) > 1e-6) {
      Log::Warning("sum_gradients %f, tmp_sum_gradients %f, feature %d, threshold %d", sum_gradients_, tmp_sum_gradients, feature, best_threshold);
    }
    CHECK(std::fabs(sum_gradients_ - tmp_sum_gradients) <= 1e-6);
    if(std::fabs(sum_hessians_ - tmp_sum_hessians) > 1e-6) {
      Log::Warning("sum_hessians %f, tmp_sum_hessians %f, feature %d, threshold %d", sum_hessians_, tmp_sum_hessians, feature, best_threshold);
    }
    CHECK(std::fabs(sum_hessians_ - tmp_sum_hessians) <= 1e-6);
  }

  if(need_refresh) {
    used_features_.clear();
    used_features_.resize(num_features_, 0);
    for(int i = 0; i < num_features_; ++i) {
      used_features_[i] = i;
    }
    std::sort(used_features_.begin(), used_features_.end(), [&feature_best_gain](int a, int b) { return feature_best_gain[a] > feature_best_gain[b]; });
    used_features_.resize(config_->symmetric_cycle);
    is_feature_used_.clear();
    is_feature_used_.resize(num_features_, 0);
    for(int inner_feature : used_features_) {
      is_feature_used_[inner_feature] = 1;
    }
  }
}

void SymmetricTreeShareThresholdRefreshLearner::InitializeThresholdStats(const size_t level_size) {
  next_feature_threshold_gain_.resize(used_features_.size());
  #pragma omp parallel for schedule(static) num_threads(config_->num_threads)
  for(size_t i = 0; i < next_feature_threshold_gain_.size(); ++i) {
    int num_bin = train_data_->FeatureBinMapper(used_features_[i])->num_bin();
    next_feature_threshold_gain_[i].resize(num_bin);
    for(int j = 0; j < num_bin; ++j) {
      next_feature_threshold_gain_[i][j].resize(2, 0.0);
      next_feature_threshold_gain_[i][j][0] = 0.0;
      next_feature_threshold_gain_[i][j][1] = 0.0;
    }
  }

  next_feature_threshold_split_info_.resize(used_features_.size());
  #pragma omp parallel for schedule(static) num_threads(config_->num_threads)
  for(size_t i = 0; i < next_feature_threshold_split_info_.size(); ++i) {
    next_feature_threshold_split_info_[i].clear();
    next_feature_threshold_split_info_[i].resize(level_size);
    for(size_t j = 0; j < level_size; ++j) {
      next_feature_threshold_split_info_[i][j].resize(train_data_->FeatureBinMapper(used_features_[i])->num_bin());
      for(size_t k = 0; k < next_feature_threshold_split_info_[i][j].size(); ++k) {
        next_feature_threshold_split_info_[i][j][k].resize(2);
      }
    }
  }
}

void SymmetricTreeShareThresholdRefreshLearner::ClearGainVector() {
  #pragma omp parallel for schedule(static) num_threads(config_->num_threads)
  for(size_t i = 0; i < used_features_.size(); ++i) {
    int num_bin = train_data_->FeatureBinMapper(used_features_[i])->num_bin();
    next_feature_threshold_gain_[i].resize(num_bin);
    for(int j = 0; j < num_bin; ++j) {
      next_feature_threshold_gain_[i][j].resize(2, 0.0);
      next_feature_threshold_gain_[i][j][0] = 0.0;
      next_feature_threshold_gain_[i][j][1] = 0.0;
    }
  }
}

void SymmetricTreeShareThresholdRefreshLearner::RefreshTopFeatures() {
  is_feature_used_.clear();
  is_feature_used_.resize(num_features_, 1);
  used_features_.clear();
  for(int i = 0; i < num_features_; ++i) {
    used_features_.push_back(i);
  }
}

void SymmetricTreeShareThresholdRefreshLearner::SetOrderedBin(const std::vector<SplitInfo>& level_split) {
  ordered_bin_indices_.clear();
  std::vector<bool> group_has_used_ordered_bin(train_data_->num_feature_groups(), false);
  for(int i = 0; i < config_->symmetric_cycle; ++i) {
    int inner_feature = train_data_->InnerFeatureIndex(level_split[i].feature);
    int group = train_data_->Feature2Group(inner_feature);
    if(ordered_bins_[group] != nullptr) {
      group_has_used_ordered_bin[group] = true;
    }
  }
  for(int i = 0; i < static_cast<int>(group_has_used_ordered_bin.size()); ++i) {
    if(group_has_used_ordered_bin[i]) {
      ordered_bin_indices_.push_back(i);
    }
  }
}

} // namespace LightGBM