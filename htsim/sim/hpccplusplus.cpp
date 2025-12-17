// -*- c-basic-offset: 4; indent-tabs-mode: nil -*- 
#include <math.h>
#include <iostream>
#include <algorithm>
#include "hpccplusplus.h"
#include "queue.h"
#include <stdio.h>
#include "switch.h"
#include "trigger.h"
using namespace std;

////////////////////////////////////////////////////////////////
//  HPCC++ SOURCE
////////////////////////////////////////////////////////////////

//#define LOGSINK 2332
#define LOGSINK   0 

uint32_t HPCCPPSrc::_global_node_count = 0;
bool HPCCPPSrc::_debug = false;  // Global debug flag

simtime_picosec HPCCPPSrc::_T = timeFromUs(12.0);//Known baseline RTT
double HPCCPPSrc::_eta = 0.95;//Target link utilization
double HPCCPPSrc::_beta = 0.7;//INT smoothing factor
double HPCCPPSrc::_gamma = 0.5;//cwnd smoothing factor
uint32_t HPCCPPSrc::_max_stages = 5;//Maximum stages for additive increases
uint32_t HPCCPPSrc::_N = 10;//maximum number of flows.
uint32_t HPCCPPSrc::_Wai = 0;//Additive increase amount.
uint32_t HPCCPPSrc::_min_cwnd_pkts = 2;//Minimum cwnd in packets

HPCCPPSrc::HPCCPPSrc(HPCCPPLogger* logger, TrafficLogger* pktlogger, EventList &eventlist, linkspeed_bps rate)
    : BaseQueue(rate,eventlist,NULL), _logger(logger), _flow(pktlogger)
{
    _mss = Packet::data_packet_size();
    _end_trigger = NULL;

    _stop_time = 0;
    _flow_started = false;
    _pacing_rate = rate;

    _acked_packets = 0;
    _packets_sent = 0;
    _new_packets_sent = 0;
    _rtx_packets_sent = 0;
    _acks_received = 0;
    _nacks_received = 0;

    _highest_sent = 0;
    _last_acked = 0;
    _dstaddr = UINT32_MAX;

    _sink = 0;
    _done = false;

    _drops = 0;
    _flow_size = ((uint64_t)1)<<63;
  
    _node_num = _global_node_count++;
    _nodename = "HPCC++src " + to_string(_node_num);

    srand(time(NULL));
    _pathid = random()%256;

    _Wai = _mss;

    // debugging hack
    _log_me = false;

    _state_send = READY;
    _time_last_sent = 0;
    
    _cwnd = _T * rate / pow(10,12) / 8;

    _pacing_rate = _cwnd * 8 * pow(10,12) / _T;
    update_spacing();

    _link_count = 0;
    _last_update_seq = 0;

    if (_debug) cout << "Initial HPCC++ CWND is " << _cwnd << " target RTT " << timeAsUs(_T) << " rate " << rate << endl;
    _flightsize = 0;
    _U = _eta;
}

void HPCCPPSrc::set_traffic_logger(TrafficLogger* pktlogger) {
    _flow.set_logger(pktlogger);
}

void HPCCPPSrc::log_me() {
    if (_log_me == true)
        return;

    if (_debug) cout << "Enabling logging on HPCCPPSrc " << _nodename << endl;
    _log_me = true;
    if (_sink)
        _sink->log_me();
}

void HPCCPPSrc::startflow(){
    if (_debug) cout << "startflow " << _flow._name << " at " << timeAsUs(eventlist().now()) << endl;
    _flow_started = true;
    _highest_sent = 0;
    _last_acked = 0;
    
    _acked_packets = 0;
    _packets_sent = 0;
    _done = false;
    
    eventlist().sourceIsPendingRel(*this,0);
}

void HPCCPPSrc::set_end_trigger(Trigger& end_trigger) {
    _end_trigger = &end_trigger;
}

void HPCCPPSrc::connect(Route* routeout, Route* routeback, HPCCPPSink& sink, simtime_picosec starttime) {
    assert(routeout);
    _route = routeout;
    
    _sink = &sink;
    _flow.set_id(get_id()); // identify the packet flow with the HPCC++ source that generated it
    _flow._name = _name;
    _sink->connect(*this, routeback);

    if (starttime != TRIGGER_START) {
        startflow();
    }
    else cout << "TRIGGER START " << _nodename << endl; 
}

