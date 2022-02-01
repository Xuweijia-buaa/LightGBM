/*!
 * Copyright (c) 2016 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for license information.
 */
#ifndef LIGHTGBM_NETWORK_LINKERS_H_
#define LIGHTGBM_NETWORK_LINKERS_H_

#include <LightGBM/config.h>
#include <LightGBM/meta.h>
#include <LightGBM/network.h>
#include <LightGBM/utils/common.h>

#include <string>
#include <algorithm>
#include <chrono>
#include <ctime>
#include <memory>
#include <thread>
#include <vector>

#include "../src/treelearner/histogram_compressor.hpp"

#ifdef USE_SOCKET
#include "socket_wrapper.hpp"
#endif

#ifdef USE_MPI
#include <mpi.h>
#define MPI_SAFE_CALL(mpi_return) CHECK((mpi_return) == MPI_SUCCESS)
#endif

namespace LightGBM {

/*!
* \brief A network basic communication wrapper.
* Will wrap low level communication methods, e.g. mpi, socket and so on.
* This class will wrap all linkers to other machines if needs
*/
class Linkers {
 public:
  Linkers() {
    is_init_ = false;
  }
  /*!
  * \brief Constructor
  * \param config Config of network settings
  */
  explicit Linkers(Config config);
  /*!
  * \brief Destructor
  */
  ~Linkers();
  /*!
  * \brief Recv data, blocking
  * \param rank Which rank will send data to local machine
  * \param data Pointer of receive data
  * \param len Recv size, will block until receive len size of data
  */
  template <bool USE_COMPRESS = false, int HIST_BITS = 0>
  inline void Recv(int rank, char* data, int len) const;

  template <bool USE_COMPRESS = false, int HIST_BITS = 0>
  inline void Recv(int rank, char* data, int64_t len) const;

  /*!
  * \brief Send data, blocking
  * \param rank Which rank local machine will send to
  * \param data Pointer of send data
  * \param len Send size
  */
  template <bool USE_COMPRESS = false, int HIST_BITS = 0>
  inline void Send(int rank, char* data, int len) const;

  template <bool USE_COMPRESS = false, int HIST_BITS = 0>
  inline void Send(int rank, char* data, int64_t len) const;
  /*!
  * \brief Send and Recv at same time, blocking
  * \param send_rank
  * \param send_data
  * \param send_len
  * \param recv_rank
  * \param recv_data
  * \param recv_len
  */
  template <bool USE_COMPRESS = false, int HIST_BITS = 0>
  inline void SendRecv(int send_rank, char* send_data, int send_len,
                       int recv_rank, char* recv_data, int recv_len);

  template <bool USE_COMPRESS = false, int HIST_BITS = 0>
  inline void SendRecv(int send_rank, char* send_data, int64_t send_len,
                       int recv_rank, char* recv_data, int64_t recv_len);
  /*!
  * \brief Get rank of local machine
  */
  inline int rank();
  /*!
  * \brief Get total number of machines
  */
  inline int num_machines();
  /*!
  * \brief Get Bruck map of this network
  */
  inline const BruckMap& bruck_map();
  /*!
  * \brief Get Recursive Halving map of this network
  */
  inline const RecursiveHalvingMap& recursive_halving_map();

  #ifdef USE_SOCKET
  /*!
  * \brief Bind local listen to port
  * \param port Local listen port
  */
  void TryBind(int port);
  /*!
  * \brief Set socket to rank
  * \param rank
  * \param socket
  */
  void SetLinker(int rank, const TcpSocket& socket);
  /*!
  * \brief Thread for listening
  * \param incoming_cnt Number of incoming machines
  */
  void ListenThread(int incoming_cnt);
  /*!
  * \brief Construct network topo
  */
  void Construct();
  /*!
  * \brief Parser machines information from file
  * \param machines
  * \param filename
  */
  void ParseMachineList(const std::string& machines, const std::string& filename);
  /*!
  * \brief Check one linker is connected or not
  * \param rank
  * \return True if linker is connected
  */
  bool CheckLinker(int rank);
  /*!
  * \brief Print connected linkers
  */
  void PrintLinkers();

