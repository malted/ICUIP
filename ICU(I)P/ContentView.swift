//
//  ContentView.swift
//  ICU(I)P
//
//  Created by Ben Dixon on 13/12/2024.
//

import SwiftUI
import CoreLocation
import MapKit
import SwiftCSV

struct ContentView: View {
    @State private var ipText: String?
    
    @State private var asName: String?
    @State private var coords = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var accuracyRadius: Double?
    
    private let db = DB()
        
    var body: some View {
        VStack {
            Button("Current IP") {
                getPublicIP { ip in
                    if let ip = ip {
                        ipText = ip
                        print("Your public IP address is: \(ip)")
                    } else {
                        print("Failed to get public IP address")
                    }
                }
            }
            
            IpInput()
            
            IpMap(asName: $asName, coords: $coords, accuracyRadius: $accuracyRadius)
            
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("""
Database and Contents Copyright (c) 2024 MaxMind, Inc. Use of this MaxMind product is governed by MaxMind's GeoLite2 End User License Agreement, which can be viewed at https://www.maxmind.com/en/geolite2/eula. This database incorporates GeoNames [https://www.geonames.org] geographical data, which is made available under the Creative Commons Attribution 4.0 License. To view a copy of this license, visit https://creativecommons.org/licenses/by/4.0/.
""").foregroundStyle(.secondary).font(.caption)
        }
        .padding()
        .onAppear {
            db.fill()
        }
        .onChange(of: ipText) {
            if ipText == nil { return }
            let res = db.getInfo(ipText: ipText)
            if let nom = res?.0 {
                asName = nom
            }
            if let crds = res?.1 {
                coords = crds
            }
            if let rad = res?.2 {
                accuracyRadius = rad
            }
        }
//        .onChange(of: ipText) {
//            do {
//                let resource: CSV? = try CSV<Named>(
//                    name: "GeoLite2-ASN-Blocks-IPv4",
//                    extension: "csv",
//                    bundle: .main,
//                    encoding: .utf8
//                )
//
//                if let matchingRow = findMatchingRow(for: ipText, in: resource) {
//                    print("Matching row: \(matchingRow)")
//                    asName = matchingRow.2
//                } else {
//                    print("No matching row found")
//                }
//            } catch {
//                print("Error reading CSV: \(error)")
//            }
//
//            var geonameId: String?
//            
//            do {
//                let resource: CSV? = try CSV<Named>(
//                    name: "GeoLite2-City-Blocks-IPv4",
//                    extension: "csv",
//                    bundle: .main,
//                    encoding: .utf8
//                )
//                
//                if resource == nil || ipText == nil { return }
//                guard let ip = IPv4Address(ipText!) else { return }
//                
//                for row in resource!.rows {
//                    guard let networkString = row["network"] else { continue }
//                    
//                    let networkComponents = networkString.split(separator: "/")
//                    guard networkComponents.count == 2,
//                          let network = IPv4Address(String(networkComponents[0])),
//                          let prefixLength = Int(networkComponents[1]) else {
//                        continue
//                    }
//                    
//                    let subnet = IPv4SubnetMask(networkAddress: network, prefixLength: prefixLength)
//                    if subnet.contains(ip) {
//                        // ["geoname_id": "4930956", "registered_country_geoname_id": "6252001", "postal_code": "02127", "is_satellite_provider": "0", "is_anycast": "", "is_anonymous_proxy": "0", "network": "74.95.120.0/22", "represented_country_geoname_id": "", "latitude": "42.3364", "accuracy_radius": "100", "longitude": "-71.0326"]
//                        geonameId = row["geoname_id"]
//                    }
//                }
//            } catch {
//                print("Error reading CSV: \(error)")
//            }
//            
//            do {
//                let resource: CSV? = try CSV<Named>(
//                    name: "GeoLite2-City-Locations-en",
//                    extension: "csv",
//                    bundle: .main,
//                    encoding: .utf8
//                )
//                
//                if geonameId == nil { return }
//                
//                let row = resource!.rows.first(where: { $0["geoname_id"] == geonameId })
//                if row == nil { return }
//                print(row)
//                coords = CLLocationCoordinate2D(latitude: Double(row!["latitude"] ?? "0")!, longitude: Double(row!["longitude"] ?? "0")!)
//                
//                print(row)
//            } catch {
//                print("Error reading CSV: \(error)")
//            }
//        }
    }
}

#Preview {
    ContentView()
}
