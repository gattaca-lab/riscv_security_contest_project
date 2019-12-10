#include <cstdlib>
#include <string>
#include <cassert>
#include <cstdio>
#include <stdexcept>
#include <iostream>

// verilator headers
#include <verilated.h>
#include <verilated_vcd_c.h>

// rtlsim headers (generated by verilator)
#include <Vsoc_includes.h>

#include "soc.h"

RV_SOC::RV_SOC(const char* trace)
{
    m_soc = new Vsoc;
    m_tracePath = trace;

    m_svScope = svGetScopeFromName("TOP.soc");
    svSetScope(m_svScope);

    int ramSize;
    ram_get_size(&ramSize);
    m_ramSize = ramSize;

    int rfSize;
    regfile_get_size(&rfSize);
    m_regFileSize = rfSize;

    clearRam();
    reset();
}

RV_SOC::~RV_SOC()
{
#ifdef TRACE_ENABLED
    if (m_trace)
    {
        m_trace->close();
        m_trace = nullptr;
    }
#endif
    assert(m_soc);
    delete m_soc;
}
    
void RV_SOC::enableVcdTrace()
{
    if (m_tracePath)
    {
#ifdef TRACE_ENABLED
        Verilated::traceEverOn(true);
        if (!m_trace) {
            delete m_trace;
        }
        m_trace = new VerilatedVcdC;
        m_soc->trace(m_trace, 99);
        m_trace->open(m_tracePath);
#endif
    }
}

void RV_SOC::tick(unsigned num)
{
    assert(m_soc);
    for (unsigned i = 0; i < num; i++)
    {
        if (m_tickCnt == 0) {

            m_soc->clk_i = 0;
            m_soc->eval();

#ifdef TRACE_ENABLED
            if (m_trace) {
                m_trace->dump(m_tickCnt);
            }
#endif

            m_tickCnt++;
            break;
        }
        en_state state_before = cpu_state();

        m_soc->clk_i = 1;
        m_soc->eval();
#ifdef TRACE_ENABLED
        if (m_trace) {
            m_trace->dump(m_tickCnt);
        }
#endif
        m_tickCnt++;

        m_soc->clk_i = 0;
        m_soc->eval();
#ifdef TRACE_ENABLED
        if (m_trace) {
            m_trace->dump(m_tickCnt);
            m_trace->flush();
        }
#endif
        m_tickCnt++;

        en_state state_after = cpu_state();
        if (    (state_before != state_after)
            &&  (state_after == en_state::FETCH)) {
            ++m_fetchCnt;
        }
    }
}

void RV_SOC::switchBusMasterToExternal(bool s)
{
    m_soc->bus_master_selector_i = s ? RV_SOC::busMaster::MASTER_EXT
                                     : RV_SOC::busMaster::MASTER_CPU;
}
    
void RV_SOC::toggleCpuReset(bool enReset)
{
    m_soc->cpu_rst_i = enReset;
}

void RV_SOC::writeWordExt(unsigned address, uint32_t val)
{
    if (address >= m_ramSize) {
        std::cerr << "writeWordExt: address " << std::dec << (address * 4) <<
            " (w_idx = 0x" <<  std::hex << address << ") is out of range " <<
            "[RamSize = " << std::dec << m_ramSize * 4 << " bytes]" << std::endl;
        throw std::out_of_range("write: the specified address is out of range");
    }
    assert(!(address & 0x3) && "Address misaligned");
    unsigned wait = 20;
    m_soc->ext_tran_addr_i = address;
    m_soc->ext_tran_data_i = val;
    m_soc->ext_tran_size_i = RV_SOC::extAccessSize::EXT_ACCESS_WORD;
    m_soc->ext_tran_write_i = 1;
    m_soc->ext_tran_start_i = 1;

    tick();
    m_soc->ext_tran_start_i = 0;
    m_soc->ext_tran_write_i = 0;

    bool success = false;
    for (unsigned i = wait; i >= 0; i--) {
        if (m_soc->ext_tran_ready_o) {
            success = true;
            break;
        }
        tick();
    }

    if (success) {
        m_soc->ext_tran_clear_i = 1;
        tick();
        m_soc->ext_tran_clear_i = 0;
    } else {
        std::cerr << "writeWordExt: no success result" << std::endl;
    }
}