  #endif  // USE_SOCKET

  #ifdef USE_MPI

  /*!
  * \brief Check if MPI has been initialized
  */
  static bool IsMpiInitialized();

  /*!
  * \brief Finalize the MPI session if it was initialized
  */
  static void MpiFinalizeIfIsParallel();

  /*!
  * \brief Abort the MPI session if it was initialized (called in case there was a error that needs abrupt ending)
  */
  static void MpiAbortIfIsParallel();

  #endif

 private:
  /*! \brief Rank of local machine */
  int rank_;
  /*! \brief Total number machines */
  int num_machines_;
  /*! \brief Bruck map */
  BruckMap bruck_map_;
  /*! \brief Recursive Halving map */
  RecursiveHalvingMap recursive_halving_map_;

  std::chrono::duration<double, std::milli> network_time_;

  bool is_init_;

  #ifdef USE_SOCKET
  /*! \brief use to store client ips */
  std::vector<std::string> client_ips_;
  /*! \brief use to store client ports */
  std::vector<int> client_ports_;
  /*! \brief time out for sockets, in minutes */
  int socket_timeout_;
  /*! \brief Local listen ports */
  int local_listen_port_;
  /*! \brief Linkers */
  std::vector<std::unique_ptr<TcpSocket>> linkers_;
  /*! \brief Local socket listener */
  std::unique_ptr<TcpSocket> listener_;
  mutable std::vector<uint32_t> buffer_;
  mutable std::vector<uint32_t> send_buffer_;
  #endif  // USE_SOCKET
};


inline int Linkers::rank() {
  return rank_;
}

inline int Linkers::num_machines() {
  return num_machines_;
}

inline const BruckMap& Linkers::bruck_map() {
  return bruck_map_;
}

inline const RecursiveHalvingMap& Linkers::recursive_halving_map() {
  return recursive_halving_map_;
}

template <bool USE_COMPRESS, int HIST_BITS>
inline void Linkers::Recv(int rank, char* data, int64_t len) const {
  int64_t used = 0;
  do {
    int cur_size = static_cast<int>(std::min<int64_t>(len - used, INT32_MAX));
    Recv<USE_COMPRESS, HIST_BITS>(rank, data + used, cur_size);
    used += cur_size;
  } while (used < len);
}

template <bool USE_COMPRESS, int HIST_BITS>
inline void Linkers::Send(int rank, char* data, int64_t len) const {
  int64_t used = 0;
  do {
    int cur_size = static_cast<int>(std::min<int64_t>(len - used, INT32_MAX));
    Send<USE_COMPRESS, HIST_BITS>(rank, data + used, cur_size);
    used += cur_size;
  } while (used < len);
}

template <bool USE_COMPRESS, int HIST_BITS>
inline void Linkers::SendRecv(int send_rank, char* send_data, int64_t send_len,
                              int recv_rank, char* recv_data, int64_t recv_len) {
  auto start_time = std::chrono::high_resolution_clock::now();
  std::thread send_worker(
    [this, send_rank, send_data, send_len]() {
    Send<USE_COMPRESS, HIST_BITS>(send_rank, send_data, send_len);
  });
  Recv<USE_COMPRESS, HIST_BITS>(recv_rank, recv_data, recv_len);
  send_worker.join();
  // wait for send complete
  auto end_time = std::chrono::high_resolution_clock::now();
  // output used time on each iteration
  network_time_ += std::chrono::duration<double, std::milli>(end_time - start_time);
}

#ifdef USE_SOCKET

template <bool USE_COMPRESS, int HIST_BITS>
inline void Linkers::Recv(int rank, char* data, int len) const {
  if (!USE_COMPRESS) {
    int recv_cnt = 0;
    if (HIST_BITS == -1) {
      global_timer.Start("Recv time -1");
    }
    while (recv_cnt < len) {
      recv_cnt += linkers_[rank]->Recv(data + recv_cnt,
        // len - recv_cnt
        std::min(len - recv_cnt, SocketConfig::kMaxReceiveSize));
    }
    if (HIST_BITS == -1) {
      global_timer.Stop("Recv time -1");
    }
  } else {
    int num_threads = OMP_NUM_THREADS();
    if (2 * static_cast<size_t>(len) * 20 > buffer_.size()) {
      buffer_.resize(2 * len * 20);
    }
    int recv_cnt = 0;
    int header_len = sizeof(uint32_t) * 2;
    global_timer.Start("Recv time");
    while (recv_cnt < header_len) {
      recv_cnt += linkers_[rank]->Recv(
        reinterpret_cast<char*>(buffer_.data()) + recv_cnt,
        // len - recv_cnt
        std::min(header_len - recv_cnt, SocketConfig::kMaxReceiveSize));
    }
    num_threads = static_cast<int>(*(reinterpret_cast<const uint32_t*>(buffer_.data() + 1)));

    int thread_info_len = sizeof(uint32_t) * (num_threads + 1);
    recv_cnt = 0;
    while (recv_cnt < thread_info_len) {
      recv_cnt += linkers_[rank]->Recv(
        reinterpret_cast<char*>(buffer_.data()) + header_len + recv_cnt,
        // len - recv_cnt
        std::min(thread_info_len - recv_cnt, SocketConfig::kMaxReceiveSize));
    }

    const int compressed_len = static_cast<int>(buffer_[0]);
    recv_cnt = 0;
    while (recv_cnt < compressed_len) {
      recv_cnt += linkers_[rank]->Recv(
        reinterpret_cast<char*>(buffer_.data()) + header_len + thread_info_len + recv_cnt,
        // len - recv_cnt
        std::min(compressed_len - recv_cnt, SocketConfig::kMaxReceiveSize));
    }
    global_timer.Stop("Recv time");

    HistogramCompressor hc(num_threads);
    if (HIST_BITS == 32) {
      hc.Decompress<int32_t, uint32_t>(
        reinterpret_cast<const uint8_t*>(buffer_.data()),
        len / sizeof(int32_t) / 2,
        reinterpret_cast<int32_t*>(data));
    } else if (HIST_BITS == 16) {
      hc.Decompress<int16_t, uint16_t>(
        reinterpret_cast<const uint8_t*>(buffer_.data()),
        len / sizeof(int16_t) / 2,
        reinterpret_cast<int16_t*>(data));
    }
  }
}

template <bool USE_COMPRESS, int HIST_BITS>
inline void Linkers::Send(int rank, char* data, int len) const {
  if (len <= 0) {
    return;
  }
  if (!USE_COMPRESS) {
    int send_cnt = 0;
    if (HIST_BITS == -1) {
      global_timer.Start("Send time -1");
    }
    while (send_cnt < len) {
      send_cnt += linkers_[rank]->Send(data + send_cnt, len - send_cnt);
    }
    if (HIST_BITS == -1) {
      global_timer.Stop("Send time -1");
    }
  } else {
    if (2 * static_cast<size_t>(len) * 20 > send_buffer_.size()) {
      send_buffer_.resize(2 * len * 20);
    }
    const int num_threads = 16;
    HistogramCompressor hc(num_threads);
    if (HIST_BITS == 32) {
      hc.Compress<int32_t, uint32_t>(
        reinterpret_cast<const int32_t*>(data),
        reinterpret_cast<uint8_t*>(send_buffer_.data()),
        len / sizeof(int32_t) / 2);
    } else if (HIST_BITS == 16) {
      hc.Compress<int16_t, uint16_t>(
        reinterpret_cast<const int16_t*>(data),
        reinterpret_cast<uint8_t*>(send_buffer_.data()),
        len / sizeof(int16_t) / 2);
    } else {
      Log::Fatal("Unknwon HIST_BITS = %d", HIST_BITS);
    }
    len = static_cast<int>(send_buffer_[0] + 2 * sizeof(uint32_t) + (num_threads + 1) * sizeof(uint32_t));
    data = reinterpret_cast<char*>(send_buffer_.data());

    int send_cnt = 0;
    global_timer.Start("Send time");
    while (send_cnt < len) {
      send_cnt += linkers_[rank]->Send(data + send_cnt, len - send_cnt);
    }
    global_timer.Stop("Send time");
  }
}

template <bool USE_COMPRESS, int HIST_BITS>
inline void Linkers::SendRecv(int send_rank, char* send_data, int send_len,
                              int recv_rank, char* recv_data, int recv_len) {
  auto start_time = std::chrono::high_resolution_clock::now();
  if (send_len < SocketConfig::kSocketBufferSize) {
    // if buffer is enough, send will non-blocking
    Send<USE_COMPRESS, HIST_BITS>(send_rank, send_data, send_len);
    Recv<USE_COMPRESS, HIST_BITS>(recv_rank, recv_data, recv_len);
  } else {
    // if buffer is not enough, use another thread to send, since send will be blocking
    std::thread send_worker(
      [this, send_rank, send_data, send_len]() {
      Send<USE_COMPRESS, HIST_BITS>(send_rank, send_data, send_len);
    });
    Recv<USE_COMPRESS, HIST_BITS>(recv_rank, recv_data, recv_len);
    send_worker.join();
  }
  // wait for send complete
  auto end_time = std::chrono::high_resolution_clock::now();
  // output used time on each iteration
  network_time_ += std::chrono::duration<double, std::milli>(end_time - start_time);
}

#endif  // USE_SOCKET

#ifdef USE_MPI

inline void Linkers::Recv(int rank, char* data, int len) const {
  MPI_Status status;
  int read_cnt = 0;
  while (read_cnt < len) {
    MPI_SAFE_CALL(MPI_Recv(data + read_cnt, len - read_cnt, MPI_BYTE, rank, MPI_ANY_TAG, MPI_COMM_WORLD, &status));
    int cur_cnt;
    MPI_SAFE_CALL(MPI_Get_count(&status, MPI_BYTE, &cur_cnt));
    read_cnt += cur_cnt;
  }
}

inline void Linkers::Send(int rank, char* data, int len) const {
  if (len <= 0) {
    return;
  }
  MPI_Status status;
  MPI_Request send_request;
  MPI_SAFE_CALL(MPI_Isend(data, len, MPI_BYTE, rank, 0, MPI_COMM_WORLD, &send_request));
  MPI_SAFE_CALL(MPI_Wait(&send_request, &status));
}

inline void Linkers::SendRecv(int send_rank, char* send_data, int send_len,
                              int recv_rank, char* recv_data, int recv_len) {
  MPI_Request send_request;
  // send first, non-blocking
  MPI_SAFE_CALL(MPI_Isend(send_data, send_len, MPI_BYTE, send_rank, 0, MPI_COMM_WORLD, &send_request));
  // then receive, blocking
  MPI_Status status;
  int read_cnt = 0;
  while (read_cnt < recv_len) {
    MPI_SAFE_CALL(MPI_Recv(recv_data + read_cnt, recv_len - read_cnt, MPI_BYTE, recv_rank, 0, MPI_COMM_WORLD, &status));
    int cur_cnt;
    MPI_SAFE_CALL(MPI_Get_count(&status, MPI_BYTE, &cur_cnt));
    read_cnt += cur_cnt;
  }
  // wait for send complete
  MPI_SAFE_CALL(MPI_Wait(&send_request, &status));
}

#endif  // USE_MPI
}  // namespace LightGBM
#endif   // LightGBM_NETWORK_LINKERS_H_
