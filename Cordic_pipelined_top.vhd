library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity Cordic_pipelined_top is
    generic (
        STAGES : integer := 16
    );
    port ( 
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        z_in  : in  std_logic_vector(15 downto 0); -- Angolo in ingresso (Q2.14)
        x_out : out std_logic_vector(15 downto 0); -- Coseno calcolato   (Q2.14)
        y_out : out std_logic_vector(15 downto 0); -- Seno calcolato     (Q2.14)
        z_out : out std_logic_vector(15 downto 0)  -- Angolo residuo     (Q2.14)
    );
end Cordic_pipelined_top;

architecture Behavioral of Cordic_pipelined_top is

component PE is
    generic (
        shift_amount : integer
    );
    port ( 
        clk_i  : in  std_logic;
        rst_i  : in  std_logic;
        d_i    : in  std_logic;
        x_prev : in  std_logic_vector(15 downto 0);
        y_prev : in  std_logic_vector(15 downto 0);
        z_prev : in  std_logic_vector(15 downto 0);
        LUT_in : in  std_logic_vector(15 downto 0);
        d_out  : out std_logic;
        x_curr : out std_logic_vector(15 downto 0);
        y_curr : out std_logic_vector(15 downto 0);
        z_curr : out std_logic_vector(15 downto 0)
    );
end component PE;

type pe_struct_t is record 
    x : std_logic_vector(15 downto 0);
    y : std_logic_vector(15 downto 0);
    z : std_logic_vector(15 downto 0);
    d : std_logic;
end record;

type pe_propagate_t is array (0 to STAGES) of pe_struct_t;
type lut_in_t       is array (0 to STAGES-1) of std_logic_vector(15 downto 0);

constant SCALE : real := 16384.0; -- Formato Q2.14 (2^14)

-- 1. Calcola il guadagno inverso 1/K a tempo di compilazione
function calc_inv_k(num_stages : integer) return std_logic_vector is
    variable k_val : real := 1.0;
    variable inv_k : integer;
begin
    for i in 0 to num_stages - 1 loop
        k_val := k_val * sqrt(1.0 + 2.0**(-2 * i));
    end loop;
    inv_k := integer(round((1.0 / k_val) * SCALE));
    return std_logic_vector(to_signed(inv_k, 16));
end function;

-- 2. Calcola la tabella degli angoli atan(2^-i) a tempo di compilazione
function init_lut(num_stages : integer) return lut_in_t is
    variable lut_data  : lut_in_t := (others => (others => '0'));
    variable angle_rad : real;
    variable angle_int : integer;
begin
    for i in 0 to num_stages - 1 loop
        angle_rad   := arctan(2.0**(-i));
        angle_int   := integer(round(angle_rad * SCALE));
        lut_data(i) := std_logic_vector(to_signed(angle_int, 16));
    end loop;
    return lut_data;
end function;

-- Costanti cablate in hardware generate automaticamente da STAGES
constant INV_K    : std_logic_vector(15 downto 0) := calc_inv_k(STAGES);
constant lut_in_s : lut_in_t := init_lut(STAGES);
signal pe_prop_s  : pe_propagate_t;

begin

-- Inizializzazione dello stadio 0 cablata in hardware
pe_prop_s(0).x <= INV_K;
pe_prop_s(0).y <= (others => '0');
pe_prop_s(0).z <= z_in;
pe_prop_s(0).d <= z_in(15);

-- Generazione degli STAGES stadi della pipeline
pipeline_generate: for i in 0 to STAGES-1 generate
    PE_inst: PE 
        generic map (
            shift_amount => i
        )
        port map ( 
            clk_i  => clk_i,
            rst_i  => rst_i,
            d_i    => pe_prop_s(i).d,
            x_prev => pe_prop_s(i).x,
            y_prev => pe_prop_s(i).y,
            z_prev => pe_prop_s(i).z, 
            LUT_in => lut_in_s(i),
            d_out  => pe_prop_s(i+1).d,
            x_curr => pe_prop_s(i+1).x,
            y_curr => pe_prop_s(i+1).y,
            z_curr => pe_prop_s(i+1).z
        );
end generate;

-- Uscite finali
x_out <= pe_prop_s(STAGES).x;
y_out <= pe_prop_s(STAGES).y;
z_out <= pe_prop_s(STAGES).z;

end Behavioral;
