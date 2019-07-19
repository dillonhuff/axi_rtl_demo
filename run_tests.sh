iverilog -o axi_tb axi_slave_ram.v axi_slave_tb.v
compile_res=$?

if [ $compile_res = 0 ]
then
    echo "Compiled correctly"
else
    echo "Error: Compilation failed"
fi


./axi_tb
