// -*- c-basic-offset: 4; indent-tabs-mode: nil -*- 
#include "hpccpluspluspacket.h"

PacketDB<HPCCPPPacket> HPCCPPPacket::_packetdb;
PacketDB<HPCCPPAck> HPCCPPAck::_packetdb;
PacketDB<HPCCPPNack> HPCCPPNack::_packetdb;

void HPCCPPAck::copy_int_info(IntEntry* info, int cnt){
    for (int i = 0;i<cnt;i++)
        _int_info[i] = info[i];
        
    _int_hop = cnt;
};