void HPCCPPSrc::processNack(const HPCCPPNack& nack){
    _last_acked = nack.ackno();
    _rtx_packets_sent += _highest_sent - _last_acked;

    if (_debug) cout << "HPCC++ " << _name << " go back n from " <<  _highest_sent << " to " << _last_acked << " at " << timeAsUs(eventlist().now()) << " us" << endl;

    if (_flow_size && _highest_sent>_flow_size && _last_acked < _flow_size){
        eventlist().sourceIsPendingRel(*this,0);
    }

    _highest_sent = _last_acked;
    _nacks_received ++;

    _cwnd = _mss;
    _flightsize = 0;
}

void HPCCPPSrc::processAck(const HPCCPPAck& ack) {
    HPCCPPAck::seq_t ackno = ack.ackno();

    if (ackno > _last_acked) { // a brand new ack    
        assert(ackno - _last_acked <= _flightsize);
        _flightsize -= (ackno - _last_acked);
        _last_acked = ackno;
    }

    if (ackno > _last_update_seq){
        _cwnd = computeWind(measureInFlight(ack), true);
        if (_debug) cout << "HPCC++ CWND1 " << _cwnd << " ACKNO " << ackno << " at " << timeAsUs(eventlist().now()) << " src " << _nodename << endl;
        _last_update_seq = _highest_sent;
    }
    else {
        _cwnd = computeWind(measureInFlight(ack), false);
        if (_debug) cout << "HPCC++ CWND2 " << _cwnd << " ACKNO " << ackno << " at " << timeAsUs(eventlist().now()) << " src " << _nodename << endl;
    }

    _pacing_rate = _cwnd * 8 * pow(10,12) / _T;
    update_spacing();

    if (_logger) _logger->logHPCCPP(*this, HPCCPPLogger::HPCCPP_RCV);

    if (ackno >= _flow_size){
        if (_debug) cout << "Flow " << _name << " finished at " << timeAsUs(eventlist().now()) << " total bytes " << ackno << endl;
        _done = true;
        if (_end_trigger) {
            _end_trigger->activate();
        }

        return;
    }
}

void HPCCPPSrc::processPause(const EthPausePacket& p) {
    if (p.sleepTime()>0){
        _state_send = PAUSED;
    }
    else {
        _state_send = READY;
        eventlist().sourceIsPendingRel(*this,0);
    }
}

void HPCCPPSrc::receivePacket(Packet& pkt) 
{
    if (!_flow_started){
        assert(pkt.type()==ETH_PAUSE);
        return; 
    }

    if (_stop_time && eventlist().now() >= _stop_time) {
        _flow_size = _highest_sent+_mss;
        _stop_time = 0;
    }

    if (_done)
        return;

    switch (pkt.type()) {
    case ETH_PAUSE:    
        processPause((const EthPausePacket&)pkt);
        pkt.free();
        return;
    case HPCCPPNACK: 
        _nacks_received++;
        processNack((const HPCCPPNack&)pkt);
        pkt.free();
        return;
    case HPCCPPACK:
        _acks_received++;
        processAck((const HPCCPPAck&)pkt);
        pkt.free();
        return;
    default:
        abort();
    }
}

void HPCCPPSrc::send_packet() {
    HPCCPPPacket* p = NULL;
    bool last_packet = false;

    assert(_flow_started);

    if (_flow_size && (_last_acked >= _flow_size || _highest_sent > _flow_size))
        return;

    if (_flow_size && _highest_sent + _mss >= _flow_size) {
        last_packet = true;
    }
    
    p = HPCCPPPacket::newpkt(_flow, *_route, _highest_sent+1, _mss, false, last_packet,_dstaddr);
    
    assert(p);
    p->set_pathid(_pathid);

    p->flow().logTraffic(*p,*this,TrafficLogger::PKT_CREATESEND);
    p->set_ts(eventlist().now());
    
    if (_log_me) {
        cout << "Sent " << _highest_sent+1 << " Flow Size: " << _flow_size << endl;
    }
    _highest_sent += _mss;
    _packets_sent++;

    _flightsize += _mss;

    p->sendOn();
}

void HPCCPPSrc::doNextEvent() {
    assert(_flow_started);

    if (_state_send==PAUSED)
        return;

    if (_flow_size && _highest_sent >= _flow_size) {
        return;
    }

    if (_time_last_sent==0 || eventlist().now() - _time_last_sent >= _packet_spacing){
        if (_cwnd >= _flightsize + _mss) 
            send_packet();

        _time_last_sent = eventlist().now();
    }

    simtime_picosec next_send = _time_last_sent + _packet_spacing;
    assert(next_send > eventlist().now());

    eventlist().sourceIsPending(*this, next_send);
}

