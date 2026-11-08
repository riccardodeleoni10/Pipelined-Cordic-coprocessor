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
  <img src="img/cordic_vector_rotation.svg" alt="CORDIC Vector Rotation Graph" width="60%">
  <br>
  <em>Figure 1: Iterative decomposition of the target angle $\theta$ into elementary micro-rotations.</em>
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

### 3. RTL Architecture 

<p align="center">
  <img src="img/cordic_pipeline_stage.svg" alt="CORDIC Pipeline Elementary Stage" width="80%">
  <br>
  <em>Figure 2: Hardware architecture of a single CORDIC pipeline stage.</em>
</p>

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

### 4. Simulation Results

<p align="center">
  <img src="img/simulation_waveform.png" alt="RTL Simulation Waveform" width="100%">
  <br>
  <em>Figure 3: Behavioral simulation showing input angle and valid sine/cosine outputs after latency cycles.</em>
</p>

---
