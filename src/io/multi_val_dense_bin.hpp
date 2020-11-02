/*!
 * Copyright (c) 2020 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for license information.
 */
#ifndef LIGHTGBM_IO_MULTI_VAL_DENSE_BIN_HPP_
#define LIGHTGBM_IO_MULTI_VAL_DENSE_BIN_HPP_

#include <LightGBM/bin.h>
#include <LightGBM/utils/openmp_wrapper.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <vector>

namespace LightGBM {

template <typename VAL_T>
class MultiValDenseBin : public MultiValBin {
 public:
  explicit MultiValDenseBin(data_size_t num_data, int num_bin, int num_feature, 
    const std::vector<uint32_t>& offsets)
    : num_data_(num_data), num_bin_(num_bin), num_feature_(num_feature),
      offsets_(offsets) {
    data_.resize(static_cast<size_t>(num_data_) * num_feature_, static_cast<VAL_T>(0));
  }

  ~MultiValDenseBin() {
  }

  data_size_t num_data() const override {
    return num_data_;
  }

  int num_bin() const override {
    return num_bin_;
  }

  double num_element_per_row() const override { return num_feature_; }

  std::vector<uint32_t> offsets() const override { return offsets_; }

  void PushOneRow(int , data_size_t idx, const std::vector<uint32_t>& values) override {
    auto start = RowPtr(idx);
    for (auto i = 0; i < num_feature_; ++i) {
      data_[start + i] = static_cast<VAL_T>(values[i]);
    }
  }

  void FinishLoad() override {
  }

  bool IsSparse() override {
    return false;
  }

  #include <x86intrin.h>

