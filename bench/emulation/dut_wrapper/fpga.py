import os
import sys

class FPGA_SOC:
    REGISTER_SANITY         = 0x0
    REGISTER_ADDR_LOW       = 0x2
    REGISTER_ADDR_HIGH      = 0x4
    REGISTER_DATA_IN_LOW    = 0x6
    REGISTER_DATA_IN_HIGH   = 0x8
    REGISTER_CONTROL        = 0xa
    REGISTER_DATA_OUT_LOW   = 0xc
    REGISTER_DATA_OUT_HIGH  = 0xe
    REGISTER_CPU_PC_LOW     = 0x10
    REGISTER_CPU_PC_HIGH    = 0x12
    REGISTER_CPU_STATE      = 0x14
    REGISTER_SOC_MEM_SIZE_LOW = 0x16
    REGISTER_SOC_MEM_SIZE_HIGH = 0x18
    SANE_CONSTANT           = 0x50FE
    BIT_CPU_RESET             = 0
    BIT_SOC_RESET             = 1
    BIT_BUS_MASTER            = 2
    BIT_TRANSACTION_START     = 3
    BIT_TRANSACTION_WRITE     = 4
    BIT_TRANSACTION_CLEAN     = 5
    BIT_TRANSACTION_READY     = 6
    BIT_TRANSACTION_SIZE_LOW  = 7
    BIT_TRANSACTION_SIZE_HIGH = 8
    BIT_CPU_HALT              = 9
    BIT_CPU_SINGLESTEP        = 10
    BIT_CPU_DO_STEP           = 11
    UART_BAUDE_DIVIDER_ADDR   = 0x80000000
    UART_TRANSMIT_BYTE_ADDR   = 0x80000004
    UART_9600_DIVIDER         = 13889
    WORD_SIZE                 = 4
    STATE_CPU_IDLE            = 24

    def  __init__(self, libbench, fpga_dev):
        # TODO: rename to libdut
        self._soc = libbench.skFpga(fpga_dev)
        self._firmware_uploaded = False
        self._control_reg = 0

    def upload_firmware(self, firmware_path):
        pass
#        self._soc.uploadBitstream(firmware_path)

    def get_cpu_state(self):
        # get pc
        state = self._soc.readShort(self.REGISTER_CPU_STATE) & 0xFFFF
        return state

    def print_cpu_state(self):
        state = self.get_cpu_state()
        print("CPU state: {0}".format(state))

    def get_cpu_pc(self):
        # get pc
        low_pc = self._soc.readShort(self.REGISTER_CPU_PC_LOW) & 0xFFFF
        high_pc = self._soc.readShort(self.REGISTER_CPU_PC_HIGH) & 0xFFFF
        return ((high_pc << 16) | low_pc)
    
    def get_cpu_status(self, halt):
        if halt:
            # halt cpu
            self.__set_cpu_halt()
            self.__update_control_register()
        # get pc
        state = self.get_cpu_state(halt = False)
        pc = self.get_cpu_pc(halt = False)
        if halt:
            # run cpu
            self.__clear_cpu_halt()
            self.__update_control_register()
        return (pc, state)

    def print_cpu_status(self, halt):
        pc, state = self.get_cpu_status(halt)
        print("PC 0x{:08X}, status {}".format(pc, status))

    def print_cpu_pc(self):
        pc = self.get_cpu_pc()
        print("PC: 0x{:08X}".format(pc))

    def print_ram(self, start_address, num_words):
        print("{:10} : {:10}".format("address", "data"))
        for w in range(num_words):
            addr = start_address + w * WORD_SIZE
            data = self.read_word_ram(addr)
            print("0x{:08X} : 0x{:08X}".format(addr, data))

    def get_soc_ram_size(self):
        # halt cpu
        self.__set_cpu_halt()
        self.__update_control_register()
        # get ram size
        ram_size_low = self._soc.readShort(self.REGISTER_SOC_MEM_SIZE_LOW) & 0xFFFF
        ram_size_high = self._soc.readShort(self.REGISTER_SOC_MEM_SIZE_HIGH) & 0xFFFF
        # run cpu
        self.__clear_cpu_halt()
        self.__update_control_register()
        return ((ram_size_high << 16) | ram_size_low)

    def fpga_init(self):
        self._soc.setReset(False)
        self._soc.setReset(1)
    
    def check_sanity(self):
        tmp = self._soc.readShort(self.REGISTER_SANITY)
        print(hex(tmp))
        assert(tmp == self.SANE_CONSTANT)
        return (tmp == self.SANE_CONSTANT)
   
    def halt_soc(self):
        # set cpu to reset
        self.__set_cpu_halt()
        # set soc to run
        self.__clear_soc_reset()
        # set bus to external
        self.__set_bus_master_external()
        # set tran width to word
        self.__set_transaction_size_to_word()
        self.__update_control_register()

    def run_soc(self, single_step = False):
        self.__clear_cpu_halt()
        self.__set_cpu_reset()
        # set soc to reset
