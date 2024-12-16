//
//  DB.swift
//  ICU(I)P
//
//  Created by Ben Dixon on 13/12/2024.
//

import Foundation
import SQLite3
import SwiftCSV
import CoreLocation

class DB {
    private let libraryDirectory: URL
    private let dbPath: URL
    
    init() {
        self.libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        self.dbPath = libraryDirectory.appendingPathComponent("Application Support/ips.db")
    }
    
    func fill() {
        guard let db = createOrAccessDB() else { return }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        fillDbAsnBlocks(db: db)
        fillDbCities(db: db)
    }
    
    func getInfo(ipText: String?) -> (String, CLLocationCoordinate2D, Double)? {
        var asName: String?
        var coords: CLLocationCoordinate2D?
        var accuracyRadius: Double?
        
        if ipText == nil { return nil }
        guard let ip = ipToInt(from: ipText!) else { return nil }
        
        guard let db = createOrAccessDB() else { return nil }
        
        do {
            var statement: OpaquePointer?
            if sqlite3_prepare(db, "select * from asn_data where ? between network_start and network_end;", -1, &statement, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("error preparing insert: \(errmsg)")
            }
            if sqlite3_bind_int(statement, 1, ip) != SQLITE_OK { // https://www.sqlite.org/c3ref/bind_blob.html
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("failure binding IP: \(errmsg)")
            }
            
            assert(sqlite3_step(statement) == SQLITE_ROW)
            
            let id = sqlite3_column_int64(statement, 0)
            print("id = \(id); ", terminator: "")
            
            if let cString = sqlite3_column_text(statement, 3) {
                let name = String(cString: cString)
                asName = name
                print("name = \(name)")
            } else {
                print("name not found")
            }
            
            if sqlite3_finalize(statement) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("error finalizing prepared statement: \(errmsg)")
            }
            
            statement = nil
        }
        
        do {
            var statement: OpaquePointer?
            if sqlite3_prepare(db, "select * from city_block where ? between network_start and network_end;", -1, &statement, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("error preparing insert: \(errmsg)")
            }
            if sqlite3_bind_int(statement, 1, ip) != SQLITE_OK { // https://www.sqlite.org/c3ref/bind_blob.html
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("failure binding IP: \(errmsg)")
            }
            
            assert(sqlite3_step(statement) == SQLITE_ROW)
            
            print("Full City Block Row:")
              for i in 0..<sqlite3_column_count(statement) {
                  let columnName = sqlite3_column_name(statement, i)
                  let columnValue: String
                  
                  if let text = sqlite3_column_text(statement, i) {
                      columnValue = String(cString: text)
                  } else {
                      columnValue = "NULL"
                  }
                  
                  print("\(String(cString: columnName!)): \(columnValue) (\(i))")
              }
            
            if let cLat = sqlite3_column_text(statement, 8), let cLong = sqlite3_column_text(statement, 9), let lat = Double(String(cString: cLat)), let long = Double(String(cString: cLong)) {
                coords = CLLocationCoordinate2D(latitude: lat, longitude: long)
            } else {
                print("LatLong not found")
            }
            
            if let cAccRad = sqlite3_column_text(statement, 10), let accRad = Double(String(cString: cAccRad)) {
                accuracyRadius = accRad
            } else {
                print("LatLong not found")
            }
            
            if sqlite3_finalize(statement) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("error finalizing prepared statement: \(errmsg)")
            }
            