uint32_t RV_SOC::readWordExt(unsigned address)
{
    if (address >= m_ramSize) {
        std::cerr << "readWordExt: address " << std::dec << (address * 4) <<
            " (w_idx = 0x" << std::hex << address << ") is out of range" <<
            "[RamSize = " << std::dec << m_ramSize * 4 << " bytes]" << std::endl;
        throw std::out_of_range("read: the specified address is out of range");
    }
    assert(!(address & 0x3) && "Address misaligned");
    unsigned wait = 20;
    m_soc->ext_tran_addr_i = address;
    m_soc->ext_tran_write_i = 0;
    m_soc->ext_tran_data_i = 0;
    m_soc->ext_tran_size_i = RV_SOC::extAccessSize::EXT_ACCESS_WORD;
    m_soc->ext_tran_start_i = 1;

    tick();
    m_soc->ext_tran_start_i = 0;
    m_soc->ext_tran_write_i = 0;

    bool success = false;
    for (unsigned i = wait; i >= 0; i--) {
        if (m_soc->ext_tran_ready_o) {
            success = true;
            break;
        }
        tick();
    }
    uint32_t data = 0;
    if (success) {
        m_soc->ext_tran_clear_i = 1;
        data = m_soc->ext_tran_data_o;
        tick();
        m_soc->ext_tran_clear_i = 0;
    } else {
        std::cerr << "readWordExt: no success result" << std::endl;
    }
    return data;
}

void RV_SOC::writeWord(unsigned address, uint32_t val)
{
    if (address >= m_ramSize) {
        std::cerr << "writeWord: address " << std::dec << (address * 4) <<
            " (w_idx = 0x" <<  std::hex << address << ") is out of range " <<
            "[RamSize = " << std::dec << m_ramSize * 4 << " bytes]" << std::endl;
        throw std::out_of_range("write: the specified address is out of range");
    }
    assert(!(address & 0x3) && "Address misaligned");
    unsigned wordIdx = address / wordSize;
    ram_write_word(wordIdx, val);
}

uint32_t RV_SOC::readWord(unsigned address)
{
    if (address >= m_ramSize) {
        std::cerr << "readWord: address " << std::dec << (address * 4) <<
            " (w_idx = 0x" << std::hex << address << ") is out of range" <<
            "[RamSize = " << std::dec << m_ramSize * 4 << " bytes]" << std::endl;
        throw std::out_of_range("read: the specified address is out of range");
    }
    assert(!(address & 0x3) && "Address misaligned");
    unsigned wordIdx = address / wordSize;
    int val = 0;
    ram_read_word(wordIdx, &val);
    return val;
}

void RV_SOC::reset()
{
    m_soc->rst_i = 1;
    m_soc->cpu_rst_i = 1;
    tick();
    m_soc->rst_i = 0;
    m_soc->cpu_rst_i = 0;
    tick();
}

uint32_t RV_SOC::getRamSize() const
{
    return m_ramSize;
}
    
uint64_t RV_SOC::getWordSize() const
{
    return wordSize;
}

void RV_SOC::writeReg(unsigned num, uint32_t val)
{
    assert(num < m_regFileSize);
    regfile_write_word(num, val);
}

uint32_t RV_SOC::readReg(unsigned num)
{
    assert(num < m_regFileSize);
    int val = 0;
    regfile_read_word(num, &val);
    return val;
}

void RV_SOC::setPC(uint32_t pc)
{
    // assert(validPc());
    m_soc->soc->cpu0->pc = pc;
}

uint32_t RV_SOC::getPC() const
{
    // assert(validPc());
    return m_soc->soc->cpu0->pc;
}

uint32_t RV_SOC::getRegFileSize() const
{
    return m_regFileSize;
}

void RV_SOC::clearRam()
{
    for (unsigned i = 0; i < m_ramSize; i += wordSize)
    {
        writeWord(i, 0);
    }
}
    
bool RV_SOC::validPc() const
{
    int val = 0;
    cpu_valid_pc(&val);
    return val;
}

en_state RV_SOC::cpu_state() const
{
    int val = 0;
    cpu_get_state(&val);
    return (en_state)val;
}

uint64_t RV_SOC::counterGetTick ()
{
    return  m_tickCnt;
}

uint64_t RV_SOC::counterGetStep ()
{
    return m_fetchCnt;
}

bool RV_SOC::getTestFinished() const
{
    return m_soc->soc->test_finished_o;
}
