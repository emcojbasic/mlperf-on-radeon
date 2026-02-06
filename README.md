# MLPerf Benchmarking on Radeon Graphics Cards

This repo contains a comprehensive benchmarking evaluation of MLPerf inference workloads executed on AMD GPUs across multiple ROCm software releases and backend configurations, with reference measurement results on NVIDIA RTX 4090 platform used for comparison.  

Initial measurements obtained using an earlier ROCm release (6.4.1) revealed performance limitations and, in selected cases, deviations from reference accuracy. Subsequent execution using a MIGraphX-based backend, followed by evaluation on a newer ROCm version (7.1.1) with the same backend resulted in notable improvements in both numerical correctness and runtime efficiency. Accross workloads, latency decreased, and throughput increased, demonstrating a clear trend toward convergence with the NVIDIA baseline.  

While the NVIDIA RTX 4090 continues to provide the highest absolute performance, the performance gap has been substantially reduced in the latest ROCm configuration, reflecting meaningful progress in the AMD inference ecosystem. Nonetheless, certain inconsistencies in performance scaling accross GPU tiers exist, particularly for transformer-dominated workloads, indicating areas where further optimization remains necessary. Overall, the results confirm that advances in backend execution and ROCm software maturity significantly enhance the competitiveness and reliability of AMD GPUs for machine learning inference. 

## General Observations 

The newest ROCm release (7.1.1) delivered the most consistent results, both in terms of stability and performance across all Radeon GPUs.  

Compared to the older ROCm version (6.4.1), the performance gap to the RTX 4090 is noticeably smaller, making AMD GPUs significantly more competitive for inference workloads.  

Using a MIGraphX-based backend generally improved latency and helped align accuracy more closely with reference results. 

The remaining advantage of the RTX 4090 is smaller than when only using ROCm backend, reducing the practical benefit of switching to NVIDIA for executing selected workloads.  

## Comparative Analysis Charts 

The comparison depicted in the following charts clearly shows a consistent improvement trend across configurations. Starting from the baseline ROCm 6.4.1 version tested, performance improves when enabling a MIGraphX-based backend and improves even further with ROCm 7.1.1 combined with the same backend. As a result, AMD latency and throughput measurements progressively move closer to the NVIDIA benchmark results, indicating that the newer ROCm stack and backend optimizations significantly reduce the performance gap. 

<img width="975" height="469" alt="image" src="https://github.com/user-attachments/assets/0d266b2d-2e87-43f3-bc10-37cd7f3eaa6b" />

<img width="975" height="470" alt="image" src="https://github.com/user-attachments/assets/8ec8e9fc-f399-4831-a2b6-a3463b82df46" />

<img width="975" height="469" alt="image" src="https://github.com/user-attachments/assets/c82b3e6b-7123-4517-be86-45454e6a6175" />

<img width="975" height="469" alt="image" src="https://github.com/user-attachments/assets/5dd631d1-8080-4095-92ab-38c4837003f5" />

<img width="975" height="469" alt="image" src="https://github.com/user-attachments/assets/19b447e2-5788-4d78-881b-017e1e26a802" />

<img width="975" height="469" alt="image" src="https://github.com/user-attachments/assets/5f1c48f7-93c0-4cbd-a78e-8a86661cfaa0" />