  template<bool USE_INDICES, bool USE_PREFETCH, bool ORDERED>
  void ConstructHistogramInner(const data_size_t* data_indices, data_size_t start, data_size_t end,
    const score_t* gradients, const score_t* hessians, float* out) const {
    data_size_t i = start;
    float* grad = out;
    float* hess = out + 1;
    const uint32_t* offsets_ptr = offsets_.data();
    const int blend_bits = 0xaa;
    const int vec_end = num_feature_ - num_feature_ % 4;
    if (USE_PREFETCH) {
      const data_size_t pf_offset = 32 / sizeof(VAL_T);
      const data_size_t pf_end = end - pf_offset;

      for (; i < pf_end; ++i) {
        const auto idx = USE_INDICES ? data_indices[i] : i;
        const auto pf_idx = USE_INDICES ? data_indices[i + pf_offset] : i + pf_offset;
        if (!ORDERED) {
          PREFETCH_T0(gradients + pf_idx);
          PREFETCH_T0(hessians + pf_idx);
        }
        PREFETCH_T0(data_.data() + RowPtr(pf_idx));
        const auto j_start = RowPtr(idx);
        const VAL_T* data_ptr = data_.data() + j_start;
        const score_t gradient = ORDERED ? gradients[i] : gradients[idx];
        const score_t hessian = ORDERED ? hessians[i] : hessians[idx];
        __m256 g_vec = _mm256_broadcast_ss(&gradient);
        __m256 h_vec = _mm256_broadcast_ss(&hessian);
        __m256 gh_vec = _mm256_blend_ps(g_vec, h_vec, blend_bits);
        int j = 0;
        for (; j < vec_end; j += 4) {
          const uint32_t bin0 = static_cast<uint32_t>(data_ptr[j]);
          const auto ti0 = (bin0 + offsets_ptr[j]) << 1;
          __m64* hist0_pos = reinterpret_cast<__m64*>(grad + ti0);
          
          __m128 hist0;
          hist0 = _mm_loadl_pi(hist0, hist0_pos);
          const uint32_t bin1 = static_cast<uint32_t>(data_ptr[j + 1]);
          const auto ti1 = (bin1 + offsets_ptr[j + 1]) << 1;
          __m64* hist1_pos = reinterpret_cast<__m64*>(grad + ti1);
          hist0 = _mm_loadh_pi(hist0, hist1_pos);

          const uint32_t bin2 = static_cast<uint32_t>(data_ptr[j + 2]);
          const auto ti2 = (bin2 + offsets_ptr[j + 2]) << 1;
          __m64* hist2_pos = reinterpret_cast<__m64*>(grad + ti2);

          __m128 hist2;
          hist2 = _mm_loadl_pi(hist2, hist2_pos);
          const uint32_t bin3 = static_cast<uint32_t>(data_ptr[j + 3]);
          const auto ti3 = (bin3 + offsets_ptr[j + 3]) << 1;
          __m64* hist3_pos = reinterpret_cast<__m64*>(grad + ti3);
          hist2 = _mm_loadh_pi(hist2, hist3_pos);

          __m256 hist = _mm256_castps128_ps256(hist0);
          hist = _mm256_insertf128_ps(hist, hist2, 1);

          hist = _mm256_add_ps(hist, gh_vec);

          __m128 res1 = _mm256_extractf128_ps(hist, 1);
          __m128 res0 = _mm256_castps256_ps128(hist);

          _mm_storel_pi(hist0_pos, res0);
          _mm_storeh_pi(hist1_pos, res0);
          _mm_storel_pi(hist2_pos, res1);
          _mm_storeh_pi(hist3_pos, res1);
        }

        for (; j < num_feature_; ++j) {
          const uint32_t bin = static_cast<uint32_t>(data_ptr[j]);
          const auto ti = (bin + offsets_ptr[j]) << 1;
          grad[ti] += gradient;
          hess[ti] += hessian;
        }
      }
    }
    for (; i < end; ++i) {
      const auto idx = USE_INDICES ? data_indices[i] : i;
      const auto j_start = RowPtr(idx);
      const VAL_T* data_ptr = data_.data() + j_start;
      const score_t gradient = ORDERED ? gradients[i] : gradients[idx];
      const score_t hessian = ORDERED ? hessians[i] : hessians[idx];
      __m256 g_vec = _mm256_broadcast_ss(&gradient);
      __m256 h_vec = _mm256_broadcast_ss(&hessian);
      __m256 gh_vec = _mm256_blend_ps(g_vec, h_vec, blend_bits);
      int j = 0;
      for (; j < vec_end; j += 4) {
        const uint32_t bin0 = static_cast<uint32_t>(data_ptr[j]);
        const auto ti0 = (bin0 + offsets_ptr[j]) << 1;
        __m64* hist0_pos = reinterpret_cast<__m64*>(grad + ti0);
        
        __m128 hist0;
        hist0 = _mm_loadl_pi(hist0, hist0_pos);
        const uint32_t bin1 = static_cast<uint32_t>(data_ptr[j + 1]);
        const auto ti1 = (bin1 + offsets_ptr[j + 1]) << 1;
        __m64* hist1_pos = reinterpret_cast<__m64*>(grad + ti1);
        hist0 = _mm_loadh_pi(hist0, hist1_pos);

        const uint32_t bin2 = static_cast<uint32_t>(data_ptr[j + 2]);
        const auto ti2 = (bin2 + offsets_ptr[j + 2]) << 1;
        __m64* hist2_pos = reinterpret_cast<__m64*>(grad + ti2);

        __m128 hist2;
        hist2 = _mm_loadl_pi(hist2, hist2_pos);
        const uint32_t bin3 = static_cast<uint32_t>(data_ptr[j + 3]);
        const auto ti3 = (bin3 + offsets_ptr[j + 3]) << 1;
        __m64* hist3_pos = reinterpret_cast<__m64*>(grad + ti3);
        hist2 = _mm_loadh_pi(hist2, hist3_pos);

        __m256 hist = _mm256_castps128_ps256(hist0);
        hist = _mm256_insertf128_ps(hist, hist2, 1);

        hist = _mm256_add_ps(hist, gh_vec);

        __m128 res1 = _mm256_extractf128_ps(hist, 1);
        __m128 res0 = _mm256_castps256_ps128(hist);

        _mm_storel_pi(hist0_pos, res0);
        _mm_storeh_pi(hist1_pos, res0);
        _mm_storel_pi(hist2_pos, res1);
        _mm_storeh_pi(hist3_pos, res1);
      }

      for (; j < num_feature_; ++j) {
        const uint32_t bin = static_cast<uint32_t>(data_ptr[j]);
        const auto ti = (bin + offsets_ptr[j]) << 1;
        grad[ti] += gradient;
        hess[ti] += hessian;
      }
    }
  }

  void ConstructHistogram(const data_size_t* data_indices, data_size_t start,
                          data_size_t end, const score_t* gradients,
                          const score_t* hessians, float* out) const override {
    ConstructHistogramInner<true, true, false>(data_indices, start, end,
                                               gradients, hessians, out);
  }

  void ConstructHistogram(data_size_t start, data_size_t end,
                          const score_t* gradients, const score_t* hessians,
                          float* out) const override {
    ConstructHistogramInner<false, false, false>(
        nullptr, start, end, gradients, hessians, out);
  }

