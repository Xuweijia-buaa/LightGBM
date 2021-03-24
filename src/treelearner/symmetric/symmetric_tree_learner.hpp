/*!
 * Copyright (c) 2016 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for license information.
 */
#ifndef LIGHTGBM_TREELEARNER_SYMMETRIC_TREE_LEARNER_H_
#define LIGHTGBM_TREELEARNER_SYMMETRIC_TREE_LEARNER_H_

#include "symmetric_feature_histogram.hpp"
#include "../serial_tree_learner.h"
#include "symmetric_data_partition.hpp"

namespace LightGBM {

class SymmetricTreeLearner : public SerialTreeLearner {
 public:
  explicit SymmetricTreeLearner(const Config* config);
  
  ~SymmetricTreeLearner();

  void Init(const Dataset* train_data, bool is_constant_hessian) override;

  void ResetTrainingDataInner(const Dataset* train_data,
                              bool is_constant_hessian,
                              bool reset_multi_val_bin) override;

  Tree* Train(const score_t* gradients, const score_t *hessians, bool is_first_tree) override;

  Tree* FitByExistingTree(const Tree* old_tree, const score_t* gradients, const score_t* hessians) const override;

  Tree* FitByExistingTree(const Tree* old_tree, const std::vector<int>& leaf_pred,
                          const score_t* gradients, const score_t* hessians) const override;

  void SetBaggingData(const Dataset* subset, const data_size_t* used_indices, data_size_t num_data) override;

  void AddPredictionToScore(const Tree* tree,
                            double* out_score) const override;

  void RenewTreeOutput(Tree* tree, const ObjectiveFunction* obj, std::function<double(const label_t*, int)> residual_getter,
                       data_size_t total_num_data, const data_size_t* bag_indices, data_size_t bag_cnt) const override;

  void FindBestLevelSplits();

  void FindBestLevelSplitsForFeature(const int inner_feature_index, const int thread_id);

  void SplitLevel(Tree* tree);

 protected:

  void BeforeTrain() override;

  void PrepareLevelHistograms();

  void SetUpLevelInfo(const int depth);

  SymmetricHistogramPool symmetric_histogram_pool_;
  std::vector<FeatureHistogram*> level_feature_histograms_;
  std::vector<int> leaf_ids_in_current_level_;
  SymmetricDataPartition symmetric_data_partition_;
  std::vector<std::unique_ptr<LeafSplits>> level_leaf_splits_;
  const int max_depth_;
  const int max_num_leaves_;
  const int num_threads_;

  int cur_depth_;
  int num_leaves_in_cur_level_;
  std::vector<int8_t> used_features_in_cur_level_;
  std::vector<std::vector<int>> paired_leaf_indices_in_cur_level_;
  int best_inner_feature_index_cur_level_;
  int best_threshold_cur_level_;
  double best_gain_cur_level_;
  int best_split_direction_cur_level_;
  std::vector<int8_t> best_leaf_in_level_should_be_split_;
  std::vector<int> thread_best_inner_feature_index_cur_level_;
  std::vector<int> thread_best_threshold_cur_level_;
  std::vector<double> thread_best_gain_cur_level_;
  std::vector<int8_t> thread_best_split_direction_cur_level_;
  std::vector<std::vector<int8_t>> thread_leaf_in_level_should_be_split_;
};

}  // namespace LightGBM
#endif  // LIGHTGBM_TREELEARNER_SYMMETRIC_TREE_LEARNER_H_