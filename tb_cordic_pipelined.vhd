library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_Cordic_pipelined is
end tb_Cordic_pipelined;

architecture sim of tb_Cordic_pipelined is

    constant STAGES     : integer := 16;
    constant CLK_PERIOD : time    := 10 ns;
    constant SCALE      : real    := 16384.0; -- 2^14 (Formato Q2.14)

    signal clk_i : std_logic := '0';
    signal rst_i : std_logic := '1';
    signal z_in  : std_logic_vector(15 downto 0) := (others => '0');
    signal x_out : std_logic_vector(15 downto 0);
    signal y_out : std_logic_vector(15 downto 0);
    signal z_out : std_logic_vector(15 downto 0);

    -- Segnali real per osservare i valori direttamente in [-1.0, +1.0]
    signal theta_in_real : real := 0.0;
    signal cos_real      : real := 0.0;
    signal sin_real      : real := 0.0;

begin

    -- Istanza del DUT (senza x_in e y_in)
    uut: entity work.Cordic_pipelined_top
        generic map (
            STAGES   => STAGES
        )
        port map (
            clk_i => clk_i,
            rst_i => rst_i,
            z_in  => z_in,
            x_out => x_out,
            y_out => y_out,
            z_out => z_out
        );

    -- Generazione del clock (100 MHz)
    clk_process: process
    begin
        clk_i <= '0';
        wait for CLK_PERIOD / 2;
        clk_i <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    cos_real <= real(to_integer(signed(x_out))) / SCALE;
    sin_real <= real(to_integer(signed(y_out))) / SCALE;

    -- Processo di stimolo (10 periodi completi per una simulazione lunga)
    stim_proc: process
        variable theta    : real := -MATH_PI;
        variable z_clamped: real := 0.0;
        constant STEP_RAD : real := 0.01; -- Passo fine: ~628 colpi di clock per periodo
    begin
        rst_i <= '1';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk_i);
        rst_i <= '0';

        for cycle in 1 to 10 loop
            theta := -MATH_PI;
            while theta <= MATH_PI loop
                theta_in_real <= theta;

                -- Tronca (satura) l'angolo a [-pi/2, +pi/2] fuori dal range di convergenza
                if theta > MATH_PI_OVER_2 then
                    z_clamped := MATH_PI_OVER_2;
                elsif theta < -MATH_PI_OVER_2 then
                    z_clamped := -MATH_PI_OVER_2;
                else
                    z_clamped := theta;
                end if;

                z_in <= std_logic_vector(to_signed(integer(round(z_clamped * SCALE)), 16));

                wait until rising_edge(clk_i);
                theta := theta + STEP_RAD;
            end loop;
        end loop;

        wait for CLK_PERIOD * (STAGES + 10);
        std.env.stop;
    end process;

end sim;