double HPCCPPSrc::measureInFlight(const HPCCPPAck& ack){
    /*
      HPCC++ uses a beta-smoothed estimate of utilization to dampen noise:
      U = (1 - beta) * U + beta * u
    */

    double u = 0, uprime;
    uint32_t i;
    double txRate;

    if (ack._int_hop == _link_count){
        for (i = 0;i<_link_count;i++){
            txRate = (ack._int_info[i]._txbytes - _link_info[i]._txbytes) * 8 * pow(10,12) / (ack._int_info[i]._ts - _link_info[i]._ts);

            uprime = min(ack._int_info[i]._queuesize, _link_info[i]._queuesize)*8 * pow (10,12) / ( (double)ack._int_info[i]._linkrate * _T ) + txRate / ack._int_info[i]._linkrate; 
            if (uprime > u) {
                u = uprime;
            }
        }

        _U = (1 - _beta)*_U + _beta*u;
    }
    else {    //reset path state
        _link_count = ack._int_hop;
        for (i = 0;i<_link_count;i++)
            _link_info[i] = ack._int_info[i];
    }

    return _U;
};

HPCCPPPacket::seq_t HPCCPPSrc::computeWind(double U, bool updateWc){
    HPCCPPPacket::seq_t W;
    HPCCPPPacket::seq_t target;
    HPCCPPPacket::seq_t min_cwnd = std::max<uint64_t>(_min_cwnd_pkts * _mss, _mss);
    
    if (_U >= _eta || _incStage >= _max_stages){
        target = _cwnd / (_U / _eta) + _Wai;

        if (updateWc){
            _incStage = 0;
            _cwnd = target;
        }
    }   
    else {
        target = _cwnd + _Wai;
        if (updateWc){
            _incStage++;
            _cwnd = target;
        }
    } 

    double smoothed = (1 - _gamma) * (double)_cwnd + _gamma * (double)target;
    if (smoothed < (double)min_cwnd)
        smoothed = (double)min_cwnd;

    W = (HPCCPPPacket::seq_t)smoothed;
    if (updateWc)
        _cwnd = W;

    return W; 
};

////////////////////////////////////////////////////////////////
//  HPCC++ SINK
////////////////////////////////////////////////////////////////

HPCCPPSink::HPCCPPSink()
    : DataReceiver("HPCC++_sink"),_cumulative_ack(0) , _total_received(0) 
{
    _src = 0;
    
    _nodename = "HPCC++sink";
    _highest_seqno = 0;
    _log_me = false;
    _total_received = 0;
}

void HPCCPPSink::log_me() {
    if (_log_me == true)
        return;

    _log_me = true;

    if (_src)
        _src->log_me();  
}

void HPCCPPSink::connect(HPCCPPSrc& src, Route* route)
{
    _src = &src;
    _route = route;
    
    _cumulative_ack = 0;
    _drops = 0;
}

void HPCCPPSink::receivePacket(Packet& pkt) {
    switch (pkt.type()) {
    case HPCCPP:
        break;
    default:
        abort();
    }

    HPCCPPPacket *p = (HPCCPPPacket*)(&pkt);
    HPCCPPPacket::seq_t seqno = p->seqno();

    simtime_picosec ts = p->ts();

    if (seqno > _cumulative_ack+1){
        send_nack(ts,_cumulative_ack);      
    
        pkt.flow().logTraffic(pkt,*this,TrafficLogger::PKT_RCVDESTROY);

        p->free();
        return;
    }

    int size = p->size()-HPCCPPPacket::ACKSIZE; 

    if (seqno == _cumulative_ack+1) {
        _cumulative_ack = seqno + size - 1;
    } else if (seqno < _cumulative_ack+1) {
        //must have been a bad retransmit
    }
    send_ack(ts,p->_int_info, p->_int_hop);
    pkt.flow().logTraffic(pkt,*this,TrafficLogger::PKT_RCVDESTROY);
    pkt.free();
}

void HPCCPPSink::send_ack(simtime_picosec ts, IntEntry* intinfo, uint32_t hops) {
    HPCCPPAck *ack = 0;
    ack = HPCCPPAck::newpkt(_src->_flow, *_route, _cumulative_ack,_srcaddr);
    ack->set_pathid(0);

    if (hops>0)
        ack->copy_int_info(intinfo,hops);

    ack->sendOn();
}

void HPCCPPSink::send_nack(simtime_picosec ts, HPCCPPPacket::seq_t ackno) {
    HPCCPPNack *nack = NULL;
    nack = HPCCPPNack::newpkt(_src->_flow, *_route, ackno,_srcaddr);

    nack->set_pathid(0);
    assert(nack);
    nack->flow().logTraffic(*nack,*this,TrafficLogger::PKT_CREATE);
    nack->set_ts(ts);
    nack->sendOn();
}

