// -*- c-basic-offset: 4; indent-tabs-mode: nil -*-
#ifndef MCCPACKET_H
#define MCCPACKET_H

#include <list>
#include "network.h"
#include "hpccpacket.h"  // For IntEntry

// MCCPacket and MCCAck are subclasses of Packet.
// They incorporate a packet database, to reuse packet objects that are no longer needed.
// Note: you never construct a new MCCPacket or MCCAck directly; 
// rather you use the static method newpkt() which knows to reuse old packets from the database.

#define VALUE_NOT_SET -1

// IntEntry is defined in hpccpacket.h, we reuse it here
// Forward declaration - IntEntry is already defined in hpccpacket.h

class MCCPacket : public Packet {
public:
    typedef uint64_t seq_t;

    // pseudo-constructor for a routeless packet - routing information
    // must be filled in later
    inline static MCCPacket* newpkt(PacketFlow &flow, 
                                     seq_t seqno, int size, 
                                     bool retransmitted, 
                                     bool last_packet,
                                     uint32_t destination = UINT32_MAX) {
        MCCPacket* p = _packetdb.allocPacket();
        p->set_attrs(flow, size+ACKSIZE, seqno+size-1); // The MCC sequence number is the first byte of the packet; I will ID the packet by its last byte.
        p->_type = MCC;
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
  
    inline static MCCPacket* newpkt(PacketFlow &flow, const Route &route, 
                                     seq_t seqno, int size, 
                                     bool retransmitted,
                                     bool last_packet,
                                     uint32_t destination = UINT32_MAX) {
        MCCPacket* p = _packetdb.allocPacket();
        p->set_route(flow,route,size+ACKSIZE,seqno+size-1); // The MCC sequence number is the first byte of the packet; I will ID the packet by its last byte.
        p->_type = MCC;
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
    virtual ~MCCPacket(){}
    
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
    bool _last_packet;  // set to true in the last packet in a flow.

    //area to aggregate switch INT information
    static PacketDB<MCCPacket> _packetdb;
};

class MCCAck : public Packet {
public:
    typedef MCCPacket::seq_t seq_t;
  
    inline static MCCAck* newpkt(PacketFlow &flow, const Route &route, 
                                  seq_t ackno, uint32_t destination = UINT32_MAX) {
        MCCAck* p = _packetdb.allocPacket();
        p->set_route(flow,route,MCCPacket::ACKSIZE,ackno);
        p->_type = MCCACK;
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
  
    virtual ~MCCAck(){}

    IntEntry _int_info[5];
    uint32_t _int_hop;
protected:
    seq_t _ackno;
    simtime_picosec _ts;
    static PacketDB<MCCAck> _packetdb;
};


class MCCNack : public Packet {
public:
    typedef MCCPacket::seq_t seq_t;
  
    inline static MCCNack* newpkt(PacketFlow &flow, const Route &route, 
                                   seq_t ackno,
                                   uint32_t destination = UINT32_MAX) {
        MCCNack* p = _packetdb.allocPacket();
        p->set_route(flow,route,MCCPacket::ACKSIZE,ackno);
        p->_type = MCCNACK;
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
  
    virtual ~MCCNack(){}

protected:
    seq_t _ackno;
    simtime_picosec _ts;
    static PacketDB<MCCNack> _packetdb;
};



#endif
