library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PE is
    generic (
        shift_amount : integer := 0
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
end PE;

architecture Behavioral of PE is
    signal x_reg, y_reg, z_reg    : signed(15 downto 0);
    signal x_next, y_next, z_next : signed(15 downto 0);
    signal d_reg                  : std_logic;
begin

register_process: process(clk_i)
begin 
    if rising_edge(clk_i) then 
        if rst_i = '1' then 
            x_reg <= (others => '0');
            y_reg <= (others => '0');
            z_reg <= (others => '0');
            d_reg <= '0';
        else 
            x_reg <= signed(x_prev);
            y_reg <= signed(y_prev);
            z_reg <= signed(z_prev);
            d_reg <= d_i;
        end if;
    end if;
end process;

next_stage_process: process(x_reg, y_reg, z_reg, LUT_in, d_reg)
begin
    if d_reg = '0' then 
        -- Angolo residuo positivo o nullo: rotazione antioraria
        x_next <= x_reg - shift_right(y_reg, shift_amount);
        y_next <= y_reg + shift_right(x_reg, shift_amount);
        z_next <= z_reg - signed(LUT_in);
    else 
        -- Angolo residuo negativo: rotazione oraria
        x_next <= x_reg + shift_right(y_reg, shift_amount);
        y_next <= y_reg - shift_right(x_reg, shift_amount);
        z_next <= z_reg + signed(LUT_in);
    end if;
end process;

-- Assegnazione uscite 
x_curr <= std_logic_vector(x_next);
y_curr <= std_logic_vector(y_next);
z_curr <= std_logic_vector(z_next);
d_out  <= z_next(15);

end Behavioral;
