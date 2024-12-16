//
//  IpInput.swift
//  ICU(I)P
//
//  Created by Ben Dixon on 15/12/2024.
//

import SwiftUI

struct IpInput: View {
    @State private var username: String = ""
    @FocusState private var emailFieldIsFocused: Bool


    var body: some View {
        TextField(
            "User name (email address)",
            text: $username
        )
        .focused($emailFieldIsFocused)
        .onSubmit {
            print("submitted: \(username)")
        }
        .disableAutocorrection(true)
        .border(.secondary)


        Text(username)
            .foregroundColor(emailFieldIsFocused ? .red : .blue)
    }
    
}

#Preview {
    IpInput()
}