#        self.__set_soc_reset()
        # set bus to cpu
        self.__set_bus_master_cpu()
        self.__update_control_register()
        # set cpu to run
        self.__clear_cpu_reset()
        # set soc to run
        self.__clear_soc_reset()
        # set singlestep mode
        if single_step:
            self.__set_cpu_singlestep()
        self.__update_control_register()

    def __cpu_is_idle(self):
        pc, state = self.get_cpu_status(halt = False)
        return (state == STATE_CPU_IDLE)

    def do_step(self, debug = False):
        # check if singlestep mode is enabled
        assert(self.__check_cpu_singlestep())
        # check cpu state if its idle
        assert(self.__cpu_is_idle())
        # set do step flag
        self.__set_cpu_do_step()
        if debug:
            self.print_cpu_status(halt = False)
        # update control register
        self.__update_control_register()

    def uart_set_baud_9600(self):
        self.write_word_ram(self.UART_BAUDE_DIVIDER_ADDR, self.UART_9600_DIVIDER)

    def uart_print(self, data):
        string = str(data)
        for ch in string:
            self.write_word_ram(self.UART_TRANSMIT_BYTE_ADDR, ord(ch))

    def read_word_ram(self, address):
        # set address
        self.__set_address(address)
        # prepare for read transaction
        self.__prepare_for_read_transaction()
        # run control
        self.__start_transaction()
        # check transaction finished
        finished = False
        for i in range(10):
            if self.__check_transaction_finished():
                finished = True
                break
        # clear transaction
        if not finished:
            print("tran is not finished successfully")
            return 0
        else:
            self.__clear_transaction_finished()
        return self.__get_data_out()

    def write_word_ram(self, address, data):
        # set address
        self.__set_address(address)
        # set data
        self.__set_data_in(data)
        # prepare control
        self.__prepare_for_write_transaction()
        # run control
        self.__start_transaction()
        # check transaction finished
        finished = False
        for i in range(10):
            if self.__check_transaction_finished():
                finished = True
                break
        # clear transaction
        if not finished:
            print("tran is not finished successfully")
            return False
        else:
            self.__clear_transaction_finished()
        return True
        # check written ??

    def __update_control_register(self):
        self._soc.writeShort(self.REGISTER_CONTROL, self._control_reg)

    def __prepare_for_write_transaction(self):
        # set transaction write
        self.__set_transaction_write()
        pass

    def __prepare_for_read_transaction(self):
        pass

    def __start_transaction(self):
        self.__set_transaction_start()
        self.__update_control_register()

    def __check_transaction_finished(self):
        return self.__check_transaction_ready()

    def __clear_transaction_finished(self):
        # clear tran we
        self.__clear_transaction_write()
        # set tran clean
        self.__set_transaction_clean()
        self.__update_control_register()
        # clear tran clean
        self.__clear_transaction_clean()
        self.__update_control_register()

    def __set_control_bit(self, bit_pos):
        self._control_reg |= (1 << bit_pos)

    def __clear_control_bit(self, bit_pos):
        self._control_reg &= ~(1 << bit_pos)

    def __check_control_bit(self, bit_pos):
        self._control_reg = self._soc.readShort(self.REGISTER_CONTROL)
        res = (self._control_reg & (1 << bit_pos))
        return res

    def __set_address(self, address):
        low_addr = address & 0xFFFF
        self._soc.writeShort(self.REGISTER_ADDR_LOW, low_addr)
        high_addr = address >> 16
        self._soc.writeShort(self.REGISTER_ADDR_HIGH, high_addr)
        assert(address == self.__get_address())

    def __get_address(self):
        low_addr = self._soc.readShort(self.REGISTER_ADDR_LOW) & 0xFFFF
        high_addr = self._soc.readShort(self.REGISTER_ADDR_HIGH) & 0xFFFF
        return ((high_addr << 16) | low_addr)
    
    def __set_data_in(self, data):
        low_data_in = data & 0xFFFF
        self._soc.writeShort(self.REGISTER_DATA_IN_LOW, low_data_in)
        high_data_in = data >> 16
        self._soc.writeShort(self.REGISTER_DATA_IN_HIGH, high_data_in)
        assert(data == self.__get_data_in())

    def __get_data_in(self):
        low_data_in = self._soc.readShort(self.REGISTER_DATA_IN_LOW) & 0xFFFF
        high_data_in = self._soc.readShort(self.REGISTER_DATA_IN_HIGH) & 0xFFFF
        return ((high_data_in << 16) | low_data_in)

    def __get_data_out(self):
        low_data_out = self._soc.readShort(self.REGISTER_DATA_OUT_LOW) & 0xFFFF
        high_data_out = self._soc.readShort(self.REGISTER_DATA_OUT_HIGH) & 0xFFFF
        return ((high_data_out << 16) | low_data_out)

    def __set_cpu_singlestep(self):
        self.__set_control_bit(self.BIT_CPU_SINGLESTEP)

    def __clear_cpu_singlestep(self):
        self.__clear_control_bit(self.BIT_CPU_SINGLESTEP)
    
    def __check_cpu_singlestep(self):
        return self.__check_control_bit(self.BIT_CPU_SINGLESTEP)

    def __set_cpu_do_step(self):
        self.__set_control_bit(self.BIT_CPU_DO_STEP)

    def __clear_cpu_do_step(self):
        self.__clear_control_bit(self.BIT_CPU_DO_STEP)

    def __set_cpu_halt(self):
        self.__set_control_bit(self.BIT_CPU_HALT)

    def __clear_cpu_halt(self):
        self.__clear_control_bit(self.BIT_CPU_HALT)

    def __set_cpu_reset(self):
        self.__set_control_bit(self.BIT_CPU_RESET)

    def __clear_cpu_reset(self):
        self.__clear_control_bit(self.BIT_CPU_RESET)

    def __set_soc_reset(self):
        self.__set_control_bit(self.BIT_SOC_RESET)

    def __clear_soc_reset(self):
        self.__clear_control_bit(self.BIT_SOC_RESET)

    def __set_bus_master_external(self):
        self.__set_control_bit(self.BIT_BUS_MASTER)

    def __set_bus_master_cpu(self):
        self.__clear_control_bit(self.BIT_BUS_MASTER)

    def __set_transaction_start(self):
        self.__set_control_bit(self.BIT_TRANSACTION_START)
    
    def __set_transaction_clean(self):
        self.__set_control_bit(self.BIT_TRANSACTION_CLEAN)

    def __clear_transaction_clean(self):
        self.__clear_control_bit(self.BIT_TRANSACTION_CLEAN)

    def __set_transaction_write(self):
        self.__set_control_bit(self.BIT_TRANSACTION_WRITE)

    def __clear_transaction_write(self):
        self.__clear_control_bit(self.BIT_TRANSACTION_WRITE)

    def __check_transaction_ready(self):
        return self.__check_control_bit(self.BIT_TRANSACTION_READY)

    def __set_transaction_size_to_word(self):
        self.__set_control_bit(self.BIT_TRANSACTION_SIZE_LOW)
        self.__set_control_bit(self.BIT_TRANSACTION_SIZE_HIGH)
