#include <core.p4>
#include <v1model.p4>

const bit<32> THRESHOLD = 1000;

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4> version;
    bit<4> ihl;
    bit<8> diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3> flags;
    bit<13> fragOffset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t ipv4;
}

struct metadata {
    bit<32> index;
    bit<32> count;
}

register<bit<32>>(1024) packet_counter;

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    action detect_and_forward(bit<9> port) {
        meta.index = hdr.ipv4.srcAddr & 1023;
        packet_counter.read(meta.count, meta.index);
        meta.count = meta.count + 1;
        packet_counter.write(meta.index, meta.count);

        // Keep the hardware fallback just in case the AI is slow
        if (meta.count > THRESHOLD) {
            mark_to_drop(standard_metadata); 
        } else {
            standard_metadata.egress_spec = port;
        }
    }

    // NEW ACTION FOR THE AI CONTROLLER TO CALL
    action drop() {
        mark_to_drop(standard_metadata);
    }

    table ipv4_table {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
            detect_and_forward;
            drop; // ADDED DROP ACTION HERE
        }
        size = 1024;
        default_action = detect_and_forward(1);
    }

    apply {
        if (hdr.ipv4.isValid()) {
            ipv4_table.apply();
        }
    }
}

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
