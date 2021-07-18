/*!
 * Copyright (c) 2021 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for
 * license information.
 */

#ifdef USE_CUDA

#include "cuda_regression_objective.hpp"
/*
namespace LightGBM {

CUDARegressionObjective::CUDARegressionObjective(const data_size_t num_data, const label_t* cuda_labels):
CUDAObjective(num_data), cuda_labels_(cuda_labels) {}

void CUDARegressionObjective::Init() {
  AllocateCUDAMemory<double>(1, &cuda_init_score_);
  SetCUDAMemory<double>(cuda_init_score_, 0, 1);
}

void CUDARegressionObjective::GetGradients(const double* cuda_scores, score_t* cuda_out_gradients, score_t* cuda_out_hessians) {
  LaunchGetGradientsKernel(cuda_scores, cuda_out_gradients, cuda_out_hessians);
}

void CUDARegressionObjective::CalcInitScore() {
  LaunchCalcInitScoreKernel();  
}

}  // namespace LightGBM
*/
#endif  // USE_CUDA
