# Pipelined CORDIC Core (Sine & Cosine Generator)

![Language](https://img.shields.io/badge/Language-VHDL-red.svg)
![Tool](https://img.shields.io/badge/Tool-Xilinx_Vivado-success.svg)
![Target](https://img.shields.io/badge/Target-Zynq_UltraScale-yellow.svg)
![Frequency](https://img.shields.io/badge/Fmax-500_MHz-blue.svg)
![Architecture](https://img.shields.io/badge/Architecture-16--Stage_Pipelined-purple.svg)

Hardware implementation in VHDL of a **fully pipelined CORDIC (*COordinate Rotation DIgital Computer*) processor** operating in rotation mode for high-throughput sine and cosine computation.

The architecture uses 16-bit **Q2.14** fixed-point arithmetic, is completely multiplier-less (**0 DSPs**), and automatically computes both the inverse gain $1/K$ and the elementary angles Look-Up Table (LUT) $\arctan(2^{-i})$ at compile/synthesis time via the `IEEE.MATH_REAL` library, dynamically adapting to the `STAGES` generic parameter.

---

## Table of Contents

1. [Key Features](#1-key-features)
2. [Mathematical Formulation (Rotation Matrices)](#2-mathematical-formulation-rotation-matrices)
3. [Hardware Architecture & Data Format](#3-hardware-architecture--data-format)
4. [Vivado Setup & Simulation Guide](#4-vivado-setup--simulation-guide)
5. [Testbench & Simulation Results](#5-testbench--simulation-results)
6. [Implementation Results (ZCU208)](#6-implementation-results-zcu208)

---

## 1. Key Features

- **Unrolled Pipelined Architecture:** One Processing Element (`PE`) per iteration with inter-stage registers, delivering **1 sample per clock cycle** after an initial latency of `STAGES` cycles.
- **Multiplier-less (Shift-and-Add):** All micro-rotations are implemented exclusively through hardwired arithmetic right shifts (`shift_right`) and adders/subtractors.
- **Compile-Time Constant Generation:** No external files required; both the pre-scaling factor $1/K$ and the angular constants array `lut_in_s` are evaluated during VHDL elaboration based on `STAGES`.
- **Q2.14 Fixed-Point Representation:** 16-bit two's complement format (1 sign bit, 1 integer bit, 14 fractional bits), providing a resolution of $2^{-14} \approx 6.1 \times 10^{-5}$.

---

## 2. Mathematical Formulation (Rotation Matrices)

Given a two-dimensional vector $[x_0, y_0]^T$ in the Cartesian plane, rotating it by an angle $\theta$ around the origin is described by the rotation matrix operator $R(\theta)$:

$$
\begin{bmatrix} 
    x' \\ 
    y' 
\end{bmatrix} 
= R(\theta) 
\begin{bmatrix} 
    x_0 \\ 
    y_0 
\end{bmatrix} 
= \begin{bmatrix} 
    \cos\theta & -\sin\theta \\ 
    \sin\theta & \cos\theta 
\end{bmatrix} 
\begin{bmatrix} 
    x_0 \\ 
    y_0 
\end{bmatrix}
$$

<p align="center">
  <img src="img/cordic.svg" alt="CORDIC Vector Rotation Graph" width="60%">
  <br>
  <em>Figure 1: Iterative decomposition of the target angle &theta; into elementary micro-rotations.</em>
</p>

The core idea of the CORDIC algorithm is to decompose the target angle $\theta$ into a finite sum of $N$ decreasing elementary micro-rotations $\alpha_i$, each directed according to the sign coefficient $\sigma_i \in \{-1, +1\}$:

$$
\theta \approx \sum_{i=0}^{N-1} \sigma_i \alpha_i \implies R(\theta) = \prod_{i=0}^{N-1} R(\sigma_i \alpha_i)
$$

Factoring out $\cos(\alpha_i)$ from the elementary rotation matrix $R(\sigma_i \alpha_i)$ and recalling that cosine is an even function ($\cos(\sigma_i \alpha_i) = \cos\alpha_i$) while sine is an odd function ($\sin(\sigma_i \alpha_i) = \sigma_i \sin\alpha_i$), we obtain:

$$
R(\sigma_i \alpha_i) = 
\begin{bmatrix} 
    \cos\alpha_i & -\sigma_i \sin\alpha_i \\ 
    \sigma_i \sin\alpha_i & \cos\alpha_i 
\end{bmatrix} 
= \cos\alpha_i 
\begin{bmatrix} 
    1 & -\sigma_i \tan\alpha_i \\ 
    \sigma_i \tan\alpha_i & 1 
\end{bmatrix}
$$

By constraining the tangents of the elementary angles to be negative powers of 2:

$$
\tan\alpha_i = 2^{-i} \implies \alpha_i = \arctan(2^{-i}) \quad \text{for } i = 0, 1, \dots, N-1
$$

multiplication by $\tan\alpha_i$ reduces to a simple **arithmetic right shift by $i$ bit positions** (`>> i`). Separating the scaling factors $\cos\alpha_i$ from the iterative pseudo-rotations, the overall transformation after $N$ stages becomes:

$$
\begin{bmatrix} 
    x_N \\ 
    y_N 
\end{bmatrix} 
= \left( \prod_{i=0}^{N-1} \cos\alpha_i \right) 
\left( \prod_{i=0}^{N-1} 
\begin{bmatrix} 
    1 & -\sigma_i 2^{-i} \\ 
    \sigma_i 2^{-i} & 1 
\end{bmatrix} \right) 
\begin{bmatrix} 
    x_0 \\ 
    y_0 
\end{bmatrix}
$$

### Anisotropic Gain $K$ and Pre-scaling

Each pseudo-rotation stage scales the vector magnitude by a factor of $\sqrt{1 + \tan^2\alpha_i} = \sqrt{1 + 2^{-2i}}$. After $N$ iterations, the cumulative CORDIC gain $K$ is:

$$
K = \prod_{i=0}^{N-1} \frac{1}{\cos\alpha_i} = \prod_{i=0}^{N-1} \sqrt{1 + 2^{-2i}} \xrightarrow{N \to \infty} 1.646760258...
$$

By initializing the input vector at the first pipeline stage to:

$$
\begin{bmatrix} 
    x_0 \\ 
    y_0 
\end{bmatrix} 
= \begin{bmatrix} 
    1/K \\ 
    0 
\end{bmatrix} 
\approx \begin{bmatrix} 
    0.607253 \\ 
    0 
\end{bmatrix}, \quad z_0 = \theta
$$

the gain $K$ is compensated upfront in hardware. Each stage $i$ then computes the iterative difference equations:

$$
\begin{cases}
    x_{i+1} = x_i - \sigma_i \cdot (y_i \gg i) \\
    y_{i+1} = y_i + \sigma_i \cdot (x_i \gg i) \\
    z_{i+1} = z_i - \sigma_i \cdot \arctan(2^{-i})
\end{cases}
\quad \text{where } \sigma_i = 
\begin{cases} 
    +1 & \text{if } z_i \ge 0 \quad (\text{MSB } d_i = \text{'0'}) \\ 
    -1 & \text{if } z_i < 0 \quad (\text{MSB } d_i = \text{'1'}) 
\end{cases}
$$

At the output of stage $N-1$, the residual angle approaches zero ($z_N \to 0$) and the coordinates directly yield:

$$
\begin{bmatrix} 
    x_N \\ 
    y_N 
\end{bmatrix} 
= \begin{bmatrix} 
    \cos\theta \\ 
    \sin\theta 
\end{bmatrix}
$$

---

## 3. Hardware Architecture & Data Format

The design consists of two main VHDL modules:
- **`PE.vhd` (Processing Element):** Implements the $i$-th pipeline stage. It contains input registers for $x_i, y_i, z_i, d_i$, hardwired arithmetic shifters parameterized by `shift_amount => i`, and three 16-bit adders/subtractors.
- **`Cordic_pipelined_top.vhd` (Top-Level):** Instantiates `STAGES` processing elements via a `for ... generate` loop, computes the `INV_K` ($1/K$) constant and the `lut_in_s` ($\arctan(2^{-i})$) array at synthesis time, and hardwires the initial stage inputs $x_0 = 1/K$, $y_0 = 0$.

<p align="center">
  <img src="img/cordic_pipeline_stage.svg" alt="CORDIC Pipeline Elementary Stage" width="80%">
  <br>
  <em>Figure 2: Hardware architecture of a single CORDIC pipeline stage.</em>
</p>

### Q2.14 Data Format
All data buses (`z_in`, `x_out`, `y_out`, `z_out`) use 16-bit signed two's complement representation with a scaling factor of $2^{14} = 16384$:

| Parameter | Real Value | Integer Value (Q2.14) | Hexadecimal Value |
| :--- | :---: | :---: | :---: |
| **Scale Factor $+1.0$** | $+1.000000$ | $+16384$ | `0x4000` |
| **Scale Factor $-1.0$** | $-1.000000$ | $-16384$ | `0xC000` |
| **Inverse Gain $1/K$ ($N=16$)** | $+0.607253$ | $+9949$ | `0x26DD` |
| **Upper Angle Bound $+\pi/2$** | $+1.570796\text{ rad}$ | $+25736$ | `0x6488` |
| **Lower Angle Bound $-\pi/2$** | $-1.570796\text{ rad}$ | $-25736$ | `0x9B78` |

---

## 4. Vivado Setup & Simulation Guide

1. **Project Creation:**
   * Open **Xilinx Vivado** and select **Create Project** $\rightarrow$ **RTL Project**.
   * In *Add Sources*, add the VHDL design files:
     * `PE.vhd`
     * `Cordic_pipelined_top.vhd`
   * In *Add Simulation Sources*, add the testbench file:
     * `tb_Cordic_pipelined.vhd`
   * Select the **Zynq UltraScale+ ZCU208** evaluation board (part `xczu48dr-fsvg1517-2-e`).

2. **Running Behavioral Simulation:**
   * In the *Flow Navigator*, click **Run Simulation** $\rightarrow$ **Run Behavioral Simulation**.
   * In the Vivado Tcl Console, run the complete simulation by typing:
     ```tcl
     run all
     ```
   * Select `x_out` and `y_out` in the waveform viewer:
     * Right-click $\rightarrow$ **Radix** $\rightarrow$ **Signed Decimal**.
     * Right-click $\rightarrow$ **Waveform Style** $\rightarrow$ **Analog**.

---

## 5. Testbench & Simulation Results

The testbench `tb_Cordic_pipelined.vhd` drives the core with a continuous angular sweep $\theta \in [-\pi, +\pi]$ over 10 full periods with a step size of $0.01\text{ rad}$ at a $100\text{ MHz}$ clock frequency ($\approx 63\text{ }\mu\text{s}$ total simulation time).

<p align="center">
  <img src="img/simulation_waveform.png" alt="RTL Simulation Waveform" width="100%">
  <br>
  <em>Figure 3: Behavioral simulation showing input angle and valid sine/cosine outputs after latency cycles.</em>
</p>

- **Initial Latency:** Valid output samples appear on `x_out` and `y_out` exactly **16 clock cycles** ($160\text{ ns}$) after deasserting reset.
- **Throughput:** In steady state, the pipeline outputs a new $\cos(\theta)$ and $\sin(\theta)$ pair on every rising clock edge.
- **Convergence Range Behavior:** Within the primary convergence range $[-\pi/2, +\pi/2]$ ($\sum_{i=0}^{15} \arctan(2^{-i}) \approx \pm 1.743\text{ rad}$), the cosine (`x_out`) and sine (`y_out`) waveforms accurately track the ideal trigonometric functions between `-16384` ($-1.0$) and `+16384` ($+1.0$), while angles outside $[-\pi/2, +\pi/2]$ are clamped at the quadrant boundaries, with a residual angle error on $z_{out}$ below $1\text{ LSB}$.

---

## 6. Implementation Results (ZCU208)

The **16-stage** configuration (`STAGES = 16`, 16-bit data width) was synthesized and implemented on an **AMD/Xilinx Zynq UltraScale+ RFSoC ZCU208** (`xczu48dr-fsvg1517-2-e`).

Thanks to the multiplier-less shift-and-add pipeline structure and compile-time constant propagation, the critical path is bounded by a single 16-bit adder/subtractor per stage, achieving an estimated maximum clock frequency of **500 MHz**.

| Metric / Hardware Resource | Result | Notes |
| :--- | :---: | :--- |
| **Target Device** | ZCU208 (`xczu48dr-fsvg1517-2-e`) | Zynq UltraScale+ RFSoC |
| **Pipeline Depth (`STAGES`)** | 16 | Latency = 16 clock cycles ($32\text{ ns}$ @ $500\text{ MHz}$) |
| **Estimated Max Frequency ($F_{\max}$)** | **500 MHz** | Throughput = $500\text{ MSps}$ |
| **CLB LUTs** | **612** | Adders/subtractors and hardwired shift routing |
| **CLB Flip-Flops (Registers)** | **602** | Pipeline registers ($x, y, z, d$) |
| **DSP Slices** | **0** | Purely multiplier-less architecture |
| **Block RAM (BRAM)** | **0** | Angular constants hardwired in logic |
