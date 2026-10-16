\# ARF-MANET: Adaptive Routing Framework for MANETs



MATLAB simulation code and reproducibility package for the paper:



> \*\*Comparison in the Performance of the Communication System MANET\*\*

> Muthanna Jaafar Abbas and Haider Mohammed Turki Al-Hilfi

> University of Babylon, Iraq



\## Overview



This repository contains the complete codebase for the ARF-MANET framework, a lightweight adaptive routing layer for Mobile Ad Hoc Networks (MANETs). The framework selects dynamically between AODV, DSR, and DSDV using a composite utility function over PDR, throughput, delay, NRL, and residual energy.



The repository includes:

\- The MATLAB discrete-event simulator

\- The ARF-MANET decision module

\- The experiment driver for 160 scenarios (4 protocols × 4 densities × 10 seeds)

\- The statistical analysis scripts

\- The figure generation scripts



\## Requirements



\- MATLAB R2020a or later

\- Statistics and Machine Learning Toolbox (for Kruskal–Wallis tests)



\## Repository Structure



matlab/

&#x20; manet\_sim.m              % Main simulator (protocols + mobility + channel)

&#x20; run\_all\_experiments.m    % Runs 160 scenarios and saves .mat files

&#x20; analyze\_results.m        % Computes mean, CI, Kruskal–Wallis; prints LaTeX tables

&#x20; generate\_figures.m       % Produces the 8 figures of the paper



results/

&#x20; matlab/                  % Simulation outputs (160 .mat + summary.mat)



figures/                   % 8 PNG figures at 300 dpi



\## How to Reproduce



1\. Open MATLAB and set the current folder to the repository root.

2\. Run the full simulation campaign:



&#x20;  run\_all\_experiments



&#x20;  This takes approximately 15–20 minutes on a modern laptop.



3\. Run the statistical analysis:



&#x20;  analyze\_results



4\. Generate all figures:



&#x20;  generate\_figures



All figures will be saved to the figures/ directory.



\## Simulation Parameters



| Parameter | Value |

|-----------|-------|

| Simulator | MATLAB discrete-event |

| Channel model | Two-ray ground |

| MAC protocol | IEEE 802.11 CSMA/CA |

| Number of nodes | 150, 200, 250, 300 |

| Traffic type | CBR |

| Packet size | 512 bytes |

| Packet rate | 12 packets/s |

| Network area | 1200 × 1200 m² |

| Simulation time | 1000 s |

| Mobility model | Time-varying Random Waypoint |

| Max speed (0–500 s) | 10 m/s |

| Max speed (500–1000 s) | 20 m/s |

| Protocols | AODV, DSR, DSDV, ARF-MANET |

| Runs per scenario | 10 |



\## Results Summary



ARF-MANET achieves the highest PDR (up to 0.9991) and throughput (up to 491.2 kbps) across all tested densities, reducing packet loss by 5–7× compared with DSR and by more than 200× compared with DSDV.



\## License



MIT License.



\## Contact



Muthanna Jaafar Abbas

Department of Electrical Engineering, University of Babylon

Email: author@uobabylon.edu.iq