  void ConstructHistogramOrdered(const data_size_t* data_indices,
                                 data_size_t start, data_size_t end,
                                 const score_t* gradients,
                                 const score_t* hessians,
                                 float* out) const override {
    ConstructHistogramInner<true, true, true>(data_indices, start, end,
                                              gradients, hessians, out);
  }

  MultiValBin* CreateLike(data_size_t num_data, int num_bin, int num_feature, double, const std::vector<uint32_t>& offsets) const override {
    return new MultiValDenseBin<VAL_T>(num_data, num_bin, num_feature, offsets);
  }

  void ReSize(data_size_t num_data, int num_bin, int num_feature,
              double, const std::vector<uint32_t>& offsets) override {
    num_data_ = num_data;
    num_bin_ = num_bin;
    num_feature_ = num_feature;
    offsets_ = offsets;
    size_t new_size = static_cast<size_t>(num_feature_) * num_data_;
    if (data_.size() < new_size) {
      data_.resize(new_size, 0);
    }
  }

  template <bool SUBROW, bool SUBCOL>
  void CopyInner(const MultiValBin* full_bin, const data_size_t* used_indices,
                 data_size_t num_used_indices,
                 const std::vector<int>& used_feature_index,
                 const std::vector<uint32_t>& delta) {
    const auto other_bin =
        reinterpret_cast<const MultiValDenseBin<VAL_T>*>(full_bin);
    if (SUBROW) {
      CHECK_EQ(num_data_, num_used_indices);
    }
    int n_block = 1;
    data_size_t block_size = num_data_;
    Threading::BlockInfo<data_size_t>(num_data_, 1024, &n_block,
                                      &block_size);
#pragma omp parallel for schedule(static, 1)
    for (int tid = 0; tid < n_block; ++tid) {
      data_size_t start = tid * block_size;
      data_size_t end = std::min(num_data_, start + block_size);
      for (data_size_t i = start; i < end; ++i) {
        const auto j_start = RowPtr(i);
        const auto other_j_start =
            SUBROW ? other_bin->RowPtr(used_indices[i]) : other_bin->RowPtr(i);
        for (int j = 0; j < num_feature_; ++j) {
          if (SUBCOL) {
            if (other_bin->data_[other_j_start + used_feature_index[j]] > 0) {
              data_[j_start + j] = static_cast<VAL_T>(
                  other_bin->data_[other_j_start + used_feature_index[j]] -
                  delta[j]);
            } else {
              data_[j_start + j] = 0;
            }
          } else {
            data_[j_start + j] =
                static_cast<VAL_T>(other_bin->data_[other_j_start + j]);
          }
        }
      }
    }
  }


  void CopySubrow(const MultiValBin* full_bin, const data_size_t* used_indices,
                  data_size_t num_used_indices) override {
    CopyInner<true, false>(full_bin, used_indices, num_used_indices,
                           std::vector<int>(), std::vector<uint32_t>());
  }

  void CopySubcol(const MultiValBin* full_bin,
                  const std::vector<int>& used_feature_index,
                  const std::vector<uint32_t>&,
                  const std::vector<uint32_t>&,
                  const std::vector<uint32_t>& delta) override {
    CopyInner<false, true>(full_bin, nullptr, num_data_, used_feature_index,
                           delta);
  }

  void CopySubrowAndSubcol(const MultiValBin* full_bin,
                           const data_size_t* used_indices,
                           data_size_t num_used_indices,
                           const std::vector<int>& used_feature_index,
                           const std::vector<uint32_t>&,
                           const std::vector<uint32_t>&,
                           const std::vector<uint32_t>& delta) override {
    CopyInner<true, true>(full_bin, used_indices, num_used_indices,
                          used_feature_index, delta);
  }

  inline size_t RowPtr(data_size_t idx) const {
    return static_cast<size_t>(idx) * num_feature_;
  }

  MultiValDenseBin<VAL_T>* Clone() override;

 private:
  data_size_t num_data_;
  int num_bin_;
  int num_feature_;
  std::vector<uint32_t> offsets_;
  std::vector<VAL_T, Common::AlignmentAllocator<VAL_T, 32>> data_;

  MultiValDenseBin<VAL_T>(const MultiValDenseBin<VAL_T>& other)
    : num_data_(other.num_data_), num_bin_(other.num_bin_), num_feature_(other.num_feature_),
      offsets_(other.offsets_), data_(other.data_) {
  }
};

template<typename VAL_T>
MultiValDenseBin<VAL_T>* MultiValDenseBin<VAL_T>::Clone() {
  return new MultiValDenseBin<VAL_T>(*this);
}

}  // namespace LightGBM
#endif   // LIGHTGBM_IO_MULTI_VAL_DENSE_BIN_HPP_
