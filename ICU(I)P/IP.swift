//
//  IP.swift
//  ICU(I)P
//
//  Created by Ben Dixon on 13/12/2024.
//

import Foundation
import SwiftCSV

struct IPv4Address {
    let value: UInt32
    
    init?(_ string: String) {
        let components = string.split(separator: ".").compactMap { UInt8($0) }
        guard components.count == 4 else { return nil }
        self.value = components.reduce(0) { ($0 << 8) + UInt32($1) }
    }
    
    init(_ intValue: UInt32) {
        self.value = intValue
    }
    
    var octets: [UInt8] {
        return [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }
    
    func toString() -> String {
        return octets.map { String($0) }.joined(separator: ".")
    }
}

struct IPv4SubnetMask {
    let prefixLength: Int
    let networkAddress: IPv4Address

    init(networkAddress: IPv4Address, prefixLength: Int) {
        self.networkAddress = networkAddress
        self.prefixLength = prefixLength
    }

    func contains(_ ip: IPv4Address) -> Bool {
        let mask = UInt32.max << (32 - prefixLength)
        return (ip.value & mask) == (networkAddress.value & mask)
    }
}

func findMatchingRow(for ipAddress: String?, in csv: CSV<Named>?) -> (String, String, String)? {
    if ipAddress == nil || csv == nil { return nil }
    
    guard let ip = IPv4Address(ipAddress!) else { return nil }
    
    for row in csv!.rows {
        guard let networkString = row["network"] else { continue }
        
        let networkComponents = networkString.split(separator: "/")
        guard networkComponents.count == 2,
              let network = IPv4Address(String(networkComponents[0])),
              let prefixLength = Int(networkComponents[1]) else {
            continue
        }
        
        let subnet = IPv4SubnetMask(networkAddress: network, prefixLength: prefixLength)
        if subnet.contains(ip) {
            return (row["network"]!, row["autonomous_system_number"]!, row["autonomous_system_organization"]!)
        }
    }
    
    return nil
}

func getPublicIP(completion: @escaping (String?) -> Void) {
    guard let url = URL(string: "https://ifconfig.me") else {
        completion(nil)
        return
    }
    
    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        guard let data = data, error == nil else {
            completion(nil)
            return
        }
        
        let ipAddress = String(data: data, encoding: .utf8)
        completion(ipAddress)
    }
    
    task.resume()
}

func ipToInt(from ip: String) -> Int32? {
    let parts = ip.split(separator: ".").compactMap { UInt8($0) }
    guard parts.count == 4 else {
        return nil 
    }
    
    return parts.reduce(0) { ($0 << 8) | Int32($1) }
}

func calculateIPBounds(from cidr: String) -> (lowerBound: Int32, upperBound: Int32)? {
    let parts = cidr.split(separator: "/")
    guard parts.count == 2,
          let baseIP = parts.first,
          let prefixLength = Int(parts.last!),
          prefixLength >= 0, prefixLength <= 32 else {
        return nil // Invalid CIDR format
    }

    // Convert IP to binary
    let ipParts = baseIP.split(separator: ".").compactMap { UInt8($0) }
    guard ipParts.count == 4 else {
        return nil // Invalid IP format
    }

    // Convert the IP to a single 32-bit integer
    let ipInt = ipParts.reduce(0) { ($0 << 8) | Int32($1) }

    // Calculate the mask
    let mask = prefixLength == 0 ? 0 : ~((1 << (32 - prefixLength)) - 1)

    // Calculate lower and upper bounds
    let lowerBoundInt = ipInt & Int32(mask)
    let upperBoundInt = lowerBoundInt | ~Int32(mask)

//    // Convert back to dotted decimal format
//    func intToIP(_ ip: Int32) -> String {
//        return [
//            (ip >> 24) & 0xFF,
//            (ip >> 16) & 0xFF,
//            (ip >> 8) & 0xFF,
//            ip & 0xFF
//        ].map { String($0) }.joined(separator: ".")
//    }
//
//    let lowerBound = intToIP(lowerBoundInt)
//    let upperBound = intToIP(upperBoundInt)
//
//    return (lowerBound, upperBound)
    return (lowerBoundInt, upperBoundInt)
}
