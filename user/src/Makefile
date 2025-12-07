# 使用的工具
IVERILOG = iverilog
VVP      = vvp

# 输出的可执行仿真文件名
OUT      = sim.out

# 文件列表
FILELIST = filelist.f

# 默认目标：编译并运行
all: run

# 只编译，不运行
sim: $(OUT)

$(OUT): $(FILELIST)
	$(IVERILOG) -g2012 -f $(FILELIST) -o $(OUT)

# 运行仿真
run: sim
	$(VVP) $(OUT)

# 清理
clean:
	rm -f $(OUT) *.vcd
