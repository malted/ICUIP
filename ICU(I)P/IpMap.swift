//
//  Map.swift
//  ICU(I)P
//
//  Created by Ben Dixon on 15/12/2024.
//

import SwiftUI
import MapKit
import CoreLocation

struct IpMap: View {
    @Binding var asName: String?
    @Binding var coords: CLLocationCoordinate2D
    @Binding var accuracyRadius: Double?

    @State private var mapType: Int = 0
    @State private var currentDistance: Double = 10000
    
    var selectedMapStyle: MapStyle {
        return switch(mapType) {
          case 0: .standard
          case 1: .hybrid
          case 2: .imagery
          default: .standard
        }
    }
    
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .camera(
            MapCamera(centerCoordinate: .init(latitude: 0, longitude: 0), distance: 10000)
        )
    )
    
    /*
     initialPosition: MapCameraPosition.region(
         MKCoordinateRegion(
             center: coords,
             span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
         )
     )
     */
    
    var body: some View {
        VStack {
            Map(position: $position) {
                if asName != nil {
                    Marker(asName!, coordinate: coords)
                }
                
                if accuracyRadius != nil {
                    MapCircle(center: coords, radius: accuracyRadius! * 1000)
                        .foregroundStyle(Color.red.opacity(0.1))
                        .stroke(Color.red, lineWidth: 2)
                }
            }
            .mapStyle(selectedMapStyle)
            .onMapCameraChange { context in
                currentDistance = context.camera.distance
            }
            .onChange(of: coords.latitude) {
                position = .camera(MapCamera(
                    centerCoordinate: coords,
                    distance: currentDistance,
                    heading: 0,
                    pitch: 0
                ))
            }
            .onChange(of: coords.longitude) {
                position = .camera(MapCamera(
                    centerCoordinate: coords,
                    distance: currentDistance,
                    heading: 0,
                    pitch: 0
                ))
            }
            
                        
            Picker("", selection: $mapType) {
                Text("Default").tag(0)
                Text("Transit").tag(1)
                Text("Satellite").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
}

#Preview {
    Map()
}