            statement = nil
        }
        
        if asName != nil && coords != nil && accuracyRadius != nil {
            return (asName!, coords!, accuracyRadius!)
        }
        
        return nil
    }

    private func fillDbAsnBlocks(db: OpaquePointer) {
        // Test first
        if sqlite3_exec(db, "select network from asn_data limit 1;", {
            resultVoidPointer, columnCount, values, columns in
            return columnCount == 1 && String(cString: values![0]!) == "1.0.0.0/24" ? 0 : 1
        }, nil, nil) == SQLITE_OK {
            print("ASN data DB already initialised")
            return
        }
        
        print("Filling ASN data DB")
        
        // Fill db if !initialised
         let createTablesSQL = """
             CREATE TABLE IF NOT EXISTS asn_data (
                 network CHAR(18) PRIMARY KEY,
                 prefix_length INTEGER,
                 autonomous_system_number INTEGER,
                 autonomous_system_organization TEXT,
                 network_start INTEGER,
                 network_end INTEGER
             );
         """
         print(sqlite3_exec(db, createTablesSQL, nil, nil, nil))
        
         do {
            let csv: CSV? = try CSV<Named>(
                name: "GeoLite2-ASN-Blocks-IPv4",
                extension: "csv",
                bundle: .main,
                encoding: .utf8
            )
        
            guard let csv else { return }
        
            for row in csv.rows {
                guard let network = row["network"] else { continue }
                let networkComponents = network.split(separator: "/")
                guard let net = IPv4Address(String(networkComponents[0])) else { continue }
                guard let prefixLength = Int(networkComponents[1]) else { continue }
        
                guard let _autoSystemNumberRaw = row["autonomous_system_number"] else { continue }
                guard let autoSystemNumber = Int(_autoSystemNumberRaw) else { continue }
                guard let autoSystemOrg = row["autonomous_system_organization"] else { continue }
        
                guard let (lowerBound, upperBound) = calculateIPBounds(from: network) else { continue }
        
                // Unsafe interpolation is okay here - it's coming straight from a trusted, static CSV.
                let rowSql = """
                INSERT INTO asn_data (network, prefix_length, autonomous_system_number, autonomous_system_organization, network_start, network_end) VALUES ("\(network)", \(prefixLength), \(autoSystemNumber), "\(autoSystemOrg)", \(lowerBound), \(upperBound));
                """
        
                 let resultCode = sqlite3_exec(db, rowSql, nil, nil, nil)
                 if resultCode != SQLITE_OK {
                 if let errorMessage = String(cString: sqlite3_errmsg(db), encoding: .utf8) {
                     print("Error executing SQL: \(errorMessage)")
                 }
             }
            }
        
         } catch {
             print("Error while reading CSV")
         }
    }
    
    private func fillDbCities(db: OpaquePointer) {
        // Test first
         if sqlite3_exec(db, "select network from city_block limit 1;", {
             resultVoidPointer, columnCount, values, columns in
             return columnCount == 1 && String(cString: values![0]!) == "1.0.0.0/24" ? 0 : 1
         }, nil, nil) == SQLITE_OK {
             print("City block data DB already initialised")
             return
         }
        
        print("Filling City block data DB")
        
        // Fill db if !initialised
         let createTablesSQL = """
             CREATE TABLE IF NOT EXISTS city_block (
                 network CHAR(18) PRIMARY KEY,
                 prefix_length INTEGER,
                 geoname_id INTEGER,
                 registered_country_geoname_id INTEGER,
                 represented_country_geoname_id INTEGER,
                 is_anonymous_proxy INTEGER,
                 is_satellite_provider INTEGER,
                 postal_code TEXT,
                 latitude REAL,
                 longitude REAL,
                 accuracy_radius INTEGER,
                 network_start INTEGER,
                 network_end INTEGER
             );
         """
         print(sqlite3_exec(db, createTablesSQL, nil, nil, nil))
        
         do {
            let csv: CSV? = try CSV<Named>(
                name: "GeoLite2-City-Blocks-IPv4",
                extension: "csv",
                bundle: .main,
                encoding: .utf8
            )
        
            guard let csv else { return }
        
             for row in csv.rows {
                 guard let network = row["network"] else { continue }
                 let networkComponents = network.split(separator: "/")
                 guard let prefixLength = Int(networkComponents[1]) else { continue }
                 
                 let geonameId = row["geoname_id"].unquotedOrNull
                 let registeredCountryGeonameId = row["registered_country_geoname_id"].unquotedOrNull
                 let representedCountryGeonameId = row["represented_country_geoname_id"].unquotedOrNull
                 
                 let isAnonymousProxy = row["is_anonymous_proxy"].unquotedOrNull
                 let isSatelliteProvider = row["is_satellite_provider"].unquotedOrNull
                 
                 let postalCode = row["postal_code"].quotedOrNull
                 
                 let latitude = row["latitude"].unquotedOrNull
                 let longitude = row["longitude"].unquotedOrNull
                 let accuracyRadius = row["accuracy_radius"].unquotedOrNull
                 
                 guard let (lowerBound, upperBound) = calculateIPBounds(from: network) else { continue }
                 
                 /*
                  network CHAR(18) PRIMARY KEY,
                  prefix_length INTEGER,
                  geoname_id INTEGER,
                  registered_country_geoname_id INTEGER,
                  represented_country_geoname_id INTEGER,
                  is_anonymous_proxy INTEGER,
                  is_satellite_provider INTEGER,
                  postal_code TEXT,
                  latitude REAL,
                  longitude REAL,
                  accuracy_radius INTEGER,
                  network_start INTEGER,
                  network_end INTEGER
                  */
                 
                 // Unsafe interpolation is okay here - it's coming straight from a trusted, static CSV.
                 let rowSql = """
                INSERT INTO city_block (network, prefix_length, geoname_id, registered_country_geoname_id, represented_country_geoname_id, is_anonymous_proxy, is_satellite_provider, postal_code, latitude, longitude, accuracy_radius, network_start, network_end) VALUES ("\(network)", \(prefixLength), \(geonameId), \(registeredCountryGeonameId), \(representedCountryGeonameId), \(isAnonymousProxy), \(isSatelliteProvider), \(postalCode), \(latitude), \(longitude), \(accuracyRadius), \(lowerBound), \(upperBound));
                """
                  let resultCode = sqlite3_exec(db, rowSql, nil, nil, nil)
                    if resultCode != SQLITE_OK {
                      if let errorMessage = String(cString: sqlite3_errmsg(db), encoding: .utf8) { print("Error executing SQL: \(errorMessage)") }
                    }
                    }
        
         } catch {
             print("Error while reading CSV")
         }
    }
    
    func createOrAccessDB() -> OpaquePointer? {
        var db: OpaquePointer?
        if sqlite3_open(dbPath.absoluteString, &db) == SQLITE_OK {
            return db
        } else {
            print("Error opening database")
            sqlite3_close(db) // Important - do not leak memory. https://sqlite.org/c3ref/open.html
            return nil
        }
    }

    func ensureDBAndAddRow() {
        guard let db = createOrAccessDB() else { return }
        
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS ip_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ip TEXT NOT NULL
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) == SQLITE_OK {
            let checkEmptySQL = "SELECT COUNT(*) FROM ip_data;"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, checkEmptySQL, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_ROW {
                    let count = sqlite3_column_int(statement, 0)
                    if count == 0 {
                        let insertSQL = "INSERT INTO ip_data (ip) VALUES ('74.95.121.126');"
                        sqlite3_exec(db, insertSQL, nil, nil, nil)
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        sqlite3_close(db)
    }
}

extension Optional where Wrapped == String {
    var quotedOrNull: String {
        guard let value = self, !value.isEmpty else {
            return "NULL"
        }
        return "\"\(value)\""
    }
    
    var unquotedOrNull: String {
        guard let value = self, !value.isEmpty else {
            return "NULL"
        }
        return "\(value)"
    }
}
