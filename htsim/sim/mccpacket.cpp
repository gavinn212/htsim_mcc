// -*- c-basic-offset: 4; indent-tabs-mode: nil -*- 
#include "mccpacket.h"

PacketDB<MCCPacket> MCCPacket::_packetdb;
PacketDB<MCCAck> MCCAck::_packetdb;
PacketDB<MCCNack> MCCNack::_packetdb;

void MCCAck::copy_int_info(IntEntry* info, int cnt){
    for (int i = 0;i<cnt;i++)
        _int_info[i] = info[i];
        
    _int_hop = cnt;
};
