// -*- c-basic-offset: 4; indent-tabs-mode: nil -*-
#ifndef HPCCPLUSPLUSPACKET_H
#define HPCCPLUSPLUSPACKET_H

#include <list>
#include "network.h"
#include "hpccpacket.h" // reuse IntEntry definition

// HPCC++ packets reuse the same INT layout as HPCC but carry a different
// packet type so we can distinguish the protocol end-to-end.

#define VALUE_NOT_SET -1

class HPCCPPPacket : public Packet {
public:
    typedef uint64_t seq_t;

    inline static HPCCPPPacket* newpkt(PacketFlow &flow,
                                       seq_t seqno, int size,
                                       bool retransmitted,
                                       bool last_packet,
                                       uint32_t destination = UINT32_MAX) {
        HPCCPPPacket* p = _packetdb.allocPacket();
        p->set_attrs(flow, size + ACKSIZE, seqno + size - 1);
        p->_type = HPCCPP;
        p->_is_header = false;
        p->_seqno = seqno;
        p->_retransmitted = retransmitted;
        p->_last_packet = last_packet;
        p->_path_len = 0;
        p->_direction = NONE;
        p->set_dst(destination);
        p->_int_hop = 0;
        return p;
    }

    inline static HPCCPPPacket* newpkt(PacketFlow &flow, const Route &route,
                                       seq_t seqno, int size,
                                       bool retransmitted,
                                       bool last_packet,
                                       uint32_t destination = UINT32_MAX) {
        HPCCPPPacket* p = _packetdb.allocPacket();
        p->set_route(flow, route, size + ACKSIZE, seqno + size - 1);
        p->_type = HPCCPP;
        p->_seqno = seqno;
        p->_is_header = false;
        p->_direction = NONE;
        p->_retransmitted = retransmitted;
        p->_last_packet = last_packet;
        p->_path_len = route.size();
        p->_int_hop = 0;
        p->set_dst(destination);
        return p;
    }

    void free() {_packetdb.freePacket(this);}
    virtual ~HPCCPPPacket(){}

    inline seq_t seqno() const {return _seqno;}
    inline bool retransmitted() const {return _retransmitted;}
    inline bool last_packet() const {return _last_packet;}
    inline simtime_picosec ts() const {return _ts;}
    inline void set_ts(simtime_picosec ts) {_ts = ts;}
    inline uint32_t path_id() const {if (_pathid!=UINT32_MAX) return _pathid; else return _route->path_id();}
    virtual PktPriority priority() const {return Packet::PRIO_LO;}
    IntEntry _int_info[5];
    uint32_t _int_hop;
    const static int ACKSIZE=64;
protected:
    seq_t _seqno;
    simtime_picosec _ts;
    bool _retransmitted;
    bool _last_packet;

    static PacketDB<HPCCPPPacket> _packetdb;
};

class HPCCPPAck : public Packet {
public:
    typedef HPCCPPPacket::seq_t seq_t;

    inline static HPCCPPAck* newpkt(PacketFlow &flow, const Route &route,
                                    seq_t ackno, uint32_t destination = UINT32_MAX) {
        HPCCPPAck* p = _packetdb.allocPacket();
        p->set_route(flow, route, HPCCPPPacket::ACKSIZE, ackno);
        p->_type = HPCCPPACK;
        p->_is_header = true;
        p->_ackno = ackno;
        p->_path_len = 0;
        p->_direction = NONE;
        p->set_dst(destination);
        p->_int_hop = 0;
        return p;
    }

    void copy_int_info(IntEntry* info, int cnt);

    void free() {_packetdb.freePacket(this);}
    inline seq_t ackno() const {return _ackno;}
    inline simtime_picosec ts() const {return _ts;}
    inline void set_ts(simtime_picosec ts) {_ts = ts;}
    virtual PktPriority priority() const {return Packet::PRIO_HI;}

    virtual ~HPCCPPAck(){}

    IntEntry _int_info[5];
    uint32_t _int_hop;
protected:
    seq_t _ackno;
    simtime_picosec _ts;
    static PacketDB<HPCCPPAck> _packetdb;
};

class HPCCPPNack : public Packet {
public:
    typedef HPCCPPPacket::seq_t seq_t;

    inline static HPCCPPNack* newpkt(PacketFlow &flow, const Route &route,
                                     seq_t ackno,
                                     uint32_t destination = UINT32_MAX) {
        HPCCPPNack* p = _packetdb.allocPacket();
        p->set_route(flow, route, HPCCPPPacket::ACKSIZE, ackno);
        p->_type = HPCCPPNACK;
        p->_is_header = true;
        p->_ackno = ackno;
        p->_direction = NONE;
        p->set_dst(destination);
        return p;
    }

    void free() {_packetdb.freePacket(this);}
    inline seq_t ackno() const {return _ackno;}
    inline simtime_picosec ts() const {return _ts;}
    inline void set_ts(simtime_picosec ts) {_ts = ts;}
    virtual PktPriority priority() const {return Packet::PRIO_HI;}

    virtual ~HPCCPPNack(){}

protected:
    seq_t _ackno;
    simtime_picosec _ts;
    static PacketDB<HPCCPPNack> _packetdb;
};

#endif
